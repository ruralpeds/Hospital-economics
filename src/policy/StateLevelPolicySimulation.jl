"""
    StateLevelPolicySimulation

Module for simulating state-level healthcare policy interventions and their impact
on hospital economics, patient access, care quality, and population health outcomes.

# Features
- PolicyIntervention type hierarchy (MedicaidExpansion, HospitalRateSetting,
  RuralHospitalSupport, PayerMixShift)
- StateHealthcareSystem representing a state's hospitals, population, and payer mix
- Baseline and intervention scenario simulation over multiple years
- Outcome tracking: financial margins, patient access, quality metrics, equity analysis
- Supports modeling ACA-style Medicaid expansion, all-payer rate-setting,
  price transparency rules, and rural hospital closure prevention
"""

module StateLevelPolicySimulation

export PolicyIntervention
export MedicaidExpansion, HospitalRateSetting, RuralHospitalSupport, PayerMixShift
export Hospital, StateHealthcareSystem, PolicyOutcomes
export simulate_policy_intervention!
export analyze_policy_outcomes, compare_scenarios
export kentucky_medicaid_expansion_scenario

using Statistics

# ====================================
# Abstract Type
# ====================================

"""
    PolicyIntervention

Abstract supertype for all state-level healthcare policy interventions.
"""
abstract type PolicyIntervention end

# ====================================
# Hospital
# ====================================

"""
    Hospital

Represents a single hospital within a state healthcare system.

# Fields
- `id`: Unique identifier
- `name`: Human-readable name
- `beds`: Licensed bed count
- `is_rural`: Rural designation flag
- `payer_mix`: Fraction of volume by payer (must sum to ~1.0)
- `baseline_margin`: Operating margin (e.g., 0.04 = 4%)
- `baseline_volume`: Annual inpatient admissions
- `quality_score`: Composite quality metric (0–1, higher is better)
- `cost_per_case`: Average cost per admission (dollars)
"""
mutable struct Hospital
    id::String
    name::String
    beds::Int
    is_rural::Bool
    payer_mix::Dict{String, Float64}
    baseline_margin::Float64
    baseline_volume::Float64
    quality_score::Float64
    cost_per_case::Float64
end

function Hospital(; id::String="", name::String="", beds::Int=100,
                  is_rural::Bool=false,
                  payer_mix::Dict{String,Float64}=Dict(
                      "Medicare"   => 0.40,
                      "Medicaid"   => 0.20,
                      "Commercial" => 0.30,
                      "Uninsured"  => 0.10),
                  baseline_margin::Float64=0.04,
                  baseline_volume::Float64=1000.0,
                  quality_score::Float64=0.85,
                  cost_per_case::Float64=10_000.0)
    Hospital(id, name, beds, is_rural, payer_mix,
             baseline_margin, baseline_volume, quality_score, cost_per_case)
end

# ====================================
# Policy Interventions
# ====================================

"""
    MedicaidExpansion <: PolicyIntervention

Models an ACA-style Medicaid expansion that increases coverage for low-income adults.

# Fields
- `coverage_increase`: Fraction of previously uninsured population gaining Medicaid (e.g., 0.15)
- `payment_rate_multiplier`: Medicaid payment rate relative to baseline (e.g., 1.0 = unchanged)
- `eligibility_age`: Upper age limit for expansion eligibility (e.g., 65)
"""
struct MedicaidExpansion <: PolicyIntervention
    coverage_increase::Float64
    payment_rate_multiplier::Float64
    eligibility_age::Int
end

function MedicaidExpansion(; coverage_increase::Float64=0.0,
                             payment_rate_multiplier::Float64=1.0,
                             eligibility_age::Int=65)
    MedicaidExpansion(coverage_increase, payment_rate_multiplier, eligibility_age)
end

