"""
    peer_benchmarking.jl — Hospital Peer Benchmarking (MBA Gap C-07)

Provides percentile-band comparison of hospital financial and operational
ratios against peer CAH, REH, and rural PPS benchmarks from three sources:

1. **Flex Monitoring Team** — 10 financial ratios for CAHs (annual, CMS-funded)
2. **MGMA Cost Survey** — physician productivity (wRVU, cost/wRVU) by specialty
3. **AHA Annual Survey** — operational ratios (LOS, FTE/AOB, OR utilization)

Embedded 2023 benchmark data (latest public release as of Apr 2026).
Data source: Flex Monitoring Team CAH Financial Indicators Report No. 25 (2024),
MGMA DataDive Cost and Revenue 2023, AHA Hospital Statistics 2024.

All benchmarks are for CAHs unless specified. PPS rural and REH benchmarks
are noted where available.
"""

using Statistics
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# Embedded benchmark tables
# ─────────────────────────────────────────────────────────────────────────────

"""
    FlexMonitoringBenchmarks

Flex Monitoring Team CAH Financial Indicators (2022 fiscal year data, published 2024).
Rows: ratio name → (P25, Median, P75, Mean) — all values in native units.

Source: Flex Monitoring Team Financial Indicators Report No. 25, Table 1.
Units:
  - Margins: decimal (0.05 = 5%)
  - Days: days
  - Ratios: ×
  - Percentages: decimal
"""
const FLEX_MONITORING_2022 = Dict{Symbol, NamedTuple{(:p25,:median,:p75,:mean,:unit),
                                                      Tuple{Float64,Float64,Float64,Float64,Symbol}}}(
    :operating_margin => (p25=-0.0320, median=0.0150, p75=0.0480, mean=0.0110, unit=:decimal),
    :total_margin     => (p25=-0.0110, median=0.0320, p75=0.0660, mean=0.0330, unit=:decimal),
    :days_cash_on_hand => (p25=32.5, median=65.4, p75=112.8, mean=78.2, unit=:days),
    :current_ratio    => (p25=1.41, median=2.02, p75=3.05, mean=2.27, unit=:ratio),
    :debt_to_cap      => (p25=0.162, median=0.320, p75=0.471, mean=0.319, unit=:decimal),
    :avg_age_of_plant => (p25=8.4, median=12.6, p75=17.8, mean=13.2, unit=:years),
    :fte_per_aob      => (p25=4.8, median=6.2, p75=8.4, mean=6.6, unit=:ratio),
    :salary_to_revenue => (p25=0.430, median=0.508, p75=0.578, mean=0.505, unit=:decimal),
    :outpatient_pct   => (p25=0.582, median=0.658, p75=0.731, mean=0.654, unit=:decimal),
    :mcr_cost_to_charge => (p25=0.312, median=0.408, p75=0.521, mean=0.413, unit=:ratio),
)

"""
    AHARuralBenchmarks

AHA Hospital Statistics 2024 — operational benchmarks for rural hospitals.
Source: AHA Annual Survey 2023 (rural community hospitals, beds < 100).
"""
const AHA_RURAL_2023 = Dict{Symbol, NamedTuple{(:p25,:median,:p75,:mean,:unit),
                                                Tuple{Float64,Float64,Float64,Float64,Symbol}}}(
    :alos_inpatient   => (p25=3.2, median=4.1, p75=5.4, mean=4.3, unit=:days),
    :ed_visits_per_bed => (p25=105.0, median=165.0, p75=240.0, mean=180.0, unit=:ratio),
    :occupancy_rate   => (p25=0.28, median=0.42, p75=0.58, mean=0.43, unit=:decimal),
    :fte_per_adjusted_discharge => (p25=12.8, median=16.4, p75=22.1, mean=17.5, unit=:ratio),
    :net_revenue_per_adjusted_discharge => (p25=9_200.0, median=12_400.0, p75=16_800.0, mean=13_100.0, unit=:dollars),
    :cost_per_adjusted_discharge => (p25=8_800.0, median=11_900.0, p75=16_200.0, mean=12_600.0, unit=:dollars),
    :charity_care_pct => (p25=0.012, median=0.028, p75=0.055, mean=0.033, unit=:decimal),
)

