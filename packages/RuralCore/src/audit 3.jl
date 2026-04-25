"""
    audit.jl — Audit logging infrastructure

Tracks statistical calculations with provenance for compliance and reproducibility.
Produces immutable JSONL records containing timestamp, function name, input hash,
output hash, Julia version, package version, and git SHA.
"""

"""
    AuditEntry

Immutable record of a single audited calculation. Fields:
- `id`            — unique UUID for this record
- `timestamp`     — UTC DateTime of execution
- `function_name` — name of the audited function
- `args_summary`  — human-readable summary of arguments
- `result_summary`— human-readable summary of the return value
- `input_hash`    — FNV-1a 32-bit hex digest of serialised arguments
- `output_hash`   — FNV-1a 32-bit hex digest of serialised result
- `elapsed_ns`    — wall-clock time in nanoseconds
- `session_id`    — UUID shared across all entries in a Julia session
- `user`          — OS username (`\$USER` / `\$USERNAME`)
- `julia_version`  — `VERSION` string at call time
- `package_version`— version string from RuralCore `Project.toml`
- `git_sha`       — HEAD commit SHA (empty string if unavailable)
"""
struct AuditEntry
    id::UUID
    timestamp::DateTime
    function_name::String
    args_summary::String
    result_summary::String
    input_hash::String
    output_hash::String
    elapsed_ns::Int64
    session_id::UUID
    user::String
    julia_version::String
    package_version::String
    git_sha::String
end

function Base.show(io::IO, e::AuditEntry)
    print(io, "AuditEntry($(e.timestamp) | $(e.function_name) | $(e.args_summary) → $(e.result_summary))")
end

# ── Module-level storage ────────────────────────────────────────────────────

const _AUDIT_LOG = AuditEntry[]
const _SESSION_ID = UUIDs.uuid4()

"""Return a copy of the in-memory audit log."""
get_audit_log() = copy(_AUDIT_LOG)

"""Clear the in-memory audit log."""
function clear_audit_log()
    empty!(_AUDIT_LOG)
    return nothing
end

_current_user() = get(ENV, "USER", get(ENV, "USERNAME", "unknown"))

# ── Provenance helpers ──────────────────────────────────────────────────────

"""Return a simple hex hash of the string representation of `x`."""
function _hash_value(@nospecialize(x))::String
    bytes = Vector{UInt8}(string(x))
    h = zero(UInt32)
    for b in bytes
        h = h * 0x01000193 ⊻ UInt32(b)   # FNV-1a 32-bit (no extra deps)
    end
    return string(h, base=16, pad=8)
end

"""Return the HEAD git SHA of the repository, or an empty string."""
function _git_sha()::String
    try
        sha = strip(read(`git rev-parse --short HEAD`, String))
        return sha
    catch
        return ""
    end
end

const _PACKAGE_VERSION = let
    toml_path = joinpath(@__DIR__, "..", "Project.toml")
    ver = "unknown"
    if isfile(toml_path)
        for line in eachline(toml_path)
            m = match(r"""^version\s*=\s*"([^"]+)""", line)
            if m !== nothing
                ver = m.captures[1]
                break
            end
        end
    end
    ver
end

const _GIT_SHA = _git_sha()

# ── Summarise helper ────────────────────────────────────────────────────────

function _summarize(@nospecialize(x))
    if x isa AbstractArray
        return "$(typeof(x))($(join(size(x), "×")))"
    elseif x isa Number
        return string(x)
    elseif x isa AbstractString
        n = length(x)
        return n <= 40 ? "\"$x\"" : "\"$(first(x, 37))…\""
    elseif x isa Tuple
        return "($(join((_summarize(v) for v in x), ", ")))"
    else
        return string(typeof(x))
    end
end

# ── JSON helpers ────────────────────────────────────────────────────────────

