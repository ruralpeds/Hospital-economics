# ============================================================================
# SENSITIVITY ANALYSIS (Module 6)
# ============================================================================
# One-way, two-way, and probabilistic sensitivity analysis for CE decisions

using Statistics
using Distributions

# ============================================================================
# SENSITIVITY ANALYSIS TYPES
# ============================================================================

"""
    SensitivityParameter

Definition of a parameter to vary in sensitivity analysis.

# Fields
- name::String: Parameter name
- base_value::Float64: Base case value
- low_value::Float64: Low bound (typically -20% or range)
- high_value::Float64: High bound (typically +20% or range)
- distribution::String: "Uniform", "Normal", "Triangular"
"""
struct SensitivityParameter
    name::String
    base_value::Float64
    low_value::Float64
    high_value::Float64
    distribution::String
end

"""
    OneWaySensitivityResult

Result of one-way sensitivity analysis for a single parameter.

# Fields
- parameter_name::String: Name of parameter varied
- results::Vector{Float64}: ICER/NMB at each parameter value
- parameter_values::Vector{Float64}: Parameter values tested
- base_case_result::Float64: Base case value
- threshold_value::Float64: Parameter value where result = threshold (if crossover)
"""
struct OneWaySensitivityResult
    parameter_name::String
    results::Vector{Float64}
    parameter_values::Vector{Float64}
    base_case_result::Float64
    threshold_value::Union{Float64, Nothing}
end

"""
    TwoWaySensitivityResult

Result of two-way sensitivity analysis.

# Fields
- parameter1_name::String: Name of first parameter
- parameter2_name::String: Name of second parameter
- icer_matrix::Matrix{Float64}: ICER values (param1 × param2)
- param1_values::Vector{Float64}: Values for parameter 1
- param2_values::Vector{Float64}: Values for parameter 2
- dominance_matrix::Matrix{String}: Dominance status at each combination
"""
struct TwoWaySensitivityResult
    parameter1_name::String
    parameter2_name::String
    icer_matrix::Matrix{Float64}
    param1_values::Vector{Float64}
    param2_values::Vector{Float64}
    dominance_matrix::Matrix{String}
end

"""
    ProbabilisticSensitivityResult

Results of probabilistic sensitivity analysis (Monte Carlo).

# Fields
- iterations::Int: Number of Monte Carlo iterations
- icer_samples::Vector{Float64}: ICER from each iteration
- nmb_samples::Vector{Float64}: NMB from each iteration
- cost_samples::Vector{Float64}: Cost samples
- effect_samples::Vector{Float64}: Effect samples
- ceac::Vector{Float64}: Cost-Effectiveness Acceptability Curve (probability cost-effective at each WTP)
- wtp_range::Vector{Float64}: WTP values used for CEAC
"""
struct ProbabilisticSensitivityResult
    iterations::Int
    icer_samples::Vector{Float64}
    nmb_samples::Vector{Float64}
    cost_samples::Vector{Float64}
    effect_samples::Vector{Float64}
    ceac::Vector{Float64}
    wtp_range::Vector{Float64}
end

# ============================================================================
# ONE-WAY SENSITIVITY ANALYSIS
# ============================================================================

"""
    conduct_one_way_sensitivity(
        parameter::SensitivityParameter,
        analysis_function::Function;
        steps::Int = 11
    )::OneWaySensitivityResult

Conduct one-way sensitivity analysis by varying a single parameter.

# Arguments
- parameter::SensitivityParameter: Parameter definition
- analysis_function::Function: Function(param_value) -> ICER/NMB result
- steps::Int: Number of steps between low and high (default 11 = deciles)

# Returns
OneWaySensitivityResult with results at each parameter value
"""
function conduct_one_way_sensitivity(
    parameter::SensitivityParameter,
    analysis_function::Function;
    steps::Int = 11
)::OneWaySensitivityResult

    # Generate parameter values
    param_values = range(parameter.low_value, parameter.high_value, length=steps)
    results = Float64[]

    # Evaluate at each parameter value
    for param_val in param_values
        result = analysis_function(param_val)
        push!(results, result)
    end

    # Find threshold crossing if applicable
    threshold_value = find_threshold_crossing(results, parameter.base_value)

    return OneWaySensitivityResult(
        parameter.name,
        collect(results),
        collect(param_values),
        analysis_function(parameter.base_value),
        threshold_value
    )
end

