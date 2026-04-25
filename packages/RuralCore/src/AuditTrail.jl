module AuditTrail

# ==============================================================================
# AuditTrail.jl — 21 CFR Part 11-aligned audit trail for Hartzog enterprise Julia
# Reference implementation.
#
# Dependencies (add to your package's Project.toml under [deps]):
#   SHA    = "ea8e919c-243c-51af-8825-aaa63cd721ce"
#   JSON3  = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
#   Dates  = "ade2ca70-3891-5945-98fb-dc099432e06a"
#   Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
# ==============================================================================

using SHA
using JSON3
using Dates
using Random
using Base.Threads: ReentrantLock

export  @audited_calculation,
        AuditContext,
        AbstractSink, FileSink, StderrSink, NullSink, CompositeSink,
        configure!, current_sink, set_sink!, set_hmac_key!, rotate_key!,
        verify_record, verify_log_file,
        with_actor,
        ProcessRisk, HIGH, MEDIUM, LOW,
        content_hash, hmac_sha256

const SCHEMA_VERSION = "1.0"

@enum ProcessRisk::UInt8 LOW=1 MEDIUM=2 HIGH=3

Base.show(io::IO, r::ProcessRisk) = print(io, r == HIGH   ? "HIGH"   :
                                              r == MEDIUM ? "MEDIUM" :
                                                            "LOW")

# ── Sinks ─────────────────────────────────────────────────────────────────────
abstract type AbstractSink end

mutable struct FileSink <: AbstractSink
    path::String
    rotate_daily::Bool
    lock::ReentrantLock
    current_date::Date
    current_path::String
    function FileSink(path::AbstractString; rotate_daily::Bool=true)
        parent = dirname(path)
        isempty(parent) || mkpath(parent)
        d = Dates.today()
        current = rotate_daily ? string(path, ".", d) : String(path)
        new(String(path), rotate_daily, ReentrantLock(), d, current)
    end
end

struct StderrSink <: AbstractSink
    lock::ReentrantLock
    StderrSink() = new(ReentrantLock())
end

struct NullSink <: AbstractSink end

struct CompositeSink <: AbstractSink
    sinks::Vector{AbstractSink}
    CompositeSink(sinks::AbstractSink...) = new(collect(AbstractSink, sinks))
end

function write_record!(sink::FileSink, line::AbstractString)
    lock(sink.lock) do
        if sink.rotate_daily
            d = Dates.today()
            if d != sink.current_date
                sink.current_date = d
                sink.current_path = string(sink.path, ".", d)
            end
        end
        open(sink.current_path, "a") do io
            write(io, line); write(io, '\n')
        end
    end
    return nothing
end

function write_record!(sink::StderrSink, line::AbstractString)
    lock(sink.lock) do
        println(stderr, line)
    end
    return nothing
end

write_record!(::NullSink, ::AbstractString) = nothing

function write_record!(sink::CompositeSink, line::AbstractString)
    first_err = nothing
    for s in sink.sinks
        try
            write_record!(s, line)
        catch e
            first_err === nothing && (first_err = e)
        end
    end
    first_err === nothing || throw(first_err)
    return nothing
end

# ── Configuration ─────────────────────────────────────────────────────────────
const _CONFIG_LOCK = ReentrantLock()

mutable struct _Config
    sink::AbstractSink
    hmac_key::Vector{UInt8}
    package::String
    version::String
    git_commit::String
    hostname::String
end

const _CONFIG = Ref{_Config}()

function _init_config()
    sink_path = get(ENV, "HARTZOG_AUDIT_LOG", "")
    sink = isempty(sink_path) ? StderrSink() : FileSink(sink_path)

    key_path = get(ENV, "HARTZOG_HMAC_KEY_FILE", "")
    key = if isempty(key_path)
        @warn "HARTZOG_HMAC_KEY_FILE not set — using ephemeral key (NOT PART 11 COMPLIANT)" maxlog=1
        rand(UInt8, 32)
    else
        isfile(key_path) || error("HARTZOG_HMAC_KEY_FILE points to non-existent path: $key_path")
        bytes = read(key_path)
        length(bytes) ≥ 32 || error("HMAC key must be ≥ 32 bytes; got $(length(bytes))")
        bytes
    end

    _CONFIG[] = _Config(
        sink, key,
        get(ENV, "HARTZOG_PACKAGE",    "unknown"),
        get(ENV, "HARTZOG_VERSION",    "unknown"),
        get(ENV, "HARTZOG_GIT_COMMIT", "unknown"),
        gethostname(),
    )
    return nothing
