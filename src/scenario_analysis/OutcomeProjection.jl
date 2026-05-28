# ============================================================================
# OUTCOME PROJECTION (Module 7)
# ============================================================================
# Project financial outcomes for payer contracts under different healthcare
# scenarios.  Supports single-scenario deterministic projection, multi-
# scenario weighted projection, and Monte-Carlo probabilistic projection.
# ============================================================================

using Statistics
using Distributions
using Random

# ============================================================================
# SINGLE-SCENARIO PROJECTION
# ============================================================================

"""
    ScenarioProjectionResult

Financial projection for a single contract under a single scenario.

# Fields
- `scenario_id::String`: identifier of the scenario used
- `scenario_name::String`: human-readable scenario label
- `contract_name::String`: name of the projected contract
- `annual_revenue::Vector{Float64}`: projected hospital revenue per year
- `annual_costs::Vector{Float64}`: projected hospital costs per year
- `annual_margin::Vector{Float64}`: projected margin (revenue - costs) per year
- `cumulative_margin::Float64`: sum of annual margins
- `npv_margin::Float64`: net-present-value of annual margins
- `probability::Float64`: scenario probability weight
"""
struct ScenarioProjectionResult
    scenario_id::String
    scenario_name::String
    contract_name::String
    annual_revenue::Vector{Float64}
    annual_costs::Vector{Float64}
    annual_margin::Vector{Float64}
    cumulative_margin::Float64
    npv_margin::Float64
    probability::Float64
end

"""
    project_contract_under_scenario(
        contract::PayerContract,
        scenario::HealthcareScenario;
        base_volume::Int = 1000,
        base_cost_per_case::Float64 = 12000.0,
        base_quality_score::Float64 = 0.80
    )::ScenarioProjectionResult

Project the financial performance of a payer contract under a single
`HealthcareScenario`.

For each projection year the function:
1. Grows volume by the scenario's `volume_growth_rate`
2. Inflates costs by `cost_inflation_rate`
3. Adjusts reimbursement by `reimbursement_change_rate`
4. Applies the scenario's `quality_score_adjustment` and `policy_impact`
5. Computes margin and discounts to present value

# Arguments
- `contract::PayerContract`: the contract to evaluate
- `scenario::HealthcareScenario`: operating-environment assumptions
- `base_volume::Int`: starting annual case volume
- `base_cost_per_case::Float64`: starting average cost per case (USD)
- `base_quality_score::Float64`: starting quality score (0-1)

# Returns
A `ScenarioProjectionResult` with year-by-year financials.
"""
function project_contract_under_scenario(
    contract::PayerContract,
    scenario::HealthcareScenario;
    base_volume::Int = 1000,
    base_cost_per_case::Float64 = 12000.0,
    base_quality_score::Float64 = 0.80
)::ScenarioProjectionResult

    n_years = scenario.projection_years
    annual_revenue = Float64[]
    annual_costs = Float64[]
    annual_margin = Float64[]

    for yr in 1:n_years
        # ── Volume ──────────────────────────────────────────────────
        projected_volume = base_volume * (1.0 + scenario.volume_growth_rate)^yr

        # ── Costs ───────────────────────────────────────────────────
        cost_per_case = base_cost_per_case * (1.0 + scenario.cost_inflation_rate)^yr
        total_cost = cost_per_case * projected_volume

        # ── Revenue ─────────────────────────────────────────────────
        revenue = _compute_scenario_revenue(
            contract, projected_volume, cost_per_case, yr,
            scenario.reimbursement_change_rate,
            base_quality_score + scenario.quality_score_adjustment
        )

        # ── Policy impact (spread evenly) ───────────────────────────
        revenue += scenario.policy_impact / n_years

        push!(annual_revenue, revenue)
        push!(annual_costs, total_cost)
        push!(annual_margin, revenue - total_cost)
    end

    cumulative = sum(annual_margin)
    npv = sum(annual_margin[yr] / (1.0 + scenario.discount_rate)^yr for yr in 1:n_years)

    return ScenarioProjectionResult(
        scenario.id,
        scenario.name,
        contract isa PayerContract ? _contract_name(contract) : "Unknown",
        annual_revenue,
        annual_costs,
        annual_margin,
        cumulative,
        npv,
        scenario.probability,
    )
