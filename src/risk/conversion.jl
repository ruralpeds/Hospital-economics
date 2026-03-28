# ============================================================================
# REH Conversion Analysis — Chapter 15
# ============================================================================

using Dates

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

# ConversionParams is defined in types/scenarios.jl — do not redefine here.
# Fields from types/scenarios.jl: conversion_type, conversion_date,
#   one_time_conversion_cost, annual_reh_facility_payment, outpatient_add_on_pct,
#   retained_service_lines, eliminated_service_lines, staff_reduction_pct,
#   severance_weeks_per_year, ramp_up_months, capital_repurposing_cost,
#   inpatient_transfer_distance_miles, community_impact_score

# Default projection constants for fields removed from ConversionParams
const _REH_DEFAULT_PROJECTION_YEARS = 10
const _REH_DEFAULT_DISCOUNT_RATE    = 0.05

"""
    ConversionTransition

Represents a single year in the conversion transition timeline.
"""
struct ConversionTransition
    year::Int
    cah_revenue::Float64
    reh_revenue::Float64
    cah_costs::Float64
    reh_costs::Float64
    cah_margin::Float64
    reh_margin::Float64
    cumulative_npv_difference::Float64
end

"""
    CommunityImpact

Assessment of the community impact of an REH conversion.
"""
struct CommunityImpact
    inpatient_beds_lost::Int
    annual_inpatient_admissions_displaced::Int
    nearest_inpatient_miles::Float64
    ed_capacity_retained::Bool
    outpatient_services_retained::Vector{String}
    services_lost::Vector{String}
    estimated_travel_burden_hours::Float64
    population_over_65_pct::Float64
    ambulance_response_impact::String
end

# REHConversionAnalysis is defined in types/results.jl — uses that @kwdef struct.
# Key fields: hospital_name, analysis_date, conversion_params,
#   pre/post_conversion_margin/revenue/costs, year_1/3/5_net_impact,
#   breakeven_year, conversion_costs, severance_costs, is_recommended, etc.

# ---------------------------------------------------------------------------
# Default assumptions
# ---------------------------------------------------------------------------

"""
    default_cah_assumptions() -> Dict{String,Float64}

Return default financial assumptions for a Critical Access Hospital
status quo projection.
"""
function default_cah_assumptions()
    return Dict{String,Float64}(
        "cost_reimbursement_rate"  => 1.01,
        "annual_cost_growth"      => 0.035,
        "annual_revenue_growth"   => 0.025,
        "occupancy_rate"          => 0.25,
        "outpatient_revenue_pct"  => 0.72,
        "medicare_payer_pct"      => 0.55,
        "medicaid_payer_pct"      => 0.12,
        "commercial_payer_pct"    => 0.18,
        "self_pay_pct"            => 0.10,
        "bad_debt_pct"            => 0.05,
        "charity_care_pct"        => 0.03,
    )
end

"""
    default_reh_assumptions() -> Dict{String,Float64}

Return default financial assumptions for a Rural Emergency Hospital
conversion projection.
"""
function default_reh_assumptions()
    return Dict{String,Float64}(
        "opps_addon_pct"              => 0.05,
        "monthly_facility_payment"    => 272866.30,
        "annual_cost_savings_pct"     => 0.25,   # savings from closing inpatient
        "volume_retention_pct"        => 0.85,
        "transition_cost_estimate"    => 500_000.0,
        "annual_cost_growth"          => 0.030,   # lower cost growth without inpatient
        "annual_revenue_growth"       => 0.020,
        "outpatient_revenue_pct"      => 1.00,
        "medicare_payer_pct"          => 0.60,
        "bad_debt_pct"                => 0.04,
    )
end

# ---------------------------------------------------------------------------
# Projection functions
# ---------------------------------------------------------------------------

"""
    project_cah_financials(base_revenue::Float64, base_costs::Float64,
                           years::Int; assumptions::Dict{String,Float64}=default_cah_assumptions()) -> Vector{Tuple{Float64,Float64}}

Project annual revenue and cost pairs for a CAH over the specified horizon.
"""
function project_cah_financials(base_revenue::Float64, base_costs::Float64,
                                years::Int;
                                assumptions::Dict{String,Float64}=default_cah_assumptions())
    rev_growth = get(assumptions, "annual_revenue_growth", 0.025)
    cost_growth = get(assumptions, "annual_cost_growth", 0.035)

    projections = Tuple{Float64,Float64}[]
    rev = base_revenue
    cost = base_costs

    for yr in 1:years
        rev *= (1.0 + rev_growth)
        cost *= (1.0 + cost_growth)
        push!(projections, (rev, cost))
    end

    return projections
end

