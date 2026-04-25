"""
    value_based_care.jl — VBC metrics

Migrated from healthcare-finance-julia/src/value_based_care_engine.jl.
"""

"""Value score = outcomes / cost."""
function value_score(outcomes::Real, cost::Real)
    cost == 0 && throw(ArgumentError("cost cannot be zero"))
    return @audited_calculation _value_score(outcomes, cost)
end
_value_score(outcomes, cost) = outcomes / cost

"""Quality-adjusted life years."""
function qalys(years::Real, quality_weight::Real)
    return @audited_calculation _qalys(years, quality_weight)
end
_qalys(years, quality_weight) = years * quality_weight
