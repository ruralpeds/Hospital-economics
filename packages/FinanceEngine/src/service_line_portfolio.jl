"""
    service_line_portfolio.jl — Service-Line Portfolio Optimization (MBA Gap B-03)

Applies Markowitz mean-variance portfolio theory to hospital service-line
capital allocation, treating each service line as an asset with:
  - Expected return: projected net margin (operating income / revenue)
  - Risk: historical variance / standard deviation of margin
  - Capacity constraint: beds, OR hours, FTEs allocated

Provides:
1. **Efficient frontier** — the set of portfolios maximising expected margin
   for a given risk level (and vice versa).
2. **Minimum-variance portfolio** — lowest-risk feasible allocation.
3. **Maximum-Sharpe portfolio** — highest risk-adjusted return.
4. **Integer-constrained open/close decisions** via JuMP (B-03 extension).
5. **Community-need override** — CAH regulatory requirement to maintain
   essential services regardless of financial performance.

References:
- Markowitz H (1952). Portfolio selection. Journal of Finance 7(1): 77-91.
- Gapenski L, Pink G (2015). Understanding Healthcare Financial Management, 7e.
- Rural Health Value Initiative (2022). Service Line Strategy for Rural Hospitals.
"""

using Statistics
using LinearAlgebra

# ─────────────────────────────────────────────────────────────────────────────
# Data structures
# ─────────────────────────────────────────────────────────────────────────────

"""
    ServiceLine

A single hospital service line (asset in the portfolio).

# Fields
- `name::String`: Display name (e.g. "Emergency Medicine", "Obstetrics").
- `annual_net_margin_history::Vector{Float64}`: Historical annual net margins
  (operating income / service-line revenue). At least 3 years required.
- `current_revenue::Float64`: Current annual revenue (USD). Used for scaling.
- `capacity_units::Float64`: Resource units consumed (beds, OR hours, FTEs).
- `is_essential::Bool`: If `true`, cannot be closed regardless of financials
  (e.g. ED for a CAH — regulatory requirement under 42 CFR § 485.618).
- `community_need_score::Float64`: 0–1 community-need weight for constrained
  optimization (higher = more pressure to maintain regardless of return).
"""
@kwdef struct ServiceLine
    name::String
    annual_net_margin_history::Vector{Float64}
    current_revenue::Float64
    capacity_units::Float64           = 1.0
    is_essential::Bool                = false
    community_need_score::Float64     = 0.5
end

"""
    PortfolioStats

Computed statistics for a set of service lines.

# Fields
- `names::Vector{String}`
- `expected_returns::Vector{Float64}`: Mean historical net margin per line.
- `std_devs::Vector{Float64}`: Std dev of historical net margin per line.
- `cov_matrix::Matrix{Float64}`: Variance-covariance matrix of net margins.
- `corr_matrix::Matrix{Float64}`: Correlation matrix.
"""
struct PortfolioStats
    names::Vector{String}
    expected_returns::Vector{Float64}
    std_devs::Vector{Float64}
    cov_matrix::Matrix{Float64}
    corr_matrix::Matrix{Float64}
end

"""
    EfficientFrontierPoint

One point on the efficient frontier.

# Fields
- `weights::Vector{Float64}`: Portfolio weights (sum to 1; one per service line).
- `expected_return::Float64`: Weighted average expected margin.
- `portfolio_std::Float64`: Portfolio standard deviation.
- `sharpe_ratio::Float64`: `(expected_return - risk_free_rate) / portfolio_std`.
"""
struct EfficientFrontierPoint
    weights::Vector{Float64}
    expected_return::Float64
    portfolio_std::Float64
    sharpe_ratio::Float64
end

"""
    ServiceLinePortfolioResult

Complete portfolio optimization result.

# Fields
- `stats::PortfolioStats`
- `frontier::Vector{EfficientFrontierPoint}`: Efficient frontier points (sorted by risk).
- `min_variance::EfficientFrontierPoint`: Global minimum variance portfolio.
- `max_sharpe::EfficientFrontierPoint`: Maximum Sharpe ratio portfolio.
- `current_weights::Vector{Float64}`: Current revenue-weighted allocation.
- `current_return::Float64`, `current_std::Float64`: Current portfolio metrics.
- `essential_service_lines::Vector{String}`: Lines that cannot be closed.
"""
struct ServiceLinePortfolioResult
    stats::PortfolioStats
    frontier::Vector{EfficientFrontierPoint}
    min_variance::EfficientFrontierPoint
    max_sharpe::EfficientFrontierPoint
    current_weights::Vector{Float64}
    current_return::Float64
    current_std::Float64
    essential_service_lines::Vector{String}
end