"""
    MGMAPhysicianBenchmarks

MGMA DataDive 2023 — physician productivity by specialty.
Source: MGMA Cost and Revenue Survey 2023.
Values: wRVU = work relative value units; compensation = total annual USD.
"""
const MGMA_2023 = Dict{Symbol, NamedTuple{(:wrvu_p25,:wrvu_median,:wrvu_p75,:comp_median,:cost_per_wrvu_median),
                                           Tuple{Float64,Float64,Float64,Float64,Float64}}}(
    :family_medicine   => (wrvu_p25=3_800.0, wrvu_median=4_750.0, wrvu_p75=5_900.0,
                           comp_median=248_000.0, cost_per_wrvu_median=52.2),
    :internal_medicine => (wrvu_p25=3_600.0, wrvu_median=4_500.0, wrvu_p75=5_600.0,
                           comp_median=258_000.0, cost_per_wrvu_median=57.4),
    :general_surgery   => (wrvu_p25=5_200.0, wrvu_median=6_800.0, wrvu_p75=8_400.0,
                           comp_median=380_000.0, cost_per_wrvu_median=55.9),
    :emergency_medicine => (wrvu_p25=4_800.0, wrvu_median=6_200.0, wrvu_p75=7_500.0,
                             comp_median=330_000.0, cost_per_wrvu_median=53.2),
    :hospitalist       => (wrvu_p25=3_400.0, wrvu_median=4_200.0, wrvu_p75=5_100.0,
                           comp_median=280_000.0, cost_per_wrvu_median=66.7),
    :ob_gyn            => (wrvu_p25=4_400.0, wrvu_median=5_600.0, wrvu_p75=7_000.0,
                           comp_median=310_000.0, cost_per_wrvu_median=55.4),
    :pediatrics        => (wrvu_p25=3_200.0, wrvu_median=4_100.0, wrvu_p75=5_200.0,
                           comp_median=230_000.0, cost_per_wrvu_median=56.1),
    :radiology         => (wrvu_p25=8_500.0, wrvu_median=11_200.0, wrvu_p75=14_000.0,
                           comp_median=490_000.0, cost_per_wrvu_median=43.8),
    :anesthesiology    => (wrvu_p25=7_200.0, wrvu_median=9_500.0, wrvu_p75=12_100.0,
                           comp_median=450_000.0, cost_per_wrvu_median=47.4),
    :orthopedics       => (wrvu_p25=7_500.0, wrvu_median=9_800.0, wrvu_p75=12_400.0,
                           comp_median=560_000.0, cost_per_wrvu_median=57.1),
)

# ─────────────────────────────────────────────────────────────────────────────
# Percentile interpolation helper
# ─────────────────────────────────────────────────────────────────────────────

"""
    _percentile_from_value(value, p25, median, p75; higher_is_better=true) -> Float64

Estimate the approximate percentile of `value` within a benchmark distribution
defined by its P25, P50 (median), and P75 using piecewise linear interpolation.

Returns a value in [0, 100] (percentile).
"""
function _percentile_from_value(
    value::Float64,
    p25::Float64,
    median::Float64,
    p75::Float64;
    higher_is_better::Bool = true,
)::Float64
    # Piecewise linear interpolation between known percentile anchors
    # Assumes: P5 ≈ P25 − 1.5×(P75−P25)/2, P95 ≈ P75 + 1.5×(P75−P25)/2
    iqr = p75 - p25
    p5  = p25 - 1.5 * iqr / 2
    p95 = p75 + 1.5 * iqr / 2

    segments = [(p5, 5.0), (p25, 25.0), (median, 50.0), (p75, 75.0), (p95, 95.0)]

    if value <= p5
        pct = 5.0 * (value - (p5 - iqr)) / (p5 - (p5 - iqr))
        pct = clamp(pct, 1.0, 5.0)
    elseif value >= p95
        pct = 95.0 + 5.0 * (value - p95) / iqr
        pct = clamp(pct, 95.0, 99.0)
    else
        pct = 5.0
        for i in 1:length(segments)-1
            lo_v, lo_p = segments[i]
            hi_v, hi_p = segments[i+1]
            if lo_v <= value <= hi_v
                frac = (value - lo_v) / (hi_v - lo_v)
                pct  = lo_p + frac * (hi_p - lo_p)
                break
            end
        end
    end
    clamp(pct, 1.0, 99.0)
