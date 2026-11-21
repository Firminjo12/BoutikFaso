import json
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Any
from uuid import UUID, uuid4

from fastapi import HTTPException, Request
from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.api.deps import AuthContext
from app.models import (
    Category,
    Client,
    CreditEntryType,
    CreditLedgerEntry,
    Expense,
    PaymentMethod,
    Product,
    RecordStatus,
    Sale,
    SaleLine,
    SaleStatus,
    StockMovement,
    StockMovementType,
    SyncOperation,
)
from app.schemas.catalog import (
    CategoryCreate,
    ProductCreate,
    ProductUpdate,
    StockMovementCreate,
)
from app.schemas.finance import ExpenseCreate
from app.schemas.sales import (
    ClientCreate,
    ClientUpdate,
    RepaymentCreate,
    SaleCreate,
)
from app.schemas.sync import (
    SyncOperationItem,
    SyncOperationResult,
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
    SyncStatusResponse,
)
from app.services.audit import record_audit


class SyncConflictError(Exception):
    def __init__(self, message: str, details: dict[str, Any] | None = None):
        super().__init__(message)
        self.message = message
        self.details = details or {}


class SyncRejectedError(Exception):
    def __init__(self, message: str):
        super().__init__(message)
        self.message = message


def _product_stock_balance(db: Session, merchant_id: UUID, product_id: UUID) -> Decimal:
    quantity_expr = case(
        (
            StockMovement.movement_type.in_(
                (StockMovementType.ENTRY, StockMovementType.REVERSAL)
            ),
            StockMovement.quantity,
        ),
        else_=-StockMovement.quantity,
    )
    result = db.scalar(
        select(func.coalesce(func.sum(quantity_expr), Decimal(0))).where(
            StockMovement.product_id == product_id,
            StockMovement.merchant_id == merchant_id,
        )
    )
    return Decimal(result or 0)


def _client_credit_balance(db: Session, merchant_id: UUID, client_id: UUID) -> int:
    signed_amount = case(
        (CreditLedgerEntry.entry_type == CreditEntryType.REPAYMENT, -CreditLedgerEntry.amount),
        else_=CreditLedgerEntry.amount,
    )
    result = db.scalar(
        select(func.coalesce(func.sum(signed_amount), 0)).where(
            CreditLedgerEntry.client_id == client_id,
            CreditLedgerEntry.merchant_id == merchant_id,
        )
    )
    return int(result or 0)