"""
    HospitalRateSetting <: PolicyIntervention

Models an all-payer rate-setting program (e.g., Maryland model) that sets uniform
payment rates across payers to achieve a target operating margin.

# Fields
- `target_margin`: Desired operating margin for affected hospitals (e.g., 0.03)
- `affected_payers`: Set of payer names subject to rate regulation
- `adjustment_period`: Years over which rates are phased in
"""
struct HospitalRateSetting <: PolicyIntervention
    target_margin::Float64
    affected_payers::Set{String}
    adjustment_period::Int
end

function HospitalRateSetting(; target_margin::Float64=0.03,
                               affected_payers::Set{String}=Set{String}(),
                               adjustment_period::Int=3)
    HospitalRateSetting(target_margin, affected_payers, adjustment_period)
end

"""
    RuralHospitalSupport <: PolicyIntervention

Models supplemental payments and support programs designed to prevent rural hospital
closures (e.g., Critical Access Hospital program enhancements, state rural stipends).

# Fields
- `supplemental_payment_per_bed`: Annual supplemental payment per licensed bed (dollars)
- `criteria`: Predicate function `Hospital -> Bool` identifying qualifying hospitals
- `funding_source`: Description of funding mechanism (e.g., "state", "federal", "combined")
"""
struct RuralHospitalSupport <: PolicyIntervention
    supplemental_payment_per_bed::Float64
    criteria::Function
    funding_source::String
end

function RuralHospitalSupport(; supplemental_payment_per_bed::Float64=0.0,
                                criteria::Function=h -> h.is_rural,
                                funding_source::String="state")
    RuralHospitalSupport(supplemental_payment_per_bed, criteria, funding_source)
end

"""
    PayerMixShift <: PolicyIntervention

Models policies that shift patient volume between payers (e.g., price transparency
rules that redirect commercially insured patients, or managed care carve-outs).

# Fields
- `from_payer`: Source payer name (e.g., "Uninsured")
- `to_payer`: Destination payer name (e.g., "Medicaid")
- `volume_shift`: Fraction of `from_payer` volume that moves to `to_payer` (0–1)
"""
struct PayerMixShift <: PolicyIntervention
    from_payer::String
    to_payer::String
    volume_shift::Float64
end

function PayerMixShift(; from_payer::String="", to_payer::String="",
                         volume_shift::Float64=0.0)
    PayerMixShift(from_payer, to_payer, volume_shift)
end

# ====================================
# State Healthcare System
# ====================================

"""
    StateHealthcareSystem

Encapsulates a state's hospital network and population health context.

# Fields
- `hospitals`: All hospitals in the state
- `state_population`: Total state population
- `payer_mix`: State-wide fraction by payer (shares of insured population)
- `baseline_utilization`: Admission rates by service line or category
- `baseline_outcomes`: Population health metrics (e.g., mortality, readmission rates)
"""
struct StateHealthcareSystem
    hospitals::Vector{Hospital}
    state_population::Int
    payer_mix::Dict{String, Float64}
    baseline_utilization::Dict{String, Float64}
    baseline_outcomes::Dict{String, Float64}
end

function StateHealthcareSystem(; hospitals::Vector{Hospital}=Hospital[],
                                 state_population::Int=1_000_000,
                                 payer_mix::Dict{String,Float64}=Dict(
                                     "Medicare"   => 0.18,
                                     "Medicaid"   => 0.22,
                                     "Commercial" => 0.50,
                                     "Uninsured"  => 0.10),
                                 baseline_utilization::Dict{String,Float64}=Dict(
                                     "inpatient"  => 0.08,
                                     "outpatient" => 0.40,
                                     "emergency"  => 0.15),
                                 baseline_outcomes::Dict{String,Float64}=Dict(
                                     "mortality_rate"    => 0.02,
                                     "readmission_rate"  => 0.15,
                                     "preventable_admissions" => 0.10))
    StateHealthcareSystem(hospitals, state_population, payer_mix,
                          baseline_utilization, baseline_outcomes)
end

# ====================================
# Policy Outcomes
# ====================================

