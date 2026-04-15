# Stochastic Interest Rate & Debt Capacity Analysis
#
# Monte Carlo simulation of hospital debt capacity using Vasicek interest
# rate dynamics and stochastic operating income. Estimates maximum sustainable
# debt service, credit tier, and sensitivity to rate changes.

"""
    DebtCapacityParams

Parameters for stochastic debt capacity analysis including operating income,
volatility assumptions, Vasicek interest rate model parameters, and DSCR
confidence constraints.
"""
@kwdef struct DebtCapacityParams
    current_operating_income::Float64
    current_depreciation::Float64
    current_debt_service::Float64
    projection_years::Int = 10
    n_simulations::Int = 1000
    revenue_volatility::Float64 = 0.05
    expense_volatility::Float64 = 0.03
    base_interest_rate::Float64 = 0.05
    rate_mean_reversion::Float64 = 0.15
    rate_volatility::Float64 = 0.01
    min_dscr_threshold::Float64 = 1.25
    target_confidence::Float64 = 0.95
    random_seed::Int = 42
end

"""
    DebtCapacityResult

Results of a stochastic debt capacity analysis: max sustainable debt service,
implied principal, DSCR distribution, and estimated credit tier.
"""
@kwdef struct DebtCapacityResult
    max_annual_debt_service::Float64
    max_debt_principal::Float64
    current_dscr::Float64
    prob_dscr_below_threshold::Float64
    dscr_percentiles::Dict{Float64,Float64}
    estimated_credit_tier::String
end

function Base.show(io::IO, r::DebtCapacityResult)
    print(io, "DebtCapacityResult(max_debt=\$$(round(Int, r.max_debt_principal)), dscr=$(round(r.current_dscr, digits=2)), tier=$(r.estimated_credit_tier))")
end

"""Simulate a single path of annual EBITDA using log-normal shocks."""
function _simulate_operating_income(params::DebtCapacityParams, rng::AbstractRNG)::Vector{Float64}
    income = Vector{Float64}(undef, params.projection_years)
    current = params.current_operating_income + params.current_depreciation
    net_vol = sqrt(params.revenue_volatility^2 + params.expense_volatility^2)

    for t in 1:params.projection_years
        shock = exp(rand(rng, Normal(0.0, net_vol)) - 0.5 * net_vol^2)
        current = current * shock
        income[t] = current
    end
    return income
end

"""Simulate a single interest rate path using Vasicek model (floored at 0.5%)."""
function _simulate_interest_rate(params::DebtCapacityParams, rng::AbstractRNG)::Vector{Float64}
    rates = Vector{Float64}(undef, params.projection_years)
    r = params.base_interest_rate
    κ = params.rate_mean_reversion
    θ = params.base_interest_rate
    σ = params.rate_volatility

    for t in 1:params.projection_years
        dr = κ * (θ - r) + σ * rand(rng, Normal(0.0, 1.0))
        r = max(0.005, r + dr)
        rates[t] = r
    end
    return rates
end

"""Present value of an annuity: max principal for given annual payment, rate, and term."""
function _annuity_principal(annual_payment::Float64, rate::Float64, years::Int)::Float64
    rate <= 0.0 && return annual_payment * years
    return annual_payment * (1.0 - (1.0 + rate)^(-years)) / rate
end

"""Assign credit tier based on 5th percentile DSCR."""
function _assign_credit_tier(dscr_5th::Float64)::String
    dscr_5th >= 4.0 && return "AA"
    dscr_5th >= 3.0 && return "A+"
    dscr_5th >= 2.5 && return "A"
    dscr_5th >= 2.0 && return "A-"
    dscr_5th >= 1.75 && return "BBB+"
    dscr_5th >= 1.50 && return "BBB"
    dscr_5th >= 1.25 && return "BBB-"
    dscr_5th >= 1.10 && return "BB"
    dscr_5th >= 1.00 && return "B"
    return "Below B"
end

