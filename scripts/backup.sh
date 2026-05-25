#!/usr/bin/env bash
#
# backup.sh — Automated PostgreSQL backup to S3 with retention cleanup.
#
# Usage:
#   ./backup.sh <environment>
#   ./backup.sh prod
#
# Environment: dev | staging | prod
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
if [[ -z "$ENVIRONMENT" ]]; then
    die "Usage: $0 <environment>  (dev|staging|prod)"
fi

case "$ENVIRONMENT" in
    dev|staging|prod) ;;
    *) die "Invalid environment '$ENVIRONMENT'. Must be one of: dev, staging, prod" ;;
esac

log "Starting backup for environment: $ENVIRONMENT"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-hospital_economics}"
DB_USER="${DB_USER:-rhsim}"
RETENTION_DAYS="${RETENTION_DAYS:-35}"

S3_BUCKET="rhsim-backups-${ENVIRONMENT}"
TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
DUMP_FILE="/tmp/${DB_NAME}_${ENVIRONMENT}_${TIMESTAMP}.dump"

log "Database: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
log "S3 Bucket: s3://${S3_BUCKET}"
log "Retention: ${RETENTION_DAYS} days"

# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------
log "Creating pg_dump (custom format, compressed)..."
if ! pg_dump \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --dbname="$DB_NAME" \
    --format=custom \
    --compress=9 \
    --verbose \
    --file="$DUMP_FILE" 2>&1 | while IFS= read -r line; do log "  pg_dump: $line"; done; then
    die "pg_dump failed"
fi

DUMP_SIZE=$(stat --printf="%s" "$DUMP_FILE" 2>/dev/null || stat -f "%z" "$DUMP_FILE" 2>/dev/null || echo "unknown")
log "Dump created: $DUMP_FILE ($DUMP_SIZE bytes)"

# ---------------------------------------------------------------------------
# Upload to S3
# ---------------------------------------------------------------------------
S3_KEY="backups/${TIMESTAMP}/${DB_NAME}_${ENVIRONMENT}_${TIMESTAMP}.dump"
S3_URI="s3://${S3_BUCKET}/${S3_KEY}"

log "Uploading to ${S3_URI} with server-side encryption..."
if ! aws s3 cp "$DUMP_FILE" "$S3_URI" \
    --sse AES256 \
    --only-show-errors; then
    die "S3 upload failed"
fi

# ---------------------------------------------------------------------------
# Verify upload
# ---------------------------------------------------------------------------
log "Verifying upload..."
if ! aws s3 ls "$S3_URI" > /dev/null 2>&1; then
    die "Upload verification failed — object not found at $S3_URI"
fi
log "Upload verified successfully"

# ---------------------------------------------------------------------------
# Cleanup local dump
# ---------------------------------------------------------------------------
log "Removing local dump file..."
rm -f "$DUMP_FILE"
log "Local cleanup complete"

# ---------------------------------------------------------------------------
# Retention cleanup — delete S3 objects older than RETENTION_DAYS
# ---------------------------------------------------------------------------
log "Running retention cleanup (removing backups older than ${RETENTION_DAYS} days)..."
CUTOFF_DATE="$(date -u -d "${RETENTION_DAYS} days ago" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -v "-${RETENTION_DAYS}d" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)"

if [[ -n "$CUTOFF_DATE" ]]; then
    log "Cutoff date: $CUTOFF_DATE"
    aws s3api list-objects-v2 \
        --bucket "$S3_BUCKET" \
        --prefix "backups/" \
        --query "Contents[?LastModified<'${CUTOFF_DATE}'].Key" \
        --output text 2>/dev/null | tr '\t' '\n' | while IFS= read -r old_key; do
        if [[ -n "$old_key" && "$old_key" != "None" ]]; then
            log "  Deleting expired backup: s3://${S3_BUCKET}/${old_key}"
            aws s3 rm "s3://${S3_BUCKET}/${old_key}" --only-show-errors
        fi
    done
    log "Retention cleanup complete"
else
    log "WARNING: Could not compute cutoff date; skipping retention cleanup"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
log "Backup completed successfully for environment: $ENVIRONMENT"
log "  S3 URI: $S3_URI"
exit 0