"""
    PolicyOutcomes

Records the simulated impacts of a policy intervention over the simulation horizon.

# Fields
- `policy_type`: Name of the policy intervention class
- `years`: Number of simulation years (excluding baseline year 0)
- `hospital_margins`: Operating margin by hospital ID, one entry per year (year 0 = baseline)
- `patient_access`: Coverage fractions by payer category per year
- `quality_metrics`: Quality indicators (mortality, readmissions) per year
- `equity_metrics`: Equity indicators (uninsured rate, rural access) per year
- `total_cost`: System-wide cost per year (dollars)
- `hospital_closures`: IDs of hospitals that fell below viability threshold
- `financial_impact`: Summary financial statistics
- `access_impact`: Summary access statistics
"""
mutable struct PolicyOutcomes
    policy_type::String
    years::Int
    hospital_margins::Dict{String, Vector{Float64}}
    patient_access::Dict{String, Vector{Float64}}
    quality_metrics::Dict{String, Vector{Float64}}
    equity_metrics::Dict{String, Vector{Float64}}
    total_cost::Vector{Float64}
    hospital_closures::Vector{String}
    financial_impact::Dict{String, Float64}
    access_impact::Dict{String, Float64}
end

# ====================================
# Payer rate constants (relative to cost)
# ====================================

# Payment rate as a fraction of cost for each payer
const PAYER_RATES = Dict{String, Float64}(
    "Medicare"   => 0.97,   # pays ~97% of cost
    "Medicaid"   => 0.90,   # pays ~90% of cost
    "Commercial" => 1.15,   # pays 115% of cost (cross-subsidy)
    "Uninsured"  => 0.30,   # charity care / partial collection
)

# Closure threshold: hospital exits if operating margin falls below this
const CLOSURE_THRESHOLD = -0.05   # -5%

# ====================================
# Internal helpers
# ====================================

"""
    _revenue_ratio(payer_mix) -> Float64

Compute the blended revenue-to-cost ratio for a given payer mix.
Uses fixed payer rate constants (payment rate relative to cost).
"""
function _revenue_ratio(payer_mix::Dict{String,Float64})::Float64
    ratio = 0.0
    for (payer, share) in payer_mix
        rate = get(PAYER_RATES, payer, 1.0)
        ratio += share * rate
    end
    return ratio
end

"""
    _margin_delta(old_mix, new_mix) -> Float64

Compute the change in operating margin due to a payer-mix shift.
Returns the additive margin change (positive = improvement).
"""
function _margin_delta(old_mix::Dict{String,Float64},
                       new_mix::Dict{String,Float64})::Float64
    return _revenue_ratio(new_mix) - _revenue_ratio(old_mix)
end

"""
    _apply_medicaid_expansion(hospital, policy, phase_in) -> (new_margin, new_volume, new_mix)

Return updated margin, volume, and payer mix for a hospital under Medicaid expansion.
"""
function _apply_medicaid_expansion(hospital::Hospital,
                                   policy::MedicaidExpansion,
                                   phase_in::Float64)
    old_mix         = hospital.payer_mix
    mix             = copy(old_mix)
    uninsured_share = get(mix, "Uninsured", 0.0)
    medicaid_share  = get(mix, "Medicaid",  0.0)

    shift = uninsured_share * policy.coverage_increase * phase_in
    mix["Uninsured"] = max(0.0, uninsured_share - shift)
    new_medicaid     = medicaid_share + shift
    # Apply payment rate multiplier: weighted blend of existing and expanded shares
    mix["Medicaid"]  = min(1.0,
                           new_medicaid * policy.payment_rate_multiplier +
                           medicaid_share * (1.0 - policy.payment_rate_multiplier))

    # Volume increases because previously-uninsured patients now seek care
    volume_increase = hospital.baseline_volume * shift * 0.5
    new_volume = hospital.baseline_volume + volume_increase

    new_margin = hospital.baseline_margin + _margin_delta(old_mix, mix)
    return new_margin, new_volume, mix
end

