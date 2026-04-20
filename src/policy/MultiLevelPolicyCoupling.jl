"""
    MultiLevelPolicyCoupling

Module for simulating coupled federal, state, and hospital-level healthcare policies.

# Features
- Federal Medicare payment reforms and quality incentives
- State Medicaid expansions and payment regulation
- Hospital-level strategy responses (conservative, aggressive, accommodative)
- Multi-year cascade effects across policy levels
- Financial impact and equity analysis
"""

module MultiLevelPolicyCoupling

export FederalPolicy, StatePolicy, HospitalStrategy
export MedicarePaymentReform, ProposedMLLRate
export MedicaidExpansion, HospitalRateSetting, RuralHospitalSupport, PayerMixShift
export ConservativeStrategy, AggressiveExpansionStrategy, AccommodativeStrategy
export MultiLevelPolicyScenario, PolicyCouplingOutcomes
export simulate_policy_coupling!, analyze_policy_interactions
export calculate_federal_impact, calculate_state_impact

using Statistics

# ====================================
# Abstract Types
# ====================================

abstract type FederalPolicy end
abstract type StatePolicy end
abstract type HospitalStrategy end

# ====================================
# Federal Policies
# ====================================

mutable struct MedicarePaymentReform <: FederalPolicy
    drg_weight_changes::Dict{String, Float64}
    quality_incentive_pool::Float64
    bundled_payment_rate::Float64
    implementation_year::Int
end

mutable struct ProposedMLLRate <: FederalPolicy
    affects_services::Set{String}
    national_rate::Float64
    implementation_year::Int
end

# ====================================
# State Policies
# ====================================

mutable struct MedicaidExpansion <: StatePolicy
    coverage_increase::Float64
    payment_rate_multiplier::Float64
    eligibility_age::Int
    implementation_year::Int
end

mutable struct HospitalRateSetting <: StatePolicy
    target_margin::Float64
    affected_payers::Set{String}
    adjustment_period::Int
    implementation_year::Int
end

mutable struct RuralHospitalSupport <: StatePolicy
    supplemental_payment_per_bed::Float64
    criteria::String
    funding_source::String
    implementation_year::Int
end

mutable struct PayerMixShift <: StatePolicy
    from_payer::String
    to_payer::String
    volume_shift::Float64
    implementation_year::Int
end

# ====================================
# Hospital Strategies
# ====================================

mutable struct ConservativeStrategy <: HospitalStrategy
    cost_reduction_target::Float64
    service_retention::Float64
    investment_multiplier::Float64
end

mutable struct AggressiveExpansionStrategy <: HospitalStrategy
    service_expansion_rate::Float64
    capacity_investment_rate::Float64
    price_competition_intensity::Float64
end

mutable struct AccommodativeStrategy <: HospitalStrategy
    quality_investment_rate::Float64
    payer_mix_flexibility::Float64
    service_mix_adjustment_rate::Float64
end

# ====================================
# Scenario & Outcomes
# ====================================

mutable struct MultiLevelPolicyScenario
    federal_policies::Vector{FederalPolicy}
    state_policies::Vector{StatePolicy}
    hospital_strategies::Dict{String, HospitalStrategy}
    hospital_demand_elasticity::Float64
    insurance_demand_elasticity::Float64
    provider_exit_threshold::Float64
    scenario_name::String
end

mutable struct PolicyCouplingOutcomes
    scenario_name::String
    years::Int
    hospital_margins::Dict{String, Vector{Float64}}
    hospital_volumes::Dict{String, Vector{Float64}}
    payer_mix::Dict{String, Vector{Float64}}
    quality_metrics::Dict{String, Vector{Float64}}
    hospital_closures::Vector{String}
    total_cost::Vector{Float64}
    financial_impact::Dict{String, Float64}
    equity_analysis::Dict{String, Float64}
end

# ====================================
# Constructors
# ====================================

function MedicarePaymentReform(; drg_weight_changes=Dict(), quality_incentive_pool=0.0,
                               bundled_payment_rate=0.0, implementation_year=1)
    MedicarePaymentReform(drg_weight_changes, quality_incentive_pool, bundled_payment_rate, implementation_year)
end

function ProposedMLLRate(; affects_services=Set{String}(), national_rate=1.0, implementation_year=1)
    ProposedMLLRate(affects_services, national_rate, implementation_year)
end

function MedicaidExpansion(; coverage_increase=0.0, payment_rate_multiplier=1.0,
                            eligibility_age=65, implementation_year=1)
    MedicaidExpansion(coverage_increase, payment_rate_multiplier, eligibility_age, implementation_year)
end

