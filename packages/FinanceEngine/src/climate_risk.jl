"""
    climate_risk.jl — Climate Risk & TCFD Disclosure (MBA Gap D-07)

Provides a TCFD (Task Force on Climate-related Financial Disclosures) framework
adapted for rural hospital boards, covering physical and transition risk
quantification and scenario analysis.

## TCFD four pillars
1. Governance — board oversight of climate risk
2. Strategy — climate risks and opportunities over short/medium/long term
3. Risk Management — identification and management processes
4. Metrics & Targets — KPIs for climate performance

## Physical risks modelled
- Flood risk (floodplain proximity, 100-yr storm frequency increase)
- Wildfire risk (WUI location, smoke-days trend)
- Extreme heat (utility demand, staff absenteeism, patient volume shifts)
- Severe weather (hurricane/tornado track probability)

## Transition risks modelled
- Carbon pricing (Scope 1+2 emissions × shadow carbon price)
- Grid reliability (renewable transition → outage frequency)
- Supply chain disruption (pharmaceutical/supply logistics)
- Insurance premium increases (property + liability)

## Scenarios (aligned to IPCC AR6)
- Net Zero / 1.5°C pathway
- Below 2°C / Delayed action
- Current Policies / ~3°C pathway

References:
- TCFD (2021). Guidance on Climate-Related Financial Disclosures. FSBD.
- IPCC AR6 (2021). Climate Change 2021: The Physical Science Basis.
- AHA (2022). Hospitals and Climate Change: Reducing Environmental Impact.
"""

using Statistics; using Printf; using Dates

# ─── Physical risk assessment ────────────────────────────────────────────────

@kwdef struct PhysicalRiskInputs
    hospital_name::String
    state::String
    county::String
    # Location hazards (0–10 scale; 0=no risk, 10=extreme risk)
    flood_hazard_score::Float64        = 3.0   # FEMA floodplain / storm surge
    wildfire_hazard_score::Float64     = 2.0   # WUI adjacency
    extreme_heat_score::Float64        = 4.0   # NOAA heat index trend
    severe_weather_score::Float64      = 3.0   # tornado/hurricane probability
    # Financial exposure
    replacement_value_usd::Float64             # facility replacement value
    annual_revenue::Float64
    generator_backup_hours::Int        = 72    # backup power hours
    backup_water_days::Int             = 3
end

struct PhysicalRiskResult
    hospital_name::String
    composite_physical_risk_score::Float64   # 0-10
    risk_tier::Symbol                         # :low, :moderate, :high, :critical
    expected_annual_loss_usd::Float64        # probabilistic loss estimate
    max_probable_loss_usd::Float64           # 1-in-100-year loss
    resilience_gap_days::Int                 # days of operation at risk
    priority_investments::Vector{String}
end

function assess_physical_risk(inputs::PhysicalRiskInputs)::PhysicalRiskResult
    # Weighted composite risk score
    composite = (inputs.flood_hazard_score * 0.30 +
                 inputs.wildfire_hazard_score * 0.20 +
                 inputs.extreme_heat_score * 0.25 +
                 inputs.severe_weather_score * 0.25)

    tier = composite < 3 ? :low : composite < 5 ? :moderate :
           composite < 7 ? :high : :critical

    # Probabilistic loss: composite/10 × 2% annual probability × replacement value
    annual_loss = inputs.replacement_value_usd * (composite / 10.0) * 0.02
    max_loss    = inputs.replacement_value_usd * (composite / 10.0) * 0.35

    # Resilience gap: how many days could the hospital be non-operational?
    resilience_days = round(Int, composite * 3.5)   # heuristic

    # Investment priorities
    priorities = String[]
    inputs.flood_hazard_score > 5 && push!(priorities,
        "Flood mitigation: perimeter berms, critical equipment elevation above 500-yr flood elevation")
    inputs.generator_backup_hours < 96 && push!(priorities,
        "Extended backup power: upgrade to 96+ hour generator capacity with automatic transfer switch")
    inputs.backup_water_days < 7 && push!(priorities,
        "Water storage: expand to 7-day onsite water supply per Joint Commission EC.02.05.07")
    inputs.extreme_heat_score > 5 && push!(priorities,
        "Cooling system redundancy: N+1 HVAC for critical care areas")
    inputs.wildfire_hazard_score > 4 && push!(priorities,
        "Smoke/air quality: upgrade HVAC filtration to MERV-13 or HEPA for ED and ICU")
    isempty(priorities) && push!(priorities, "Current resilience investment appears adequate for risk level")

    PhysicalRiskResult(inputs.hospital_name, composite, tier,
        annual_loss, max_loss, resilience_days, priorities)
end

# ─── Transition risk assessment ──────────────────────────────────────────────