"""
    _apply_rate_setting(hospital, policy, phase_in) -> (new_margin, new_volume, new_mix)

Return updated margin and volume under an all-payer rate-setting program.
"""
function _apply_rate_setting(hospital::Hospital,
                              policy::HospitalRateSetting,
                              phase_in::Float64)
    mix = copy(hospital.payer_mix)
    current_margin = hospital.baseline_margin
    # Margin is moved toward target_margin over adjustment_period
    delta = (policy.target_margin - current_margin) * phase_in
    new_margin = current_margin + delta

    # Volume: regulated rates may reduce or maintain volume depending on direction
    volume_factor = 1.0 + (delta > 0 ? 0.01 : -0.01) * phase_in
    new_volume = hospital.baseline_volume * volume_factor
    return new_margin, new_volume, mix
end

"""
    _apply_rural_support(hospital, policy, phase_in) -> (new_margin, new_volume, new_mix)

Return updated margin for a qualifying rural hospital receiving supplemental payments.
"""
function _apply_rural_support(hospital::Hospital,
                               policy::RuralHospitalSupport,
                               phase_in::Float64)
    mix = copy(hospital.payer_mix)
    qualifies = policy.criteria(hospital)
    if !qualifies
        return hospital.baseline_margin, hospital.baseline_volume, mix
    end

    supplemental_revenue = policy.supplemental_payment_per_bed * hospital.beds * phase_in
    # Margin boost = supplemental / total_revenue (approx total_revenue = cost / (1 - margin))
    total_cost = hospital.baseline_volume * hospital.cost_per_case
    total_revenue = total_cost / max(1.0 - hospital.baseline_margin, 0.01)
    margin_boost = supplemental_revenue / total_revenue
    new_margin = hospital.baseline_margin + margin_boost
    return new_margin, hospital.baseline_volume, mix
end

"""
    _apply_payer_mix_shift(hospital, policy, phase_in) -> (new_margin, new_volume, new_mix)

Return updated margin and payer mix after shifting volume between payers.
"""
function _apply_payer_mix_shift(hospital::Hospital,
                                 policy::PayerMixShift,
                                 phase_in::Float64)
    old_mix    = hospital.payer_mix
    mix        = copy(old_mix)
    from_share = get(mix, policy.from_payer, 0.0)
    to_share   = get(mix, policy.to_payer,   0.0)

    shift = from_share * policy.volume_shift * phase_in
    mix[policy.from_payer] = max(0.0, from_share - shift)
    mix[policy.to_payer]   = min(1.0, to_share   + shift)

    new_margin = hospital.baseline_margin + _margin_delta(old_mix, mix)
    return new_margin, hospital.baseline_volume, mix
end

"""
    _apply_policy(hospital, policy, phase_in) -> (new_margin, new_volume, new_mix)

Dispatch to the correct policy application function.
"""
function _apply_policy(hospital::Hospital, policy::MedicaidExpansion, phase_in::Float64)
    return _apply_medicaid_expansion(hospital, policy, phase_in)
end
function _apply_policy(hospital::Hospital, policy::HospitalRateSetting, phase_in::Float64)
    return _apply_rate_setting(hospital, policy, phase_in)
end
function _apply_policy(hospital::Hospital, policy::RuralHospitalSupport, phase_in::Float64)
    return _apply_rural_support(hospital, policy, phase_in)
end
function _apply_policy(hospital::Hospital, policy::PayerMixShift, phase_in::Float64)
    return _apply_payer_mix_shift(hospital, policy, phase_in)
end

# ====================================
# Core Simulation
# ====================================

