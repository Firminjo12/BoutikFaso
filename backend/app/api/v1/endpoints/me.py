from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import AuthContext, get_current_context
from app.db.session import get_db
from app.models import Merchant, MerchantMembership
from app.schemas.auth import (
    MeResponse,
    MerchantMembershipRead,
    MerchantRead,
    UserRead,
)

router = APIRouter()


@router.get("", response_model=MeResponse, summary="Afficher le compte et la boutique active")
def read_me(context: AuthContext = Depends(get_current_context)) -> MeResponse:
    return MeResponse(
        user=UserRead.model_validate(context.user),
        active_merchant=(
            MerchantRead.model_validate(context.merchant) if context.merchant else None
        ),
        role=context.membership.role.value if context.membership else None,
    )


@router.get(
    "/merchants",
    response_model=list[MerchantMembershipRead],
    summary="Lister les boutiques accessibles au compte connecté",
)
def list_my_merchants(
    context: AuthContext = Depends(get_current_context),
    db: Session = Depends(get_db),
) -> list[MerchantMembershipRead]:
    rows = db.execute(
        select(MerchantMembership, Merchant)
        .join(Merchant, Merchant.id == MerchantMembership.merchant_id)
        .where(
            MerchantMembership.user_id == context.user.id,
            MerchantMembership.is_active.is_(True),
            Merchant.is_active.is_(True),
        )
        .order_by(Merchant.name)
    ).all()
    return [
        MerchantMembershipRead(
            merchant=MerchantRead.model_validate(merchant),
            role=membership.role.value,
            is_active=membership.is_active,
            joined_at=membership.created_at,
        )
        for membership, merchant in rows
    ]
