"""
    RequirementsTraceability

Requirements traceability matrix linking code to formal requirements
(functional, security, performance, regulatory, usability).

This is the Julia port of the `cah-validation::requirements` Rust module,
extended with a pre-populated catalog of HIPAA Technical Safeguards
(§164.312) so that auditors can immediately see which code paths satisfy
which control.
"""
module RequirementsTraceabilityModule

using Dates
using JSON3
using CSV
using DataFrames

export RequirementSeverity, RequirementCategory
export Requirement, CodeLink, TraceabilityMatrix
export add_requirement!, link_code!, traceability_report
export unlinked_requirements, requirements_for_file, export_traceability_matrix
export HIPAA_REQUIREMENTS, TRACEABILITY_MATRIX

"""Requirement severity per IEC 62304-style risk classification."""
@enum RequirementSeverity begin
    critical = 0
    high = 1
    medium = 2
    low = 3
end

"""Requirement category — what *kind* of requirement this is."""
@enum RequirementCategory begin
    functional = 0
    security = 1
    performance = 2
    regulatory = 3
    usability = 4
end

"""
    Requirement

A single formal requirement.

# Fields
- `id::String`                       — e.g. `"REQ-FIN-001"`, `"HIPAA-164.312-a"`
- `title::String`
- `description::String`
- `severity::RequirementSeverity`
- `category::RequirementCategory`
- `source::String`                   — provenance (e.g. `"HIPAA §164.312"`,
  `"User Story #42"`)
"""
struct Requirement
    id::String
    title::String
    description::String
    severity::RequirementSeverity
    category::RequirementCategory
    source::String
end

"""
    CodeLink

Maps a single code site to a requirement.

# Fields
- `requirement_id::String`
- `file_path::String`
- `function_name::String`
- `test_files::Vector{String}` — tests that exercise this link
- `verified::Bool`             — `true` once the link has at least one passing test
"""
mutable struct CodeLink
    requirement_id::String
    file_path::String
    function_name::String
    test_files::Vector{String}
    verified::Bool
end

"""
    TraceabilityMatrix

Thread-safe registry of requirements and their code links.
"""
mutable struct TraceabilityMatrix
    requirements::Dict{String, Requirement}
    links::Vector{CodeLink}
    lock::ReentrantLock
end

TraceabilityMatrix() = TraceabilityMatrix(
    Dict{String, Requirement}(),
    CodeLink[],
    ReentrantLock(),
)

"""
    add_requirement!(matrix, req)

Insert (or overwrite) a requirement keyed by `req.id`.
"""
function add_requirement!(matrix::TraceabilityMatrix, req::Requirement)
    lock(matrix.lock) do
        matrix.requirements[req.id] = req
    end
    return matrix
end

"""
    link_code!(matrix, requirement_id, file_path, function_name; test_files=String[])

Record that `function_name` in `file_path` implements `requirement_id`. The
link is marked `verified = true` iff at least one test file is supplied.
"""
function link_code!(matrix::TraceabilityMatrix,
                    requirement_id::AbstractString,
                    file_path::AbstractString,
                    function_name::AbstractString;
                    test_files::Vector{String} = String[])
    link = CodeLink(
        String(requirement_id),
        String(file_path),
        String(function_name),
        copy(test_files),
        !isempty(test_files),
    )
    lock(matrix.lock) do
        push!(matrix.links, link)
    end
    return link
end

"""
    traceability_report(matrix) -> NamedTuple

Summary statistics across the matrix:

- `total_requirements`
- `linked_count`     — requirements that have at least one code link
- `coverage_pct`     — `100 * linked_count / total_requirements`
- `by_severity`      — `Dict{RequirementSeverity, NamedTuple{total, linked}}`
"""
function traceability_report(matrix::TraceabilityMatrix)::NamedTuple
    lock(matrix.lock) do
        total = length(matrix.requirements)
        linked_ids = Set{String}(link.requirement_id for link in matrix.links)
        linked_count = count(id -> id in linked_ids, keys(matrix.requirements))

        by_severity = Dict{RequirementSeverity, NamedTuple{(:total, :linked), Tuple{Int, Int}}}()
        for sev in (critical, high, medium, low)
            total_s = 0
            linked_s = 0
            for (id, req) in matrix.requirements
                if req.severity == sev
                    total_s += 1
                    if id in linked_ids
                        linked_s += 1
                    end
                end
            end
            by_severity[sev] = (total = total_s, linked = linked_s)
        end

        coverage_pct = total == 0 ? 0.0 : 100.0 * linked_count / total
        return (total_requirements = total,
                linked_count = linked_count,
                coverage_pct = coverage_pct,
                by_severity = by_severity)
    end
