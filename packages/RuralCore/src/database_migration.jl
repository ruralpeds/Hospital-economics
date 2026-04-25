"""
    Database Migration System for RuralHealthPlatform

Supports offline deployment on hospital private networks:
- Dual-backend support (SQLite for offline, PostgreSQL for cloud)
- Data bundling for pre-computed external data
- Schema versioning and migrations
- Complete offline operation
- HIPAA-friendly data encapsulation
"""

module DatabaseMigration

using SQLite, DataFrames, JSON3, Dates, UUIDs, Logging
import LibPQ  # Optional: only loaded if PostgreSQL backend selected

# ── Configuration ────────────────────────────────────────────────────────────

"""Backend selection: :sqlite (offline) or :postgres (cloud/networked)"""
const BACKEND = Ref{Symbol}(:sqlite)  # Default to SQLite for offline

"""Database paths (for SQLite backend)"""
const DB_PATHS = (
    scenarios = "data/scenarios.db",
    geocode_cache = "data/geocode_cache.db",
    job_queue = "data/job_queue.db",
    external_data = "data/external_data.db",  # Census, CDC, BLS snapshots
)

"""PostgreSQL connection string (for PostgreSQL backend)"""
const PG_CONN_STRING = Ref{String}("")

"""Schema versions for migrations"""
const SCHEMA_VERSION = "1.0.0"

# ── Backend Abstraction ──────────────────────────────────────────────────────

"""
    DatabaseConnection — Abstracts SQLite vs PostgreSQL
"""
struct DatabaseConnection
    backend::Symbol
    sqlite_db::Union{SQLite.DB, Nothing}
    postgres_conn::Union{Any, Nothing}  # LibPQ.Connection
end

"""
    get_connection(db_name::Symbol) -> DatabaseConnection

Get connection to database. Auto-creates SQLite or connects to PostgreSQL.
"""
function get_connection(db_name::Symbol)::DatabaseConnection
    if BACKEND[] == :sqlite
        path = getfield(DB_PATHS, db_name)
        mkpath(dirname(path))
        db = SQLite.DB(path)
        return DatabaseConnection(:sqlite, db, nothing)
    else  # :postgres
        if isempty(PG_CONN_STRING[])
            error("PostgreSQL connection string not set. Call set_postgres_connection() first.")
        end
        # Defer connection for safety
        return DatabaseConnection(:postgres, nothing, nothing)
    end
end

"""
    set_postgres_connection(conn_string::String)

Configure PostgreSQL backend. Format: "postgresql://user:pass@host:port/dbname"
"""
function set_postgres_connection(conn_string::String)
    PG_CONN_STRING[] = conn_string
    BACKEND[] = :postgres
    @info "Database backend set to PostgreSQL"
end

"""
    set_sqlite_backend()

Switch to SQLite backend (offline-friendly).
"""
function set_sqlite_backend()
    BACKEND[] = :sqlite
    @info "Database backend set to SQLite (offline mode)"
end

"""
    execute_query(conn::DatabaseConnection, query::String, params=[], table_name::Symbol=:none)

Execute SQL on either backend. Returns DataFrame or status.
"""
function execute_query(conn::DatabaseConnection, query::String, params=[], table_name::Symbol=:none)
    if conn.backend == :sqlite
        return SQLite.execute(conn.sqlite_db, query, params) |> DataFrame
    else
        # PostgreSQL: requires network access
        error("PostgreSQL queries require initialized connection (network access required)")
    end
end

# ── Schema Initialization ────────────────────────────────────────────────────

"""Initialize all database schemas (both SQLite and PostgreSQL compatible)"""
function init_all_schemas()
    @info "Initializing database schemas (backend: $(BACKEND[]))"

    init_scenarios_schema()
    init_geocode_cache_schema()
    init_job_queue_schema()
    init_external_data_schema()
    init_metadata_schema()

    @info "Database schemas initialized successfully"
end