def _apply_sale_create(
    db: Session,
    context: AuthContext,
    merchant_id: UUID,
    op: SyncOperationItem,
) -> tuple[UUID, dict[str, Any]]:
    payload = SaleCreate.model_validate(op.payload)
    occurred_at = op.occurred_at.astimezone(UTC) if op.occurred_at else datetime.now(UTC)

    # 1. Verification des produits
    quantities: dict[UUID, Decimal] = {}
    for line in payload.lines:
        quantities[line.product_id] = quantities.get(line.product_id, Decimal(0)) + line.quantity

    products = {
        p.id: p
        for p in db.scalars(
            select(Product)
            .where(
                Product.id.in_(sorted(quantities, key=str)),
                Product.merchant_id == merchant_id,
                Product.status == RecordStatus.ACTIVE,
            )
            .with_for_update()
        ).all()
    }
    if len(products) != len(quantities):
        raise SyncRejectedError("Un ou plusieurs produits de la vente sont introuvables ou archivés.")

    subtotal = 0
    line_values: list[tuple[Product, Decimal, int]] = []
    for line in payload.lines:
        product = products[line.product_id]
        line_total = int(product.sale_price * line.quantity)
        subtotal += line_total
        line_values.append((product, line.quantity, line_total))

    if payload.discount_amount > subtotal:
        raise SyncRejectedError("La remise dépasse le sous-total de la vente.")
    total = subtotal - payload.discount_amount

    paid = payload.paid_amount
    if paid is None:
        paid = 0 if payload.payment_method == "credit" else total
    if paid > total:
        raise SyncRejectedError("Le montant payé dépasse le total de la vente.")
    if total > 0 and paid == 0 and payload.payment_method != "credit":
        raise SyncRejectedError("Une vente non payée exige le mode de paiement crédit.")

    credit_created = total - paid
    client = None
    if payload.client_id:
        client = db.scalar(
            select(Client).where(
                Client.id == payload.client_id,
                Client.merchant_id == merchant_id,
                Client.status == RecordStatus.ACTIVE,
            ).with_for_update()
        )
        if client is None:
            raise SyncRejectedError("Client introuvable ou archivé.")
    elif credit_created > 0:
        raise SyncRejectedError("Un client est obligatoire pour une vente avec reste à crédit.")

    sale_id = op.operation_id or uuid4()
    receipt_number = f"BF-{occurred_at:%Y%m%d}-{sale_id.hex[:8].upper()}"

    sale = Sale(
        id=sale_id,
        merchant_id=merchant_id,
        client_id=client.id if client else None,
        created_by_user_id=context.user.id,
        receipt_number=receipt_number,
        status=SaleStatus.COMPLETED,
        payment_method=PaymentMethod(payload.payment_method),
        subtotal=subtotal,
        discount_amount=payload.discount_amount,
        total_amount=total,
        sold_at=occurred_at,
        idempotency_key=op.idempotency_key,
    )
    db.add(sale)

    for product, qty, l_total in line_values:
        db.add(
            SaleLine(
                merchant_id=merchant_id,
                sale_id=sale.id,
                product_id=product.id,
                product_name=product.name,
                quantity=qty,
                unit_sale_price=product.sale_price,
                unit_purchase_price=product.purchase_price,
                line_total=l_total,
            )
        )
        db.add(
            StockMovement(
                merchant_id=merchant_id,
                product_id=product.id,
                created_by_user_id=context.user.id,
                sale_id=sale.id,
                movement_type=StockMovementType.SALE,
                quantity=qty,
                note=f"Vente hors ligne {sale.receipt_number}",
                occurred_at=occurred_at,
            )
        )

    if credit_created > 0 and client:
        db.add(
            CreditLedgerEntry(
                merchant_id=merchant_id,
                client_id=client.id,
                sale_id=sale.id,
                created_by_user_id=context.user.id,
                entry_type=CreditEntryType.CREDIT_SALE,
                amount=credit_created,
                payment_method=None,
                note=f"Vente hors ligne {sale.receipt_number}",
                occurred_at=occurred_at,
            )
        )

    return sale.id, {
        "receipt_number": sale.receipt_number,
        "subtotal": sale.subtotal,
        "total_amount": sale.total_amount,
        "paid_amount": paid,
        "credit_created": credit_created,
    }


def _apply_credit_repayment(
    db: Session,
    context: AuthContext,
    merchant_id: UUID,
    op: SyncOperationItem,
) -> tuple[UUID, dict[str, Any]]:
    client_id_raw = op.payload.get("client_id")
    if not client_id_raw:
        raise SyncRejectedError("L'identifiant du client (client_id) est obligatoire.")
    try:
        client_id = UUID(str(client_id_raw))
    except ValueError:
        raise SyncRejectedError("Identifiant client invalide.")

    payload = RepaymentCreate.model_validate(op.payload)
    occurred_at = op.occurred_at.astimezone(UTC) if op.occurred_at else datetime.now(UTC)

    client = db.scalar(
        select(Client).where(
            Client.id == client_id,
            Client.merchant_id == merchant_id,
            Client.status == RecordStatus.ACTIVE,
        ).with_for_update()
    )
    if client is None:
        raise SyncRejectedError("Client introuvable ou archivé.")

    balance = _client_credit_balance(db, merchant_id, client_id)
    if balance <= 0:
        raise SyncConflictError(
            "Le solde dû du client est déjà à zéro FCFA (dette déjà réglée en ligne).",
            {"current_balance": 0, "attempted_repayment": payload.amount},
        )
    if payload.amount > balance:
        raise SyncConflictError(
            f"Le remboursement ({payload.amount} FCFA) dépasse le solde restant dû ({balance} FCFA).",
            {"current_balance": balance, "attempted_repayment": payload.amount},
        )

    entry_id = op.operation_id or uuid4()
    entry = CreditLedgerEntry(
        id=entry_id,
        merchant_id=merchant_id,
        client_id=client.id,
        sale_id=None,
        created_by_user_id=context.user.id,
        entry_type=CreditEntryType.REPAYMENT,
        amount=payload.amount,
        payment_method=PaymentMethod(payload.payment_method),
        note=payload.note.strip() if payload.note else None,
        occurred_at=occurred_at,
    )
    db.add(entry)

    return entry.id, {
        "client_id": str(client.id),
        "amount": entry.amount,
        "remaining_balance": balance - entry.amount,
    }


