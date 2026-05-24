"""
Structured JSON logging with correlation IDs for the Rural Hospital Economics Simulator.

Provides structured log output (one JSON object per line) with W3C-style
correlation IDs (request_id, trace_id, span_id) and a Genie-compatible
request logging middleware that measures latency and propagates trace headers.

# Public API
- `init_logger!(path)` / `close_logger!()` — manage the log file handle
- `CorrelationContext` — per-request identity bag
- `new_context(; user_id, ip)` — generate a fresh context with random UUIDs
- `log_structured(level, message; extra)` — emit a JSON log line
- `request_logging_middleware(handler)` — Genie middleware for automatic request logging
"""
module StructuredLogger

using Dates, Random, Logging, JSON3
using Genie, Genie.Requests, Genie.Responses, HTTP

export init_logger!, close_logger!
export CorrelationContext, CURRENT_CONTEXT, new_context
export log_structured
export request_logging_middleware

# ═══════════════════════════════════════════════════════════════════════════
# Application version — read once at module load
# ═══════════════════════════════════════════════════════════════════════════

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
# Log file handle
# ═══════════════════════════════════════════════════════════════════════════

"""Global log file handle.  `nothing` when logging to file is disabled."""
const LOG_FILE = Ref{Union{IOStream, Nothing}}(nothing)

"""
    init_logger!(path::String="/var/log/rhsim/app.log")

Open (or create) the structured-log file at `path` and store the handle in
[`LOG_FILE`](@ref).  The parent directory is created automatically if it does
not exist.
"""
function init_logger!(path::String="/var/log/rhsim/app.log")
    dir = dirname(path)
    isdir(dir) || mkpath(dir)
    LOG_FILE[] = open(path, "a")
    @info "StructuredLogger initialised — writing to $path"
    return nothing
end

"""
    close_logger!()

Flush and close the log file handle, then reset [`LOG_FILE`](@ref) to `nothing`.
"""
function close_logger!()
    io = LOG_FILE[]
    if io !== nothing
        flush(io)
        close(io)
        LOG_FILE[] = nothing
    end
    return nothing
end

# ═══════════════════════════════════════════════════════════════════════════
# Correlation context
# ═══════════════════════════════════════════════════════════════════════════

"""
Per-request correlation context carrying W3C-style trace identifiers and
caller metadata.
"""
struct CorrelationContext
    request_id::String
    trace_id::String
    span_id::String
    user_id::String
    ip_address::String
end

"""The currently active correlation context (task-local approximation via `Ref`)."""
const CURRENT_CONTEXT = Ref{Union{CorrelationContext, Nothing}}(nothing)

"""
    _generate_uuid()::String

Generate a random UUID-v4-style hex string (32 hex chars, no dashes).
"""
function _generate_uuid()::String
    bytes = rand(Random.default_rng(), UInt8, 16)
    return bytes2hex(bytes)
end

