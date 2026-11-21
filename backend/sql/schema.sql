-- Schéma PostgreSQL de Boutik Faso.
-- À exécuter dans une base PostgreSQL déjà créée et sélectionnée.
-- Ce fichier ne crée pas la base de données.

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(160) NOT NULL,
    email VARCHAR(320) UNIQUE,
    phone VARCHAR(32) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_users_login CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE TABLE merchants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(160) NOT NULL,
    phone VARCHAR(32),
    address VARCHAR(255),
    currency VARCHAR(3) NOT NULL DEFAULT 'XOF',
    timezone VARCHAR(64) NOT NULL DEFAULT 'Africa/Ouagadougou',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE merchant_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    role VARCHAR(24) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_membership_user_merchant UNIQUE (user_id, merchant_id),
    CONSTRAINT ck_membership_role CHECK (role IN ('owner', 'manager', 'cashier', 'stock_manager'))
);

CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_user_sessions_user_id ON user_sessions(user_id);

CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_categories_id_merchant UNIQUE (id, merchant_id),
    CONSTRAINT uq_categories_merchant_name UNIQUE (merchant_id, name),
    CONSTRAINT ck_categories_status CHECK (status IN ('active', 'archived'))
);

CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    category_id UUID,
    name VARCHAR(180) NOT NULL,
    sku VARCHAR(80),
    purchase_price INTEGER NOT NULL DEFAULT 0,
    sale_price INTEGER NOT NULL,
    stock_alert_threshold NUMERIC(12, 3) NOT NULL DEFAULT 0,
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_products_id_merchant UNIQUE (id, merchant_id),
    CONSTRAINT uq_products_merchant_sku UNIQUE (merchant_id, sku),
    CONSTRAINT fk_products_category_same_merchant
        FOREIGN KEY (category_id, merchant_id)
        REFERENCES categories(id, merchant_id) ON DELETE RESTRICT,
    CONSTRAINT ck_products_purchase_price_nonnegative CHECK (purchase_price >= 0),
    CONSTRAINT ck_products_sale_price_nonnegative CHECK (sale_price >= 0),
    CONSTRAINT ck_products_stock_threshold_nonnegative CHECK (stock_alert_threshold >= 0),
    CONSTRAINT ck_products_status CHECK (status IN ('active', 'archived'))
);
CREATE INDEX ix_products_merchant_name ON products(merchant_id, name);

CREATE TABLE product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL,
    product_id UUID NOT NULL,
    storage_key VARCHAR(500) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    size_bytes INTEGER NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_product_images_product_same_merchant
        FOREIGN KEY (product_id, merchant_id)
        REFERENCES products(id, merchant_id) ON DELETE CASCADE,
    CONSTRAINT uq_product_images_order UNIQUE (product_id, display_order),
    CONSTRAINT ck_product_images_size_positive CHECK (size_bytes > 0)
);

CREATE TABLE clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    full_name VARCHAR(160) NOT NULL,
    phone VARCHAR(32),
    address VARCHAR(255),
    notes TEXT,
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_clients_id_merchant UNIQUE (id, merchant_id),
    CONSTRAINT ck_clients_status CHECK (status IN ('active', 'archived'))
);
CREATE INDEX ix_clients_merchant_name ON clients(merchant_id, full_name);

CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    client_id UUID,
    created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    receipt_number VARCHAR(64) NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'completed',
    payment_method VARCHAR(24) NOT NULL,
    subtotal INTEGER NOT NULL,
    discount_amount INTEGER NOT NULL DEFAULT 0,
    total_amount INTEGER NOT NULL,
    sold_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    idempotency_key VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_sales_id_merchant UNIQUE (id, merchant_id),
    CONSTRAINT uq_sales_merchant_receipt UNIQUE (merchant_id, receipt_number),
    CONSTRAINT uq_sales_merchant_idempotency UNIQUE (merchant_id, idempotency_key),
    CONSTRAINT fk_sales_client_same_merchant
        FOREIGN KEY (client_id, merchant_id)
        REFERENCES clients(id, merchant_id) ON DELETE RESTRICT,
    CONSTRAINT ck_sales_amounts_nonnegative
        CHECK (subtotal >= 0 AND discount_amount >= 0 AND total_amount >= 0),
    CONSTRAINT ck_sales_total_matches CHECK (total_amount = subtotal - discount_amount),
    CONSTRAINT ck_sales_status CHECK (status IN ('completed', 'voided')),
    CONSTRAINT ck_sales_payment_method
        CHECK (payment_method IN ('cash', 'orange_money', 'moov_money', 'credit')),
    CONSTRAINT ck_credit_sale_requires_client
        CHECK (payment_method <> 'credit' OR client_id IS NOT NULL)
);
CREATE INDEX ix_sales_merchant_sold_at ON sales(merchant_id, sold_at);