def _apply_expense_create(
    db: Session,
    context: AuthContext,
    merchant_id: UUID,
    op: SyncOperationItem,
) -> tuple[UUID, dict[str, Any]]:
    payload = ExpenseCreate.model_validate(op.payload)
    spent_at = op.occurred_at.astimezone(UTC) if op.occurred_at else (
        payload.spent_at.astimezone(UTC) if payload.spent_at else datetime.now(UTC)
    )

    expense = Expense(
        id=op.operation_id or uuid4(),
        merchant_id=merchant_id,
        created_by_user_id=context.user.id,
        label=payload.label,
        category=payload.category,
        amount=payload.amount,
        note=payload.note.strip() if payload.note and payload.note.strip() else None,
        spent_at=spent_at,
    )
    db.add(expense)
    return expense.id, {
        "label": expense.label,
        "category": expense.category,
        "amount": expense.amount,
    }


def _apply_client_create(
    db: Session,
    context: AuthContext,
    merchant_id: UUID,
    op: SyncOperationItem,
) -> tuple[UUID, dict[str, Any]]:
    payload = ClientCreate.model_validate(op.payload)
    client_id = op.operation_id or uuid4()
    client = Client(
        id=client_id,
        merchant_id=merchant_id,
        full_name=payload.full_name,
        phone=payload.phone.strip() if payload.phone else None,
        address=payload.address.strip() if payload.address else None,
        notes=payload.notes.strip() if payload.notes else None,
        status=RecordStatus.ACTIVE,
    )
    db.add(client)
    return client.id, {
        "full_name": client.full_name,
        "phone": client.phone,
        "status": client.status.value,
    }


def _apply_client_update(
    db: Session,
    context: AuthContext,
    merchant_id: UUID,
    op: SyncOperationItem,
) -> tuple[UUID, dict[str, Any]]:
    client_id_raw = op.payload.get("client_id")
    if not client_id_raw:
        raise SyncRejectedError("L'identifiant du client (client_id) est obligatoire.")
    try:
        client_id = UUID(str(client_id_raw))
    except ValueError:
        raise SyncRejectedError("Identifiant client invalide.")

    payload = ClientUpdate.model_validate(op.payload)
    client = db.scalar(
        select(Client).where(
            Client.id == client_id,
            Client.merchant_id == merchant_id,
        ).with_for_update()
    )
    if client is None:
        raise SyncRejectedError("Client introuvable.")

    if op.client_updated_at and client.updated_at:
        client_ver = op.client_updated_at.astimezone(UTC)
        server_ver = client.updated_at.astimezone(UTC)
        if server_ver > client_ver + timedelta(seconds=1):
            raise SyncConflictError(
                "La fiche client a été modifiée sur le serveur depuis votre dernière synchronisation.",
                {
                    "server_updated_at": server_ver.isoformat(),
                    "client_version": client_ver.isoformat(),
                    "server_full_name": client.full_name,
                },
            )

    if payload.full_name is not None:
        client.full_name = payload.full_name
    if "phone" in payload.model_fields_set:
        client.phone = payload.phone.strip() if payload.phone else None
    if "address" in payload.model_fields_set:
        client.address = payload.address.strip() if payload.address else None
    if "notes" in payload.model_fields_set:
        client.notes = payload.notes.strip() if payload.notes else None

    return client.id, {
        "full_name": client.full_name,
        "phone": client.phone,
    }


