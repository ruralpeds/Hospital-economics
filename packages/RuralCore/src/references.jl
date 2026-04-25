"""
Clinical and regulatory references for evidence-based calculations.
"""

using Dates

"""
    ClinicalReference

Metadata for a clinical or regulatory reference source.
"""
struct ClinicalReference
    id::String
    title::String
    publisher::String
    year::Int
    source::String
    doi::Union{String, Nothing}
    notes::Union{String, Nothing}
end

const REFERENCES = Dict{String, ClinicalReference}()
const CITATION_LOG = Vector{Tuple{DateTime, String, Vector{String}}}()

"""
    register_reference(ref::ClinicalReference)::ClinicalReference

Register a reference for use in calculations.
"""
function register_reference(ref::ClinicalReference)::ClinicalReference
    REFERENCES[ref.id] = ref
    ref
end

"""
    get_reference(id::String)::Union{ClinicalReference, Nothing}

Retrieve a registered reference by ID.
"""
function get_reference(id::String)::Union{ClinicalReference, Nothing}
    get(REFERENCES, id, nothing)
end

"""
    @cited refs expr

Macro to cite references during calculation.
Records which references were used for evidence tracing.
"""
macro cited(refs, expr)
    # Normalize refs to vector
    ref_vec = if isa(refs, Tuple)
        collect(refs)
    else
        [refs]
    end

    quote
        _result = $(esc(expr))
        push!(CITATION_LOG, (now(UTC), string($(expr.args[1])), $(ref_vec)))
        _result
    end
end

"""
    get_citation_log()::Vector{Tuple}

Retrieve citation log with all references used in calculations.
"""
function get_citation_log()::Vector{Tuple{DateTime, String, Vector{String}}}
    CITATION_LOG
end

"""
    clear_citation_log()

Clear all citations from current session.
"""
function clear_citation_log()
    empty!(CITATION_LOG)
end