"""
    simulate_policy_intervention!(state, policy, years) -> PolicyOutcomes

Simulate a state-level healthcare policy over `years` years.

The simulation runs a baseline year (year 0) and then applies the policy incrementally
over the specified horizon. Each hospital in `state.hospitals` is updated annually.

# Arguments
- `state`: The `StateHealthcareSystem` to simulate
- `policy`: A `PolicyIntervention` instance describing the policy
- `years`: Number of policy years to simulate

# Returns
A `PolicyOutcomes` struct with time-series data for margins, access, quality, and equity.
"""
function simulate_policy_intervention!(state::StateHealthcareSystem,
                                       policy::PolicyIntervention,
                                       years::Int)::PolicyOutcomes
    policy_type = string(typeof(policy))

    # Initialise tracking containers
    hospital_margins   = Dict{String, Vector{Float64}}()
    patient_access     = Dict{String, Vector{Float64}}()
    quality_metrics    = Dict{String, Vector{Float64}}()
    equity_metrics     = Dict{String, Vector{Float64}}()
    total_cost         = Float64[]
    hospital_closures  = String[]

    # ── Year 0: record baseline ───────────────────────────────────────────
    for h in state.hospitals
        hospital_margins[h.id]   = [h.baseline_margin]
        quality_metrics[h.id]    = [h.quality_score]
    end

    # State-level access baseline
    uninsured_baseline = get(state.payer_mix, "Uninsured", 0.10)
    medicaid_baseline  = get(state.payer_mix, "Medicaid",  0.22)
    patient_access["uninsured_rate"]  = [uninsured_baseline]
    patient_access["medicaid_rate"]   = [medicaid_baseline]
    patient_access["coverage_rate"]   = [1.0 - uninsured_baseline]

    equity_metrics["rural_access_score"]       = [1.0]  # normalised 0-1
    equity_metrics["low_income_access_score"]  = [1.0 - uninsured_baseline * 2]

    # System-wide baseline cost
    baseline_total_cost = sum(h.baseline_volume * h.cost_per_case for h in state.hospitals;
                              init=0.0)
    push!(total_cost, baseline_total_cost)

    # ── Years 1..years: apply policy ─────────────────────────────────────
    for year in 1:years
        year_total_cost = 0.0

        # Phase-in fraction (linear ramp; rate-setting uses its own period)
        phase_in = if policy isa HospitalRateSetting
            min(1.0, year / max(1, policy.adjustment_period))
        else
            min(1.0, Float64(year))   # immediate full effect from year 1
        end

        # ── Per-hospital update ──────────────────────────────────────────
        for h in state.hospitals
            h.id in hospital_closures && continue

            new_margin, new_volume, new_mix = _apply_policy(h, policy, phase_in)

            # Quality: Medicaid expansion and rural support improve quality slightly
            quality_delta = if policy isa MedicaidExpansion
                0.005 * phase_in * get(new_mix, "Medicaid", 0.0)
            elseif policy isa RuralHospitalSupport
                policy.criteria(h) ? 0.01 * phase_in : 0.0
            elseif policy isa HospitalRateSetting
                (new_margin > h.baseline_margin) ? 0.005 * phase_in : -0.002 * phase_in
            else
                0.0
            end
            new_quality = clamp(h.quality_score + quality_delta, 0.0, 1.0)

            # Closure check
            if new_margin < CLOSURE_THRESHOLD
                push!(hospital_closures, h.id)
                continue
            end

            push!(hospital_margins[h.id], new_margin)
            push!(quality_metrics[h.id], new_quality)

            year_total_cost += new_volume * h.cost_per_case
        end

        # ── State-level access metrics ───────────────────────────────────
        new_uninsured = if policy isa MedicaidExpansion
            max(0.0, uninsured_baseline - uninsured_baseline * policy.coverage_increase * phase_in)
        elseif policy isa PayerMixShift && policy.from_payer == "Uninsured"
            max(0.0, uninsured_baseline - uninsured_baseline * policy.volume_shift * phase_in)
        else
            uninsured_baseline
        end
        new_medicaid = if policy isa MedicaidExpansion
            min(1.0, medicaid_baseline + uninsured_baseline * policy.coverage_increase * phase_in)
        else
            medicaid_baseline
        end

        push!(patient_access["uninsured_rate"],  new_uninsured)
        push!(patient_access["medicaid_rate"],   new_medicaid)
        push!(patient_access["coverage_rate"],   1.0 - new_uninsured)

        # ── Equity metrics ───────────────────────────────────────────────
        rural_hospitals_open = [h for h in state.hospitals
                                if h.is_rural && h.id ∉ hospital_closures]
        total_rural = count(h -> h.is_rural, state.hospitals)
        rural_access = total_rural == 0 ? 1.0 : length(rural_hospitals_open) / total_rural

        push!(equity_metrics["rural_access_score"], rural_access)
        push!(equity_metrics["low_income_access_score"],
              clamp(1.0 - new_uninsured * 2, 0.0, 1.0))

        push!(total_cost, year_total_cost)
    end

    # ── Summary statistics ────────────────────────────────────────────────
    active_ids = [h.id for h in state.hospitals if h.id ∉ hospital_closures]

    baseline_avg_margin = isempty(state.hospitals) ? 0.0 :
        mean(h.baseline_margin for h in state.hospitals)
    final_avg_margin = isempty(active_ids) ? 0.0 :
        mean(hospital_margins[id][end] for id in active_ids)

    financial_impact = Dict{String, Float64}(
        "baseline_avg_margin"    => baseline_avg_margin,
        "final_avg_margin"       => final_avg_margin,
        "margin_change"          => final_avg_margin - baseline_avg_margin,
        "hospital_closures"      => Float64(length(hospital_closures)),
        "active_hospitals"       => Float64(length(active_ids)),
        "total_cost_baseline"    => isempty(total_cost) ? 0.0 : total_cost[1],
        "total_cost_final"       => isempty(total_cost) ? 0.0 : total_cost[end],
    )

    baseline_coverage = isempty(patient_access["coverage_rate"]) ? 0.0 :
        patient_access["coverage_rate"][1]
    final_coverage = isempty(patient_access["coverage_rate"]) ? 0.0 :
        patient_access["coverage_rate"][end]

    access_impact = Dict{String, Float64}(
        "baseline_coverage_rate" => baseline_coverage,
        "final_coverage_rate"    => final_coverage,
        "coverage_change"        => final_coverage - baseline_coverage,
        "uninsured_reduction"    => isempty(patient_access["uninsured_rate"]) ? 0.0 :
            patient_access["uninsured_rate"][1] - patient_access["uninsured_rate"][end],
    )

    return PolicyOutcomes(
        policy_type, years,
        hospital_margins, patient_access, quality_metrics, equity_metrics,
        total_cost, hospital_closures,
        financial_impact, access_impact,
    )