@kwdef struct TransitionRiskInputs
    hospital_name::String
    scope1_emissions_mtco2e::Float64    # natural gas, fleet, backup generators
    scope2_emissions_mtco2e::Float64    # purchased electricity
    annual_energy_spend::Float64
    annual_supply_chain_spend::Float64  # pharmaceuticals, supplies
    property_insurance_annual::Float64
    shadow_carbon_price_2030::Float64 = 65.0   # USD/tCO2e (IEA 2030 estimate)
    shadow_carbon_price_2050::Float64 = 140.0
    grid_reliability_risk_pct::Float64 = 0.05  # probability of extended outage/yr
    supply_chain_disruption_cost::Float64 = 0.03  # % of supply spend at risk/yr
end

struct TransitionRiskResult
    hospital_name::String
    total_emissions_mtco2e::Float64
    carbon_cost_2030::Float64        # shadow carbon cost in 2030
    carbon_cost_2050::Float64
    energy_transition_investment::Float64  # estimated investment for net-zero path
    insurance_premium_increase_10yr::Float64  # expected increase over 10 years
    supply_chain_disruption_annual::Float64
    total_transition_risk_annual::Float64
    decarbonisation_opportunities::Vector{String}
end

function assess_transition_risk(inputs::TransitionRiskInputs)::TransitionRiskResult
    total_emissions = inputs.scope1_emissions_mtco2e + inputs.scope2_emissions_mtco2e
    carbon_2030 = total_emissions * inputs.shadow_carbon_price_2030
    carbon_2050 = total_emissions * inputs.shadow_carbon_price_2050

    # Energy efficiency investment to reach net-zero: ~8× annual energy spend
    energy_investment = inputs.annual_energy_spend * 3.0

    # Insurance: property/liability premiums expected to rise 40-60% over 10 years
    insurance_increase = inputs.property_insurance_annual * 0.45

    # Supply chain disruption
    supply_disruption = inputs.annual_supply_chain_spend * inputs.supply_chain_disruption_cost

    total_annual_risk = (carbon_2030 / 7) + insurance_increase / 10 + supply_disruption

    opps = [
        "LED + controls retrofit: 15-25% energy reduction, 3-5 year payback",
        "Solar PV + battery storage: reduce Scope 2 emissions 40-60%, hedge against grid risk",
        "Heat pump HVAC replacement: eliminate Scope 1 natural gas, improve efficiency",
        "ENERGY STAR certification: operational benchmark, reporting credential",
        "Sustainable procurement policy: prefer suppliers with Scope 3 commitments",
    ]

    TransitionRiskResult(inputs.hospital_name, total_emissions,
        carbon_2030, carbon_2050, energy_investment,
        insurance_increase, supply_disruption, total_annual_risk, opps)
end

# ─── TCFD scenario analysis ──────────────────────────────────────────────────

@kwdef struct ClimateScenario
    name::String
    label::Symbol      # :net_zero, :below_2c, :current_policies
    warming_by_2100_c::Float64
    carbon_price_2030::Float64
    physical_risk_multiplier::Float64   # how much worse physical risks become
    transition_risk_multiplier::Float64
    probability::Float64 = 1.0/3
end

const IPCC_SCENARIOS = (
    net_zero = ClimateScenario(
        name="Net Zero / 1.5°C", label=:net_zero,
        warming_by_2100_c=1.5, carbon_price_2030=130.0,
        physical_risk_multiplier=1.20, transition_risk_multiplier=1.80,
        probability=0.25),
    below_2c = ClimateScenario(
        name="Below 2°C / Delayed Action", label=:below_2c,
        warming_by_2100_c=1.8, carbon_price_2030=65.0,
        physical_risk_multiplier=1.40, transition_risk_multiplier=1.35,
        probability=0.40),
    current_policies = ClimateScenario(
        name="Current Policies / ~3°C", label=:current_policies,
        warming_by_2100_c=3.0, carbon_price_2030=15.0,
        physical_risk_multiplier=2.20, transition_risk_multiplier=0.80,
        probability=0.35),
)

"""
    tcfd_scenario_analysis(physical::PhysicalRiskResult,
                            transition::TransitionRiskResult) -> NamedTuple

Run TCFD-style scenario analysis across the three IPCC pathways.
"""
function tcfd_scenario_analysis(
    physical::PhysicalRiskResult,
    transition::TransitionRiskResult,
)
    results = map(collect(values(IPCC_SCENARIOS))) do scen
        phys_risk  = physical.expected_annual_loss_usd * scen.physical_risk_multiplier
        trans_risk = transition.total_transition_risk_annual * scen.transition_risk_multiplier
        total_risk = phys_risk + trans_risk
        (
            scenario         = scen.name,
            label            = scen.label,
            warming_c        = scen.warming_by_2100_c,
            physical_risk    = phys_risk,
            transition_risk  = trans_risk,
            total_annual_risk = total_risk,
            probability      = scen.probability,
        )
    end

    ev_risk = sum(r.total_annual_risk * r.probability for r in results)
    worst   = results[argmax(r.total_annual_risk for r in results)]

    (
        scenarios              = results,
        expected_value_risk    = ev_risk,
        worst_case_scenario    = worst.scenario,
        worst_case_risk        = worst.total_annual_risk,
        hospital_name          = physical.hospital_name,
        report_date            = string(today()),
    )
end
