#!/usr/bin/env bash
set -euo pipefail

BACKEND_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$BACKEND_DIR/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$BACKEND_DIR/.env"
  set +a
fi

: "${DB_HOST:?DB_HOST doit être défini dans backend/.env}"
: "${DB_NAME:?DB_NAME doit être défini dans backend/.env}"
: "${DB_USER:?DB_USER doit être défini dans backend/.env}"
: "${DB_PASSWORD:?DB_PASSWORD doit être défini dans backend/.env}"
DB_PORT="${DB_PORT:-5432}"
BACKUP_DIR="${BACKUP_DIR:-$BACKEND_DIR/backups}"

if ! command -v pg_dump >/dev/null 2>&1; then
  echo "pg_dump est requis pour créer une sauvegarde PostgreSQL." >&2
  exit 1
fi

umask 077
mkdir -p "$BACKUP_DIR"
backup_file="$BACKUP_DIR/boutik-faso-$(date -u +%Y%m%dT%H%M%SZ).dump"

PGPASSWORD="$DB_PASSWORD" PGCONNECT_TIMEOUT=10 pg_dump \
  --host "$DB_HOST" \
  --port "$DB_PORT" \
  --username "$DB_USER" \
  --dbname "$DB_NAME" \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file "$backup_file"

echo "Sauvegarde créée : $backup_file"