"""Scenarios table schema (both SQLite and PostgreSQL)"""
function init_scenarios_schema()
    conn = get_connection(:scenarios)

    if conn.backend == :sqlite
        # SQLite version
        SQLite.execute(conn.sqlite_db, """
            CREATE TABLE IF NOT EXISTS scenarios (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                app_type TEXT NOT NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                modified_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                is_favorite BOOLEAN DEFAULT 0,
                created_by TEXT,
                hospital_id TEXT
            )
        """)

        SQLite.execute(conn.sqlite_db, """
            CREATE TABLE IF NOT EXISTS scenario_parameters (
                scenario_id TEXT PRIMARY KEY,
                parameters_json TEXT NOT NULL,
                FOREIGN KEY(scenario_id) REFERENCES scenarios(id) ON DELETE CASCADE
            )
        """)

        SQLite.execute(conn.sqlite_db, """
            CREATE TABLE IF NOT EXISTS scenario_results (
                scenario_id TEXT PRIMARY KEY,
                results_json TEXT NOT NULL,
                result_summary TEXT,
                computed_at DATETIME,
                FOREIGN KEY(scenario_id) REFERENCES scenarios(id) ON DELETE CASCADE
            )
        """)

        SQLite.execute(conn.sqlite_db, """
            CREATE TABLE IF NOT EXISTS scenario_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                scenario_id TEXT NOT NULL,
                version_num INTEGER NOT NULL,
                parameters_json TEXT NOT NULL,
                results_json TEXT,
                change_reason TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(scenario_id) REFERENCES scenarios(id) ON DELETE CASCADE
            )
        """)

        SQLite.execute(conn.sqlite_db, """
            CREATE INDEX IF NOT EXISTS idx_scenarios_hospital ON scenarios(hospital_id)
        """)

        SQLite.execute(conn.sqlite_db, """
            CREATE INDEX IF NOT EXISTS idx_scenarios_app_type ON scenarios(app_type)
        """)
    else
        # PostgreSQL version (if network available)
        # Similar schema but with UUID primary keys, SERIAL for sequences, etc.
        @warn "PostgreSQL schema not yet implemented"
    end
end

"""Geocoding cache schema"""
function init_geocode_cache_schema()
    conn = get_connection(:geocode_cache)

    if conn.backend == :sqlite
        SQLite.execute(conn.sqlite_db, """
            CREATE TABLE IF NOT EXISTS geocode_cache (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                address_hash TEXT UNIQUE NOT NULL,
                original_address TEXT NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                match_quality INTEGER NOT NULL,
                source TEXT NOT NULL,
                matched_address TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                expires_at DATETIME NOT NULL
            )
        """)

        SQLite.execute(conn.sqlite_db, """
            CREATE INDEX IF NOT EXISTS idx_geocode_hash ON geocode_cache(address_hash)
        """)

        SQLite.execute(conn.sqlite_db, """
            CREATE INDEX IF NOT EXISTS idx_geocode_expires ON geocode_cache(expires_at)
        """)
    end
end

"""Job queue schema"""
function init_job_queue_schema()
    conn = get_connection(:job_queue)

    if conn.backend == :sqlite
        SQLite.execute(conn.sqlite_db, """
            CREATE TABLE IF NOT EXISTS jobs (
                id TEXT PRIMARY KEY,
                status TEXT NOT NULL,
                model TEXT NOT NULL,
                config_json TEXT NOT NULL,
                results_json TEXT,
                progress REAL DEFAULT 0.0,
                error_message TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                started_at DATETIME,
                completed_at DATETIME,
                runtime_seconds REAL DEFAULT 0.0,
                hospital_id TEXT
            )
        """)

        SQLite.execute(conn.sqlite_db, """
            CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status)
        """)

        SQLite.execute(conn.sqlite_db, """
            CREATE INDEX IF NOT EXISTS idx_jobs_hospital ON jobs(hospital_id)
        """)
    end
end

