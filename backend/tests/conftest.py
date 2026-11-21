from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.security import create_access_token, hash_password
from app.db.session import get_db
from app.main import app
from app.models.entities import (
    Base,
    MembershipRole,
    Merchant,
    MerchantMembership,
    User,
    UserSession,
)


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(engine)


@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def auth_fixture(db_session):
    user = User(
        id=uuid4(),
        full_name="Firmin Yameogo",
        phone="+22670000000",
        password_hash=hash_password("SuperSecretPass123!"),
        is_active=True,
    )
    merchant = Merchant(
        id=uuid4(),
        name="Boutik Faso Ouaga",
        phone="+22670000001",
        address="Ouagadougou, Secteur 15",
        timezone="Africa/Ouagadougou",
        is_active=True,
    )
    membership = MerchantMembership(
        id=uuid4(),
        user_id=user.id,
        merchant_id=merchant.id,
        role=MembershipRole.OWNER,
        is_active=True,
    )
    session_record = UserSession(
        id=uuid4(),
        user_id=user.id,
        refresh_token_hash="fake_hash",
        expires_at=datetime.now(UTC) + timedelta(days=7),
    )
    db_session.add_all([user, merchant, membership, session_record])
    db_session.commit()

    token = create_access_token(
        str(user.id),
        additional_claims={
            "sid": str(session_record.id),
            "mid": str(merchant.id),
        },
    )
    headers = {"Authorization": f"Bearer {token}"}
    return {
        "user": user,
        "merchant": merchant,
        "membership": membership,
        "token": token,
        "headers": headers,
    }
