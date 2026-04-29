"""
    competitive_analytics.jl — Hospital Market Competitive Analytics (MBA Gap B-07)

Provides HRR/HSA-level competitive analytics:

1. **Herfindahl-Hirschman Index (HHI)** — standard DOJ/FTC market concentration
   measure used in hospital merger review and competitive strategy.
2. **Market Share Analysis** — discharge-based, revenue-based, and
   specialty-specific market share by hospital within an HRR/HSA.
3. **Geographic Access Overlap** — how much of a hospital's service area is
   contested by competitor hospitals.
4. **5-Year Trend Analysis** — HHI and market share over time.
5. **Competitive Position Score** — composite rating for strategic planning.

DOJ/FTC concentration thresholds (2010 Horizontal Merger Guidelines):
  HHI < 1,500           → Unconcentrated market
  1,500 ≤ HHI < 2,500   → Moderately concentrated
  HHI ≥ 2,500           → Highly concentrated (antitrust scrutiny)

References:
- Dafny L (2009). Estimation and identification of merger effects. J Law Econ 52(3).
- Town R, Vistnes G (2001). Hospital competition in HMO networks. J Health Econ 20(5).
- Gaynor M, Town R (2011). Competition in health care markets. NBER w17208.
"""

using Statistics
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# HHI core
# ─────────────────────────────────────────────────────────────────────────────

"""
    compute_hhi(market_shares::Vector{Float64}) -> Float64

Compute the Herfindahl-Hirschman Index from market share fractions.

HHI = Σ (sᵢ × 100)² where sᵢ are market shares summing to 1.0.

The ×100 scaling means HHI ranges from 0 (perfect competition) to 10,000
(monopoly). This matches the DOJ/FTC standard.

# Example
```julia
# Duopoly: 60% / 40% split
compute_hhi([0.60, 0.40])    # → 5,200 (highly concentrated)

# Five equal competitors
compute_hhi(fill(0.20, 5))   # → 2,000 (moderately concentrated)
```
"""
function compute_hhi(market_shares::Vector{Float64})::Float64
    isempty(market_shares) && throw(ArgumentError("market_shares must not be empty"))
    all(s >= 0 for s in market_shares) ||
        throw(ArgumentError("All market shares must be non-negative"))
    total = sum(market_shares)
    abs(total - 1.0) > 0.01 && @warn "Market shares sum to $total (expected 1.0)"
    sum((s * 100)^2 for s in market_shares)
end

"""
    DOJ/FTC HHI thresholds (2010 Horizontal Merger Guidelines).
"""
const HHI_UNCONCENTRATED   = 1_500.0
const HHI_MODERATELY_CONC  = 2_500.0

"""
    market_concentration_tier(hhi::Float64) -> Symbol

Return `:unconcentrated`, `:moderately_concentrated`, or `:highly_concentrated`.
"""
function market_concentration_tier(hhi::Float64)::Symbol
    hhi < HHI_UNCONCENTRATED  ? :unconcentrated :
    hhi < HHI_MODERATELY_CONC ? :moderately_concentrated :
                                 :highly_concentrated
end

"""
    hhi_merger_delta(pre_shares, hospital_a_share, hospital_b_share) -> NamedTuple

Compute the HHI change from merging two hospitals with given market shares.

DOJ/FTC safe harbour: ΔHHI < 100 in markets with HHI < 2,500.

# Returns
- `pre_hhi`, `post_hhi`, `delta_hhi`, `antitrust_concern::Bool`
"""
function hhi_merger_delta(
    pre_shares::Vector{Float64},
    hospital_a_share::Float64,
    hospital_b_share::Float64,
)
    pre_hhi = compute_hhi(pre_shares)
    # Post-merger: replace a and b with combined share (a+b)
    post_shares = filter(s -> s != hospital_a_share && s != hospital_b_share, pre_shares)
    push!(post_shares, hospital_a_share + hospital_b_share)
    post_hhi = compute_hhi(post_shares)
    delta    = post_hhi - pre_hhi

    # DOJ concern thresholds
    concern = (post_hhi >= HHI_MODERATELY_CONC && delta >= 100) ||
              (post_hhi >= HHI_UNCONCENTRATED  && delta >= 200)

    (pre_hhi=pre_hhi, post_hhi=post_hhi, delta_hhi=delta, antitrust_concern=concern,
     pre_tier=market_concentration_tier(pre_hhi),
     post_tier=market_concentration_tier(post_hhi))
end

# ─────────────────────────────────────────────────────────────────────────────
# Market share types
# ─────────────────────────────────────────────────────────────────────────────

"""
    HospitalCompetitor

One hospital in a competitive market.

# Fields
- `id::Any`
- `name::String`
- `annual_discharges::Int`
- `annual_revenue::Float64`
- `distance_miles::Float64`: Distance from the target hospital.
- `service_lines::Vector{String}`: Service lines offered (for specialty overlap).
- `is_target::Bool`: Whether this is the hospital we're analyzing.
"""
@kwdef struct HospitalCompetitor
    id::Any                         = 1
    name::String
    annual_discharges::Int
    annual_revenue::Float64         = 0.0
    distance_miles::Float64         = 0.0
    service_lines::Vector{String}   = String[]
    is_target::Bool                 = false