end

"""
    unlinked_requirements(matrix) -> Vector{String}

Return the sorted IDs of requirements with no associated code link. These
are the most likely sources of regulatory gaps and should be triaged.
"""
function unlinked_requirements(matrix::TraceabilityMatrix)::Vector{String}
    lock(matrix.lock) do
        linked_ids = Set{String}(link.requirement_id for link in matrix.links)
        return sort([id for id in keys(matrix.requirements) if !(id in linked_ids)])
    end
end

"""
    requirements_for_file(matrix, file_path) -> Vector{Requirement}

Return all requirements that have at least one code link in `file_path`.
"""
function requirements_for_file(matrix::TraceabilityMatrix,
                               file_path::AbstractString)::Vector{Requirement}
    target = String(file_path)
    lock(matrix.lock) do
        ids = Set{String}()
        for link in matrix.links
            if link.file_path == target
                push!(ids, link.requirement_id)
            end
        end
        return Requirement[matrix.requirements[id] for id in ids if haskey(matrix.requirements, id)]
    end
end

_severity_str(s::RequirementSeverity) = s == critical ? "critical" :
                                         s == high ? "high" :
                                         s == medium ? "medium" : "low"

_category_str(c::RequirementCategory) = c == functional ? "functional" :
                                         c == security ? "security" :
                                         c == performance ? "performance" :
                                         c == regulatory ? "regulatory" : "usability"

"""
    export_traceability_matrix(matrix, filepath; format=:csv)

Persist the matrix to `filepath`. Supported formats are `:csv` (one row per
link, requirements without links produce a single row with empty link
columns) and `:json` (structured dump of requirements and links).
"""
function export_traceability_matrix(matrix::TraceabilityMatrix,
                                    filepath::AbstractString;
                                    format::Symbol = :csv)
    parent = dirname(String(filepath))
    if !isempty(parent) && !isdir(parent)
        mkpath(parent)
    end

    if format === :csv
        rows = lock(matrix.lock) do
            r = NamedTuple[]
            linked_ids = Set{String}(link.requirement_id for link in matrix.links)
            # one row per link
            for link in matrix.links
                req = get(matrix.requirements, link.requirement_id, nothing)
                push!(r, (
                    requirement_id = link.requirement_id,
                    title          = req === nothing ? "" : req.title,
                    severity       = req === nothing ? "" : _severity_str(req.severity),
                    category       = req === nothing ? "" : _category_str(req.category),
                    source         = req === nothing ? "" : req.source,
                    file_path      = link.file_path,
                    function_name  = link.function_name,
                    test_files     = join(link.test_files, "|"),
                    verified       = link.verified,
                ))
            end
            # one row per unlinked requirement
            for (id, req) in matrix.requirements
                if !(id in linked_ids)
                    push!(r, (
                        requirement_id = id,
                        title          = req.title,
                        severity       = _severity_str(req.severity),
                        category       = _category_str(req.category),
                        source         = req.source,
                        file_path      = "",
                        function_name  = "",
                        test_files     = "",
                        verified       = false,
                    ))
                end
            end
            r
        end
        df = DataFrame(rows)
        CSV.write(String(filepath), df)
    elseif format === :json
        payload = lock(matrix.lock) do
            reqs = Dict{String, Any}()
            for (id, req) in matrix.requirements
                reqs[id] = Dict(
                    "id" => req.id,
                    "title" => req.title,
                    "description" => req.description,
                    "severity" => _severity_str(req.severity),
                    "category" => _category_str(req.category),
                    "source" => req.source,
                )
            end
            links = [Dict(
                "requirement_id" => l.requirement_id,
                "file_path" => l.file_path,
                "function_name" => l.function_name,
                "test_files" => l.test_files,
                "verified" => l.verified,
            ) for l in matrix.links]
            Dict("generated_at" => string(now(UTC)),
                 "requirements" => reqs,
                 "links" => links)
        end
        open(String(filepath), "w") do io
            JSON3.pretty(io, payload)
            write(io, "\n")
        end
    else
        throw(ArgumentError("Unsupported export format: $format (expected :csv or :json)"))
    end
    return String(filepath)
