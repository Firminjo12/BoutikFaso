from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import AuthContext, get_current_context
from app.db.session import get_db
from app.models import Merchant, MerchantMembership, MembershipRole
from app.schemas.auth import MerchantCreate, MerchantRead, TokenResponse
from app.services.audit import record_audit
from app.services.tokens import issue_session_tokens

router = APIRouter()


@router.post(
    "",
    response_model=MerchantRead,
    status_code=status.HTTP_201_CREATED,
    summary="Créer une boutique pour le compte connecté",
)
def create_merchant(
    payload: MerchantCreate,
    request: Request,
    context: AuthContext = Depends(get_current_context),
    db: Session = Depends(get_db),
) -> MerchantRead:
    merchant = Merchant(
        name=payload.name,
        phone=payload.phone.strip() if payload.phone else None,
        address=payload.address.strip() if payload.address else None,
    )
    db.add(merchant)
    db.flush()
    membership = MerchantMembership(
        user_id=context.user.id,
        merchant_id=merchant.id,
        role=MembershipRole.OWNER,
        is_active=True,
    )
    db.add(membership)
    record_audit(
        db,
        request,
        "merchant.created",
        actor_user_id=context.user.id,
        merchant_id=merchant.id,
        target_type="merchant",
        target_id=merchant.id,
    )
    db.commit()
    db.refresh(merchant)
    return MerchantRead.model_validate(merchant)


@router.post(
    "/{merchant_id}/switch",
    response_model=TokenResponse,
    summary="Sélectionner une boutique active",
)
def switch_merchant(
    merchant_id: UUID,
    request: Request,
    context: AuthContext = Depends(get_current_context),
    db: Session = Depends(get_db),
) -> TokenResponse:
    membership = db.scalar(
        select(MerchantMembership).where(
            MerchantMembership.user_id == context.user.id,
            MerchantMembership.merchant_id == merchant_id,
            MerchantMembership.is_active.is_(True),
        )
    )
    merchant = db.get(Merchant, merchant_id)
    if membership is None or merchant is None or not merchant.is_active:
        raise HTTPException(status_code=404, detail="Boutique introuvable.")

    tokens = issue_session_tokens(db, context.user, context.session, merchant.id)
    record_audit(
        db,
        request,
        "merchant.switched",
        actor_user_id=context.user.id,
        merchant_id=merchant.id,
        target_type="merchant",
        target_id=merchant.id,
        details={"role": membership.role.value},
    )
    db.commit()
    return tokens
