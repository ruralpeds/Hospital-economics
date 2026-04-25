# ==============================================================================
# audit.jl — RuralCore audit-trail layer
#
# This file provides the user-facing `@audited_calculation` macro for all
# RuralHealthPlatform packages. It delegates to the canonical
# `AuditTrail` submodule (21 CFR Part 11-aligned, HMAC-signed JSONL) and
# preserves backward compatibility with the pre-v1.0 1-argument form.
#
#   Legacy (pre-v1.0): @audited_calculation expr
#   Canonical (v1.0+): @audited_calculation intended_use process_risk operation expr
#
# The legacy form emits a DEPRECATION warning at macro expansion time and
# records with `intended_use="legacy"`, `process_risk=MEDIUM`, and
# `operation` auto-derived from the expression.
# ==============================================================================

using Dates
using JSON3

# Canonical Part 11 audit-trail submodule
include("AuditTrail.jl")

# Bring in internal helpers — intentionally NOT importing AuditTrail's own
# `@audited_calculation` macro (we define a variadic shim here instead).
using .AuditTrail: _run_audited, ProcessRisk, HIGH, MEDIUM, LOW,
                   AuditContext, with_actor,
                   configure! as _configure_audittrail!,
                   current_sink, set_sink!, set_hmac_key!, rotate_key!,
                   verify_record, verify_log_file,
                   content_hash, hmac_sha256,
                   AbstractSink, FileSink, StderrSink, NullSink, CompositeSink

# ── Variadic @audited_calculation — 1-arg legacy and 4-arg canonical ─────────

"""
    @audited_calculation intended_use process_risk operation expr   # canonical
    @audited_calculation expr                                        # legacy

Wrap `expr` in a 21 CFR Part 11-aligned audit record. On exception, emits
an error record to the audit log and rethrows.

# Arguments (canonical 4-arg form, preferred)
- `intended_use`: String tag describing what this computation is for.
- `process_risk`: `HIGH`, `MEDIUM`, or `LOW` (see `AuditTrail.ProcessRisk`).
- `operation`: Dotted name identifying the operation (e.g. `"npv.compute"`).
- `expr`: The expression to audit.

# Legacy 1-arg form
The single-argument form is retained for backward compatibility with code
written before the framework upgrade. It emits a deprecation warning at
macro-expansion time and records with default metadata:
`intended_use="legacy"`, `process_risk=MEDIUM`, and `operation` auto-derived
from the expression's call head (or `"<expr>"` if not a call).

Callers should migrate to the 4-arg form as part of their next
validation-release cycle.

# Examples
```julia
# Canonical
result = @audited_calculation "npv_analysis" HIGH "finance.npv" begin
    compute_npv(cashflows, rate)
end

# Legacy (deprecated)
result = @audited_calculation validate_fips("01001")
```
"""
macro audited_calculation(args...)
    if length(args) == 4
        intended_use, process_risk, operation, expr = args
        return quote
            $(_run_audited)(
                $(esc(intended_use)),
                $(esc(process_risk)),
                $(esc(operation)),
                () -> $(esc(expr)),
            )
        end

    elseif length(args) == 1
        expr = args[1]
        op_name = _derive_operation_name(expr)
        # Emit a compile-time deprecation warning (runs once per call site)
        @warn """
        @audited_calculation 1-arg form is deprecated; migrate to 4-arg canonical form:
            @audited_calculation "intended_use" HIGH|MEDIUM|LOW "module.operation" <expr>
        This call site will continue to work but emits records with
        intended_use="legacy" and process_risk=MEDIUM. Derived operation: $op_name
        """ _module=__module__ _file=string(__source__.file) _line=__source__.line maxlog=1
        return quote
            $(_run_audited)(
                "legacy",
                $(MEDIUM),
                $(op_name),
                () -> $(esc(expr)),
            )
        end

    else
        return :(error("@audited_calculation takes 1 or 4 arguments; got $(length(args))"))
    end
end

# Introspect an AST node to derive a reasonable operation name for legacy calls
function _derive_operation_name(expr)::String
    if expr isa Expr && expr.head == :call && !isempty(expr.args)
        return string(expr.args[1])
    elseif expr isa Symbol
        return string(expr)
    else
        return "<expr>"
    end
end

