"""
    sfa.jl — Stochastic Frontier Analysis for Hospital Cost Efficiency (MBA Gap C-02)

Implements the half-normal SFA model (Aigner, Lovell & Schmidt 1977) with a
translog cost function — the standard specification in published rural hospital
efficiency studies.

The model decomposes the residual of a log-cost regression into:
  ln(C) = f(y, w) + v + u

where:
  f(y, w) = translog cost frontier (outputs y, input prices w)
  v ~ N(0, σ_v²)  = symmetric noise (measurement error, random shocks)
  u ~ N⁺(0, σ_u²) = one-sided inefficiency (always ≥ 0)

The efficiency score for hospital i: E[exp(−u_i) | ε_i] ∈ (0, 1].
  1.0 = on the cost frontier (fully efficient)
  0.85 = 15% cost inefficiency (could produce same outputs with 15% fewer costs)

## Translog cost function
ln(C) = α₀ + Σ_j α_j ln(y_j) + Σ_k β_k ln(w_k)
       + ½ Σ_j Σ_l δ_jl ln(y_j) ln(y_l)
       + ½ Σ_k Σ_m γ_km ln(w_k) ln(w_m)
       + Σ_j Σ_k φ_jk ln(y_j) ln(w_k)

For rural hospitals, typical outputs: inpatient discharges, ED visits, outpatient visits.
Typical input prices: labour (wages), capital (PPE/beds), supplies (COGS).

## Implementation note
Full ML estimation of SFA requires numerical optimisation (gradient descent or
Nelder-Mead on the log-likelihood). This implementation provides:
1. OLS translog cost estimation (unbiased for the systematic part).
2. Jondrow et al (1982) JLMS efficiency estimator from OLS residuals.
3. Summary statistics and efficiency rankings.

References:
- Aigner D, Lovell C, Schmidt P (1977). Formulation and estimation of SFA. J Econometrics.
- Battese G, Coelli T (1988). Prediction of firm-level technical efficiencies. J Econometrics.
- Jondrow J et al (1982). On the estimation of technical inefficiency. J Econometrics.
- Rosko M, Mutter R (2011). What have we learned from SFA applied to U.S. hospitals?
  Medical Care Research and Review 68(1 Suppl): 75S–100S.
"""

using Statistics
using LinearAlgebra
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# Input types
# ─────────────────────────────────────────────────────────────────────────────

"""
    SFAHospital

A single hospital observation for the SFA panel.

# Fields
- `id::Any`
- `total_cost::Float64`: Total operating costs (USD) — the dependent variable.
- `outputs::Dict{Symbol,Float64}`: Output quantities (discharges, ED visits, OP visits).
- `input_prices::Dict{Symbol,Float64}`: Input prices (wage index, capital price, supply price).
  At minimum: `:labour_price` and `:capital_price`.
- `year::Int`: Fiscal year (for panel data).
"""
@kwdef struct SFAHospital
    id::Any
    total_cost::Float64
    outputs::Dict{Symbol,Float64}
    input_prices::Dict{Symbol,Float64}
    year::Int = 2023
end

"""
    SFAResult

Efficiency estimates from stochastic frontier analysis.

# Fields
- `hospital_id::Any`
- `efficiency_score::Float64`: E[exp(−u)|ε] ∈ (0,1]. Higher = more efficient.
- `cost_inefficiency_pct::Float64`: `(1 - efficiency_score) × 100`.
- `excess_cost_usd::Float64`: Estimated dollar amount of inefficient spending.
- `frontier_cost_usd::Float64`: What the hospital would spend on the frontier.
- `residual::Float64`: OLS residual (v + u component).
- `efficiency_rank::Int`: Rank among peers (1 = most efficient).
"""
struct SFAResult
    hospital_id::Any
    efficiency_score::Float64
    cost_inefficiency_pct::Float64
    excess_cost_usd::Float64
    frontier_cost_usd::Float64
    residual::Float64
    efficiency_rank::Int
end