"""
    project_reh_financials(base_revenue::Float64, base_costs::Float64,
                           years::Int, params::ConversionParams;
                           assumptions::Dict{String,Float64}=default_reh_assumptions()) -> Vector{Tuple{Float64,Float64}}

Project annual revenue and cost pairs for an REH over the specified horizon.

Revenue includes retained outpatient revenue, OPPS 5% add-on, and the
monthly facility payment. Costs reflect savings from closing the inpatient unit.
"""
function project_reh_financials(base_revenue::Float64, base_costs::Float64,
                                years::Int, params::ConversionParams;
                                assumptions::Dict{String,Float64}=default_reh_assumptions())
    rev_growth = get(assumptions, "annual_revenue_growth", 0.020)
    cost_growth = get(assumptions, "annual_cost_growth", 0.030)
    savings_pct = params.staff_reduction_pct
    volume_retention = 1.0 - savings_pct * 0.5  # approximate volume retention
    facility_payment = params.annual_reh_facility_payment

    projections = Tuple{Float64,Float64}[]

    # Base adjustments for conversion
    reh_base_rev = base_revenue * volume_retention + facility_payment
    reh_base_cost = base_costs * (1.0 - savings_pct)

    rev = reh_base_rev
    cost = reh_base_cost

    for yr in 1:years
        # Year 1 includes transition costs
        extra = yr == 1 ? params.one_time_conversion_cost : 0.0
        rev *= (1.0 + rev_growth)
        cost *= (1.0 + cost_growth)
        push!(projections, (rev, cost + extra))
    end

    return projections
end

# ---------------------------------------------------------------------------
# Discount helper
# ---------------------------------------------------------------------------

"""
    discount(value::Float64, rate::Float64, year::Int) -> Float64

Discount a future value to present value.
"""
function discount(value::Float64, rate::Float64, year::Int)
    return value / (1.0 + rate)^year
end

# ---------------------------------------------------------------------------
# Conversion modeling
# ---------------------------------------------------------------------------

"""
    model_reh_transition(base_revenue::Float64, base_costs::Float64,
                         params::ConversionParams) -> Vector{ConversionTransition}

Model the year-by-year financial comparison between maintaining CAH status
and converting to REH.
"""
function model_reh_transition(base_revenue::Float64, base_costs::Float64,
                              params::ConversionParams; projection_years::Int=10)
    years = projection_years
    cah_proj = project_cah_financials(base_revenue, base_costs, years)
    reh_proj = project_reh_financials(base_revenue, base_costs, years, params)

    timeline = ConversionTransition[]
    cumulative_npv = 0.0

    for yr in 1:years
        cah_rev, cah_cost = cah_proj[yr]
        reh_rev, reh_cost = reh_proj[yr]

        cah_margin = cah_rev - cah_cost
        reh_margin = reh_rev - reh_cost

        diff = discount(reh_margin - cah_margin, _REH_DEFAULT_DISCOUNT_RATE, yr)
        cumulative_npv += diff

        push!(timeline, ConversionTransition(
            yr, cah_rev, reh_rev, cah_cost, reh_cost,
            cah_margin, reh_margin, cumulative_npv
        ))
    end

    return timeline
end

# ---------------------------------------------------------------------------
# Community impact assessment
# ---------------------------------------------------------------------------

"""
    assess_community_impact(hospital::AbstractHospital;
                            beds::Int=25,
                            annual_admissions::Int=300,
                            nearest_inpatient_miles::Float64=30.0,
                            population_over_65_pct::Float64=0.22) -> CommunityImpact

Assess the community impact of converting a CAH to an REH, including
displaced inpatient admissions, travel burden, and services affected.
"""
function assess_community_impact(hospital::AbstractHospital;
                                  beds::Int=25,
                                  annual_admissions::Int=300,
                                  nearest_inpatient_miles::Float64=30.0,
                                  population_over_65_pct::Float64=0.22)
    # Estimate travel burden: round trip at average 45 mph
    avg_travel_time_hours = (nearest_inpatient_miles * 2) / 45.0
    total_travel_burden = avg_travel_time_hours * annual_admissions * 3  # patient + 2 visitors

    retained = ["Emergency Department", "Observation (≤24hr)",
                "Outpatient Surgery", "Diagnostic Imaging",
                "Laboratory", "Physical Therapy",
                "Telehealth Services"]

    lost = ["Inpatient Medical/Surgical", "Skilled Nursing (swing beds)",
            "Labor & Delivery (if applicable)", "Extended Observation (>24hr)"]

    ambulance_impact = if nearest_inpatient_miles > 40
        "Critical — transfer times may exceed golden hour for trauma/STEMI"
    elseif nearest_inpatient_miles > 25
        "Significant — increased transfer times for acute conditions"
    else
        "Moderate — reasonable transfer distance to inpatient facility"
    end

    return CommunityImpact(
        beds,
        annual_admissions,
        nearest_inpatient_miles,
        true,  # ED always retained
        retained,
        lost,
        total_travel_burden,
        population_over_65_pct,
        ambulance_impact,
    )
end

# ---------------------------------------------------------------------------
# Full conversion analysis
# ---------------------------------------------------------------------------

