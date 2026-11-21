from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        value = " ".join(value.split())
        if not value:
            raise ValueError("Le nom de catégorie est obligatoire.")
        return value


class CategoryUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=100)

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        value = " ".join(value.split())
        if not value:
            raise ValueError("Le nom de catégorie est obligatoire.")
        return value


class CategoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    status: str


class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=180)
    category_id: UUID | None = None
    sku: str | None = Field(default=None, max_length=80)
    purchase_price: int = Field(default=0, ge=0)
    sale_price: int = Field(ge=0)
    stock_alert_threshold: Decimal = Field(default=Decimal("0"), ge=0, max_digits=12, decimal_places=3)
    initial_quantity: Decimal = Field(default=Decimal("0"), ge=0, max_digits=12, decimal_places=3)

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        value = " ".join(value.split())
        if not value:
            raise ValueError("Le nom du produit est obligatoire.")
        return value

    @field_validator("sku")
    @classmethod
    def clean_sku(cls, value: str | None) -> str | None:
        value = value.strip() if value else None
        return value or None


class ProductUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=180)
    category_id: UUID | None = None
    sku: str | None = Field(default=None, max_length=80)
    purchase_price: int | None = Field(default=None, ge=0)
    sale_price: int | None = Field(default=None, ge=0)
    stock_alert_threshold: Decimal | None = Field(default=None, ge=0, max_digits=12, decimal_places=3)

    @model_validator(mode="after")
    def validate_changes(self) -> "ProductUpdate":
        if not self.model_fields_set:
            raise ValueError("Indiquez au moins un champ à modifier.")
        for field in ("name", "purchase_price", "sale_price", "stock_alert_threshold"):
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"Le champ {field} ne peut pas être nul.")
        return self

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = " ".join(value.split())
        if not value:
            raise ValueError("Le nom du produit est obligatoire.")
        return value

    @field_validator("sku")
    @classmethod
    def clean_sku(cls, value: str | None) -> str | None:
        value = value.strip() if value else None
        return value or None


class ProductImageRead(BaseModel):
    id: UUID
    url: str
    content_type: str
    size_bytes: int
    display_order: int


class ProductRead(BaseModel):
    id: UUID
    merchant_id: UUID
    category_id: UUID | None
    category_name: str | None
    name: str
    sku: str | None
    purchase_price: int
    sale_price: int
    stock_alert_threshold: Decimal
    quantity: Decimal
    status: str
    image: ProductImageRead | None = None
    created_at: datetime
    updated_at: datetime


class StockMovementCreate(BaseModel):
    product_id: UUID
    movement_type: str = Field(pattern="^(entry|exit|loss)$")
    quantity: Decimal = Field(gt=0, max_digits=12, decimal_places=3)
    note: str | None = Field(default=None, max_length=2000)


class StockMovementRead(BaseModel):
    id: UUID
    product_id: UUID
    product_name: str
    movement_type: str
    quantity: Decimal
    note: str | None
    occurred_at: datetime


class StockSummary(BaseModel):
    total_units: Decimal
    entries: Decimal
    exits: Decimal
    losses: Decimal
    low_stock_products: int
    out_of_stock_products: int


class ProductStockRead(BaseModel):
    product_id: UUID
    product_name: str
    quantity: Decimal
    alert_threshold: Decimal
