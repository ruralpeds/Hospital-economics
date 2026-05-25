"""
Migration 011: Create TimescaleDB hypertables on time-series tables

Converts regular PostgreSQL tables into TimescaleDB hypertables for
efficient time-series queries, automatic partitioning, and compression.

Tables converted:
- audit_logs        (migration 009, partitioned on `timestamp`)
- streaming_metrics (migration 008, partitioned on `metric_timestamp`)

Wrapped in try/catch because TimescaleDB extension may not be installed
in all environments (dev SQLite, CI, etc.).
"""

using SearchLight, SearchLight.Migrations

export up, down

function up()
    # ── Enable TimescaleDB extension (idempotent) ──────────────────────────
    try
        SearchLight.query("CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;")
        @info "TimescaleDB extension enabled"
    catch e
        @warn "TimescaleDB extension not available — skipping hypertable creation" exception=(e, catch_backtrace())
        return  # nothing more to do without the extension
    end

    # ── Convert audit_logs ─────────────────────────────────────────────────
    try
        SearchLight.query("""
            SELECT create_hypertable('audit_logs', 'timestamp',
                                     migrate_data => true,
                                     if_not_exists => true);
        """)
        @info "audit_logs converted to hypertable"
    catch e
        @warn "Could not convert audit_logs to hypertable" exception=(e, catch_backtrace())
    end

    # ── Convert streaming_metrics ──────────────────────────────────────────
    try
        SearchLight.query("""
            SELECT create_hypertable('streaming_metrics', 'metric_timestamp',
                                     migrate_data => true,
                                     if_not_exists => true);
        """)
        @info "streaming_metrics converted to hypertable"
    catch e
        @warn "Could not convert streaming_metrics to hypertable" exception=(e, catch_backtrace())
    end

    # ── Convert patient_encounters_stream (time-series encounter data) ────
    try
        SearchLight.query("""
            SELECT create_hypertable('patient_encounters_stream', 'ingestion_timestamp',
                                     migrate_data => true,
                                     if_not_exists => true);
        """)
        @info "patient_encounters_stream converted to hypertable"
    catch e
        @warn "Could not convert patient_encounters_stream to hypertable" exception=(e, catch_backtrace())
    end
end

function down()
    # TimescaleDB does not support reverting a hypertable back to a regular
    # table without recreating it.  Dropping the extension would cascade-drop
    # dependent objects, so we leave it in place and log a warning.
    @warn "Hypertable conversion is not reversible. Tables remain as hypertables."
end
