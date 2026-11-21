from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class ExpenseCreate(BaseModel):
    label: str = Field(min_length=1, max_length=180)
    category: str = Field(min_length=1, max_length=100)
    amount: int = Field(gt=0)
    note: str | None = Field(default=None, max_length=4000)
    spent_at: datetime | None = None

    @field_validator("label", "category")
    @classmethod
    def clean_required_text(cls, value: str) -> str:
        value = " ".join(value.split())
        if not value:
            raise ValueError("Ce champ est obligatoire.")
        return value

    @field_validator("spent_at")
    @classmethod
    def require_timezone(cls, value: datetime | None) -> datetime | None:
        if value is not None and value.tzinfo is None:
            raise ValueError("La date doit inclure un fuseau horaire.")
        return value


class ExpenseUpdate(BaseModel):
    label: str | None = Field(default=None, min_length=1, max_length=180)
    category: str | None = Field(default=None, min_length=1, max_length=100)
    amount: int | None = Field(default=None, gt=0)
    note: str | None = Field(default=None, max_length=4000)
    spent_at: datetime | None = None

    @model_validator(mode="after")
    def validate_changes(self) -> "ExpenseUpdate":
        if not self.model_fields_set:
            raise ValueError("Indiquez au moins un champ à modifier.")
        for field in ("label", "category", "amount", "spent_at"):
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"Le champ {field} ne peut pas être nul.")
        if self.spent_at is not None and self.spent_at.tzinfo is None:
            raise ValueError("La date doit inclure un fuseau horaire.")
        for field in ("label", "category"):
            value = getattr(self, field)
            if value is not None:
                value = " ".join(value.split())
                if not value:
                    raise ValueError("Ce champ est obligatoire.")
                setattr(self, field, value)
        return self


class ExpenseRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    merchant_id: UUID
    label: str
    category: str
    amount: int
    note: str | None
    spent_at: datetime
    is_voided: bool
    created_at: datetime


class ReportPeriod(BaseModel):
    period: str
    start_date: date
    end_date: date
    timezone: str


class DailyTotals(BaseModel):
    date: date
    sales_total: int
    expenses_total: int
    estimated_gross_profit: int


class TopProduct(BaseModel):
    product_name: str
    quantity_sold: Decimal
    sales_total: int


class BusinessSummary(ReportPeriod):
    sales_count: int
    sales_total: int
    collected_total: int
    credit_created: int
    credit_repaid: int
    credit_outstanding: int
    estimated_gross_profit: int
    expenses_total: int
    estimated_net_profit: int
    daily_totals: list[DailyTotals]


class DashboardRead(BusinessSummary):
    low_stock_products: int
    out_of_stock_products: int
    top_products: list[TopProduct]


class ExpenseCategoryTotal(BaseModel):
    category: str
    amount: int


class ExpensesReport(ReportPeriod):
    expenses_total: int
    expense_count: int
    by_category: list[ExpenseCategoryTotal]
    daily_totals: list[DailyTotals]


class StockReport(ReportPeriod):
    current_units: Decimal
    purchase_value: int
    sale_value: int
    entries: Decimal
    exits: Decimal
    losses: Decimal
    low_stock_products: int
    out_of_stock_products: int