end

# ====================================
# Analysis Utilities
# ====================================

"""
    analyze_policy_outcomes(outcomes) -> Dict{String, Any}

Return a human-readable summary of simulation outcomes.
"""
function analyze_policy_outcomes(outcomes::PolicyOutcomes)::Dict{String, Any}
    summary = Dict{String, Any}()
    summary["policy_type"]    = outcomes.policy_type
    summary["years_simulated"] = outcomes.years
    summary["hospitals_closed"] = length(outcomes.hospital_closures)

    if !isempty(outcomes.hospital_margins)
        active = [id for id in keys(outcomes.hospital_margins)
                  if id ∉ outcomes.hospital_closures]
        if !isempty(active)
            avg_start = mean(outcomes.hospital_margins[id][1] for id in active)
            avg_end   = mean(outcomes.hospital_margins[id][end] for id in active)
            summary["avg_margin_start"] = avg_start
            summary["avg_margin_end"]   = avg_end
            summary["margin_trend"]     = avg_end > avg_start ? "improving" : "declining"
        end
    end

    summary["coverage_improvement"] = get(outcomes.access_impact, "coverage_change", 0.0)
    summary["uninsured_reduction"]  = get(outcomes.access_impact, "uninsured_reduction", 0.0)

    if !isempty(outcomes.quality_metrics)
        active_q = [id for id in keys(outcomes.quality_metrics)
                    if id ∉ outcomes.hospital_closures]
        if !isempty(active_q)
            avg_q = mean(outcomes.quality_metrics[id][end] for id in active_q)
            summary["avg_final_quality"] = avg_q
        end
    end

    return summary
end

