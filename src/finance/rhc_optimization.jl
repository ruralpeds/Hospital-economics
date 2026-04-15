# Rural Health Clinic Optimization
#
# Revenue optimization for Medicare-certified Rural Health Clinics (RHCs)
# under the all-inclusive rate (AIR) methodology. Identifies opportunities
# to capture allowable costs up to the payment cap and model revenue from
# adding behavioral health, telehealth, and CCM service lines.

"""
    RHCParams

Parameters for a Rural Health Clinic's operations and service expansion opportunities.
"""
@kwdef struct RHCParams
    annual_visits::Int
    current_cost_per_visit::Float64
    payment_cap_per_visit::Float64 = 165.0
    allowable_cost_categories::Dict{String,Float64} = Dict{String,Float64}()
    behavioral_health_visits::Int = 0
    telehealth_visits::Int = 0
    ccm_eligible_patients::Int = 0
    ccm_monthly_revenue::Float64 = 62.0
end

function Base.show(io::IO, p::RHCParams)
    print(io, "RHCParams(visits=$(p.annual_visits), cost/visit=\$$(round(p.current_cost_per_visit, digits=2)), cap=\$$(round(p.payment_cap_per_visit, digits=2)))")
end

"""
    RHCOptimizationResult

Results of an RHC revenue optimization analysis including current/optimized AIR,
revenue projections, recommendations, and service line additions.
"""
@kwdef struct RHCOptimizationResult
    current_air::Float64
    optimized_air::Float64
    current_revenue::Float64
    optimized_revenue::Float64
    revenue_increase::Float64
    recommendations::Vector{String}
    service_additions::Vector{NamedTuple}
end

function Base.show(io::IO, r::RHCOptimizationResult)
    increase_pct = r.current_revenue > 0.0 ? r.revenue_increase / r.current_revenue * 100 : 0.0
    print(io, "RHCOptimizationResult(AIR \$$(round(r.current_air, digits=2)) -> \$$(round(r.optimized_air, digits=2)), +\$$(round(Int, r.revenue_increase)), +$(round(increase_pct, digits=1))%)")
end