function HospitalRateSetting(; target_margin=0.0, affected_payers=Set{String}(),
                              adjustment_period=1, implementation_year=1)
    HospitalRateSetting(target_margin, affected_payers, adjustment_period, implementation_year)
end

function RuralHospitalSupport(; supplemental_payment_per_bed=0.0, criteria="",
                               funding_source="state", implementation_year=1)
    RuralHospitalSupport(supplemental_payment_per_bed, criteria, funding_source, implementation_year)
end

function PayerMixShift(; from_payer="", to_payer="", volume_shift=0.0, implementation_year=1)
    PayerMixShift(from_payer, to_payer, volume_shift, implementation_year)
end

function ConservativeStrategy(; cost_reduction_target=0.05, service_retention=0.95, investment_multiplier=0.5)
    ConservativeStrategy(cost_reduction_target, service_retention, investment_multiplier)
end

function AggressiveExpansionStrategy(; service_expansion_rate=0.15, capacity_investment_rate=0.20,
                                     price_competition_intensity=0.8)
    AggressiveExpansionStrategy(service_expansion_rate, capacity_investment_rate, price_competition_intensity)
end

function AccommodativeStrategy(; quality_investment_rate=0.10, payer_mix_flexibility=0.75,
                                service_mix_adjustment_rate=0.10)
    AccommodativeStrategy(quality_investment_rate, payer_mix_flexibility, service_mix_adjustment_rate)
end

function MultiLevelPolicyScenario(; federal_policies=FederalPolicy[], state_policies=StatePolicy[],
                                   hospital_strategies=Dict{String, HospitalStrategy}(),
                                   hospital_demand_elasticity=-0.5, insurance_demand_elasticity=-0.3,
                                   provider_exit_threshold=0.01, scenario_name="Scenario")
    MultiLevelPolicyScenario(federal_policies, state_policies, hospital_strategies,
                             hospital_demand_elasticity, insurance_demand_elasticity,
                             provider_exit_threshold, scenario_name)
end

# ====================================
# Core Simulation
# ====================================

function simulate_policy_coupling!(scenario::MultiLevelPolicyScenario,
                                   baseline_hospitals::Dict,
                                   baseline_state_data,
                                   years::Int)::PolicyCouplingOutcomes

    # Initialize tracking
    hospital_margins = Dict{String, Vector{Float64}}()
    hospital_volumes = Dict{String, Vector{Float64}}()
    payer_mix = Dict{String, Vector{Float64}}()
    quality_metrics = Dict{String, Vector{Float64}}()
    hospital_closures = String[]
    total_costs = Float64[]
    state_enrollment = [baseline_state_data.enrollment]

    # Initialize baselines
    for (hospital_id, baseline) in baseline_hospitals
        hospital_margins[hospital_id] = [baseline.margin]
        hospital_volumes[hospital_id] = [baseline.volume]
        payer_mix[hospital_id] = [baseline.payer_mix_medicare]
        quality_metrics[hospital_id] = [baseline.quality_score]
    end

    # Year-by-year simulation
    for year = 2:years+1
        year_index = year - 1
        federal_adjustment = calculate_federal_impact(scenario.federal_policies, year_index)
        state_shift = calculate_state_impact(scenario.state_policies, year_index)

        push!(state_enrollment, state_enrollment[end] * (1.0 + state_shift))

        year_cost = 0.0

        for (hospital_id, baseline) in baseline_hospitals
            hospital_id in hospital_closures && continue

            prev_margin = hospital_margins[hospital_id][end]
            prev_volume = hospital_volumes[hospital_id][end]
            prev_quality = quality_metrics[hospital_id][end]

            strategy = get(scenario.hospital_strategies, hospital_id, ConservativeStrategy())

            # Volume change
            volume_shift = prev_volume * state_shift * scenario.insurance_demand_elasticity
            new_volume = prev_volume + volume_shift

            # Margin change
            cost_per_case = 100.0
            new_margin = prev_margin
            new_margin -= (cost_per_case * federal_adjustment / prev_volume)

            if state_shift > 0
                new_margin *= (1.0 - state_shift * 0.10)
            end

            # Strategy response
            if strategy isa ConservativeStrategy
                new_margin += strategy.cost_reduction_target
            elseif strategy isa AggressiveExpansionStrategy
                new_margin -= strategy.capacity_investment_rate
                new_volume *= (1.0 + strategy.service_expansion_rate)
            else
                new_margin += strategy.quality_investment_rate * 0.02
                new_volume *= (1.0 + strategy.payer_mix_flexibility * state_shift)
            end

            # Quality
            new_quality = prev_quality
            if strategy isa AggressiveExpansionStrategy
                new_quality -= 0.01
            elseif strategy isa AccommodativeStrategy
                new_quality += 0.01
            end

            # Check closure
            if new_margin < scenario.provider_exit_threshold
                push!(hospital_closures, hospital_id)
                continue
            end

            push!(hospital_margins[hospital_id], new_margin)
            push!(hospital_volumes[hospital_id], new_volume)
            push!(quality_metrics[hospital_id], new_quality)

            old_mix = payer_mix[hospital_id][end]
            new_mix = old_mix - (state_shift * 0.5)
            push!(payer_mix[hospital_id], max(0.0, min(1.0, new_mix)))

            year_cost += new_volume * cost_per_case
        end

        push!(total_costs, year_cost)
    end

    # Calculate financial impact
    baseline_margin = 0.0
    final_margin = 0.0
    for id in keys(baseline_hospitals)
        if id ∉ hospital_closures
            baseline_margin += baseline_hospitals[id].margin * baseline_hospitals[id].volume
            final_margin += hospital_margins[id][end] * hospital_volumes[id][end]
        end
    end

    enrollment_change = length(state_enrollment) > 1 ?
        (state_enrollment[end] - state_enrollment[1]) / state_enrollment[1] : 0.0

    financial_impact = Dict{String, Float64}()
    financial_impact["baseline_total_margin"] = baseline_margin
    financial_impact["final_total_margin"] = final_margin
    financial_impact["hospital_closures"] = Float64(length(hospital_closures))
    financial_impact["enrollment_change"] = enrollment_change

    # Calculate equity analysis
    access_disparity = length(hospital_closures) * 0.1
    cost_increase = length(total_costs) > 1 ?
        (total_costs[end] - total_costs[1]) / total_costs[1] : 0.0

    equity_analysis = Dict{String, Float64}()
    equity_analysis["access_disparity"] = access_disparity
    equity_analysis["cost_increase"] = cost_increase

    return PolicyCouplingOutcomes(
        scenario.scenario_name, years,
        hospital_margins, hospital_volumes, payer_mix, quality_metrics,
        hospital_closures, total_costs,
        financial_impact, equity_analysis
    )
