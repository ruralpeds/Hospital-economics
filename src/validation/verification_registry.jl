"""
    VerificationRegistry

Registry tracking which hospital finance calculations have been independently
verified against an external reference (Excel models, R/Python packages,
hand-computed values, peer review, etc.).

Each [`VerificationEntry`] documents *who* verified *what* function *when*,
*against which reference*, and *within what tolerance*. The registry persists
to JSON so the verification history travels with the repository.

This is a Julia port of the `cah-validation::verification` Rust module,
adapted for the Hospital-economics codebase.
"""
module VerificationRegistryModule

using Dates
using JSON3

export VerificationStatus, not_verified, verified, stale, failed
export VerificationEntry, VerificationRegistry
export register_verification!, mark_stale!, mark_failed!
export query_verifications, verification_coverage, critical_unverified
export export_verification_report, VERIFICATION_REGISTRY

"""
    VerificationStatus

Lifecycle state of a verification record.

* `not_verified` — function is registered but no verification attempt yet.
* `verified`     — last run matched the reference within tolerance.
* `stale`        — source code changed since the last successful verification.
* `failed`       — last run did not match the reference.
"""
@enum VerificationStatus begin
    not_verified = 0
    verified = 1
    stale = 2
    failed = 3
end

"""
    VerificationEntry

A single immutable-in-spirit verification record.

# Fields
- `function_name::String`      — fully qualified name (e.g. `"finance.dscr"`)
- `module_name::String`        — Julia module the function lives in
- `status::VerificationStatus` — current lifecycle state
- `verified_by::String`        — reference authority (e.g. `"Excel reference model v3.1"`,
  `"R survminer 0.4.9"`, or a domain-expert name)
- `verified_at::DateTime`      — UTC timestamp of the most recent state change
- `reference_source::String`   — citation or path to the external reference artifact
- `tolerance::Float64`         — numeric tolerance used at verification time
- `notes::String`              — free-form notes from the verifier
"""
mutable struct VerificationEntry
    function_name::String
    module_name::String
    status::VerificationStatus
    verified_by::String
    verified_at::DateTime
    reference_source::String
    tolerance::Float64
    notes::String
end

"""
    VerificationRegistry

Thread-safe registry of [`VerificationEntry`] keyed by `function_name`.
"""
mutable struct VerificationRegistry
    entries::Dict{String, VerificationEntry}
    lock::ReentrantLock
end

VerificationRegistry() = VerificationRegistry(Dict{String, VerificationEntry}(), ReentrantLock())

"""
    register_verification!(reg, function_name, module_name, verified_by,
                           reference_source; tolerance=1e-6, notes="")

Insert (or overwrite) a verification record marking `function_name` as
`verified` against `reference_source`. Returns the entry.
"""
function register_verification!(reg::VerificationRegistry,
                                function_name::AbstractString,
                                module_name::AbstractString,
                                verified_by::AbstractString,
                                reference_source::AbstractString;
                                tolerance::Float64 = 1e-6,
                                notes::AbstractString = "")
    entry = VerificationEntry(
        String(function_name),
        String(module_name),
        verified,
        String(verified_by),
        now(UTC),
        String(reference_source),
        tolerance,
        String(notes),
    )
    lock(reg.lock) do
        reg.entries[String(function_name)] = entry
    end
    return entry
end

"""
    mark_stale!(reg, function_name; reason="")

Flag a previously verified function as stale because its source code (or a
fixture it depends on) has changed. Appends `reason` to the notes.
"""
function mark_stale!(reg::VerificationRegistry,
                     function_name::AbstractString;
                     reason::AbstractString = "")
    key = String(function_name)
    lock(reg.lock) do
        if haskey(reg.entries, key)
            entry = reg.entries[key]
            entry.status = stale
            entry.verified_at = now(UTC)
            if !isempty(reason)
                entry.notes = isempty(entry.notes) ?
                    "stale: $(reason)" :
                    string(entry.notes, " | stale: ", reason)
            end
        end
    end
    return reg
end

"""
    mark_failed!(reg, function_name, reason)

Flag a function whose verification run did not match the reference.
"""
function mark_failed!(reg::VerificationRegistry,
                      function_name::AbstractString,
                      reason::AbstractString)
    key = String(function_name)
    lock(reg.lock) do
        if haskey(reg.entries, key)
            entry = reg.entries[key]
            entry.status = failed
            entry.verified_at = now(UTC)
            entry.notes = isempty(entry.notes) ?
                "failed: $(reason)" :
                string(entry.notes, " | failed: ", reason)
        end
    end
    return reg
