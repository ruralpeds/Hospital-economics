# ============================================================================
# REH Conversion Analysis — Chapter 15
# ============================================================================

using Dates

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    ConversionParams

Parameters governing a CAH-to-REH conversion analysis.
"""
struct ConversionParams
    conversion_date::Date
    projection_years::Int
    discount_rate::Float64
    inflation_rate::Float64
    medicare_update_factor::Float64
    reh_monthly_facility_payment::Float64
    transition_costs::Float64          # one-time conversion costs
    annual_cost_savings::Float64       # from closing inpatient unit
    volume_retention_pct::Float64      # outpatient volume retained post-conversion
end

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

"""
    REHConversionAnalysis

Complete results of a CAH-to-REH conversion financial analysis.
"""
struct REHConversionAnalysis
    hospital_name::String
    conversion_date::Date
    transition_timeline::Vector{ConversionTransition}
    npv_cah::Float64
    npv_reh::Float64
    npv_difference::Float64
    breakeven_year::Union{Int,Nothing}
    irr_estimate::Float64
    recommendation::String
    community_impact::CommunityImpact
end

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
    savings_pct = get(assumptions, "annual_cost_savings_pct", 0.25)
    volume_retention = params.volume_retention_pct
    facility_payment = params.reh_monthly_facility_payment * 12

    projections = Tuple{Float64,Float64}[]

    # Base adjustments for conversion
    reh_base_rev = base_revenue * volume_retention + facility_payment
    reh_base_cost = base_costs * (1.0 - savings_pct)

    rev = reh_base_rev
    cost = reh_base_cost

    for yr in 1:years
        # Year 1 includes transition costs
        extra = yr == 1 ? params.transition_costs : 0.0
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
                              params::ConversionParams)
    years = params.projection_years
    cah_proj = project_cah_financials(base_revenue, base_costs, years)
    reh_proj = project_reh_financials(base_revenue, base_costs, years, params)

    timeline = ConversionTransition[]
    cumulative_npv = 0.0

    for yr in 1:years
        cah_rev, cah_cost = cah_proj[yr]
        reh_rev, reh_cost = reh_proj[yr]

        cah_margin = cah_rev - cah_cost
        reh_margin = reh_rev - reh_cost

        diff = discount(reh_margin - cah_margin, params.discount_rate, yr)
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
    analyze_reh_conversion(hospital::CriticalAccessHospital,
                           params::ConversionParams;
                           base_revenue::Float64=0.0,
                           base_costs::Float64=0.0,
                           nearest_inpatient_miles::Float64=30.0) -> REHConversionAnalysis

Perform a comprehensive REH conversion analysis for a Critical Access Hospital,
as specified in Chapter 15.

Computes NPV comparison, breakeven year, IRR estimate, community impact,
and generates a recommendation.
"""
function analyze_reh_conversion(hospital::CriticalAccessHospital,
                                params::ConversionParams;
                                base_revenue::Float64=0.0,
                                base_costs::Float64=0.0,
                                nearest_inpatient_miles::Float64=30.0)
    # Use hospital data if base values not provided
    rev = base_revenue > 0 ? base_revenue : hospital.total_charges * hospital.cost_to_charge_ratio
    costs = base_costs > 0 ? base_costs : hospital.total_costs

    timeline = model_reh_transition(rev, costs, params)

    # NPV calculations
    npv_cah = sum(discount(t.cah_margin, params.discount_rate, t.year) for t in timeline)
    npv_reh = sum(discount(t.reh_margin, params.discount_rate, t.year) for t in timeline)
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
    beds = hasproperty(hospital, :beds) ? hospital.beds : 25
    community = assess_community_impact(hospital;
        beds=beds,
        nearest_inpatient_miles=nearest_inpatient_miles)

    # Recommendation
    recommendation = if npv_diff > 0 && breakeven !== nothing && breakeven <= 3
        "Strongly consider REH conversion — positive NPV with breakeven in $breakeven years"
    elseif npv_diff > 0
        "REH conversion financially favorable but breakeven is $(something(breakeven, ">$(params.projection_years)")) years — weigh against community impact"
    elseif npv_diff > -500_000
        "Marginal case — REH conversion roughly neutral; decision should emphasize community need"
    else
        "Maintain CAH status — REH conversion shows negative NPV of $(round(npv_diff; digits=0))"
    end

    return REHConversionAnalysis(
        hospital.name,
        params.conversion_date,
        timeline,
        npv_cah,
        npv_reh,
        npv_diff,
        breakeven,
        irr_est,
        recommendation,
        community,
    )
end

"""Estimate internal rate of return via bisection on the NPV-difference stream."""
function _estimate_irr(timeline::Vector{ConversionTransition},
                       params::ConversionParams;
                       tol::Float64=0.001, max_iter::Int=100)
    cashflows = [t.reh_margin - t.cah_margin for t in timeline]
    # Include initial transition cost as negative year-0 flow
    pushfirst!(cashflows, -params.transition_costs)

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
