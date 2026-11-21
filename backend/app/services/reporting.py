from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal, ROUND_HALF_UP
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import HTTPException
from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.models import (
    CreditEntryType,
    CreditLedgerEntry,
    Expense,
    Merchant,
    Product,
    RecordStatus,
    Sale,
    SaleLine,
    SaleStatus,
    StockMovement,
    StockMovementType,
)
from app.schemas.finance import BusinessSummary, DailyTotals, ReportPeriod


@dataclass(frozen=True)
class ResolvedPeriod:
    label: str
    start_date: date
    end_date: date
    timezone: ZoneInfo
    start_utc: datetime
    end_utc: datetime

    def schema(self) -> ReportPeriod:
        return ReportPeriod(
            period=self.label,
            start_date=self.start_date,
            end_date=self.end_date,
            timezone=self.timezone.key,
        )


def resolve_period(
    merchant: Merchant,
    period: str,
    start_date: date | None,
    end_date: date | None,
) -> ResolvedPeriod:
    try:
        timezone = ZoneInfo(merchant.timezone)
    except ZoneInfoNotFoundError:
        raise HTTPException(status_code=422, detail="Le fuseau horaire de la boutique est invalide.") from None

    today = datetime.now(timezone).date()
    if start_date is not None or end_date is not None:
        if start_date is None or end_date is None:
            raise HTTPException(status_code=422, detail="Les dates de début et de fin sont requises ensemble.")
        label = "custom"
        first, last = start_date, end_date
    elif period == "today":
        label = period
        first = last = today
    elif period == "week":
        label = period
        first = today - timedelta(days=today.weekday())
        last = today
    elif period == "month":
        label = period
        first = today.replace(day=1)
        last = today
    else:
        raise HTTPException(status_code=422, detail="Période invalide.")

    if last < first:
        raise HTTPException(status_code=422, detail="La date de fin précède la date de début.")
    if (last - first).days > 365:
        raise HTTPException(status_code=422, detail="La période ne peut pas dépasser 366 jours.")

    start_local = datetime.combine(first, time.min, tzinfo=timezone)
    end_local = datetime.combine(last + timedelta(days=1), time.min, tzinfo=timezone)
    return ResolvedPeriod(
        label=label,
        start_date=first,
        end_date=last,
        timezone=timezone,
        start_utc=start_local.astimezone(UTC),
        end_utc=end_local.astimezone(UTC),
    )


def _round_amount(value: Decimal | int | None) -> int:
    if value is None:
        return 0
    return int(Decimal(value).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def _sales_rows(db: Session, merchant_id, window: ResolvedPeriod):
    gross_margin = func.sum(
        SaleLine.line_total - SaleLine.unit_purchase_price * SaleLine.quantity
    ) - Sale.discount_amount
    return db.execute(
        select(
            Sale.id,
            Sale.sold_at,
            Sale.receipt_number,
            Sale.total_amount,
            Sale.discount_amount,
            gross_margin.label("gross_margin"),
        )
        .join(SaleLine, (SaleLine.sale_id == Sale.id) & (SaleLine.merchant_id == Sale.merchant_id))
        .where(
            Sale.merchant_id == merchant_id,
            Sale.status == SaleStatus.COMPLETED,
            Sale.sold_at >= window.start_utc,
            Sale.sold_at < window.end_utc,
        )
        .group_by(Sale.id)
        .order_by(Sale.sold_at)
    ).all()


def _expense_rows(db: Session, merchant_id, window: ResolvedPeriod):
    return db.execute(
        select(Expense.spent_at, Expense.amount, Expense.category)
        .where(
            Expense.merchant_id == merchant_id,
            Expense.is_voided.is_(False),
            Expense.spent_at >= window.start_utc,
            Expense.spent_at < window.end_utc,
        )
        .order_by(Expense.spent_at)
    ).all()


def build_business_summary(db: Session, merchant_id, window: ResolvedPeriod) -> BusinessSummary:
    sales = _sales_rows(db, merchant_id, window)
    expenses = _expense_rows(db, merchant_id, window)
    daily: dict[date, dict[str, int]] = {}
    cursor = window.start_date
    while cursor <= window.end_date:
        daily[cursor] = {"sales": 0, "expenses": 0, "profit": 0}
        cursor += timedelta(days=1)

    sales_total = gross_profit = 0
    sales_ids = [row.id for row in sales]
    credit_by_sale = dict(
        db.execute(
            select(CreditLedgerEntry.sale_id, func.sum(CreditLedgerEntry.amount))
            .where(
                CreditLedgerEntry.merchant_id == merchant_id,
                CreditLedgerEntry.sale_id.in_(sales_ids),
                CreditLedgerEntry.entry_type == CreditEntryType.CREDIT_SALE,
            )
            .group_by(CreditLedgerEntry.sale_id)
        ).all()
    ) if sales_ids else {}
    collected_from_sales = 0
    for sale in sales:
        local_day = sale.sold_at.astimezone(window.timezone).date()
        sale_total = int(sale.total_amount)
        sale_profit = _round_amount(sale.gross_margin)
        sale_credit = int(credit_by_sale.get(sale.id) or 0)
        sales_total += sale_total
        gross_profit += sale_profit
        collected_from_sales += max(0, sale_total - sale_credit)
        daily[local_day]["sales"] += sale_total
        daily[local_day]["profit"] += sale_profit

    expenses_total = 0
    for spent_at, amount, _ in expenses:
        local_day = spent_at.astimezone(window.timezone).date()
        expenses_total += int(amount)
        daily[local_day]["expenses"] += int(amount)

    credit_totals = db.execute(
        select(
            func.coalesce(
                func.sum(case((CreditLedgerEntry.entry_type == CreditEntryType.CREDIT_SALE,
                               CreditLedgerEntry.amount), else_=0)), 0
            ),
            func.coalesce(
                func.sum(case((CreditLedgerEntry.entry_type == CreditEntryType.REPAYMENT,
                               CreditLedgerEntry.amount), else_=0)), 0
            ),
        ).where(
            CreditLedgerEntry.merchant_id == merchant_id,
            CreditLedgerEntry.occurred_at >= window.start_utc,
            CreditLedgerEntry.occurred_at < window.end_utc,
        )
    ).one()
    outstanding = db.scalar(
        select(
            func.coalesce(
                func.sum(
                    case(
                        (CreditLedgerEntry.entry_type == CreditEntryType.REPAYMENT,
                         -CreditLedgerEntry.amount),
                        else_=CreditLedgerEntry.amount,
                    )
                ),
                0,
            )
        ).where(
            CreditLedgerEntry.merchant_id == merchant_id,
            CreditLedgerEntry.occurred_at < window.end_utc,
        )
    ) or 0

    period_info = window.schema()
    return BusinessSummary(
        **period_info.model_dump(),
        sales_count=len(sales),
        sales_total=sales_total,
        collected_total=collected_from_sales + int(credit_totals[1]),
        credit_created=int(credit_totals[0]),
        credit_repaid=int(credit_totals[1]),
        credit_outstanding=max(0, int(outstanding)),
        estimated_gross_profit=gross_profit,
        expenses_total=expenses_total,
        estimated_net_profit=gross_profit - expenses_total,
        daily_totals=[
            DailyTotals(
                date=day,
                sales_total=values["sales"],
                expenses_total=values["expenses"],
                estimated_gross_profit=values["profit"],
            )
            for day, values in daily.items()
        ],
    )


def stock_quantity_expression():
    signed_quantity = case(
        (StockMovement.movement_type.in_((StockMovementType.ENTRY, StockMovementType.REVERSAL)),
         StockMovement.quantity),
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