"""Escape a string for embedding in a JSON value."""
function _json_escape(s::AbstractString)
    buf = IOBuffer()
    for c in s
        if c == '"'
            write(buf, "\\\"")
        elseif c == '\\'
            write(buf, "\\\\")
        elseif c == '\n'
            write(buf, "\\n")
        elseif c == '\r'
            write(buf, "\\r")
        elseif c == '\t'
            write(buf, "\\t")
        else
            write(buf, c)
        end
    end
    return String(take!(buf))
end

"""Serialise an `AuditEntry` to a single-line JSON string."""
function _entry_to_json(e::AuditEntry)
    return string(
        "{",
        "\"id\":\"", _json_escape(string(e.id)), "\",",
        "\"timestamp\":\"", _json_escape(string(e.timestamp)), "\",",
        "\"function_name\":\"", _json_escape(e.function_name), "\",",
        "\"args_summary\":\"", _json_escape(e.args_summary), "\",",
        "\"result_summary\":\"", _json_escape(e.result_summary), "\",",
        "\"input_hash\":\"", _json_escape(e.input_hash), "\",",
        "\"output_hash\":\"", _json_escape(e.output_hash), "\",",
        "\"elapsed_ns\":", e.elapsed_ns, ",",
        "\"session_id\":\"", _json_escape(string(e.session_id)), "\",",
        "\"user\":\"", _json_escape(e.user), "\",",
        "\"julia_version\":\"", _json_escape(e.julia_version), "\",",
        "\"package_version\":\"", _json_escape(e.package_version), "\",",
        "\"git_sha\":\"", _json_escape(e.git_sha), "\"",
        "}"
    )
end

# ── Persistence ─────────────────────────────────────────────────────────────

"""
    save_audit_log(path::String)

Append all in-memory audit entries to `path` as JSONL (one JSON object per line).
If `path` ends with `.csv` the legacy CSV format is used instead for backward
compatibility.
"""
function save_audit_log(path::String)
    if endswith(path, ".csv")
        open(path, "w") do io
            println(io, "id,timestamp,function_name,args_summary,result_summary,elapsed_ns,session_id,user")
            for entry in _AUDIT_LOG
                println(io, join([
                    entry.id, entry.timestamp, entry.function_name,
                    replace(entry.args_summary, "," => ";"),
                    replace(entry.result_summary, "," => ";"),
                    entry.elapsed_ns, entry.session_id, entry.user
                ], ","))
            end
        end
    else
        open(path, "a") do io
            for entry in _AUDIT_LOG
                println(io, _entry_to_json(entry))
            end
        end
    end
    return path
end

# ── Macro ───────────────────────────────────────────────────────────────────

"""
    @audited_calculation(expr)

Wrap a function call to record timing and provenance in the audit log.
Each invocation appends an immutable `AuditEntry` containing: timestamp,
function name, argument/result summaries, SHA hashes of inputs and outputs,
Julia version, RuralCore package version, and git SHA.

# Example
```julia
result = @audited_calculation my_function(arg1, arg2)
```
"""
macro audited_calculation(expr)
    if expr.head == :call
        func_name = string(expr.args[1])
        # Filter out keyword argument :parameters nodes to avoid semicolons in array literals
        positional_args = filter(a -> !(a isa Expr && a.head == :parameters), expr.args[2:end])
        return quote
            local _args_tuple = ($(esc.(positional_args)...),)
            local _input_hash = _hash_value(_args_tuple)
            local _start = time_ns()
            local _result = $(esc(expr))
            local _elapsed = time_ns() - _start
            local _output_hash = _hash_value(_result)
            local _entry = AuditEntry(
                UUIDs.uuid4(),
                Dates.now(Dates.UTC),
                $func_name,
                join([_summarize(a) for a in [$(esc.(positional_args)...)]], ", "),
                _summarize(_result),
                _input_hash,
                _output_hash,
                _elapsed,
                _SESSION_ID,
                _current_user(),
                string(VERSION),
                _PACKAGE_VERSION,
                _GIT_SHA,
            )
            push!(_AUDIT_LOG, _entry)
            _result
        end
    else
        return esc(expr)
    end
end