"""
    SFAAnalysis

Complete SFA analysis output.

# Fields
- `results::Vector{SFAResult}`: Sorted by efficiency_score descending.
- `lambda::Float64`: λ = σ_u / σ_v (signal-to-noise ratio; λ > 1 = inefficiency dominates).
- `sigma_u::Float64`, `sigma_v::Float64`, `sigma_sq::Float64`
- `mean_efficiency::Float64`
- `median_efficiency::Float64`
- `n_efficient_hospitals::Int`: Score ≥ 0.90.
- `total_excess_cost_usd::Float64`: System-wide inefficiency cost.
- `model_specification::String`
- `n_observations::Int`
"""
struct SFAAnalysis
    results::Vector{SFAResult}
    lambda::Float64
    sigma_u::Float64
    sigma_v::Float64
    sigma_sq::Float64
    mean_efficiency::Float64
    median_efficiency::Float64
    n_efficient_hospitals::Int
    total_excess_cost_usd::Float64
    model_specification::String
    n_observations::Int
end

# ─────────────────────────────────────────────────────────────────────────────
# Translog design matrix builder
# ─────────────────────────────────────────────────────────────────────────────

"""
    build_translog_matrix(hospitals; output_keys, price_keys) -> Matrix{Float64}

Build the translog design matrix (log variables + interaction terms).

Columns: [1, ln(y₁), ..., ln(yₙ), ln(w₁), ..., ln(wₘ),
           ½ln(y₁)², ln(y₁)ln(y₂), ..., ½ln(y₁)ln(w₁), ...]
"""
function build_translog_matrix(
    hospitals::Vector{SFAHospital};
    output_keys::Vector{Symbol},
    price_keys::Vector{Symbol},
)::Tuple{Matrix{Float64}, Vector{Float64}}

    n  = length(hospitals)
    ny = length(output_keys)
    nw = length(price_keys)

    # Number of columns: intercept + ny + nw + ny(ny+1)/2 + nw(nw+1)/2 + ny×nw
    n_second_order = ny*(ny+1)÷2 + nw*(nw+1)÷2 + ny*nw
    ncols = 1 + ny + nw + n_second_order

    X = zeros(n, ncols)
    y = zeros(n)

    for (i, h) in enumerate(hospitals)
        ln_y = [log(max(h.outputs[k],  1.0)) for k in output_keys]
        ln_w = [log(max(h.input_prices[k], 1.0)) for k in price_keys]
        y[i] = log(max(h.total_cost, 1.0))

        col = 1
        X[i, col] = 1.0; col += 1
        for v in vcat(ln_y, ln_w); X[i, col] = v; col += 1; end

        # Second-order output terms
        for a in 1:ny, b in a:ny
            X[i, col] = 0.5 * ln_y[a] * ln_y[b]; col += 1
        end
        # Second-order price terms
        for a in 1:nw, b in a:nw
            X[i, col] = 0.5 * ln_w[a] * ln_w[b]; col += 1
        end
        # Cross output-price terms
        for a in 1:ny, b in 1:nw
            X[i, col] = ln_y[a] * ln_w[b]; col += 1
        end
    end

    X, y
end

# ─────────────────────────────────────────────────────────────────────────────
# JLMS efficiency estimator
# ─────────────────────────────────────────────────────────────────────────────

