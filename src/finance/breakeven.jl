# Break-even analysis for Rural Hospital Economics Simulator
#
# Provides contribution-margin-based break-even calculations for hospital
# services and payer-specific break-even analysis critical for rural
# hospital strategic planning.

"""
    BreakEvenResult

Results of a break-even analysis for a service or payer category.

# Fields
- `break_even_volume::Float64`: volume of units needed to break even
- `current_volume::Float64`: actual or projected volume
- `cushion_pct::Float64`: percentage above (positive) or below (negative) break-even
- `contribution_margin_per_unit::Float64`: revenue per unit minus variable cost per unit
- `fixed_costs::Float64`: total fixed costs allocated to this analysis
- `variable_cost_per_unit::Float64`: variable cost per unit of service
- `revenue_per_unit::Float64`: average revenue per unit of service
"""
@kwdef struct BreakEvenResult
    break_even_volume::Float64
    current_volume::Float64 = 0.0
    cushion_pct::Float64 = 0.0
    contribution_margin_per_unit::Float64
    fixed_costs::Float64
    variable_cost_per_unit::Float64
    revenue_per_unit::Float64
end

function Base.show(io::IO, r::BreakEvenResult)
    cushion_str = r.cushion_pct >= 0 ? "+" : ""
    print(io, "BreakEvenResult(BE=$(round(Int, r.break_even_volume)), current=$(round(Int, r.current_volume)), cushion=$(cushion_str)$(round(r.cushion_pct * 100, digits=1))%)")
end

"""
    calculate_break_even(fixed_costs::Float64, variable_cost_per_unit::Float64,
                         revenue_per_unit::Float64; current_volume::Float64=0.0) -> BreakEvenResult

Calculate break-even volume using the contribution margin approach:
    break_even_volume = fixed_costs / (revenue_per_unit - variable_cost_per_unit)

If the contribution margin is zero or negative, break-even volume is set to `Inf`,
indicating the service cannot cover its fixed costs at any volume.
"""
function calculate_break_even(fixed_costs::Float64, variable_cost_per_unit::Float64,
                               revenue_per_unit::Float64;
                               current_volume::Float64=0.0)::BreakEvenResult
    cm = revenue_per_unit - variable_cost_per_unit

    if cm <= 0.0
        return BreakEvenResult(
            break_even_volume = Inf,
            current_volume = current_volume,
            cushion_pct = -1.0,
            contribution_margin_per_unit = cm,
            fixed_costs = fixed_costs,
            variable_cost_per_unit = variable_cost_per_unit,
            revenue_per_unit = revenue_per_unit,
        )
    end

    be_volume = fixed_costs / cm
    cushion = be_volume > 0.0 ? (current_volume - be_volume) / be_volume : 0.0

    return BreakEvenResult(
        break_even_volume = be_volume,
        current_volume = current_volume,
        cushion_pct = cushion,
        contribution_margin_per_unit = cm,
        fixed_costs = fixed_costs,
        variable_cost_per_unit = variable_cost_per_unit,
        revenue_per_unit = revenue_per_unit,
    )
end

"""
    break_even_by_payer(hospital::AbstractHospital) -> Dict{Symbol, BreakEvenResult}

Compute break-even analysis for each payer type in the hospital's payer mix.
Allocates fixed costs proportionally by volume share and uses payer-specific
revenue rates and variable costs.

Requires the hospital to have a populated `payer_mix` and at least one year of
`historical_financials`.
"""
function break_even_by_payer(hospital::AbstractHospital)::Dict{Symbol, BreakEvenResult}
    results = Dict{Symbol, BreakEvenResult}()

    payer_mix = hospital.payer_mix
    isnothing(payer_mix) && error("Hospital payer_mix is not set")

    financials = if !isempty(hospital.historical_financials)
        hospital.historical_financials[end]
    else
        error("Hospital has no historical financials for break-even analysis")
    end

    total_fixed = financials.depreciation + financials.amortization +
                  financials.insurance + financials.lease_rental +
                  financials.utilities + financials.interest_expense
    total_variable = financials.total_operating_expenses - total_fixed
    total_volume = Float64(financials.inpatient_discharges + financials.outpatient_visits + financials.ed_visits)

    total_volume <= 0.0 && return results

    variable_cost_per_unit = total_variable / total_volume

    for contract in payer_mix.contracts
        vol_share = contract.overall_volume_pct
        payer_volume = total_volume * vol_share
        payer_fixed = total_fixed * vol_share

        # Estimate revenue per unit from the contract's adjustment off gross charges
        gross_rev_per_unit = financials.gross_patient_revenue / total_volume
        revenue_per_unit = gross_rev_per_unit * (1.0 - contract.contractual_adjustment_pct)

        result = calculate_break_even(payer_fixed, variable_cost_per_unit, revenue_per_unit;
                                       current_volume=payer_volume)
        results[contract.payer_type] = result
    end

    return results
end

"""
    target_margin_volume(fixed_costs::Float64, var_cost::Float64,
                         revenue::Float64, target_margin::Float64) -> Float64

Calculate the volume required to achieve a target operating margin.
The target margin is expressed as a fraction (e.g., 0.03 for 3%).

    volume = fixed_costs / (revenue * (1 - target_margin) - var_cost)

Returns `Inf` if the target margin is unachievable at any volume.
"""
function target_margin_volume(fixed_costs::Float64, var_cost::Float64,
                               revenue::Float64, target_margin::Float64)::Float64
    effective_cm = revenue * (1.0 - target_margin) - var_cost
    effective_cm <= 0.0 && return Inf
    return fixed_costs / effective_cm
end
