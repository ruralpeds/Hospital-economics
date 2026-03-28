# ============================================================================
# Disaster / Climate Resilience Assessment — vulnerability scoring,
# financial exposure estimation, and stress testing for natural disasters.
# ============================================================================

const DISASTER_SCENARIO_PARAMS = Dict{Symbol,NamedTuple{(:revenue_loss_pct, :cost_surge_pct, :base_interruption_days), Tuple{Float64,Float64,Float64}}}(
    :flood    => (revenue_loss_pct=0.40, cost_surge_pct=0.25, base_interruption_days=14.0),
    :tornado  => (revenue_loss_pct=0.60, cost_surge_pct=0.35, base_interruption_days=21.0),
    :pandemic => (revenue_loss_pct=0.30, cost_surge_pct=0.50, base_interruption_days=90.0),
    :ice_storm => (revenue_loss_pct=0.35, cost_surge_pct=0.15, base_interruption_days=7.0),
    :hurricane  => (revenue_loss_pct=0.70, cost_surge_pct=0.40, base_interruption_days=30.0),
    :wildfire   => (revenue_loss_pct=0.50, cost_surge_pct=0.30, base_interruption_days=21.0),
    :earthquake => (revenue_loss_pct=0.80, cost_surge_pct=0.45, base_interruption_days=45.0),
)

"""Hospital disaster preparedness and hazard exposure profile."""
@kwdef struct DisasterProfile
    fema_risk_score::Float64            = 0.5    # 0-1, from National Risk Index
    flood_zone::Symbol                  = :minimal  # :minimal, :moderate, :high, :very_high
    wildfire_risk::Symbol               = :low      # :low, :moderate, :high, :very_high
    hurricane_zone::Bool                = false
    earthquake_zone::Bool               = false
    days_generator_fuel::Float64        = 3.0
    has_helipad::Bool                   = false
    surge_bed_capacity::Int             = 0
    supply_chain_redundancy::Float64    = 0.5    # 0-1
    insurance_coverage_pct::Float64     = 0.80   # 0-1
end

"""Comprehensive disaster resilience assessment output."""
@kwdef struct DisasterImpactResult
    infrastructure_vulnerability_score::Float64
    financial_exposure::Float64
    revenue_interruption_days::Float64
    surge_cost_estimate::Float64
    recovery_time_estimate_days::Float64
    insurance_gap::Float64
    resilience_score::Float64
    recommendations::Vector{String}
end

"""Map a categorical risk level to a numeric multiplier."""
function _hazard_multiplier(level::Symbol)::Float64
    level == :very_high && return 1.0
    level == :high && return 0.75
    level == :moderate && return 0.50
    (level == :minimal || level == :low) && return 0.15
    return 0.25
end