def _apply_product_create(
    db: Session,
    context: AuthContext,
    merchant_id: UUID,
    op: SyncOperationItem,
) -> tuple[UUID, dict[str, Any]]:
    payload = ProductCreate.model_validate(op.payload)
    if payload.sku:
        existing_sku = db.scalar(
            select(Product.id).where(
                Product.merchant_id == merchant_id,
                Product.sku == payload.sku,
            )
        )
        if existing_sku:
            raise SyncConflictError(
                f"Le code SKU « {payload.sku} » est déjà utilisé par un autre produit.",
                {"sku": payload.sku},
            )

    if payload.category_id:
        category = db.scalar(
            select(Category.id).where(
                Category.id == payload.category_id,
                Category.merchant_id == merchant_id,
            )
        )
        if not category:
            raise SyncRejectedError("La catégorie sélectionnée est introuvable.")

    product_id = op.operation_id or uuid4()
    product = Product(
        id=product_id,
        merchant_id=merchant_id,
        category_id=payload.category_id,
        name=payload.name,
        sku=payload.sku,
        purchase_price=payload.purchase_price,
        sale_price=payload.sale_price,
        stock_alert_threshold=payload.stock_alert_threshold,
        status=RecordStatus.ACTIVE,
    )
    db.add(product)

    if payload.initial_quantity > 0:
        db.add(
            StockMovement(
                merchant_id=merchant_id,
                product_id=product.id,
                created_by_user_id=context.user.id,
                movement_type=StockMovementType.ENTRY,
                quantity=payload.initial_quantity,
                note="Stock initial lors de la création hors ligne",
                occurred_at=op.occurred_at.astimezone(UTC) if op.occurred_at else datetime.now(UTC),
            )
        )

    return product.id, {
        "name": product.name,
        "sku": product.sku,
        "sale_price": product.sale_price,
    }


def _apply_product_update(
    db: Session,
    context: AuthContext,
    merchant_id: UUID,
    op: SyncOperationItem,
) -> tuple[UUID, dict[str, Any]]:
    product_id_raw = op.payload.get("product_id")
    if not product_id_raw:
        raise SyncRejectedError("L'identifiant du produit (product_id) est obligatoire.")
    try:
        product_id = UUID(str(product_id_raw))
    except ValueError:
        raise SyncRejectedError("Identifiant produit invalide.")

    payload = ProductUpdate.model_validate(op.payload)
    product = db.scalar(
        select(Product).where(
            Product.id == product_id,
            Product.merchant_id == merchant_id,
        ).with_for_update()
    )
    if product is None:
        raise SyncRejectedError("Produit introuvable.")

    if op.client_updated_at and product.updated_at:
        client_ver = op.client_updated_at.astimezone(UTC)
        server_ver = product.updated_at.astimezone(UTC)
        if server_ver > client_ver + timedelta(seconds=1):
            raise SyncConflictError(
                "Le produit a été modifié sur le serveur depuis votre dernière synchronisation.",
                {
                    "server_updated_at": server_ver.isoformat(),
                    "client_version": client_ver.isoformat(),
                    "server_name": product.name,
                },
            )

    if payload.name is not None:
        product.name = payload.name
    if "sku" in payload.model_fields_set:
        product.sku = payload.sku
    if payload.category_id is not None or "category_id" in payload.model_fields_set:
        product.category_id = payload.category_id
    if payload.purchase_price is not None:
        product.purchase_price = payload.purchase_price
    if payload.sale_price is not None:
        product.sale_price = payload.sale_price
    if payload.stock_alert_threshold is not None:
        product.stock_alert_threshold = payload.stock_alert_threshold

    return product.id, {
        "name": product.name,
        "sale_price": product.sale_price,
    }