end

# ─────────────────────────────────────────────────────────────────────────────
# Core benchmarking result types
# ─────────────────────────────────────────────────────────────────────────────

"""
    BenchmarkComparison

Single-metric benchmark comparison result.

# Fields
- `metric::Symbol`
- `hospital_value::Float64`
- `p25::Float64`, `median::Float64`, `p75::Float64`, `mean::Float64`
- `percentile::Float64`: Hospital's estimated percentile within the peer distribution.
- `unit::Symbol`: Unit of measure (`:decimal`, `:days`, `:ratio`, `:dollars`, `:years`).
- `higher_is_better::Bool`
- `performance_tier::Symbol`: `:strong` (≥P75), `:adequate` (P25–P75), `:watch` (<P25).
- `source::Symbol`: `:flex_monitoring`, `:aha_rural`, or `:mgma`.
"""
struct BenchmarkComparison
    metric::Symbol
    hospital_value::Float64
    p25::Float64
    median::Float64
    p75::Float64
    mean::Float64
    percentile::Float64
    unit::Symbol
    higher_is_better::Bool
    performance_tier::Symbol
    source::Symbol
end

"""
    PeerBenchmarkReport

Full peer benchmark report for a hospital.

# Fields
- `hospital_id::Any`
- `comparisons::Vector{BenchmarkComparison}`: One per metric benchmarked.
- `overall_percentile::Float64`: Mean percentile across all benchmarked metrics.
- `strengths::Vector{Symbol}`: Metrics in `:strong` tier.
- `watches::Vector{Symbol}`: Metrics in `:watch` tier.
- `source_counts::Dict{Symbol,Int}`: How many metrics from each source.
"""
struct PeerBenchmarkReport
    hospital_id::Any
    comparisons::Vector{BenchmarkComparison}
    overall_percentile::Float64
    strengths::Vector{Symbol}
    watches::Vector{Symbol}
    source_counts::Dict{Symbol, Int}
end

# Metrics where lower = better
const _LOWER_IS_BETTER = Set([
    :debt_to_cap, :avg_age_of_plant, :fte_per_aob, :salary_to_revenue,
    :mcr_cost_to_charge, :alos_inpatient, :fte_per_adjusted_discharge,
    :cost_per_adjusted_discharge, :charity_care_pct,
])

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

"""
    benchmark_flex_monitoring(hospital_id, metrics::Dict{Symbol,Float64}) -> PeerBenchmarkReport

Compare a hospital's Flex Monitoring financial ratios against the CAH peer
distribution.

`metrics` keys must match the keys in `FLEX_MONITORING_2022`:
`:operating_margin`, `:total_margin`, `:days_cash_on_hand`, `:current_ratio`,
`:debt_to_cap`, `:avg_age_of_plant`, `:fte_per_aob`, `:salary_to_revenue`,
`:outpatient_pct`, `:mcr_cost_to_charge`.

Unrecognized keys are silently ignored. Missing keys are not benchmarked.

# Example
```julia
report = benchmark_flex_monitoring("Valley CAH", Dict(
    :operating_margin   => 0.028,
    :total_margin       => 0.045,
    :days_cash_on_hand  => 58.0,
    :current_ratio      => 1.85,
    :debt_to_cap        => 0.38,
    :salary_to_revenue  => 0.52,
))
for c in report.comparisons
    println(c.metric, ": P", round(Int, c.percentile), " (", c.performance_tier, ")")
end
```
"""
function benchmark_flex_monitoring(
    hospital_id,
    metrics::Dict{Symbol, Float64},
)::PeerBenchmarkReport
    _benchmark_against(hospital_id, metrics, FLEX_MONITORING_2022, :flex_monitoring)