"""
    new_context(; user_id="anonymous", ip="0.0.0.0")::CorrelationContext

Create a fresh [`CorrelationContext`](@ref) with randomly generated
`request_id`, `trace_id`, and `span_id`.
"""
function new_context(; user_id::String="anonymous", ip::String="0.0.0.0")::CorrelationContext
    CorrelationContext(
        _generate_uuid(),
        _generate_uuid(),
        _generate_uuid(),
        user_id,
        ip,
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# Structured log emitter
# ═══════════════════════════════════════════════════════════════════════════

# Map symbols to Base.CoreLogging log levels
const _LEVEL_MAP = Dict{Symbol, LogLevel}(
    :debug => Logging.Debug,
    :info  => Logging.Info,
    :warn  => Logging.Warn,
    :error => Logging.Error,
)

"""
    log_structured(level::Symbol, message::String; extra::Dict{String,Any}=Dict{String,Any}())

Emit a single JSON log line containing:
- `timestamp` (ISO 8601 UTC)
- `level`, `message`
- correlation IDs from [`CURRENT_CONTEXT`](@ref)
- `service="rhsim"`, `version`
- any additional key-value pairs in `extra`

The line is written to [`LOG_FILE`](@ref) (if open) **and** forwarded to
`stderr` via `@logmsg`.
"""
function log_structured(level::Symbol, message::String;
                        extra::Dict{String,Any}=Dict{String,Any}())
    ctx = CURRENT_CONTEXT[]

    entry = Dict{String, Any}(
        "timestamp"  => Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SS.sssZ"),
        "level"      => String(level),
        "message"    => message,
        "request_id" => ctx !== nothing ? ctx.request_id : "",
        "trace_id"   => ctx !== nothing ? ctx.trace_id   : "",
        "span_id"    => ctx !== nothing ? ctx.span_id    : "",
        "user_id"    => ctx !== nothing ? ctx.user_id    : "",
        "ip_address" => ctx !== nothing ? ctx.ip_address : "",
        "service"    => "rhsim",
        "version"    => APP_VERSION,
    )

    # Merge caller-supplied extra fields
    for (k, v) in extra
        entry[k] = v
    end

    json_line = JSON3.write(entry)

    # ── Write to file ─────────────────────────────────────────────────
    io = LOG_FILE[]
    if io !== nothing
        try
            println(io, json_line)
            flush(io)
        catch e
            @warn "StructuredLogger: failed to write to log file" exception=(e, catch_backtrace())
        end
    end

    # ── Mirror to stderr via Logging ──────────────────────────────────
    log_level = get(_LEVEL_MAP, level, Logging.Info)
    @logmsg log_level message request_id=(ctx !== nothing ? ctx.request_id : "") trace_id=(ctx !== nothing ? ctx.trace_id : "")

    return nothing
end

# ═══════════════════════════════════════════════════════════════════════════
# Genie request logging middleware
# ═══════════════════════════════════════════════════════════════════════════

"""
    request_logging_middleware(handler)

Genie-compatible middleware that:
1. Creates a [`CorrelationContext`](@ref) (re-uses `X-Request-ID` header if present)
2. Sets [`CURRENT_CONTEXT`](@ref)
3. Logs **request start** (method, path, user_agent)
4. Calls `handler`, measuring wall-clock latency
5. Logs **request complete** (status_code, latency_ms)
6. Adds `X-Request-ID` and `X-Trace-ID` to the response headers
7. Clears [`CURRENT_CONTEXT`](@ref)
"""
function request_logging_middleware(handler)
    return function(req)
        # ── 1. Build correlation context ──────────────────────────────
        # Try to extract X-Request-ID from incoming headers
        incoming_request_id = ""
        try
            for (k, v) in req.headers
                if lowercase(String(k)) == "x-request-id"
                    incoming_request_id = String(v)
                    break
                end
            end
        catch
            incoming_request_id = ""
        end

        request_id = isempty(incoming_request_id) ? _generate_uuid() : incoming_request_id
        trace_id   = _generate_uuid()
        span_id    = _generate_uuid()

        # Extract caller IP
        ip = "0.0.0.0"
        try
            for (k, v) in req.headers
                if lowercase(String(k)) == "x-forwarded-for"
                    ip = strip(split(String(v), ",")[1])
                    break
                end
            end
        catch; end

        # Extract user agent
        user_agent = ""
        try
            for (k, v) in req.headers
                if lowercase(String(k)) == "user-agent"
                    user_agent = String(v)
                    break
                end
            end
        catch; end

        ctx = CorrelationContext(request_id, trace_id, span_id, "anonymous", ip)

        # ── 2. Set context ────────────────────────────────────────────
        CURRENT_CONTEXT[] = ctx

        # ── Extract request path and method ───────────────────────────
        path = try
            String(req.target)
        catch
            "/"
        end
        query_idx = findfirst('?', path)
        if query_idx !== nothing
            path = path[1:query_idx-1]
        end

        method = try
            String(req.method)
        catch
            "GET"
        end

        # ── 3. Log request start ─────────────────────────────────────
        log_structured(:info, "request_start"; extra=Dict{String,Any}(
            "http_method" => method,
            "http_path"   => path,
            "user_agent"  => user_agent,
        ))

        # ── 4. Call handler & measure latency ────────────────────────
        t_start = time_ns()
        local response
        try
            response = handler(req)
        catch e
            latency_ms = round((time_ns() - t_start) / 1_000_000; digits=2)
            log_structured(:error, "request_error"; extra=Dict{String,Any}(
                "http_method" => method,
                "http_path"   => path,
                "latency_ms"  => latency_ms,
                "error"       => sprint(showerror, e),
            ))
            CURRENT_CONTEXT[] = nothing
            rethrow(e)
        end

        latency_ms = round((time_ns() - t_start) / 1_000_000; digits=2)

        # ── 5. Log request complete ──────────────────────────────────
        status_code = try
            Int(response.status)
        catch
            200
        end

        log_structured(:info, "request_complete"; extra=Dict{String,Any}(
            "http_method"  => method,
            "http_path"    => path,
            "status_code"  => status_code,
            "latency_ms"   => latency_ms,
        ))

        # ── 6. Add trace headers to response ─────────────────────────
        try
            push!(response.headers, "X-Request-ID" => request_id)
            push!(response.headers, "X-Trace-ID"   => trace_id)
        catch; end

        # ── 7. Clear context ─────────────────────────────────────────
        CURRENT_CONTEXT[] = nothing

        return response
    end
end

end # module StructuredLogger