def _apply_category_create(
    db: Session,
    context: AuthContext,
    merchant_id: UUID,
    op: SyncOperationItem,
) -> tuple[UUID, dict[str, Any]]:
    payload = CategoryCreate.model_validate(op.payload)
    existing = db.scalar(
        select(Category).where(
            Category.merchant_id == merchant_id,
            Category.name == payload.name,
        )
    )
    if existing:
        return existing.id, {"name": existing.name, "already_existed": True}

    category_id = op.operation_id or uuid4()
    category = Category(
        id=category_id,
        merchant_id=merchant_id,
        name=payload.name,
        status=RecordStatus.ACTIVE,
    )
    db.add(category)
    return category.id, {"name": category.name}


def _apply_stock_movement(
    db: Session,
    context: AuthContext,
    merchant_id: UUID,
    op: SyncOperationItem,
) -> tuple[UUID, dict[str, Any]]:
    payload = StockMovementCreate.model_validate(op.payload)
    occurred_at = op.occurred_at.astimezone(UTC) if op.occurred_at else datetime.now(UTC)

    product = db.scalar(
        select(Product).where(
            Product.id == payload.product_id,
            Product.merchant_id == merchant_id,
            Product.status == RecordStatus.ACTIVE,
        )
    )
    if product is None:
        raise SyncRejectedError("Produit introuvable ou archivé.")

    movement_id = op.operation_id or uuid4()
    movement = StockMovement(
        id=movement_id,
        merchant_id=merchant_id,
        product_id=product.id,
        created_by_user_id=context.user.id,
        movement_type=StockMovementType(payload.movement_type),
        quantity=payload.quantity,
        note=payload.note.strip() if payload.note else None,
        occurred_at=occurred_at,
    )
    db.add(movement)
    return movement.id, {
        "product_id": str(product.id),
        "movement_type": movement.movement_type.value,
        "quantity": float(movement.quantity),
    }


DISPATCH_MAP = {
    "sale.create": _apply_sale_create,
    "credit.repayment": _apply_credit_repayment,
    "expense.create": _apply_expense_create,
    "client.create": _apply_client_create,
    "client.update": _apply_client_update,
    "product.create": _apply_product_create,
    "product.update": _apply_product_update,
    "category.create": _apply_category_create,
    "stock.movement": _apply_stock_movement,
}


