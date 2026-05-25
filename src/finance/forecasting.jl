# Time Series Forecasting for Hospital Finance
#
# Implements simple exponential smoothing (SES), Holt double exponential
# smoothing (level + trend), weighted moving average (WMA), and forecast
# accuracy metrics (RMSE, MAPE, bias).

using Statistics

# ============================================================================
# Forecast Accuracy
# ============================================================================

"""
    ForecastAccuracy

Accuracy metrics comparing actual values to predicted values.

# Fields
- `rmse::Float64`: root mean squared error
- `mape::Float64`: mean absolute percentage error (0–100 scale)
- `bias::Float64`: mean signed error (positive = over-forecast)
"""
@kwdef struct ForecastAccuracy
    rmse::Float64
    mape::Float64
    bias::Float64
end

function Base.show(io::IO, fa::ForecastAccuracy)
    print(io, "ForecastAccuracy(RMSE=$(round(fa.rmse, digits=4)), " *
          "MAPE=$(round(fa.mape, digits=2))%, bias=$(round(fa.bias, digits=4)))")
end

"""
    forecast_accuracy(actual::Vector{Float64}, predicted::Vector{Float64}) -> ForecastAccuracy

Compute forecast accuracy metrics between `actual` and `predicted` series.

# Metrics
- **RMSE** = sqrt(mean((actual - predicted)^2))
- **MAPE** = mean(|actual - predicted| / |actual|) * 100, excluding zero actuals
- **Bias** = mean(predicted - actual)

# Arguments
- `actual::Vector{Float64}`: observed values
- `predicted::Vector{Float64}`: forecasted values (same length as actual)

# Returns
- `ForecastAccuracy`: computed accuracy metrics
"""
function forecast_accuracy(actual::Vector{Float64}, predicted::Vector{Float64})::ForecastAccuracy
    length(actual) == length(predicted) || error("actual and predicted must have the same length")
    length(actual) > 0 || error("input vectors must not be empty")

    n = length(actual)
    errors = predicted .- actual

    # RMSE
    rmse = sqrt(sum(errors .^ 2) / n)

    # MAPE (skip zero actuals to avoid division by zero)
    ape_sum = 0.0
    ape_count = 0
    for i in 1:n
        if abs(actual[i]) > 1e-12
            ape_sum += abs(errors[i]) / abs(actual[i])
            ape_count += 1
        end
    end
    mape = ape_count > 0 ? (ape_sum / ape_count) * 100.0 : 0.0

    # Bias (mean signed error: positive = over-forecast)
    bias = sum(errors) / n

    return ForecastAccuracy(rmse=rmse, mape=mape, bias=bias)
end

# ============================================================================
# Simple Exponential Smoothing (SES)
# ============================================================================

"""
    simple_exponential_smoothing(values::Vector{Float64}, alpha::Float64,
                                  n_forecast::Int) -> Vector{Float64}

Forecast using Simple Exponential Smoothing (SES).

## Algorithm
    S_1 = values[1]
    S_t = alpha * values[t] + (1 - alpha) * S_{t-1}

The forecast for all future periods is the last smoothed level S_T.

# Arguments
- `values::Vector{Float64}`: historical time series
- `alpha::Float64`: smoothing parameter in (0, 1)
- `n_forecast::Int`: number of future periods to forecast

# Returns
- `Vector{Float64}`: vector of `n_forecast` forecasted values
"""
function simple_exponential_smoothing(values::Vector{Float64}, alpha::Float64,
                                      n_forecast::Int)::Vector{Float64}
    length(values) >= 1 || error("values must contain at least one observation")
    0.0 < alpha < 1.0 || error("alpha must be in (0, 1); got $alpha")
    n_forecast >= 1 || error("n_forecast must be >= 1; got $n_forecast")

    # Initialize level with first observation
    level = values[1]

    # Smooth through historical data
    for t in 2:length(values)
        level = alpha * values[t] + (1.0 - alpha) * level
    end

    # Forecast: SES produces a flat forecast at the final level
    return fill(level, n_forecast)
end

# ============================================================================
# Holt Double Exponential Smoothing
# ============================================================================

"""
    holt_double_exponential(values::Vector{Float64}, alpha::Float64,
                             beta::Float64, n_forecast::Int) -> Vector{Float64}

Forecast using Holt's double exponential smoothing (level + trend).

## Algorithm
    Level:   L_t = alpha * values[t] + (1 - alpha) * (L_{t-1} + T_{t-1})
    Trend:   T_t = beta * (L_t - L_{t-1}) + (1 - beta) * T_{t-1}
    Forecast: F_{T+h} = L_T + h * T_T

# Arguments
- `values::Vector{Float64}`: historical time series (>= 2 observations)
- `alpha::Float64`: level smoothing parameter in (0, 1)
- `beta::Float64`: trend smoothing parameter in (0, 1)
- `n_forecast::Int`: number of future periods to forecast

# Returns
- `Vector{Float64}`: vector of `n_forecast` forecasted values
"""
function holt_double_exponential(values::Vector{Float64}, alpha::Float64,
                                  beta::Float64, n_forecast::Int)::Vector{Float64}
    length(values) >= 2 || error("values must contain at least 2 observations for trend estimation")
    0.0 < alpha < 1.0 || error("alpha must be in (0, 1); got $alpha")
    0.0 < beta < 1.0 || error("beta must be in (0, 1); got $beta")
    n_forecast >= 1 || error("n_forecast must be >= 1; got $n_forecast")

    # Initialize level and trend
    level = values[1]
    trend = values[2] - values[1]

    # Smooth through historical data
    for t in 2:length(values)
        prev_level = level
        level = alpha * values[t] + (1.0 - alpha) * (prev_level + trend)
        trend = beta * (level - prev_level) + (1.0 - beta) * trend
    end

    # Forecast with trend
    forecasts = Vector{Float64}(undef, n_forecast)
    for h in 1:n_forecast
        forecasts[h] = level + h * trend
    end

    return forecasts
end

# ============================================================================
# Weighted Moving Average
# ============================================================================

"""
    weighted_moving_average(values::Vector{Float64},
                             weights::Vector{Float64}) -> Float64

Compute a single weighted moving average forecast value.

The weights are applied to the last `k` observations (where `k = length(weights)`),
with `weights[1]` applied to the oldest and `weights[end]` to the most recent.
Weights are normalized internally to sum to 1.

# Arguments
- `values::Vector{Float64}`: historical time series (length >= length(weights))
- `weights::Vector{Float64}`: weighting vector (positive values)

# Returns
- `Float64`: the weighted moving average forecast for the next period
"""
function weighted_moving_average(values::Vector{Float64},
                                  weights::Vector{Float64})::Float64
    k = length(weights)
    k >= 1 || error("weights must have at least one element")
    length(values) >= k || error("values must have at least $(k) observations; got $(length(values))")
    all(w -> w >= 0.0, weights) || error("weights must be non-negative")

    # Normalize weights
    w_sum = sum(weights)
    w_sum > 0.0 || error("weights must have a positive sum")
    norm_weights = weights ./ w_sum

    # Apply weights to the last k observations
    window = values[end-k+1:end]
    return sum(norm_weights .* window)
end
