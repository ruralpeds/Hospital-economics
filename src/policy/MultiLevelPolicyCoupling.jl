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
export ACARepealPolicy, MedicareAdvantageTransformation, VerticalIntegrationPolicy
export PriceRegulationPolicy
export MedicaidExpansion, HospitalRateSetting, RuralHospitalSupport, PayerMixShift
export ConservativeStrategy, AggressiveExpansionStrategy, AccommodativeStrategy
export MultiLevelPolicyScenario, PolicyCouplingOutcomes
export simulate_policy_coupling!, analyze_policy_interactions
export calculate_federal_impact, calculate_state_impact
export build_aca_repeal_scenario, build_medicare_advantage_scenario
export build_consolidation_scenario, build_price_regulation_scenario

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

# ACA Repeal & Replace: models individual mandate elimination, community rating
# modification, and optional Medicaid expansion repeal
mutable struct ACARepealPolicy <: FederalPolicy
    medicaid_expansion_repealed::Bool
    individual_mandate_eliminated::Bool
    community_rating_modification::Float64  # multiplier on risk-rated premiums (1.0 = unchanged)
    rural_impact_multiplier::Float64        # additional burden on rural hospitals
    implementation_year::Int
end

# Medicare Advantage Transformation: shift to risk-adjusted capitation
mutable struct MedicareAdvantageTransformation <: FederalPolicy
    capitation_rate_change::Float64  # fractional change in per-member payment
    rural_rate_adjustment::Float64   # additional adjustment for rural providers
    urban_rate_adjustment::Float64   # additional adjustment for urban providers
    traditional_medicare_shift::Float64  # fraction of FFS volume moving to MA
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

# Consolidated Delivery Systems: vertical integration requirements and
# competition impact
mutable struct VerticalIntegrationPolicy <: StatePolicy
    integration_requirement::Float64  # fraction of services requiring integration
    competition_reduction::Float64    # reduction in market competition (0..1)
    efficiency_gain::Float64          # cost efficiency from integration
    implementation_year::Int
end

# Price Regulation Models: covers All-Payer, German/Dutch-style, and
# Australian ACHS-style payment regulation
mutable struct PriceRegulationPolicy <: StatePolicy
    model_type::String              # "all_payer", "german_dutch", "australian_achs"
    rate_cap_multiplier::Float64    # caps payment as multiple of Medicare rates
    negotiation_discount::Float64   # fractional reduction from negotiation
    applies_to_payers::Set{String}  # payers subject to regulation
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

function ACARepealPolicy(; medicaid_expansion_repealed=true, individual_mandate_eliminated=true,
                          community_rating_modification=1.5, rural_impact_multiplier=1.2,
                          implementation_year=1)
    ACARepealPolicy(medicaid_expansion_repealed, individual_mandate_eliminated,
                    community_rating_modification, rural_impact_multiplier, implementation_year)
end

function MedicareAdvantageTransformation(; capitation_rate_change=0.0, rural_rate_adjustment=-0.05,
                                          urban_rate_adjustment=0.02,
                                          traditional_medicare_shift=0.10,
                                          implementation_year=1)
    MedicareAdvantageTransformation(capitation_rate_change, rural_rate_adjustment,
                                    urban_rate_adjustment, traditional_medicare_shift,
                                    implementation_year)
end

function VerticalIntegrationPolicy(; integration_requirement=0.5, competition_reduction=0.20,
                                    efficiency_gain=0.05, implementation_year=1)
    VerticalIntegrationPolicy(integration_requirement, competition_reduction,
                               efficiency_gain, implementation_year)
end