end

# ── Internal: revenue calculation under scenario assumptions ──────────────

function _compute_scenario_revenue(
    contract::PayerContract,
    volume::Float64,
    cost_per_case::Float64,
    year::Int,
    reimbursement_change_rate::Float64,
    quality_score::Float64
)::Float64

    int_volume = Int(round(volume))

    if contract isa FeeForServiceContract
        rate = contract.base_rate_per_case * (1.0 + reimbursement_change_rate)^year
        return rate * int_volume

    elseif contract isa CapitationContract
        monthly = contract.monthly_capitation_per_member * contract.risk_adjuster *
                  (1.0 + reimbursement_change_rate)^year
        return monthly * 12 * contract.expected_members

    elseif contract isa BundledPaymentContract
        bundle = contract.bundle_price * (1.0 + reimbursement_change_rate)^year
        return bundle * int_volume

    elseif contract isa SharedSavingsContract
        expected_cost = cost_per_case * volume
        savings = max(0.0, contract.baseline_cost - expected_cost)
        shared = quality_score >= contract.quality_threshold && savings > contract.minimum_savings_threshold ?
                 savings * contract.shared_savings_rate : 0.0
        base_rev = contract.baseline_cost
        if contract.risk_sharing && savings < 0
            base_rev += savings * contract.shared_loss_rate
        end
        return base_rev + shared

    elseif contract isa QualityBasedPaymentContract
        quality_adj = clamp(quality_score - 0.80, -0.15, 0.10)  # deviation from 80 % target
        return contract.base_payment * (1.0 + quality_adj)

    else
        return cost_per_case * volume  # fallback: break-even
    end
end

function _contract_name(contract::PayerContract)::String
    if hasproperty(contract, :name)
        return contract.name
    end
    return string(typeof(contract))
end

# ============================================================================
# MULTI-SCENARIO PROJECTION
# ============================================================================

"""
    project_contract_across_scenarios(
        contract::PayerContract,
        scenarios::Vector{HealthcareScenario};
        base_volume::Int = 1000,
        base_cost_per_case::Float64 = 12000.0,
        base_quality_score::Float64 = 0.80
    )::Vector{ScenarioProjectionResult}

Run `project_contract_under_scenario` for every scenario in the set and
return the collected results.  Useful as input to
`calculate_scenario_probability_distribution`.
"""
function project_contract_across_scenarios(
    contract::PayerContract,
    scenarios::Vector{HealthcareScenario};
    base_volume::Int = 1000,
    base_cost_per_case::Float64 = 12000.0,
    base_quality_score::Float64 = 0.80
)::Vector{ScenarioProjectionResult}

    results = ScenarioProjectionResult[]
    for scenario in scenarios
        result = project_contract_under_scenario(
            contract, scenario;
            base_volume = base_volume,
            base_cost_per_case = base_cost_per_case,
            base_quality_score = base_quality_score,
        )
        push!(results, result)
    end
    return results
end

# ============================================================================
# PROBABILITY-WEIGHTED DISTRIBUTION
# ============================================================================

"""
    ScenarioProbabilityDistribution

Probability-weighted summary across multiple scenario projections.

# Fields
- `contract_name::String`: contract being evaluated
- `expected_npv::Float64`: probability-weighted expected NPV
- `expected_cumulative_margin::Float64`: probability-weighted cumulative margin
- `best_case_npv::Float64`: highest NPV across scenarios
- `worst_case_npv::Float64`: lowest NPV across scenarios
- `npv_range::Float64`: best minus worst NPV
- `scenario_npvs::Dict{String,Float64}`: scenario id -> NPV
- `scenario_weights::Dict{String,Float64}`: scenario id -> probability weight
"""
struct ScenarioProbabilityDistribution
    contract_name::String
    expected_npv::Float64
    expected_cumulative_margin::Float64
    best_case_npv::Float64
    worst_case_npv::Float64
    npv_range::Float64
    scenario_npvs::Dict{String,Float64}
    scenario_weights::Dict{String,Float64}
