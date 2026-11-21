from uuid import UUID

from fastapi import Request
from sqlalchemy.orm import Session

from app.models import AuditLog


def record_audit(
    db: Session,
    request: Request,
    action: str,
    *,
    actor_user_id: UUID | None = None,
    merchant_id: UUID | None = None,
    target_type: str | None = None,
    target_id: UUID | None = None,
    details: dict[str, object] | None = None,
) -> None:
    """Ajoute une trace sans données sensibles dans la transaction courante."""
    db.add(
        AuditLog(
            actor_user_id=actor_user_id,
            merchant_id=merchant_id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            ip_address=request.client.host if request.client else None,
            user_agent=request.headers.get("user-agent", "")[:500] or None,
            details=details,
        )
    )
