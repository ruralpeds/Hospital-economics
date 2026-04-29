"""
    real_options.jl — Real Options Valuation for Hospital Service Lines (MBA Gap A-06)

Provides three complementary real-options frameworks for hospital capital
and strategic decisions:

1. **Black-Scholes-Merton (BSM)** — closed-form for continuous-time options
   on service-line value (expand, abandon, switch). Best for quick screening.

2. **Binomial lattice** — discrete-time CRR tree for American-style options
   (early-exercise rights). Better for options with irregular cash flows or
   multiple interacting decisions.

3. **Service-line decision framework** — wraps BSM and binomial with
   hospital-specific scenarios: option to expand OB service line, option to
   abandon inpatient, option to convert CAH → REH.

All monetary values in USD. All rates decimal (0.05 = 5%).

References:
- Cox, Ross, Rubinstein (1979) CRR binomial model
- Black & Scholes (1973); Merton (1973)
- Copeland & Antikarov (2001) for real-asset volatility estimation
- Trigeorgis (1996) real options in capital investment
"""

using Statistics

# ─────────────────────────────────────────────────────────────────────────────
# Normal CDF helper (no external dependency)
# ─────────────────────────────────────────────────────────────────────────────

"""
    _Φ(x) — standard normal CDF via rational approximation (Abramowitz & Stegun).
    Max error < 7.5×10⁻⁸.
"""
function _Φ(x::Float64)::Float64
    x >= 0.0 || return 1.0 - _Φ(-x)
    t = 1.0 / (1.0 + 0.2316419 * x)
    poly = t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 +
           t * (-1.821255978 + t * 1.330274429))))
    1.0 - (1.0 / sqrt(2π)) * exp(-0.5 * x^2) * poly
end

# ─────────────────────────────────────────────────────────────────────────────
# Black-Scholes-Merton
# ─────────────────────────────────────────────────────────────────────────────

"""
    RealOptionBSM

Inputs for a Black-Scholes-Merton real option.

# Fields
- `S::Float64`: Current value of the underlying asset (PV of cash flows from
  the project / service line). USD.
- `K::Float64`: Exercise price (investment required to expand, or salvage from
  abandonment). USD.
- `T::Float64`: Time to expiry in years (decision horizon).
- `r::Float64`: Risk-free rate (decimal).
- `σ::Float64`: Volatility of the underlying asset value (decimal, annualised).
  For real assets, estimated from Monte Carlo of project value — typically 0.15–0.35
  for rural hospital service lines.
- `δ::Float64`: Convenience yield / opportunity cost of waiting (analogous to
  dividend yield). Represents cash flows foregone while holding the option.
- `option_type::Symbol`: `:call` (option to expand / invest) or `:put` (option to abandon).
"""
@kwdef struct RealOptionBSM
    S::Float64                      # Underlying value ($)
    K::Float64                      # Strike / investment cost ($)
    T::Float64                      # Time to expiry (years)
    r::Float64 = 0.043              # Risk-free rate
    σ::Float64 = 0.25               # Asset volatility
    δ::Float64 = 0.0                # Convenience yield
    option_type::Symbol = :call
end

"""
    BSMResult

Output of `bsm_real_option`.

# Fields
- `option_value::Float64`: Option value (USD).
- `d1`, `d2`: BSM intermediate values (for Greeks computation).
- `delta::Float64`: ∂V/∂S — sensitivity to 1% change in underlying value.
- `intrinsic_value::Float64`: max(S−K, 0) for call; max(K−S, 0) for put.
- `time_value::Float64`: Option premium above intrinsic value.
"""
struct BSMResult
    option_value::Float64
    d1::Float64
    d2::Float64
    delta::Float64
    intrinsic_value::Float64
    time_value::Float64
end

