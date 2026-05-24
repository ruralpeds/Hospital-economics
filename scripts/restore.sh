#!/usr/bin/env bash
#
# restore.sh — Point-in-time PostgreSQL restore from S3 backup.
#
# Usage:
#   ./restore.sh <environment> <backup_filename> [--target-db <dbname>]
#
# Examples:
#   ./restore.sh prod hospital_economics_prod_20260524T020000Z.dump
#   ./restore.sh staging hospital_economics_staging_20260524T020000Z.dump --target-db hospital_economics_restored
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log() {
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"
}

die() {
    log "ERROR: $*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
ENVIRONMENT="${1:-}"
BACKUP_FILE="${2:-}"
TARGET_DB=""

if [[ -z "$ENVIRONMENT" || -z "$BACKUP_FILE" ]]; then
    die "Usage: $0 <environment> <backup_filename> [--target-db <dbname>]"
fi

case "$ENVIRONMENT" in
    dev|staging|prod) ;;
    *) die "Invalid environment '$ENVIRONMENT'. Must be one of: dev, staging, prod" ;;
esac

# Parse optional --target-db flag
shift 2
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-db)
            TARGET_DB="${2:-}"
            if [[ -z "$TARGET_DB" ]]; then
                die "--target-db requires a database name argument"
            fi
            shift 2
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

log "Starting restore for environment: $ENVIRONMENT"
log "Backup file: $BACKUP_FILE"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-hospital_economics}"
DB_USER="${DB_USER:-rhsim}"

S3_BUCKET="rhsim-backups-${ENVIRONMENT}"
LOCAL_DUMP="/tmp/restore_${BACKUP_FILE}"

# Determine the restore target database
RESTORE_DB="${TARGET_DB:-$DB_NAME}"
log "Restore target database: $RESTORE_DB"

# ---------------------------------------------------------------------------
# Download from S3
# ---------------------------------------------------------------------------
# Try to locate the backup file in S3 by searching under the backups/ prefix
log "Searching for backup in s3://${S3_BUCKET}/backups/..."

S3_KEY=$(aws s3api list-objects-v2 \
    --bucket "$S3_BUCKET" \
    --prefix "backups/" \
    --query "Contents[?contains(Key, '${BACKUP_FILE}')].Key | [0]" \
    --output text 2>/dev/null)

if [[ -z "$S3_KEY" || "$S3_KEY" == "None" ]]; then
    die "Backup file '$BACKUP_FILE' not found in s3://${S3_BUCKET}/backups/"
fi

S3_URI="s3://${S3_BUCKET}/${S3_KEY}"
log "Found backup at: $S3_URI"

log "Downloading backup..."
if ! aws s3 cp "$S3_URI" "$LOCAL_DUMP" --only-show-errors; then
    die "Failed to download backup from $S3_URI"
fi

DUMP_SIZE=$(stat --printf="%s" "$LOCAL_DUMP" 2>/dev/null || stat -f "%z" "$LOCAL_DUMP" 2>/dev/null || echo "unknown")
log "Download complete: $LOCAL_DUMP ($DUMP_SIZE bytes)"

# ---------------------------------------------------------------------------
# Optionally create target database
# ---------------------------------------------------------------------------
if [[ -n "$TARGET_DB" ]]; then
    log "Creating target database '$TARGET_DB' (if it does not exist)..."
    if psql \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname="postgres" \
        --tuples-only \
        --command="SELECT 1 FROM pg_database WHERE datname = '${TARGET_DB}'" 2>/dev/null | grep -q 1; then
        log "Database '$TARGET_DB' already exists — restoring into it"
    else
        if ! createdb \
            --host="$DB_HOST" \
            --port="$DB_PORT" \
            --username="$DB_USER" \
            --owner="$DB_USER" \
            "$TARGET_DB"; then
            die "Failed to create database '$TARGET_DB'"
        fi
        log "Database '$TARGET_DB' created"
    fi
fi

# ---------------------------------------------------------------------------
# Restore
# ---------------------------------------------------------------------------
log "Running pg_restore into '$RESTORE_DB'..."
if ! pg_restore \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --dbname="$RESTORE_DB" \
    --no-owner \
    --no-privileges \
    --verbose \
    "$LOCAL_DUMP" 2>&1 | while IFS= read -r line; do log "  pg_restore: $line"; done; then
    # pg_restore may return non-zero for warnings; check if data actually loaded
    log "WARNING: pg_restore exited with non-zero status (may include non-fatal warnings)"
fi

# ---------------------------------------------------------------------------
# Verify restore
# ---------------------------------------------------------------------------
log "Verifying restore..."
TABLE_COUNT=$(psql \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --dbname="$RESTORE_DB" \
    --tuples-only \
    --no-align \
    --command="SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null || echo "0")

TABLE_COUNT=$(echo "$TABLE_COUNT" | tr -d '[:space:]')

if [[ "$TABLE_COUNT" -gt 0 ]] 2>/dev/null; then
    log "Verification passed: $TABLE_COUNT tables found in '$RESTORE_DB'"
else
    die "Verification failed: no tables found in '$RESTORE_DB' after restore"
fi

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
log "Removing local dump file..."
rm -f "$LOCAL_DUMP"
log "Local cleanup complete"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
log "Restore completed successfully"
log "  Environment: $ENVIRONMENT"
log "  Source: $S3_URI"
log "  Target DB: $RESTORE_DB"
exit 0