"""
    analyze_reh_conversion(hospital::AbstractRuralHospital,
                           params::ConversionParams;
                           base_revenue::Float64=0.0,
                           base_costs::Float64=0.0,
                           nearest_inpatient_miles::Float64=30.0) -> REHConversionAnalysis

Perform a comprehensive REH conversion analysis for a rural hospital,
as specified in Chapter 15.

Computes NPV comparison, breakeven year, IRR estimate, community impact,
and generates a recommendation.
"""
function analyze_reh_conversion(hospital::AbstractRuralHospital,
                                params::ConversionParams;
                                base_revenue::Float64=0.0,
                                base_costs::Float64=0.0,
                                nearest_inpatient_miles::Float64=30.0)
    # Extract base financials from hospital history if not provided
    rev = base_revenue
    costs = base_costs
    if rev <= 0.0 && !isempty(hospital.historical_financials)
        fy = hospital.historical_financials[end]
        rev = fy.total_operating_revenue
        costs = fy.total_operating_expenses
    end
    rev = max(rev, 1.0)
    costs = max(costs, 1.0)

    timeline = model_reh_transition(rev, costs, params)

    # NPV calculations
    npv_cah = sum(discount(t.cah_margin, _REH_DEFAULT_DISCOUNT_RATE, t.year) for t in timeline)
    npv_reh = sum(discount(t.reh_margin, _REH_DEFAULT_DISCOUNT_RATE, t.year) for t in timeline)
    npv_diff = npv_reh - npv_cah

    # Breakeven year
    breakeven = nothing
    for t in timeline
        if t.cumulative_npv_difference > 0
            breakeven = t.year
            break
        end
    end

    # Simplified IRR estimate using bisection
    irr_est = _estimate_irr(timeline, params)

    # Community impact
    beds = hasproperty(hospital, :licensed_beds) ? hospital.licensed_beds : 25
    community = assess_community_impact(hospital;
        beds=beds,
        nearest_inpatient_miles=nearest_inpatient_miles)

    # Recommendation
    recommendation = if npv_diff > 0 && breakeven !== nothing && breakeven <= 3
        "Strongly consider REH conversion — positive NPV with breakeven in $breakeven years"
    elseif npv_diff > 0
        "REH conversion financially favorable but breakeven is $(something(breakeven, ">$(_REH_DEFAULT_PROJECTION_YEARS)")) years — weigh against community impact"
    elseif npv_diff > -500_000
        "Marginal case — REH conversion roughly neutral; decision should emphasize community need"
    else
        "Maintain CAH status — REH conversion shows negative NPV of $(round(npv_diff; digits=0))"
    end

    # Compute summary values for the types/results.jl REHConversionAnalysis
    is_recommended = npv_diff > 0
    cah_yr1 = !isempty(timeline) ? timeline[1].cah_margin : 0.0
    reh_yr1 = !isempty(timeline) ? timeline[1].reh_margin : 0.0
    cah_rev1 = !isempty(timeline) ? timeline[1].cah_revenue : rev
    reh_rev1 = !isempty(timeline) ? timeline[1].reh_revenue : rev
    cah_cost1 = !isempty(timeline) ? timeline[1].cah_costs : costs
    reh_cost1 = !isempty(timeline) ? timeline[1].reh_costs : costs

    return REHConversionAnalysis(
        hospital_name = hospital.name,
        analysis_date = params.conversion_date,
        conversion_params = params,
        pre_conversion_margin = cah_yr1 / max(cah_rev1, 1.0),
        pre_conversion_net_revenue = cah_rev1,
        pre_conversion_total_costs = cah_cost1,
        post_conversion_margin = reh_yr1 / max(reh_rev1, 1.0),
        post_conversion_net_revenue = reh_rev1,
        post_conversion_total_costs = reh_cost1,
        annual_facility_payment = params.annual_reh_facility_payment,
        year_1_net_impact = reh_yr1 - cah_yr1,
        year_3_cumulative_impact = length(timeline) >= 3 ? timeline[3].cumulative_npv_difference : npv_diff,
        year_5_cumulative_impact = length(timeline) >= 5 ? timeline[5].cumulative_npv_difference : npv_diff,
        breakeven_year = breakeven,
        conversion_costs = params.one_time_conversion_cost,
        capital_repurposing_costs = params.capital_repurposing_cost,
        inpatient_transfers_annual = 0,
        avg_transfer_distance_miles = params.inpatient_transfer_distance_miles,
        services_eliminated = String[string(s) for s in params.eliminated_service_lines],
        services_retained = String[string(s) for s in params.retained_service_lines],
        is_recommended = is_recommended,
        recommendation_rationale = recommendation,
    )
end

"""Estimate internal rate of return via bisection on the NPV-difference stream."""
function _estimate_irr(timeline::Vector{ConversionTransition},
                       params::ConversionParams;
                       tol::Float64=0.001, max_iter::Int=100)
    cashflows = [t.reh_margin - t.cah_margin for t in timeline]
    # Include initial transition cost as negative year-0 flow
    pushfirst!(cashflows, -params.one_time_conversion_cost)

    lo, hi = -0.50, 2.0
    for _ in 1:max_iter
        mid = (lo + hi) / 2.0
        npv = sum(cf / (1.0 + mid)^(i-1) for (i, cf) in enumerate(cashflows))
        if abs(npv) < tol
            return mid
        elseif npv > 0
            lo = mid
        else
            hi = mid
        end
    end
    return (lo + hi) / 2.0
end
