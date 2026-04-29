"""
    team_bundled_payment.jl — TEAM FY2026 Bundled Payment Audit (MBA Gap E-07)

Implements the CMS Transforming Episode Accountability Model (TEAM) that became
mandatory for selected hospitals starting January 1, 2026 (CMS-5531-F, Oct 2024).

## TEAM overview
TEAM is a mandatory episode-based payment model covering five episode types for
hospitals in randomly selected Core-Based Statistical Areas (CBSAs):

  Episode Type               ICD-10 / DRG Trigger          90-Day Bundle
  ──────────────────────────────────────────────────────────────────────
  1. LEJR (Lower Extremity   DRGs 469, 470 (TKA/THA)       Inpatient + 90 days post
     Joint Replacement)
  2. SHFF (Surgical Hip/     DRGs 480-482 (hip Fx repair)  Inpatient + 90 days post
     Femur Fracture)
  3. SF (Spinal Fusion)      DRGs 453-455, 460              Inpatient + 90 days post
  4. CDI (Cardiac Defib      DRGs 222-227                   Inpatient + 90 days post
     Implant)
  5. CABG (Coronary Artery   DRGs 231-236                   Inpatient + 90 days post
     Bypass Graft)

## Payment mechanics
1. CMS establishes a **target price** per episode from regional FFS benchmarks
   adjusted for case mix (risk score) and quality category.
2. Actual Medicare payments for all services in the episode window are summed.
3. **Reconciliation**:
   - If actual < target × (1 − stop_loss): hospital earns savings (positive reconciliation).
   - If actual > target × (1 + stop_gain): hospital owes CMS (negative reconciliation).
4. **Quality adjustment**: hospitals with higher quality scores (1-5) receive
   a more favourable target price (up to +5% for quality category 1).

## This module provides
- Episode attribution (which discharges qualify for TEAM)
- Target price calculation (regional benchmark × case mix × quality adjustment)
- Reconciliation payment computation
- Multi-episode portfolio analysis for a hospital's full TEAM programme
- Year-end financial projection

References:
- CMS TEAM Final Rule (CMS-5531-F), 89 FR 77684, October 1, 2024.
- CMS TEAM Model FAQs (January 2026).
- CMS IPPS DRG weight tables (FY2026).
"""

using Statistics
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# Episode types and DRG groupings
# ─────────────────────────────────────────────────────────────────────────────

"""
    TEAMEpisodeType

The five TEAM episode types.
"""
@enum TEAMEpisodeType lejr=1 shff=2 sf=3 cdi=4 cabg=5

episode_label(e::TEAMEpisodeType) = e == lejr ? "LEJR (Joint Replacement)" :
    e == shff ? "SHFF (Hip/Femur Fracture)" :
    e == sf   ? "SF (Spinal Fusion)" :
    e == cdi  ? "CDI (Cardiac Defibrillator)" : "CABG (Coronary Bypass)"

"""
    TEAM_DRG_MAP

DRGs that trigger TEAM episodes. From CMS TEAM Final Rule Appendix A.
"""
const TEAM_DRG_MAP = Dict{TEAMEpisodeType, Vector{Int}}(
    lejr => [469, 470],
    shff => [480, 481, 482],
    sf   => [453, 454, 455, 460],
    cdi  => [222, 223, 224, 225, 226, 227],
    cabg => [231, 232, 233, 234, 235, 236],
)

"""
    TEAM_QUALITY_ADJUSTMENTS

Target price multiplier by quality category (1=best, 5=worst).
Source: CMS TEAM Final Rule § 512.600.
"""
const TEAM_QUALITY_ADJUSTMENTS = Dict{Int,Float64}(
    1 => 1.050,   # Best quality: +5% target (more generous)
    2 => 1.025,
    3 => 1.000,   # Average: no adjustment
    4 => 0.975,
    5 => 0.950,   # Worst quality: -5% target (less generous)
)

