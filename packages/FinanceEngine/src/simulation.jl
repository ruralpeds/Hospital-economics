"""
    simulation.jl — Monte Carlo and stochastic simulation for healthcare finance

Provides Monte Carlo mean estimation, stochastic growth simulation,
ARMA forecasting, and ARMA stochastic path generation.
Uses Random for reproducibility and Statistics for aggregation.
"""

# ── Monte Carlo Mean ─────────────────────────────────────────────────────────

"""
    monte_carlo_mean(sample_fn::Function, n_sims::Int; seed::Union{Int,Nothing}=nothing) -> NamedTuple

Estimate the expected value of a stochastic function via Monte Carlo simulation.

Runs `sample_fn()` (a zero-argument callable returning a scalar) `n_sims` times
and returns summary statistics.

# Arguments
- `sample_fn`: Zero-argument function that returns a single numeric draw.
- `n_sims`: Number of Monte Carlo replications (must be ≥ 1).
- `seed`: Optional RNG seed for reproducibility.

# Returns
Named tuple with:
- `mean`: Sample mean of the draws.
- `std`: Sample standard deviation.
- `min`: Minimum draw.
- `max`: Maximum draw.
- `ci_lower`: Lower bound of 95% confidence interval for the mean.
- `ci_upper`: Upper bound of 95% confidence interval for the mean.
- `n`: Number of simulations run.

# Example
```julia
# Estimate expected NPV when cash flows are random
result = monte_carlo_mean(1000; seed=42) do
    cf = [-100_000; rand(30_000:70_000, 3)]
    sum(cf[t] / 1.1^(t-1) for t in 1:4)
end
result.mean  # ≈ expected NPV
```
"""
function monte_carlo_mean(sample_fn::Function, n_sims::Int;
                          seed::Union{Int,Nothing}=nothing)
    n_sims >= 1 || throw(
        DomainValidationError("n_sims", string(n_sims), "n_sims ≥ 1",
            "Number of simulations must be at least 1")
    )

    rng = isnothing(seed) ? Random.default_rng() : Random.MersenneTwister(seed)

    # Run simulations
    draws = Vector{Float64}(undef, n_sims)
    if !isnothing(seed)
        Random.seed!(rng, seed)
        for i in 1:n_sims
            draws[i] = Float64(sample_fn())
        end
    else
        for i in 1:n_sims
            draws[i] = Float64(sample_fn())
        end
    end

    m = mean(draws)
    s = n_sims > 1 ? std(draws) : 0.0
    se = s / sqrt(n_sims)

    return (
        mean = m,
        std = s,
        min = minimum(draws),
        max = maximum(draws),
        ci_lower = m - 1.96 * se,
        ci_upper = m + 1.96 * se,
        n = n_sims
    )
end

# ── Simulate Growth ──────────────────────────────────────────────────────────

"""
    simulate_growth(initial_value::Real, growth_rate::Real, volatility::Real,
                    periods::Int, n_paths::Int;
                    seed::Union{Int,Nothing}=nothing) -> Matrix{Float64}

Simulate geometric Brownian motion paths for financial projections.

Each path evolves as: V_{t+1} = V_t × exp((μ - σ²/2) + σ × Z_t)
where μ is the growth rate, σ is volatility, and Z_t ~ N(0,1).

# Arguments
- `initial_value`: Starting value (e.g., annual revenue; must be positive).
- `growth_rate`: Expected annual growth rate (e.g., 0.03 for 3%).
- `volatility`: Annual volatility (standard deviation of log-returns; must be ≥ 0).
- `periods`: Number of time periods to simulate (must be ≥ 1).
- `n_paths`: Number of stochastic paths to generate (must be ≥ 1).
- `seed`: Optional RNG seed for reproducibility.

# Returns
Matrix of size `(periods + 1, n_paths)` where row 1 is the initial value
and each column is an independent path.

# Example
```julia
# Simulate 5-year revenue paths with 3% growth and 10% volatility
paths = simulate_growth(10_000_000, 0.03, 0.10, 5, 1000; seed=123)
# paths[6, :] contains year-5 values across 1000 scenarios
```
"""
function simulate_growth(initial_value::Real, growth_rate::Real, volatility::Real,
                         periods::Int, n_paths::Int;
                         seed::Union{Int,Nothing}=nothing)
    initial_value > 0 || throw(
        DomainValidationError("initial_value", string(initial_value), "initial_value > 0",
            "Initial value must be positive")
    )
    volatility >= 0 || throw(
        DomainValidationError("volatility", string(volatility), "volatility ≥ 0",
            "Volatility cannot be negative")
    )
    periods >= 1 || throw(
        DomainValidationError("periods", string(periods), "periods ≥ 1",
            "Must simulate at least 1 period")
    )
    n_paths >= 1 || throw(
        DomainValidationError("n_paths", string(n_paths), "n_paths ≥ 1",
            "Must simulate at least 1 path")
    )

    rng = isnothing(seed) ? Random.default_rng() : Random.MersenneTwister(seed)

    paths = Matrix{Float64}(undef, periods + 1, n_paths)
    paths[1, :] .= Float64(initial_value)

    drift = growth_rate - 0.5 * volatility^2

    for j in 1:n_paths
        for t in 1:periods
            z = randn(rng)
            paths[t + 1, j] = paths[t, j] * exp(drift + volatility * z)
        end
    end

    return paths
