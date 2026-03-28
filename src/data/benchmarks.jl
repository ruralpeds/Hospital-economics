# ============================================================================
# Benchmark Comparison Analysis
# ============================================================================

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    BenchmarkData

Contains national and peer-group median values for key financial and
operational ratios used in hospital benchmarking.

# Fields
- `operating_margin::Float64`: national median operating margin
- `total_margin::Float64`: national median total margin
- `days_cash_on_hand::Float64`: national median days cash on hand
- `current_ratio::Float64`: national median current ratio
- `debt_to_capitalization::Float64`: national median debt-to-cap ratio
- `avg_age_of_plant::Float64`: national median average age of plant (years)
- `fte_per_aob::Float64`: FTEs per adjusted occupied bed
- `salary_to_revenue::Float64`: salary-to-net-revenue ratio
- `outpatient_revenue_pct::Float64`: outpatient share of net revenue
- `medicare_ccr::Float64`: Medicare cost-to-charge ratio
- `peer_operating_margin::Float64`: peer-group median operating margin
- `peer_total_margin::Float64`: peer-group median total margin
- `peer_days_cash::Float64`: peer-group median days cash on hand
- `peer_current_ratio::Float64`: peer-group median current ratio
"""
struct BenchmarkData
    operating_margin::Float64
    total_margin::Float64
    days_cash_on_hand::Float64
    current_ratio::Float64
    debt_to_capitalization::Float64
    avg_age_of_plant::Float64
    fte_per_aob::Float64
    salary_to_revenue::Float64
    outpatient_revenue_pct::Float64
    medicare_ccr::Float64
    peer_operating_margin::Float64
    peer_total_margin::Float64
    peer_days_cash::Float64
    peer_current_ratio::Float64
end

"""
    BenchmarkComparison

Comparison of a hospital's metrics against national and peer benchmarks.
"""
struct BenchmarkComparison
    metric::String
    hospital_value::Float64
    national_median::Float64
    peer_median::Float64
    national_percentile::Float64
    variance_from_national::Float64
    variance_from_peer::Float64
    rating::String
end

# ---------------------------------------------------------------------------
# Default benchmarks
# ---------------------------------------------------------------------------

"""
    default_cah_benchmarks() -> BenchmarkData

Return typical national and peer-group benchmark values for Critical Access
Hospitals, based on published Flex Monitoring and HCRIS data.
"""
function default_cah_benchmarks()
    return BenchmarkData(
        -0.005,   # operating_margin
         0.024,   # total_margin
        95.0,     # days_cash_on_hand
         2.45,    # current_ratio
         0.32,    # debt_to_capitalization
        12.8,     # avg_age_of_plant
         6.2,     # fte_per_aob
         0.52,    # salary_to_revenue
         0.72,    # outpatient_revenue_pct
         0.42,    # medicare_ccr
        -0.008,   # peer_operating_margin
         0.020,   # peer_total_margin
        88.0,     # peer_days_cash
         2.30,    # peer_current_ratio
    )
end

# ---------------------------------------------------------------------------
# Comparison functions
# ---------------------------------------------------------------------------

"""
    compare_to_benchmarks(hospital_metrics::Dict{String,Float64},
                          benchmarks::BenchmarkData=default_cah_benchmarks()) -> Vector{BenchmarkComparison}

Compare a hospital's financial and operational metrics against national
and peer-group benchmarks.

# Arguments
- `hospital_metrics`: dictionary mapping metric names to the hospital's values
- `benchmarks`: benchmark data (defaults to national CAH medians)

# Returns
A vector of `BenchmarkComparison` structs, one per metric.
"""
function compare_to_benchmarks(hospital_metrics::Dict{String,Float64},
                               benchmarks::BenchmarkData=default_cah_benchmarks())
    # Map metric names to (national, peer) benchmark values
    benchmark_map = Dict(
        "operating_margin"      => (benchmarks.operating_margin, benchmarks.peer_operating_margin),
        "total_margin"          => (benchmarks.total_margin, benchmarks.peer_total_margin),
        "days_cash_on_hand"     => (benchmarks.days_cash_on_hand, benchmarks.peer_days_cash),
        "current_ratio"         => (benchmarks.current_ratio, benchmarks.peer_current_ratio),
        "debt_to_capitalization"=> (benchmarks.debt_to_capitalization, benchmarks.debt_to_capitalization),
        "avg_age_of_plant"      => (benchmarks.avg_age_of_plant, benchmarks.avg_age_of_plant),
        "fte_per_aob"           => (benchmarks.fte_per_aob, benchmarks.fte_per_aob),
        "salary_to_revenue"     => (benchmarks.salary_to_revenue, benchmarks.salary_to_revenue),
        "outpatient_revenue_pct"=> (benchmarks.outpatient_revenue_pct, benchmarks.outpatient_revenue_pct),
        "medicare_ccr"          => (benchmarks.medicare_ccr, benchmarks.medicare_ccr),
    )

    # Metrics where lower is better
    lower_is_better = Set([
        "debt_to_capitalization", "avg_age_of_plant",
        "fte_per_aob", "salary_to_revenue", "medicare_ccr",
    ])

    comparisons = BenchmarkComparison[]

    for (metric, value) in hospital_metrics
        if !haskey(benchmark_map, metric)
            continue
        end

        natl, peer = benchmark_map[metric]
        var_natl = value - natl
        var_peer = value - peer

        # Estimate percentile rank (simplified normal approximation)
        pctile = percentile_rank(value, natl, metric)

        # Rating
        better_higher = !(metric in lower_is_better)
        rating = _rate_metric(value, natl, better_higher)

        push!(comparisons, BenchmarkComparison(
            metric, value, natl, peer, pctile, var_natl, var_peer, rating
        ))
    end

    return comparisons
end

"""
    percentile_rank(value::Float64, median::Float64, metric::String;
                    spread::Float64=0.0) -> Float64

Estimate the percentile rank of a hospital's metric value relative to the
national distribution. Uses a simplified normal approximation with assumed
standard deviations per metric.

Returns a value between 0 and 100.
"""
function percentile_rank(value::Float64, median::Float64, metric::String;
                         spread::Float64=0.0)
    # Assumed standard deviations for common metrics
    assumed_sd = Dict(
        "operating_margin"       => 0.08,
        "total_margin"           => 0.07,
        "days_cash_on_hand"      => 80.0,
        "current_ratio"          => 1.5,
        "debt_to_capitalization" => 0.20,
        "avg_age_of_plant"       => 5.0,
        "fte_per_aob"            => 2.0,
        "salary_to_revenue"      => 0.08,
        "outpatient_revenue_pct" => 0.12,
        "medicare_ccr"           => 0.10,
    )

    sd = get(assumed_sd, metric, spread > 0 ? spread : abs(median) * 0.3 + 0.01)

    if sd <= 0
        return 50.0
    end

    z = (value - median) / sd
    # Approximate CDF using logistic function
    percentile = 100.0 / (1.0 + exp(-1.7 * z))
    return clamp(percentile, 0.1, 99.9)
end

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

"""Rate a metric as Above Average, Average, Below Average, or Critical."""
function _rate_metric(value::Float64, median::Float64, better_higher::Bool)
    diff = better_higher ? value - median : median - value

    if diff > abs(median) * 0.25
        return "Above Average"
    elseif diff > -abs(median) * 0.10
        return "Average"
    elseif diff > -abs(median) * 0.50
        return "Below Average"
    else
        return "Critical"
    end
end