end

"""
    query_verifications(reg; status=nothing, module_name=nothing)

Return a vector of entries matching the given filters. Both filters are
optional and combine with logical AND.
"""
function query_verifications(reg::VerificationRegistry;
                             status::Union{Nothing, VerificationStatus} = nothing,
                             module_name::Union{Nothing, AbstractString} = nothing)::Vector{VerificationEntry}
    results = VerificationEntry[]
    lock(reg.lock) do
        for entry in values(reg.entries)
            (status !== nothing) && entry.status != status && continue
            (module_name !== nothing) && entry.module_name != String(module_name) && continue
            push!(results, entry)
        end
    end
    return results
end

"""
    verification_coverage(reg, all_functions) -> NamedTuple

Compute coverage of `all_functions` against the registry. Returns a named
tuple with totals and a `coverage_pct` (0–100) treating only `verified` as
fully covered.
"""
function verification_coverage(reg::VerificationRegistry,
                               all_functions::Vector{String})::NamedTuple
    total = length(all_functions)
    v_count = 0
    s_count = 0
    f_count = 0
    nv_count = 0
    lock(reg.lock) do
        for fn in all_functions
            entry = get(reg.entries, fn, nothing)
            if entry === nothing
                nv_count += 1
            elseif entry.status == verified
                v_count += 1
            elseif entry.status == stale
                s_count += 1
            elseif entry.status == failed
                f_count += 1
            else
                nv_count += 1
            end
        end
    end
    coverage_pct = total == 0 ? 0.0 : 100.0 * v_count / total
    return (total = total,
            verified = v_count,
            stale = s_count,
            failed = f_count,
            not_verified = nv_count,
            coverage_pct = coverage_pct)
end

"""
    critical_unverified(reg, critical_functions) -> Vector{String}

Return the subset of `critical_functions` whose registry entry is missing,
stale, failed, or not verified. These are the functions that should block a
release on the basis of verification gaps.
"""
function critical_unverified(reg::VerificationRegistry,
                             critical_functions::Vector{String})::Vector{String}
    missing_or_bad = String[]
    lock(reg.lock) do
        for fn in critical_functions
            entry = get(reg.entries, fn, nothing)
            if entry === nothing || entry.status != verified
                push!(missing_or_bad, fn)
            end
        end
    end
    return missing_or_bad
end

# JSON3 needs help with enums and DateTime
_status_str(s::VerificationStatus) = s == verified ? "verified" :
                                     s == stale ? "stale" :
                                     s == failed ? "failed" : "not_verified"

function _entry_to_dict(e::VerificationEntry)
    return Dict(
        "function_name" => e.function_name,
        "module_name" => e.module_name,
        "status" => _status_str(e.status),
        "verified_by" => e.verified_by,
        "verified_at" => string(e.verified_at),
        "reference_source" => e.reference_source,
        "tolerance" => e.tolerance,
        "notes" => e.notes,
    )
end

"""
    export_verification_report(reg, filepath)

Persist the registry to `filepath` as pretty-printed JSON, sorted by
`function_name` for diff-friendliness.
"""
function export_verification_report(reg::VerificationRegistry, filepath::AbstractString)
    payload = lock(reg.lock) do
        keys_sorted = sort(collect(keys(reg.entries)))
        records = Dict{String, Any}()
        for k in keys_sorted
            records[k] = _entry_to_dict(reg.entries[k])
        end
        Dict(
            "generated_at" => string(now(UTC)),
            "total_entries" => length(keys_sorted),
            "records" => records,
        )
    end

    parent = dirname(String(filepath))
    if !isempty(parent) && !isdir(parent)
        mkpath(parent)
    end
    open(String(filepath), "w") do io
        JSON3.pretty(io, payload)
        write(io, "\n")
    end
    return String(filepath)
end

"""
    VERIFICATION_REGISTRY

Process-wide singleton [`VerificationRegistry`]. Library code should record
verifications here so the global health of the calculation surface can be
queried from anywhere.
"""
const VERIFICATION_REGISTRY = VerificationRegistry()

end # module