def process_sync_push(
    db: Session,
    context: AuthContext,
    merchant_id: UUID,
    request: SyncPushRequest,
    http_request: Request,
) -> SyncPushResponse:
    now = datetime.now(UTC)
    results: list[SyncOperationResult] = []
    applied_count = 0
    duplicate_count = 0
    conflict_count = 0
    rejected_count = 0

    for op in request.operations:
        # 1. Vérification idempotence globale device + key
        existing_op = db.scalar(
            select(SyncOperation).where(
                SyncOperation.merchant_id == merchant_id,
                SyncOperation.device_id == request.device_id,
                SyncOperation.idempotency_key == op.idempotency_key,
            )
        )
        if existing_op:
            duplicate_count += 1
            payload_data = None
            if existing_op.response_payload:
                try:
                    payload_data = json.loads(existing_op.response_payload)
                except Exception:
                    payload_data = None
            results.append(
                SyncOperationResult(
                    operation_id=op.operation_id,
                    idempotency_key=op.idempotency_key,
                    operation_type=op.operation_type,
                    status="duplicate",
                    entity_id=UUID(payload_data["entity_id"]) if payload_data and "entity_id" in payload_data else None,
                    message="Opération déjà traitée précédemment (idempotence).",
                    data=payload_data.get("data") if payload_data else None,
                )
            )
            continue

        handler = DISPATCH_MAP.get(op.operation_type)
        if not handler:
            rejected_count += 1
            results.append(
                SyncOperationResult(
                    operation_id=op.operation_id,
                    idempotency_key=op.idempotency_key,
                    operation_type=op.operation_type,
                    status="rejected",
                    message=f"Type d'opération inconnu : {op.operation_type}",
                )
            )
            continue

        # Point de sauvegarde pour isolation partielle
        savepoint = db.begin_nested()
        try:
            entity_id, data = handler(db, context, merchant_id, op)
            # Enregistrer l'opération dans le journal de synchronisation
            sync_record = SyncOperation(
                merchant_id=merchant_id,
                user_id=context.user.id,
                device_id=request.device_id,
                idempotency_key=op.idempotency_key,
                operation_type=op.operation_type,
                response_payload=json.dumps({
                    "entity_id": str(entity_id),
                    "data": data,
                }),
            )
            db.add(sync_record)
            savepoint.commit()

            applied_count += 1
            results.append(
                SyncOperationResult(
                    operation_id=op.operation_id,
                    idempotency_key=op.idempotency_key,
                    operation_type=op.operation_type,
                    status="applied",
                    entity_id=entity_id,
                    message="Opération appliquée avec succès.",
                    data=data,
                )
            )
        except SyncConflictError as err:
            savepoint.rollback()
            conflict_count += 1
            results.append(
                SyncOperationResult(
                    operation_id=op.operation_id,
                    idempotency_key=op.idempotency_key,
                    operation_type=op.operation_type,
                    status="conflict",
                    message=err.message,
                    data=err.details,
                )
            )
        except (SyncRejectedError, Exception) as err:
            savepoint.rollback()
            rejected_count += 1
            message = getattr(err, "message", None) or str(err)
            if hasattr(err, "detail"):
                message = str(err.detail)
            results.append(
                SyncOperationResult(
                    operation_id=op.operation_id,
                    idempotency_key=op.idempotency_key,
                    operation_type=op.operation_type,
                    status="rejected",
                    message=message,
                )
            )

    db.commit()

    record_audit(
        db,
        http_request,
        "sync.pushed",
        actor_user_id=context.user.id,
        merchant_id=merchant_id,
        target_type="sync_batch",
        details={
            "device_id": request.device_id,
            "total": len(request.operations),
            "applied": applied_count,
            "duplicates": duplicate_count,
            "conflicts": conflict_count,
            "rejected": rejected_count,
        },
    )

    return SyncPushResponse(
        server_time=now,
        new_cursor=now.isoformat(),
        processed_count=len(request.operations),
        applied_count=applied_count,
        duplicate_count=duplicate_count,
        conflict_count=conflict_count,
        rejected_count=rejected_count,
        results=results,
    )


