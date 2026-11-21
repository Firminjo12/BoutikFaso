import json
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, status
from sqlalchemy import case, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import AuthContext, require_path_merchant, require_path_merchant_roles
from app.db.session import get_db
from app.models import (
    Client,
    CreditEntryType,
    CreditLedgerEntry,
    MembershipRole,
    RecordStatus,
    SyncOperation,
)
from app.schemas.sales import ClientRead, CreditLedgerRead, RepaymentCreate
from app.services.audit import record_audit

router = APIRouter()
REPAYMENT_CREATORS = (MembershipRole.OWNER, MembershipRole.MANAGER, MembershipRole.CASHIER)


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


def _ledger_read(entry: CreditLedgerEntry) -> CreditLedgerRead:
    return CreditLedgerRead(
        id=entry.id,
        client_id=entry.client_id,
        sale_id=entry.sale_id,
        entry_type=entry.entry_type.value,
        amount=entry.amount,
        payment_method=entry.payment_method.value if entry.payment_method else None,
        note=entry.note,
        occurred_at=entry.occurred_at,
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


def _replay_repayment(
    db: Session,
    operation: SyncOperation,
    *,
    client_id: UUID,
    payload: RepaymentCreate,
) -> CreditLedgerRead:
    if operation.operation_type != "credit.repayment" or not operation.response_payload:
        raise HTTPException(status_code=409, detail="Cette clé d’idempotence a déjà été utilisée.")
    try:
        stored = json.loads(operation.response_payload)
        entry_id = UUID(stored["entry_id"])
    except (ValueError, KeyError, TypeError):
        raise HTTPException(status_code=409, detail="La réponse de cette opération est indisponible.") from None
    if (
        stored.get("client_id") != str(client_id)
        or stored.get("amount") != payload.amount
        or stored.get("payment_method") != payload.payment_method
        or stored.get("note") != (payload.note.strip() if payload.note else None)
    ):
        raise HTTPException(status_code=409, detail="Cette clé d’idempotence a déjà servi pour un autre remboursement.")
    entry = db.get(CreditLedgerEntry, entry_id)
    if entry is None or entry.merchant_id != operation.merchant_id or entry.client_id != client_id:
        raise HTTPException(status_code=409, detail="Le remboursement associé est introuvable.")
    return _ledger_read(entry)


@router.get("/credits", response_model=list[ClientRead])
def list_open_credits(
    merchant_id: UUID,
    q: str | None = Query(default=None, max_length=160),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=200),
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> list[ClientRead]:
    balance = _balance_expression()
    query = select(Client, balance).where(
        Client.merchant_id == merchant_id,
        Client.status == RecordStatus.ACTIVE,
        balance > 0,
    )
    if q and q.strip():
        pattern = f"%{q.strip()}%"
        query = query.where(Client.full_name.ilike(pattern) | Client.phone.ilike(pattern))
    rows = db.execute(query.order_by(balance.desc(), Client.full_name)
                      .offset(offset).limit(limit)).all()
    return [_client_read(client, amount) for client, amount in rows]


@router.get("/clients/{client_id}/credit-ledger", response_model=list[CreditLedgerRead])
def list_credit_ledger(
    merchant_id: UUID,
    client_id: UUID,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=200),
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> list[CreditLedgerRead]:
    client = db.scalar(select(Client.id).where(
        Client.id == client_id,
        Client.merchant_id == merchant_id,
        Client.status == RecordStatus.ACTIVE,
    ))
    if client is None:
        raise HTTPException(status_code=404, detail="Client introuvable.")
    rows = db.scalars(
        select(CreditLedgerEntry)
        .where(
            CreditLedgerEntry.client_id == client_id,
            CreditLedgerEntry.merchant_id == merchant_id,
        )
        .order_by(CreditLedgerEntry.occurred_at.desc())
        .offset(offset)
        .limit(limit)
    ).all()
    return [_ledger_read(entry) for entry in rows]


@router.post(
    "/clients/{client_id}/repayments",
    response_model=CreditLedgerRead,
    status_code=status.HTTP_201_CREATED,
)
def register_repayment(
    merchant_id: UUID,
    client_id: UUID,
    payload: RepaymentCreate,
    request: Request,
    idempotency_key: str = Header(alias="Idempotency-Key", min_length=8, max_length=128),
    device_id: str = Header(default="default-device", alias="X-Device-ID", max_length=128),
    context: AuthContext = Depends(require_path_merchant_roles(*REPAYMENT_CREATORS)),
    db: Session = Depends(get_db),
) -> CreditLedgerRead:
    operation = db.scalar(select(SyncOperation).where(
        SyncOperation.merchant_id == merchant_id,
        SyncOperation.device_id == device_id,
        SyncOperation.idempotency_key == idempotency_key,
    ))
    if operation:
        return _replay_repayment(db, operation, client_id=client_id, payload=payload)

    client = db.scalar(select(Client).where(
        Client.id == client_id,
        Client.merchant_id == merchant_id,
        Client.status == RecordStatus.ACTIVE,
    ).with_for_update())
    if client is None:
        raise HTTPException(status_code=404, detail="Client introuvable.")
    # Une requête identique a pu se terminer pendant l’attente du verrou client.
    operation = db.scalar(select(SyncOperation).where(
        SyncOperation.merchant_id == merchant_id,
        SyncOperation.device_id == device_id,
        SyncOperation.idempotency_key == idempotency_key,
    ))
    if operation:
        return _replay_repayment(db, operation, client_id=client_id, payload=payload)
    balance = db.scalar(select(_balance_expression()).where(Client.id == client_id)) or 0
    if payload.amount > balance:
        raise HTTPException(
            status_code=409,
            detail=f"Le remboursement dépasse le solde dû ({balance} FCFA).",
        )

    entry_id = uuid4()
    entry = CreditLedgerEntry(
        id=entry_id,
        merchant_id=merchant_id,
        client_id=client_id,
        sale_id=None,
        created_by_user_id=context.user.id,
        entry_type=CreditEntryType.REPAYMENT,
        amount=payload.amount,
        payment_method=payload.payment_method,
        note=payload.note.strip() if payload.note else None,
    )
    operation = SyncOperation(
        merchant_id=merchant_id,
        user_id=context.user.id,
        device_id=device_id,
        idempotency_key=idempotency_key,
        operation_type="credit.repayment",
        response_payload=json.dumps({
            "entry_id": str(entry_id),
            "client_id": str(client_id),
            "amount": payload.amount,
            "payment_method": payload.payment_method,
            "note": payload.note.strip() if payload.note else None,
        }),
    )
    db.add_all((entry, operation))
    record_audit(
        db,
        request,
        "credit.repayment_recorded",
        actor_user_id=context.user.id,
        merchant_id=merchant_id,
        target_type="credit_ledger_entry",
        target_id=entry.id,
        details={"client_id": str(client_id), "amount": payload.amount},
    )
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        operation = db.scalar(select(SyncOperation).where(
            SyncOperation.merchant_id == merchant_id,
            SyncOperation.device_id == device_id,
            SyncOperation.idempotency_key == idempotency_key,
        ))
        if operation:
            return _replay_repayment(db, operation, client_id=client_id, payload=payload)
        raise HTTPException(status_code=409, detail="Le remboursement n’a pas pu être enregistré.") from None
    db.refresh(entry)
    return _ledger_read(entry)
