# ============================================================================
# Sensitivity Analysis
# ============================================================================

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    SensitivityResult

Result of a one-at-a-time sensitivity analysis for a single parameter.

# Fields
- `parameter_name::String`: name of the varied parameter
- `base_value::Float64`: original value of the parameter
- `low_value::Float64`: lower-bound perturbation value
- `high_value::Float64`: upper-bound perturbation value
- `base_outcome::Float64`: model outcome at base value
- `low_outcome::Float64`: model outcome at low value
- `high_outcome::Float64`: model outcome at high value
- `swing::Float64`: absolute spread between low and high outcomes
"""
struct SensitivityResult
    parameter_name::String
    base_value::Float64
    low_value::Float64
    high_value::Float64
    base_outcome::Float64
    low_outcome::Float64
    high_outcome::Float64
    swing::Float64
end

# ---------------------------------------------------------------------------
# Core sensitivity analysis
# ---------------------------------------------------------------------------

"""
    run_sensitivity_analysis(model_fn::Function,
                             base_params::Dict{String,Float64};
                             perturbation::Float64=0.10,
                             outcome_name::String="outcome") -> Vector{SensitivityResult}

Perform a one-at-a-time (OAT) sensitivity analysis by perturbing each
parameter independently while holding all others at their base values.

# Arguments
- `model_fn`: a function that accepts a `Dict{String,Float64}` of parameters
  and returns a scalar `Float64` outcome
- `base_params`: dictionary of parameter names to their base-case values
- `perturbation`: fractional perturbation (default ±10%)
- `outcome_name`: label for the outcome metric (for reporting)

# Returns
A vector of `SensitivityResult`, one per parameter, sorted by descending
swing (most sensitive parameters first).
"""
function run_sensitivity_analysis(model_fn::Function,
                                  base_params::Dict{String,Float64};
                                  perturbation::Float64=0.10,
                                  outcome_name::String="outcome")
    base_outcome = model_fn(base_params)
    results = SensitivityResult[]

    for (param_name, base_val) in base_params
        # Perturb down
        low_val = base_val * (1.0 - perturbation)
        low_params = copy(base_params)
        low_params[param_name] = low_val
        low_outcome = model_fn(low_params)

        # Perturb up
        high_val = base_val * (1.0 + perturbation)
        high_params = copy(base_params)
        high_params[param_name] = high_val
        high_outcome = model_fn(high_params)

        swing = abs(high_outcome - low_outcome)

        push!(results, SensitivityResult(
            param_name,
            base_val,
            low_val,
            high_val,
            base_outcome,
            low_outcome,
            high_outcome,
            swing,
        ))
    end

    # Sort by descending swing
    sort!(results; by=r -> r.swing, rev=true)
    return results
end

# ---------------------------------------------------------------------------
# Tornado diagram data
# ---------------------------------------------------------------------------

"""
    TornadoBar

Data for a single bar in a tornado diagram.
"""
struct TornadoBar
    parameter::String
    low_delta::Float64
    high_delta::Float64
    base_outcome::Float64
end

"""
    build_tornado_data(results::Vector{SensitivityResult};
                       top_n::Int=10) -> Vector{TornadoBar}

Convert sensitivity analysis results into data suitable for rendering
a tornado diagram.

# Arguments
- `results`: output from `run_sensitivity_analysis`
- `top_n`: number of top parameters to include (default 10)

# Returns
A vector of `TornadoBar` structs ordered by descending swing, each
containing the delta from the base outcome for low and high perturbations.
"""
function build_tornado_data(results::Vector{SensitivityResult};
                            top_n::Int=10)
    n = min(top_n, length(results))
    bars = TornadoBar[]

    for i in 1:n
        r = results[i]
        low_delta = r.low_outcome - r.base_outcome
        high_delta = r.high_outcome - r.base_outcome

        push!(bars, TornadoBar(
            r.parameter_name,
            low_delta,
            high_delta,
            r.base_outcome,
        ))
    end

    return bars
end