def process_sync_pull(
    db: Session,
    merchant_id: UUID,
    cursor: str | None,
    limit: int = 200,
) -> SyncPullResponse:
    now = datetime.now(UTC)
    cursor_dt: datetime | None = None
    if cursor and cursor.strip():
        try:
            cursor_dt = datetime.fromisoformat(cursor.strip())
        except ValueError:
            raise HTTPException(status_code=422, detail="Curseur de synchronisation invalide (format ISO 8601 attendu).")

    # Categories
    cat_query = select(Category).where(Category.merchant_id == merchant_id)
    if cursor_dt:
        cat_query = cat_query.where(Category.updated_at >= cursor_dt)
    categories = db.scalars(cat_query.order_by(Category.updated_at.asc()).limit(limit)).all()

    # Products with stock
    prod_query = select(Product).where(Product.merchant_id == merchant_id)
    if cursor_dt:
        prod_query = prod_query.where(Product.updated_at >= cursor_dt)
    products = db.scalars(prod_query.order_by(Product.updated_at.asc()).limit(limit)).all()

    product_stocks: dict[UUID, float] = {}
    if products:
        prod_ids = [p.id for p in products]
        quantity_expr = case(
            (
                StockMovement.movement_type.in_(
                    (StockMovementType.ENTRY, StockMovementType.REVERSAL)
                ),
                StockMovement.quantity,
            ),
            else_=-StockMovement.quantity,
        )
        stock_rows = db.execute(
            select(StockMovement.product_id, func.coalesce(func.sum(quantity_expr), 0))
            .where(
                StockMovement.merchant_id == merchant_id,
                StockMovement.product_id.in_(prod_ids),
            )
            .group_by(StockMovement.product_id)
        ).all()
        product_stocks = {p_id: float(q) for p_id, q in stock_rows}

    # Clients with credit balance
    client_query = select(Client).where(Client.merchant_id == merchant_id)
    if cursor_dt:
        client_query = client_query.where(Client.updated_at >= cursor_dt)
    clients = db.scalars(client_query.order_by(Client.updated_at.asc()).limit(limit)).all()

    client_balances: dict[UUID, int] = {}
    if clients:
        c_ids = [c.id for c in clients]
        signed_amount = case(
            (CreditLedgerEntry.entry_type == CreditEntryType.REPAYMENT, -CreditLedgerEntry.amount),
            else_=CreditLedgerEntry.amount,
        )
        balance_rows = db.execute(
            select(CreditLedgerEntry.client_id, func.coalesce(func.sum(signed_amount), 0))
            .where(
                CreditLedgerEntry.merchant_id == merchant_id,
                CreditLedgerEntry.client_id.in_(c_ids),
            )
            .group_by(CreditLedgerEntry.client_id)
        ).all()
        client_balances = {c_id: int(b) for c_id, b in balance_rows}

    # Sales
    sale_query = select(Sale).where(Sale.merchant_id == merchant_id)
    if cursor_dt:
        sale_query = sale_query.where(Sale.sold_at >= cursor_dt)
    sales = db.scalars(sale_query.order_by(Sale.sold_at.asc()).limit(limit)).all()

    sales_data: list[dict[str, Any]] = []
    if sales:
        sale_ids = [s.id for s in sales]
        lines_rows = db.scalars(
            select(SaleLine).where(
                SaleLine.merchant_id == merchant_id,
                SaleLine.sale_id.in_(sale_ids),
            )
        ).all()
        lines_by_sale: dict[UUID, list[dict[str, Any]]] = {}
        for line in lines_rows:
            lines_by_sale.setdefault(line.sale_id, []).append({
                "product_id": str(line.product_id) if line.product_id else None,
                "product_name": line.product_name,
                "quantity": float(line.quantity),
                "unit_sale_price": line.unit_sale_price,
                "line_total": line.line_total,
            })
        for sale in sales:
            sales_data.append({
                "id": str(sale.id),
                "receipt_number": sale.receipt_number,
                "client_id": str(sale.client_id) if sale.client_id else None,
                "status": sale.status.value,
                "payment_method": sale.payment_method.value,
                "subtotal": sale.subtotal,
                "discount_amount": sale.discount_amount,
                "total_amount": sale.total_amount,
                "sold_at": sale.sold_at.isoformat(),
                "lines": lines_by_sale.get(sale.id, []),
            })

    # Credit ledger
    credit_query = select(CreditLedgerEntry).where(CreditLedgerEntry.merchant_id == merchant_id)
    if cursor_dt:
        credit_query = credit_query.where(CreditLedgerEntry.occurred_at >= cursor_dt)
    credit_entries = db.scalars(credit_query.order_by(CreditLedgerEntry.occurred_at.asc()).limit(limit)).all()

    # Expenses
    expense_query = select(Expense).where(Expense.merchant_id == merchant_id)
    if cursor_dt:
        expense_query = expense_query.where(Expense.updated_at >= cursor_dt)
    expenses = db.scalars(expense_query.order_by(Expense.updated_at.asc()).limit(limit)).all()

    # Stock movements
    sm_query = select(StockMovement).where(StockMovement.merchant_id == merchant_id)
    if cursor_dt:
        sm_query = sm_query.where(StockMovement.occurred_at >= cursor_dt)
    stock_movements = db.scalars(sm_query.order_by(StockMovement.occurred_at.asc()).limit(limit)).all()

    has_more = any(
        len(lst) == limit
        for lst in (categories, products, clients, sales, credit_entries, expenses, stock_movements)
    )

    return SyncPullResponse(
        server_time=now,
        cursor=cursor,
        next_cursor=now.isoformat(),
        has_more=has_more,
        categories=[
            {
                "id": str(c.id),
                "name": c.name,
                "status": c.status.value,
                "created_at": c.created_at.isoformat(),
                "updated_at": c.updated_at.isoformat(),
            }
            for c in categories
        ],
        products=[
            {
                "id": str(p.id),
                "category_id": str(p.category_id) if p.category_id else None,
                "name": p.name,
                "sku": p.sku,
                "purchase_price": p.purchase_price,
                "sale_price": p.sale_price,
                "stock_alert_threshold": float(p.stock_alert_threshold),
                "current_stock": product_stocks.get(p.id, 0.0),
                "status": p.status.value,
                "created_at": p.created_at.isoformat(),
                "updated_at": p.updated_at.isoformat(),
            }
            for p in products
        ],
        clients=[
            {
                "id": str(c.id),
                "full_name": c.full_name,
                "phone": c.phone,
                "address": c.address,
                "notes": c.notes,
                "status": c.status.value,
                "credit_balance": client_balances.get(c.id, 0),
                "created_at": c.created_at.isoformat(),
                "updated_at": c.updated_at.isoformat(),
            }
            for c in clients
        ],
        sales=sales_data,
        credit_entries=[
            {
                "id": str(ce.id),
                "client_id": str(ce.client_id),
                "sale_id": str(ce.sale_id) if ce.sale_id else None,
                "entry_type": ce.entry_type.value,
                "amount": ce.amount,
                "payment_method": ce.payment_method.value if ce.payment_method else None,
                "note": ce.note,
                "occurred_at": ce.occurred_at.isoformat(),
            }
            for ce in credit_entries
        ],
        expenses=[
            {
                "id": str(e.id),
                "label": e.label,
                "category": e.category,
                "amount": e.amount,
                "note": e.note,
                "spent_at": e.spent_at.isoformat(),
                "is_voided": e.is_voided,
                "created_at": e.created_at.isoformat(),
                "updated_at": e.updated_at.isoformat(),
            }
            for e in expenses
        ],
        stock_movements=[
            {
                "id": str(sm.id),
                "product_id": str(sm.product_id),
                "sale_id": str(sm.sale_id) if sm.sale_id else None,
                "movement_type": sm.movement_type.value,
                "quantity": float(sm.quantity),
                "note": sm.note,
                "occurred_at": sm.occurred_at.isoformat(),
            }
            for sm in stock_movements
        ],
    )