"""
    TEAM_STOP_LOSS_GAIN

Stop-loss and stop-gain parameters as fractions of target price.
Stop-gain: if actual exceeds target by this %, hospital owes balance.
Stop-loss: if actual is this % below target, hospital earns maximum savings.
"""
const TEAM_STOP_GAIN = 0.20   # 20% above target → maximum repayment obligation
const TEAM_STOP_LOSS = 0.20   # 20% below target → maximum savings

# ─────────────────────────────────────────────────────────────────────────────
# Input types
# ─────────────────────────────────────────────────────────────────────────────

"""
    TEAMEpisode

One patient episode attributed to the hospital under TEAM.

# Fields
- `episode_id::Any`
- `episode_type::TEAMEpisodeType`
- `drg::Int`: Admission DRG.
- `admission_date::String`: ISO date string.
- `actual_episode_cost::Float64`: Total Medicare payments for the 90-day episode
  (anchor admission + all Part A/B/D services post-discharge).
- `risk_score::Float64`: CMS risk score for this patient (adjusts target price).
- `quality_category::Int`: Hospital quality category 1-5 (set annually by CMS).
- `is_anchor_hospital_admission::Bool`: Whether the anchor stay was at this hospital.
"""
@kwdef struct TEAMEpisode
    episode_id::Any
    episode_type::TEAMEpisodeType
    drg::Int
    admission_date::String            = "2026-01-01"
    actual_episode_cost::Float64
    risk_score::Float64               = 1.00
    quality_category::Int             = 3
    is_anchor_hospital_admission::Bool = true
end

"""
    TEAMTargetPriceInputs

Inputs for TEAM target price calculation for a specific episode type.

# Fields
- `episode_type::TEAMEpisodeType`
- `regional_benchmark_price::Float64`: CMS regional target price for this episode type
  (base amount before risk and quality adjustment, USD per episode).
- `trending_factor::Float64 = 1.0`: Annual update factor (typically 1.02-1.03).
- `discount_factor::Float64 = 0.97`: 3% discount retained by CMS (not shared with hospital).
"""
@kwdef struct TEAMTargetPriceInputs
    episode_type::TEAMEpisodeType
    regional_benchmark_price::Float64
    trending_factor::Float64    = 1.02
    discount_factor::Float64    = 0.97
end

# ─────────────────────────────────────────────────────────────────────────────
# Published regional benchmark prices (FY2026, CMS TEAM Final Rule)
# ─────────────────────────────────────────────────────────────────────────────

"""
    TEAM_REGIONAL_BENCHMARKS_FY2026

Approximate national average target prices for TEAM episodes, FY2026.
Individual hospitals receive region-specific prices; these are national averages
for estimation. Source: CMS TEAM Final Rule Table 12, national averages.
"""
const TEAM_REGIONAL_BENCHMARKS_FY2026 = Dict{TEAMEpisodeType,Float64}(
    lejr => 28_750.0,
    shff => 38_400.0,
    sf   => 45_200.0,
    cdi  => 62_100.0,
    cabg => 94_300.0,
)

# ─────────────────────────────────────────────────────────────────────────────
# Core calculations
# ─────────────────────────────────────────────────────────────────────────────

"""
    calculate_team_target_price(
        inputs::TEAMTargetPriceInputs,
        risk_score::Float64,
        quality_category::Int
    ) -> Float64

Compute the TEAM target price for one episode.

Target price = regional_benchmark × trending_factor × risk_score
                × quality_adjustment × (1 − discount_factor_deduction)

The 3% discount factor means hospitals can earn up to 97% of FFS benchmark
savings — CMS retains 3% as programme savings.
"""
function calculate_team_target_price(
    inputs::TEAMTargetPriceInputs,
    risk_score::Float64 = 1.0,
    quality_category::Int = 3,
)::Float64
    1 <= quality_category <= 5 ||
        throw(ArgumentError("quality_category must be 1-5"))
    risk_score > 0 || throw(ArgumentError("risk_score must be > 0"))

    qa = TEAM_QUALITY_ADJUSTMENTS[quality_category]
    inputs.regional_benchmark_price *
        inputs.trending_factor *
        risk_score *
        qa *
        inputs.discount_factor
end

