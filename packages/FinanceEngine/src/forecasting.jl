# ── Time Series Forecasting and Accuracy Metrics ─────────────────────────────
#
# Exponential smoothing (SES, Holt, Holt-Winters), weighted moving average,
# seasonal index helpers, budget variance functions, and forecast accuracy.
#
# Ported from healthcare-finance-julia/src/forecasting/forecasting.jl

# ─── Exponential Smoothing ────────────────────────────────────────────────────

"""
    simple_exponential_smoothing(values, α; horizon=1) -> NamedTuple

Simple Exponential Smoothing.
α ∈ (0,1]: level smoothing parameter.
Returns `(smoothed, forecast)`.
"""
function simple_exponential_smoothing(values::AbstractVector{<:Real},
                                       α::Real;
                                       horizon::Int=1)
    0 < α <= 1 || throw(ArgumentError("α must be in (0, 1]"))
    length(values) >= 1 || throw(ArgumentError("values must not be empty"))
    horizon >= 1 || throw(ArgumentError("horizon must be at least 1"))
    smoothed    = similar(values, Float64)
    smoothed[1] = Float64(values[1])
    for i in 2:length(values)
        smoothed[i] = α * values[i] + (1 - α) * smoothed[i-1]
    end
    return (smoothed=smoothed, forecast=fill(smoothed[end], horizon))
end

"""
    holt_double_exponential(values, α, β; horizon=1) -> NamedTuple

Holt's Double Exponential Smoothing (trend-adjusted).
α: level smoothing; β: trend smoothing.
Returns `(level, trend, forecast)`.
"""
function holt_double_exponential(values::AbstractVector{<:Real},
                                  α::Real, β::Real;
                                  horizon::Int=1)
    0 < α <= 1 || throw(ArgumentError("α must be in (0, 1]"))
    0 < β <= 1 || throw(ArgumentError("β must be in (0, 1]"))
    n = length(values)
    n >= 2 || throw(ArgumentError("at least two values are required"))
    horizon >= 1 || throw(ArgumentError("horizon must be at least 1"))
    level    = zeros(Float64, n)
    trend    = zeros(Float64, n)
    level[1] = Float64(values[1])
    trend[1] = Float64(values[2]) - Float64(values[1])
    for i in 2:n
        level[i] = α * values[i] + (1 - α) * (level[i-1] + trend[i-1])
        trend[i] = β * (level[i] - level[i-1]) + (1 - β) * trend[i-1]
    end
    forecast = [level[end] + h * trend[end] for h in 1:horizon]
    return (level=level, trend=trend, forecast=forecast)
end

"""
    holt_winters_additive(values, α, β, γ, season_length; horizon=season_length)
        -> NamedTuple

Holt-Winters Additive exponential smoothing (level + trend + seasonality).
Requires at least two full seasons of data.
Returns `(level, trend, seasonal, forecast)`.
"""
function holt_winters_additive(values::AbstractVector{<:Real},
                                α::Real, β::Real, γ::Real,
                                season_length::Int;
                                horizon::Int=season_length)
    0 < α <= 1 || throw(ArgumentError("α must be in (0, 1]"))
    0 < β <= 1 || throw(ArgumentError("β must be in (0, 1]"))
    0 < γ <= 1 || throw(ArgumentError("γ must be in (0, 1]"))
    season_length >= 2 || throw(ArgumentError("season_length must be at least 2"))
    n = length(values)
    n >= 2 * season_length ||
        throw(ArgumentError("values must contain at least two full seasons"))
    horizon >= 1 || throw(ArgumentError("horizon must be at least 1"))

    level    = zeros(Float64, n)
    trend    = zeros(Float64, n)
    seasonal = zeros(Float64, n + horizon)

    n_seasons   = div(n, season_length)
    season_avg1 = mean(values[1:season_length])
    season_avg2 = mean(values[season_length+1:2*season_length])

    level[1] = season_avg1
    trend[1] = (season_avg2 - season_avg1) / season_length
    for i in 1:season_length
        seasonal[i] = Float64(values[i]) / (season_avg1 == 0 ? 1.0 : season_avg1)
    end

    for i in 2:n
        s_idx = mod1(i, season_length)
        level[i] = α * (values[i] - seasonal[s_idx]) +
                   (1 - α) * (level[i-1] + trend[i-1])
        trend[i] = β * (level[i] - level[i-1]) + (1 - β) * trend[i-1]
        seasonal[i] = γ * (values[i] - level[i]) + (1 - γ) * seasonal[s_idx]
    end
    for h in 1:horizon
        seasonal[n + h] = seasonal[n + h - season_length]
    end
    forecast = [level[end] + h * trend[end] + seasonal[n + h] for h in 1:horizon]
    return (level=level, trend=trend, seasonal=seasonal[1:n], forecast=forecast)
end

# ─── Weighted Moving Average ──────────────────────────────────────────────────

