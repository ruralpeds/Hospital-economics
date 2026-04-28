# ── Cost-Effectiveness Analysis ───────────────────────────────────────────────
#
# Markov cohort models, ICER/dominance, net monetary benefit, DALYs,
# budget impact analysis, decision trees, probabilistic sensitivity analysis,
# and tornado/one-way sensitivity.
#
# Ported from healthcare-finance-julia/src/cost_effectiveness/cea_engine.jl

# ─── Markov Cohort Model ──────────────────────────────────────────────────────

"""
    markov_cohort(transition_matrix, initial_cohort, n_cycles;
                  discount_rate=0.03) -> Matrix{Float64}

Run a discrete-time Markov cohort model.
Returns an (n_cycles+1) × n_states trace matrix where `traces[t, s]` is the
fraction of the cohort in state s at the start of cycle t.

Each row of `transition_matrix` must sum to 1.
"""
function markov_cohort(transition_matrix::Matrix{<:Real},
                        initial_cohort::AbstractVector{<:Real},
                        n_cycles::Integer;
                        discount_rate::Real=0.03)::Matrix{Float64}
    n_states = length(initial_cohort)
    size(transition_matrix) == (n_states, n_states) ||
        throw(ArgumentError(
            "transition_matrix dimensions must match initial_cohort length"))
    n_cycles > 0 || throw(ArgumentError("n_cycles must be positive"))
    for i in 1:n_states
        abs(sum(transition_matrix[i, :]) - 1.0) > 1e-6 &&
            throw(ArgumentError("row $i of transition_matrix does not sum to 1"))
    end
    traces       = zeros(Float64, n_cycles + 1, n_states)
    traces[1, :] = Float64.(initial_cohort)
    for t in 2:(n_cycles + 1)
        traces[t, :] = traces[t-1, :] * transition_matrix
    end
    return traces
end

"""
    markov_cycle_traces(traces, utility_weights; discount_rate=0.03)
        -> Vector{Float64}

Convert Markov cohort traces to discounted QALYs per cycle.
Uses the half-cycle correction (average of start and end of cycle).
"""
function markov_cycle_traces(traces::Matrix{Float64},
                              utility_weights::AbstractVector{<:Real};
                              discount_rate::Real=0.03)::Vector{Float64}
    n_rows, n_states = size(traces)
    n_cycles = n_rows - 1
    length(utility_weights) == n_states ||
        throw(ArgumentError(
            "utility_weights length must match number of Markov states"))
    qaly_per_cycle = Float64[]
    for t in 1:n_cycles
        cohort_in_cycle = (traces[t, :] .+ traces[t+1, :]) ./ 2
        raw_qaly        = dot(cohort_in_cycle, utility_weights)
        push!(qaly_per_cycle, raw_qaly / (1 + discount_rate)^(t - 1))
    end
    return qaly_per_cycle
end

# ─── ICER / Dominance ─────────────────────────────────────────────────────────

"""
    icer(delta_cost, delta_effectiveness) -> Float64

Incremental Cost-Effectiveness Ratio = ΔCost / ΔEffectiveness.
Common threshold: \$50,000–\$150,000 per QALY.
"""
function icer(delta_cost::Real, delta_effectiveness::Real)::Float64
    delta_effectiveness == 0 &&
        throw(ArgumentError(
            "delta_effectiveness is zero — strategies are equally effective"))
    return delta_cost / delta_effectiveness
end

"""
    cea_dominant(cost_a, effect_a, cost_b, effect_b) -> Symbol

Determine dominance between two strategies.
Returns `:a_dominates`, `:b_dominates`, or `:neither`.
"""
function cea_dominant(cost_a::Real, effect_a::Real,
                       cost_b::Real, effect_b::Real)::Symbol
    if cost_a <= cost_b && effect_a >= effect_b
        return :a_dominates
    elseif cost_b <= cost_a && effect_b >= effect_a
        return :b_dominates
    else
        return :neither
    end
end

# ─── Net Monetary Benefit ─────────────────────────────────────────────────────

"""
    net_monetary_benefit(effectiveness, cost, wtp_threshold) -> Float64

NMB = effectiveness × WTP_threshold − cost.
Positive NMB at a given WTP means the intervention is cost-effective.
"""
function net_monetary_benefit(effectiveness::Real, cost::Real,
                               wtp_threshold::Real)::Float64
    wtp_threshold >= 0 ||
        throw(ArgumentError("wtp_threshold must be non-negative"))
    return effectiveness * wtp_threshold - cost
end

"""
    willingness_to_pay_threshold(delta_cost, delta_effectiveness) -> Float64

Maximum WTP at which a more effective strategy remains cost-effective.
"""
function willingness_to_pay_threshold(delta_cost::Real,
                                       delta_effectiveness::Real)::Float64
    delta_effectiveness <= 0 &&
        throw(ArgumentError("delta_effectiveness must be positive"))
    return delta_cost / delta_effectiveness
end

# ─── Outcome Metrics ──────────────────────────────────────────────────────────

"""
    daly(years_life_lost, years_lived_with_disability, disability_weight)
        -> Float64

Disability-Adjusted Life Year = YLL + YLD × disability_weight.
`disability_weight` ∈ [0, 1].
"""
function daly(years_life_lost::Real,
              years_lived_with_disability::Real,
              disability_weight::Real)::Float64
    0 <= disability_weight <= 1 ||
        throw(ArgumentError("disability_weight must be in [0, 1]"))
    return years_life_lost + years_lived_with_disability * disability_weight