"""
    TEAMEpisodeResult

Reconciliation result for one TEAM episode.

# Fields
- `episode_id`
- `episode_type::TEAMEpisodeType`
- `target_price::Float64`
- `actual_episode_cost::Float64`
- `raw_surplus::Float64`: target − actual (positive = hospital earned savings).
- `capped_surplus::Float64`: After applying stop-loss and stop-gain caps.
- `reconciliation_payment::Float64`: Positive = hospital receives; negative = hospital owes.
- `performance::Symbol`: `:savings`, `:neutral`, `:repayment`.
"""
struct TEAMEpisodeResult
    episode_id::Any
    episode_type::TEAMEpisodeType
    target_price::Float64
    actual_episode_cost::Float64
    raw_surplus::Float64
    capped_surplus::Float64
    reconciliation_payment::Float64
    performance::Symbol
end

"""
    team_episode_reconciliation(
        episode::TEAMEpisode,
        target_inputs::TEAMTargetPriceInputs
    ) -> TEAMEpisodeResult

Compute the TEAM reconciliation payment for one episode.
"""
function team_episode_reconciliation(
    episode::TEAMEpisode,
    target_inputs::TEAMTargetPriceInputs,
)::TEAMEpisodeResult
    target = calculate_team_target_price(
        target_inputs, episode.risk_score, episode.quality_category)
    actual = episode.actual_episode_cost
    raw    = target - actual

    # Apply stop-loss and stop-gain caps
    max_savings    = target * TEAM_STOP_LOSS
    max_repayment  = target * TEAM_STOP_GAIN
    capped = clamp(raw, -max_repayment, max_savings)

    perf = capped > 100 ? :savings : capped < -100 ? :repayment : :neutral

    TEAMEpisodeResult(
        episode.episode_id, episode.episode_type,
        target, actual, raw, capped, capped, perf,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Portfolio analysis
# ─────────────────────────────────────────────────────────────────────────────

"""
    TEAMPortfolioResult

Hospital-level TEAM programme summary.

# Fields
- `episode_results::Vector{TEAMEpisodeResult}`
- `by_episode_type::Dict{TEAMEpisodeType,NamedTuple}`: Summary per episode type.
- `total_reconciliation_payment::Float64`: Net programme payment (+ = hospital earns).
- `total_episodes::Int`
- `n_savings_episodes::Int`
- `n_repayment_episodes::Int`
- `savings_rate::Float64`: Fraction of episodes with positive reconciliation.
- `avg_savings_per_episode::Float64`: Average across savings episodes.
- `total_target_price::Float64`
- `total_actual_cost::Float64`
- `programme_margin_pct::Float64`: (total_target − total_actual) / total_target.
"""
struct TEAMPortfolioResult
    episode_results::Vector{TEAMEpisodeResult}
    by_episode_type::Dict{TEAMEpisodeType,NamedTuple}
    total_reconciliation_payment::Float64
    total_episodes::Int
    n_savings_episodes::Int
    n_repayment_episodes::Int
    savings_rate::Float64
    avg_savings_per_episode::Float64
    total_target_price::Float64
    total_actual_cost::Float64
    programme_margin_pct::Float64
end

"""
    team_portfolio_analysis(
        episodes::Vector{TEAMEpisode},
        target_inputs::Dict{TEAMEpisodeType,TEAMTargetPriceInputs}
    ) -> TEAMPortfolioResult

Analyse a hospital's full TEAM episode portfolio.

# Example
```julia
# Set up target price inputs for each episode type
targets = Dict(
    lejr => TEAMTargetPriceInputs(episode_type=lejr,
                regional_benchmark_price=TEAM_REGIONAL_BENCHMARKS_FY2026[lejr]),
    shff => TEAMTargetPriceInputs(episode_type=shff,
                regional_benchmark_price=TEAM_REGIONAL_BENCHMARKS_FY2026[shff]),
)
result = team_portfolio_analysis(my_episodes, targets)
result.total_reconciliation_payment   # + = hospital earns savings
result.programme_margin_pct           # (target - actual) / target
```
"""
function team_portfolio_analysis(
    episodes::Vector{TEAMEpisode},
    target_inputs::Dict{TEAMEpisodeType,TEAMTargetPriceInputs},
)::TEAMPortfolioResult
    isempty(episodes) && throw(ArgumentError("episodes must not be empty"))

    results = TEAMEpisodeResult[]
    for ep in episodes
        haskey(target_inputs, ep.episode_type) ||
            throw(ArgumentError("No target price inputs for episode type $(ep.episode_type)"))
        push!(results, team_episode_reconciliation(ep, target_inputs[ep.episode_type]))
    end

    # Summarise by episode type
    by_type = Dict{TEAMEpisodeType,NamedTuple}()
    for etype in unique(r.episode_type for r in results)
        subset = filter(r -> r.episode_type == etype, results)
        by_type[etype] = (
            n_episodes      = length(subset),
            total_recon     = sum(r.reconciliation_payment for r in subset),
            avg_target      = mean(r.target_price for r in subset),
            avg_actual      = mean(r.actual_episode_cost for r in subset),
            n_savings       = count(r -> r.performance == :savings, subset),
            n_repayment     = count(r -> r.performance == :repayment, subset),
        )
    end

    tot_recon = sum(r.reconciliation_payment for r in results)
    n_sav = count(r -> r.performance == :savings, results)
    n_rep = count(r -> r.performance == :repayment, results)
    tot_tgt = sum(r.target_price for r in results)
    tot_act = sum(r.actual_episode_cost for r in results)
    sav_episodes = filter(r -> r.performance == :savings, results)
    avg_sav = isempty(sav_episodes) ? 0.0 :
              mean(r.reconciliation_payment for r in sav_episodes)

    TEAMPortfolioResult(
        results, by_type,
        tot_recon, length(results), n_sav, n_rep,
        length(results) > 0 ? n_sav / length(results) : 0.0,
        avg_sav, tot_tgt, tot_act,
        tot_tgt > 0 ? (tot_tgt - tot_act) / tot_tgt : 0.0,
    )
end

"""
    team_annual_projection(
        episodes_per_type::Dict{TEAMEpisodeType,Int},
        target_inputs::Dict{TEAMEpisodeType,TEAMTargetPriceInputs};
        avg_risk_score, quality_category,
        avg_cost_ratio_to_target
    ) -> NamedTuple

Project full-year TEAM reconciliation payment for a hospital.

# Arguments
- `episodes_per_type`: Expected annual episode count per type.
- `avg_risk_score::Float64 = 1.0`: Average patient risk score.
- `quality_category::Int = 3`: Hospital quality category.
- `avg_cost_ratio_to_target::Float64 = 0.98`: Hospital's actual cost as % of target
  (< 1.0 = hospital performs below target = earns savings).
"""
function team_annual_projection(
    episodes_per_type::Dict{TEAMEpisodeType,Int},
    target_inputs::Dict{TEAMEpisodeType,TEAMTargetPriceInputs};
    avg_risk_score::Float64 = 1.0,
    quality_category::Int   = 3,
    avg_cost_ratio_to_target::Float64 = 0.98,
)
    rows = NamedTuple[]
    total_recon = 0.0

    for (etype, n_episodes) in episodes_per_type
        haskey(target_inputs, etype) || continue
        ti  = target_inputs[etype]
        tp  = calculate_team_target_price(ti, avg_risk_score, quality_category)
        actual = tp * avg_cost_ratio_to_target
        raw  = tp - actual
        capped = clamp(raw, -tp * TEAM_STOP_GAIN, tp * TEAM_STOP_LOSS)
        annual_recon = capped * n_episodes
        total_recon += annual_recon

        push!(rows, (
            episode_type         = etype,
            label                = episode_label(etype),
            n_episodes           = n_episodes,
            target_price         = tp,
            avg_actual           = actual,
            per_episode_recon    = capped,
            annual_reconciliation = annual_recon,
        ))
    end

    (
        episodes_by_type         = rows,
        total_annual_reconciliation = total_recon,
        avg_risk_score           = avg_risk_score,
        quality_category         = quality_category,
        cost_ratio               = avg_cost_ratio_to_target,
        programme_outcome        = total_recon >= 0 ? :net_savings : :net_repayment,
    )
end
