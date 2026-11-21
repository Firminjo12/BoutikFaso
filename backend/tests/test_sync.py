from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import uuid4

from app.models.entities import (
    Category,
    Client,
    CreditEntryType,
    CreditLedgerEntry,
    Expense,
    Product,
    RecordStatus,
    Sale,
    StockMovement,
    StockMovementType,
)


def test_sync_status(client, auth_fixture):
    headers = auth_fixture["headers"]
    merchant_id = auth_fixture["merchant"].id

    res = client.get(f"/api/v1/merchants/{merchant_id}/sync/status", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["merchant_id"] == str(merchant_id)
    assert data["total_sync_operations"] == 0
    assert data["is_sync_active"] is True

    # Test direct active merchant route
    res_direct = client.get("/api/v1/sync/status", headers=headers)
    assert res_direct.status_code == 200
    assert res_direct.json()["merchant_id"] == str(merchant_id)


def test_sync_push_sale_and_idempotency(client, auth_fixture, db_session):
    headers = auth_fixture["headers"]
    merchant = auth_fixture["merchant"]
    user = auth_fixture["user"]

    # Création produit avec stock initial
    category = Category(
        id=uuid4(),
        merchant_id=merchant.id,
        name="Boissons",
        status=RecordStatus.ACTIVE,
    )
    product = Product(
        id=uuid4(),
        merchant_id=merchant.id,
        category_id=category.id,
        name="Bissap 50cl",
        sku="BISSAP-50",
        purchase_price=300,
        sale_price=500,
        stock_alert_threshold=Decimal("5.0"),
        status=RecordStatus.ACTIVE,
    )
    initial_stock = StockMovement(
        id=uuid4(),
        merchant_id=merchant.id,
        product_id=product.id,
        created_by_user_id=user.id,
        movement_type=StockMovementType.ENTRY,
        quantity=Decimal("20.0"),
        note="Approvisionnement initial",
    )
    db_session.add_all([category, product, initial_stock])
    db_session.commit()

    op_id = uuid4()
    idempotency_key = "idemp-offline-sale-001"
    push_payload = {
        "device_id": "caisse-ouaga-tab-1",
        "operations": [
            {
                "operation_id": str(op_id),
                "idempotency_key": idempotency_key,
                "operation_type": "sale.create",
                "occurred_at": datetime.now(UTC).isoformat(),
                "payload": {
                    "payment_method": "cash",
                    "lines": [
                        {
                            "product_id": str(product.id),
                            "quantity": 3.0,
                        }
                    ],
                    "discount_amount": 0,
                    "paid_amount": 1500,
                },
            }
        ],
    }

    # Premier envoi
    res = client.post(
        f"/api/v1/merchants/{merchant.id}/sync/push",
        headers=headers,
        json=push_payload,
    )
    assert res.status_code == 200
    body = res.json()
    assert body["processed_count"] == 1
    assert body["applied_count"] == 1
    assert body["duplicate_count"] == 0
    assert body["results"][0]["status"] == "applied"
    assert body["results"][0]["data"]["total_amount"] == 1500

    # Vérification en base
    sale = db_session.get(Sale, op_id)
    assert sale is not None
    assert sale.total_amount == 1500

    # Second envoi identique -> doit renvoyer duplicate sans ré-appliquer
    res2 = client.post(
        f"/api/v1/merchants/{merchant.id}/sync/push",
        headers=headers,
        json=push_payload,
    )
    assert res2.status_code == 200
    body2 = res2.json()
    assert body2["applied_count"] == 0
    assert body2["duplicate_count"] == 1
    assert body2["results"][0]["status"] == "duplicate"


def test_sync_push_partial_errors(client, auth_fixture, db_session):
    headers = auth_fixture["headers"]
    merchant = auth_fixture["merchant"]

    push_payload = {
        "device_id": "caisse-phone-02",
        "operations": [
            {
                "operation_id": str(uuid4()),
                "idempotency_key": "idemp-expense-good-01",
                "operation_type": "expense.create",
                "payload": {
                    "label": "Facture électricité boutique",
                    "category": "Électricité",
                    "amount": 7500,
                    "note": "Paiement SONABEL",
                },
            },
            {
                "operation_id": str(uuid4()),
                "idempotency_key": "idemp-sale-bad-01",
                "operation_type": "sale.create",
                "payload": {
                    "payment_method": "cash",
                    "lines": [
                        {
                            "product_id": str(uuid4()),  # Inexistant
                            "quantity": 1.0,
                        }
                    ],
                },
            },
        ],
    }

    res = client.post("/api/v1/sync/push", headers=headers, json=push_payload)
    assert res.status_code == 200
    body = res.json()
    assert body["processed_count"] == 2
    assert body["applied_count"] == 1
    assert body["rejected_count"] == 1
    assert body["results"][0]["status"] == "applied"
    assert body["results"][1]["status"] == "rejected"

    # Vérifie que la dépense valide a bien été persistée malgré l'erreur sur la vente
    expenses = db_session.query(Expense).filter_by(merchant_id=merchant.id).all()
    assert len(expenses) == 1
    assert expenses[0].amount == 7500


def test_sync_push_credit_repayment_and_conflict(client, auth_fixture, db_session):
    headers = auth_fixture["headers"]
    merchant = auth_fixture["merchant"]
    user = auth_fixture["user"]

    # Création d'un client avec une dette existante
    client_record = Client(
        id=uuid4(),
        merchant_id=merchant.id,
        full_name="Ousmane Sawadogo",
        phone="+22676000000",
        status=RecordStatus.ACTIVE,
    )
    initial_debt = CreditLedgerEntry(
        id=uuid4(),
        merchant_id=merchant.id,
        client_id=client_record.id,
        created_by_user_id=user.id,
        entry_type=CreditEntryType.CREDIT_SALE,
        amount=5000,
        note="Crédit initial",
    )
    db_session.add_all([client_record, initial_debt])
    db_session.commit()

    # Remboursement valide de 3000 FCFA
    push_valid = {
        "device_id": "device-tablet",
        "operations": [
            {
                "operation_id": str(uuid4()),
                "idempotency_key": "repay-part-01",
                "operation_type": "credit.repayment",
                "payload": {
                    "client_id": str(client_record.id),
                    "amount": 3000,
                    "payment_method": "cash",
                    "note": "Remboursement partiel",
                },
            }
        ],
    }
    res = client.post("/api/v1/sync/push", headers=headers, json=push_valid)
    assert res.status_code == 200
    assert res.json()["applied_count"] == 1
    assert res.json()["results"][0]["data"]["remaining_balance"] == 2000

    # Remboursement dépassant le solde restant (4000 > 2000) -> Conflit
    push_conflict = {
        "device_id": "device-tablet",
        "operations": [
            {
                "operation_id": str(uuid4()),
                "idempotency_key": "repay-exceed-02",
                "operation_type": "credit.repayment",
                "payload": {
                    "client_id": str(client_record.id),
                    "amount": 4000,
                    "payment_method": "cash",
                },
            }
        ],
    }
    res2 = client.post("/api/v1/sync/push", headers=headers, json=push_conflict)
    assert res2.status_code == 200
    assert res2.json()["conflict_count"] == 1
    assert res2.json()["results"][0]["status"] == "conflict"


def test_sync_push_optimistic_conflict_on_client_update(client, auth_fixture, db_session):
    headers = auth_fixture["headers"]
    merchant = auth_fixture["merchant"]

    client_record = Client(
        id=uuid4(),
        merchant_id=merchant.id,
        full_name="Awa Kabore",
        phone="+22678000000",
        status=RecordStatus.ACTIVE,
    )
    db_session.add(client_record)
    db_session.commit()

    # Mise à jour sur le serveur pour simuler une modification ultérieure
    old_time = datetime.now(UTC) - timedelta(hours=2)

    push_update = {
        "device_id": "device-tablet",
        "operations": [
            {
                "operation_id": str(uuid4()),
                "idempotency_key": "client-update-conflict-01",
                "operation_type": "client.update",
                "client_updated_at": old_time.isoformat(),
                "payload": {
                    "client_id": str(client_record.id),
                    "full_name": "Awa Kabore Modifiée Hors-Ligne",
                },
            }
        ],
    }
    res = client.post("/api/v1/sync/push", headers=headers, json=push_update)
    assert res.status_code == 200
    assert res.json()["conflict_count"] == 1
    assert res.json()["results"][0]["status"] == "conflict"


def test_sync_pull_incremental(client, auth_fixture, db_session):
    headers = auth_fixture["headers"]
    merchant = auth_fixture["merchant"]

    # 1. Pull initial sans données
    res1 = client.get(f"/api/v1/merchants/{merchant.id}/sync/pull", headers=headers)
    assert res1.status_code == 200
    data1 = res1.json()
    assert len(data1["categories"]) == 0
    assert len(data1["products"]) == 0
    cursor1 = data1["next_cursor"]

    # 2. Ajout d'une catégorie et d'un produit
    cat = Category(id=uuid4(), merchant_id=merchant.id, name="Épicerie", status=RecordStatus.ACTIVE)
    prod = Product(
        id=uuid4(),
        merchant_id=merchant.id,
        category_id=cat.id,
        name="Riz local 5kg",
        purchase_price=2500,
        sale_price=3000,
        stock_alert_threshold=Decimal("2.0"),
        status=RecordStatus.ACTIVE,
    )
    db_session.add_all([cat, prod])
    db_session.commit()

    # 3. Pull incrémental avec le curseur
    res2 = client.get(
        f"/api/v1/merchants/{merchant.id}/sync/pull?cursor={cursor1}",
        headers=headers,
    )
    assert res2.status_code == 200
    data2 = res2.json()
    assert len(data2["categories"]) == 1
    assert data2["categories"][0]["name"] == "Épicerie"
    assert len(data2["products"]) == 1
    assert data2["products"][0]["name"] == "Riz local 5kg"