"""
    jlms_efficiency(residuals; lambda_init=1.0) -> NamedTuple

Apply the Jondrow-Lovell-Materov-Schmidt (JLMS 1982) estimator to OLS
residuals from the translog frontier regression.

The JLMS estimator for the conditional mean of the inefficiency term:
  E[u_i | ε_i] = σ_* × [φ(μ_*i / σ_*) / Φ(μ_*i / σ_*) + μ_*i / σ_*]

where:
  ε_i = residual (v_i + u_i)
  σ² = σ_u² + σ_v²
  λ = σ_u / σ_v
  μ_*i = −ε_i × σ_u² / σ²
  σ_* = σ_u × σ_v / σ

The efficiency score: E[exp(−u_i) | ε_i].

Returns σ_u, σ_v, λ, and efficiency scores for each observation.
"""
function jlms_efficiency(residuals::Vector{Float64}; lambda_init::Float64 = 1.0)
    n = length(residuals)
    # Method of moments: estimate σ² and skewness
    ε = residuals
    m2 = mean(ε.^2)
    m3 = mean(ε.^3)  # should be negative for cost frontier (u ≥ 0 skews ε right)

    # Moment conditions: σ² = σ_v² + σ_u², skewness from half-normal
    # σ_u² estimated from skewness (simplified MOM)
    b = (2.0/π)^0.5
    σ_u_sq = abs(m3 / b)^(2.0/3.0)
    σ_u = sqrt(max(σ_u_sq, 1e-9))
    σ_v_sq = max(m2 - σ_u_sq, 1e-9)
    σ_v    = sqrt(σ_v_sq)
    λ      = σ_u / σ_v
    σ_sq   = σ_u_sq + σ_v_sq
    σ      = sqrt(σ_sq)
    σ_star = σ_u * σ_v / σ

    # JLMS conditional mean of u_i
    efficiency_scores = map(ε) do ε_i
        μ_star = -ε_i * σ_u_sq / σ_sq
        # Use Normal CDF and PDF
        z = μ_star / σ_star
        φ_z = exp(-0.5 * z^2) / sqrt(2π)
        Φ_z = 0.5 * erfc(-z / sqrt(2))
        Φ_z = max(Φ_z, 1e-12)
        E_u = σ_star * (φ_z / Φ_z + z)
        exp(-max(E_u, 0.0))   # efficiency score
    end

    (
        efficiency_scores = efficiency_scores,
        sigma_u = σ_u,
        sigma_v = σ_v,
        lambda  = λ,
        sigma_sq = σ_sq,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Main SFA function
# ─────────────────────────────────────────────────────────────────────────────

"""
    run_sfa(
        hospitals::Vector{SFAHospital};
        output_keys, price_keys
    ) -> SFAAnalysis

Run stochastic frontier analysis on a panel of hospitals.

## Minimum requirements
- At least 5 hospitals (more = better identification).
- Consistent output and price keys across all hospitals.
- Typical specification for rural CAHs:
  - Outputs: `:inpatient_discharges`, `:ed_visits`, `:outpatient_visits`
  - Prices: `:labour_price`, `:capital_price`

# Example
```julia
hospitals = [
    SFAHospital(id="CAH-001", total_cost=7_500_000,
        outputs=Dict(:discharges=>620, :ed_visits=>4200, :op_visits=>12800),
        input_prices=Dict(:labour_price=>52.0, :capital_price=>1.8)),
    # ... more hospitals
]
analysis = run_sfa(hospitals; output_keys=[:discharges,:ed_visits,:op_visits],
                              price_keys=[:labour_price,:capital_price])
for r in analysis.results
    println(r.hospital_id, ": ", round(r.efficiency_score*100, digits=1), "%")
end
```
"""
function run_sfa(
    hospitals::Vector{SFAHospital};
    output_keys::Vector{Symbol} = [:inpatient_discharges, :ed_visits],
    price_keys::Vector{Symbol}  = [:labour_price, :capital_price],
)::SFAAnalysis
    length(hospitals) >= 5 ||
        throw(ArgumentError("SFA requires at least 5 hospitals; got $(length(hospitals))"))

    # Check all hospitals have required keys
    for h in hospitals
        for k in output_keys
            haskey(h.outputs, k) ||
                throw(ArgumentError("Hospital $(h.id) missing output key :$k"))
        end
        for k in price_keys
            haskey(h.input_prices, k) ||
                throw(ArgumentError("Hospital $(h.id) missing price key :$k"))
        end
    end

    # Build design matrix
    X, ln_cost = build_translog_matrix(hospitals; output_keys=output_keys, price_keys=price_keys)

    # OLS regression: β̂ = (X'X)⁻¹ X'y
    XtX = X' * X
    Xty = X' * ln_cost
    β̂ = try
        XtX \ Xty
    catch
        # Ridge fallback for near-singular matrices (small samples)
        (XtX + 1e-6 * I) \ Xty
    end

    residuals = ln_cost - X * β̂

    # JLMS efficiency estimation
    jlms = jlms_efficiency(residuals)
    eff_scores = jlms.efficiency_scores

    # Build results
    sorted_idx = sortperm(eff_scores; rev=true)
    results = map(1:length(hospitals)) do rank
        idx = sorted_idx[rank]
        h   = hospitals[idx]
        eff = eff_scores[idx]
        frontier_cost = h.total_cost * eff
        excess        = h.total_cost - frontier_cost
        SFAResult(
            h.id, eff, (1 - eff) * 100, excess, frontier_cost,
            residuals[idx], rank,
        )
    end

    model_spec = "Translog cost frontier | Outputs: $(join(output_keys, ", ")) | " *
                 "Input prices: $(join(price_keys, ", "))"

    SFAAnalysis(
        results,
        jlms.lambda, jlms.sigma_u, jlms.sigma_v, jlms.sigma_sq,
        mean(eff_scores), median(eff_scores),
        count(e -> e >= 0.90, eff_scores),
        sum(h.total_cost * (1 - eff_scores[i]) for (i,h) in enumerate(hospitals)),
        model_spec,
        length(hospitals),
    )
end
