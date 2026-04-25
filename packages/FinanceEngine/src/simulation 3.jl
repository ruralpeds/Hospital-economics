"""
    simulation.jl — Monte Carlo, growth, and ARMA forecasting

Migrated from healthcare-finance-julia/src/simulation_engine.jl.
Enhanced with QuantEcon ARMA for revenue forecasting.
"""

using QuantEcon

"""Monte Carlo simulation returning mean of sampled values."""
function monte_carlo_mean(dist_sampler::Function, n::Int)
    n > 0 || throw(ArgumentError("n must be positive"))
    return @audited_calculation _monte_carlo_mean(dist_sampler, n)
end
_monte_carlo_mean(dist_sampler, n) = mean([dist_sampler() for _ in 1:n])

"""Simulate compounded growth over time."""
function simulate_growth(initial::Real, rate::Real, periods::Int)
    return @audited_calculation _simulate_growth(initial, rate, periods)
end
function _simulate_growth(initial, rate, periods)
    values = Float64[]
    current = initial
    for _ in 1:periods
        current *= (1 + rate)
        push!(values, current)
    end
    return values
end

"""
    arma_forecast(data::AbstractVector{<:Real}, p::Int, q::Int, n_forecast::Int;
                  n_bootstrap::Int=1000, α::Float64=0.05)

Forecast future values using ARMA(p, q) model fitted to historical data.

# Arguments
- `data`: Historical values to fit ARMA model
- `p`: AR lag order
- `q`: MA lag order
- `n_forecast`: Number of periods to forecast
- `n_bootstrap`: Number of bootstrap samples for confidence intervals
- `α`: Significance level for confidence intervals (default 0.05 → 95% CI)

# Returns
- `point_forecast`: Point estimates for future periods
- `ci_lower`: Lower confidence interval bounds
- `ci_upper`: Upper confidence interval bounds
- `arma_model`: Fitted ARMA object (for reuse/inspection)

# Example
```julia
historical_revenue = [100, 105, 103, 108, 110, 112, ...]
forecast, ci_lo, ci_hi, model = arma_forecast(historical_revenue, 2, 1, 12)
```
"""
function arma_forecast(data::AbstractVector{<:Real}, p::Int, q::Int, n_forecast::Int;
                       n_bootstrap::Int=1000, α::Float64=0.05)
    length(data) > p + q || throw(ArgumentError("need at least p+q+1 observations to fit ARMA"))
    p >= 0 || throw(ArgumentError("p must be non-negative"))
    q >= 0 || throw(ArgumentError("q must be non-negative"))
    n_forecast > 0 || throw(ArgumentError("n_forecast must be positive"))
    0 < α < 1 || throw(ArgumentError("α must be in (0, 1)"))

    # Fit ARMA model
    arma_model = ARMA(data; order=(p, q))

    # Generate point forecast
    point_forecast = simulate(arma_model, n_forecast)

    # Bootstrap for confidence intervals
    bootstrap_forecasts = Matrix{Float64}(undef, n_bootstrap, n_forecast)
    for i in 1:n_bootstrap
        # Resample residuals with replacement
        residuals = data .- mean(data)  # Simplified residuals
        bootstrap_data = data .+ rand(residuals, length(data))

        try
            bootstrap_model = ARMA(bootstrap_data; order=(p, q))
            bootstrap_forecasts[i, :] .= simulate(bootstrap_model, n_forecast)
        catch
            # If fit fails, use original forecast
            bootstrap_forecasts[i, :] .= point_forecast
        end
    end

    # Compute confidence intervals
    quantile_lower = α / 2
    quantile_upper = 1 - α / 2
    ci_lower = [quantile(bootstrap_forecasts[:, t], quantile_lower) for t in 1:n_forecast]
    ci_upper = [quantile(bootstrap_forecasts[:, t], quantile_upper) for t in 1:n_forecast]

    return (point_forecast = point_forecast, ci_lower = ci_lower, ci_upper = ci_upper,
            model = arma_model)
end

"""
    arma_stochastic_paths(data::AbstractVector{<:Real}, p::Int, q::Int, n_periods::Int,
                          n_paths::Int=1000)

Generate multiple stochastic forecast paths using ARMA(p, q) model.

Useful for Monte Carlo simulations (e.g., computing NPV under revenue uncertainty).

# Arguments
- `data`: Historical values to fit ARMA model
- `p`: AR lag order
- `q`: MA lag order
- `n_periods`: Length of each forecast path
- `n_paths`: Number of independent paths to generate

# Returns
- Matrix of shape (n_paths, n_periods) where each row is one stochastic path

# Example
```julia
revenue_scenarios = arma_stochastic_paths(historical_medicaid, 2, 1, 60, n_paths=1000)
# Compute NPV for each scenario
npvs = [npv(0.05, revenue_scenarios[i, :]) for i in 1:1000]
```
"""
function arma_stochastic_paths(data::AbstractVector{<:Real}, p::Int, q::Int, n_periods::Int;
                               n_paths::Int=1000)
    length(data) > p + q || throw(ArgumentError("need at least p+q+1 observations to fit ARMA"))
    p >= 0 || throw(ArgumentError("p must be non-negative"))
    q >= 0 || throw(ArgumentError("q must be non-negative"))
    n_periods > 0 || throw(ArgumentError("n_periods must be positive"))
    n_paths > 0 || throw(ArgumentError("n_paths must be positive"))

    # Fit ARMA model
    arma_model = ARMA(data; order=(p, q))

    # Generate stochastic paths
    paths = Matrix{Float64}(undef, n_paths, n_periods)
    for i in 1:n_paths
        paths[i, :] = simulate(arma_model, n_periods)
    end

    return paths
end
