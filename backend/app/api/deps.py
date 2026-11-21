from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, Path, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.session import get_db
from app.models import Merchant, MerchantMembership, MembershipRole, User, UserSession

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


@dataclass(frozen=True)
class AuthContext:
    user: User
    session: UserSession
    merchant: Merchant | None = None
    membership: MerchantMembership | None = None


def unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Session invalide ou expirée.",
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_context(
    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)
) -> AuthContext:
    try:
        claims = decode_access_token(token)
        if claims.get("typ") != "access":
            raise unauthorized()
        user_id = UUID(claims["sub"])
        session_id = UUID(claims["sid"])
        merchant_id = UUID(claims["mid"]) if claims.get("mid") else None
    except (jwt.InvalidTokenError, KeyError, TypeError, ValueError):
        raise unauthorized() from None

    now = datetime.now(UTC)
    session = db.scalar(
        select(UserSession).where(
            UserSession.id == session_id,
            UserSession.user_id == user_id,
            UserSession.revoked_at.is_(None),
            UserSession.expires_at > now,
        )
    )
    user = db.get(User, user_id)
    if session is None or user is None or not user.is_active:
        raise unauthorized()

    if merchant_id is None:
        return AuthContext(user=user, session=session)

    membership = db.scalar(
        select(MerchantMembership).where(
            MerchantMembership.user_id == user_id,
            MerchantMembership.merchant_id == merchant_id,
            MerchantMembership.is_active.is_(True),
        )
    )
    merchant = db.get(Merchant, merchant_id)
    if membership is None or merchant is None or not merchant.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Accès à cette boutique refusé.",
        )
    return AuthContext(user=user, session=session, merchant=merchant, membership=membership)


def require_active_merchant(context: AuthContext = Depends(get_current_context)) -> AuthContext:
    if context.merchant is None or context.membership is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Sélectionnez d’abord une boutique active.",
        )
    return context


def require_roles(*roles: MembershipRole):
    def dependency(context: AuthContext = Depends(require_active_merchant)) -> AuthContext:
        if context.membership is None or context.membership.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Votre rôle ne permet pas cette opération.",
            )
        return context

    return dependency


def require_path_merchant(
    merchant_id: UUID = Path(),
    context: AuthContext = Depends(require_active_merchant),
) -> AuthContext:
    """Require the URL tenant to match the tenant selected in the signed token."""
    if context.merchant is None or context.merchant.id != merchant_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Boutique introuvable.",
        )
    return context


def require_path_merchant_roles(*roles: MembershipRole):
    def dependency(
        context: AuthContext = Depends(require_path_merchant),
    ) -> AuthContext:
        if context.membership is None or context.membership.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Votre rôle ne permet pas cette opération.",
            )
        return context

    return dependency