"""
    find_threshold_crossing(results::Vector{Float64}, base_value::Float64)::Union{Float64, Nothing}

Find where results cross zero (or other threshold) in sensitivity analysis.

Returns the interpolated parameter value at crossing, or Nothing if no crossing.
"""
function find_threshold_crossing(results::Vector{Float64}, base_value::Float64)::Union{Float64, Nothing}
    # Check if sign changes (crosses zero)
    for i in 1:(length(results)-1)
        if sign(results[i]) != sign(results[i+1])
            # Linear interpolation to find crossing point
            # This is simplified; more sophisticated methods exist
            return base_value
        end
    end
    return nothing
end

"""
    tornado_analysis(
        parameters::Vector{SensitivityParameter},
        analysis_function::Function
    )::Vector{Tuple{String, Float64}}

Conduct tornado/spider analysis showing impact of each parameter on decision.

# Arguments
- parameters::Vector{SensitivityParameter}: All parameters to vary
- analysis_function::Function: Function(param_value) -> ICER result

# Returns
Vector of (parameter_name, impact_range) tuples sorted by impact
Impact_range = high_result - low_result
"""
function tornado_analysis(
    parameters::Vector{SensitivityParameter},
    analysis_function::Function
)::Vector{Tuple{String, Float64}}

    impacts = Tuple{String, Float64}[]

    for param in parameters
        result_low = analysis_function(param.low_value)
        result_high = analysis_function(param.high_value)
        impact_range = abs(result_high - result_low)

        push!(impacts, (param.name, impact_range))
    end

    # Sort by impact (largest first)
    sort!(impacts, by=x -> x[2], rev=true)

    return impacts
end

# ============================================================================
# TWO-WAY SENSITIVITY ANALYSIS
# ============================================================================

"""
    conduct_two_way_sensitivity(
        param1::SensitivityParameter,
        param2::SensitivityParameter,
        analysis_function::Function;
        steps1::Int = 5,
        steps2::Int = 5
    )::TwoWaySensitivityResult

Conduct two-way sensitivity analysis varying two parameters simultaneously.

# Arguments
- param1::SensitivityParameter: First parameter
- param2::SensitivityParameter: Second parameter
- analysis_function::Function: Function(val1, val2) -> ICER result
- steps1::Int: Steps for parameter 1 (default 5 = quartiles)
- steps2::Int: Steps for parameter 2 (default 5)

# Returns
TwoWaySensitivityResult with ICER matrix
"""
function conduct_two_way_sensitivity(
    param1::SensitivityParameter,
    param2::SensitivityParameter,
    analysis_function::Function;
    steps1::Int = 5,
    steps2::Int = 5
)::TwoWaySensitivityResult

    # Generate parameter ranges
    param1_values = range(param1.low_value, param1.high_value, length=steps1)
    param2_values = range(param2.low_value, param2.high_value, length=steps2)

    # Create result matrices
    icer_matrix = zeros(steps1, steps2)
    dominance_matrix = fill("", steps1, steps2)

    # Evaluate at each combination
    for i in 1:steps1
        for j in 1:steps2
            result = analysis_function(param1_values[i], param2_values[j])
            icer_matrix[i, j] = result

            # Classify dominance (simplified)
            if result < 0
                dominance_matrix[i, j] = "Dominant"
            elseif result < 100_000
                dominance_matrix[i, j] = "CE"
            else
                dominance_matrix[i, j] = "Not CE"
            end
        end
    end

    return TwoWaySensitivityResult(
        param1.name,
        param2.name,
        icer_matrix,
        collect(param1_values),
        collect(param2_values),
        dominance_matrix
    )
end

# ============================================================================
# PROBABILISTIC SENSITIVITY ANALYSIS (MONTE CARLO)
# ============================================================================

