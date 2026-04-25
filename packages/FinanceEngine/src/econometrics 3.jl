"""
    econometrics.jl — Statistical modeling for healthcare finance

Migrated from healthcare-finance-julia/src/econometrics_engine.jl.
"""

"""
    simple_linear_regression(x, y) -> (intercept, slope)

Fit y = a + b*x via OLS.
"""
function simple_linear_regression(x::AbstractVector{<:Real}, y::AbstractVector{<:Real})
    length(x) == length(y) || throw(ArgumentError("x and y must have same length"))
    length(x) > 1 || throw(ArgumentError("at least two observations are required"))
    return @audited_calculation _simple_linear_regression(x, y)
end
function _simple_linear_regression(x, y)
    x̄ = mean(x)
    ȳ = mean(y)
    numerator = sum((xi - x̄) * (yi - ȳ) for (xi, yi) in zip(x, y))
    denominator = sum((xi - x̄)^2 for xi in x)
    denominator == 0 && throw(ArgumentError("x values must not all be identical"))
    slope = numerator / denominator
    intercept = ȳ - slope * x̄
    return (intercept = intercept, slope = slope)
end

"""Predict values from a linear model."""
function predict_linear(model, x::AbstractVector{<:Real})
    return @audited_calculation _predict_linear(model, x)
end
_predict_linear(model, x) = [model.intercept + model.slope * xi for xi in x]

"""Coefficient of determination (R²)."""
function r_squared(y_true::AbstractVector{<:Real}, y_pred::AbstractVector{<:Real})
    length(y_true) == length(y_pred) || throw(ArgumentError("vectors must have same length"))
    return @audited_calculation _r_squared(y_true, y_pred)
end
function _r_squared(y_true, y_pred)
    ȳ = mean(y_true)
    ss_res = sum((yt - yp)^2 for (yt, yp) in zip(y_true, y_pred))
    ss_tot = sum((yt - ȳ)^2 for yt in y_true)
    ss_tot == 0 && throw(ArgumentError("true values must not all be identical"))
    return 1 - ss_res / ss_tot
end

"""Mean absolute error."""
function mean_absolute_error(y_true::AbstractVector{<:Real}, y_pred::AbstractVector{<:Real})
    length(y_true) == length(y_pred) || throw(ArgumentError("vectors must have same length"))
    return @audited_calculation _mean_absolute_error(y_true, y_pred)
end
_mean_absolute_error(y_true, y_pred) = mean(abs.(y_true .- y_pred))