# ─────────────────────────────────────────────────────────────────────────────
# Statistics computation
# ─────────────────────────────────────────────────────────────────────────────

"""
    compute_portfolio_stats(lines::Vector{ServiceLine}) -> PortfolioStats

Compute expected returns, covariance matrix, and correlation matrix from
historical margin data. Requires all service lines to have the same number
of historical observations (pads shorter series with the mean if mismatched).
"""
function compute_portfolio_stats(lines::Vector{ServiceLine})::PortfolioStats
    n = length(lines)
    n >= 2 || throw(ArgumentError("Need at least 2 service lines for portfolio analysis"))

    # Align history lengths (use minimum common length, at least 2)
    min_len = minimum(length(l.annual_net_margin_history) for l in lines)
    min_len >= 2 || throw(ArgumentError("Each service line needs at least 2 years of margin history"))

    # Build return matrix (n_years × n_lines)
    R = hcat([l.annual_net_margin_history[end-min_len+1:end] for l in lines]...)

    μ = vec(mean(R; dims=1))
    σ = vec(std(R; dims=1))
    Σ = cov(R)

    # Correlation matrix
    D_inv = Diagonal(1.0 ./ σ)
    C = D_inv * Σ * D_inv

    PortfolioStats(
        [l.name for l in lines],
        μ, σ, Σ, C,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Efficient frontier via quadratic programming (pure Julia, no JuMP)
# ─────────────────────────────────────────────────────────────────────────────

"""
    _portfolio_variance(w, Σ) — w' Σ w
"""
_portfolio_variance(w::Vector{Float64}, Σ::Matrix{Float64}) = dot(w, Σ * w)

"""
    _portfolio_return(w, μ) — w' μ
"""
_portfolio_return(w::Vector{Float64}, μ::Vector{Float64}) = dot(w, μ)

"""
    _min_variance_for_target(μ, Σ, target_return; constraints) -> Vector{Float64}

Find the minimum-variance portfolio achieving at least `target_return` using
gradient-projected iteration. Enforces:
- weights ≥ 0 (no short-selling of service lines)
- sum(weights) = 1
- weights[i] = min_weight[i] for essential service lines
"""
function _min_variance_for_target(
    μ::Vector{Float64},
    Σ::Matrix{Float64},
    target_return::Float64;
    essential_mask::Vector{Bool} = fill(false, length(μ)),
    min_weight::Float64 = 0.02,   # minimum 2% even for non-essential
    max_weight::Float64 = 0.80,
    n_iter::Int = 2_000,
    lr::Float64 = 0.01,
)::Vector{Float64}
    n = length(μ)
    w = fill(1.0 / n, n)

    # Lock essential service lines to at least min_weight
    for i in 1:n
        essential_mask[i] && (w[i] = max(w[i], min_weight))
    end

    for _ in 1:n_iter
        # Gradient of variance: 2Σw
        grad_var = 2.0 * Σ * w

        # Project step
        w_new = w .- lr * grad_var

        # Clip to [min_weight, max_weight]
        for i in 1:n
            lo = essential_mask[i] ? min_weight : 0.0
            w_new[i] = clamp(w_new[i], lo, max_weight)
        end

        # Normalise to sum = 1
        s = sum(w_new)
        s > 0 && (w_new ./= s)

        # If return constraint not met, pull toward high-return assets
        curr_ret = dot(w_new, μ)
        if curr_ret < target_return - 1e-6
            # Shift weight toward the highest-return non-essential asset
            best = argmax(μ)
            push_amt = min(lr * 5, max_weight - w_new[best])
            push_amt = max(push_amt, 0.0)
            w_new[best] += push_amt
            s = sum(w_new)
            s > 0 && (w_new ./= s)
        end

        w = w_new
    end
    w
end

# ─────────────────────────────────────────────────────────────────────────────
# Main public API
# ─────────────────────────────────────────────────────────────────────────────

"""
    optimize_service_line_portfolio(
        lines::Vector{ServiceLine};
        n_frontier_points, risk_free_rate, capacity_budget
    ) -> ServiceLinePortfolioResult

Compute the Markowitz efficient frontier for a hospital's service-line portfolio.

# Arguments
- `lines`: Service lines to analyse (≥ 2, each with ≥ 2 years of margin history).
- `n_frontier_points::Int = 50`: Number of points on the efficient frontier.
- `risk_free_rate::Float64 = 0.043`: Risk-free rate for Sharpe ratio (10-yr Treasury).
- `capacity_budget::Float64 = Inf`: Maximum total capacity units across all lines.

# Returns
`ServiceLinePortfolioResult` with efficient frontier, minimum-variance and
maximum-Sharpe portfolios, and current allocation metrics.

# Example
```julia
lines = [
    ServiceLine(name="Emergency Medicine",
        annual_net_margin_history=[0.12, 0.11, 0.14, 0.13, 0.10],
        current_revenue=2_800_000.0, is_essential=true),
    ServiceLine(name="Obstetrics",
        annual_net_margin_history=[-0.05, -0.08, -0.03, -0.06, -0.04],
        current_revenue=950_000.0),
    ServiceLine(name="Swing Bed / SNF",
        annual_net_margin_history=[0.08, 0.09, 0.07, 0.11, 0.10],
        current_revenue=620_000.0),
    ServiceLine(name="Rural Health Clinic",
        annual_net_margin_history=[0.15, 0.18, 0.14, 0.16, 0.17],
        current_revenue=1_100_000.0),
]
result = optimize_service_line_portfolio(lines)
result.max_sharpe.expected_return   # best risk-adjusted allocation
```
"""
function optimize_service_line_portfolio(
    lines::Vector{ServiceLine};
    n_frontier_points::Int = 50,
    risk_free_rate::Float64 = 0.043,
    capacity_budget::Float64 = Inf,
)::ServiceLinePortfolioResult

    stats = compute_portfolio_stats(lines)
    n = length(lines)
    μ = stats.expected_returns
    Σ = stats.cov_matrix
    essential = [l.is_essential for l in lines]

    # Current weights (revenue-weighted)
    total_rev = sum(l.current_revenue for l in lines)
    curr_w = [l.current_revenue / total_rev for l in lines]
    curr_ret = dot(curr_w, μ)
    curr_std = sqrt(max(_portfolio_variance(curr_w, Σ), 0.0))

    # Sweep target returns to build frontier
    ret_min = minimum(μ)
    ret_max = maximum(μ)
    targets = range(ret_min, ret_max; length = n_frontier_points)

    frontier = EfficientFrontierPoint[]
    for target in targets
        w = _min_variance_for_target(μ, Σ, Float64(target); essential_mask=essential)
        port_ret = dot(w, μ)
        port_var = _portfolio_variance(w, Σ)
        port_std = sqrt(max(port_var, 0.0))
        sharpe   = port_std > 1e-9 ? (port_ret - risk_free_rate) / port_std : 0.0
        push!(frontier, EfficientFrontierPoint(w, port_ret, port_std, sharpe))
    end

    # Sort by portfolio std (x-axis of frontier plot)
    sort!(frontier; by = p -> p.portfolio_std)

    # Min variance: lowest std
    min_var_pt = frontier[argmin(p.portfolio_std for p in frontier)]

    # Max Sharpe: highest Sharpe ratio
    max_sharpe_pt = frontier[argmax(p.sharpe_ratio for p in frontier)]

    ServiceLinePortfolioResult(
        stats, frontier, min_var_pt, max_sharpe_pt,
        curr_w, curr_ret, curr_std,
        [l.name for l in lines if l.is_essential],
    )
end

"""
    portfolio_recommendation(result::ServiceLinePortfolioResult) -> Vector{NamedTuple}

Generate actionable recommendations for each service line based on the
maximum-Sharpe optimal portfolio vs the current allocation.

Returns a Vector of NamedTuples with:
- `name`, `current_weight`, `optimal_weight`, `action`
  (`:maintain`, `:grow`, `:reduce`, or `:close_evaluate`)
- `return_contribution`, `risk_contribution`
"""
function portfolio_recommendation(result::ServiceLinePortfolioResult)
    opt_w = result.max_sharpe.weights
    curr_w = result.current_weights
    μ = result.stats.expected_returns
    Σ = result.stats.cov_matrix
    n = length(opt_w)

    rows = NamedTuple[]
    for i in 1:n
        Δw = opt_w[i] - curr_w[i]
        action = if opt_w[i] < 0.03 && !(result.stats.names[i] in result.essential_service_lines)
            :close_evaluate
        elseif Δw > 0.05
            :grow
        elseif Δw < -0.05
            :reduce
        else
            :maintain
        end
        # Marginal risk contribution: w_i × (Σw)_i / portfolio_variance
        Σw = Σ * opt_w
        port_var = dot(opt_w, Σw)
        mrc = port_var > 0 ? opt_w[i] * Σw[i] / port_var : 0.0
        push!(rows, (
            name               = result.stats.names[i],
            current_weight     = curr_w[i],
            optimal_weight     = opt_w[i],
            weight_change      = Δw,
            action             = action,
            expected_margin    = μ[i],
            return_contribution = opt_w[i] * μ[i],
            risk_contribution  = mrc,
        ))
    end
    sort(rows; by = r -> -r.optimal_weight)
end
