"""Ajoute le journal d’audit de l’étape 1.

Cette révision est additive : les tables métier existantes ne sont pas recréées.
"""

from typing import Sequence, Union

from alembic import op

revision: str = "20261121_01"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS audit_logs (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            merchant_id UUID NULL REFERENCES merchants(id) ON DELETE SET NULL,
            actor_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
            action VARCHAR(100) NOT NULL,
            target_type VARCHAR(80),
            target_id UUID,
            ip_address VARCHAR(45),
            user_agent VARCHAR(500),
            details JSON,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_audit_logs_merchant_created "
        "ON audit_logs (merchant_id, created_at)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_audit_logs_actor_created "
        "ON audit_logs (actor_user_id, created_at)"
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS audit_logs")
