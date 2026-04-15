# patient_flow/PatientAgent.jl
# Patient agent definition with economic tracking

abstract type PatientAgent end

struct PatientEconomic
    patient_id::String
    admission_date::Date
    los::Int
    cost_accumulator::Float64
    outcomes::Dict
end
