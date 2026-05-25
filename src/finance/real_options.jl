# Real Options Valuation — Black-Scholes-Merton
#
# Values strategic flexibility (option to expand, defer, abandon) using the
# BSM framework with continuous convenience yield. Useful for evaluating
# hospital expansion decisions, equipment investments, and service line launches.

"""
    RealOptionInput

Input parameters for Black-Scholes-Merton real option valuation.

Fields:
- `underlying_value` — present value of the project's expected cash flows (S)
- `exercise_price` — investment cost required to exercise (K)
- `time_to_expiry` — time until the option expires, in years (T)
- `risk_free_rate` — continuously compounded risk-free rate (r)
- `volatility` — annualized volatility of the underlying value (σ)
- `convenience_yield` — continuous dividend/convenience yield (q), default 0.0
"""
@kwdef struct RealOptionInput
    underlying_value::Float64
    exercise_price::Float64
    time_to_expiry::Float64
    risk_free_rate::Float64
    volatility::Float64
    convenience_yield::Float64 = 0.0
end

"""
    RealOptionResult

Result of BSM real option valuation including price and Greeks.
"""
@kwdef struct RealOptionResult
    call_value::Float64
    put_value::Float64
    d1::Float64
    d2::Float64
    delta::Float64
    gamma::Float64
    vega::Float64
    theta::Float64
end

function Base.show(io::IO, r::RealOptionResult)
    print(io, "RealOptionResult(call=$(round(r.call_value, digits=2)), put=$(round(r.put_value, digits=2)), delta=$(round(r.delta, digits=3)))")
end

"""
    _standard_normal_cdf(x::Float64) -> Float64

Standard normal CDF using the Distributions.jl Normal distribution.
"""
function _standard_normal_cdf(x::Float64)::Float64
    return cdf(Normal(0.0, 1.0), x)
end

"""
    _standard_normal_pdf(x::Float64) -> Float64

Standard normal probability density function.
"""
function _standard_normal_pdf(x::Float64)::Float64
    return exp(-0.5 * x^2) / sqrt(2.0 * π)
end

"""
    calculate_real_option(input::RealOptionInput) -> RealOptionResult

Compute call and put values plus Greeks using the Black-Scholes-Merton model
with continuous convenience yield.

d1 = [ln(S/K) + (r - q + σ²/2) * T] / (σ√T)
d2 = d1 - σ√T

Call = S * e^(-qT) * N(d1) - K * e^(-rT) * N(d2)
Put  = K * e^(-rT) * N(-d2) - S * e^(-qT) * N(-d1)

Note: The returned Greeks (delta, gamma, vega, theta) correspond to the **call** option,
following standard BSM convention.
"""
function calculate_real_option(input::RealOptionInput)::RealOptionResult
    input.underlying_value > 0.0 || error("underlying_value must be positive")
    input.exercise_price > 0.0 || error("exercise_price must be positive")
    input.time_to_expiry > 0.0 || error("time_to_expiry must be positive")
    input.volatility > 0.0 || error("volatility must be positive")

    S = input.underlying_value
    K = input.exercise_price
    T = input.time_to_expiry
    r = input.risk_free_rate
    σ = input.volatility
    q = input.convenience_yield

    sqrt_t = sqrt(T)
    σ_sqrt_t = σ * sqrt_t

    d1 = (log(S / K) + (r - q + 0.5 * σ^2) * T) / σ_sqrt_t
    d2 = d1 - σ_sqrt_t

    nd1 = _standard_normal_cdf(d1)
    nd2 = _standard_normal_cdf(d2)
    n_neg_d1 = _standard_normal_cdf(-d1)
    n_neg_d2 = _standard_normal_cdf(-d2)
    pdf_d1 = _standard_normal_pdf(d1)

    disc_q = exp(-q * T)
    disc_r = exp(-r * T)

    call_value = S * disc_q * nd1 - K * disc_r * nd2
    put_value = K * disc_r * n_neg_d2 - S * disc_q * n_neg_d1

    # Greeks (call-side; put delta = delta - e^(-qT), put theta differs by +rKe^(-rT))
    delta = disc_q * nd1
    gamma = disc_q * pdf_d1 / (S * σ_sqrt_t)
    vega = S * disc_q * pdf_d1 * sqrt_t / 100.0  # per 1% vol change
    theta = (-(S * disc_q * pdf_d1 * σ / (2.0 * sqrt_t)) -
              r * K * disc_r * nd2 +
              q * S * disc_q * nd1) / 365.0  # per calendar day

    return RealOptionResult(
        call_value = call_value,
        put_value = put_value,
        d1 = d1,
        d2 = d2,
        delta = delta,
        gamma = gamma,
        vega = vega,
        theta = theta,
    )
end
