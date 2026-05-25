# Physician Compensation Modeling
#
# Evaluates physician compensation relative to wRVU productivity, specialty
# benchmarks, and quality-adjusted metrics. Identifies outliers (>2σ from
# mean comp/wRVU) and provides cohort-level analysis.

"""
    PhysicianProfile

Individual physician compensation and productivity data.

Fields:
- `name` — physician identifier
- `specialty` — clinical specialty (e.g. "Family Medicine", "Cardiology")
- `wrvu_actual` — actual work RVUs generated
- `wrvu_benchmark` — median benchmark wRVUs for specialty
- `base_salary` — annual base salary
- `quality_bonus_pct` — quality bonus as fraction of base (0.05 = 5%)
- `overhead_allocation` — allocated overhead costs
"""
@kwdef struct PhysicianProfile
    name::String
    specialty::String
    wrvu_actual::Float64
    wrvu_benchmark::Float64
    base_salary::Float64
    quality_bonus_pct::Float64 = 0.0
    overhead_allocation::Float64 = 0.0
end

"""
    CompensationResult

Computed compensation metrics for a single physician.
"""
@kwdef struct CompensationResult
    name::String
    specialty::String
    total_comp::Float64
    comp_per_wrvu::Float64
    productivity_pct::Float64
    comp_to_benchmark_ratio::Float64
    outlier_flag::Bool
end

function Base.show(io::IO, r::CompensationResult)
    flag = r.outlier_flag ? " [OUTLIER]" : ""
    print(io, "CompensationResult($(r.name): \$/wRVU=$(round(r.comp_per_wrvu, digits=2)), prod=$(round(r.productivity_pct, digits=1))%$(flag))")
end

"""
    CohortSummary

Aggregate compensation statistics for a physician specialty cohort.
"""
@kwdef struct CohortSummary
    specialty::String
    n_physicians::Int
    mean_total_comp::Float64
    median_total_comp::Float64
    mean_comp_per_wrvu::Float64
    std_comp_per_wrvu::Float64
    mean_productivity_pct::Float64
    total_wrvu::Float64
    total_compensation::Float64
    n_outliers::Int
end

function Base.show(io::IO, s::CohortSummary)
    print(io, "CohortSummary($(s.specialty): n=$(s.n_physicians), mean_comp=\$$(round(Int, s.mean_total_comp)), outliers=$(s.n_outliers))")
end

"""
    calculate_physician_compensation(profiles::Vector{PhysicianProfile}) -> Vector{CompensationResult}

Compute compensation metrics for each physician, flag outliers where
comp/wRVU is more than 2 standard deviations from the mean within their specialty.

For each physician:
- total_comp = base_salary * (1 + quality_bonus_pct)
- comp_per_wrvu = total_comp / max(wrvu_actual, 1)
- productivity_pct = wrvu_actual / wrvu_benchmark * 100
- comp_to_benchmark_ratio = comp_per_wrvu / specialty_median_comp_per_wrvu
"""
function calculate_physician_compensation(profiles::Vector{PhysicianProfile})::Vector{CompensationResult}
    !isempty(profiles) || error("profiles must not be empty")

    # First pass: compute basic metrics
    basic = [(
        name = p.name,
        specialty = p.specialty,
        total_comp = p.base_salary * (1.0 + p.quality_bonus_pct),
        comp_per_wrvu = p.wrvu_actual > 0.0 ? (p.base_salary * (1.0 + p.quality_bonus_pct)) / p.wrvu_actual : 0.0,
        productivity_pct = p.wrvu_benchmark > 0.0 ? (p.wrvu_actual / p.wrvu_benchmark) * 100.0 : 0.0,
    ) for p in profiles]

    # Compute specialty-level statistics for outlier detection
    specialties = unique(p.specialty for p in profiles)
    specialty_stats = Dict{String,Tuple{Float64,Float64}}()  # (mean, std) of comp/wRVU

    for spec in specialties
        cpw_values = [b.comp_per_wrvu for b in basic if b.specialty == spec && b.comp_per_wrvu > 0.0]
        if length(cpw_values) >= 2
            specialty_stats[spec] = (mean(cpw_values), std(cpw_values))
        elseif length(cpw_values) == 1
            specialty_stats[spec] = (cpw_values[1], 0.0)
        else
            specialty_stats[spec] = (0.0, 0.0)
        end
    end

    results = CompensationResult[]
    for (i, b) in enumerate(basic)
        spec_mean, spec_std = get(specialty_stats, b.specialty, (0.0, 0.0))

        # Outlier: comp/wRVU more than 2σ from specialty mean
        outlier = spec_std > 0.0 && abs(b.comp_per_wrvu - spec_mean) > 2.0 * spec_std

        # Benchmark ratio: relative to specialty mean
        benchmark_ratio = spec_mean > 0.0 ? b.comp_per_wrvu / spec_mean : 1.0

        push!(results, CompensationResult(
            name = b.name,
            specialty = b.specialty,
            total_comp = b.total_comp,
            comp_per_wrvu = b.comp_per_wrvu,
            productivity_pct = b.productivity_pct,
            comp_to_benchmark_ratio = benchmark_ratio,
            outlier_flag = outlier,
        ))
    end

    return results
end

"""
    physician_cohort_analysis(profiles::Vector{PhysicianProfile}) -> Vector{CohortSummary}

Aggregate physician compensation statistics by specialty.
"""
function physician_cohort_analysis(profiles::Vector{PhysicianProfile})::Vector{CohortSummary}
    !isempty(profiles) || error("profiles must not be empty")

    comp_results = calculate_physician_compensation(profiles)
    specialties = unique(p.specialty for p in profiles)
    summaries = CohortSummary[]

    for spec in specialties
        spec_results = filter(r -> r.specialty == spec, comp_results)
        spec_profiles = filter(p -> p.specialty == spec, profiles)

        comps = [r.total_comp for r in spec_results]
        cpw_values = [r.comp_per_wrvu for r in spec_results if r.comp_per_wrvu > 0.0]
        prod_values = [r.productivity_pct for r in spec_results]

        push!(summaries, CohortSummary(
            specialty = spec,
            n_physicians = length(spec_results),
            mean_total_comp = mean(comps),
            median_total_comp = length(comps) >= 1 ? quantile(comps, 0.5) : 0.0,
            mean_comp_per_wrvu = isempty(cpw_values) ? 0.0 : mean(cpw_values),
            std_comp_per_wrvu = length(cpw_values) >= 2 ? std(cpw_values) : 0.0,
            mean_productivity_pct = isempty(prod_values) ? 0.0 : mean(prod_values),
            total_wrvu = sum(p.wrvu_actual for p in spec_profiles),
            total_compensation = sum(comps),
            n_outliers = count(r -> r.outlier_flag, spec_results),
        ))
    end

    return summaries
end
