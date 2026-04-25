"""
    financial_monitoring.jl — Real-time financial health monitoring with Kalman filtering

Implements state estimation to separate true financial performance from noisy payment data.
Provides early warning signals for margin deterioration and liquidity risk.
"""

"""
    KalmanFilterState

State of a 1D Kalman filter tracking an unobserved scalar state.

# Fields
- `x::Float64`: Current state estimate (true margin)
- `P::Float64`: Current uncertainty (variance of estimate)
- `Q::Float64`: Process noise (how much state drifts randomly)
- `R::Float64`: Observation noise (measurement error variance)
- `A::Float64`: State transition coefficient (default 1.0 for random walk)
- `C::Float64`: Observation coefficient (default 1.0 for direct observation)
"""
mutable struct KalmanFilterState
    x::Float64      # State estimate
    P::Float64      # State variance
    Q::Float64      # Process noise variance
    R::Float64      # Observation noise variance
    A::Float64      # State transition: x_t = A * x_{t-1} + w_t
    C::Float64      # Observation: z_t = C * x_t + v_t
end

"""
    initialize_kalman(initial_state::Real, initial_uncertainty::Real,
                      process_noise::Real, observation_noise::Real;
                      transition_coeff::Real=1.0, observation_coeff::Real=1.0)

Initialize a Kalman filter for tracking a scalar state variable.

# Arguments
- `initial_state`: Best guess for true state (e.g., expected margin)
- `initial_uncertainty`: Initial uncertainty (variance) of estimate
- `process_noise`: How much state drifts randomly per period (higher = more drift)
- `observation_noise`: Measurement error variance (higher = noisier data)
- `transition_coeff`: How state evolves (1.0 = random walk, <1.0 = mean-reverting)
- `observation_coeff`: Observation scaling (usually 1.0)

# Returns
KalmanFilterState object ready for filtering

# Example
```julia
# Initialize filter for operating margin
# Assume true margin is ~20%, but we're uncertain (5% variance)
# Margin drifts slowly (1% process noise)
# Monthly reports have ~2% measurement error
kf = initialize_kalman(
    initial_state = 0.20,
    initial_uncertainty = 0.05^2,
    process_noise = 0.01^2,
    observation_noise = 0.02^2
)
```
"""
function initialize_kalman(initial_state::Real, initial_uncertainty::Real,
                          process_noise::Real, observation_noise::Real;
                          transition_coeff::Real=1.0, observation_coeff::Real=1.0)

    initial_uncertainty > 0 || throw(ArgumentError("initial_uncertainty must be positive"))
    process_noise >= 0 || throw(ArgumentError("process_noise must be non-negative"))
    observation_noise > 0 || throw(ArgumentError("observation_noise must be positive"))

    return KalmanFilterState(
        Float64(initial_state),
        Float64(initial_uncertainty),
        Float64(process_noise),
        Float64(observation_noise),
        Float64(transition_coeff),
        Float64(observation_coeff)
    )
end

"""
    kalman_filter_step(kf::KalmanFilterState, observation::Real) ->
        (state_estimate::Float64, uncertainty::Float64, innovation::Float64,
         innovation_var::Float64)

Update Kalman filter with a new observation.

The filter separates:
- **True state:** Hidden operating margin unaffected by payment timing
- **Observation:** Monthly reported margin (noisy due to audit adjustments, late payments)

# Algorithm
1. **Predict:** Where should state be next?
   - state = A * previous_state
   - uncertainty += process_noise

2. **Update:** Given new observation, revise estimate
   - Kalman gain = uncertainty / (uncertainty + observation_noise)
   - state += gain * (observation - predicted_state)
   - uncertainty *= (1 - gain)

# Arguments
- `kf`: KalmanFilterState to update in-place
- `observation`: New observed measurement (e.g., reported margin this month)

# Returns
Named tuple with:
- `state_estimate`: Updated estimate of true state
- `uncertainty`: Updated uncertainty (confidence interval)
- `innovation`: Difference between observed and predicted (signal of deterioration)
- `innovation_var`: Variance of innovation (for testing significance)

# Example
```julia
kf = initialize_kalman(0.20, 0.05^2, 0.01^2, 0.02^2)

# Month 1: observe 19% margin (slightly low)
result = kalman_filter_step(kf, 0.19)
# → state_estimate ≈ 0.195 (pulls down from 0.20, but not fully trusting noisy data)
# → uncertainty shrinks (gained information)

# Month 2: observe 18% margin (lower)
result = kalman_filter_step(kf, 0.18)
# → state_estimate ≈ 0.19 (continues downward, but slower than observations)
# → innovation ≈ -0.01 (consistent signal of deterioration)
```
"""
function kalman_filter_step(kf::KalmanFilterState, observation::Real)
    # Prediction step
    x_pred = kf.A * kf.x
    P_pred = kf.A^2 * kf.P + kf.Q

    # Update step
    # Innovation: difference between observation and prediction
    y = observation - kf.C * x_pred
    S = kf.C^2 * P_pred + kf.R  # Innovation variance

    # Kalman gain
    K = (kf.C * P_pred) / S

    # Update state and uncertainty
    kf.x = x_pred + K * y
    kf.P = (1 - K * kf.C) * P_pred

    return (
        state_estimate = kf.x,
        uncertainty = sqrt(kf.P),
        innovation = y,
        innovation_var = S
    )
