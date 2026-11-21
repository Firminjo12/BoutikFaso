from datetime import datetime
from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator


PaymentMethodValue = Literal["cash", "orange_money", "moov_money", "credit"]


class ClientCreate(BaseModel):
    full_name: str = Field(min_length=2, max_length=160)
    phone: str | None = Field(default=None, max_length=32)
    address: str | None = Field(default=None, max_length=255)
    notes: str | None = Field(default=None, max_length=4000)

    @field_validator("full_name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        value = " ".join(value.split())
        if len(value) < 2:
            raise ValueError("Le nom du client est obligatoire.")
        return value


class ClientUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=160)
    phone: str | None = Field(default=None, max_length=32)
    address: str | None = Field(default=None, max_length=255)
    notes: str | None = Field(default=None, max_length=4000)

    @model_validator(mode="after")
    def validate_changes(self) -> "ClientUpdate":
        if not self.model_fields_set:
            raise ValueError("Indiquez au moins un champ à modifier.")
        if "full_name" in self.model_fields_set:
            if self.full_name is None or len(" ".join(self.full_name.split())) < 2:
                raise ValueError("Le nom du client doit contenir au moins 2 caractères.")
            self.full_name = " ".join(self.full_name.split())
        return self


class ClientRead(BaseModel):
    id: UUID
    merchant_id: UUID
    full_name: str
    phone: str | None
    address: str | None
    notes: str | None
    status: str
    credit_balance: int
    created_at: datetime


class SaleLineCreate(BaseModel):
    product_id: UUID
    quantity: Decimal = Field(gt=0, max_digits=12, decimal_places=3)


class SaleCreate(BaseModel):
    client_id: UUID | None = None
    payment_method: PaymentMethodValue
    lines: list[SaleLineCreate] = Field(min_length=1, max_length=100)
    discount_amount: int = Field(default=0, ge=0)
    paid_amount: int | None = Field(default=None, ge=0)

    @model_validator(mode="after")
    def validate_payment(self) -> "SaleCreate":
        if self.payment_method == "credit" and self.paid_amount not in (None, 0):
            raise ValueError("Une vente entièrement à crédit ne peut pas avoir de paiement immédiat.")
        if len({line.product_id for line in self.lines}) != len(self.lines):
            raise ValueError("Regroupez les quantités du même produit sur une seule ligne.")
        return self


class SaleLineRead(BaseModel):
    product_id: UUID
    product_name: str
    quantity: Decimal
    unit_sale_price: int
    unit_purchase_price: int
    line_total: int


class SaleRead(BaseModel):
    id: UUID
    receipt_number: str
    client_id: UUID | None
    client_name: str | None
    status: str
    payment_method: str
    subtotal: int
    discount_amount: int
    total_amount: int
    paid_amount: int
    credit_created: int
    sold_at: datetime
    lines: list[SaleLineRead]


class RepaymentCreate(BaseModel):
    amount: int = Field(gt=0)
    payment_method: Literal["cash", "orange_money", "moov_money"]
    note: str | None = Field(default=None, max_length=2000)


class CreditLedgerRead(BaseModel):
    id: UUID
    client_id: UUID
    sale_id: UUID | None
    entry_type: str
    amount: int
    payment_method: str | None
    note: str | None
    occurred_at: datetime


class CreditSummary(BaseModel):
    client: ClientRead
    ledger: list[CreditLedgerRead]