function PriceRegulationPolicy(; model_type="all_payer", rate_cap_multiplier=1.1,
                                 negotiation_discount=0.10,
                                 applies_to_payers=Set{String}(["Commercial", "Medicare", "Medicaid"]),
                                 implementation_year=1)
    PriceRegulationPolicy(model_type, rate_cap_multiplier, negotiation_discount,
                           applies_to_payers, implementation_year)
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
    state_enrollment = Float64[baseline_state_data.enrollment]

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
        elseif policy isa ACARepealPolicy && year >= policy.implementation_year
            # Repeal reduces coverage, tightening hospital revenue
            if policy.medicaid_expansion_repealed
                total -= 0.08  # loss of Medicaid expansion revenue
            end
            if policy.individual_mandate_eliminated
                total -= 0.03  # higher uninsured rate increases bad debt
            end
            # Community rating modification affects premium risk pools
            total -= (policy.community_rating_modification - 1.0) * 0.05
        elseif policy isa MedicareAdvantageTransformation && year >= policy.implementation_year
            # Net effect of capitation change plus volume shift from FFS to MA
            total += policy.capitation_rate_change
            total -= policy.traditional_medicare_shift * 0.05
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
        elseif policy isa VerticalIntegrationPolicy && year >= policy.implementation_year
            # Efficiency gains improve hospital margins; competition reduction
            # may allow modest rate increases but also reduces market discipline
            total += policy.efficiency_gain - policy.competition_reduction * 0.02
        elseif policy isa PriceRegulationPolicy && year >= policy.implementation_year
            # Rate caps compress margins; negotiation discount directly reduces revenue
            total -= policy.negotiation_discount
            if policy.rate_cap_multiplier < 1.0
                total -= (1.0 - policy.rate_cap_multiplier) * 0.05
            end
        end
    end
    return total
end

function analyze_policy_interactions(scenario::MultiLevelPolicyScenario,
                                     outcomes::PolicyCouplingOutcomes)::Dict{String, Any}
    interactions = Dict{String, Any}()

    has_medicaid = any(p isa MedicaidExpansion for p in scenario.state_policies)
    has_medicare_cut = any(p isa MedicarePaymentReform for p in scenario.federal_policies)
    has_aca_repeal = any(p isa ACARepealPolicy for p in scenario.federal_policies)
    has_ma_transform = any(p isa MedicareAdvantageTransformation for p in scenario.federal_policies)
    has_integration = any(p isa VerticalIntegrationPolicy for p in scenario.state_policies)
    has_price_reg = any(p isa PriceRegulationPolicy for p in scenario.state_policies)

    if has_medicaid && has_medicare_cut
        interactions["medicaid_expansion_medicare_cut_stress"] = true
        interactions["stress_level"] = "high"
    end

    if has_aca_repeal
        interactions["aca_repeal_detected"] = true
        interactions["coverage_risk"] = "high"
    end

    if has_ma_transform
        interactions["medicare_advantage_transformation_detected"] = true
    end

    if has_integration
        interactions["vertical_integration_detected"] = true
    end

    if has_price_reg
        interactions["price_regulation_detected"] = true
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

# ====================================
# Scenario Builders
# ====================================

"""
    build_aca_repeal_scenario(; kwargs...) -> MultiLevelPolicyScenario

Construct a pre-configured ACA Repeal & Replace scenario with individual mandate
elimination, Medicaid expansion repeal, and modified community rating rules.
"""
function build_aca_repeal_scenario(;
    community_rating_modification=1.5,
    rural_impact_multiplier=1.2,
    implementation_year=1,
    hospital_strategies=Dict{String, HospitalStrategy}(),
    scenario_name="ACA Repeal & Replace"
)::MultiLevelPolicyScenario
    federal = FederalPolicy[
        ACARepealPolicy(
            medicaid_expansion_repealed=true,
            individual_mandate_eliminated=true,
            community_rating_modification=community_rating_modification,
            rural_impact_multiplier=rural_impact_multiplier,
            implementation_year=implementation_year
        )
    ]
    state = StatePolicy[
        MedicaidExpansion(coverage_increase=-0.10, implementation_year=implementation_year),
        PayerMixShift(from_payer="Medicaid", to_payer="Uninsured",
                      volume_shift=0.05, implementation_year=implementation_year)
    ]
    MultiLevelPolicyScenario(
        federal_policies=federal,
        state_policies=state,
        hospital_strategies=hospital_strategies,
        insurance_demand_elasticity=-0.4,
        scenario_name=scenario_name
    )
