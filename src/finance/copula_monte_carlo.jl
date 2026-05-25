using LinearAlgebra
using Random
using Statistics

# Gaussian Copula Monte Carlo Simulation
#
# Generates correlated random samples using a Gaussian copula:
# 1. Cholesky decomposition of the correlation matrix
# 2. Generate independent standard normals
# 3. Correlate via the Cholesky factor
# 4. Transform to uniform via Φ (standard normal CDF)
# 5. Transform to target marginal distributions via inverse CDF

"""
    CopulaInput

Input parameters for Gaussian copula Monte Carlo simulation.

Fields:
- `n_simulations` — number of samples to generate
- `marginal_params` — vector of (mean, std) tuples for each marginal distribution
- `correlation_matrix` — positive-definite correlation matrix
- `random_seed` — RNG seed for reproducibility (default 42)
"""
@kwdef struct CopulaInput
    n_simulations::Int
    marginal_params::Vector{Tuple{Float64,Float64}}  # (mean, std) per variable
    correlation_matrix::Matrix{Float64}
    random_seed::Int = 42
end

"""
    CopulaResult

Result of Gaussian copula simulation.

Fields:
- `samples` — n_simulations × n_variables matrix of correlated samples
- `empirical_correlation` — observed correlation matrix of generated samples
- `summary_stats` — per-variable summary: mean, std, min, max
"""
@kwdef struct CopulaResult
    samples::Matrix{Float64}
    empirical_correlation::Matrix{Float64}
    summary_stats::Vector{NamedTuple}
end

function Base.show(io::IO, r::CopulaResult)
    n, d = size(r.samples)
    print(io, "CopulaResult($(n) samples × $(d) variables)")
end

"""
    _copula_normal_cdf(x::Float64) -> Float64

Standard normal CDF for copula transform (Abramowitz & Stegun approximation).
"""
function _copula_normal_cdf(x::Float64)::Float64
    a1 = 0.254829592
    a2 = -0.284496736
    a3 = 1.421413741
    a4 = -1.453152027
    a5 = 1.061405429
    p = 0.3275911

    sign = x < 0.0 ? -1.0 : 1.0
    x_abs = abs(x)
    t = 1.0 / (1.0 + p * x_abs)
    y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-x_abs^2 / 2.0)
    return 0.5 * (1.0 + sign * y)
end

"""
    _copula_normal_inv(u::Float64) -> Float64

Inverse standard normal CDF (rational approximation by Peter Acklam).
"""
function _copula_normal_inv(u::Float64)::Float64
    # Coefficients for rational approximation
    a = [-3.969683028665376e+01, 2.209460984245205e+02,
         -2.759285104469687e+02, 1.383577518672690e+02,
         -3.066479806614716e+01, 2.506628277459239e+00]
    b = [-5.447609879822406e+01, 1.615858368580409e+02,
         -1.556989798598866e+02, 6.680131188771972e+01,
         -1.328068155288572e+01]
    c = [-7.784894002430293e-03, -3.223964580411365e-01,
         -2.400758277161838e+00, -2.549732539343734e+00,
          4.374664141464968e+00, 2.938163982698783e+00]
    d = [7.784695709041462e-03, 3.224671290700398e-01,
         2.445134137142996e+00, 3.754408661907416e+00]

    p_low = 0.02425
    p_high = 1.0 - p_low

    if u < p_low
        q = sqrt(-2.0 * log(u))
        return (((((c[1]*q + c[2])*q + c[3])*q + c[4])*q + c[5])*q + c[6]) /
                ((((d[1]*q + d[2])*q + d[3])*q + d[4])*q + 1.0)
    elseif u <= p_high
        q = u - 0.5
        r = q * q
        return (((((a[1]*r + a[2])*r + a[3])*r + a[4])*r + a[5])*r + a[6]) * q /
               (((((b[1]*r + b[2])*r + b[3])*r + b[4])*r + b[5])*r + 1.0)
    else
        q = sqrt(-2.0 * log(1.0 - u))
        return -(((((c[1]*q + c[2])*q + c[3])*q + c[4])*q + c[5])*q + c[6]) /
                 ((((d[1]*q + d[2])*q + d[3])*q + d[4])*q + 1.0)
    end
end

"""
    generate_copula_samples(input::CopulaInput) -> CopulaResult

Generate correlated random samples using a Gaussian copula.

Algorithm:
1. Cholesky decomposition of correlation matrix → L
2. Generate independent standard normals Z
3. Correlated normals: Y = L * Z
4. Transform to uniform: U = Φ(Y)
5. Transform to target marginals: X = μ + σ * Φ⁻¹(U) = μ + σ * Y
   (for normal marginals, step 4-5 simplify to X = μ + σ * Y)
"""
function generate_copula_samples(input::CopulaInput)::CopulaResult
    input.n_simulations > 0 || error("n_simulations must be positive")
    d = length(input.marginal_params)
    d > 0 || error("must specify at least one marginal distribution")
    size(input.correlation_matrix) == (d, d) || error("correlation_matrix must be $(d)×$(d)")

    # Validate correlation matrix symmetry
    for i in 1:d, j in 1:d
        abs(input.correlation_matrix[i, j] - input.correlation_matrix[j, i]) < 1e-10 ||
            error("correlation_matrix must be symmetric")
    end

    # Cholesky decomposition
    C = copy(input.correlation_matrix)
    L = try
        cholesky(Hermitian(C)).L
    catch
        error("correlation_matrix must be positive definite")
    end

    rng = MersenneTwister(input.random_seed)

    # Generate independent standard normals and correlate
    Z = randn(rng, d, input.n_simulations)  # d × n
    Y = L * Z  # d × n — correlated normals

    # Transform to target marginals (normal marginals)
    samples = Matrix{Float64}(undef, input.n_simulations, d)
    for j in 1:d
        μ, σ = input.marginal_params[j]
        for i in 1:input.n_simulations
            samples[i, j] = μ + σ * Y[j, i]
        end
    end

    # Empirical correlation
    emp_corr = cor(samples)

    # Summary statistics
    stats = NamedTuple[]
    for j in 1:d
        col = samples[:, j]
        push!(stats, (
            variable = j,
            mean = mean(col),
            std = std(col),
            min = minimum(col),
            max = maximum(col),
        ))
    end

    return CopulaResult(
        samples = samples,
        empirical_correlation = emp_corr,
        summary_stats = stats,
    )
end
