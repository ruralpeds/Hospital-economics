# ============================================================================
# SCENARIO MODELS (Module 7)
# ============================================================================
# Healthcare scenario definitions for multi-scenario financial evaluation.
# Provides typed scenario structures, validation, and standard scenario sets
# (optimistic, base-case, pessimistic) used across outcome projection,
# contract optimization, and risk analysis.
# ============================================================================

# ============================================================================
# SCENARIO TYPE
# ============================================================================

"""
    HealthcareScenario

A self-contained description of a future operating environment for a hospital
or health system.  Each scenario bundles assumptions about volume, cost,
reimbursement, quality performance, and payer-mix that drive financial
projections.

# Fields
- `id::String`: unique machine-readable identifier (e.g., `"base_2026"`)
- `name::String`: human-readable label
- `description::String`: narrative description of the scenario
- `probability::Float64`: subjective probability weight (0.0-1.0)
- `volume_growth_rate::Float64`: annual patient volume growth rate (e.g., 0.02 = +2 %)
- `cost_inflation_rate::Float64`: annual cost inflation (e.g., 0.035 = 3.5 %)
- `reimbursement_change_rate::Float64`: annual change in average reimbursement
- `quality_score_adjustment::Float64`: additive shift to baseline quality score (e.g., +0.05)
- `payer_mix_shift::Dict{String,Float64}`: payer -> fraction delta (positive = more of that payer)
- `policy_impact::Float64`: net revenue impact from regulatory / policy changes (USD)
- `projection_years::Int`: number of years to project (default 3)
- `discount_rate::Float64`: annual discount rate for NPV calculations
"""
struct HealthcareScenario
    id::String
    name::String
    description::String
    probability::Float64

    # Operating assumptions
    volume_growth_rate::Float64
    cost_inflation_rate::Float64
    reimbursement_change_rate::Float64
    quality_score_adjustment::Float64
    payer_mix_shift::Dict{String,Float64}
    policy_impact::Float64

    # Projection parameters
    projection_years::Int
    discount_rate::Float64
end

function HealthcareScenario(;
    id::String = "custom",
    name::String = "Custom Scenario",
    description::String = "",
    probability::Float64 = 1.0,
    volume_growth_rate::Float64 = 0.0,
    cost_inflation_rate::Float64 = 0.03,
    reimbursement_change_rate::Float64 = 0.02,
    quality_score_adjustment::Float64 = 0.0,
    payer_mix_shift::Dict{String,Float64} = Dict{String,Float64}(),
    policy_impact::Float64 = 0.0,
    projection_years::Int = 3,
    discount_rate::Float64 = 0.03
)
    HealthcareScenario(
        id, name, description, probability,
        volume_growth_rate, cost_inflation_rate, reimbursement_change_rate,
        quality_score_adjustment, payer_mix_shift, policy_impact,
        projection_years, discount_rate
    )
end

function Base.show(io::IO, s::HealthcareScenario)
    print(io, "HealthcareScenario(\"$(s.name)\", p=$(s.probability), yrs=$(s.projection_years))")
end

# ============================================================================
# VALIDATION
# ============================================================================

"""
    validate_scenario(scenario::HealthcareScenario)::Vector{String}

Validate a single `HealthcareScenario`, returning a vector of error messages.
An empty vector means the scenario is valid.

# Checks performed
- `probability` is in [0, 1]
- `projection_years` >= 1
- `discount_rate` >= 0
- `volume_growth_rate` within plausible bounds (-0.30 to 0.30)
- `cost_inflation_rate` within plausible bounds (-0.10 to 0.30)
- payer mix shift fractions each in [-1, 1]
"""
function validate_scenario(scenario::HealthcareScenario)::Vector{String}
    errors = String[]

    if scenario.probability < 0.0 || scenario.probability > 1.0
        push!(errors, "probability must be in [0, 1], got $(scenario.probability)")
    end

    if scenario.projection_years < 1
        push!(errors, "projection_years must be >= 1, got $(scenario.projection_years)")
    end

    if scenario.discount_rate < 0.0
        push!(errors, "discount_rate must be >= 0, got $(scenario.discount_rate)")
    end

    if scenario.volume_growth_rate < -0.30 || scenario.volume_growth_rate > 0.30
        push!(errors, "volume_growth_rate $(scenario.volume_growth_rate) outside plausible range [-0.30, 0.30]")
    end

    if scenario.cost_inflation_rate < -0.10 || scenario.cost_inflation_rate > 0.30
        push!(errors, "cost_inflation_rate $(scenario.cost_inflation_rate) outside plausible range [-0.10, 0.30]")
    end

    for (payer, shift) in scenario.payer_mix_shift
        if shift < -1.0 || shift > 1.0
            push!(errors, "payer_mix_shift[\"$payer\"] = $shift outside [-1, 1]")
        end
    end

    return errors
