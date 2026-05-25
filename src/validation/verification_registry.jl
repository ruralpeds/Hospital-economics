# ============================================================================
# Verification Registry — IEC 62304 Documentary Evidence
# ============================================================================

using Dates

# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------

"""Valid verification methods."""
const VERIFICATION_METHODS = (
    :unit_test, :integration_test, :property_test,
    :manual_review, :formal_proof, :parity_test,
)

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    VerificationRecord

Documentary evidence that a requirement was verified at a specific time
by a specific method.

# Fields
- `requirement_id::String`: linked requirement ID
- `method::Symbol`: verification method used (see `VERIFICATION_METHODS`)
- `test_id::String`: identifier of the test or review artefact
- `result::Symbol`: outcome (:pass, :fail, or :skip)
- `timestamp::DateTime`: when verification occurred
- `evidence::String`: free-form description or link to evidence
"""
@kwdef struct VerificationRecord
    requirement_id::String
    method::Symbol
    test_id::String
    result::Symbol               = :pass
    timestamp::DateTime          = Dates.now()
    evidence::String             = ""
end

"""
    VerificationRegistry

Persisted collection of verification records.

# Fields
- `records::Vector{VerificationRecord}`: all registered records
"""
mutable struct VerificationRegistry
    records::Vector{VerificationRecord}
end

VerificationRegistry() = VerificationRegistry(VerificationRecord[])

# ---------------------------------------------------------------------------
# Mutators
# ---------------------------------------------------------------------------

"""
    register_verification!(registry::VerificationRegistry, record::VerificationRecord)

Append a verification record to the registry.
"""
function register_verification!(registry::VerificationRegistry, record::VerificationRecord)
    push!(registry.records, record)
    return registry
end

# ---------------------------------------------------------------------------
# Coverage queries
# ---------------------------------------------------------------------------

"""
    coverage_by_requirement(registry::VerificationRegistry) -> Dict{String,Symbol}

Map each requirement ID to its aggregate verification status.

A requirement is `:pass` if at least one record passes and none fail;
`:fail` if any record fails; `:skip` if all records are skipped.
"""
function coverage_by_requirement(registry::VerificationRegistry)
    result = Dict{String,Symbol}()
    # Group records by requirement
    grouped = Dict{String,Vector{VerificationRecord}}()
    for rec in registry.records
        recs = get!(grouped, rec.requirement_id, VerificationRecord[])
        push!(recs, rec)
    end

    for (req_id, recs) in grouped
        has_fail = any(r -> r.result == :fail, recs)
        has_pass = any(r -> r.result == :pass, recs)
        if has_fail
            result[req_id] = :fail
        elseif has_pass
            result[req_id] = :pass
        else
            result[req_id] = :skip
        end
    end
    return result
end

"""
    coverage_by_method(registry::VerificationRegistry) -> Dict{Symbol,Int}

Count the number of verification records by method type.
"""
function coverage_by_method(registry::VerificationRegistry)
    result = Dict{Symbol,Int}()
    for rec in registry.records
        result[rec.method] = get(result, rec.method, 0) + 1
    end
    return result
end

"""
    generate_coverage_report(registry::VerificationRegistry,
                             requirements::Vector{String}) -> NamedTuple

Compute overall coverage against a known set of requirement IDs.

Returns a NamedTuple with:
- `total`: number of requirements
- `verified`: number with at least one passing record
- `failed`: number with a failing record
- `unverified`: requirement IDs with no records
- `coverage_pct`: percentage of requirements verified
"""
function generate_coverage_report(registry::VerificationRegistry,
                                  requirements::Vector{String})
    req_status = coverage_by_requirement(registry)
    verified = 0
    failed = 0
    unverified = String[]

    for req_id in requirements
        status = get(req_status, req_id, nothing)
        if status === nothing
            push!(unverified, req_id)
        elseif status == :pass
            verified += 1
        elseif status == :fail
            failed += 1
        end
    end

    total = length(requirements)
    coverage_pct = total > 0 ? (verified / total) * 100.0 : 0.0

    return (total=total, verified=verified, failed=failed,
            unverified=unverified, coverage_pct=coverage_pct)
end
