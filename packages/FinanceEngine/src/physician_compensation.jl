"""
A-14: Physician Compensation Model & Productivity Benchmarking

Models compensation structures including wRVU-based productivity pay, quality
incentives, and benchmarking against specialty-specific standards to guide
fair compensation and identify high/low performers.
"""

struct PhysicianProfile
    physician_id::String
    specialty::String
    years_experience::Int
    annual_wrvu::Float64
    annual_collections::Float64
    patient_satisfaction_score::Float64  # 0-100
    quality_metric_pct::Float64  # e.g., readmission rate, 0-100
end

struct CompensationModel
    base_salary::Float64
    wrvu_conversion_factor::Float64  # $ per wRVU
    quality_bonus_pct::Float64  # % of base if quality metrics met
    productivity_threshold_wrvu::Int
    high_performer_bonus_pct::Float64
end

struct PhysicianCompensation
    physician_id::String
    base_salary::Float64
    wrvu_based_payment::Float64
    quality_incentive::Float64
    total_compensation::Float64
    productivity_vs_benchmark_pct::Float64
    quality_vs_benchmark_pct::Float64
end

struct SpecialtyBenchmarks
    specialty::String
    median_wrvu::Float64
    median_compensation::Float64
    median_collections::Float64
    median_satisfaction::Float64
    median_quality_metric::Float64
end

"""
    calculate_physician_compensation(profile::PhysicianProfile, model::CompensationModel,
                                    specialty_median_wrvu::Float64) -> PhysicianCompensation

Calculate physician compensation including base, wRVU pay, and quality incentives.

Returns total compensation and productivity benchmarking metrics.
"""
function calculate_physician_compensation(profile::PhysicianProfile, model::CompensationModel,
                                         specialty_median_wrvu::Float64)::PhysicianCompensation
    # wRVU-based payment
    wrvu_payment = profile.annual_wrvu * model.wrvu_conversion_factor

    # Quality incentive (paid if satisfaction > 75 and quality metric > 80)
    quality_eligible = profile.patient_satisfaction_score >= 75.0 && profile.quality_metric_pct >= 80.0
    quality_incentive = quality_eligible ? model.base_salary * (model.quality_bonus_pct / 100.0) : 0.0

    # High performer bonus (if wRVU > 90th percentile estimate: specialty_median * 1.2)
    high_performer_threshold = specialty_median_wrvu * 1.2
    high_performer_bonus = profile.annual_wrvu > high_performer_threshold ?
        model.base_salary * (model.high_performer_bonus_pct / 100.0) : 0.0

    total_comp = model.base_salary + wrvu_payment + quality_incentive + high_performer_bonus

    # Benchmarking metrics
    productivity_vs_bench_pct = specialty_median_wrvu > 0 ?
        (profile.annual_wrvu / specialty_median_wrvu) * 100.0 : 0.0

    quality_vs_bench_pct = (profile.patient_satisfaction_score + profile.quality_metric_pct) / 2.0

    PhysicianCompensation(
        profile.physician_id,
        model.base_salary,
        wrvu_payment,
        quality_incentive + high_performer_bonus,
        total_comp,
        productivity_vs_bench_pct,
        quality_vs_bench_pct
    )
end

"""
    benchmark_specialty(physicians::Vector{PhysicianProfile}, specialty::String) -> SpecialtyBenchmarks

Calculate specialty-level benchmarks from physician cohort.
"""
function benchmark_specialty(physicians::Vector{PhysicianProfile}, specialty::String)::SpecialtyBenchmarks
    spec_physicians = filter(p -> p.specialty == specialty, physicians)

    if isempty(spec_physicians)
        return SpecialtyBenchmarks(specialty, 0.0, 0.0, 0.0, 0.0, 0.0)
    end

    wrvus = [p.annual_wrvu for p in spec_physicians]
    collections = [p.annual_collections for p in spec_physicians]
    satisfaction = [p.patient_satisfaction_score for p in spec_physicians]
    quality = [p.quality_metric_pct for p in spec_physicians]

    SpecialtyBenchmarks(
        specialty,
        median(wrvus),
        median(collections) * 0.65,  # Rough estimate of compensation from collections
        median(collections),
        median(satisfaction),
        median(quality)
    )
end

"""
    identify_outliers(physicians::Vector{PhysicianProfile}, specialty::String;
                     productivity_threshold::Float64=0.7) -> Vector{String}

Identify underperforming physicians based on productivity relative to specialty median.

Returns vector of physician IDs below productivity threshold.
"""
function identify_outliers(physicians::Vector{PhysicianProfile}, specialty::String;
                          productivity_threshold::Float64=0.7)::Vector{String}
    spec_physicians = filter(p -> p.specialty == specialty, physicians)
    if isempty(spec_physicians)
        return String[]
    end

    median_wrvu = median([p.annual_wrvu for p in spec_physicians])
    threshold_wrvu = median_wrvu * productivity_threshold

    [p.physician_id for p in spec_physicians if p.annual_wrvu < threshold_wrvu]
end