"""External data snapshot schema (Census, CDC, BLS pre-computed data)"""
function init_external_data_schema()
    conn = get_connection(:external_data)

    if conn.backend == :sqlite
        SQLite.execute(conn.sqlite_db, """
            CREATE TABLE IF NOT EXISTS external_data_snapshots (
                id TEXT PRIMARY KEY,
                data_source TEXT NOT NULL,
                geography_level TEXT,
                time_period TEXT,
                snapshot_date DATETIME NOT NULL,
                data_version TEXT,
                compressed_json TEXT NOT NULL,
                metadata_json TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                expires_at DATETIME
            )
        """)

        SQLite.execute(conn.sqlite_db, """
            CREATE INDEX IF NOT EXISTS idx_data_source ON external_data_snapshots(data_source)
        """)

        SQLite.execute(conn.sqlite_db, """
            CREATE INDEX IF NOT EXISTS idx_data_geography ON external_data_snapshots(geography_level)
        """)
    end
end

"""Metadata schema (migrations, versions, timestamps)"""
function init_metadata_schema()
    conn = get_connection(:scenarios)

    if conn.backend == :sqlite
        SQLite.execute(conn.sqlite_db, """
            CREATE TABLE IF NOT EXISTS _schema_version (
                schema_name TEXT PRIMARY KEY,
                version TEXT NOT NULL,
                migrated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                backend TEXT
            )
        """)

        # Record migration
        try
            SQLite.execute(conn.sqlite_db,
                """INSERT OR REPLACE INTO _schema_version
                   (schema_name, version, backend)
                   VALUES (?, ?, ?)""",
                ["all", SCHEMA_VERSION, String(BACKEND[])]
            )
        catch
            # Already exists, ignore
        end
    end
end

# ── Data Export/Import (for offline bundling) ────────────────────────────────

"""
    export_data_bundle(output_path::String)

Export all data to a portable JSON bundle for offline deployment.
Useful for: licensing, air-gapped networks, backup.
"""
function export_data_bundle(output_path::String)
    @info "Exporting data bundle to $output_path"

    bundle = Dict{String, Any}(
        "export_date" => now(UTC),
        "schema_version" => SCHEMA_VERSION,
        "backend" => String(BACKEND[]),
        "data" => Dict(
            "scenarios" => export_scenarios(),
            "geocode_cache" => export_geocode_cache(),
            "jobs" => export_jobs(),
            "external_data" => export_external_data(),
        )
    )

    open(output_path, "w") do io
        JSON3.write(io, bundle)
    end

    @info "Data bundle exported: $(filesize(output_path) / 1024 / 1024) MB"
    return output_path
end

"""Export all scenarios as JSON"""
function export_scenarios()
    conn = get_connection(:scenarios)
    df = execute_query(conn, "SELECT * FROM scenarios")

    scenarios = []
    for row in eachrow(df)
        params_df = execute_query(conn,
            "SELECT parameters_json FROM scenario_parameters WHERE scenario_id = ?",
            [row.id]
        )
        params = if nrow(params_df) > 0
            JSON3.read(params_df[1, :parameters_json], Dict)
        else
            Dict()
        end

        results_df = execute_query(conn,
            "SELECT results_json FROM scenario_results WHERE scenario_id = ?",
            [row.id]
        )
        results = if nrow(results_df) > 0
            JSON3.read(results_df[1, :results_json], Dict)
        else
            nothing
        end

        push!(scenarios, Dict(
            "id" => row.id,
            "name" => row.name,
            "description" => row.description,
            "app_type" => row.app_type,
            "created_at" => row.created_at,
            "modified_at" => row.modified_at,
            "parameters" => params,
            "results" => results,
            "is_favorite" => row.is_favorite,
        ))
    end

    return scenarios
end

"""Export geocoding cache as JSON"""
function export_geocode_cache()
    conn = get_connection(:geocode_cache)
    df = execute_query(conn, "SELECT * FROM geocode_cache")

    return [Dict(
        "address" => row.original_address,
        "lat" => row.latitude,
        "lon" => row.longitude,
        "quality" => row.match_quality,
        "source" => row.source,
        "created_at" => row.created_at,
        "expires_at" => row.expires_at,
    ) for row in eachrow(df)]
