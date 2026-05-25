"""
Database connection configuration for the Rural Hospital Economics Simulator.

Reads connection parameters from environment variables and provides helpers
to configure SearchLight's connection pool for PostgreSQL.
"""
using Dates

# ═══════════════════════════════════════════════════════════════════════════
# Connection configuration
# ═══════════════════════════════════════════════════════════════════════════

"""
    db_config()::Dict{String, Any}

Return a Dict of database connection parameters, sourced from environment
variables with sensible development defaults.

Environment variables:
- `DB_HOST`     — PostgreSQL host (default: "localhost")
- `DB_PORT`     — PostgreSQL port (default: 5432)
- `DB_NAME`     — Database name  (default: "rhsim_dev")
- `DB_USERNAME` — Database user  (default: "rhsim")
- `DB_PASSWORD` — Database password (default: "")
- `DB_POOL_SIZE`    — Connection pool size (default: 10)
- `DB_IDLE_TIMEOUT` — Idle connection timeout in seconds (default: 300)
- `DB_CONNECT_TIMEOUT` — Connection timeout in seconds (default: 10)
- `DB_RETRY_ATTEMPTS`  — Retries on transient failure (default: 3)
- `DB_RETRY_DELAY`     — Seconds between retries (default: 1)
"""
function db_config()::Dict{String, Any}
    Dict{String, Any}(
        "adapter"          => "PostgreSQL",
        "host"             => get(ENV, "DB_HOST", "localhost"),
        "port"             => parse(Int, get(ENV, "DB_PORT", "5432")),
        "database"         => get(ENV, "DB_NAME", "rhsim_dev"),
        "username"         => get(ENV, "DB_USERNAME", "rhsim"),
        "password"         => get(ENV, "DB_PASSWORD", ""),
        "pool_size"        => parse(Int, get(ENV, "DB_POOL_SIZE", "10")),
        "idle_timeout"     => parse(Int, get(ENV, "DB_IDLE_TIMEOUT", "300")),
        "connect_timeout"  => parse(Int, get(ENV, "DB_CONNECT_TIMEOUT", "10")),
        "retry_attempts"   => parse(Int, get(ENV, "DB_RETRY_ATTEMPTS", "3")),
        "retry_delay"      => parse(Int, get(ENV, "DB_RETRY_DELAY", "1")),
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# SearchLight integration
# ═══════════════════════════════════════════════════════════════════════════

"""
    setup_database!()

Configure the SearchLight connection using environment-driven settings.
Call this during application bootstrap (after SearchLight is loaded).

The function:
1. Reads config via `db_config()`
2. Sets SearchLight connection parameters
3. Logs the connection target (without credentials)
"""
function setup_database!()
    config = db_config()

    try
        # SearchLight.Configuration expects these keys in its settings dict
        SearchLight.Configuration.Settings(
            :adapter  => config["adapter"],
            :host     => config["host"],
            :port     => config["port"],
            :database => config["database"],
            :username => config["username"],
            :password => config["password"],
        )

        @info "Database configured" host=config["host"] port=config["port"] database=config["database"] pool_size=config["pool_size"]
    catch e
        @error "Failed to configure database connection" exception=(e, catch_backtrace())
        rethrow(e)
    end
end
