"""Modèles métier SQLAlchemy. Aucun modèle ne crée de base de données."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    JSON,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


def enum_values(enum_class: type[StrEnum]) -> list[str]:
    return [item.value for item in enum_class]


class MembershipRole(StrEnum):
    OWNER = "owner"
    MANAGER = "manager"
    CASHIER = "cashier"
    STOCK_MANAGER = "stock_manager"


class RecordStatus(StrEnum):
    ACTIVE = "active"
    ARCHIVED = "archived"


class StockMovementType(StrEnum):
    ENTRY = "entry"
    EXIT = "exit"
    LOSS = "loss"
    SALE = "sale"
    REVERSAL = "reversal"


class SaleStatus(StrEnum):
    COMPLETED = "completed"
    VOIDED = "voided"


class PaymentMethod(StrEnum):
    CASH = "cash"
    ORANGE_MONEY = "orange_money"
    MOOV_MONEY = "moov_money"
    CREDIT = "credit"


class CreditEntryType(StrEnum):
    CREDIT_SALE = "credit_sale"
    REPAYMENT = "repayment"
    ADJUSTMENT = "adjustment"
    REVERSAL = "reversal"


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    full_name: Mapped[str] = mapped_column(String(160), nullable=False)
    email: Mapped[str | None] = mapped_column(String(320), unique=True)
    phone: Mapped[str | None] = mapped_column(String(32), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    __table_args__ = (
        CheckConstraint("email IS NOT NULL OR phone IS NOT NULL", name="ck_users_login"),
    )


class Merchant(TimestampMixin, Base):
    __tablename__ = "merchants"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(32))
    address: Mapped[str | None] = mapped_column(String(255))
    currency: Mapped[str] = mapped_column(String(3), default="XOF", nullable=False)
    timezone: Mapped[str] = mapped_column(String(64), default="Africa/Ouagadougou", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class MerchantMembership(TimestampMixin, Base):
    __tablename__ = "merchant_memberships"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    merchant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("merchants.id", ondelete="CASCADE"))
    role: Mapped[MembershipRole] = mapped_column(
        Enum(
            MembershipRole,
            native_enum=False,
            length=24,
            values_callable=enum_values,
        ),
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    __table_args__ = (UniqueConstraint("user_id", "merchant_id", name="uq_membership_user_merchant"),)


class UserSession(Base):
    __tablename__ = "user_sessions"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    refresh_token_hash: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    merchant_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("merchants.id", ondelete="SET NULL")
    )
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL")
    )
    action: Mapped[str] = mapped_column(String(100), nullable=False)
    target_type: Mapped[str | None] = mapped_column(String(80))
    target_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)
    ip_address: Mapped[str | None] = mapped_column(String(45))
    user_agent: Mapped[str | None] = mapped_column(String(500))
    details: Mapped[dict[str, object] | None] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (
        Index("ix_audit_logs_merchant_created", "merchant_id", "created_at"),
        Index("ix_audit_logs_actor_created", "actor_user_id", "created_at"),
    )


class Category(TimestampMixin, Base):
    __tablename__ = "categories"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    merchant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("merchants.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    status: Mapped[RecordStatus] = mapped_column(
        Enum(RecordStatus, native_enum=False, length=16, values_callable=enum_values),
        default=RecordStatus.ACTIVE,
        nullable=False,
    )

    __table_args__ = (UniqueConstraint("id", "merchant_id", name="uq_categories_id_merchant"),
                      UniqueConstraint("merchant_id", "name", name="uq_categories_merchant_name"))


class Product(TimestampMixin, Base):
    __tablename__ = "products"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    merchant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("merchants.id", ondelete="CASCADE"))
    category_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    sku: Mapped[str | None] = mapped_column(String(80))
    purchase_price: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    sale_price: Mapped[int] = mapped_column(Integer, nullable=False)
    stock_alert_threshold: Mapped[Decimal] = mapped_column(Numeric(12, 3), default=0, nullable=False)
    status: Mapped[RecordStatus] = mapped_column(
        Enum(RecordStatus, native_enum=False, length=16, values_callable=enum_values),
        default=RecordStatus.ACTIVE,
        nullable=False,
    )

    __table_args__ = (
        UniqueConstraint("id", "merchant_id", name="uq_products_id_merchant"),
        UniqueConstraint("merchant_id", "sku", name="uq_products_merchant_sku"),
        ForeignKeyConstraint(
            ["category_id", "merchant_id"],
            ["categories.id", "categories.merchant_id"],
            name="fk_products_category_same_merchant",
            ondelete="RESTRICT",
        ),
        CheckConstraint("purchase_price >= 0", name="ck_products_purchase_price_nonnegative"),
        CheckConstraint("sale_price >= 0", name="ck_products_sale_price_nonnegative"),
        CheckConstraint("stock_alert_threshold >= 0", name="ck_products_stock_threshold_nonnegative"),
        Index("ix_products_merchant_name", "merchant_id", "name"),
    )


class ProductImage(Base):
    __tablename__ = "product_images"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    merchant_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    product_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    storage_key: Mapped[str] = mapped_column(String(500), nullable=False)
    content_type: Mapped[str] = mapped_column(String(100), nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    display_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        ForeignKeyConstraint(["product_id", "merchant_id"], ["products.id", "products.merchant_id"],
                             name="fk_product_images_product_same_merchant", ondelete="CASCADE"),
        UniqueConstraint("product_id", "display_order", name="uq_product_images_order"),
        CheckConstraint("size_bytes > 0", name="ck_product_images_size_positive"),
    )


class Client(TimestampMixin, Base):
    __tablename__ = "clients"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    merchant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("merchants.id", ondelete="CASCADE"))
    full_name: Mapped[str] = mapped_column(String(160), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(32))
    address: Mapped[str | None] = mapped_column(String(255))
    notes: Mapped[str | None] = mapped_column(Text)
    status: Mapped[RecordStatus] = mapped_column(
        Enum(RecordStatus, native_enum=False, length=16, values_callable=enum_values),
        default=RecordStatus.ACTIVE,
        nullable=False,
    )

    __table_args__ = (UniqueConstraint("id", "merchant_id", name="uq_clients_id_merchant"),
                      Index("ix_clients_merchant_name", "merchant_id", "full_name"))


class Sale(TimestampMixin, Base):
    __tablename__ = "sales"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    merchant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("merchants.id", ondelete="CASCADE"))
    client_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    receipt_number: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[SaleStatus] = mapped_column(
        Enum(SaleStatus, native_enum=False, length=16, values_callable=enum_values),
        default=SaleStatus.COMPLETED,
        nullable=False,
    )
    payment_method: Mapped[PaymentMethod] = mapped_column(
        Enum(PaymentMethod, native_enum=False, length=24, values_callable=enum_values),
        nullable=False,
    )
    subtotal: Mapped[int] = mapped_column(Integer, nullable=False)
    discount_amount: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_amount: Mapped[int] = mapped_column(Integer, nullable=False)
    sold_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    idempotency_key: Mapped[str | None] = mapped_column(String(128))

    __table_args__ = (
        UniqueConstraint("id", "merchant_id", name="uq_sales_id_merchant"),
        UniqueConstraint("merchant_id", "receipt_number", name="uq_sales_merchant_receipt"),
        UniqueConstraint("merchant_id", "idempotency_key", name="uq_sales_merchant_idempotency"),
        ForeignKeyConstraint(["client_id", "merchant_id"], ["clients.id", "clients.merchant_id"],
                             name="fk_sales_client_same_merchant", ondelete="RESTRICT"),
        CheckConstraint("subtotal >= 0 AND discount_amount >= 0 AND total_amount >= 0",
                        name="ck_sales_amounts_nonnegative"),
        CheckConstraint("total_amount = subtotal - discount_amount", name="ck_sales_total_matches"),
        Index("ix_sales_merchant_sold_at", "merchant_id", "sold_at"),
    )


class SaleLine(Base):
    __tablename__ = "sale_lines"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    merchant_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    sale_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    product_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)
    product_name: Mapped[str] = mapped_column(String(180), nullable=False)
    quantity: Mapped[Decimal] = mapped_column(Numeric(12, 3), nullable=False)
    unit_sale_price: Mapped[int] = mapped_column(Integer, nullable=False)
    unit_purchase_price: Mapped[int] = mapped_column(Integer, nullable=False)
    line_total: Mapped[int] = mapped_column(Integer, nullable=False)

    __table_args__ = (
        ForeignKeyConstraint(["sale_id", "merchant_id"], ["sales.id", "sales.merchant_id"],
                             name="fk_sale_lines_sale_same_merchant", ondelete="CASCADE"),
        ForeignKeyConstraint(["product_id", "merchant_id"], ["products.id", "products.merchant_id"],
                             name="fk_sale_lines_product_same_merchant", ondelete="RESTRICT"),
        CheckConstraint("quantity > 0", name="ck_sale_lines_quantity_positive"),
        CheckConstraint("unit_sale_price >= 0 AND unit_purchase_price >= 0 AND line_total >= 0",
                        name="ck_sale_lines_amounts_nonnegative"),
        Index("ix_sale_lines_sale", "sale_id"),
    )


class StockMovement(Base):
    __tablename__ = "stock_movements"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    merchant_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    product_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    sale_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)
    movement_type: Mapped[StockMovementType] = mapped_column(
        Enum(StockMovementType, native_enum=False, length=16, values_callable=enum_values),
        nullable=False,
    )
    quantity: Mapped[Decimal] = mapped_column(Numeric(12, 3), nullable=False)
    note: Mapped[str | None] = mapped_column(Text)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        ForeignKeyConstraint(["product_id", "merchant_id"], ["products.id", "products.merchant_id"],
                             name="fk_stock_movements_product_same_merchant", ondelete="RESTRICT"),
        ForeignKeyConstraint(["sale_id", "merchant_id"], ["sales.id", "sales.merchant_id"],
                             name="fk_stock_movements_sale_same_merchant", ondelete="RESTRICT"),
        CheckConstraint("quantity > 0", name="ck_stock_movements_quantity_positive"),
        Index("ix_stock_movements_merchant_time", "merchant_id", "occurred_at"),
    )


class CreditLedgerEntry(Base):
    __tablename__ = "credit_ledger_entries"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    merchant_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    client_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    sale_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    entry_type: Mapped[CreditEntryType] = mapped_column(
        Enum(CreditEntryType, native_enum=False, length=20, values_callable=enum_values),
        nullable=False,
    )
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    payment_method: Mapped[PaymentMethod | None] = mapped_column(
        Enum(PaymentMethod, native_enum=False, length=24, values_callable=enum_values)
    )
    note: Mapped[str | None] = mapped_column(Text)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        ForeignKeyConstraint(["client_id", "merchant_id"], ["clients.id", "clients.merchant_id"],
                             name="fk_credit_entries_client_same_merchant", ondelete="RESTRICT"),
        ForeignKeyConstraint(["sale_id", "merchant_id"], ["sales.id", "sales.merchant_id"],
                             name="fk_credit_entries_sale_same_merchant", ondelete="RESTRICT"),
        CheckConstraint("amount > 0", name="ck_credit_entries_amount_positive"),
        Index("ix_credit_entries_client_time", "merchant_id", "client_id", "occurred_at"),
    )


class Expense(TimestampMixin, Base):
    __tablename__ = "expenses"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    merchant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("merchants.id", ondelete="CASCADE"))
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    label: Mapped[str] = mapped_column(String(180), nullable=False)
    category: Mapped[str] = mapped_column(String(100), nullable=False)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    note: Mapped[str | None] = mapped_column(Text)
    spent_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    is_voided: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    __table_args__ = (
        CheckConstraint("amount > 0", name="ck_expenses_amount_positive"),
        Index("ix_expenses_merchant_time", "merchant_id", "spent_at"),
    )


class SyncOperation(Base):
    __tablename__ = "sync_operations"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    merchant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("merchants.id", ondelete="CASCADE"))
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    device_id: Mapped[str] = mapped_column(String(128), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    operation_type: Mapped[str] = mapped_column(String(80), nullable=False)
    response_payload: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("merchant_id", "device_id", "idempotency_key", name="uq_sync_operation_key"),
        Index("ix_sync_operations_merchant_created", "merchant_id", "created_at"),
    )
