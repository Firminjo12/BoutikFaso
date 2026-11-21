from fastapi import APIRouter

from app.api.v1.endpoints import auth, catalog, clients, credit, health, me, merchants, sales, stock

api_router = APIRouter()
api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(me.router, prefix="/me", tags=["account"])
api_router.include_router(merchants.router, prefix="/merchants", tags=["merchants"])
api_router.include_router(catalog.router, prefix="/merchants/{merchant_id}", tags=["catalog"])
api_router.include_router(stock.router, prefix="/merchants/{merchant_id}/stock", tags=["stock"])
api_router.include_router(clients.router, prefix="/merchants/{merchant_id}/clients", tags=["clients"])
api_router.include_router(credit.router, prefix="/merchants/{merchant_id}", tags=["credit"])
api_router.include_router(sales.router, prefix="/merchants/{merchant_id}/sales", tags=["sales"])