end

__init__() = _init_config()

function configure!(; sink=nothing, hmac_key=nothing, package=nothing,
                     version=nothing, git_commit=nothing)
    lock(_CONFIG_LOCK) do
        cfg = _CONFIG[]
        sink       === nothing || (cfg.sink = sink)
        hmac_key   === nothing || (cfg.hmac_key = collect(UInt8, hmac_key))
        package    === nothing || (cfg.package = String(package))
        version    === nothing || (cfg.version = String(version))
        git_commit === nothing || (cfg.git_commit = String(git_commit))
    end
    return nothing
end

current_sink()   = _CONFIG[].sink
set_sink!(s)     = configure!(sink=s)
set_hmac_key!(k) = configure!(hmac_key=k)
rotate_key!(k)   = configure!(hmac_key=k)

# ── Actor context ────────────────────────────────────────────────────────────
Base.@kwdef struct AuditContext
    user_id::String     = "system"
    session_id::String  = "unknown"
    role::String        = "unknown"
    auth_method::String = "unknown"
end

function with_actor(f::Function, ctx::AuditContext)
    prev = get(task_local_storage(), :hartzog_audit_actor, nothing)
    task_local_storage()[:hartzog_audit_actor] = ctx
    try
        return f()
    finally
        if prev === nothing
            delete!(task_local_storage(), :hartzog_audit_actor)
        else
            task_local_storage()[:hartzog_audit_actor] = prev
        end
    end
end

_current_actor() = get(task_local_storage(), :hartzog_audit_actor, AuditContext())

# ── ULID ──────────────────────────────────────────────────────────────────────
const _CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

function _ulid()
    t_ms = round(UInt64, time() * 1000)
    rb   = rand(UInt128)
    raw  = (UInt128(t_ms) << 80) | (rb & ((UInt128(1) << 80) - 1))
    buf  = Vector{UInt8}(undef, 26)
    @inbounds for i in 26:-1:1
        buf[i] = UInt8(_CROCKFORD[(raw & 0x1f) + 1])
        raw >>= 5
    end
    return String(buf)
end

# ── Hashing & HMAC ────────────────────────────────────────────────────────────
function content_hash(x)::String
    bytes = try
        Vector{UInt8}(JSON3.write(_summarize_for_hash(x)))
    catch
        Vector{UInt8}(string(typeof(x), ":", hash(x)))
    end
    return "sha256:" * bytes2hex(SHA.sha256(bytes))
end

_summarize_for_hash(x::AbstractArray) = (type = string(typeof(x)),
                                          size = collect(size(x)),
                                          hash = hash(x))
_summarize_for_hash(x::AbstractDict)  = (type = string(typeof(x)),
                                          length = length(x),
                                          hash = hash(x))
_summarize_for_hash(x) = x

function hmac_sha256(key::AbstractVector{UInt8}, message::AbstractVector{UInt8})
    blocksize = 64
    k = length(key) > blocksize ? SHA.sha256(key) : collect(UInt8, key)
    length(k) < blocksize && (k = vcat(k, zeros(UInt8, blocksize - length(k))))
    opad = UInt8(0x5c) .⊻ k
    ipad = UInt8(0x36) .⊻ k
    inner = SHA.sha256(vcat(ipad, collect(UInt8, message)))
    return SHA.sha256(vcat(opad, inner))
end

# ── Canonical record form (NamedTuple — JSON3 preserves field order) ─────────
#
# IMPORTANT: field order here IS the canonical signing order. Changing it
# is a breaking change that invalidates all prior-key HMAC verifications.
#
function _record_nt(audit_id::String, wall::String, mono::UInt64,
                    actor::AuditContext, system::NamedTuple, action::NamedTuple,
                    inputs::NamedTuple, outputs, status::String, err, parent)
    return (
        audit_id               = audit_id,
        schema_version         = SCHEMA_VERSION,
        timestamp_iso8601      = wall,
        timestamp_monotonic_ns = mono,
        actor                  = actor,
        system                 = system,
        action                 = action,
        inputs                 = inputs,
        outputs                = outputs,
        result                 = status,
        error                  = err,
        parent_audit_id        = parent,
    )
end