# ── Legacy AuditEntry API (backward-compat — deprecated but functional) ──────
#
# Pre-v1.0 RuralCore code materialized audit records as an in-memory
# Vector{AuditEntry}. The canonical AuditTrail writes to a configurable
# sink (typically a daily-rotated JSONL file with HMAC integrity). The
# legacy types below are retained so that existing save_audit_log /
# load_audit_log call sites continue to compile.
#
# New code should use AuditTrail.configure!(sink=FileSink("/path/audit.jsonl"))
# and AuditTrail.verify_log_file(...).

"""
    AuditEntry

**Deprecated** legacy record type retained for backward compatibility.
New code should use the Part-11 canonical JSONL schema written by
`@audited_calculation` to the configured sink.

Fields:
- `timestamp::DateTime` — UTC wall-clock time.
- `function_name::String` — operation name.
- `input_hash::String` — SHA-256 content hash of inputs.
- `output_hash::String` — SHA-256 content hash of outputs.
- `elapsed_ns::UInt64` — wall-clock elapsed nanoseconds.
- `julia_version::String` — Julia version.
- `package_version::String` — RuralCore version.
- `git_sha::String` — git commit SHA at build time.
"""
struct AuditEntry
    timestamp::DateTime
    function_name::String
    input_hash::String
    output_hash::String
    elapsed_ns::UInt64
    julia_version::String
    package_version::String
    git_sha::String
end

# Legacy in-memory log. Not thread-safe. Not used by the canonical Part 11
# audit trail; retained so that `get_audit_log()` / `save_audit_log()`
# call sites continue to compile.
const AUDIT_LOG = Vector{AuditEntry}()

"""
    get_audit_log() -> Vector{AuditEntry}

**Deprecated.** Returns the in-memory legacy log. New code should read
records from the configured AuditTrail sink directly (`AuditTrail.current_sink()`
to inspect, or read the JSONL file).
"""
function get_audit_log()::Vector{AuditEntry}
    return AUDIT_LOG
end

"""
    clear_audit_log()

**Deprecated.** Empties the in-memory legacy log. Does not affect the
durable canonical audit trail (which is append-only to the configured
sink).
"""
function clear_audit_log()
    empty!(AUDIT_LOG)
    return nothing
end

"""
    save_audit_log(filepath::String)

**Deprecated.** Writes the in-memory legacy log to `filepath` as JSONL.
Records written this way are NOT HMAC-integrity-protected and do NOT
satisfy 21 CFR Part 11. For compliance, configure the canonical
AuditTrail sink at application entry:

```julia
using RuralCore.AuditTrail
AuditTrail.configure!(
    sink = FileSink("/var/log/hartzog/audit.jsonl"),
    hmac_key = read(ENV["HARTZOG_HMAC_KEY_FILE"]),
    package = "RuralHealthPlatform",
    version = "1.0.0",
    git_commit = ENV["GIT_COMMIT"],
)
```

and records will be written automatically by every `@audited_calculation`.
"""
function save_audit_log(filepath::String)
    open(filepath, "w") do f
        for entry in AUDIT_LOG
            println(f, JSON3.write(entry))
        end
    end
    return nothing
end

"""
    load_audit_log(filepath::String) -> Vector{AuditEntry}

**Deprecated.** Loads legacy JSONL entries from `filepath`. Does not
verify HMAC integrity. For compliant verification of canonical records,
use `AuditTrail.verify_log_file(path; hmac_key=...)`.
"""
function load_audit_log(filepath::String)::Vector{AuditEntry}
    entries = AuditEntry[]
    open(filepath, "r") do f
        for line in eachline(f)
            isempty(strip(line)) && continue
            d = JSON3.read(line, Dict)
            push!(entries, AuditEntry(
                DateTime(get(d, "timestamp", string(now(UTC)))),
                get(d, "function_name", ""),
                get(d, "input_hash", ""),
                get(d, "output_hash", ""),
                UInt64(get(d, "elapsed_ns", 0)),
                get(d, "julia_version", ""),
                get(d, "package_version", ""),
                get(d, "git_sha", ""),
            ))
        end
    end
    return entries
end

# ── Convenience re-exports (RuralCore.jl will further re-export these) ───────
export AuditEntry, get_audit_log, clear_audit_log, save_audit_log, load_audit_log,
       @audited_calculation,
       # Canonical Part 11 API:
       AuditContext, with_actor,
       ProcessRisk, HIGH, MEDIUM, LOW,
       AbstractSink, FileSink, StderrSink, NullSink, CompositeSink,
       current_sink, set_sink!, set_hmac_key!, rotate_key!,
       verify_record, verify_log_file,
       content_hash, hmac_sha256