end

"""
    benchmark_aha_rural(hospital_id, metrics::Dict{Symbol,Float64}) -> PeerBenchmarkReport

Compare a hospital's operational ratios against AHA rural hospital benchmarks.

`metrics` keys: `:alos_inpatient`, `:ed_visits_per_bed`, `:occupancy_rate`,
`:fte_per_adjusted_discharge`, `:net_revenue_per_adjusted_discharge`,
`:cost_per_adjusted_discharge`, `:charity_care_pct`.
"""
function benchmark_aha_rural(
    hospital_id,
    metrics::Dict{Symbol, Float64},
)::PeerBenchmarkReport
    _benchmark_against(hospital_id, metrics, AHA_RURAL_2023, :aha_rural)
end

"""
    benchmark_mgma_physician(hospital_id, specialty::Symbol,
                              actual_wrvu::Float64,
                              actual_cost_per_wrvu::Float64) -> NamedTuple

Compare a physician's productivity and cost against MGMA specialty benchmarks.

`specialty` must be one of: `:family_medicine`, `:internal_medicine`,
`:general_surgery`, `:emergency_medicine`, `:hospitalist`, `:ob_gyn`,
`:pediatrics`, `:radiology`, `:anesthesiology`, `:orthopedics`.

Returns a NamedTuple with:
- `specialty`, `actual_wrvu`, `actual_cost_per_wrvu`
- `wrvu_percentile`: wRVU output percentile (higher = better).
- `cost_percentile`: cost/wRVU percentile (lower = better → invert so higher = better).
- `wrvu_p25/median/p75`, `comp_median`
- `performance_tier::Symbol`
"""
function benchmark_mgma_physician(
    hospital_id,
    specialty::Symbol,
    actual_wrvu::Float64,
    actual_cost_per_wrvu::Float64,
)
    haskey(MGMA_2023, specialty) ||
        throw(ArgumentError("Unknown specialty: $(repr(specialty)). " *
                            "Valid: $(sort(collect(keys(MGMA_2023))))"))
    bm = MGMA_2023[specialty]

    wrvu_pct = _percentile_from_value(actual_wrvu,
                   bm.wrvu_p25, bm.wrvu_median, bm.wrvu_p75;
                   higher_is_better=true)

    # Cost/wRVU: lower is better → invert for tier labelling
    cost_p25_approx   = bm.cost_per_wrvu_median * 0.85
    cost_p75_approx   = bm.cost_per_wrvu_median * 1.15
    cost_raw_pct = _percentile_from_value(actual_cost_per_wrvu,
                       cost_p25_approx, bm.cost_per_wrvu_median, cost_p75_approx;
                       higher_is_better=false)
    # Invert so that "lower cost = higher percentile" for tier
    cost_pct_inverted = 100.0 - cost_raw_pct

    overall = (wrvu_pct + cost_pct_inverted) / 2.0
    tier = overall >= 75 ? :strong : overall >= 25 ? :adequate : :watch

    (
        hospital_id           = hospital_id,
        specialty             = specialty,
        actual_wrvu           = actual_wrvu,
        actual_cost_per_wrvu  = actual_cost_per_wrvu,
        wrvu_percentile       = wrvu_pct,
        cost_percentile_inverted = cost_pct_inverted,
        overall_percentile    = overall,
        wrvu_p25              = bm.wrvu_p25,
        wrvu_median           = bm.wrvu_median,
        wrvu_p75              = bm.wrvu_p75,
        comp_median           = bm.comp_median,
        cost_per_wrvu_median  = bm.cost_per_wrvu_median,
        performance_tier      = tier,
    )