end

"""
    validate_scenario_set(scenarios::Vector{HealthcareScenario})::Vector{String}

Validate a collection of scenarios.  In addition to per-scenario checks,
verifies that probabilities sum to approximately 1.0 (within tolerance 0.01)
and that all scenario `id` values are unique.
"""
function validate_scenario_set(scenarios::Vector{HealthcareScenario})::Vector{String}
    errors = String[]

    if isempty(scenarios)
        push!(errors, "scenario set must contain at least one scenario")
        return errors
    end

    # Per-scenario validation
    for (i, s) in enumerate(scenarios)
        for msg in validate_scenario(s)
            push!(errors, "scenario[$i] ($(s.id)): $msg")
        end
    end

    # Probability sum check
    prob_sum = sum(s.probability for s in scenarios)
    if abs(prob_sum - 1.0) > 0.01
        push!(errors, "scenario probabilities sum to $(round(prob_sum, digits=4)); expected ~1.0")
    end

    # Unique IDs
    ids = [s.id for s in scenarios]
    if length(unique(ids)) != length(ids)
        push!(errors, "duplicate scenario ids detected: $(ids)")
    end

    return errors
end

# ============================================================================
# DEFAULT SCENARIOS
# ============================================================================

"""
    SCENARIO_OPTIMISTIC

Pre-built optimistic scenario: strong volume growth, moderate inflation,
improving quality, and favourable reimbursement trends.
"""
const SCENARIO_OPTIMISTIC = HealthcareScenario(
    id = "optimistic",
    name = "Optimistic",
    description = "Strong volume growth, moderate cost inflation, improving quality scores, and favorable reimbursement environment.",
    probability = 0.25,
    volume_growth_rate = 0.04,
    cost_inflation_rate = 0.025,
    reimbursement_change_rate = 0.035,
    quality_score_adjustment = 0.05,
    payer_mix_shift = Dict("Commercial" => 0.03, "Medicare" => -0.01, "Medicaid" => -0.02),
    policy_impact = 200_000.0,
    projection_years = 3,
    discount_rate = 0.03,
)

"""
    SCENARIO_BASE

Pre-built base-case scenario: trend-line volume, typical inflation, stable
quality, and neutral reimbursement.
"""
const SCENARIO_BASE = HealthcareScenario(
    id = "base",
    name = "Base Case",
    description = "Trend-line volume growth, typical medical cost inflation, stable quality performance, and neutral reimbursement changes.",
    probability = 0.50,
    volume_growth_rate = 0.02,
    cost_inflation_rate = 0.035,
    reimbursement_change_rate = 0.025,
    quality_score_adjustment = 0.0,
    payer_mix_shift = Dict{String,Float64}(),
    policy_impact = 0.0,
    projection_years = 3,
    discount_rate = 0.03,
)

"""
    SCENARIO_PESSIMISTIC

Pre-built pessimistic scenario: declining volume, high inflation, quality
degradation, and adverse reimbursement cuts.
"""
const SCENARIO_PESSIMISTIC = HealthcareScenario(
    id = "pessimistic",
    name = "Pessimistic",
    description = "Declining patient volume, elevated cost inflation, quality score degradation, and reimbursement cuts.",
    probability = 0.25,
    volume_growth_rate = -0.02,
    cost_inflation_rate = 0.05,
    reimbursement_change_rate = 0.01,
    quality_score_adjustment = -0.05,
    payer_mix_shift = Dict("Commercial" => -0.03, "Medicare" => 0.01, "Medicaid" => 0.02),
    policy_impact = -300_000.0,
    projection_years = 3,
    discount_rate = 0.03,
)

"""
    get_default_scenarios()::Vector{HealthcareScenario}

Return the standard three-scenario set (optimistic, base, pessimistic) with
probabilities summing to 1.0.
"""
function get_default_scenarios()::Vector{HealthcareScenario}
    return [SCENARIO_OPTIMISTIC, SCENARIO_BASE, SCENARIO_PESSIMISTIC]
end

"""
    get_scenario_by_id(scenarios::Vector{HealthcareScenario}, id::String)::Union{HealthcareScenario, Nothing}

Look up a scenario by its `id` field.  Returns `nothing` if not found.
"""
function get_scenario_by_id(scenarios::Vector{HealthcareScenario}, id::String)::Union{HealthcareScenario, Nothing}
    idx = findfirst(s -> s.id == id, scenarios)
    return idx === nothing ? nothing : scenarios[idx]
end
