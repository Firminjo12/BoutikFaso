from datetime import UTC, date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import AuthContext, require_path_merchant, require_path_merchant_roles
from app.db.session import get_db
from app.models import Expense, MembershipRole
from app.schemas.finance import ExpenseCreate, ExpenseRead, ExpenseUpdate
from app.services.audit import record_audit
from app.services.reporting import resolve_period

router = APIRouter()
EXPENSE_EDITORS = (MembershipRole.OWNER, MembershipRole.MANAGER)


@router.get("", response_model=list[ExpenseRead])
def list_expenses(
    merchant_id: UUID,
    period: str | None = Query(default=None, pattern="^(today|week|month|custom)$"),
    start_date: date | None = None,
    end_date: date | None = None,
    category: str | None = Query(default=None, max_length=100),
    include_voided: bool = False,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=200),
    context: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> list[ExpenseRead]:
    query = select(Expense).where(Expense.merchant_id == merchant_id)
    if not include_voided:
        query = query.where(Expense.is_voided.is_(False))
    if period is not None or start_date is not None or end_date is not None:
        window = resolve_period(context.merchant, period or "today", start_date, end_date)
        query = query.where(
            Expense.spent_at >= window.start_utc,
            Expense.spent_at < window.end_utc,
        )
    if category and category.strip():
        query = query.where(Expense.category == " ".join(category.split()))
    rows = db.scalars(
        query.order_by(Expense.spent_at.desc(), Expense.created_at.desc())
        .offset(offset)
        .limit(limit)
    ).all()
    return [ExpenseRead.model_validate(row) for row in rows]


@router.get("/categories", response_model=list[str])
def list_expense_categories(
    merchant_id: UUID,
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> list[str]:
    return list(
        db.scalars(
            select(Expense.category)
            .where(Expense.merchant_id == merchant_id, Expense.is_voided.is_(False))
            .distinct()
            .order_by(Expense.category)
        ).all()
    )


@router.post("", response_model=ExpenseRead, status_code=status.HTTP_201_CREATED)
def create_expense(
    merchant_id: UUID,
    payload: ExpenseCreate,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*EXPENSE_EDITORS)),
    db: Session = Depends(get_db),
) -> ExpenseRead:
    spent_at = payload.spent_at.astimezone(UTC) if payload.spent_at else None
    expense = Expense(
        merchant_id=merchant_id,
        created_by_user_id=context.user.id,
        label=payload.label,
        category=payload.category,
        amount=payload.amount,
        note=payload.note.strip() if payload.note and payload.note.strip() else None,
        **({"spent_at": spent_at} if spent_at else {}),
    )
    db.add(expense)
    db.flush()
    record_audit(
        db,
        request,
        "expense.created",
        actor_user_id=context.user.id,
        merchant_id=merchant_id,
        target_type="expense",
        target_id=expense.id,
        details={"category": expense.category, "amount": expense.amount},
    )
    db.commit()
    db.refresh(expense)
    return ExpenseRead.model_validate(expense)


@router.patch("/{expense_id}", response_model=ExpenseRead)
def update_expense(
    merchant_id: UUID,
    expense_id: UUID,
    payload: ExpenseUpdate,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*EXPENSE_EDITORS)),
    db: Session = Depends(get_db),
) -> ExpenseRead:
    expense = db.scalar(
        select(Expense).where(
            Expense.id == expense_id,
            Expense.merchant_id == merchant_id,
            Expense.is_voided.is_(False),
        )
    )
    if expense is None:
        raise HTTPException(status_code=404, detail="Dépense introuvable.")

    changes = payload.model_dump(exclude_unset=True)
    if "note" in changes:
        changes["note"] = changes["note"].strip() if changes["note"] else None
    if "spent_at" in changes:
        changes["spent_at"] = changes["spent_at"].astimezone(UTC)
    for field, value in changes.items():
        setattr(expense, field, value)
    record_audit(
        db,
        request,
        "expense.updated",
        actor_user_id=context.user.id,
        merchant_id=merchant_id,
        target_type="expense",
        target_id=expense.id,
        details={"fields": sorted(changes)},
    )
    db.commit()
    db.refresh(expense)
    return ExpenseRead.model_validate(expense)


@router.delete("/{expense_id}", status_code=status.HTTP_204_NO_CONTENT)
def void_expense(
    merchant_id: UUID,
    expense_id: UUID,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*EXPENSE_EDITORS)),
    db: Session = Depends(get_db),
) -> Response:
    expense = db.scalar(
        select(Expense).where(
            Expense.id == expense_id,
            Expense.merchant_id == merchant_id,
        )
    )
    if expense is None:
        raise HTTPException(status_code=404, detail="Dépense introuvable.")
    if not expense.is_voided:
        expense.is_voided = True
        record_audit(
            db,
            request,
            "expense.voided",
            actor_user_id=context.user.id,
            merchant_id=merchant_id,
            target_type="expense",
            target_id=expense.id,
            details={"category": expense.category, "amount": expense.amount},
        )
        db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
