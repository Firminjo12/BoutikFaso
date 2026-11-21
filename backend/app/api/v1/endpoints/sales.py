from datetime import UTC, datetime
from decimal import Decimal, ROUND_HALF_UP
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
    PaymentMethod,
    Product,
    RecordStatus,
    Sale,
    SaleLine,
    SaleStatus,
    StockMovement,
    StockMovementType,
)
from app.schemas.sales import SaleCreate, SaleLineRead, SaleRead
from app.services.audit import record_audit

router = APIRouter()
SALE_CREATORS = (MembershipRole.OWNER, MembershipRole.MANAGER, MembershipRole.CASHIER)


def _stock_balance(product_id: UUID, merchant_id: UUID):
    quantity = case(
        (
            StockMovement.movement_type.in_(
                (StockMovementType.ENTRY, StockMovementType.REVERSAL)
            ),
            StockMovement.quantity,
        ),
        else_=-StockMovement.quantity,
    )
    return select(func.coalesce(func.sum(quantity), 0)).where(
        StockMovement.product_id == product_id,
        StockMovement.merchant_id == merchant_id,
    ).scalar_subquery()


def _sale_read(db: Session, sale: Sale) -> SaleRead:
    client_name = None
    if sale.client_id:
        client_name = db.scalar(select(Client.full_name).where(
            Client.id == sale.client_id,
            Client.merchant_id == sale.merchant_id,
        ))
    lines = db.scalars(
        select(SaleLine).where(
            SaleLine.sale_id == sale.id,
            SaleLine.merchant_id == sale.merchant_id,
        ).order_by(SaleLine.id)
    ).all()
    credit_created = db.scalar(
        select(CreditLedgerEntry.amount).where(
            CreditLedgerEntry.sale_id == sale.id,
            CreditLedgerEntry.merchant_id == sale.merchant_id,
            CreditLedgerEntry.entry_type == CreditEntryType.CREDIT_SALE,
        )
    ) or 0
    return SaleRead(
        id=sale.id,
        receipt_number=sale.receipt_number,
        client_id=sale.client_id,
        client_name=client_name,
        status=sale.status.value,
        payment_method=sale.payment_method.value,
        subtotal=sale.subtotal,
        discount_amount=sale.discount_amount,
        total_amount=sale.total_amount,
        paid_amount=sale.total_amount - credit_created,
        credit_created=credit_created,
        sold_at=sale.sold_at,
        lines=[
            SaleLineRead(
                product_id=line.product_id,
                product_name=line.product_name,
                quantity=line.quantity,
                unit_sale_price=line.unit_sale_price,
                unit_purchase_price=line.unit_purchase_price,
                line_total=line.line_total,
            )
            for line in lines
        ],
    )


def _request_matches_sale(db: Session, sale: Sale, payload: SaleCreate) -> bool:
    if (
        sale.client_id != payload.client_id
        or sale.payment_method != PaymentMethod(payload.payment_method)
        or sale.discount_amount != payload.discount_amount
    ):
        return False
    stored = db.scalars(select(SaleLine).where(SaleLine.sale_id == sale.id)).all()
    stored_items = {line.product_id: line.quantity for line in stored}
    submitted_items: dict[UUID, Decimal] = {}
    for line in payload.lines:
        submitted_items[line.product_id] = submitted_items.get(line.product_id, Decimal(0)) + line.quantity
    if stored_items != submitted_items:
        return False
    credit_created = db.scalar(select(CreditLedgerEntry.amount).where(
        CreditLedgerEntry.sale_id == sale.id,
        CreditLedgerEntry.entry_type == CreditEntryType.CREDIT_SALE,
    )) or 0
    expected_paid = payload.paid_amount
    if expected_paid is None:
        expected_paid = 0 if payload.payment_method == "credit" else sale.total_amount
    return sale.total_amount - credit_created == expected_paid


