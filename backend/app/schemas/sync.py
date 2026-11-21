from datetime import datetime
from decimal import Decimal
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, Field


SyncOperationType = Literal[
    "sale.create",
    "credit.repayment",
    "expense.create",
    "client.create",
    "client.update",
    "product.create",
    "product.update",
    "category.create",
    "stock.movement",
]

SyncStatus = Literal["applied", "duplicate", "conflict", "rejected"]


class SyncOperationItem(BaseModel):
    operation_id: UUID
    idempotency_key: str = Field(min_length=8, max_length=128)
    operation_type: SyncOperationType
    payload: dict[str, Any]
    occurred_at: datetime | None = None
    client_updated_at: datetime | None = None


class SyncPushRequest(BaseModel):
    device_id: str = Field(min_length=1, max_length=128)
    operations: list[SyncOperationItem] = Field(min_length=1, max_length=500)


class SyncOperationResult(BaseModel):
    operation_id: UUID
    idempotency_key: str
    operation_type: str
    status: SyncStatus
    entity_id: UUID | None = None
    message: str | None = None
    data: dict[str, Any] | None = None


class SyncPushResponse(BaseModel):
    server_time: datetime
    new_cursor: str
    processed_count: int
    applied_count: int
    duplicate_count: int
    conflict_count: int
    rejected_count: int
    results: list[SyncOperationResult]


class SyncPullResponse(BaseModel):
    server_time: datetime
    cursor: str | None
    next_cursor: str
    has_more: bool
    categories: list[dict[str, Any]]
    products: list[dict[str, Any]]
    clients: list[dict[str, Any]]
    sales: list[dict[str, Any]]
    credit_entries: list[dict[str, Any]]
    expenses: list[dict[str, Any]]
    stock_movements: list[dict[str, Any]]


class SyncStatusResponse(BaseModel):
    merchant_id: UUID
    device_id: str | None
    server_time: datetime
    last_sync_at: datetime | None
    total_sync_operations: int
    device_sync_operations_count: int
    is_sync_active: bool = True
