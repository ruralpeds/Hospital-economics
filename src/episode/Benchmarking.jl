# episode/Benchmarking.jl — Service line benchmarking against rural hospital standards

"""
    RuralHospitalBenchmark

Benchmark data for rural hospitals by service line.
Based on CMS data and rural hospital networks.
"""
struct RuralHospitalBenchmark
    service_line::String
    median_margin_pct::Float64
    q1_margin_pct::Float64  # 25th percentile
    q3_margin_pct::Float64  # 75th percentile
    median_cost_per_case::Float64
    median_revenue_per_case::Float64
    typical_volume::Int
end

"""
    get_rural_benchmarks()::Dict{String, RuralHospitalBenchmark}

Get standard benchmarks for rural hospital service lines.
Based on aggregated CMS and HCUP data.
"""
function get_rural_benchmarks()::Dict{String, RuralHospitalBenchmark}

    return Dict(
        "Orthopedic Surgery" => RuralHospitalBenchmark(
            "Orthopedic Surgery", 18.5, 12.0, 25.0, 18500.0, 22500.0, 120
        ),
        "Cardiology" => RuralHospitalBenchmark(
            "Cardiology", 22.0, 15.0, 30.0, 16000.0, 20500.0, 180
        ),
        "General Surgery" => RuralHospitalBenchmark(
            "General Surgery", 15.0, 8.0, 22.0, 12000.0, 14100.0, 200
        ),
        "Obstetrics" => RuralHospitalBenchmark(
            "Obstetrics", 8.0, 0.0, 16.0, 8500.0, 9200.0, 150
        ),
        "Oncology" => RuralHospitalBenchmark(
            "Oncology", 25.0, 18.0, 32.0, 32000.0, 42700.0, 80
        ),
        "Emergency Medicine" => RuralHospitalBenchmark(
            "Emergency Medicine", 5.0, -5.0, 12.0, 4500.0, 4700.0, 400
        ),
        "ICU" => RuralHospitalBenchmark(
            "ICU", 12.0, 5.0, 20.0, 18000.0, 20500.0, 150
        ),
        "Neurology" => RuralHospitalBenchmark(
            "Neurology", 20.0, 12.0, 28.0, 15000.0, 18700.0, 90
        ),
    )
end

"""
    BenchmarkComparison

Results of comparing a service line to benchmarks.
"""
struct BenchmarkComparison
    service_line_id::String
    service_line_name::String
    hospital_margin_pct::Float64
    benchmark_median_margin_pct::Float64
    benchmark_q1_margin_pct::Float64
    benchmark_q3_margin_pct::Float64
    quartile::Symbol  # :above_q3, :q3_to_median, :median_to_q1, :below_q1
    percentile_rank::Float64
    hospital_cost_per_case::Float64
    benchmark_cost_per_case::Float64
    cost_efficiency::Float64  # hospital_cost / benchmark_cost
    hospital_volume::Int
    benchmark_typical_volume::Int
    performance_rating::Symbol  # :excellent, :good, :fair, :poor
    recommendations::Vector{String}
end

"""
    benchmark_compare(
        service_line::ServiceLine,
        metrics::ServiceLineMetrics,
        benchmarks::Dict{String, RuralHospitalBenchmark} = get_rural_benchmarks()
    )::Union{BenchmarkComparison, Nothing}

Compare a service line against rural hospital benchmarks.
Returns nothing if service line not found in benchmark database.
"""
function benchmark_compare(
    sl::ServiceLine,
    metrics::ServiceLineMetrics,
    benchmarks::Dict{String, RuralHospitalBenchmark} = get_rural_benchmarks()
)::Union{BenchmarkComparison, Nothing}

    # Try to find matching benchmark
    benchmark = nothing
    for (key, bench) in benchmarks
        if lowercase(key) == lowercase(sl.name) || lowercase(key) in [lowercase(sl.department)]
            benchmark = bench
            break
        end
    end

    # If no exact match, try partial match
    if benchmark === nothing
        for (key, bench) in benchmarks
            if contains(lowercase(key), lowercase(sl.name)) || contains(lowercase(sl.name), lowercase(key))
                benchmark = bench
                break
            end
        end
    end

    if benchmark === nothing
        return nothing
    end

    # Calculate metrics
    hospital_margin_pct = metrics.allocated_margin_pct
    hospital_cost_per_case = metrics.total_cost_per_case
    benchmark_cost_per_case = benchmark.median_cost_per_case

    # Determine quartile
    quartile = if hospital_margin_pct > benchmark.q3_margin_pct
        :above_q3
    elseif hospital_margin_pct > benchmark.median_margin_pct
        :q3_to_median
    elseif hospital_margin_pct > benchmark.q1_margin_pct
        :median_to_q1
    else
        :below_q1
    end

    # Calculate percentile rank (simplified)
    percentile = if hospital_margin_pct > benchmark.q3_margin_pct
        0.75 + 0.25 * min(1.0, (hospital_margin_pct - benchmark.q3_margin_pct) / 10)
    elseif hospital_margin_pct > benchmark.median_margin_pct
        0.50 + 0.25 * (hospital_margin_pct - benchmark.median_margin_pct) / (benchmark.q3_margin_pct - benchmark.median_margin_pct)
    elseif hospital_margin_pct > benchmark.q1_margin_pct
        0.25 + 0.25 * (hospital_margin_pct - benchmark.q1_margin_pct) / (benchmark.median_margin_pct - benchmark.q1_margin_pct)
    else
        max(0.0, 0.25 * (hospital_margin_pct / benchmark.q1_margin_pct))
    end

    # Cost efficiency (lower is better)
    cost_efficiency = benchmark_cost_per_case > 0 ? hospital_cost_per_case / benchmark_cost_per_case : 1.0

    # Performance rating
    performance = if hospital_margin_pct >= benchmark.q3_margin_pct && cost_efficiency <= 0.95
        :excellent
    elseif hospital_margin_pct >= benchmark.median_margin_pct || cost_efficiency <= 1.0
        :good
    elseif hospital_margin_pct >= benchmark.q1_margin_pct
        :fair
    else
        :poor
    end

    # Generate recommendations
    recommendations = generate_benchmark_recommendations(
        sl, metrics, benchmark, quartile, cost_efficiency
    )

    return BenchmarkComparison(
        sl.id, sl.name,
        hospital_margin_pct, benchmark.median_margin_pct, benchmark.q1_margin_pct, benchmark.q3_margin_pct,
        quartile, percentile,
        hospital_cost_per_case, benchmark_cost_per_case, cost_efficiency,
        sl.volume, benchmark.typical_volume,
        performance,
        recommendations
    )
