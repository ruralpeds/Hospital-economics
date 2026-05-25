using Statistics

# Value-at-Risk (VaR) and Conditional VaR (CVaR)
#
# Historical simulation approach: uses empirical return distribution to estimate
# potential losses at a given confidence level. CVaR (Expected Shortfall) captures
# tail risk beyond VaR. Multi-day holding period scaled by √T.

"""
    VaRInput

Input parameters for Value-at-Risk / CVaR calculation.

Fields:
- `returns` — vector of historical returns (decimal, e.g. -0.02 = -2%)
- `confidence` — confidence level (default 0.95 = 95th percentile)
- `holding_period` — holding period in days for scaling (default 1)
"""
@kwdef struct VaRInput
    returns::Vector{Float64}
    confidence::Float64 = 0.95
    holding_period::Int = 1
end

"""
    VaRResult

Result of VaR/CVaR calculation.

Fields:
- `var_amount` — Value-at-Risk (absolute, positive = loss)
- `cvar_amount` — Conditional VaR / Expected Shortfall (positive = loss)
- `var_pct` — VaR as percentage
- `cvar_pct` — CVaR as percentage
- `n_observations` — number of return observations used
"""
@kwdef struct VaRResult
    var_amount::Float64
    cvar_amount::Float64
    var_pct::Float64
    cvar_pct::Float64
    n_observations::Int
end

function Base.show(io::IO, r::VaRResult)
    print(io, "VaRResult(VaR=$(round(r.var_pct * 100, digits=2))%, CVaR=$(round(r.cvar_pct * 100, digits=2))%, n=$(r.n_observations))")
end

"""
    calculate_var_cvar(input::VaRInput) -> VaRResult

Compute VaR and CVaR using historical simulation.

Method:
1. Sort returns ascending
2. VaR = negative of the quantile at (1 - confidence) — reported as positive loss
3. CVaR = negative of the mean of all returns at or below the VaR threshold
4. Scale both by √(holding_period) for multi-day horizons
"""
function calculate_var_cvar(input::VaRInput)::VaRResult
    length(input.returns) >= 2 || error("at least 2 return observations required")
    0.0 < input.confidence < 1.0 || error("confidence must be in (0, 1); got $(input.confidence)")
    input.holding_period >= 1 || error("holding_period must be >= 1; got $(input.holding_period)")

    sorted_returns = sort(input.returns)
    n = length(sorted_returns)

    # VaR: quantile at the (1 - confidence) level
    alpha = 1.0 - input.confidence
    var_idx = max(1, ceil(Int, alpha * n))
    var_pct = -sorted_returns[var_idx]  # positive = loss

    # CVaR: mean of returns at or below the VaR threshold
    threshold = sorted_returns[var_idx]
    tail_returns = filter(r -> r <= threshold, sorted_returns)
    cvar_pct = isempty(tail_returns) ? var_pct : -mean(tail_returns)

    # Scale by √holding_period
    scale = sqrt(Float64(input.holding_period))
    var_scaled = var_pct * scale
    cvar_scaled = cvar_pct * scale

    return VaRResult(
        var_amount = var_scaled,
        cvar_amount = cvar_scaled,
        var_pct = var_scaled,
        cvar_pct = cvar_scaled,
        n_observations = n,
    )
end
