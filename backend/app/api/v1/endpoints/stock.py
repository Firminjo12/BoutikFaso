from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.api.deps import AuthContext, require_path_merchant, require_path_merchant_roles
from app.db.session import get_db
from app.models import (
    Category,
    MembershipRole,
    Product,
    RecordStatus,
    StockMovement,
    StockMovementType,
)
from app.schemas.catalog import StockMovementCreate, StockMovementRead, StockSummary
from app.services.audit import record_audit

router = APIRouter()
STOCK_EDITORS = (MembershipRole.OWNER, MembershipRole.MANAGER, MembershipRole.STOCK_MANAGER)


def _quantity_expression():
    signed_quantity = case(
        (
            StockMovement.movement_type.in_(
                (StockMovementType.ENTRY, StockMovementType.REVERSAL)
            ),
            StockMovement.quantity,
        ),
        else_=-StockMovement.quantity,
    )
    return (
        select(func.coalesce(func.sum(signed_quantity), 0))
        .where(
            StockMovement.product_id == Product.id,
            StockMovement.merchant_id == Product.merchant_id,
        )
        .correlate(Product)
        .scalar_subquery()
    )


@router.get("/summary", response_model=StockSummary)
def stock_summary(
    merchant_id: UUID,
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> StockSummary:
    quantity = _quantity_expression()
    products = db.execute(
        select(Product.stock_alert_threshold, quantity).where(
            Product.merchant_id == merchant_id,
            Product.status == RecordStatus.ACTIVE,
        )
    ).all()
    movement_totals = db.execute(
        select(
            func.coalesce(
                func.sum(case((StockMovement.movement_type == StockMovementType.ENTRY,
                               StockMovement.quantity), else_=0)), 0
            ),
            func.coalesce(
                func.sum(case((StockMovement.movement_type.in_(
                    (StockMovementType.EXIT, StockMovementType.SALE)),
                    StockMovement.quantity), else_=0)), 0
            ),
            func.coalesce(
                func.sum(case((StockMovement.movement_type == StockMovementType.LOSS,
                               StockMovement.quantity), else_=0)), 0
            ),
        ).where(StockMovement.merchant_id == merchant_id)
    ).one()
    return StockSummary(
        total_units=sum((qty for _, qty in products), start=0),
        entries=movement_totals[0],
        exits=movement_totals[1],
        losses=movement_totals[2],
        low_stock_products=sum(1 for threshold, qty in products if qty > 0 and qty <= threshold),
        out_of_stock_products=sum(1 for _, qty in products if qty <= 0),
    )


@router.get("/movements", response_model=list[StockMovementRead])
def list_movements(
    merchant_id: UUID,
    movement_type: str | None = Query(default=None, pattern="^(entry|exit|loss|sale|reversal)$"),
    product_id: UUID | None = None,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=200),
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> list[StockMovementRead]:
    query = select(StockMovement, Product.name).join(
        Product,
        (Product.id == StockMovement.product_id)
        & (Product.merchant_id == StockMovement.merchant_id),
    ).where(StockMovement.merchant_id == merchant_id)
    if movement_type:
        query = query.where(StockMovement.movement_type == StockMovementType(movement_type))
    if product_id:
        query = query.where(StockMovement.product_id == product_id)
    rows = db.execute(query.order_by(StockMovement.occurred_at.desc())
                      .offset(offset).limit(limit)).all()
    return [
        StockMovementRead(
            id=movement.id,
            product_id=movement.product_id,
            product_name=name,
            movement_type=movement.movement_type.value,
            quantity=movement.quantity,
            note=movement.note,
            occurred_at=movement.occurred_at,
        )
        for movement, name in rows
    ]


@router.get("/products/{product_id}")
def product_stock(
    merchant_id: UUID,
    product_id: UUID,
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    row = db.execute(
        select(Product, _quantity_expression()).where(
            Product.id == product_id,
            Product.merchant_id == merchant_id,
            Product.status == RecordStatus.ACTIVE,
        )
    ).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Produit introuvable.")
    product, quantity = row
    return {
        "product_id": product.id,
        "product_name": product.name,
        "quantity": quantity,
        "alert_threshold": product.stock_alert_threshold,
    }


@router.post("/movements", response_model=StockMovementRead,
             status_code=status.HTTP_201_CREATED)
def create_movement(
    merchant_id: UUID,
    payload: StockMovementCreate,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*STOCK_EDITORS)),
    db: Session = Depends(get_db),
) -> StockMovementRead:
    product = db.scalar(
        select(Product)
        .where(
            Product.id == payload.product_id,
            Product.merchant_id == merchant_id,
            Product.status == RecordStatus.ACTIVE,
        )
        .with_for_update()
    )
    if product is None:
        raise HTTPException(status_code=404, detail="Produit introuvable.")

    quantity = db.scalar(select(_quantity_expression()).where(Product.id == product.id)) or 0
    if payload.movement_type in ("exit", "loss") and payload.quantity > quantity:
        raise HTTPException(
            status_code=409,
            detail=f"Stock insuffisant : {quantity} unité(s) disponible(s).",
        )

    movement = StockMovement(
        merchant_id=merchant_id,
        product_id=product.id,
        created_by_user_id=context.user.id,
        movement_type=StockMovementType(payload.movement_type),
        quantity=payload.quantity,
        note=payload.note.strip() if payload.note else None,
    )
    db.add(movement)
    db.flush()
    record_audit(
        db,
        request,
        "stock.movement_created",
        actor_user_id=context.user.id,
        merchant_id=merchant_id,
        target_type="stock_movement",
        target_id=movement.id,
        details={"type": payload.movement_type, "quantity": str(payload.quantity)},
    )
    db.commit()
    db.refresh(movement)
    return StockMovementRead(
        id=movement.id,
        product_id=product.id,
        product_name=product.name,
        movement_type=movement.movement_type.value,
        quantity=movement.quantity,
        note=movement.note,
        occurred_at=movement.occurred_at,
    )
