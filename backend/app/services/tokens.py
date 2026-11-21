import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import create_access_token, create_refresh_token
from app.models import User, UserSession
from app.schemas.auth import TokenResponse


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_session_tokens(
    db: Session,
    user: User,
    session: UserSession,
    merchant_id: UUID | None,
) -> TokenResponse:
    settings = get_settings()
    now = datetime.now(UTC)
    merchant_claim = str(merchant_id) if merchant_id else None
    access_claims: dict[str, object] = {"sid": str(session.id)}
    if merchant_claim:
        access_claims["mid"] = merchant_claim
    access_token = create_access_token(str(user.id), additional_claims=access_claims)
    refresh_token, refresh_expires_at = create_refresh_token(
        str(user.id), str(session.id), merchant_claim
    )
    session.refresh_token_hash = hash_refresh_token(refresh_token)
    session.expires_at = refresh_expires_at
    db.add(session)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.jwt_access_token_minutes * 60,
        active_merchant_id=merchant_id,
    )


def new_user_session(user_id: UUID) -> UserSession:
    settings = get_settings()
    return UserSession(
        id=uuid4(),
        user_id=user_id,
        refresh_token_hash=secrets.token_hex(32),
        expires_at=datetime.now(UTC) + timedelta(days=settings.jwt_refresh_token_days),
    )