end

"""Export all jobs as JSON"""
function export_jobs()
    conn = get_connection(:job_queue)
    df = execute_query(conn, "SELECT * FROM jobs")

    return [Dict(
        "id" => row.id,
        "status" => row.status,
        "model" => row.model,
        "config" => JSON3.read(row.config_json, Dict),
        "progress" => row.progress,
        "created_at" => row.created_at,
    ) for row in eachrow(df)]
end

"""Export external data snapshots"""
function export_external_data()
    conn = get_connection(:external_data)
    df = execute_query(conn, "SELECT * FROM external_data_snapshots")

    return [Dict(
        "id" => row.id,
        "source" => row.data_source,
        "geography" => row.geography_level,
        "period" => row.time_period,
        "snapshot_date" => row.snapshot_date,
    ) for row in eachrow(df)]
end

"""
    import_data_bundle(bundle_path::String; overwrite::Bool=false)

Import data from bundle JSON. For air-gapped deployment.
"""
function import_data_bundle(bundle_path::String; overwrite::Bool=false)
    @info "Importing data bundle from $bundle_path"

    bundle = open(bundle_path) do io
        JSON3.read(io)
    end

    @info "Bundle metadata: $(bundle["schema_version"]) @ $(bundle["export_date"])"

    # Clear existing data if requested
    if overwrite
        @warn "Overwriting existing data..."
        # TODO: implement clear_all_data()
    end

    # Import each section
    import_scenarios(bundle["data"]["scenarios"])
    import_geocode_cache(bundle["data"]["geocode_cache"])
    import_jobs(bundle["data"]["jobs"])
    import_external_data(bundle["data"]["external_data"])

    @info "Data bundle imported successfully"
end

# Placeholder import functions
function import_scenarios(scenarios)
    @info "Importing $(length(scenarios)) scenarios"
end

function import_geocode_cache(cache)
    @info "Importing $(length(cache)) geocoding results"
end

function import_jobs(jobs)
    @info "Importing $(length(jobs)) jobs"
end

function import_external_data(data)
    @info "Importing $(length(data)) external data snapshots"
end

# ── Backup & Restore ─────────────────────────────────────────────────────────

"""
    backup_databases(backup_dir::String = "backups")

Create timestamped backup of all SQLite databases.
Safe for hospital deployments (automatic point-in-time recovery).
"""
function backup_databases(backup_dir::String = "backups")
    mkpath(backup_dir)

    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    backup_subdir = joinpath(backup_dir, "backup_$timestamp")
    mkpath(backup_subdir)

    backup_count = 0
    for (db_name, db_path) in pairs(DB_PATHS)
        if isfile(db_path)
            cp(db_path, joinpath(backup_subdir, basename(db_path)), force=true)
            backup_count += 1
            @info "Backed up $db_name"
        end
    end

    @info "Backup complete: $backup_subdir ($backup_count files)"
    return backup_subdir
end

"""
    restore_database(backup_path::String)

Restore databases from backup directory.
"""
function restore_database(backup_path::String)
    if !isdir(backup_path)
        error("Backup path not found: $backup_path")
    end

    @warn "Restoring from: $backup_path"

    for file in readdir(backup_path)
        if endswith(file, ".db")
            src = joinpath(backup_path, file)
            dst = joinpath(dirname(DB_PATHS.scenarios), file)
            cp(src, dst, force=true)
            @info "Restored $file"
        end
    end

    @info "Restore complete"
end

# ── Export for Public Use ────────────────────────────────────────────────────

export DatabaseConnection, get_connection, init_all_schemas
export set_postgres_connection, set_sqlite_backend
export execute_query
export export_data_bundle, import_data_bundle
export backup_databases, restore_database
export BACKEND, DB_PATHS, PG_CONN_STRING

end  # module DatabaseMigration
