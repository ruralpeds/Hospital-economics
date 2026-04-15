# patient_flow/ClinicalPathway.jl
# Clinical pathway definitions

struct ClinicalPathway
    pathway_id::String
    primary_diagnosis::String
    expected_los::Int
    typical_procedures::Vector{String}
    cost_model::String
end