end

"""
    MarketShareResult

Comprehensive market share analysis for a set of competing hospitals.

# Fields
- `hospitals::Vector{HospitalCompetitor}`
- `discharge_shares::Dict{Any,Float64}`: Discharge-based market share by hospital id.
- `revenue_shares::Dict{Any,Float64}`: Revenue-based market share.
- `hhi_discharges::Float64`: HHI based on discharge shares.
- `hhi_revenue::Float64`: HHI based on revenue shares.
- `concentration_tier::Symbol`
- `target_discharge_rank::Int`: Target hospital's rank by discharge share.
- `target_market_share::Float64`
- `largest_competitor_share::Float64`
- `competitive_gap::Float64`: Largest competitor share - target share.
"""
struct MarketShareResult
    hospitals::Vector{HospitalCompetitor}
    discharge_shares::Dict{Any,Float64}
    revenue_shares::Dict{Any,Float64}
    hhi_discharges::Float64
    hhi_revenue::Float64
    concentration_tier::Symbol
    target_discharge_rank::Int
    target_market_share::Float64
    largest_competitor_share::Float64
    competitive_gap::Float64
end

"""
    analyze_market_share(hospitals::Vector{HospitalCompetitor}) -> MarketShareResult

Compute discharge and revenue market shares, HHI, and competitive position
for a set of hospitals in a common HRR/HSA.

# Example
```julia
market = [
    HospitalCompetitor(name="Valley CAH", annual_discharges=620, annual_revenue=5_800_000, is_target=true),
    HospitalCompetitor(name="Regional Medical", annual_discharges=4_200, annual_revenue=98_000_000),
    HospitalCompetitor(name="St. Mary's", annual_discharges=2_800, annual_revenue=52_000_000),
]
result = analyze_market_share(market)
result.hhi_discharges         # market concentration
result.target_market_share    # Valley CAH's share
result.competitive_gap        # how far behind the leader
```
"""
function analyze_market_share(hospitals::Vector{HospitalCompetitor})::MarketShareResult
    isempty(hospitals) && throw(ArgumentError("hospitals must not be empty"))

    total_discharges = sum(h.annual_discharges for h in hospitals)
    total_revenue    = sum(h.annual_revenue    for h in hospitals)

    discharge_shares = Dict(h.id => (total_discharges > 0 ?
        h.annual_discharges / total_discharges : 0.0) for h in hospitals)
    revenue_shares   = Dict(h.id => (total_revenue > 0 ?
        h.annual_revenue    / total_revenue    : 0.0) for h in hospitals)

    hhi_d = compute_hhi(collect(values(discharge_shares)))
    hhi_r = total_revenue > 0 ? compute_hhi(collect(values(revenue_shares))) : hhi_d
    tier  = market_concentration_tier(hhi_d)

    # Target hospital stats
    target = findfirst(h -> h.is_target, hospitals)
    if isnothing(target)
        target_id    = hospitals[1].id
        target_share = discharge_shares[hospitals[1].id]
    else
        target_id    = hospitals[target].id
        target_share = discharge_shares[target_id]
    end

    sorted_shares = sort(collect(values(discharge_shares)); rev=true)
    target_rank   = findfirst(==(target_share), sorted_shares)
    target_rank   = isnothing(target_rank) ? length(hospitals) : target_rank

    competitor_shares = [discharge_shares[h.id] for h in hospitals if h.id != target_id]
    largest_comp = isempty(competitor_shares) ? 0.0 : maximum(competitor_shares)
    gap = largest_comp - target_share

    MarketShareResult(
        hospitals, discharge_shares, revenue_shares,
        hhi_d, hhi_r, tier,
        target_rank, target_share, largest_comp, gap,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Geographic access overlap
# ─────────────────────────────────────────────────────────────────────────────

"""
    geographic_overlap_score(
        hospitals::Vector{HospitalCompetitor};
        service_radius_miles = 35.0
    ) -> NamedTuple

Estimate geographic overlap between the target hospital's service area and
competitors within `service_radius_miles`.

For CAHs, the 35-mile rule defines the typical service area.
Higher overlap = more direct competition for patients.

# Returns
- `n_competitors_in_radius::Int`
- `overlap_score::Float64`: 0–1 (0 = no overlap; 1 = full overlap)
- `weighted_overlap::Float64`: Distance-weighted overlap (closer = more weight)
- `contested_market::Bool`: `true` if ≥ 1 competitor within radius
"""
function geographic_overlap_score(
    hospitals::Vector{HospitalCompetitor};
    service_radius_miles::Float64 = 35.0,
)
    competitors = filter(h -> !h.is_target, hospitals)
    in_radius   = filter(h -> h.distance_miles < service_radius_miles, competitors)
    n_in_radius = length(in_radius)

    overlap = n_in_radius == 0 ? 0.0 :
        min(1.0, n_in_radius / 5.0 + sum(1 - h.distance_miles / service_radius_miles
                                         for h in in_radius) / (5.0 * n_in_radius))

    weighted = n_in_radius == 0 ? 0.0 :
        mean(1.0 - h.distance_miles / service_radius_miles for h in in_radius)

    (
        n_competitors_in_radius = n_in_radius,
        overlap_score           = clamp(overlap, 0.0, 1.0),
        weighted_overlap        = clamp(weighted, 0.0, 1.0),
        contested_market        = n_in_radius >= 1,
        nearby_competitors      = [h.name for h in in_radius],
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# 5-Year HHI Trend
# ─────────────────────────────────────────────────────────────────────────────

"""
    HHITrendPoint

One year of HHI data.
"""
struct HHITrendPoint
    year::Int
    hhi::Float64
    tier::Symbol
    n_competitors::Int
    top_two_share::Float64
end

"""
    compute_hhi_trend(
        annual_discharges::Dict{Int, Vector{Int}};
        years
    ) -> Vector{HHITrendPoint}

Compute HHI trend over multiple years.

# Arguments
- `annual_discharges`: Dict mapping year → vector of discharge counts (one per hospital).
- `years`: vector of years to include (must be keys in `annual_discharges`).

# Example
```julia
data = Dict(
    2020 => [620, 4200, 2800],
    2021 => [590, 4400, 2700],
    2022 => [640, 4100, 2900],
    2023 => [680, 4000, 3100],
    2024 => [710, 3900, 3200],
)
trend = compute_hhi_trend(data; years=2020:2024)
```
"""
function compute_hhi_trend(
    annual_discharges::Dict{Int, Vector{Int}};
    years = sort(collect(keys(annual_discharges))),
)::Vector{HHITrendPoint}
    points = HHITrendPoint[]
    for yr in years
        haskey(annual_discharges, yr) || continue
        d = annual_discharges[yr]
        total = sum(d)
        total == 0 && continue
        shares = d ./ total
        hhi    = compute_hhi(shares)
        tier   = market_concentration_tier(hhi)
        sorted = sort(shares; rev=true)
        top2   = length(sorted) >= 2 ? sorted[1] + sorted[2] : sorted[1]
        push!(points, HHITrendPoint(yr, hhi, tier, length(d), top2))
    end
    sort(points; by=p->p.year)
end

# ─────────────────────────────────────────────────────────────────────────────
# Competitive Position Score
# ─────────────────────────────────────────────────────────────────────────────

"""
    competitive_position_score(
        market_result::MarketShareResult,
        overlap_result::NamedTuple;
        quality_rank_pct = 50.0
    ) -> NamedTuple

Compute a composite competitive position score (0–100) for the target hospital.

| Dimension | Weight | Scoring |
|---|---|---|
| Market share rank | 35 | Solo → 35; #1 → 30; #2 → 20; #3 → 10; lower → 0 |
| Market concentration (lower HHI = more competitive) | 25 | HHI>2500→5; 1500-2500→15; <1500→25 |
| Geographic protection (low overlap = protected) | 25 | overlap<0.2→25; <0.5→15; <0.8→5; else 0 |
| Quality rank (percentile vs peers) | 15 | P75+→15; P50+→10; P25+→5; else 0 |
"""
function competitive_position_score(
    market_result::MarketShareResult,
    overlap_result::NamedTuple;
    quality_rank_pct::Float64 = 50.0,
)
    # Market share rank (35 pts)
    share_pts = market_result.target_discharge_rank == 1 ? 35.0 :
                market_result.target_discharge_rank == 2 ? 25.0 :
                market_result.target_discharge_rank == 3 ? 15.0 : 5.0
    # Sole community provider
    length(market_result.hospitals) == 1 && (share_pts = 35.0)

    # Concentration (25 pts) — lower HHI = less dominated market = better position
    hhi_pts = market_result.hhi_discharges > HHI_MODERATELY_CONC ? 5.0 :
              market_result.hhi_discharges > HHI_UNCONCENTRATED   ? 15.0 : 25.0

    # Geographic protection (25 pts)
    geo_pts = overlap_result.weighted_overlap < 0.2 ? 25.0 :
              overlap_result.weighted_overlap < 0.5 ? 15.0 :
              overlap_result.weighted_overlap < 0.8 ? 5.0  : 0.0

    # Quality rank (15 pts)
    qual_pts = quality_rank_pct >= 75 ? 15.0 :
               quality_rank_pct >= 50 ? 10.0 :
               quality_rank_pct >= 25 ? 5.0  : 0.0

    total = share_pts + hhi_pts + geo_pts + qual_pts

    (
        total_score              = total,
        market_share_score       = share_pts,
        concentration_score      = hhi_pts,
        geographic_score         = geo_pts,
        quality_score            = qual_pts,
        strategic_position       = total >= 70 ? :strong :
                                   total >= 45 ? :moderate : :vulnerable,
    )
end