end

# ── ARMA Forecast ────────────────────────────────────────────────────────────

"""
    arma_forecast(series::Vector{<:Real}, p::Int, q::Int, horizon::Int) -> Vector{Float64}

Produce point forecasts from a fitted ARMA(p, q) model.

Fits AR and MA coefficients from the input series using the Yule-Walker
equations for the AR component and residual-based estimation for MA.
Then generates `horizon` steps of out-of-sample forecasts.

# Arguments
- `series`: Historical time series (length must be > p + q).
- `p`: AR order (number of autoregressive lags; ≥ 0).
- `q`: MA order (number of moving-average lags; ≥ 0).
- `horizon`: Number of future periods to forecast (≥ 1).

# Returns
Vector of length `horizon` with forecasted values.

# Example
```julia
# Monthly revenue data with AR(2) and no MA
data = [100.0, 102.0, 105.0, 103.0, 107.0, 110.0, 108.0, 112.0]
forecast = arma_forecast(data, 2, 0, 6)
# forecast contains 6 months of projected revenue
```
"""
function arma_forecast(series::Vector{<:Real}, p::Int, q::Int, horizon::Int)
    p >= 0 || throw(
        DomainValidationError("p", string(p), "p ≥ 0", "AR order must be non-negative")
    )
    q >= 0 || throw(
        DomainValidationError("q", string(q), "q ≥ 0", "MA order must be non-negative")
    )
    horizon >= 1 || throw(
        DomainValidationError("horizon", string(horizon), "horizon ≥ 1",
            "Forecast horizon must be at least 1")
    )
    min_len = max(p, q) + 1
    length(series) >= min_len || throw(
        InsufficientSampleError(
            "Series length $(length(series)) too short for ARMA($p,$q); need at least $min_len")
    )

    sf = Float64.(series)
    n = length(sf)
    mu = mean(sf)
    centered = sf .- mu

    # --- Fit AR(p) coefficients via Yule-Walker ---
    ar_coeffs = zeros(max(p, 1))
    if p > 0
        # Compute autocorrelations
        gamma = [sum(centered[1:n-k] .* centered[k+1:n]) / n for k in 0:p]
        # Build Toeplitz system: Γ φ = γ
        Gamma = [gamma[abs(i - j) + 1] for i in 1:p, j in 1:p]
        rhs = gamma[2:p+1]

        det_val = det(Gamma)
        if abs(det_val) < 1e-12
            # Fall back to simple AR(1) if system is singular
            if gamma[1] > 0
                ar_coeffs = zeros(p)
                ar_coeffs[1] = gamma[2] / gamma[1]
            end
        else
            ar_coeffs = Gamma \ rhs
        end
    end

    # --- Compute residuals from AR fit ---
    residuals = zeros(n)
    for t in (p+1):n
        pred = mu
        for k in 1:p
            pred += ar_coeffs[k] * centered[t - k]
        end
        residuals[t] = sf[t] - pred
    end

    # --- Fit MA(q) coefficients from residuals ---
    ma_coeffs = zeros(max(q, 1))
    if q > 0 && n > p + q
        # Simple estimation: regress residuals on lagged residuals
        n_res = n - max(p, q)
        if n_res > q
            X_ma = zeros(n_res, q)
            y_ma = residuals[(max(p, q)+1):n]
            for k in 1:q
                X_ma[:, k] = residuals[(max(p, q)+1-k):(n-k)]
            end
            xxt = X_ma' * X_ma
            if det(xxt) > 1e-12
                ma_coeffs = xxt \ (X_ma' * y_ma)
            end
        end
    end

    # --- Generate forecasts ---
    # Extend the series with forecasts; residuals go to zero beyond sample
    extended = copy(sf)
    ext_residuals = copy(residuals)

    forecasts = Vector{Float64}(undef, horizon)
    for h in 1:horizon
        t = n + h
        pred = mu
        for k in 1:p
            idx = t - k
            val = idx <= n ? centered[idx] : (extended[idx] - mu)
            pred += ar_coeffs[k] * val
        end
        for k in 1:q
            idx = t - k
            e_val = idx <= length(ext_residuals) ? ext_residuals[idx] : 0.0
            pred += ma_coeffs[k] * e_val
        end
        forecasts[h] = pred
        push!(extended, pred)
        push!(ext_residuals, 0.0)  # Future residuals assumed zero
    end

    return forecasts
end

# ── ARMA Stochastic Paths ───────────────────────────────────────────────────

"""
    arma_stochastic_paths(series::Vector{<:Real}, p::Int, q::Int,
                          horizon::Int, n_paths::Int;
                          seed::Union{Int,Nothing}=nothing) -> Matrix{Float64}

Generate stochastic forecast paths from a fitted ARMA(p, q) model by
sampling future innovations from the empirical residual distribution.

# Arguments
- `series`: Historical time series.
- `p`: AR order (≥ 0).
- `q`: MA order (≥ 0).
- `horizon`: Number of future periods per path (≥ 1).
- `n_paths`: Number of stochastic paths to generate (≥ 1).
- `seed`: Optional RNG seed for reproducibility.

# Returns
Matrix of size `(horizon, n_paths)` where each column is an independent
stochastic forecast path.

# Example
```julia
data = cumsum(randn(100)) .+ 200.0
paths = arma_stochastic_paths(data, 1, 0, 12, 500; seed=99)
# paths[12, :] gives distribution of 12-step-ahead forecasts
```
"""
function arma_stochastic_paths(series::Vector{<:Real}, p::Int, q::Int,
                               horizon::Int, n_paths::Int;
                               seed::Union{Int,Nothing}=nothing)
    p >= 0 || throw(
        DomainValidationError("p", string(p), "p ≥ 0", "AR order must be non-negative")
    )
    q >= 0 || throw(
        DomainValidationError("q", string(q), "q ≥ 0", "MA order must be non-negative")
    )
    horizon >= 1 || throw(
        DomainValidationError("horizon", string(horizon), "horizon ≥ 1",
            "Forecast horizon must be at least 1")
    )
    n_paths >= 1 || throw(
        DomainValidationError("n_paths", string(n_paths), "n_paths ≥ 1",
            "Must generate at least 1 path")
    )

    sf = Float64.(series)
    n = length(sf)
    mu = mean(sf)
    centered = sf .- mu

    # Fit AR coefficients (Yule-Walker)
    ar_coeffs = zeros(max(p, 1))
    if p > 0
        gamma = [sum(centered[1:n-k] .* centered[k+1:n]) / n for k in 0:p]
        Gamma = [gamma[abs(i - j) + 1] for i in 1:p, j in 1:p]
        if abs(det(Gamma)) > 1e-12
            ar_coeffs = Gamma \ gamma[2:p+1]
        elseif gamma[1] > 0
            ar_coeffs = zeros(p)
            ar_coeffs[1] = gamma[2] / gamma[1]
        end
    end

    # Compute in-sample residuals
    residuals = zeros(n)
    for t in (p+1):n
        pred = mu
        for k in 1:p
            pred += ar_coeffs[k] * centered[t - k]
        end
        residuals[t] = sf[t] - pred
    end

    # Residual standard deviation for innovation sampling
    valid_residuals = residuals[(p+1):n]
    resid_std = length(valid_residuals) > 1 ? std(valid_residuals) : 1.0

    # Fit MA coefficients
    ma_coeffs = zeros(max(q, 1))
    if q > 0
        n_res = n - max(p, q)
        if n_res > q
            X_ma = zeros(n_res, q)
            y_ma = residuals[(max(p, q)+1):n]
            for k in 1:q
                X_ma[:, k] = residuals[(max(p, q)+1-k):(n-k)]
            end
            xxt = X_ma' * X_ma
            if det(xxt) > 1e-12
                ma_coeffs = xxt \ (X_ma' * y_ma)
            end
        end
    end

    rng = isnothing(seed) ? Random.default_rng() : Random.MersenneTwister(seed)
    result = Matrix{Float64}(undef, horizon, n_paths)

    for j in 1:n_paths
        # Working copies for this path
        ext_vals = copy(centered)   # Extended centered values
        ext_resid = copy(residuals) # Extended residuals

        for h in 1:horizon
            t = n + h
            innovation = randn(rng) * resid_std

            pred = mu
            for k in 1:p
                idx = t - k
                val = idx <= n ? centered[idx] : ext_vals[idx]
                pred += ar_coeffs[k] * val
            end
            for k in 1:q
                idx = t - k
                e_val = idx <= length(ext_resid) ? ext_resid[idx] : 0.0
                pred += ma_coeffs[k] * e_val
            end

            forecast_val = pred + innovation
            result[h, j] = forecast_val
            push!(ext_vals, forecast_val - mu)
            push!(ext_resid, innovation)
        end
    end

    return result
end