end

"""
    margin_tracker(observations::AbstractVector{<:Real};
                   initial_margin::Real=mean(observations),
                   process_noise::Real=0.01^2,
                   observation_noise::Real=0.02^2,
                   transition_coeff::Real=0.95)

Filter historical margin observations to estimate true sustainable margin.

Separates monthly operating margin into:
- **True margin:** Underlying profitability (what we care about)
- **Noise:** Payment timing, audit adjustments, one-time items

# Arguments
- `observations`: Monthly operating margins (as decimals, e.g., [0.18, 0.19, 0.20])
- `initial_margin`: Starting estimate of true margin (default: average of data)
- `process_noise`: Drift in true margin per month (default: 0.01² = 1% std dev)
- `observation_noise`: Monthly measurement error (default: 0.02² = 2% std dev)
- `transition_coeff`: Mean reversion (0.95 = slightly mean-reverting, 1.0 = random walk)

# Returns
Named tuple with:
- `state_estimates`: Filtered estimate of true margin each month
- `uncertainties`: Confidence intervals (±1 std dev)
- `innovations`: Deviations from predicted (signal of real change)
- `trends`: Smoothed trend of true margin
- `cycles`: Extracted cyclical component

# Example
```julia
# 12 months of operating margin data
margins = [0.18, 0.19, 0.195, 0.18, 0.17, 0.16, 0.15, 0.14, 0.13, 0.12, 0.11, 0.10]

result = margin_tracker(margins)

# True margin is lower than reported (accounting for noisy payments)
result.state_estimates[end]  # ≈ 0.11 (end of period)

# Confidence bounds
low = result.state_estimates[end] - result.uncertainties[end]
high = result.state_estimates[end] + result.uncertainties[end]
# Report: "True margin is 11% ± 2% with 95% confidence"
```
"""
function margin_tracker(observations::AbstractVector{<:Real};
                       initial_margin::Real=mean(observations),
                       process_noise::Real=0.01^2,
                       observation_noise::Real=0.02^2,
                       transition_coeff::Real=0.95)

    length(observations) > 0 || throw(ArgumentError("observations cannot be empty"))
    process_noise >= 0 || throw(ArgumentError("process_noise must be non-negative"))
    observation_noise > 0 || throw(ArgumentError("observation_noise must be positive"))

    # Initialize Kalman filter
    kf = initialize_kalman(
        initial_margin,
        process_noise,  # Initial uncertainty = process noise
        process_noise,
        observation_noise,
        transition_coeff = transition_coeff
    )

    n = length(observations)
    state_estimates = Float64[]
    uncertainties = Float64[]
    innovations = Float64[]

    # Filter forward
    for obs in observations
        result = kalman_filter_step(kf, obs)
        push!(state_estimates, result.state_estimate)
        push!(uncertainties, result.uncertainty)
        push!(innovations, result.innovation)
    end

    # Extract trend (smoothed states) and cycle
    trend = copy(state_estimates)
    # Cycle = observations - trend (what's left after removing filtered signal)
    cycles = observations .- state_estimates

    return (
        state_estimates = state_estimates,
        uncertainties = uncertainties,
        innovations = innovations,
        trends = trend,
        cycles = cycles,
        observations = observations
    )
end

