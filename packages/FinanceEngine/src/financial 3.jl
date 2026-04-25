"""
    financial.jl — Core financial metrics

Migrated from healthcare-finance-julia/src/financial_engine.jl.
"""

"""Net present value using period-indexed cashflows (first cashflow discounted one period)."""
function npv(rate::Real, cashflows::AbstractVector{<:Real})
    return @audited_calculation _npv(rate, cashflows)
end
_npv(rate, cashflows) = sum(cf / (1 + rate)^t for (t, cf) in enumerate(cashflows))

"""Return on investment."""
function roi(gain::Real, cost::Real)
    cost == 0 && throw(ArgumentError("cost cannot be zero"))
    return @audited_calculation _roi(gain, cost)
end
_roi(gain, cost) = (gain - cost) / cost

"""Operating margin = (revenue - expense) / revenue."""
function operating_margin(revenue::Real, expense::Real)
    revenue == 0 && throw(ArgumentError("revenue cannot be zero"))
    return @audited_calculation _operating_margin(revenue, expense)
end
_operating_margin(revenue, expense) = (revenue - expense) / revenue

"""Cost per patient encounter."""
function cost_per_patient(total_cost::Real, encounters::Real)
    encounters == 0 && throw(ArgumentError("encounters cannot be zero"))
    return @audited_calculation _cost_per_patient(total_cost, encounters)
end
_cost_per_patient(total_cost, encounters) = total_cost / encounters

"""Break-even volume in units."""
function break_even_units(fixed_cost::Real, unit_price::Real, unit_variable_cost::Real)
    contribution_margin = unit_price - unit_variable_cost
    contribution_margin <= 0 && throw(ArgumentError("unit price must exceed variable cost"))
    return @audited_calculation _break_even_units(fixed_cost, contribution_margin)
end
_break_even_units(fixed_cost, contribution_margin) = fixed_cost / contribution_margin

"""Payback period in whole and partial periods. Returns `missing` when not achieved."""
function payback_period(initial_investment::Real, cashflows::AbstractVector{<:Real})
    return @audited_calculation _payback_period(initial_investment, cashflows)
end
function _payback_period(initial_investment, cashflows)
    remaining = initial_investment
    for (i, cf) in enumerate(cashflows)
        if cf <= 0
            remaining -= cf
            continue
        end
        if cf >= remaining
            fraction = remaining / cf
            return (i - 1) + fraction
        end
        remaining -= cf
    end
    return missing
end

"""Simple DRG revenue estimate."""
function drg_revenue(base_rate::Real, weight::Real, cases::Integer)
    return @audited_calculation _drg_revenue(base_rate, weight, cases)
end
_drg_revenue(base_rate, weight, cases) = base_rate * weight * cases

"""Weighted average payer rate from rates and payer shares."""
function weighted_payer_rate(rates::AbstractVector{<:Real}, shares::AbstractVector{<:Real})
    length(rates) == length(shares) || throw(ArgumentError("rates and shares must have same length"))
    return @audited_calculation _weighted_payer_rate(rates, shares)
end
_weighted_payer_rate(rates, shares) = sum(r * s for (r, s) in zip(rates, shares))

"""Net collection rate = payments / (charges - contractual_adjustments)."""
function net_collection_rate(payments::Real, charges::Real, contractual_adjustments::Real)
    denominator = charges - contractual_adjustments
    denominator == 0 && throw(ArgumentError("charges minus contractual adjustments cannot be zero"))
    return @audited_calculation _net_collection_rate(payments, denominator)
end
_net_collection_rate(payments, denominator) = payments / denominator
