from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.api.deps import AuthContext, require_path_merchant, require_path_merchant_roles
from app.db.session import get_db
from app.models import Client, CreditEntryType, CreditLedgerEntry, MembershipRole, RecordStatus
from app.schemas.sales import ClientCreate, ClientRead, ClientUpdate
from app.services.audit import record_audit

router = APIRouter()
CLIENT_EDITORS = (MembershipRole.OWNER, MembershipRole.MANAGER, MembershipRole.CASHIER)


def _balance_expression():
    signed_amount = case(
        (CreditLedgerEntry.entry_type == CreditEntryType.REPAYMENT, -CreditLedgerEntry.amount),
        else_=CreditLedgerEntry.amount,
    )
    return (
        select(func.coalesce(func.sum(signed_amount), 0))
        .where(
            CreditLedgerEntry.client_id == Client.id,
            CreditLedgerEntry.merchant_id == Client.merchant_id,
        )
        .correlate(Client)
        .scalar_subquery()
    )


def _client_read(client: Client, balance: int) -> ClientRead:
    return ClientRead(
        id=client.id,
        merchant_id=client.merchant_id,
        full_name=client.full_name,
        phone=client.phone,
        address=client.address,
        notes=client.notes,
        status=client.status.value,
        credit_balance=max(0, balance),
        created_at=client.created_at,
    )


@router.get("", response_model=list[ClientRead])
def list_clients(
    merchant_id: UUID,
    q: str | None = Query(default=None, max_length=160),
    credit_status: str = Query(default="all", pattern="^(all|open|settled)$"),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=200),
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> list[ClientRead]:
    balance = _balance_expression()
    query = select(Client, balance).where(
        Client.merchant_id == merchant_id,
        Client.status == RecordStatus.ACTIVE,
    )
    if q and q.strip():
        pattern = f"%{q.strip()}%"
        query = query.where(
            Client.full_name.ilike(pattern) | Client.phone.ilike(pattern)
        )
    if credit_status == "open":
        query = query.where(balance > 0)
    elif credit_status == "settled":
        query = query.where(balance <= 0)
    rows = db.execute(
        query.order_by(Client.full_name).offset(offset).limit(limit)
    ).all()
    return [_client_read(client, amount) for client, amount in rows]


@router.post("", response_model=ClientRead, status_code=status.HTTP_201_CREATED)
def create_client(
    merchant_id: UUID,
    payload: ClientCreate,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*CLIENT_EDITORS)),
    db: Session = Depends(get_db),
) -> ClientRead:
    client = Client(
        merchant_id=merchant_id,
        full_name=" ".join(payload.full_name.split()),
        phone=payload.phone.strip() if payload.phone else None,
        address=payload.address.strip() if payload.address else None,
        notes=payload.notes.strip() if payload.notes else None,
    )
    db.add(client)
    db.flush()
    record_audit(db, request, "client.created", actor_user_id=context.user.id,
                 merchant_id=merchant_id, target_type="client", target_id=client.id)
    db.commit()
    db.refresh(client)
    return _client_read(client, 0)


@router.get("/{client_id}", response_model=ClientRead)
def read_client(
    merchant_id: UUID,
    client_id: UUID,
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> ClientRead:
    row = db.execute(select(Client, _balance_expression()).where(
        Client.id == client_id,
        Client.merchant_id == merchant_id,
        Client.status == RecordStatus.ACTIVE,
    )).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Client introuvable.")
    client, balance = row
    return _client_read(client, balance)


@router.patch("/{client_id}", response_model=ClientRead)
def update_client(
    merchant_id: UUID,
    client_id: UUID,
    payload: ClientUpdate,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*CLIENT_EDITORS)),
    db: Session = Depends(get_db),
) -> ClientRead:
    client = db.scalar(select(Client).where(
        Client.id == client_id,
        Client.merchant_id == merchant_id,
        Client.status == RecordStatus.ACTIVE,
    ))
    if client is None:
        raise HTTPException(status_code=404, detail="Client introuvable.")
    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        if isinstance(value, str):
            value = value.strip()
        setattr(client, field, value)
    record_audit(db, request, "client.updated", actor_user_id=context.user.id,
                 merchant_id=merchant_id, target_type="client", target_id=client.id)
    db.commit()
    db.refresh(client)
    balance = db.scalar(select(_balance_expression()).where(Client.id == client.id)) or 0
    return _client_read(client, balance)


@router.delete("/{client_id}", status_code=status.HTTP_204_NO_CONTENT)
def archive_client(
    merchant_id: UUID,
    client_id: UUID,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*CLIENT_EDITORS)),
    db: Session = Depends(get_db),
) -> None:
    client = db.scalar(select(Client).where(
        Client.id == client_id,
        Client.merchant_id == merchant_id,
        Client.status == RecordStatus.ACTIVE,
    ))
    if client is None:
        raise HTTPException(status_code=404, detail="Client introuvable.")
    balance = db.scalar(select(_balance_expression()).where(Client.id == client.id)) or 0
    if balance > 0:
        raise HTTPException(status_code=409, detail="Impossible d’archiver un client avec un crédit restant.")
    client.status = RecordStatus.ARCHIVED
    record_audit(db, request, "client.archived", actor_user_id=context.user.id,
                 merchant_id=merchant_id, target_type="client", target_id=client.id)
    db.commit()
