-- Extension du schéma existant pour le journal d’audit de l’étape 1.
-- Exécuter dans la base déjà créée si audit_logs n’existe pas.

CREATE TABLE IF NOT EXISTS audit_logs (
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

CREATE INDEX IF NOT EXISTS ix_audit_logs_merchant_created
    ON audit_logs (merchant_id, created_at);
CREATE INDEX IF NOT EXISTS ix_audit_logs_actor_created
    ON audit_logs (actor_user_id, created_at);