"""
    bsm_real_option(opt::RealOptionBSM) -> BSMResult

Price a European-style real option using Black-Scholes-Merton.

For **expansion options** (`:call`): right to invest K and receive asset worth S.
  Value = S·e^{−δT}·Φ(d₁) − K·e^{−rT}·Φ(d₂)

For **abandonment options** (`:put`): right to sell asset for K (salvage).
  Value = K·e^{−rT}·Φ(−d₂) − S·e^{−δT}·Φ(−d₁)

# Assumptions
- European exercise (BSM cannot price early exercise; use `binomial_real_option` for that).
- Asset volatility `σ` must be estimated externally (Monte Carlo on project DCF is standard).

# Example
```julia
opt = RealOptionBSM(S=8_000_000, K=5_000_000, T=3.0, σ=0.28)
r = bsm_real_option(opt)
r.option_value   # value of the right to expand, exercisable in 3 years
```
"""
function bsm_real_option(opt::RealOptionBSM)::BSMResult
    opt.T > 0 || throw(ArgumentError("T must be > 0"))
    opt.σ > 0 || throw(ArgumentError("σ must be > 0"))
    opt.S > 0 || throw(ArgumentError("S must be > 0"))
    opt.K > 0 || throw(ArgumentError("K must be > 0"))

    S, K, T, r, σ, δ = opt.S, opt.K, opt.T, opt.r, opt.σ, opt.δ

    sqrtT = sqrt(T)
    d1 = (log(S / K) + (r - δ + 0.5 * σ^2) * T) / (σ * sqrtT)
    d2 = d1 - σ * sqrtT

    if opt.option_type == :call
        V     = S * exp(-δ * T) * _Φ(d1) - K * exp(-r * T) * _Φ(d2)
        delta = exp(-δ * T) * _Φ(d1)
        intrinsic = max(S - K, 0.0)
    elseif opt.option_type == :put
        V     = K * exp(-r * T) * _Φ(-d2) - S * exp(-δ * T) * _Φ(-d1)
        delta = -exp(-δ * T) * _Φ(-d1)
        intrinsic = max(K - S, 0.0)
    else
        throw(ArgumentError("option_type must be :call or :put"))
    end

    BSMResult(V, d1, d2, delta, intrinsic, V - intrinsic)
end

# ─────────────────────────────────────────────────────────────────────────────
# Binomial lattice (CRR) — American-style real options
# ─────────────────────────────────────────────────────────────────────────────

"""
    RealOptionBinomial

Parameters for a CRR binomial lattice real option.

Adds to the BSM inputs:
- `n_steps::Int`: Number of time steps (more = more accurate; 50–200 typical).
- `american::Bool`: `true` → American-style (early exercise allowed); `false` → European.
- `exercise_cash_flow::Union{Nothing, Float64}`: Optional fixed cash flow received on
  exercise (e.g. annual cash flow from the new service line). If `nothing`, standard
  BSM-equivalent payoff S − K is used.
"""
@kwdef struct RealOptionBinomial
    S::Float64
    K::Float64
    T::Float64
    r::Float64 = 0.043
    σ::Float64 = 0.25
    δ::Float64 = 0.0
    n_steps::Int = 100
    american::Bool = true
    option_type::Symbol = :call
end

"""
    BinomialResult

Output of `binomial_real_option`.

# Fields
- `option_value::Float64`
- `delta::Float64`: Hedge ratio at the root node.
- `bsm_reference::Float64`: European BSM value for comparison.
- `early_exercise_premium::Float64`: `option_value − bsm_reference` (>0 for American).
"""
struct BinomialResult
    option_value::Float64
    delta::Float64
    bsm_reference::Float64
    early_exercise_premium::Float64
end