end

"""
    HIPAA_REQUIREMENTS

Pre-populated dictionary of HIPAA Technical Safeguards from 45 CFR §164.312
that are most often implicated by hospital-economics calculation pipelines
that handle PHI-derived aggregates.
"""
const HIPAA_REQUIREMENTS = Dict{String, Requirement}(
    "HIPAA-164.312-a-1" => Requirement(
        "HIPAA-164.312-a-1",
        "Access Control — Unique User Identification",
        "Assign a unique name and/or number for identifying and tracking user identity.",
        critical,
        security,
        "HIPAA §164.312(a)(1)",
    ),
    "HIPAA-164.312-a-2-i" => Requirement(
        "HIPAA-164.312-a-2-i",
        "Access Control — Emergency Access Procedure",
        "Establish procedures for obtaining necessary ePHI during an emergency.",
        high,
        security,
        "HIPAA §164.312(a)(2)(i)",
    ),
    "HIPAA-164.312-a-2-iii" => Requirement(
        "HIPAA-164.312-a-2-iii",
        "Access Control — Automatic Logoff",
        "Implement electronic procedures that terminate an electronic session after a predetermined time of inactivity.",
        medium,
        security,
        "HIPAA §164.312(a)(2)(iii)",
    ),
    "HIPAA-164.312-a-2-iv" => Requirement(
        "HIPAA-164.312-a-2-iv",
        "Access Control — Encryption and Decryption",
        "Implement a mechanism to encrypt and decrypt electronic protected health information.",
        critical,
        security,
        "HIPAA §164.312(a)(2)(iv)",
    ),
    "HIPAA-164.312-b" => Requirement(
        "HIPAA-164.312-b",
        "Audit Controls",
        "Implement hardware, software, and/or procedural mechanisms that record and examine activity in information systems that contain or use ePHI.",
        critical,
        regulatory,
        "HIPAA §164.312(b)",
    ),
    "HIPAA-164.312-c-1" => Requirement(
        "HIPAA-164.312-c-1",
        "Integrity — Protection from Improper Alteration",
        "Implement policies and procedures to protect ePHI from improper alteration or destruction.",
        critical,
        regulatory,
        "HIPAA §164.312(c)(1)",
    ),
    "HIPAA-164.312-c-2" => Requirement(
        "HIPAA-164.312-c-2",
        "Integrity — Mechanism to Authenticate ePHI",
        "Implement electronic mechanisms to corroborate that ePHI has not been altered or destroyed in an unauthorized manner.",
        high,
        regulatory,
        "HIPAA §164.312(c)(2)",
    ),
    "HIPAA-164.312-d" => Requirement(
        "HIPAA-164.312-d",
        "Person or Entity Authentication",
        "Implement procedures to verify that a person or entity seeking access to ePHI is the one claimed.",
        critical,
        security,
        "HIPAA §164.312(d)",
    ),
    "HIPAA-164.312-e-1" => Requirement(
        "HIPAA-164.312-e-1",
        "Transmission Security",
        "Implement technical security measures to guard against unauthorized access to ePHI being transmitted over an electronic communications network.",
        critical,
        security,
        "HIPAA §164.312(e)(1)",
    ),
    "HIPAA-164.312-e-2-i" => Requirement(
        "HIPAA-164.312-e-2-i",
        "Transmission Security — Integrity Controls",
        "Implement security measures to ensure that electronically transmitted ePHI is not improperly modified without detection until disposed of.",
        high,
        security,
        "HIPAA §164.312(e)(2)(i)",
    ),
    "HIPAA-164.312-e-2-ii" => Requirement(
        "HIPAA-164.312-e-2-ii",
        "Transmission Security — Encryption",
        "Implement a mechanism to encrypt ePHI whenever deemed appropriate.",
        critical,
        security,
        "HIPAA §164.312(e)(2)(ii)",
    ),
)

"""
    TRACEABILITY_MATRIX

Process-wide singleton [`TraceabilityMatrix`], pre-seeded with the
[`HIPAA_REQUIREMENTS`] catalog.
"""
const TRACEABILITY_MATRIX = TraceabilityMatrix()

function __init__()
    # Seed the global matrix with HIPAA requirements at module load.
    for req in values(HIPAA_REQUIREMENTS)
        add_requirement!(TRACEABILITY_MATRIX, req)
    end
end

end # module