"""
    early_warning_signal(margin_history::AbstractVector{<:Real};
                        threshold_months::Int=3,
                        deterioration_threshold::Real=-0.02,
                        confidence_level::Real=0.95)

Detect early warning signs of financial deterioration.

Returns alert level based on:
1. **Trend:** Is true margin consistently falling?
2. **Velocity:** How fast is margin falling?
3. **Confidence:** How certain are we?

# Arguments
- `margin_history`: Recent monthly margins (recommend 12-24 months)
- `threshold_months`: How many months of deterioration signals alert? (default: 3)
- `deterioration_threshold`: Max change per month to trigger alert (default: -0.02 = -2%)
- `confidence_level`: Confidence required to trust estimate (default: 0.95)

# Returns
Named tuple with:
- `alert_level`: "green" (normal), "yellow" (watch), "red" (action needed)
- `estimated_margin`: Current estimated true margin
- `margin_ci`: (lower, upper) 95% confidence interval
- `deterioration_rate`: Estimated margin change per month
- `months_to_warning`: Months until margin hits critical threshold
- `recommendation`: Action to consider
- `signal_strength`: How confident is the warning (0-1)

# Example
```julia
# Last 12 months of operating margin
margins = [0.20, 0.205, 0.198, 0.195, 0.188, 0.185,
           0.18, 0.175, 0.17, 0.165, 0.16, 0.155]

warning = early_warning_signal(margins)

warning.alert_level  # "yellow" or "red"?
warning.deterioration_rate  # How fast falling? ≈ -0.004/month = -4.8%/year
warning.months_to_warning  # How long until critical margin hit?
warning.recommendation  # "Monitor closely" or "Take action"
```
"""
function early_warning_signal(margin_history::AbstractVector{<:Real};
                             threshold_months::Int=3,
                             deterioration_threshold::Real=-0.02,
                             confidence_level::Real=0.95)

    length(margin_history) >= 3 || throw(ArgumentError("Need at least 3 months of data"))
    threshold_months > 0 || throw(ArgumentError("threshold_months must be positive"))
    0 < confidence_level < 1 || throw(ArgumentError("confidence_level must be in (0,1)"))

    # Run margin tracker
    tracking = margin_tracker(margin_history)

    # Current state
    current_margin = tracking.state_estimates[end]
    current_uncertainty = tracking.uncertainties[end]

    # Trend analysis: fit line to last N months
    n = length(margin_history)
    months = 1:n

    # Simple linear trend
    x̄ = mean(months)
    ȳ = mean(tracking.state_estimates)
    numerator = sum((i - x̄) * (tracking.state_estimates[i] - ȳ) for i in 1:n)
    denominator = sum((i - x̄)^2 for i in 1:n)

    if abs(denominator) < 1e-10
        deterioration_rate = 0.0
    else
        deterioration_rate = numerator / denominator
    end

    # Count negative innovation months (months where margin fell more than expected)
    negative_innovations = sum(tracking.innovations .< deterioration_threshold)

    # Determine alert level
    if negative_innovations >= threshold_months && deterioration_rate < -0.005
        alert_level = "red"
        recommendation = "URGENT: Implement cost reduction plan immediately"
        signal_strength = min(1.0, negative_innovations / threshold_months)
    elseif negative_innovations >= 1 && deterioration_rate < -0.002
        alert_level = "yellow"
        recommendation = "Monitor closely; prepare contingency plans"
        signal_strength = min(1.0, negative_innovations / (threshold_months * 0.66))
    else
        alert_level = "green"
        recommendation = "Continue normal monitoring"
        signal_strength = 0.0
    end

    # Estimate months until critical threshold (10% margin)
    critical_margin = 0.10
    margin_gap = current_margin - critical_margin
    if deterioration_rate < -0.001
        months_to_critical = margin_gap / (-deterioration_rate)
    else
        months_to_critical = Inf
    end

    return (
        alert_level = alert_level,
        estimated_margin = current_margin,
        margin_ci = (current_margin - 1.96 * current_uncertainty,
                    current_margin + 1.96 * current_uncertainty),
        deterioration_rate = deterioration_rate,
        months_to_critical = months_to_critical,
        recommendation = recommendation,
        signal_strength = signal_strength,
        data_confidence = 1 - current_uncertainty / mean(tracking.uncertainties)
    )
end

"""
    hamilton_filter(data::AbstractVector{<:Real}, h::Int=8) -> (trend, cycle)

Extract trend and cyclical components using Hamilton filter.

The Hamilton filter separates time series into:
- **Trend:** Long-term direction (growth, decline)
- **Cycle:** Deviations from trend (seasonal, temporary shocks)

Better than HP filter for healthcare data: less prone to spurious cyclicality at endpoints.

# Arguments
- `data`: Time series to decompose (e.g., annual revenues)
- `h`: Lookback period for trend calculation (default: 8 years for annual data)

# Returns
Named tuple with:
- `trend`: Long-term trajectory
- `cycle`: Deviations from trend
- `gap`: Another term for cycle

# Example
```julia
# 20 years of annual revenue
revenues = [10M, 10.5M, 11M, ..., 15M]

result = hamilton_filter(revenues)

# Plot trend to see if hospital is growing or declining
plot(result.trend)  # Shows structural direction

# Cycle shows temporary ups/downs
plot(result.cycle)  # Shows year-to-year volatility
```
"""
function hamilton_filter(data::AbstractVector{<:Real}, h::Int=8)
    length(data) > h || throw(ArgumentError("Need at least h+1 observations"))
    h > 0 || throw(ArgumentError("h must be positive"))

    n = length(data)
    trend = similar(data)
    cycle = similar(data)

    # For points before we have h observations, use simple average
    for t in 1:h
        trend[t] = mean(data[1:min(t, h)])
    end

    # Hamilton filter: subtract h-period lagged value from current
    # This removes trend, leaving cyclical component
    for t in (h+1):n
        # Trend is the h-period backward average
        trend[t] = mean(data[(t-h):t])
        cycle[t] = data[t] - trend[t]
    end

    # Fill early cycle values
    for t in 1:h
        cycle[t] = data[t] - trend[t]
    end

    return (
        trend = trend,
        cycle = cycle,
        gap = cycle  # Alias for cycle (common in literature)
    )