"""
    assess_disaster_resilience(profile, annual_revenue, annual_expenses) -> DisasterImpactResult

Score disaster vulnerability, estimate financial exposure, and generate
a resilience score (0-100, higher = more resilient).
"""
function assess_disaster_resilience(profile::DisasterProfile,
                                    annual_revenue::Float64,
                                    annual_expenses::Float64)::DisasterImpactResult
    daily_revenue  = annual_revenue / 365.0
    daily_expenses = annual_expenses / 365.0

    # --- Infrastructure vulnerability (0-1, higher = more vulnerable) ---
    flood_v     = _hazard_multiplier(profile.flood_zone)
    wildfire_v  = _hazard_multiplier(profile.wildfire_risk)
    hurricane_v = profile.hurricane_zone ? 0.7 : 0.1
    earthquake_v = profile.earthquake_zone ? 0.6 : 0.1

    hazard_exposure = 0.30 * flood_v + 0.25 * wildfire_v +
                      0.25 * hurricane_v + 0.20 * earthquake_v

    # Preparedness reduces vulnerability
    generator_factor  = clamp(1.0 - profile.days_generator_fuel / 7.0, 0.0, 1.0)
    supply_factor     = 1.0 - profile.supply_chain_redundancy
    helipad_factor    = profile.has_helipad ? 0.0 : 0.15

    preparedness_gap = 0.40 * generator_factor + 0.35 * supply_factor + 0.25 * helipad_factor

    infra_vuln = clamp(0.55 * hazard_exposure + 0.30 * preparedness_gap + 0.15 * profile.fema_risk_score,
                       0.0, 1.0)

    # --- Revenue interruption estimate ---
    base_interruption = 7.0 + infra_vuln * 45.0   # 7 to 52 days
    interruption_days = round(base_interruption, digits=1)

    # --- Financial exposure ---
    financial_exposure = daily_revenue * interruption_days

    # --- Surge costs ---
    surge_cost = if profile.surge_bed_capacity > 0
        daily_expenses * 0.30 * min(interruption_days, 30.0)
    else
        daily_expenses * 0.15 * min(interruption_days, 30.0)
    end

    # --- Recovery timeline ---
    recovery_days = interruption_days * (1.5 + 0.5 * (1.0 - profile.supply_chain_redundancy))

    # --- Insurance gap ---
    total_loss   = financial_exposure + surge_cost
    covered      = total_loss * profile.insurance_coverage_pct
    insurance_gap = total_loss - covered

    # --- Resilience score (0-100, inverse of vulnerability) ---
    resilience = clamp((1.0 - infra_vuln) * 100.0, 0.0, 100.0)

    # --- Recommendations ---
    recs = String[]
    profile.days_generator_fuel < 5.0 &&
        push!(recs, "Increase generator fuel reserves to at least 5 days (currently $(profile.days_generator_fuel) days)")
    !profile.has_helipad &&
        push!(recs, "Consider helipad installation for emergency medical transport")
    profile.supply_chain_redundancy < 0.6 &&
        push!(recs, "Establish redundant supply chain agreements with secondary vendors")
    profile.insurance_coverage_pct < 0.90 &&
        push!(recs, "Review insurance coverage; current $(round(profile.insurance_coverage_pct * 100, digits=0))% leaves significant gap")
    profile.surge_bed_capacity < 10 &&
        push!(recs, "Develop surge capacity plan targeting at least 10 additional beds")
    profile.flood_zone in (:high, :very_high) &&
        push!(recs, "Implement flood mitigation: barriers, elevated critical systems, waterproofing")
    profile.wildfire_risk in (:high, :very_high) &&
        push!(recs, "Create defensible space and upgrade HVAC filtration for wildfire smoke")
    profile.earthquake_zone &&
        push!(recs, "Conduct seismic assessment and retrofit critical structural elements")
    isempty(recs) &&
        push!(recs, "Current resilience posture is adequate; maintain readiness drills and review annually")

    return DisasterImpactResult(
        infrastructure_vulnerability_score = round(infra_vuln, digits=4),
        financial_exposure                 = round(financial_exposure, digits=2),
        revenue_interruption_days          = interruption_days,
        surge_cost_estimate                = round(surge_cost, digits=2),
        recovery_time_estimate_days        = round(recovery_days, digits=1),
        insurance_gap                      = round(insurance_gap, digits=2),
        resilience_score                   = round(resilience, digits=2),
        recommendations                   = recs,
    )
end

"""
    disaster_stress_test(profile, annual_revenue, cash_reserves; scenarios) -> Vector{NamedTuple}

For each scenario, estimate revenue loss, extra costs, days to recovery,
and whether cash reserves survive. Net impact accounts for insurance.
"""
function disaster_stress_test(profile::DisasterProfile,
                              annual_revenue::Float64,
                              cash_reserves::Float64;
                              scenarios::Vector{Symbol}=[:flood, :tornado, :pandemic, :ice_storm])::Vector{NamedTuple}
    daily_revenue = annual_revenue / 365.0
    results = NamedTuple[]

    for scenario in scenarios
        params = get(DISASTER_SCENARIO_PARAMS, scenario, nothing)
        if params === nothing
            push!(results, (
                scenario              = scenario,
                revenue_loss          = 0.0,
                extra_costs           = 0.0,
                total_financial_impact = 0.0,
                days_to_recovery      = 0.0,
                cash_reserves_survive = true,
                reserve_margin        = cash_reserves,
            ))
            continue
        end

        # Adjust interruption days by profile hazard exposure
        hazard_mod = 0.5 + 0.5 * profile.fema_risk_score  # 0.5x to 1.0x
        interruption = params.base_interruption_days * hazard_mod

        # Supply chain issues extend recovery
        supply_mod = 1.0 + 0.5 * (1.0 - profile.supply_chain_redundancy)
        recovery   = interruption * supply_mod

        revenue_loss = daily_revenue * interruption * params.revenue_loss_pct
        extra_costs  = daily_revenue * interruption * params.cost_surge_pct
        total_impact = revenue_loss + extra_costs

        insured_recovery = total_impact * profile.insurance_coverage_pct
        net_impact       = total_impact - insured_recovery
        margin           = cash_reserves - net_impact

        push!(results, (
            scenario              = scenario,
            revenue_loss          = round(revenue_loss, digits=2),
            extra_costs           = round(extra_costs, digits=2),
            total_financial_impact = round(net_impact, digits=2),
            days_to_recovery      = round(recovery, digits=1),
            cash_reserves_survive = margin >= 0.0,
            reserve_margin        = round(margin, digits=2),
        ))
    end

    return results
end
