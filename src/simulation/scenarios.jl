# ============================================================================
# Scenario Comparison Framework for Simulation
# ============================================================================
#
# Provides a structured way to define, run, and compare multiple simulation
# scenarios using any of the available simulation engines (deterministic,
# Monte Carlo, system dynamics, or DES).
# ============================================================================

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    SimulationScenario

A self-contained scenario definition bundling a hospital (or base financials),
simulation parameters, and an optional policy overlay.

# Fields
- `name::String`: short descriptive name.
- `description::String`: longer explanation of the scenario.
- `hospital::Any`: an `AbstractHospital` instance or a `NamedTuple` with base financials.
- `params::AbstractSimulationParams`: engine-specific parameters.
- `policy::Union{PolicyScenario, Nothing}`: optional policy overlay.

# Example
```julia
scenario = SimulationScenario(
    name        = "Baseline CAH",
    description = "Current operations with status-quo policy",
    hospital    = my_cah,
    params      = DeterministicParams(),
    policy      = PolicyScenario(scenario_name="Current Law"),
)
```
"""
@kwdef struct SimulationScenario
    name::String
    description::String = ""
    hospital::Any       # AbstractHospital or NamedTuple with base financials
    params::AbstractSimulationParams
    policy::Union{PolicyScenario, Nothing} = nothing
end

function Base.show(io::IO, s::SimulationScenario)
    engine = typeof(s.params) |> nameof
    has_policy = s.policy !== nothing ? " +policy" : ""
    print(io, "SimulationScenario(\"$(s.name)\", engine=$(engine)$(has_policy))")
end

"""
    ScenarioSet

An ordered collection of scenarios with a designated baseline.

# Fields
- `scenarios::Vector{SimulationScenario}`: the scenarios to run and compare.
- `base_scenario_idx::Int`: 1-based index of the baseline scenario.

# Example
```julia
ss = ScenarioSet(
    scenarios = [baseline, expansion, reh_conversion],
    base_scenario_idx = 1,
)
```
"""
struct ScenarioSet
    scenarios::Vector{SimulationScenario}
    base_scenario_idx::Int

    function ScenarioSet(scenarios::Vector{SimulationScenario}, base_scenario_idx::Int=1)
        isempty(scenarios) && error("ScenarioSet requires at least one scenario")
        1 <= base_scenario_idx <= length(scenarios) ||
            error("base_scenario_idx ($base_scenario_idx) out of range 1:$(length(scenarios))")
        new(scenarios, base_scenario_idx)
    end
end

function Base.show(io::IO, ss::ScenarioSet)
    n = length(ss.scenarios)
    base = ss.scenarios[ss.base_scenario_idx].name
    print(io, "ScenarioSet($(n) scenarios, base=\"$(base)\")")
end

Base.length(ss::ScenarioSet) = length(ss.scenarios)
Base.getindex(ss::ScenarioSet, i::Int) = ss.scenarios[i]
Base.iterate(ss::ScenarioSet) = iterate(ss.scenarios)
Base.iterate(ss::ScenarioSet, state) = iterate(ss.scenarios, state)

# ---------------------------------------------------------------------------
# Engine dispatch
# ---------------------------------------------------------------------------

"""
    _run_single_scenario(scenario::SimulationScenario; engine::Symbol=:deterministic) -> AbstractSimulationResult

Dispatch a single scenario to the appropriate simulation engine.

Supported engines:
- `:deterministic` — requires `DeterministicParams`
- `:des` — requires `DESParams`

For Monte Carlo and system dynamics engines, the scenario's own `params` type
is used for dispatch when the generic `:auto` engine is specified.
"""
function _run_single_scenario(scenario::SimulationScenario;
                              engine::Symbol=:deterministic)
    p = scenario.params

    # Auto-detect engine from params type
    actual_engine = if engine == :auto
        if p isa DESParams
            :des
        else
            :deterministic
        end
    else
        engine
    end

    if actual_engine == :des
        p isa DESParams || error("DES engine requires DESParams, got $(typeof(p))")
        return run_des(p)
    elseif actual_engine == :deterministic
        # Deterministic engine needs a hospital and params
        h = scenario.hospital
        if h isa AbstractHospital
            return project_financials(h, p)
        else
            error("Deterministic engine requires an AbstractHospital, got $(typeof(h))")
        end
    else
        error("Unknown engine: :$(actual_engine). Supported: :deterministic, :des, :auto")
    end
end

# ---------------------------------------------------------------------------
# Batch execution
# ---------------------------------------------------------------------------

"""
    run_scenario_set(scenario_set::ScenarioSet;
                     engine::Symbol=:deterministic) -> Vector{<:AbstractSimulationResult}

Execute every scenario in the set and return a vector of results in the
same order as the input scenarios.

# Arguments
- `scenario_set::ScenarioSet`: the set of scenarios to run.
- `engine::Symbol`: simulation engine to use (`:deterministic`, `:des`, or `:auto`).

# Example
```julia
ss = ScenarioSet([baseline, expansion], 1)
results = run_scenario_set(ss; engine=:des)
for (i, r) in enumerate(results)
    println(ss.scenarios[i].name, ": ", r)
end
```
"""
function run_scenario_set(scenario_set::ScenarioSet;
                          engine::Symbol=:deterministic)
    results = AbstractSimulationResult[]
    for scenario in scenario_set.scenarios
        result = _run_single_scenario(scenario; engine=engine)
        push!(results, result)
    end
    return results
end

# ---------------------------------------------------------------------------
# Comparison bridge
# ---------------------------------------------------------------------------

"""
    compare_scenario_set(results::Vector, scenario_set::ScenarioSet;
                         metrics::Vector{Symbol}=[:operating_margin, :total_revenue, :days_cash_on_hand]) -> ScenarioComparison

Convenience function that bridges `run_scenario_set` output into the
`ScenarioComparison` framework from `analysis/comparison.jl`.

# Arguments
- `results`: vector of simulation results (one per scenario).
- `scenario_set`: the original `ScenarioSet` for metadata.
- `metrics`: which metrics to extract and compare.

# Returns
A `ScenarioComparison` instance ready for ranking and delta analysis.

# Example
```julia
ss = ScenarioSet([baseline, expansion], 1)
results = run_scenario_set(ss; engine=:des)
comparison = compare_scenario_set(results, ss)
ranking = rank_scenarios(comparison)
println("Best: ", comparison.scenario_names[ranking[1]])
```
"""
function compare_scenario_set(results::Vector, scenario_set::ScenarioSet;
                              metrics::Vector{Symbol}=[:operating_margin, :total_revenue, :days_cash_on_hand])
    length(results) == length(scenario_set.scenarios) ||
        error("Number of results ($(length(results))) must match number of scenarios ($(length(scenario_set.scenarios)))")

    names = [s.name for s in scenario_set.scenarios]
    metric_names = String.(metrics)

    n_scen = length(results)
    n_met = length(metrics)
    values = Matrix{Float64}(undef, n_scen, n_met)

    for (i, result) in enumerate(results)
        for (j, metric) in enumerate(metrics)
            values[i, j] = _extract_metric(result, metric)
        end
    end

    return ScenarioComparison(names, metric_names, values, scenario_set.base_scenario_idx)
end
