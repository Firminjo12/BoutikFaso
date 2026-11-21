from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import jwt
from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import AuthContext, get_current_context, unauthorized
from app.core.security import (
    decode_access_token,
    hash_password,
    verify_password,
)
from app.db.session import get_db
from app.models import (
    AuditLog,
    Merchant,
    MerchantMembership,
    MembershipRole,
    User,
    UserSession,
)
from app.schemas.auth import (
    RegisterRequest,
    RefreshRequest,
    TokenResponse,
    UserRead,
)
from app.services.audit import record_audit
from app.services.tokens import (
    hash_refresh_token,
    issue_session_tokens,
    new_user_session,
)

router = APIRouter()


def _find_user_by_login(db: Session, identifier: str) -> User | None:
    identifier = identifier.strip()
    return db.scalar(
        select(User).where(
            or_(
                func.lower(User.email) == identifier.lower(),
                User.phone == identifier,
            )
        )
    )


def _first_active_merchant_id(db: Session, user_id: UUID) -> UUID | None:
    return db.scalar(
        select(MerchantMembership.merchant_id)
        .join(Merchant, Merchant.id == MerchantMembership.merchant_id)
        .where(
            MerchantMembership.user_id == user_id,
            MerchantMembership.is_active.is_(True),
            Merchant.is_active.is_(True),
        )
        .order_by(MerchantMembership.created_at)
        .limit(1)
    )


def _new_token_pair(
    db: Session, user: User, session: UserSession, merchant_id: UUID | None
) -> TokenResponse:
    return issue_session_tokens(db, user, session, merchant_id)


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Créer un compte et sa première boutique",
)
def register(
    payload: RegisterRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> TokenResponse:
    filters = []
    if payload.email:
        filters.append(func.lower(User.email) == payload.email)
    if payload.phone:
        filters.append(User.phone == payload.phone)
    if db.scalar(select(User.id).where(or_(*filters)).limit(1)):
        raise HTTPException(status_code=409, detail="Ce compte existe déjà.")

    user = User(
        id=uuid4(),
        full_name=payload.full_name,
        email=payload.email,
        phone=payload.phone,
        password_hash=hash_password(payload.password),
    )
    db.add(user)

    merchant = Merchant(
        id=uuid4(),
        name=payload.merchant_name,
        phone=payload.merchant_phone,
        address=payload.merchant_address,
    )
    db.add(merchant)
    membership = MerchantMembership(
        user_id=user.id,
        merchant_id=merchant.id,
        role=MembershipRole.OWNER,
        is_active=True,
    )
    db.add(membership)

    session = new_user_session(user.id)
    tokens = _new_token_pair(db, user, session, merchant.id)
    record_audit(
        db,
        request,
        "account.registered",
        actor_user_id=user.id,
        merchant_id=merchant.id,
        target_type="merchant",
        target_id=merchant.id,
    )
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="E-mail ou téléphone déjà utilisé.") from None
    return tokens


@router.post("/login", response_model=TokenResponse, summary="Ouvrir une session")
def login(
    request: Request,
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
) -> TokenResponse:
    ip_address = request.client.host if request.client else None
    if ip_address:
        failed_attempts = db.scalar(
            select(func.count(AuditLog.id)).where(
                AuditLog.action == "auth.login_failed",
                AuditLog.ip_address == ip_address,
                AuditLog.created_at >= datetime.now(UTC) - timedelta(minutes=15),
            )
        ) or 0
        if failed_attempts >= 5:
            raise HTTPException(
                status_code=429,
                detail="Trop de tentatives. Réessayez dans quelques minutes.",
                headers={"Retry-After": "900"},
            )
    user = _find_user_by_login(db, form.username)
    if user is None or not verify_password(form.password, user.password_hash):
        record_audit(
            db,
            request,
            "auth.login_failed",
            details={"identifier_kind": "email" if "@" in form.username else "phone"},
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiants incorrects.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Ce compte est désactivé.")

    merchant_id = _first_active_merchant_id(db, user.id)
    session = new_user_session(user.id)
    tokens = _new_token_pair(db, user, session, merchant_id)
    record_audit(
        db,
        request,
        "auth.login",
        actor_user_id=user.id,
        merchant_id=merchant_id,
        target_type="user",
        target_id=user.id,
    )
    db.commit()
    return tokens


@router.post("/refresh", response_model=TokenResponse, summary="Renouveler les jetons")
def refresh_tokens(
    payload: RefreshRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> TokenResponse:
    try:
        claims = decode_access_token(payload.refresh_token)
        if claims.get("typ") != "refresh":
            raise unauthorized()
        user_id = UUID(claims["sub"])
        session_id = UUID(claims["sid"])
        merchant_id = UUID(claims["mid"]) if claims.get("mid") else None
    except (jwt.InvalidTokenError, KeyError, TypeError, ValueError):
        raise unauthorized() from None

    session = db.scalar(
        select(UserSession)
        .where(UserSession.id == session_id, UserSession.user_id == user_id)
        .with_for_update()
    )
    user = db.get(User, user_id)
    now = datetime.now(UTC)
    if (
        session is None
        or user is None
        or not user.is_active
        or session.revoked_at is not None
        or session.expires_at <= now
    ):
        raise unauthorized()

    if session.refresh_token_hash != hash_refresh_token(payload.refresh_token):
        session.revoked_at = now
        db.add(
            AuditLog(
                actor_user_id=user.id,
                action="auth.refresh_reuse_detected",
                target_type="user_session",
                target_id=session.id,
                ip_address=request.client.host if request.client else None,
                user_agent=request.headers.get("user-agent", "")[:500] or None,
            )
        )
        db.commit()
        raise unauthorized()

    if merchant_id is not None:
        membership_exists = db.scalar(
            select(MerchantMembership.id)
            .join(Merchant, Merchant.id == MerchantMembership.merchant_id)
            .where(
                MerchantMembership.user_id == user.id,
                MerchantMembership.merchant_id == merchant_id,
                MerchantMembership.is_active.is_(True),
                Merchant.is_active.is_(True),
            )
        )
        if membership_exists is None:
            merchant_id = None

    tokens = _new_token_pair(db, user, session, merchant_id)
    record_audit(
        db,
        request,
        "auth.refresh",
        actor_user_id=user.id,
        merchant_id=merchant_id,
        target_type="user_session",
        target_id=session.id,
    )
    db.commit()
    return tokens


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT, summary="Fermer la session")
def logout(
    request: Request,
    context: AuthContext = Depends(get_current_context),
    db: Session = Depends(get_db),
) -> Response:
    context.session.revoked_at = datetime.now(UTC)
    record_audit(
        db,
        request,
        "auth.logout",
        actor_user_id=context.user.id,
        merchant_id=context.merchant.id if context.merchant else None,
        target_type="user_session",
        target_id=context.session.id,
    )
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=UserRead, summary="Afficher le compte connecté")
def read_current_user(
    context: AuthContext = Depends(get_current_context),
) -> UserRead:
    return UserRead.model_validate(context.user)