end

"""
    life_years_gained(intervention_survival, comparator_survival) -> Float64

Undiscounted life years gained by the intervention vs. comparator.
"""
function life_years_gained(intervention_survival::Real,
                            comparator_survival::Real)::Float64
    return Float64(intervention_survival - comparator_survival)
end

"""
    qaly_adjusted_life_years(life_years, utility_weight) -> Float64

QALYs = life_years × utility_weight.
`utility_weight` ∈ [0, 1] (0 = death, 1 = full health).
"""
function qaly_adjusted_life_years(life_years::Real, utility_weight::Real)::Float64
    0 <= utility_weight <= 1 ||
        throw(ArgumentError("utility_weight must be in [0, 1]"))
    return life_years * utility_weight
end

# ─── Budget Impact Analysis ───────────────────────────────────────────────────

"""
    budget_impact_analysis(eligible_population, uptake_rate, new_therapy_cost,
                           current_therapy_cost, current_market_share;
                           horizon_years=3) -> NamedTuple

Estimate the budget impact of a new therapy introduction over a multi-year horizon.
Models market share shifting linearly from `current_market_share` by `uptake_rate`
per year. Returns `(annual_impacts, cumulative_impact, horizon_years)`.
"""
function budget_impact_analysis(eligible_population::Real,
                                 uptake_rate::Real,
                                 new_therapy_cost::Real,
                                 current_therapy_cost::Real,
                                 current_market_share::Real;
                                 horizon_years::Integer=3)
    0 <= uptake_rate <= 1 ||
        throw(ArgumentError("uptake_rate must be in [0, 1]"))
    0 <= current_market_share <= 1 ||
        throw(ArgumentError("current_market_share must be in [0, 1]"))
    horizon_years > 0 || throw(ArgumentError("horizon_years must be positive"))
    annual_impacts = Float64[]
    for yr in 1:horizon_years
        new_share       = min(1.0, current_market_share + uptake_rate * yr)
        old_share       = 1 - new_share
        new_cost_total  = eligible_population * new_share * new_therapy_cost
        old_cost_total  = eligible_population * old_share * current_therapy_cost
        counterfactual  = eligible_population * current_therapy_cost
        push!(annual_impacts, (new_cost_total + old_cost_total) - counterfactual)
    end
    return (annual_impacts=annual_impacts,
            cumulative_impact=sum(annual_impacts),
            horizon_years=horizon_years)
end

# ─── Decision Tree ────────────────────────────────────────────────────────────

"""
    decision_tree_ev(outcomes, probabilities) -> Float64

Decision tree expected value = dot(outcomes, probabilities).
`probabilities` must sum to 1.
"""
function decision_tree_ev(outcomes::AbstractVector{<:Real},
                           probabilities::AbstractVector{<:Real})::Float64
    length(outcomes) == length(probabilities) ||
        throw(ArgumentError("outcomes and probabilities must have the same length"))
    abs(sum(probabilities) - 1.0) > 1e-6 &&
        throw(ArgumentError("probabilities must sum to 1"))
    return dot(outcomes, probabilities)
end

# ─── Probabilistic Sensitivity Analysis ──────────────────────────────────────

"""
    probabilistic_sensitivity_analysis(cost_sampler, effect_sampler,
                                       n_simulations; wtp_threshold=50_000.0)
        -> NamedTuple

Monte Carlo PSA: sample cost and effectiveness differences, compute ICERs and NMBs.
Returns `(icers, nmbs, mean_icer, fraction_cost_effective)`.
"""
function probabilistic_sensitivity_analysis(cost_sampler::Function,
                                             effect_sampler::Function,
                                             n_simulations::Integer;
                                             wtp_threshold::Real=50_000.0)
    n_simulations > 0 || throw(ArgumentError("n_simulations must be positive"))
    icers = Float64[]
    nmbs  = Float64[]
    for _ in 1:n_simulations
        dc = cost_sampler()
        de = effect_sampler()
        push!(nmbs, net_monetary_benefit(de, dc, wtp_threshold))
        de != 0 && push!(icers, dc / de)
    end
    frac_ce = count(x -> x > 0, nmbs) / n_simulations
    return (icers=icers, nmbs=nmbs,
            mean_icer=isempty(icers) ? NaN : mean(icers),
            fraction_cost_effective=frac_ce)
end

# ─── Tornado / One-Way Sensitivity ───────────────────────────────────────────

"""
    tornado_diagram_inputs(base_icer, parameter_ranges, icer_function)
        -> Vector{NamedTuple}

One-way sensitivity analysis. For each parameter, compute ICER at low and high
values and record the swing (range). Returns sorted by swing descending.

`parameter_ranges`: Dict of `"param_name" => (low_value, high_value)`.
`icer_function(param_name, value) -> Float64`.
"""
function tornado_diagram_inputs(base_icer::Real,
                                 parameter_ranges::Dict{String,Tuple{Float64,Float64}},
                                 icer_function::Function)
    results = NamedTuple[]
    for (param, (low, high)) in parameter_ranges
        icer_low  = icer_function(param, low)
        icer_high = icer_function(param, high)
        push!(results, (parameter=param, low_icer=icer_low,
                        high_icer=icer_high,
                        swing=abs(icer_high - icer_low)))
    end
    return sort(results; by=r -> r.swing, rev=true)
end
