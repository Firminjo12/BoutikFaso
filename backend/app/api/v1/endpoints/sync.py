from uuid import UUID

from fastapi import APIRouter, Depends, Header, Query, Request, status
from sqlalchemy.orm import Session

from app.api.deps import AuthContext, require_active_merchant, require_path_merchant
from app.db.session import get_db
from app.schemas.sync import (
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
    SyncStatusResponse,
)
from app.services.sync import (
    get_sync_status,
    process_sync_pull,
    process_sync_push,
)

router = APIRouter()
direct_router = APIRouter()


# --- Tenant-scoped routes (/merchants/{merchant_id}/sync) ---

@router.post("/push", response_model=SyncPushResponse, status_code=status.HTTP_200_OK)
def sync_push(
    merchant_id: UUID,
    payload: SyncPushRequest,
    request: Request,
    context: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> SyncPushResponse:
    """Envoie un lot d'opérations effectuées hors ligne (ventes, remboursements, dépenses, clients, stock)."""
    return process_sync_push(db, context, merchant_id, payload, request)


@router.get("/pull", response_model=SyncPullResponse)
def sync_pull(
    merchant_id: UUID,
    cursor: str | None = Query(default=None, description="Curseur ISO 8601 de reprise"),
    limit: int = Query(default=200, ge=1, le=500),
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> SyncPullResponse:
    """Récupère les modifications incrémentales depuis le curseur fourni."""
    return process_sync_pull(db, merchant_id, cursor, limit)


@router.get("/status", response_model=SyncStatusResponse)
def sync_status(
    merchant_id: UUID,
    device_id: str | None = Query(default=None),
    x_device_id: str | None = Header(default=None, alias="X-Device-ID"),
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> SyncStatusResponse:
    """Consulte l'état de synchronisation de la boutique et de l'appareil."""
    effective_device = device_id or x_device_id
    return get_sync_status(db, merchant_id, effective_device)


# --- Active merchant direct routes (/sync) ---

@direct_router.post("/push", response_model=SyncPushResponse, status_code=status.HTTP_200_OK)
def sync_push_active(
    payload: SyncPushRequest,
    request: Request,
    context: AuthContext = Depends(require_active_merchant),
    db: Session = Depends(get_db),
) -> SyncPushResponse:
    """Envoie un lot d'opérations hors ligne pour la boutique active de la session."""
    assert context.merchant is not None
    return process_sync_push(db, context, context.merchant.id, payload, request)


@direct_router.get("/pull", response_model=SyncPullResponse)
def sync_pull_active(
    cursor: str | None = Query(default=None, description="Curseur ISO 8601 de reprise"),
    limit: int = Query(default=200, ge=1, le=500),
    context: AuthContext = Depends(require_active_merchant),
    db: Session = Depends(get_db),
) -> SyncPullResponse:
    """Récupère les modifications incrémentales pour la boutique active de la session."""
    assert context.merchant is not None
    return process_sync_pull(db, context.merchant.id, cursor, limit)


@direct_router.get("/status", response_model=SyncStatusResponse)
def sync_status_active(
    device_id: str | None = Query(default=None),
    x_device_id: str | None = Header(default=None, alias="X-Device-ID"),
    context: AuthContext = Depends(require_active_merchant),
    db: Session = Depends(get_db),
) -> SyncStatusResponse:
    """Consulte l'état de synchronisation pour la boutique active de la session."""
    assert context.merchant is not None
    effective_device = device_id or x_device_id
    return get_sync_status(db, context.merchant.id, effective_device)