"""
    compare_scenarios(outcomes_a, outcomes_b) -> Dict{String, Float64}

Compare two PolicyOutcomes structs and return key differential metrics.
"""
function compare_scenarios(a::PolicyOutcomes, b::PolicyOutcomes)::Dict{String, Float64}
    diff = Dict{String, Float64}()
    diff["margin_difference"]    = get(b.financial_impact, "final_avg_margin", 0.0) -
                                   get(a.financial_impact, "final_avg_margin", 0.0)
    diff["coverage_difference"]  = get(b.access_impact, "final_coverage_rate", 0.0) -
                                   get(a.access_impact, "final_coverage_rate", 0.0)
    diff["closures_difference"]  = Float64(length(b.hospital_closures)) -
                                   Float64(length(a.hospital_closures))
    return diff
end

# ====================================
# Reference Scenario: Kentucky 2014
# ====================================

"""
    kentucky_medicaid_expansion_scenario() -> (StateHealthcareSystem, MedicaidExpansion)

Return a pre-configured Kentucky 2014 Medicaid expansion scenario for validation.

Kentucky expanded Medicaid under the ACA on January 1, 2014. The state's uninsured
rate fell from ~14% to ~6% by 2016, and Medicaid enrollment grew substantially.
This scenario provides a baseline for comparing simulated vs. observed outcomes.
"""
function kentucky_medicaid_expansion_scenario()
    # Representative Kentucky hospital network (simplified)
    hospitals = Hospital[
        Hospital(id="KY_001", name="Louisville Urban Medical Center",
                 beds=500, is_rural=false,
                 payer_mix=Dict("Medicare"=>0.38,"Medicaid"=>0.25,
                                "Commercial"=>0.27,"Uninsured"=>0.10),
                 baseline_margin=0.04, baseline_volume=18_000.0,
                 quality_score=0.88, cost_per_case=12_000.0),
        Hospital(id="KY_002", name="Lexington Regional Hospital",
                 beds=350, is_rural=false,
                 payer_mix=Dict("Medicare"=>0.40,"Medicaid"=>0.22,
                                "Commercial"=>0.28,"Uninsured"=>0.10),
                 baseline_margin=0.03, baseline_volume=12_000.0,
                 quality_score=0.86, cost_per_case=11_500.0),
        Hospital(id="KY_003", name="Eastern Kentucky Rural Hospital",
                 beds=75, is_rural=true,
                 payer_mix=Dict("Medicare"=>0.45,"Medicaid"=>0.28,
                                "Commercial"=>0.15,"Uninsured"=>0.12),
                 baseline_margin=0.01, baseline_volume=1_800.0,
                 quality_score=0.78, cost_per_case=9_500.0),
        Hospital(id="KY_004", name="Appalachian Community Hospital",
                 beds=50, is_rural=true,
                 payer_mix=Dict("Medicare"=>0.48,"Medicaid"=>0.30,
                                "Commercial"=>0.10,"Uninsured"=>0.12),
                 baseline_margin=0.005, baseline_volume=900.0,
                 quality_score=0.75, cost_per_case=9_000.0),
    ]

    # Kentucky 2013 state-level payer mix (pre-expansion)
    state = StateHealthcareSystem(
        hospitals=hospitals,
        state_population=4_395_000,
        payer_mix=Dict("Medicare"=>0.18,"Medicaid"=>0.22,
                       "Commercial"=>0.46,"Uninsured"=>0.14),
        baseline_utilization=Dict("inpatient"=>0.07,"outpatient"=>0.38,"emergency"=>0.14),
        baseline_outcomes=Dict("mortality_rate"=>0.022,"readmission_rate"=>0.155,
                               "preventable_admissions"=>0.12),
    )

    # ACA expansion: ~14% uninsured → ~6% (≈8 percentage point reduction = 57% of uninsured gain coverage)
    policy = MedicaidExpansion(
        coverage_increase=0.57,
        payment_rate_multiplier=1.0,
        eligibility_age=65,
    )

    return state, policy
end

end  # module StateLevelPolicySimulation
