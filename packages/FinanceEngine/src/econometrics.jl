"""
    econometrics.jl — Healthcare econometric methods

Provides simple linear regression, prediction, goodness-of-fit measures, and
mean absolute error for healthcare cost and demand analysis.
No external dependencies beyond Statistics and LinearAlgebra.
"""

using LinearAlgebra

# ── Simple Linear Regression ─────────────────────────────────────────────────

"""
    RegressionResult

Result container for a simple linear regression fit.

# Fields
- `intercept::Float64`: Estimated intercept (β₀).
- `slope::Float64`: Estimated slope (β₁).
- `r_squared::Float64`: Coefficient of determination (R²).
- `residuals::Vector{Float64}`: Residual vector (y - ŷ).
- `n::Int`: Number of observations.
"""
struct RegressionResult
    intercept::Float64
    slope::Float64
    r_squared::Float64
    residuals::Vector{Float64}
    n::Int
end

"""
    simple_linear_regression(x::Vector{<:Real}, y::Vector{<:Real}) -> RegressionResult

Fit a simple linear regression y = β₀ + β₁x using the normal equations.

# Arguments
- `x`: Predictor variable vector (length ≥ 2).
- `y`: Response variable vector (same length as `x`).

# Returns
A `RegressionResult` with fitted intercept, slope, R², and residuals.

# Example
```julia
x = [1.0, 2.0, 3.0, 4.0, 5.0]
y = [2.1, 3.9, 6.2, 7.8, 10.1]
result = simple_linear_regression(x, y)
# result.slope ≈ 2.0, result.intercept ≈ 0.06
```
"""
function simple_linear_regression(x::Vector{<:Real}, y::Vector{<:Real})
    length(x) == length(y) || throw(
        DataValidationError("x and y must have equal length; got $(length(x)) and $(length(y))")
    )
    length(x) >= 2 || throw(
        InsufficientSampleError("Need at least 2 observations for regression, got $(length(x))")
    )

    n = length(x)
    xf = Float64.(x)
    yf = Float64.(y)

    x_mean = mean(xf)
    y_mean = mean(yf)

    ss_xy = sum((xf .- x_mean) .* (yf .- y_mean))
    ss_xx = sum((xf .- x_mean) .^ 2)

    ss_xx > 0 || throw(
        CalculationError("Zero variance in x — cannot fit regression (all x values are identical)")
    )

    slope = ss_xy / ss_xx
    intercept = y_mean - slope * x_mean

    y_hat = intercept .+ slope .* xf
    residuals = yf .- y_hat

    ss_res = sum(residuals .^ 2)
    ss_tot = sum((yf .- y_mean) .^ 2)
    r2 = ss_tot > 0 ? 1.0 - ss_res / ss_tot : 0.0

    return RegressionResult(intercept, slope, r2, residuals, n)
end

# ── Prediction ───────────────────────────────────────────────────────────────

"""
    predict_linear(result::RegressionResult, x_new::Vector{<:Real}) -> Vector{Float64}

Predict response values from a fitted simple linear regression.

# Arguments
- `result`: A `RegressionResult` from `simple_linear_regression`.
- `x_new`: New predictor values at which to predict.

# Returns
Vector of predicted ŷ values.

# Example
```julia
result = simple_linear_regression([1.0, 2.0, 3.0], [2.0, 4.0, 6.0])
predict_linear(result, [4.0, 5.0])  # => [8.0, 10.0]
```
"""
function predict_linear(result::RegressionResult, x_new::Vector{<:Real})
    return result.intercept .+ result.slope .* Float64.(x_new)
end

# ── R-Squared ────────────────────────────────────────────────────────────────

"""
    r_squared(y_actual::Vector{<:Real}, y_predicted::Vector{<:Real}) -> Float64

Compute the coefficient of determination (R²) between actual and predicted values.

R² = 1 - SS_res / SS_tot

# Arguments
- `y_actual`: Observed response values.
- `y_predicted`: Model-predicted response values (same length as `y_actual`).

# Returns
R² value. A value of 1.0 indicates perfect fit; 0.0 indicates the model
explains no more variance than the mean. Can be negative for poor models.

# Example
```julia
r_squared([2.0, 4.0, 6.0], [2.1, 3.9, 6.0])  # ≈ 0.9975
```
"""
function r_squared(y_actual::Vector{<:Real}, y_predicted::Vector{<:Real})
    length(y_actual) == length(y_predicted) || throw(
        DataValidationError("y_actual and y_predicted must have equal length; " *
            "got $(length(y_actual)) and $(length(y_predicted))")
    )
    length(y_actual) >= 2 || throw(
        InsufficientSampleError("Need at least 2 observations for R², got $(length(y_actual))")
    )

    ya = Float64.(y_actual)
    yp = Float64.(y_predicted)

    y_mean = mean(ya)
    ss_res = sum((ya .- yp) .^ 2)
    ss_tot = sum((ya .- y_mean) .^ 2)

    ss_tot > 0 || return 0.0
    return 1.0 - ss_res / ss_tot
end

# ── Mean Absolute Error ──────────────────────────────────────────────────────

"""
    mean_absolute_error(y_actual::Vector{<:Real}, y_predicted::Vector{<:Real}) -> Float64

Compute the Mean Absolute Error (MAE) between actual and predicted values.

MAE = (1/n) Σ|yᵢ - ŷᵢ|

# Arguments
- `y_actual`: Observed response values.
- `y_predicted`: Model-predicted response values (same length as `y_actual`).

# Returns
Non-negative MAE value in the same units as y.

# Example
```julia
mean_absolute_error([10.0, 20.0, 30.0], [12.0, 18.0, 33.0])  # => 3.0
```
"""
function mean_absolute_error(y_actual::Vector{<:Real}, y_predicted::Vector{<:Real})
    length(y_actual) == length(y_predicted) || throw(
        DataValidationError("y_actual and y_predicted must have equal length; " *
            "got $(length(y_actual)) and $(length(y_predicted))")
    )
    isempty(y_actual) && throw(
        DataValidationError("Input vectors must not be empty")
    )

    return mean(abs.(Float64.(y_actual) .- Float64.(y_predicted)))
end