"""
    calculate_debt_capacity(params::DebtCapacityParams) -> DebtCapacityResult

Monte Carlo debt capacity analysis. Simulates operating income and interest
rate paths, finds max debt service where P(DSCR < threshold) <= (1 - confidence).
"""
function calculate_debt_capacity(params::DebtCapacityParams)::DebtCapacityResult
    params.current_operating_income > 0.0 || error("current_operating_income must be positive; got $(params.current_operating_income)")
    params.current_depreciation >= 0.0 || error("current_depreciation must be non-negative; got $(params.current_depreciation)")
    params.current_debt_service >= 0.0 || error("current_debt_service must be non-negative; got $(params.current_debt_service)")
    params.projection_years > 0 || error("projection_years must be positive; got $(params.projection_years)")
    params.n_simulations > 0 || error("n_simulations must be positive; got $(params.n_simulations)")
    0.0 <= params.revenue_volatility <= 1.0 || error("revenue_volatility must be between 0 and 1; got $(params.revenue_volatility)")
    0.0 <= params.expense_volatility <= 1.0 || error("expense_volatility must be between 0 and 1; got $(params.expense_volatility)")
    params.base_interest_rate >= 0.0 || error("base_interest_rate must be non-negative; got $(params.base_interest_rate)")
    params.rate_mean_reversion >= 0.0 || error("rate_mean_reversion must be non-negative; got $(params.rate_mean_reversion)")
    params.rate_volatility >= 0.0 || error("rate_volatility must be non-negative; got $(params.rate_volatility)")
    params.min_dscr_threshold > 0.0 || error("min_dscr_threshold must be positive; got $(params.min_dscr_threshold)")
    0.0 < params.target_confidence <= 1.0 || error("target_confidence must be in (0, 1]; got $(params.target_confidence)")

    rng = MersenneTwister(params.random_seed)

    ebitda = params.current_operating_income + params.current_depreciation
    current_dscr = params.current_debt_service > 0.0 ? ebitda / params.current_debt_service : Inf

    # Simulate minimum operating income across each path
    min_incomes = Vector{Float64}(undef, params.n_simulations)
    avg_rates = Vector{Float64}(undef, params.n_simulations)

    for sim in 1:params.n_simulations
        income_path = _simulate_operating_income(params, rng)
        rate_path = _simulate_interest_rate(params, rng)
        min_incomes[sim] = minimum(income_path)
        avg_rates[sim] = mean(rate_path)
    end

    # Find max debt service such that P(min_income / DS < threshold) <= (1 - confidence)
    # Equivalently, the (1-confidence) percentile of min_income / threshold gives max DS
    sort!(min_incomes)
    target_idx = max(1, ceil(Int, (1.0 - params.target_confidence) * params.n_simulations))
    stress_income = min_incomes[target_idx]
    max_annual_ds = stress_income / params.min_dscr_threshold

    # Max principal using annuity formula at median simulated rate
    median_rate = quantile(avg_rates, 0.50)
    max_principal = _annuity_principal(max(0.0, max_annual_ds), median_rate, params.projection_years)

    # DSCR distribution at current debt service level
    dscr_values = min_incomes ./ max(params.current_debt_service, 1.0)
    prob_below = count(d -> d < params.min_dscr_threshold, dscr_values) / params.n_simulations

    percentiles = Dict{Float64,Float64}()
    for p in [0.05, 0.25, 0.50, 0.75, 0.95]
        percentiles[p] = quantile(dscr_values, p)
    end

    credit_tier = _assign_credit_tier(get(percentiles, 0.05, 0.0))

    return DebtCapacityResult(
        max_annual_debt_service = max_annual_ds,
        max_debt_principal = max_principal,
        current_dscr = current_dscr,
        prob_dscr_below_threshold = prob_below,
        dscr_percentiles = percentiles,
        estimated_credit_tier = credit_tier,
    )
end

"""Sensitivity analysis varying base interest rate +/-200bp in 100bp steps."""
function debt_capacity_sensitivity(params::DebtCapacityParams)::Vector{NamedTuple}
    params.current_operating_income > 0.0 || error("current_operating_income must be positive; got $(params.current_operating_income)")
    params.base_interest_rate >= 0.0 || error("base_interest_rate must be non-negative; got $(params.base_interest_rate)")

    results = NamedTuple[]
    for bp_shift in [-200, -100, 0, 100, 200]
        shifted_rate = max(0.005, params.base_interest_rate + bp_shift / 10_000.0)
        shifted_params = DebtCapacityParams(
            current_operating_income = params.current_operating_income,
            current_depreciation = params.current_depreciation,
            current_debt_service = params.current_debt_service,
            projection_years = params.projection_years,
            n_simulations = params.n_simulations,
            revenue_volatility = params.revenue_volatility,
            expense_volatility = params.expense_volatility,
            base_interest_rate = shifted_rate,
            rate_mean_reversion = params.rate_mean_reversion,
            rate_volatility = params.rate_volatility,
            min_dscr_threshold = params.min_dscr_threshold,
            target_confidence = params.target_confidence,
            random_seed = params.random_seed,
        )
        result = calculate_debt_capacity(shifted_params)
        push!(results, (
            rate_shift_bp = bp_shift,
            base_rate = shifted_rate,
            max_annual_debt_service = result.max_annual_debt_service,
            max_debt_principal = result.max_debt_principal,
            estimated_credit_tier = result.estimated_credit_tier,
        ))
    end
    return results
end