end

"""
    comprehensive_benchmark(hospital_id,
                            flex_metrics, aha_metrics) -> PeerBenchmarkReport

Run both Flex Monitoring and AHA Rural benchmarks and merge into a single report.
"""
function comprehensive_benchmark(
    hospital_id,
    flex_metrics::Dict{Symbol, Float64},
    aha_metrics::Dict{Symbol, Float64},
)::PeerBenchmarkReport
    flex_report = benchmark_flex_monitoring(hospital_id, flex_metrics)
    aha_report  = benchmark_aha_rural(hospital_id, aha_metrics)

    all_comparisons = vcat(flex_report.comparisons, aha_report.comparisons)
    _build_report(hospital_id, all_comparisons)
end

# ─────────────────────────────────────────────────────────────────────────────
# Internal helpers
# ─────────────────────────────────────────────────────────────────────────────

function _benchmark_against(
    hospital_id,
    metrics::Dict{Symbol, Float64},
    table::Dict,
    source::Symbol,
)::PeerBenchmarkReport
    comparisons = BenchmarkComparison[]
    for (metric, value) in metrics
        haskey(table, metric) || continue
        bm = table[metric]
        higher = metric ∉ _LOWER_IS_BETTER
        pct = _percentile_from_value(value, bm.p25, bm.median, bm.p75;
                                     higher_is_better=higher)
        tier = (higher ? pct : 100-pct) >= 75 ? :strong :
               (higher ? pct : 100-pct) >= 25 ? :adequate : :watch
        push!(comparisons, BenchmarkComparison(
            metric, value, bm.p25, bm.median, bm.p75, bm.mean,
            pct, bm.unit, higher, tier, source,
        ))
    end
    _build_report(hospital_id, comparisons)
end

function _build_report(hospital_id, comparisons::Vector{BenchmarkComparison})
    isempty(comparisons) &&
        return PeerBenchmarkReport(hospital_id, comparisons, NaN, Symbol[], Symbol[],
                                   Dict{Symbol,Int}())
    percentiles = [c.percentile for c in comparisons]
    overall     = mean(percentiles)
    strengths   = [c.metric for c in comparisons if c.performance_tier == :strong]
    watches     = [c.metric for c in comparisons if c.performance_tier == :watch]
    counts      = Dict{Symbol,Int}()
    for c in comparisons
        counts[c.source] = get(counts, c.source, 0) + 1
    end
    PeerBenchmarkReport(hospital_id, comparisons, overall, strengths, watches, counts)
end

"""
    benchmark_report_text(report::PeerBenchmarkReport) -> String

Render a `PeerBenchmarkReport` as a formatted text summary.
"""
function benchmark_report_text(report::PeerBenchmarkReport)::String
    io = IOBuffer()
    println(io, "═"^70)
    println(io, "Peer Benchmark Report — $(report.hospital_id)")
    println(io, "Overall Percentile: $(round(report.overall_percentile, digits=1))")
    println(io, "═"^70)
    for c in sort(report.comparisons; by=r->-r.percentile)
        tier_sym = c.performance_tier == :strong ? "▲" :
                   c.performance_tier == :adequate ? "●" : "▼"
        val_str = c.unit == :decimal ? @sprintf("%.1f%%", c.hospital_value*100) :
                  c.unit == :days   ? @sprintf("%.1f d", c.hospital_value) :
                  c.unit == :dollars ? @sprintf("\$%.0f", c.hospital_value) :
                                       @sprintf("%.2f×", c.hospital_value)
        println(io, @sprintf("  %s %-38s %12s  P%-3.0f  [%s]",
            tier_sym, c.metric, val_str, c.percentile, c.source))
    end
    println(io, "─"^70)
    println(io, "  Strengths (≥P75): ", join(report.strengths, ", "))
    println(io, "  Watch    (<P25):  ", join(report.watches,   ", "))
    String(take!(io))
end