end

"""
    liquidity_forecast(margin_history::AbstractVector{<:Real},
                      monthly_revenue::Real;
                      cash_balance::Real=1_000_000,
                      daily_operating_cost::Real=30_000,
                      forecast_horizon::Int=6)

Forecast liquidity position based on margin trajectory.

Combines margin tracking + daily cash burn to forecast when hospital
might face liquidity stress.

# Arguments
- `margin_history`: Recent monthly operating margins
- `monthly_revenue`: Expected monthly revenue (\$)
- `cash_balance`: Current cash on hand (\$)
- `daily_operating_cost`: Daily operating expenses (\$)
- `forecast_horizon`: Months to forecast ahead

# Returns
Named tuple with:
- `projected_margins`: Forecasted margins by month
- `projected_cash`: Projected cash balance by month
- `months_to_stress`: When does cash hit danger zone (60 days operating)
- `stress_risk`: Probability of liquidity stress in next 6 months
- `recommendation`: Action to take

# Example
```julia
margins = [0.20, 0.195, 0.19, 0.18, 0.17, 0.16]

forecast = liquidity_forecast(
    margins,
    monthly_revenue = 2_000_000,
    cash_balance = 500_000,
    daily_operating_cost = 30_000
)

if forecast.stress_risk > 0.3
    println("HIGH RISK: May face liquidity stress in \$(forecast.months_to_stress) months")
    println(forecast.recommendation)
end
```
"""
function liquidity_forecast(margin_history::AbstractVector{<:Real},
                           monthly_revenue::Real;
                           cash_balance::Real=1_000_000,
                           daily_operating_cost::Real=30_000,
                           forecast_horizon::Int=6)

    monthly_cost = daily_operating_cost * 30
    monthly_cost < monthly_revenue || throw(ArgumentError("Monthly cost exceeds revenue"))
    forecast_horizon > 0 || throw(ArgumentError("forecast_horizon must be positive"))

    # Track margins
    tracking = margin_tracker(margin_history)
    current_margin = tracking.state_estimates[end]
    deterioration_rate = mean(diff(tracking.state_estimates[max(1,end-3):end]))

    # Project forward
    projected_margins = Float64[]
    projected_cash = Float64[]
    current_cash = cash_balance
    current_m = current_margin

    for month in 1:forecast_horizon
        # Project margin (linear decline based on recent trend)
        current_m = max(0, current_m + deterioration_rate)
        push!(projected_margins, current_m)

        # Project cash (margin × revenue - deficit)
        operating_profit = current_m * monthly_revenue
        current_cash += operating_profit - (monthly_revenue - current_m * monthly_revenue)
        # Simplify: current_cash decreases by losses
        actual_profit = (current_m - 1.0) * monthly_revenue + monthly_revenue
        # Further simplify: loss = (1-margin)*revenue
        monthly_loss = (1 - current_m) * monthly_revenue
        current_cash -= monthly_loss * 0.5  # Assume partial cash impact

        push!(projected_cash, current_cash)
    end

    # Minimum safe cash (60 days operating cost)
    minimum_safe = daily_operating_cost * 60

    # Find when cash hits minimum
    months_to_stress = findfirst(c -> c < minimum_safe, projected_cash)
    if isnothing(months_to_stress)
        months_to_stress = Inf
    end

    # Stress risk = probability current trajectory leads to stress
    stress_risk = count(projected_cash .< minimum_safe) / forecast_horizon

    if months_to_stress <= 3
        recommendation = "CRITICAL: Implement immediate cost reduction and revenue initiatives"
    elseif months_to_stress <= 6
        recommendation = "HIGH PRIORITY: Develop 90-day financial recovery plan"
    elseif stress_risk > 0.2
        recommendation = "WATCH: Monitor margin closely; prepare contingencies"
    else
        recommendation = "Normal: Continue standard financial management"
    end

    return (
        projected_margins = projected_margins,
        projected_cash = projected_cash,
        months_to_stress = months_to_stress,
        stress_risk = stress_risk,
        recommendation = recommendation,
        current_cash = cash_balance,
        minimum_safe_cash = minimum_safe
    )
end