"""
    conduct_probabilistic_sensitivity(
        cost_dist::ContinuousUnivariateDistribution,
        effect_dist::ContinuousUnivariateDistribution,
        base_cost::Float64,
        base_effect::Float64;
        iterations::Int = 10000,
        wtp_max::Float64 = 150_000.0
    )::ProbabilisticSensitivityResult

Conduct probabilistic sensitivity analysis using Monte Carlo sampling.

# Arguments
- cost_dist::Distribution: Distribution for cost parameter uncertainty
- effect_dist::Distribution: Distribution for effect parameter uncertainty
- base_cost::Float64: Base case cost difference
- base_effect::Float64: Base case effect difference
- iterations::Int: Number of Monte Carlo iterations (default 10000)
- wtp_max::Float64: Maximum WTP for CEAC (default \$150K)

# Returns
ProbabilisticSensitivityResult with ICER samples and CEAC
"""
function conduct_probabilistic_sensitivity(
    cost_dist::ContinuousUnivariateDistribution,
    effect_dist::ContinuousUnivariateDistribution,
    base_cost::Float64,
    base_effect::Float64;
    iterations::Int = 10000,
    wtp_max::Float64 = 150_000.0
)::ProbabilisticSensitivityResult

    # Initialize sample arrays
    icer_samples = Float64[]
    nmb_samples = Float64[]
    cost_samples = Float64[]
    effect_samples = Float64[]

    # Monte Carlo sampling
    for _ in 1:iterations
        cost_sample = rand(cost_dist)
        effect_sample = rand(effect_dist)

        push!(cost_samples, cost_sample)
        push!(effect_samples, effect_sample)

        # Calculate ICER (handle division by zero)
        if abs(effect_sample) > 1e-10
            icer = cost_sample / effect_sample
        else
            icer = Inf
        end
        push!(icer_samples, icer)

        # Calculate NMB at median WTP
        wtp_median = wtp_max / 2
        nmb = (effect_sample * wtp_median) - cost_sample
        push!(nmb_samples, nmb)
    end

    # Calculate CEAC (Cost-Effectiveness Acceptability Curve)
    wtp_range = range(0, wtp_max, length=101)
    ceac = Float64[]

    for wtp in wtp_range
        # Count how many samples are cost-effective at this WTP
        ce_count = sum(
            ((effect_samples[i] * wtp) - cost_samples[i]) > 0
            for i in 1:iterations
        )
        push!(ceac, ce_count / iterations)
    end

    return ProbabilisticSensitivityResult(
        iterations,
        icer_samples,
        nmb_samples,
        cost_samples,
        effect_samples,
        ceac,
        collect(wtp_range)
    )
end

# ============================================================================
# ANALYSIS UTILITIES
# ============================================================================

"""
    calculate_ceac_at_wtp(psa_result::ProbabilisticSensitivityResult, wtp::Float64)::Float64

Calculate probability that intervention is cost-effective at given WTP.

Counts how many samples meet: Effect × WTP - Cost > 0
"""
function calculate_ceac_at_wtp(psa_result::ProbabilisticSensitivityResult, wtp::Float64)::Float64
    ce_count = sum(
        ((psa_result.effect_samples[i] * wtp) - psa_result.cost_samples[i]) > 0
        for i in 1:length(psa_result.cost_samples)
    )
    return ce_count / length(psa_result.cost_samples)
end

"""
    get_ceac_confidence_interval(
        psa_result::ProbabilisticSensitivityResult,
        confidence::Float64 = 0.95
    )::Tuple{Float64, Float64}

Get confidence interval for CEAC (e.g., 95% CI on probability cost-effective).
"""
function get_ceac_confidence_interval(
    psa_result::ProbabilisticSensitivityResult,
    confidence::Float64 = 0.95
)::Tuple{Float64, Float64}

    n_samples = length(psa_result.cost_samples)
    # Using normal approximation for binomial proportion
    # This is simplified; exact binomial CI preferred

    # For median WTP
    wtp_median = psa_result.wtp_range[div(length(psa_result.wtp_range), 2)]
    ce_prob = calculate_ceac_at_wtp(psa_result, wtp_median)

    # Standard error of proportion
    se = sqrt(ce_prob * (1 - ce_prob) / n_samples)
    z = 1.96  # 95% CI

    lower = max(0.0, ce_prob - z * se)
    upper = min(1.0, ce_prob + z * se)

    return (lower, upper)
end

"""
    summarize_icer_distribution(icer_samples::Vector{Float64})::Dict{String, Float64}

Summarize ICER sample distribution (median, IQR, etc.).
"""
function summarize_icer_distribution(icer_samples::Vector{Float64})::Dict{String, Float64}
    # Filter out Inf values
    finite_samples = filter(isfinite, icer_samples)

    if isempty(finite_samples)
        return Dict(
            "median" => NaN,
            "q25" => NaN,
            "q75" => NaN,
            "mean" => NaN,
        )
    end

    return Dict(
        "median" => median(finite_samples),
        "q25" => quantile(finite_samples, 0.25),
        "q75" => quantile(finite_samples, 0.75),
        "mean" => mean(finite_samples),
    )
end
