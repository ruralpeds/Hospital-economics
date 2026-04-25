# ── Population health economics ────────────────────────────────────────────
#
# Preventive care ROI, telehealth cost-effectiveness, social determinants
# of health (SDOH) impact modeling, and chronic disease management economics.

"""
    preventive_care_roi(intervention_cost::Float64, avoided_cost::Float64,
                        effectiveness::Float64, population::Int;
                        time_horizon::Int=1, discount_rate::Float64=0.03) -> NamedTuple

Compute ROI of a preventive care intervention.

# Arguments
- `intervention_cost`: cost per person for the intervention
- `avoided_cost`: average cost of the condition prevented (per case)
- `effectiveness`: probability the intervention prevents the condition (0-1)
- `population`: number of people receiving the intervention
- `time_horizon`: years over which benefits accrue
- `discount_rate`: annual discount rate for future savings
"""
function preventive_care_roi(intervention_cost::Float64, avoided_cost::Float64,
                             effectiveness::Float64, population::Int;
                             time_horizon::Int=1, discount_rate::Float64=0.03)
    0 <= effectiveness <= 1 || throw(DomainValidationError("effectiveness",
        string(effectiveness), "[0, 1]", "Effectiveness must be a probability"))

    total_investment = intervention_cost * population
    annual_savings = avoided_cost * effectiveness * population

    # PV of savings stream
    pv_savings = sum(annual_savings / (1 + discount_rate)^t for t in 1:time_horizon)
    net_benefit = pv_savings - total_investment
    roi = total_investment > 0 ? net_benefit / total_investment : 0.0
    payback = annual_savings > 0 ? total_investment / annual_savings : Inf

    return (total_investment=total_investment, pv_savings=pv_savings,
            net_benefit=net_benefit, roi=roi, payback_years=payback,
            cost_per_case_avoided=effectiveness > 0 ? intervention_cost / effectiveness : Inf,
            nnt=effectiveness > 0 ? ceil(Int, 1 / effectiveness) : 0)
end

"""
    telehealth_cost_effectiveness(telehealth_cost::Float64, in_person_cost::Float64,
                                  telehealth_outcomes::Float64, in_person_outcomes::Float64;
                                  travel_savings::Float64=0.0,
                                  productivity_savings::Float64=0.0) -> NamedTuple

Compare telehealth vs in-person care cost-effectiveness.

Outcomes are on a quality scale (e.g., QALYs, symptom improvement score).
"""
function telehealth_cost_effectiveness(telehealth_cost::Float64, in_person_cost::Float64,
                                       telehealth_outcomes::Float64, in_person_outcomes::Float64;
                                       travel_savings::Float64=0.0,
                                       productivity_savings::Float64=0.0)
    # Incremental cost-effectiveness ratio
    delta_cost = (telehealth_cost - travel_savings - productivity_savings) - in_person_cost
    delta_outcome = telehealth_outcomes - in_person_outcomes

    icer = delta_outcome != 0 ? delta_cost / delta_outcome : NaN

    # Net monetary benefit at WTP = $50,000/QALY
    wtp = 50_000.0
    nmb = wtp * delta_outcome - delta_cost

    dominant = delta_cost < 0 && delta_outcome > 0
    dominated = delta_cost > 0 && delta_outcome < 0

    interpretation = if dominant
        "Telehealth is dominant (cheaper and better)"
    elseif dominated
        "In-person is dominant (cheaper and better)"
    elseif !isnan(icer) && icer < wtp
        "Telehealth is cost-effective at WTP=\$$(Int(wtp))/QALY"
    elseif !isnan(icer)
        "Telehealth is NOT cost-effective at WTP=\$$(Int(wtp))/QALY"
    else
        "No difference in outcomes"
    end

    return (icer=icer, net_monetary_benefit=nmb, delta_cost=delta_cost,
            delta_outcome=delta_outcome, dominant=dominant, dominated=dominated,
            interpretation=interpretation)
end

"""
    sdoh_impact_model(sdoh_scores::Dict{String,Float64},
                      weights::Dict{String,Float64};
                      baseline_cost::Float64=10000.0) -> NamedTuple

Model the impact of social determinants of health on healthcare costs.

# Arguments
- `sdoh_scores`: Dict of SDOH domain → score (0-100, higher = more disadvantaged)
  Domains: "economic_stability", "education", "healthcare_access",
  "neighborhood", "social_community"
- `weights`: impact weights per domain (sum to 1.0)
- `baseline_cost`: per-capita healthcare cost at average SDOH

# Returns
`(composite_score, cost_multiplier, estimated_cost, high_risk_domains)`
"""
function sdoh_impact_model(sdoh_scores::Dict{String,Float64},
                           weights::Dict{String,Float64};
                           baseline_cost::Float64=10000.0)
    # Compute weighted composite SDOH score
    composite = 0.0
    total_weight = 0.0
    for (domain, score) in sdoh_scores
        w = get(weights, domain, 0.0)
        composite += score * w
        total_weight += w
    end
    total_weight > 0 && (composite /= total_weight)

    # Cost multiplier: each 10-point increase in composite adds ~5% to costs
    # Based on literature: high SDOH burden → 30-50% higher utilization
    cost_multiplier = 1.0 + (composite / 100.0) * 0.50
    estimated_cost = baseline_cost * cost_multiplier

    # Flag high-risk domains (score > 70)
    high_risk = [d for (d, s) in sdoh_scores if s > 70]

    return (composite_score=composite, cost_multiplier=cost_multiplier,
            estimated_cost=estimated_cost, high_risk_domains=high_risk,
            baseline_cost=baseline_cost)
end

"""
    chronic_disease_management_savings(prevalence::Float64, population::Int,
                                       avg_annual_cost::Float64, program_cost_pmpm::Float64,
                                       reduction_pct::Float64; enrollment_pct::Float64=0.60) -> NamedTuple

Estimate savings from a chronic disease management program.

# Arguments
- `prevalence`: disease prevalence in population (0-1)
- `population`: total population
- `avg_annual_cost`: average annual cost per patient with the condition
- `program_cost_pmpm`: monthly cost of the management program per enrolled patient
- `reduction_pct`: expected cost reduction from program (0-1)
- `enrollment_pct`: expected enrollment rate (0-1)
"""
function chronic_disease_management_savings(prevalence::Float64, population::Int,
                                            avg_annual_cost::Float64,
                                            program_cost_pmpm::Float64,
                                            reduction_pct::Float64;
                                            enrollment_pct::Float64=0.60)
    eligible = round(Int, prevalence * population)
    enrolled = round(Int, eligible * enrollment_pct)
    program_cost = enrolled * program_cost_pmpm * 12  # annual
    gross_savings = enrolled * avg_annual_cost * reduction_pct
    net_savings = gross_savings - program_cost
    roi = program_cost > 0 ? net_savings / program_cost : 0.0

    return (eligible_patients=eligible, enrolled_patients=enrolled,
            program_cost=program_cost, gross_savings=gross_savings,
            net_savings=net_savings, roi=roi,
            savings_per_enrolled=enrolled > 0 ? net_savings / enrolled : 0.0)
end
