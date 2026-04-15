# payer_models/BudgetImpactModel.jl
# 3-year budget impact modeling

struct BudgetImpactResult
    year1::Float64
    year2::Float64
    year3::Float64
    total_impact::Float64
end

function calculate_budget_impact(intervention::String, cohort_size::Int)
    nothing
end
