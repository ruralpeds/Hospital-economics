# ── Risk-based contracting and population health finance ───────────────────
#
# PMPM calculations, shared savings/risk, risk corridors, HCC risk scoring,
# and capitated contract modeling for accountable care organizations.

"""
    pmpm(total_cost::Float64, member_months::Int) -> Float64

Per-Member-Per-Month cost calculation.
"""
function pmpm(total_cost::Float64, member_months::Int)::Float64
    member_months > 0 || throw(DomainValidationError("member_months",
        string(member_months), "> 0", "Member months must be positive"))
    return total_cost / member_months
end

"""
    shared_savings(actual_cost::Float64, benchmark_cost::Float64,
                   savings_rate::Float64; min_savings_rate=0.0,
                   quality_gate::Bool=true) -> NamedTuple

Compute shared savings under an ACO/value-based contract.

# Arguments
- `actual_cost`: actual total cost of care
- `benchmark_cost`: target/expected cost
- `savings_rate`: provider's share of savings (e.g., 0.50 = 50%)
- `min_savings_rate`: minimum savings % to trigger sharing (default: 0%)
- `quality_gate`: if false, quality threshold not met → no savings

# Returns
`(gross_savings, savings_pct, provider_share, benchmark, achieved_quality_gate)`
"""
function shared_savings(actual_cost::Float64, benchmark_cost::Float64,
                        savings_rate::Float64;
                        min_savings_rate::Float64=0.0,
                        quality_gate::Bool=true)
    0 <= savings_rate <= 1 || throw(DomainValidationError("savings_rate",
        string(savings_rate), "[0, 1]", "Savings rate must be between 0 and 1"))

    gross_savings = benchmark_cost - actual_cost
    savings_pct = benchmark_cost > 0 ? gross_savings / benchmark_cost : 0.0

    # Check minimum savings threshold and quality gate
    qualifies = savings_pct >= min_savings_rate && quality_gate && gross_savings > 0
    provider_share = qualifies ? gross_savings * savings_rate : 0.0

    return (gross_savings=gross_savings, savings_pct=savings_pct,
            provider_share=provider_share, benchmark=benchmark_cost,
            achieved_quality_gate=quality_gate, qualifies=qualifies)
end

"""
    shared_risk(actual_cost::Float64, benchmark_cost::Float64,
                savings_rate::Float64, risk_rate::Float64;
                risk_cap::Float64=0.10) -> NamedTuple

Two-sided shared savings/shared risk model.
Provider shares in savings AND losses (capped at `risk_cap` of benchmark).
"""
function shared_risk(actual_cost::Float64, benchmark_cost::Float64,
                     savings_rate::Float64, risk_rate::Float64;
                     risk_cap::Float64=0.10)
    diff = benchmark_cost - actual_cost
    if diff >= 0
        # Savings — provider receives share
        provider_amount = diff * savings_rate
        return (scenario=:savings, amount=diff, provider_payment=provider_amount,
                capped=false)
    else
        # Loss — provider pays share (capped)
        max_risk = benchmark_cost * risk_cap
        loss = abs(diff)
        provider_liability = min(loss * risk_rate, max_risk)
        return (scenario=:loss, amount=loss, provider_payment=-provider_liability,
                capped=provider_liability >= max_risk)
    end
end

"""
    risk_corridor(actual_cost::Float64, target_cost::Float64;
                  corridor_pcts::Vector{Float64}=[0.03, 0.08],
                  sharing_rates::Vector{Float64}=[0.50, 0.80, 1.00]) -> NamedTuple

CMS-style risk corridor with graduated sharing bands.

# Default bands
- Within ±3%: 50/50 sharing
- 3-8% deviation: 80/20 sharing
- Beyond 8%: 100% government/plan risk

# Returns
`(deviation_pct, band, plan_share, government_share)`
"""
function risk_corridor(actual_cost::Float64, target_cost::Float64;
                       corridor_pcts::Vector{Float64}=[0.03, 0.08],
                       sharing_rates::Vector{Float64}=[0.50, 0.80, 1.00])
    target_cost > 0 || throw(DomainValidationError("target_cost",
        string(target_cost), "> 0", "Target cost must be positive"))

    deviation = actual_cost - target_cost
    deviation_pct = abs(deviation) / target_cost

    # Determine band
    band = 1
    for (i, pct) in enumerate(corridor_pcts)
        deviation_pct > pct && (band = i + 1)
    end

    plan_rate = band <= length(sharing_rates) ? sharing_rates[band] : 1.0
    plan_share = deviation * plan_rate
    govt_share = deviation * (1.0 - plan_rate)

    return (deviation=deviation, deviation_pct=deviation_pct, band=band,
            plan_share=plan_share, government_share=govt_share)
end

"""
    hcc_risk_score(conditions::Vector{String}, hcc_weights::Dict{String,Float64};
                   demographic_factor::Float64=1.0) -> Float64

Compute CMS-HCC risk score from a list of condition categories.

# Arguments
- `conditions`: vector of HCC category codes (e.g., ["HCC19", "HCC85"])
- `hcc_weights`: Dict mapping HCC code → relative weight
- `demographic_factor`: age/sex demographic adjustment (default: 1.0)

# Returns
Total risk score (1.0 = average Medicare beneficiary).
"""
function hcc_risk_score(conditions::Vector{String},
                        hcc_weights::Dict{String,Float64};
                        demographic_factor::Float64=1.0)::Float64
    condition_score = sum(get(hcc_weights, c, 0.0) for c in conditions)
    return demographic_factor + condition_score
end

"""
    case_mix_index(drg_weights::Vector{Float64}) -> Float64

Compute the Case Mix Index (CMI) from a vector of DRG relative weights.
CMI = mean of all DRG weights for a hospital's discharges.
"""
function case_mix_index(drg_weights::Vector{Float64})::Float64
    isempty(drg_weights) && throw(DataValidationError("Cannot compute CMI from empty DRG weights"))
    return mean(drg_weights)
end

"""
    capitation_rate(pmpm_cost::Float64, admin_load::Float64,
                    risk_margin::Float64, profit_margin::Float64) -> Float64

Build up a capitation rate from components.
`capitation = pmpm_cost × (1 + admin_load) × (1 + risk_margin) × (1 + profit_margin)`
"""
function capitation_rate(pmpm_cost::Float64; admin_load::Float64=0.12,
                         risk_margin::Float64=0.03,
                         profit_margin::Float64=0.02)::Float64
    return pmpm_cost * (1 + admin_load) * (1 + risk_margin) * (1 + profit_margin)
end

"""
    medical_loss_ratio(medical_costs::Float64, premium_revenue::Float64) -> Float64

Compute Medical Loss Ratio (MLR). ACA requires MLR ≥ 80% (individual/small group)
or ≥ 85% (large group).
"""
function medical_loss_ratio(medical_costs::Float64, premium_revenue::Float64)::Float64
    premium_revenue > 0 || throw(DomainValidationError("premium_revenue",
        string(premium_revenue), "> 0", "Premium revenue must be positive"))
    return medical_costs / premium_revenue
end
