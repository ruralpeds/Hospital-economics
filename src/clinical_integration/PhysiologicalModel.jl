# clinical_integration/PhysiologicalModel.jl
# Interface for physiological models like PedNeoSim.jl

abstract type PhysiologicalModelInterface end

struct PatientPhysiologicalState
    state_vars::Dict
    time::Float64
end