"""
    binomial_real_option(opt::RealOptionBinomial) -> BinomialResult

Price a real option using the CRR binomial lattice. Supports American-style
early exercise, which is critical for real options where the manager can
exercise at any point during the decision horizon.

# Algorithm (CRR)
u = e^{σ√Δt}, d = 1/u, p = (e^{(r−δ)Δt} − d) / (u − d)
Roll back from terminal payoffs, applying early-exercise comparison at each node.

# Example
```julia
opt = RealOptionBinomial(S=8_000_000, K=5_000_000, T=3.0, σ=0.28,
                         american=true, n_steps=200)
r = binomial_real_option(opt)
r.option_value               # American call value
r.early_exercise_premium     # extra value vs European
```
"""
function binomial_real_option(opt::RealOptionBinomial)::BinomialResult
    opt.T > 0 || throw(ArgumentError("T must be > 0"))
    opt.σ > 0 || throw(ArgumentError("σ must be > 0"))
    opt.n_steps >= 2 || throw(ArgumentError("n_steps must be ≥ 2"))

    n = opt.n_steps
    dt = opt.T / n
    u  = exp(opt.σ * sqrt(dt))
    d  = 1.0 / u
    p  = (exp((opt.r - opt.δ) * dt) - d) / (u - d)
    df = exp(-opt.r * dt)

    # Terminal asset values (vectorised)
    asset_terminal = [opt.S * u^(n - 2j) for j in 0:n]

    # Terminal option payoffs
    if opt.option_type == :call
        V = max.(asset_terminal .- opt.K, 0.0)
    else
        V = max.(opt.K .- asset_terminal, 0.0)
    end

    # Backward induction
    for step in n-1:-1:0
        V_new = Vector{Float64}(undef, step + 1)
        for j in 0:step
            continuation = df * (p * V[j+1] + (1-p) * V[j+2])
            if opt.american
                S_node = opt.S * u^(step - 2j)
                exercise = opt.option_type == :call ? max(S_node - opt.K, 0.0) :
                                                      max(opt.K - S_node, 0.0)
                V_new[j+1] = max(continuation, exercise)
            else
                V_new[j+1] = continuation
            end
        end
        V = V_new
    end

    american_val = V[1]

    # European BSM reference
    bsm_in = RealOptionBSM(S=opt.S, K=opt.K, T=opt.T, r=opt.r, σ=opt.σ,
                            δ=opt.δ, option_type=opt.option_type)
    euro_val = bsm_real_option(bsm_in).option_value

    delta = length(V) >= 2 ?
        (V[1] - V[2]) / (opt.S * u - opt.S * d) : NaN

    BinomialResult(american_val, delta, euro_val, american_val - euro_val)
end

# ─────────────────────────────────────────────────────────────────────────────
# Hospital service-line decision framework
# ─────────────────────────────────────────────────────────────────────────────

"""
    ServiceLineOption

A named real option on a hospital service line.

# Fields
- `name::String`: Descriptive name (e.g. "Expand OB", "Abandon Inpatient", "CAH→REH").
- `option_type::Symbol`: `:expand`, `:abandon`, `:switch`, `:defer`.
- `underlying_value::Float64`: PV of cash flows from the service line (USD).
- `investment_or_salvage::Float64`: Capital required to expand, or salvage value to abandon.
- `decision_horizon_years::Float64`: Years until the decision must be made.
- `annual_cash_flow::Float64`: Annual net cash flow from the service line (for convenience yield).
- `asset_volatility::Float64`: Annualised volatility of service-line value (decimal).
- `risk_free_rate::Float64`: Risk-free rate (decimal).
- `use_american::Bool = true`: Use binomial (American) vs BSM (European).
- `n_binomial_steps::Int = 100`: Binomial lattice steps if `use_american`.
"""
@kwdef struct ServiceLineOption
    name::String
    option_type::Symbol                    # :expand | :abandon | :switch | :defer
    underlying_value::Float64
    investment_or_salvage::Float64
    decision_horizon_years::Float64
    annual_cash_flow::Float64              = 0.0
    asset_volatility::Float64              = 0.25
    risk_free_rate::Float64                = 0.043
    use_american::Bool                     = true
    n_binomial_steps::Int                  = 100
end

"""
    ServiceLineOptionResult

Valuation output for a `ServiceLineOption`.

# Fields
- `option`: input parameters
- `option_value::Float64`: Computed real option value (USD).
- `npv_static::Float64`: Static NPV (underlying_value − investment or + salvage).
- `strategic_premium::Float64`: option_value − max(npv_static, 0) — the value
  of managerial flexibility above the static NPV.
- `method::Symbol`: `:binomial` or `:bsm`.
- `recommendation::Symbol`: `:exercise_now`, `:hold_option`, or `:abandon_option`.
- `recommendation_rationale::String`
"""
struct ServiceLineOptionResult
    option::ServiceLineOption
    option_value::Float64
    npv_static::Float64
    strategic_premium::Float64
    method::Symbol
    recommendation::Symbol
    recommendation_rationale::String
end

