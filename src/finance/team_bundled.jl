# TEAM Bundled Payment Simulation for Rural Hospital Economics Simulator
#
# Implements CMS Transforming Episode Accountability Model (TEAM) mandatory
# bundled payment program (2026-2030) for five surgical episode types.
# Computes reconciliation amounts, quality adjustments, and stop-gain/loss caps.

"""
    TEAMEpisode

A single surgical episode under the TEAM bundled payment model.

# Fields
- `episode_type::Symbol`: one of :lejr, :hip_fracture, :spinal_fusion, :cabg, :major_bowel
- `base_drg_payment::Float64`: original DRG payment for the episode
- `target_price::Float64`: CMS-set target price for the episode
- `actual_cost::Float64`: total actual spending during the episode window
- `quality_score::Float64`: composite quality score 0.0-1.0 (default 0.5)
"""
@kwdef struct TEAMEpisode
    episode_type::Symbol
    base_drg_payment::Float64
    target_price::Float64
    actual_cost::Float64
    quality_score::Float64 = 0.5
end

"""
    TEAMParams

Parameters for a TEAM bundled payment reconciliation calculation.

# Fields
- `episodes::Vector{TEAMEpisode}`: all episodes in the performance period
- `risk_track::Symbol`: :track1 (10% stop-gain/loss) or :track2 (5%)
- `discount_factor::Float64`: CMS discount percentage applied to target price
- `quality_adjustment_pct::Float64`: max quality bonus/penalty as fraction
- `low_volume_threshold::Int`: episode count below which provider is exempt
"""
@kwdef struct TEAMParams
    episodes::Vector{TEAMEpisode}
    risk_track::Symbol = :track2
    discount_factor::Float64 = 0.03
    quality_adjustment_pct::Float64 = 0.02
    low_volume_threshold::Int = 31
end

"""
    TEAMResult

Results of a TEAM reconciliation calculation.

# Fields
- `total_target_price::Float64`: sum of target prices across all episodes
- `total_actual_cost::Float64`: sum of actual costs across all episodes
- `raw_reconciliation::Float64`: total target minus total actual cost
- `quality_adjusted_reconciliation::Float64`: after quality adjustment
- `stop_gain_loss_applied::Float64`: after applying stop-gain/loss caps
- `net_payment_adjustment::Float64`: final payment to/from CMS
- `is_low_volume_exempt::Bool`: true if episode count is below threshold
- `episode_count::Int`: number of episodes evaluated
"""
@kwdef struct TEAMResult
    total_target_price::Float64
    total_actual_cost::Float64
    raw_reconciliation::Float64
    quality_adjusted_reconciliation::Float64
    stop_gain_loss_applied::Float64
    net_payment_adjustment::Float64
    is_low_volume_exempt::Bool
    episode_count::Int
end

function Base.show(io::IO, r::TEAMResult)
    status = r.net_payment_adjustment >= 0 ? "savings" : "repayment"
    print(io, "TEAMResult(episodes=$(r.episode_count), $(status)=\$$(round(Int, abs(r.net_payment_adjustment))), exempt=$(r.is_low_volume_exempt))")
end

"""
    calculate_team_reconciliation(params::TEAMParams) -> TEAMResult

Compute TEAM bundled payment reconciliation.

1. Sum target prices and actual costs across all episodes.
2. Raw reconciliation = total target price - total actual cost.
3. Apply quality adjustment: multiply by (1 + quality_adjustment_pct) for
   above-median quality (avg score > 0.5) or (1 - quality_adjustment_pct) for below.
4. Apply stop-gain/loss caps based on risk track.
5. Exempt low-volume providers (episode count < low_volume_threshold).
"""
function calculate_team_reconciliation(params::TEAMParams)::TEAMResult
    eps = params.episodes
    n = length(eps)

    n > 0 || error("TEAMParams must contain at least one episode")
    params.risk_track in (:track1, :track2) || error("risk_track must be :track1 or :track2; got $(params.risk_track)")
    0.0 <= params.discount_factor <= 1.0 || error("discount_factor must be between 0 and 1; got $(params.discount_factor)")
    0.0 <= params.quality_adjustment_pct <= 1.0 || error("quality_adjustment_pct must be between 0 and 1; got $(params.quality_adjustment_pct)")
    params.low_volume_threshold > 0 || error("low_volume_threshold must be positive; got $(params.low_volume_threshold)")

    valid_episode_types = (:lejr, :hip_fracture, :spinal_fusion, :cabg, :major_bowel)
    for e in eps
        e.episode_type in valid_episode_types || error("Invalid episode_type $(e.episode_type); must be one of $valid_episode_types")
        e.base_drg_payment >= 0.0 || error("base_drg_payment must be non-negative; got $(e.base_drg_payment)")
        e.target_price >= 0.0 || error("target_price must be non-negative; got $(e.target_price)")
        e.actual_cost >= 0.0 || error("actual_cost must be non-negative; got $(e.actual_cost)")
        0.0 <= e.quality_score <= 1.0 || error("quality_score must be between 0 and 1; got $(e.quality_score)")
    end

    is_exempt = n < params.low_volume_threshold

    total_target = sum(e.target_price for e in eps)
    total_actual = sum(e.actual_cost for e in eps)
    raw_recon = total_target - total_actual

    # Quality adjustment based on average quality score across episodes
    avg_quality = sum(e.quality_score for e in eps) / n
    quality_mult = if avg_quality >= 0.5
        1.0 + params.quality_adjustment_pct * ((avg_quality - 0.5) / 0.5)
    else
        1.0 - params.quality_adjustment_pct * ((0.5 - avg_quality) / 0.5)
    end
    quality_adj_recon = raw_recon * quality_mult

    # Stop-gain / stop-loss cap as percentage of total target price
    cap_pct = params.risk_track == :track1 ? 0.10 : 0.05
    cap_amount = total_target * cap_pct
    capped_recon = clamp(quality_adj_recon, -cap_amount, cap_amount)

    # Low-volume exempt providers receive zero adjustment
    net_adjustment = is_exempt ? 0.0 : capped_recon

    return TEAMResult(
        total_target_price = total_target,
        total_actual_cost = total_actual,
        raw_reconciliation = raw_recon,
        quality_adjusted_reconciliation = quality_adj_recon,
        stop_gain_loss_applied = capped_recon,
        net_payment_adjustment = net_adjustment,
        is_low_volume_exempt = is_exempt,
        episode_count = n,
    )
end

"""
    team_episode_summary(params::TEAMParams) -> Vector{NamedTuple}

Per-episode breakdown with episode type, target price, actual cost, and margin.
"""
function team_episode_summary(params::TEAMParams)::Vector{NamedTuple}
    !isempty(params.episodes) || error("episodes must not be empty")

    return [(
        episode_type = e.episode_type,
        target_price = e.target_price,
        actual_cost = e.actual_cost,
        margin = e.target_price - e.actual_cost,
    ) for e in params.episodes]
end