"""
    weighted_moving_average(values, weights; horizon=1) -> Vector{Float64}

Weighted moving average forecast. `weights` are normalised and applied to the
most recent `length(weights)` observations.
"""
function weighted_moving_average(values::AbstractVector{<:Real},
                                  weights::AbstractVector{<:Real};
                                  horizon::Int=1)::Vector{Float64}
    window = length(weights)
    window > 0 || throw(ArgumentError("weights must not be empty"))
    length(values) >= window ||
        throw(ArgumentError("values length must be at least the window size"))
    horizon >= 1 || throw(ArgumentError("horizon must be at least 1"))
    all(w >= 0 for w in weights) || throw(ArgumentError("weights must be non-negative"))
    total_weight = sum(weights)
    total_weight > 0 || throw(ArgumentError("sum of weights must be positive"))
    norm_w    = weights ./ total_weight
    window_v  = values[end-window+1:end]
    forecast_val = sum(v * w for (v, w) in zip(window_v, norm_w))
    return fill(Float64(forecast_val), horizon)
end

# ─── Seasonal Helpers ─────────────────────────────────────────────────────────

"""
    seasonal_indices(values, season_length) -> Vector{Float64}

Compute multiplicative seasonal indices from historical data.
Uses as many complete seasons as available.
"""
function seasonal_indices(values::AbstractVector{<:Real},
                           season_length::Int)::Vector{Float64}
    season_length >= 2 || throw(ArgumentError("season_length must be at least 2"))
    n = length(values)
    n >= season_length ||
        throw(ArgumentError("values must cover at least one full season"))
    n_complete  = div(n, season_length) * season_length
    mat         = reshape(collect(Float64.(values[1:n_complete])),
                          season_length, div(n_complete, season_length))
    overall_avg = mean(values[1:n_complete])
    overall_avg == 0 && throw(ArgumentError("mean of values cannot be zero"))
    return [mean(mat[s, :]) / overall_avg for s in 1:season_length]
end

"""
    deseasonalize(values, indices) -> Vector{Float64}

Remove seasonality by dividing each value by its seasonal index (multiplicative).
`indices` are recycled over the full series length.
"""
function deseasonalize(values::AbstractVector{<:Real},
                        indices::AbstractVector{<:Real})::Vector{Float64}
    isempty(indices) && throw(ArgumentError("indices must not be empty"))
    m = length(indices)
    return [values[i] / indices[mod1(i, m)] for i in eachindex(values)]
end

"""
    reseasonalize(values, indices) -> Vector{Float64}

Restore seasonality by multiplying each value by its seasonal index.
"""
function reseasonalize(values::AbstractVector{<:Real},
                        indices::AbstractVector{<:Real})::Vector{Float64}
    isempty(indices) && throw(ArgumentError("indices must not be empty"))
    m = length(indices)
    return [values[i] * indices[mod1(i, m)] for i in eachindex(values)]
end

# ─── Budget / Variance (Forecasting Module) ───────────────────────────────────

"""
    budget_variance(actual, budget) -> Float64

Raw budget variance = actual − budget.
Positive = over budget (unfavorable for expenses, favorable for revenue).
"""
function budget_variance(actual::Real, budget::Real)::Float64
    return Float64(actual - budget)
end

"""
    budget_variance_pct(actual, budget) -> Float64

Budget variance as a percentage of budget.
"""
function budget_variance_pct(actual::Real, budget::Real)::Float64
    budget == 0 && throw(ArgumentError("budget cannot be zero"))
    return (actual - budget) / budget
end

"""
    flexible_budget_variance(actual, flexible_budget) -> Float64

Flexible budget variance = actual − flexible_budget (volume-adjusted budget).
"""
function flexible_budget_variance(actual::Real, flexible_budget::Real)::Float64
    return Float64(actual - flexible_budget)
end

# ─── Accuracy Metrics ─────────────────────────────────────────────────────────

"""
    forecast_rmse(actual, forecast) -> Float64

Root Mean Squared Error between actual and forecast vectors.
"""
function forecast_rmse(actual::AbstractVector{<:Real},
                        forecast::AbstractVector{<:Real})::Float64
    length(actual) == length(forecast) ||
        throw(ArgumentError("actual and forecast must have the same length"))
    return sqrt(mean((a - f)^2 for (a, f) in zip(actual, forecast)))
end

"""
    forecast_mape(actual, forecast) -> Float64

Mean Absolute Percentage Error. Actual values must not contain zeros.
"""
function forecast_mape(actual::AbstractVector{<:Real},
                        forecast::AbstractVector{<:Real})::Float64
    length(actual) == length(forecast) ||
        throw(ArgumentError("actual and forecast must have the same length"))
    any(a == 0 for a in actual) &&
        throw(ArgumentError("actual values must not contain zeros"))
    return mean(abs((a - f) / a) for (a, f) in zip(actual, forecast))
end

"""
    forecast_bias(actual, forecast) -> Float64

Forecast bias = mean(forecast − actual).
Positive = systematic over-forecasting.
"""
function forecast_bias(actual::AbstractVector{<:Real},
                        forecast::AbstractVector{<:Real})::Float64
    length(actual) == length(forecast) ||
        throw(ArgumentError("actual and forecast must have the same length"))
    return mean(f - a for (a, f) in zip(actual, forecast))
end