function _sign_and_write(rec::NamedTuple)
    cfg = _CONFIG[]
    payload = JSON3.write(rec)
    mac = hmac_sha256(cfg.hmac_key, Vector{UInt8}(payload))
    hmac_str = "sha256:" * bytes2hex(mac)
    # Splice integrity_hmac as final field immediately before the closing brace
    # payload is guaranteed to end in '}' because it's a JSON object
    @assert !isempty(payload) && last(payload) == '}' "unexpected JSON serialization shape"
    line = string(payload[1:end-1], ",\"integrity_hmac\":\"", hmac_str, "\"}")
    write_record!(cfg.sink, line)
    return line
end

# ── Core runner ──────────────────────────────────────────────────────────────
function _run_audited(intended_use::AbstractString,
                      process_risk::ProcessRisk,
                      operation::AbstractString,
                      f::Function)
    audit_id = _ulid()
    wall     = Dates.format(now(UTC), "yyyy-mm-ddTHH:MM:SS.sssZ")
    mono     = time_ns()
    actor    = _current_actor()
    cfg      = _CONFIG[]
    system   = (hostname      = cfg.hostname,
                package       = cfg.package,
                version       = cfg.version,
                git_commit    = cfg.git_commit,
                julia_version = string(VERSION))
    action   = (type         = "calculation",
                operation    = String(operation),
                intended_use = String(intended_use),
                process_risk = string(process_risk))
    parent      = get(task_local_storage(), :hartzog_parent_audit_id, nothing)
    prev_parent = parent
    task_local_storage()[:hartzog_parent_audit_id] = audit_id

    local result
    try
        result = f()
    catch e
        err = (type      = string(typeof(e)),
               message   = sprint(showerror, e),
               backtrace = sprint(Base.show_backtrace, catch_backtrace()))
        rec = _record_nt(audit_id, wall, mono, actor, system, action,
                         (hash_sha256 = "sha256:nohash",),
                         nothing, "error", err, parent)
        _sign_and_write(rec)
        _restore_parent(prev_parent)
        rethrow(e)
    end

    out_hash = content_hash(result)
    rec = _record_nt(audit_id, wall, mono, actor, system, action,
                     (hash_sha256 = "sha256:nohash",),
                     (hash_sha256 = out_hash,),
                     "success", nothing, parent)
    _sign_and_write(rec)
    _restore_parent(prev_parent)
    return result
end

function _restore_parent(prev)
    if prev === nothing
        delete!(task_local_storage(), :hartzog_parent_audit_id)
    else
        task_local_storage()[:hartzog_parent_audit_id] = prev
    end
    return nothing
end

# ── Macro ─────────────────────────────────────────────────────────────────────
"""
    @audited_calculation intended_use process_risk operation expr

Wrap `expr` in a Part-11 audit record. On exception, emits an error record
and rethrows.

# Example
```julia
result = @audited_calculation "survival_analysis" HIGH "coxph.fit" begin
    _fit_coxph_impl(data, formula)
end
```
"""
macro audited_calculation(intended_use, process_risk, operation, expr)
    return quote
        $(_run_audited)(
            $(esc(intended_use)),
            $(esc(process_risk)),
            $(esc(operation)),
            () -> $(esc(expr)),
        )
    end
end

# ── Verification ──────────────────────────────────────────────────────────────
"""
    verify_record(line; hmac_key=nothing) -> Bool

Verify the HMAC integrity of a single JSONL audit-record line. The line
must have been produced by `_sign_and_write` (integrity_hmac as the final
field of the JSON object).
"""
function verify_record(line::AbstractString; hmac_key = nothing)
    # Locate the integrity_hmac field we appended as the final field
    m = match(r",\"integrity_hmac\":\"([^\"]+)\"\}\s*$", line)
    m === nothing && return false
    claimed = m.captures[1]
    payload = string(SubString(line, 1, m.offset - 1), "}")
    key = hmac_key === nothing ? _CONFIG[].hmac_key : collect(UInt8, hmac_key)
    mac = hmac_sha256(key, Vector{UInt8}(payload))
    return "sha256:" * bytes2hex(mac) == claimed
end

function verify_log_file(path::AbstractString; hmac_key=nothing)
    total = 0
    valid = 0
    bad = Int[]
    open(path, "r") do io
        for (i, line) in enumerate(eachline(io))
            isempty(strip(line)) && continue
            total += 1
            try
                verify_record(line; hmac_key=hmac_key) ? (valid += 1) : push!(bad, i)
            catch
                push!(bad, i)
            end
        end
    end
    return (total=total, valid=valid, bad_lines=bad)
end

end # module