def get_sync_status(
    db: Session,
    merchant_id: UUID,
    device_id: str | None,
) -> SyncStatusResponse:
    now = datetime.now(UTC)
    total_count = db.scalar(
        select(func.count(SyncOperation.id)).where(SyncOperation.merchant_id == merchant_id)
    ) or 0

    device_count = 0
    last_sync_at: datetime | None = None
    if device_id and device_id.strip():
        dev = device_id.strip()
        device_count = db.scalar(
            select(func.count(SyncOperation.id)).where(
                SyncOperation.merchant_id == merchant_id,
                SyncOperation.device_id == dev,
            )
        ) or 0
        last_sync_at = db.scalar(
            select(SyncOperation.created_at)
            .where(
                SyncOperation.merchant_id == merchant_id,
                SyncOperation.device_id == dev,
            )
            .order_by(SyncOperation.created_at.desc())
            .limit(1)
        )
    else:
        last_sync_at = db.scalar(
            select(SyncOperation.created_at)
            .where(SyncOperation.merchant_id == merchant_id)
            .order_by(SyncOperation.created_at.desc())
            .limit(1)
        )

    return SyncStatusResponse(
        merchant_id=merchant_id,
        device_id=device_id.strip() if device_id else None,
        server_time=now,
        last_sync_at=last_sync_at,
        total_sync_operations=total_count,
        device_sync_operations_count=device_count,
        is_sync_active=True,
    )