@router.post("", response_model=SaleRead, status_code=status.HTTP_201_CREATED)
def create_sale(
    merchant_id: UUID,
    payload: SaleCreate,
    request: Request,
    idempotency_key: str = Header(alias="Idempotency-Key", min_length=8, max_length=128),
    context: AuthContext = Depends(require_path_merchant_roles(*SALE_CREATORS)),
    db: Session = Depends(get_db),
) -> SaleRead:
    existing = db.scalar(select(Sale).where(
        Sale.merchant_id == merchant_id,
        Sale.idempotency_key == idempotency_key,
    ))
    if existing:
        if not _request_matches_sale(db, existing, payload):
            raise HTTPException(status_code=409, detail="Cette clé d’idempotence a déjà servi pour une autre vente.")
        return _sale_read(db, existing)

    quantities: dict[UUID, Decimal] = {}
    for line in payload.lines:
        quantities[line.product_id] = quantities.get(line.product_id, Decimal(0)) + line.quantity
    product_rows = db.scalars(
        select(Product)
        .where(
            Product.id.in_(sorted(quantities, key=str)),
            Product.merchant_id == merchant_id,
            Product.status == RecordStatus.ACTIVE,
        )
        .order_by(Product.id)
        .with_for_update()
    ).all()
    products = {product.id: product for product in product_rows}
    if len(products) != len(quantities):
        raise HTTPException(status_code=404, detail="Un produit de la vente est introuvable.")

    # Une requête concurrente avec la même clé peut avoir terminé pendant le verrouillage.
    existing = db.scalar(select(Sale).where(
        Sale.merchant_id == merchant_id,
        Sale.idempotency_key == idempotency_key,
    ))
    if existing:
        if not _request_matches_sale(db, existing, payload):
            raise HTTPException(status_code=409, detail="Cette clé d’idempotence a déjà servi pour une autre vente.")
        return _sale_read(db, existing)

    line_values: list[tuple[Product, Decimal, int]] = []
    subtotal = 0
    for product_id in sorted(quantities, key=str):
        product = products[product_id]
        quantity = quantities[product_id]
        available = db.scalar(select(_stock_balance(product.id, merchant_id))) or 0
        if quantity > available:
            raise HTTPException(
                status_code=409,
                detail=f"Stock insuffisant pour « {product.name} » : {available} disponible(s).",
            )
        line_total = int(
            (Decimal(product.sale_price) * quantity).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
        )
        subtotal += line_total
        line_values.append((product, quantity, line_total))

    if payload.discount_amount > subtotal:
        raise HTTPException(status_code=422, detail="La remise dépasse le sous-total.")
    total = subtotal - payload.discount_amount
    paid = payload.paid_amount
    if paid is None:
        paid = 0 if payload.payment_method == "credit" else total
    if paid > total:
        raise HTTPException(status_code=422, detail="Le montant payé dépasse le total de la vente.")
    if total > 0 and paid == 0 and payload.payment_method != "credit":
        raise HTTPException(status_code=422, detail="Choisissez le mode crédit pour une vente non payée.")
    credit_created = total - paid
    if credit_created > 0 and payload.client_id is None:
        raise HTTPException(status_code=422, detail="Un client est nécessaire pour enregistrer le reste à crédit.")
    if payload.payment_method == "credit" and payload.client_id is None:
        raise HTTPException(status_code=422, detail="Une vente à crédit nécessite un client.")

    client = None
    if payload.client_id:
        client = db.scalar(select(Client).where(
            Client.id == payload.client_id,
            Client.merchant_id == merchant_id,
            Client.status == RecordStatus.ACTIVE,
        ).with_for_update())
        if client is None:
            raise HTTPException(status_code=404, detail="Client introuvable.")

    now = datetime.now(UTC)
    sale_id = uuid4()
    sale = Sale(
        id=sale_id,
        merchant_id=merchant_id,
        client_id=client.id if client else None,
        created_by_user_id=context.user.id,
        receipt_number=f"BF-{now:%Y%m%d}-{sale_id.hex[:8].upper()}",
        status=SaleStatus.COMPLETED,
        payment_method=PaymentMethod(payload.payment_method),
        subtotal=subtotal,
        discount_amount=payload.discount_amount,
        total_amount=total,
        idempotency_key=idempotency_key,
    )
    db.add(sale)
    for product, quantity, line_total in line_values:
        db.add(SaleLine(
            merchant_id=merchant_id,
            sale_id=sale.id,
            product_id=product.id,
            product_name=product.name,
            quantity=quantity,
            unit_sale_price=product.sale_price,
            unit_purchase_price=product.purchase_price,
            line_total=line_total,
        ))
        db.add(StockMovement(
            merchant_id=merchant_id,
            product_id=product.id,
            created_by_user_id=context.user.id,
            sale_id=sale.id,
            movement_type=StockMovementType.SALE,
            quantity=quantity,
            note=f"Vente {sale.receipt_number}",
        ))
    if credit_created > 0 and client:
        db.add(CreditLedgerEntry(
            merchant_id=merchant_id,
            client_id=client.id,
            sale_id=sale.id,
            created_by_user_id=context.user.id,
            entry_type=CreditEntryType.CREDIT_SALE,
            amount=credit_created,
            payment_method=None,
            note=f"Vente {sale.receipt_number}",
        ))
    record_audit(
        db,
        request,
        "sale.created",
        actor_user_id=context.user.id,
        merchant_id=merchant_id,
        target_type="sale",
        target_id=sale.id,
        details={"receipt_number": sale.receipt_number, "total": total, "credit": credit_created},
    )
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        existing = db.scalar(select(Sale).where(
            Sale.merchant_id == merchant_id,
            Sale.idempotency_key == idempotency_key,
        ))
        if existing and _request_matches_sale(db, existing, payload):
            return _sale_read(db, existing)
        if existing:
            raise HTTPException(status_code=409, detail="Cette clé d’idempotence a déjà servi pour une autre vente.") from None
        raise HTTPException(status_code=409, detail="La vente n’a pas pu être enregistrée. Vérifiez les données et réessayez.") from None
    db.refresh(sale)
    return _sale_read(db, sale)


@router.get("", response_model=list[SaleRead])
def list_sales(
    merchant_id: UUID,
    client_id: UUID | None = None,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=200),
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> list[SaleRead]:
    query = select(Sale).where(Sale.merchant_id == merchant_id)
    if client_id:
        query = query.where(Sale.client_id == client_id)
    sales = db.scalars(query.order_by(Sale.sold_at.desc()).offset(offset).limit(limit)).all()
    return [_sale_read(db, sale) for sale in sales]


@router.get("/{sale_id}", response_model=SaleRead)
def read_sale(
    merchant_id: UUID,
    sale_id: UUID,
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> SaleRead:
    sale = db.scalar(select(Sale).where(Sale.id == sale_id, Sale.merchant_id == merchant_id))
    if sale is None:
        raise HTTPException(status_code=404, detail="Vente introuvable.")
    return _sale_read(db, sale)


@router.get("/{sale_id}/receipt", response_model=SaleRead)
def read_receipt(
    merchant_id: UUID,
    sale_id: UUID,
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> SaleRead:
    return read_sale(merchant_id, sale_id, _, db)
