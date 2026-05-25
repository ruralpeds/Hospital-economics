# ============================================================================
# Requirement Traceability Matrix — GAMP 5 / IEC 62304
# ============================================================================

using Dates

# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------

"""Valid requirement status values."""
const REQUIREMENT_STATUSES = (:draft, :approved, :implemented, :verified, :retired)

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    Requirement

A single requirement with verification links and lifecycle tracking.

# Fields
- `id::String`: unique identifier (e.g. "FR-001", "NFR-002")
- `description::String`: what the requirement mandates
- `category::Symbol`: requirement category (:functional, :safety, :security, etc.)
- `status::Symbol`: lifecycle status (see `REQUIREMENT_STATUSES`)
- `source::String`: origin document or authority
- `affected_modules::Vector{String}`: modules that implement this requirement
- `verification_method::Symbol`: how verification is performed
- `verified_by::String`: identity of verifier (empty if not yet verified)
- `verified_date::Union{Nothing,DateTime}`: when verification occurred
"""
@kwdef mutable struct Requirement
    id::String
    description::String
    category::Symbol                        = :functional
    status::Symbol                          = :draft
    source::String                          = ""
    affected_modules::Vector{String}        = String[]
    verification_method::Symbol             = :unit_test
    verified_by::String                     = ""
    verified_date::Union{Nothing,DateTime}  = nothing
end

"""
    CoverageStats

Summary statistics for requirement coverage.

# Fields
- `total::Int`: total number of requirements
- `implemented::Int`: requirements in :implemented or later status
- `verified::Int`: requirements verified
- `coverage_pct::Float64`: percentage verified
- `gaps::Vector{String}`: IDs of unverified requirements
"""
struct CoverageStats
    total::Int
    implemented::Int
    verified::Int
    coverage_pct::Float64
    gaps::Vector{String}
end

"""
    TraceabilityMatrix

Registry of requirements mapped by ID with coverage statistics.

# Fields
- `requirements::Dict{String,Requirement}`: requirement ID -> Requirement
- `coverage_stats::Union{Nothing,CoverageStats}`: cached coverage (recomputed on demand)
"""
mutable struct TraceabilityMatrix
    requirements::Dict{String,Requirement}
    coverage_stats::Union{Nothing,CoverageStats}
end

# ---------------------------------------------------------------------------
# Constructor and mutators
# ---------------------------------------------------------------------------

"""
    create_traceability_matrix() -> TraceabilityMatrix

Create a new, empty traceability matrix.
"""
function create_traceability_matrix()
    return TraceabilityMatrix(Dict{String,Requirement}(), nothing)
end

"""
    add_requirement!(matrix::TraceabilityMatrix, req::Requirement)

Add a requirement to the traceability matrix. Invalidates cached coverage.
"""
function add_requirement!(matrix::TraceabilityMatrix, req::Requirement)
    matrix.requirements[req.id] = req
    matrix.coverage_stats = nothing  # invalidate cache
    return matrix
end

"""
    mark_verified!(matrix::TraceabilityMatrix, req_id::String,
                   method::Symbol, verified_by::String)

Mark a requirement as verified, recording the method, verifier, and timestamp.
Throws `KeyError` if the requirement ID is not found.
"""
function mark_verified!(matrix::TraceabilityMatrix, req_id::String,
                        method::Symbol, verified_by::String)
    req = matrix.requirements[req_id]
    req.status = :verified
    req.verification_method = method
    req.verified_by = verified_by
    req.verified_date = Dates.now()
    matrix.coverage_stats = nothing  # invalidate cache
    return matrix
end

# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

"""
    coverage_report(matrix::TraceabilityMatrix) -> CoverageStats

Compute coverage statistics: total, implemented, verified counts and gap list.
"""
function coverage_report(matrix::TraceabilityMatrix)
    reqs = values(matrix.requirements)
    total = length(reqs)

    implemented_statuses = (:implemented, :verified)
    implemented = count(r -> r.status in implemented_statuses, reqs)
    verified = count(r -> r.status == :verified, reqs)

    coverage_pct = total > 0 ? (verified / total) * 100.0 : 0.0

    gaps = [r.id for r in reqs if r.status != :verified]
    sort!(gaps)

    stats = CoverageStats(total, implemented, verified, coverage_pct, gaps)
    matrix.coverage_stats = stats
    return stats
end

"""
    find_unverified(matrix::TraceabilityMatrix) -> Vector{Requirement}

Return requirements that are implemented but not yet verified.
"""
function find_unverified(matrix::TraceabilityMatrix)
    return [r for r in values(matrix.requirements)
            if r.status == :implemented]
end

"""
    find_orphaned_tests(matrix::TraceabilityMatrix, test_ids::Vector{String}) -> Vector{String}

Return test IDs that are not linked to any requirement's verification method
or affected modules.
"""
function find_orphaned_tests(matrix::TraceabilityMatrix, test_ids::Vector{String})
    # Collect all test/module references from requirements
    linked = Set{String}()
    for req in values(matrix.requirements)
        push!(linked, req.id)
        for mod in req.affected_modules
            push!(linked, mod)
        end
    end

    return [tid for tid in test_ids if !(tid in linked)]
end