CREATE TABLE sale_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL,
    sale_id UUID NOT NULL,
    product_id UUID,
    product_name VARCHAR(180) NOT NULL,
    quantity NUMERIC(12, 3) NOT NULL,
    unit_sale_price INTEGER NOT NULL,
    unit_purchase_price INTEGER NOT NULL,
    line_total INTEGER NOT NULL,
    CONSTRAINT fk_sale_lines_sale_same_merchant
        FOREIGN KEY (sale_id, merchant_id)
        REFERENCES sales(id, merchant_id) ON DELETE CASCADE,
    CONSTRAINT fk_sale_lines_product_same_merchant
        FOREIGN KEY (product_id, merchant_id)
        REFERENCES products(id, merchant_id) ON DELETE RESTRICT,
    CONSTRAINT ck_sale_lines_quantity_positive CHECK (quantity > 0),
    CONSTRAINT ck_sale_lines_amounts_nonnegative
        CHECK (unit_sale_price >= 0 AND unit_purchase_price >= 0 AND line_total >= 0)
);
CREATE INDEX ix_sale_lines_sale ON sale_lines(sale_id);

CREATE TABLE stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL,
    product_id UUID NOT NULL,
    created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    sale_id UUID,
    movement_type VARCHAR(16) NOT NULL,
    quantity NUMERIC(12, 3) NOT NULL,
    note TEXT,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_stock_movements_product_same_merchant
        FOREIGN KEY (product_id, merchant_id)
        REFERENCES products(id, merchant_id) ON DELETE RESTRICT,
    CONSTRAINT fk_stock_movements_sale_same_merchant
        FOREIGN KEY (sale_id, merchant_id)
        REFERENCES sales(id, merchant_id) ON DELETE RESTRICT,
    CONSTRAINT ck_stock_movements_quantity_positive CHECK (quantity > 0),
    CONSTRAINT ck_stock_movements_type
        CHECK (movement_type IN ('entry', 'exit', 'loss', 'sale', 'reversal'))
);
CREATE INDEX ix_stock_movements_merchant_time ON stock_movements(merchant_id, occurred_at);

CREATE TABLE credit_ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL,
    client_id UUID NOT NULL,
    sale_id UUID,
    created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    entry_type VARCHAR(20) NOT NULL,
    amount INTEGER NOT NULL,
    payment_method VARCHAR(24),
    note TEXT,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_credit_entries_client_same_merchant
        FOREIGN KEY (client_id, merchant_id)
        REFERENCES clients(id, merchant_id) ON DELETE RESTRICT,
    CONSTRAINT fk_credit_entries_sale_same_merchant
        FOREIGN KEY (sale_id, merchant_id)
        REFERENCES sales(id, merchant_id) ON DELETE RESTRICT,
    CONSTRAINT ck_credit_entries_amount_positive CHECK (amount > 0),
    CONSTRAINT ck_credit_entries_type
        CHECK (entry_type IN ('credit_sale', 'repayment', 'adjustment', 'reversal')),
    CONSTRAINT ck_credit_entries_payment_method
        CHECK (payment_method IS NULL OR payment_method IN ('cash', 'orange_money', 'moov_money', 'credit'))
);
CREATE INDEX ix_credit_entries_client_time
    ON credit_ledger_entries(merchant_id, client_id, occurred_at);

CREATE TABLE expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    label VARCHAR(180) NOT NULL,
    category VARCHAR(100) NOT NULL,
    amount INTEGER NOT NULL,
    note TEXT,
    spent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_voided BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_expenses_amount_positive CHECK (amount > 0)
);
CREATE INDEX ix_expenses_merchant_time ON expenses(merchant_id, spent_at);

CREATE TABLE sync_operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    device_id VARCHAR(128) NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    operation_type VARCHAR(80) NOT NULL,
    response_payload TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_sync_operation_key UNIQUE (merchant_id, device_id, idempotency_key)
);
CREATE INDEX ix_sync_operations_merchant_created ON sync_operations(merchant_id, created_at);

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID REFERENCES merchants(id) ON DELETE SET NULL,
    actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(80),
    target_id UUID,
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    details JSON,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_audit_logs_merchant_created ON audit_logs(merchant_id, created_at);
CREATE INDEX ix_audit_logs_actor_created ON audit_logs(actor_user_id, created_at);
