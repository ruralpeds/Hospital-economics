# clinical_integration/ClinicalEconomicCoupling.jl
# Couple clinical states with economic costs

struct ClinicalEconomicState
    physiological_state::Any
    daily_cost::Float64
    cumulative_cost::Float64
end