end

"""
    generate_benchmark_recommendations(
        service_line::ServiceLine,
        metrics::ServiceLineMetrics,
        benchmark::RuralHospitalBenchmark,
        quartile::Symbol,
        cost_efficiency::Float64
    )::Vector{String}

Generate specific recommendations based on benchmark comparison.
"""
function generate_benchmark_recommendations(
    sl::ServiceLine,
    metrics::ServiceLineMetrics,
    benchmark::RuralHospitalBenchmark,
    quartile::Symbol,
    cost_efficiency::Float64
)::Vector{String}

    recs = String[]

    # Margin-based recommendations
    if quartile == :above_q3
        push!(recs, "EXCELLENT PERFORMANCE: '$(sl.name)' is in top quartile for margin — maintain current strategy")
    elseif quartile == :q3_to_median
        push!(recs, "GOOD PERFORMANCE: '$(sl.name)' margin is at or above median — focus on maintaining")
    elseif quartile == :median_to_q1
        push!(recs, "FAIR PERFORMANCE: '$(sl.name)' margin is below median — investigate cost reduction opportunities")
    else
        push!(recs, "POOR PERFORMANCE: '$(sl.name)' margin is below 1st quartile — urgent action required")
    end

    # Cost efficiency recommendations
    if cost_efficiency > 1.15
        push!(recs, "COST CONTROL NEEDED: '$(sl.name)' costs are 15% above benchmark — implement cost reduction initiatives")
    elseif cost_efficiency > 1.05
        push!(recs, "COST OPPORTUNITY: '$(sl.name)' costs are 5% above benchmark — optimize supply chain or staffing")
    elseif cost_efficiency < 0.90
        push!(recs, "COST ADVANTAGE: '$(sl.name)' has lower costs than peers — leverage this competitive advantage")
    end

    # Volume recommendations
    volume_diff = sl.volume - benchmark.typical_volume
    if abs(volume_diff) > benchmark.typical_volume * 0.3
        if volume_diff > 0
            push!(recs, "HIGH VOLUME: '$(sl.name)' volume $(sl.volume) exceeds typical rural hospital ($(benchmark.typical_volume)) — consider capacity expansion")
        else
            push!(recs, "LOW VOLUME: '$(sl.name)' volume $(sl.volume) is below typical ($(benchmark.typical_volume)) — consider strategic marketing")
        end
    end

    return recs
end

"""
    identify_outliers(
        service_lines::Vector{ServiceLine},
        metrics_dict::Dict{String, ServiceLineMetrics},
        benchmarks::Dict{String, RuralHospitalBenchmark} = get_rural_benchmarks()
    )::Vector{Tuple{String, String}}

Identify service lines that are outliers (significantly above or below benchmarks).
Returns pairs of (service_line_id, outlier_type).
"""
function identify_outliers(
    service_lines::Vector{ServiceLine},
    metrics_dict::Dict{String, ServiceLineMetrics},
    benchmarks::Dict{String, RuralHospitalBenchmark} = get_rural_benchmarks()
)::Vector{Tuple{String, String}}

    outliers = Tuple{String, String}[]

    for sl in service_lines
        if haskey(metrics_dict, sl.id)
            metrics = metrics_dict[sl.id]
            comparison = benchmark_compare(sl, metrics, benchmarks)

            if comparison !== nothing
                if comparison.quartile == :above_q3 && comparison.cost_efficiency < 0.95
                    push!(outliers, (sl.id, "high_performer"))
                elseif comparison.quartile == :below_q1 || comparison.cost_efficiency > 1.20
                    push!(outliers, (sl.id, "underperformer"))
                elseif comparison.hospital_volume > comparison.benchmark_typical_volume * 1.5
                    push!(outliers, (sl.id, "high_volume"))
                elseif comparison.hospital_volume < comparison.benchmark_typical_volume * 0.5
                    push!(outliers, (sl.id, "low_volume"))
                end
            end
        end
    end

    return outliers
end
