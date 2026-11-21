import csv
from datetime import date
from decimal import Decimal
from io import StringIO
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.api.deps import AuthContext, require_path_merchant
from app.db.session import get_db
from app.models import (
    Expense,
    Product,
    RecordStatus,
    Sale,
    SaleLine,
    SaleStatus,
    StockMovement,
    StockMovementType,
)
from app.schemas.finance import (
    BusinessSummary,
    DashboardRead,
    ExpenseCategoryTotal,
    ExpensesReport,
    StockReport,
)
from app.services.reporting import (
    _expense_rows,
    _round_amount,
    _sales_rows,
    build_business_summary,
    resolve_period,
    stock_quantity_expression,
)

router = APIRouter()
PERIODS = "^(today|week|month|custom)$"


def _window(
    merchant,
    period: str,
    start_date: date | None,
    end_date: date | None,
):
    return resolve_period(merchant, period, start_date, end_date)


@router.get("/dashboard", response_model=DashboardRead)
def dashboard(
    merchant_id: UUID,
    period: str = Query(default="today", pattern=PERIODS),
    start_date: date | None = None,
    end_date: date | None = None,
    context: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> DashboardRead:
    window = _window(context.merchant, period, start_date, end_date)
    summary = build_business_summary(db, merchant_id, window)
    quantity = stock_quantity_expression()
    stock_rows = db.execute(
        select(Product.stock_alert_threshold, quantity).where(
            Product.merchant_id == merchant_id,
            Product.status == RecordStatus.ACTIVE,
        )
    ).all()
    low_stock = sum(1 for threshold, current in stock_rows if 0 < current <= threshold)
    out_of_stock = sum(1 for _, current in stock_rows if current <= 0)
    top_products = db.execute(
        select(
            SaleLine.product_name,
            func.sum(SaleLine.quantity).label("quantity_sold"),
            func.sum(SaleLine.line_total).label("sales_total"),
        )
        .join(Sale, (Sale.id == SaleLine.sale_id) & (Sale.merchant_id == SaleLine.merchant_id))
        .where(
            Sale.merchant_id == merchant_id,
            Sale.status == SaleStatus.COMPLETED,
            Sale.sold_at >= window.start_utc,
            Sale.sold_at < window.end_utc,
        )
        .group_by(SaleLine.product_name)
        .order_by(func.sum(SaleLine.quantity).desc(), func.sum(SaleLine.line_total).desc())
        .limit(5)
    ).all()
    data = summary.model_dump()
    return DashboardRead(
        **data,
        low_stock_products=low_stock,
        out_of_stock_products=out_of_stock,
        top_products=[
            {
                "product_name": row.product_name,
                "quantity_sold": row.quantity_sold,
                "sales_total": int(row.sales_total),
            }
            for row in top_products
        ],
    )


@router.get("/reports/summary", response_model=BusinessSummary)
def summary_report(
    merchant_id: UUID,
    period: str = Query(default="month", pattern=PERIODS),
    start_date: date | None = None,
    end_date: date | None = None,
    context: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> BusinessSummary:
    window = _window(context.merchant, period, start_date, end_date)
    return build_business_summary(db, merchant_id, window)


@router.get("/reports/sales", response_model=BusinessSummary)
def sales_report(
    merchant_id: UUID,
    period: str = Query(default="month", pattern=PERIODS),
    start_date: date | None = None,
    end_date: date | None = None,
    context: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> BusinessSummary:
    window = _window(context.merchant, period, start_date, end_date)
    return build_business_summary(db, merchant_id, window)


@router.get("/reports/profit", response_model=BusinessSummary)
def profit_report(
    merchant_id: UUID,
    period: str = Query(default="month", pattern=PERIODS),
    start_date: date | None = None,
    end_date: date | None = None,
    context: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> BusinessSummary:
    window = _window(context.merchant, period, start_date, end_date)
    return build_business_summary(db, merchant_id, window)


@router.get("/reports/expenses", response_model=ExpensesReport)
def expenses_report(
    merchant_id: UUID,
    period: str = Query(default="month", pattern=PERIODS),
    start_date: date | None = None,
    end_date: date | None = None,
    context: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> ExpensesReport:
    window = _window(context.merchant, period, start_date, end_date)
    rows = _expense_rows(db, merchant_id, window)
    totals: dict[str, int] = {}
    for _, amount, category in rows:
        totals[category] = totals.get(category, 0) + int(amount)
    summary = build_business_summary(db, merchant_id, window)
    return ExpensesReport(
        period=window.label,
        start_date=window.start_date,
        end_date=window.end_date,
        timezone=window.timezone.key,
        expenses_total=summary.expenses_total,
        expense_count=len(rows),
        by_category=[
            ExpenseCategoryTotal(category=name, amount=amount)
            for name, amount in sorted(totals.items(), key=lambda item: (-item[1], item[0]))
        ],
        daily_totals=summary.daily_totals,
    )


@router.get("/reports/stock", response_model=StockReport)
def stock_report(
    merchant_id: UUID,
    period: str = Query(default="month", pattern=PERIODS),
    start_date: date | None = None,
    end_date: date | None = None,
    context: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> StockReport:
    window = _window(context.merchant, period, start_date, end_date)
    quantity = stock_quantity_expression()
    products = db.execute(
        select(Product, quantity).where(
            Product.merchant_id == merchant_id,
            Product.status == RecordStatus.ACTIVE,
        )
    ).all()
    current_units = sum((amount for _, amount in products), start=Decimal(0))
    purchase_value = _round_amount(
        sum((Decimal(product.purchase_price) * amount for product, amount in products), start=Decimal(0))
    )
    sale_value = _round_amount(
        sum((Decimal(product.sale_price) * amount for product, amount in products), start=Decimal(0))
    )
    movements = db.execute(
        select(
            func.coalesce(func.sum(case((StockMovement.movement_type.in_(
                (StockMovementType.ENTRY, StockMovementType.REVERSAL)), StockMovement.quantity), else_=0)), 0),
            func.coalesce(func.sum(case((StockMovement.movement_type.in_(
                (StockMovementType.EXIT, StockMovementType.SALE)), StockMovement.quantity), else_=0)), 0),
            func.coalesce(func.sum(case((StockMovement.movement_type == StockMovementType.LOSS,
                                         StockMovement.quantity), else_=0)), 0),
        ).where(
            StockMovement.merchant_id == merchant_id,
            StockMovement.occurred_at >= window.start_utc,
            StockMovement.occurred_at < window.end_utc,
        )
    ).one()
    return StockReport(
        period=window.label,
        start_date=window.start_date,
        end_date=window.end_date,
        timezone=window.timezone.key,
        current_units=current_units,
        purchase_value=purchase_value,
        sale_value=sale_value,
        entries=movements[0],
        exits=movements[1],
        losses=movements[2],
        low_stock_products=sum(1 for product, amount in products
                               if amount > 0 and amount <= product.stock_alert_threshold),
        out_of_stock_products=sum(1 for _, amount in products if amount <= 0),
    )


def _csv_cell(value: object) -> object:
    if isinstance(value, str) and value.startswith(("=", "+", "-", "@", "\t", "\r")):
        return f"'{value}"
    return value


def _csv_response(buffer: StringIO, report: str, window) -> Response:
    filename = f"boutik-faso-{report}-{window.start_date}-{window.end_date}.csv"
    return Response(
        content="\ufeff" + buffer.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/reports/export")
def export_report(
    merchant_id: UUID,
    report: str = Query(pattern="^(sales|profit|expenses|stock)$"),
    period: str = Query(default="month", pattern=PERIODS),
    start_date: date | None = None,
    end_date: date | None = None,
    context: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> Response:
    window = _window(context.merchant, period, start_date, end_date)
    buffer = StringIO(newline="")
    writer = csv.writer(buffer)

    if report == "sales":
        writer.writerow(("Date", "Reçu", "Ventes nettes (FCFA)", "Bénéfice brut estimé (FCFA)"))
        for sale in _sales_rows(db, merchant_id, window):
            writer.writerow((
                sale.sold_at.astimezone(window.timezone).isoformat(),
                sale.receipt_number,
                sale.total_amount,
                _round_amount(sale.gross_margin),
            ))
    elif report == "profit":
        result = build_business_summary(db, merchant_id, window)
        writer.writerow(("Date", "Ventes nettes (FCFA)", "Bénéfice brut estimé (FCFA)", "Dépenses (FCFA)", "Résultat estimé (FCFA)"))
        for day in result.daily_totals:
            writer.writerow((
                day.date.isoformat(), day.sales_total, day.estimated_gross_profit,
                day.expenses_total, day.estimated_gross_profit - day.expenses_total,
            ))
    elif report == "expenses":
        writer.writerow(("Date", "Libellé", "Catégorie", "Montant (FCFA)", "Note"))
        expenses = db.scalars(
            select(Expense).where(
                Expense.merchant_id == merchant_id,
                Expense.is_voided.is_(False),
                Expense.spent_at >= window.start_utc,
                Expense.spent_at < window.end_utc,
            ).order_by(Expense.spent_at)
        ).all()
        for expense in expenses:
            writer.writerow(tuple(_csv_cell(value) for value in (
                expense.spent_at.astimezone(window.timezone).isoformat(),
                expense.label,
                expense.category,
                expense.amount,
                expense.note or "",
            )))
    else:
        quantity = stock_quantity_expression()
        products = db.execute(
            select(Product, quantity).where(
                Product.merchant_id == merchant_id,
                Product.status == RecordStatus.ACTIVE,
            ).order_by(Product.name)
        ).all()
        writer.writerow(("Produit", "Stock actuel", "Seuil d’alerte", "Valeur achat (FCFA)", "Valeur vente (FCFA)"))
        for product, amount in products:
            writer.writerow((
                _csv_cell(product.name),
                str(amount),
                str(product.stock_alert_threshold),
                _round_amount(Decimal(product.purchase_price) * amount),
                _round_amount(Decimal(product.sale_price) * amount),
            ))

    return _csv_response(buffer, report, window)