end

"""
    build_medicare_advantage_scenario(; kwargs...) -> MultiLevelPolicyScenario

Construct a pre-configured Medicare Advantage Transformation scenario shifting
volume from traditional FFS Medicare to risk-adjusted capitation.
"""
function build_medicare_advantage_scenario(;
    capitation_rate_change=0.0,
    rural_rate_adjustment=-0.05,
    urban_rate_adjustment=0.02,
    traditional_medicare_shift=0.10,
    implementation_year=1,
    hospital_strategies=Dict{String, HospitalStrategy}(),
    scenario_name="Medicare Advantage Transformation"
)::MultiLevelPolicyScenario
    federal = FederalPolicy[
        MedicareAdvantageTransformation(
            capitation_rate_change=capitation_rate_change,
            rural_rate_adjustment=rural_rate_adjustment,
            urban_rate_adjustment=urban_rate_adjustment,
            traditional_medicare_shift=traditional_medicare_shift,
            implementation_year=implementation_year
        )
    ]
    MultiLevelPolicyScenario(
        federal_policies=federal,
        hospital_strategies=hospital_strategies,
        hospital_demand_elasticity=-0.3,
        scenario_name=scenario_name
    )
end

"""
    build_consolidation_scenario(; kwargs...) -> MultiLevelPolicyScenario

Construct a pre-configured Consolidated Delivery Systems scenario modeling
vertical integration requirements and their impact on competition.
"""
function build_consolidation_scenario(;
    integration_requirement=0.5,
    competition_reduction=0.20,
    efficiency_gain=0.05,
    implementation_year=1,
    hospital_strategies=Dict{String, HospitalStrategy}(),
    scenario_name="Consolidated Delivery Systems"
)::MultiLevelPolicyScenario
    state = StatePolicy[
        VerticalIntegrationPolicy(
            integration_requirement=integration_requirement,
            competition_reduction=competition_reduction,
            efficiency_gain=efficiency_gain,
            implementation_year=implementation_year
        )
    ]
    MultiLevelPolicyScenario(
        state_policies=state,
        hospital_strategies=hospital_strategies,
        scenario_name=scenario_name
    )
end

"""
    build_price_regulation_scenario(model_type; kwargs...) -> MultiLevelPolicyScenario

Construct a pre-configured Price Regulation scenario.

`model_type` must be one of `"all_payer"` (Maryland-style), `"german_dutch"`
(negotiated rates), or `"australian_achs"` (activity-based funding).
"""
function build_price_regulation_scenario(
    model_type::String="all_payer";
    rate_cap_multiplier=1.1,
    negotiation_discount=0.10,
    applies_to_payers=Set{String}(["Commercial", "Medicare", "Medicaid"]),
    implementation_year=1,
    hospital_strategies=Dict{String, HospitalStrategy}(),
    scenario_name=""
)::MultiLevelPolicyScenario
    model_type in ("all_payer", "german_dutch", "australian_achs") ||
        error("model_type must be \"all_payer\", \"german_dutch\", or \"australian_achs\"")
    sname = isempty(scenario_name) ? "Price Regulation ($model_type)" : scenario_name
    state = StatePolicy[
        PriceRegulationPolicy(
            model_type=model_type,
            rate_cap_multiplier=rate_cap_multiplier,
            negotiation_discount=negotiation_discount,
            applies_to_payers=applies_to_payers,
            implementation_year=implementation_year
        )
    ]
    MultiLevelPolicyScenario(
        state_policies=state,
        hospital_strategies=hospital_strategies,
        scenario_name=sname
    )
end

end  # module
