"""
Observability module — liveness, readiness, and Prometheus metrics endpoints.

Provides three HTTP handler functions for Kubernetes-style health probes
and a Prometheus text-exposition metrics endpoint.

# Endpoints
- `healthz()`       — liveness probe (always "ok")
- `readyz()`        — readiness probe (checks DB connectivity)
- `metrics()`       — Prometheus-compatible text exposition
- `request_counter!()` — increment the global request counter (call from middleware)
"""
module Health

using Dates

export healthz, readyz, metrics, request_counter!

# ═══════════════════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════════════════

"""Application start time — used to compute uptime."""
const APP_START_TIME = Ref(now(UTC))

"""Global request counter (thread-safe via Threads.atomic_add!)."""
const REQUEST_COUNT = Threads.Atomic{Int}(0)

"""Application version — read once at module load."""
const APP_VERSION = let
    toml_path = joinpath(@__DIR__, "..", "..", "Project.toml")
    if isfile(toml_path)
        m = match(r"version\s*=\s*\"([^\"]+)\"", read(toml_path, String))
        isnothing(m) ? "1.1.0" : m.captures[1]
    else
        "1.1.0"
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# 1. Liveness probe
# ═══════════════════════════════════════════════════════════════════════════

"""
    healthz()::Dict{String, Any}

Liveness probe handler. Always returns status "ok" with the current
timestamp and application version. Kubernetes uses this to decide
whether to restart the container.
"""
function healthz()::Dict{String, Any}
    Dict{String, Any}(
        "status"    => "ok",
        "timestamp" => string(now(UTC)),
        "version"   => APP_VERSION,
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# 2. Readiness probe
# ═══════════════════════════════════════════════════════════════════════════

"""
    readyz()::Dict{String, Any}

Readiness probe handler. Checks backend dependencies and returns an
aggregate status:
- `"ok"`        — all checks pass
- `"degraded"`  — some non-critical checks fail
- `"unhealthy"` — critical checks (database) fail

Kubernetes uses this to decide whether to route traffic to the pod.
"""
function readyz()::Dict{String, Any}
    checks = Dict{String, Any}()

    # ── Database connectivity ──────────────────────────────────────────
    db_ok = try
        # Attempt a lightweight query via SearchLight
        SearchLight.query("SELECT 1;")
        true
    catch e
        @warn "Readiness check: database unreachable" exception=(e, catch_backtrace())
        false
    end
    checks["database"] = db_ok

    # ── Aggregate status ───────────────────────────────────────────────
    status = if db_ok
        "ok"
    else
        "unhealthy"
    end

    Dict{String, Any}(
        "status"    => status,
        "checks"    => checks,
        "timestamp" => string(now(UTC)),
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# 3. Prometheus metrics
# ═══════════════════════════════════════════════════════════════════════════

"""
    metrics()::String

Return Prometheus text-exposition formatted metrics.

Exposed metrics:
- `rhsim_info`             — gauge with version label (always 1)
- `rhsim_uptime_seconds`   — gauge, seconds since application start
- `rhsim_requests_total`   — counter, total HTTP requests observed
- `rhsim_active_sessions`  — gauge, current in-memory session count
"""
function metrics()::String
    uptime_seconds = round(Dates.value(now(UTC) - APP_START_TIME[]) / 1000.0, digits=1)
    total_requests = REQUEST_COUNT[]

    # Count active sessions from the Auth module's SESSION_STORE
    active_sessions = try
        # Access the global SESSION_STORE from the Auth module
        length(Main.Auth.SESSION_STORE)
    catch
        # Fallback if Auth module is not loaded or SESSION_STORE unavailable
        0
    end

    io = IOBuffer()

    # rhsim_info
    println(io, "# HELP rhsim_info Application version information.")
    println(io, "# TYPE rhsim_info gauge")
    println(io, "rhsim_info{version=\"$(APP_VERSION)\"} 1")
    println(io)

    # rhsim_uptime_seconds
    println(io, "# HELP rhsim_uptime_seconds Time since application start in seconds.")
    println(io, "# TYPE rhsim_uptime_seconds gauge")
    println(io, "rhsim_uptime_seconds $uptime_seconds")
    println(io)

    # rhsim_requests_total
    println(io, "# HELP rhsim_requests_total Total number of HTTP requests processed.")
    println(io, "# TYPE rhsim_requests_total counter")
    println(io, "rhsim_requests_total $total_requests")
    println(io)

    # rhsim_active_sessions
    println(io, "# HELP rhsim_active_sessions Current number of active user sessions.")
    println(io, "# TYPE rhsim_active_sessions gauge")
    println(io, "rhsim_active_sessions $active_sessions")

    return String(take!(io))
end

# ═══════════════════════════════════════════════════════════════════════════
# 4. Request counter helper
# ═══════════════════════════════════════════════════════════════════════════

"""
    request_counter!()

Atomically increment the global HTTP request counter.
Call this from the request middleware on every incoming request.
"""
function request_counter!()
    Threads.atomic_add!(REQUEST_COUNT, 1)
end

end # module Health
