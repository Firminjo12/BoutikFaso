from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.db.session import get_db

router = APIRouter()


@router.get("/live", summary="Vérifier que l’API répond")
def liveness_check() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/ready", summary="Vérifier que l’API peut accéder à PostgreSQL")
def readiness_check(db: Session = Depends(get_db)) -> dict[str, str]:
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="La base de données est indisponible.",
        ) from error
    return {"status": "ready"}