"""
    optimize_rhc_revenue(params::RHCParams) -> RHCOptimizationResult

Analyze an RHC's cost structure and identify revenue optimization opportunities.
AIR = min(cost_per_visit, cap). Models BH, telehealth, and CCM service additions.
"""
function optimize_rhc_revenue(params::RHCParams)::RHCOptimizationResult
    params.annual_visits > 0 || error("annual_visits must be positive; got $(params.annual_visits)")
    params.current_cost_per_visit >= 0.0 || error("current_cost_per_visit must be non-negative; got $(params.current_cost_per_visit)")
    params.payment_cap_per_visit > 0.0 || error("payment_cap_per_visit must be positive; got $(params.payment_cap_per_visit)")
    params.behavioral_health_visits >= 0 || error("behavioral_health_visits must be non-negative; got $(params.behavioral_health_visits)")
    params.telehealth_visits >= 0 || error("telehealth_visits must be non-negative; got $(params.telehealth_visits)")
    params.ccm_eligible_patients >= 0 || error("ccm_eligible_patients must be non-negative; got $(params.ccm_eligible_patients)")
    params.ccm_monthly_revenue >= 0.0 || error("ccm_monthly_revenue must be non-negative; got $(params.ccm_monthly_revenue)")

    # Current AIR is the lesser of cost per visit and payment cap
    current_air = min(params.current_cost_per_visit, params.payment_cap_per_visit)
    current_revenue = current_air * params.annual_visits

    recommendations = String[]
    service_additions = NamedTuple[]

    # --- Cost capture opportunity ---
    cost_gap = params.payment_cap_per_visit - params.current_cost_per_visit
    optimized_cost_per_visit = params.current_cost_per_visit

    if cost_gap > 0.0
        # Opportunity to increase allowable costs up to the cap
        optimized_cost_per_visit = params.payment_cap_per_visit
        annual_gain = cost_gap * params.annual_visits
        push!(recommendations,
            "Cost per visit (\$$(round(params.current_cost_per_visit, digits=2))) is " *
            "\$$(round(cost_gap, digits=2)) below the payment cap. " *
            "Capturing additional allowable costs could add \$$(round(Int, annual_gain))/year.")
        push!(service_additions, (
            service = "Cost Report Optimization",
            additional_visits = 0,
            revenue_per_unit = cost_gap,
            annual_revenue = annual_gain,
        ))
    else
        push!(recommendations,
            "Cost per visit already meets or exceeds the payment cap. " *
            "Focus on volume growth and new service lines.")
    end

    optimized_air = min(optimized_cost_per_visit, params.payment_cap_per_visit)

    # --- Behavioral health ---
    bh_revenue = 0.0
    if params.behavioral_health_visits > 0
        bh_revenue = optimized_air * params.behavioral_health_visits
        push!(recommendations,
            "Adding $(params.behavioral_health_visits) behavioral health visits " *
            "at \$$(round(optimized_air, digits=2))/visit generates \$$(round(Int, bh_revenue))/year.")
        push!(service_additions, (
            service = "Behavioral Health",
            additional_visits = params.behavioral_health_visits,
            revenue_per_unit = optimized_air,
            annual_revenue = bh_revenue,
        ))
    else
        push!(recommendations,
            "Consider adding a behavioral health provider (LCSW/psychologist) " *
            "to bill RHC visits and address unmet community need.")
    end

    # --- Telehealth ---
    telehealth_revenue = 0.0
    if params.telehealth_visits > 0
        telehealth_revenue = optimized_air * params.telehealth_visits
        push!(recommendations,
            "Telehealth expansion with $(params.telehealth_visits) visits " *
            "generates \$$(round(Int, telehealth_revenue))/year at the RHC AIR.")
        push!(service_additions, (
            service = "Telehealth",
            additional_visits = params.telehealth_visits,
            revenue_per_unit = optimized_air,
            annual_revenue = telehealth_revenue,
        ))
    else
        push!(recommendations,
            "Evaluate telehealth for specialty access; RHC-eligible telehealth " *
            "visits are reimbursed at the AIR.")
    end

    # --- Chronic Care Management ---
    ccm_revenue = 0.0
    if params.ccm_eligible_patients > 0
        ccm_revenue = params.ccm_eligible_patients * params.ccm_monthly_revenue * 12.0
        push!(recommendations,
            "CCM for $(params.ccm_eligible_patients) eligible patients at " *
            "\$$(round(params.ccm_monthly_revenue, digits=2))/month yields " *
            "\$$(round(Int, ccm_revenue))/year outside the AIR.")
        push!(service_additions, (
            service = "Chronic Care Management",
            additional_visits = 0,
            revenue_per_unit = params.ccm_monthly_revenue * 12.0,
            annual_revenue = ccm_revenue,
        ))
    else
        push!(recommendations,
            "Implement CCM (CPT 99490) for Medicare patients with 2+ chronic " *
            "conditions to generate revenue outside the per-visit AIR.")
    end

    # --- Totals ---
    optimized_revenue = optimized_air * (params.annual_visits + params.behavioral_health_visits +
                                          params.telehealth_visits) + ccm_revenue
    revenue_increase = optimized_revenue - current_revenue

    return RHCOptimizationResult(
        current_air = current_air,
        optimized_air = optimized_air,
        current_revenue = current_revenue,
        optimized_revenue = optimized_revenue,
        revenue_increase = revenue_increase,
        recommendations = recommendations,
        service_additions = service_additions,
    )
end

"""
    rhc_vs_hopd_comparison(rhc_params::RHCParams, opps_rate::Float64) -> NamedTuple

Compare RHC AIR revenue vs. OPPS equivalent. Returns rhc_revenue, opps_revenue,
revenue_difference, rhc_advantage, and breakeven_opps_rate.
"""
function rhc_vs_hopd_comparison(rhc_params::RHCParams, opps_rate::Float64)
    rhc_params.annual_visits <= 0 && error("annual_visits must be positive")
    opps_rate < 0.0 && error("opps_rate must be non-negative")

    rhc_air = min(rhc_params.current_cost_per_visit, rhc_params.payment_cap_per_visit)
    total_rhc_visits = rhc_params.annual_visits + rhc_params.behavioral_health_visits +
                       rhc_params.telehealth_visits

    rhc_revenue = rhc_air * total_rhc_visits
    opps_revenue = opps_rate * total_rhc_visits
    difference = rhc_revenue - opps_revenue
    breakeven_opps_rate = rhc_air  # OPPS rate that equalizes revenue

    return (
        rhc_revenue = rhc_revenue,
        opps_revenue = opps_revenue,
        revenue_difference = difference,
        rhc_advantage = difference > 0.0,
        breakeven_opps_rate = breakeven_opps_rate,
    )
end