"""
    value_service_line_option(opt::ServiceLineOption) -> ServiceLineOptionResult

Value a hospital service-line real option and produce an actionable recommendation.

Maps `:expand`/`:defer` → call option; `:abandon` → put option; `:switch` → call
on the difference in values.

The **convenience yield** δ is estimated as `annual_cash_flow / underlying_value`
(cash flows foregone while waiting).
"""
function value_service_line_option(opt::ServiceLineOption)::ServiceLineOptionResult
    # Map service-line option type to financial option type
    fin_type = opt.option_type in (:expand, :defer, :switch) ? :call : :put

    # Convenience yield from annual cash flows
    δ = opt.underlying_value > 0 ? opt.annual_cash_flow / opt.underlying_value : 0.0
    δ = clamp(δ, 0.0, 0.20)

    if opt.use_american
        bin_opt = RealOptionBinomial(
            S = opt.underlying_value,
            K = opt.investment_or_salvage,
            T = opt.decision_horizon_years,
            r = opt.risk_free_rate,
            σ = opt.asset_volatility,
            δ = δ,
            n_steps = opt.n_binomial_steps,
            american = true,
            option_type = fin_type,
        )
        result = binomial_real_option(bin_opt)
        opt_val = result.option_value
        method  = :binomial
    else
        bsm_opt = RealOptionBSM(
            S = opt.underlying_value,
            K = opt.investment_or_salvage,
            T = opt.decision_horizon_years,
            r = opt.risk_free_rate,
            σ = opt.asset_volatility,
            δ = δ,
            option_type = fin_type,
        )
        result = bsm_real_option(bsm_opt)
        opt_val = result.option_value
        method  = :bsm
    end

    # Static NPV
    static_npv = fin_type == :call ?
        (opt.underlying_value - opt.investment_or_salvage) :
        (opt.investment_or_salvage - opt.underlying_value)

    strategic_premium = opt_val - max(static_npv, 0.0)

    # Recommendation
    rec, rationale = if static_npv >= opt_val * 0.90
        (:exercise_now,
         "Static NPV ($(round(static_npv/1e6,digits=2))M) close to or exceeds option value — " *
         "delay has minimal value; consider exercising the $(opt.option_type) decision now.")
    elseif opt_val <= 0
        (:abandon_option,
         "Option has near-zero value; the $(opt.option_type) decision is not worth pursuing.")
    else
        (:hold_option,
         "Strategic premium of \$$(round(strategic_premium/1e3,digits=0))k from flexibility. " *
         "Hold option and monitor — exercise when uncertainty resolves.")
    end

    ServiceLineOptionResult(opt, opt_val, static_npv, strategic_premium, method, rec, rationale)
end

"""
    hospital_real_options_portfolio(options::Vector{ServiceLineOption}) -> Vector{ServiceLineOptionResult}

Value a portfolio of hospital real options and return results sorted by
`option_value` descending (highest strategic value first).
"""
function hospital_real_options_portfolio(
    options::Vector{ServiceLineOption},
)::Vector{ServiceLineOptionResult}
    results = [value_service_line_option(o) for o in options]
    sort(results; by = r -> -r.option_value)
end

# ─────────────────────────────────────────────────────────────────────────────
# Volatility estimation helper
# ─────────────────────────────────────────────────────────────────────────────

"""
    estimate_real_asset_volatility(annual_cash_flows::Vector{Float64};
                                   drift_adjustment=true) -> Float64

Estimate the annualised volatility of a real asset's value from historical
annual cash-flow data, using the project-returns approach of
Copeland & Antikarov (2001).

Returns: annualised σ (decimal) of the natural-log returns of asset value
proxied by cumulative cash flows.

Requires at least 3 observations; more is better (typical CAH: 5–10 years).

# Example
```julia
noi_history = [280_000, 315_000, 295_000, 340_000, 290_000, 325_000]
σ = estimate_real_asset_volatility(noi_history)
# Use σ in RealOptionBSM or RealOptionBinomial
```
"""
function estimate_real_asset_volatility(
    annual_cash_flows::Vector{Float64};
    drift_adjustment::Bool = true,
)::Float64
    length(annual_cash_flows) >= 3 ||
        throw(ArgumentError("Need at least 3 annual cash flows to estimate volatility"))
    all(annual_cash_flows .> 0) ||
        throw(ArgumentError("All cash flows must be positive for log-return estimation"))

    log_returns = diff(log.(annual_cash_flows))
    σ = std(log_returns)
    drift_adjustment && (σ *= sqrt(length(log_returns) / (length(log_returns) - 1)))
    σ
end