end

"""
    calculate_scenario_probability_distribution(
        results::Vector{ScenarioProjectionResult}
    )::ScenarioProbabilityDistribution

Aggregate multiple scenario projections into a probability-weighted
distribution.  Each result's `probability` field is used as its weight.
"""
function calculate_scenario_probability_distribution(
    results::Vector{ScenarioProjectionResult}
)::ScenarioProbabilityDistribution

    isempty(results) && error("results vector must not be empty")

    contract_name = results[1].contract_name

    scenario_npvs = Dict{String,Float64}()
    scenario_weights = Dict{String,Float64}()

    for r in results
        scenario_npvs[r.scenario_id] = r.npv_margin
        scenario_weights[r.scenario_id] = r.probability
    end

    # Normalize probabilities if they do not sum to 1
    total_prob = sum(r.probability for r in results)
    norm = total_prob > 0.0 ? total_prob : 1.0

    expected_npv = sum(r.npv_margin * r.probability / norm for r in results)
    expected_cumulative = sum(r.cumulative_margin * r.probability / norm for r in results)

    best_npv = maximum(r.npv_margin for r in results)
    worst_npv = minimum(r.npv_margin for r in results)

    return ScenarioProbabilityDistribution(
        contract_name,
        expected_npv,
        expected_cumulative,
        best_npv,
        worst_npv,
        best_npv - worst_npv,
        scenario_npvs,
        scenario_weights,
    )
end

# ============================================================================
# SUMMARY / FORMATTING
# ============================================================================

"""
    summarize_scenario_projections(
        results::Vector{ScenarioProjectionResult}
    )::String

Produce a human-readable summary table of scenario projection results
including per-scenario margins, NPVs, and the probability-weighted expected
value.
"""
function summarize_scenario_projections(
    results::Vector{ScenarioProjectionResult}
)::String

    io = IOBuffer()

    println(io, "╔════════════════════════════════════════════════════════════════════╗")
    println(io, "║                 SCENARIO PROJECTION SUMMARY                       ║")
    println(io, "╚════════════════════════════════════════════════════════════════════╝")
    println(io, "")

    if isempty(results)
        println(io, "  (no results)")
        return String(take!(io))
    end

    println(io, "Contract: $(results[1].contract_name)")
    println(io, "")

    # Per-scenario detail
    println(io, "──── PER-SCENARIO RESULTS ─────────────────────────────────────────")
    for r in results
        println(io, "  $(r.scenario_name) (p=$(round(r.probability, digits=2)))")
        for (yr, m) in enumerate(r.annual_margin)
            println(io, "    Year $yr margin: USD $(round(m, digits=0))")
        end
        println(io, "    Cumulative:     USD $(round(r.cumulative_margin, digits=0))")
        println(io, "    NPV:            USD $(round(r.npv_margin, digits=0))")
        println(io, "")
    end

    # Probability-weighted summary
    dist = calculate_scenario_probability_distribution(results)
    println(io, "──── PROBABILITY-WEIGHTED SUMMARY ─────────────────────────────────")
    println(io, "  Expected NPV:             USD $(round(dist.expected_npv, digits=0))")
    println(io, "  Expected Cumulative:      USD $(round(dist.expected_cumulative_margin, digits=0))")
    println(io, "  Best-Case NPV:            USD $(round(dist.best_case_npv, digits=0))")
    println(io, "  Worst-Case NPV:           USD $(round(dist.worst_case_npv, digits=0))")
    println(io, "  NPV Range:                USD $(round(dist.npv_range, digits=0))")
    println(io, "")

    return String(take!(io))
end