end

# ====================================
# Helper Functions
# ====================================

function calculate_federal_impact(policies::Vector{FederalPolicy}, year::Int)::Float64
    total = 0.0
    for policy in policies
        if policy isa MedicarePaymentReform && year >= policy.implementation_year
            avg_change = isempty(policy.drg_weight_changes) ? 0.0 : mean(values(policy.drg_weight_changes))
            total += (avg_change - 1.0) - policy.quality_incentive_pool - policy.bundled_payment_rate * 0.05
        elseif policy isa ProposedMLLRate && year >= policy.implementation_year
            total += (policy.national_rate - 1.0) * 0.3
        end
    end
    return total
end

function calculate_state_impact(policies::Vector{StatePolicy}, year::Int)::Float64
    total = 0.0
    for policy in policies
        if policy isa MedicaidExpansion && year >= policy.implementation_year
            years_active = year - policy.implementation_year + 1
            phase_in = min(1.0, years_active / 3.0)
            total += policy.coverage_increase * phase_in
        elseif policy isa PayerMixShift && year >= policy.implementation_year
            total += policy.volume_shift
        end
    end
    return total
end

function analyze_policy_interactions(scenario::MultiLevelPolicyScenario,
                                     outcomes::PolicyCouplingOutcomes)::Dict{String, Any}
    interactions = Dict{String, Any}()

    has_medicaid = any(p isa MedicaidExpansion for p in scenario.state_policies)
    has_medicare_cut = any(p isa MedicarePaymentReform for p in scenario.federal_policies)

    if has_medicaid && has_medicare_cut
        interactions["medicaid_expansion_medicare_cut_stress"] = true
        interactions["stress_level"] = "high"
    end

    rural_hospitals = [h for h in keys(scenario.hospital_strategies) if occursin("rural", lowercase(h))]
    rural_closures = length([h for h in outcomes.hospital_closures if h in rural_hospitals])
    interactions["rural_hospital_closures"] = rural_closures

    if !isempty(outcomes.hospital_margins)
        active_hospitals = [h for h in keys(outcomes.hospital_margins) if h ∉ outcomes.hospital_closures]
        if !isempty(active_hospitals)
            avg_margin = mean([outcomes.hospital_margins[h][end] for h in active_hospitals])
            interactions["average_final_margin"] = avg_margin
            interactions["financial_stress"] = avg_margin < 0.01 ? "high" : "moderate"
        end
    end

    return interactions
end

end  # module
