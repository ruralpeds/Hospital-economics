# ============================================================================
# COST ANALYSIS ENGINE (Module 3: Cost Analysis for Patient Cohorts)
# ============================================================================
# Cohort-level cost analysis, inflation adjustment, and benchmarking
#
# Builds on:
# - PatientCohort (Module 2): Cohort definitions with inclusion/exclusion criteria
# - PatientEncounter (Module 1): De-identified patient encounter data
# - Episode costing models: DRG, daily-rate, RVU, activity-based

using Dates
using Statistics
using DataFrames

# ============================================================================
# CONSTANTS: Inflation and Base Year Adjustments
# ============================================================================

const BASE_YEAR = 2023  # Reference year for cost adjustments
const MEDICAL_INFLATION_RATE = 0.035  # 3.5% annual medical inflation (post-2023)
const INFLATION_BY_YEAR = Dict(
    2020 => 0.020,
    2021 => 0.025,
    2022 => 0.045,  # Higher inflation in 2022
    2023 => 0.035,  # Base year
    2024 => 0.032,
    2025 => 0.030,
    2026 => 0.029,
)

# ============================================================================
# COHORT COST SUMMARY
# ============================================================================

"""
    CohortCostSummary

Summary of costs for a patient cohort.

# Fields
- total_cost::Float64: Total cost for entire cohort
- cost_per_patient::Float64: Average cost per patient
- cost_median::Float64: Median cost per patient
- cost_std::Float64: Standard deviation of patient costs
- cost_min::Float64: Minimum patient cost
- cost_max::Float64: Maximum patient cost
- cost_percentile_90::Float64: 90th percentile cost
- cohort_size::Int: Number of patients in cohort
- inflated_to_year::Int: Year costs are adjusted to
"""
struct CohortCostSummary
    total_cost::Float64
    cost_per_patient::Float64
    cost_median::Float64
    cost_std::Float64
    cost_min::Float64
    cost_max::Float64
    cost_percentile_90::Float64
    cohort_size::Int
    inflated_to_year::Int

    function CohortCostSummary(;
        total_cost::Float64 = 0.0,
        cost_per_patient::Float64 = 0.0,
        cost_median::Float64 = 0.0,
        cost_std::Float64 = 0.0,
        cost_min::Float64 = 0.0,
        cost_max::Float64 = 0.0,
        cost_percentile_90::Float64 = 0.0,
        cohort_size::Int = 0,
        inflated_to_year::Int = BASE_YEAR
    )
        new(total_cost, cost_per_patient, cost_median, cost_std, cost_min, cost_max,
            cost_percentile_90, cohort_size, inflated_to_year)
    end
end

# ============================================================================
# COST CALCULATION: COHORT-LEVEL
# ============================================================================

"""
    calculate_cohort_total_cost(cohort::PatientCohort, encounters::Vector{PatientEncounter})::Float64

Calculate total cost for all patients in cohort.

Uses total_charges from encounters as proxy for healthcare costs.
"""
function calculate_cohort_total_cost(
    cohort::PatientCohort,
    encounters::Vector{PatientEncounter}
)::Float64
    return sum(
        enc.total_charges
        for enc in encounters
        if enc.encounter_id in cohort.encounter_ids
    )
end

"""
    calculate_cohort_cost_summary(
        cohort::PatientCohort,
        encounters::Vector{PatientEncounter};
        base_year::Int = BASE_YEAR
    )::CohortCostSummary

Calculate comprehensive cost statistics for cohort.
"""
function calculate_cohort_cost_summary(
    cohort::PatientCohort,
    encounters::Vector{PatientEncounter};
    base_year::Int = BASE_YEAR
)::CohortCostSummary
    # Filter encounters to cohort
    cohort_encounters = [
        enc for enc in encounters
        if enc.encounter_id in cohort.encounter_ids
    ]

    if isempty(cohort_encounters)
        return CohortCostSummary(inflated_to_year=base_year)
    end

    costs = [enc.total_charges for enc in cohort_encounters]

    total = sum(costs)
    n = length(costs)
    per_patient = total / n

    return CohortCostSummary(
        total_cost=total,
        cost_per_patient=per_patient,
        cost_median=median(costs),
        cost_std=std(costs),
        cost_min=minimum(costs),
        cost_max=maximum(costs),
        cost_percentile_90=quantile(costs, 0.9),
        cohort_size=n,
        inflated_to_year=base_year
    )
end

# ============================================================================
# INFLATION ADJUSTMENT
# ============================================================================

"""
    inflate_cost(
        cost::Float64,
        from_year::Int,
        to_year::Int;
        inflation_rates::Dict{Int, Float64} = INFLATION_BY_YEAR
    )::Float64

Adjust cost from one year to another using annual inflation rates.

# Arguments
- cost: Original cost in from_year dollars
- from_year: Year cost was incurred
- to_year: Year to adjust to
- inflation_rates: Dict mapping year to annual inflation rate

# Example
```julia
# Adjust \$50,000 from 2023 to 2026
inflate_cost(50_000.0, 2023, 2026)  # ~USD 54,778
```
"""
function inflate_cost(
    cost::Float64,
    from_year::Int,
    to_year::Int;
    inflation_rates::Dict{Int, Float64} = INFLATION_BY_YEAR
)::Float64
    if from_year == to_year
        return cost
    end

    adjusted_cost = cost
    if from_year < to_year
        # Inflate forward
        for year in from_year:(to_year-1)
            rate = get(inflation_rates, year, MEDICAL_INFLATION_RATE)
            adjusted_cost *= (1.0 + rate)
        end
    else
        # Deflate backward
        for year in (to_year):(from_year-1)
            rate = get(inflation_rates, year, MEDICAL_INFLATION_RATE)
            adjusted_cost /= (1.0 + rate)
        end
    end

    return adjusted_cost
end

"""
    inflate_cohort_costs(
        summary::CohortCostSummary,
        to_year::Int;
        inflation_rates::Dict{Int, Float64} = INFLATION_BY_YEAR
    )::CohortCostSummary

Adjust all costs in cohort summary to target year.
"""
function inflate_cohort_costs(
    summary::CohortCostSummary,
    to_year::Int;
    inflation_rates::Dict{Int, Float64} = INFLATION_BY_YEAR
)::CohortCostSummary
    from_year = summary.inflated_to_year

    return CohortCostSummary(
        total_cost=inflate_cost(summary.total_cost, from_year, to_year, inflation_rates),
        cost_per_patient=inflate_cost(summary.cost_per_patient, from_year, to_year, inflation_rates),
        cost_median=inflate_cost(summary.cost_median, from_year, to_year, inflation_rates),
        cost_std=inflate_cost(summary.cost_std, from_year, to_year, inflation_rates),
        cost_min=inflate_cost(summary.cost_min, from_year, to_year, inflation_rates),
        cost_max=inflate_cost(summary.cost_max, from_year, to_year, inflation_rates),
        cost_percentile_90=inflate_cost(summary.cost_percentile_90, from_year, to_year, inflation_rates),
        cohort_size=summary.cohort_size,
        inflated_to_year=to_year
    )
end

# ============================================================================
# BENCHMARKING & COMPARISON
# ============================================================================

"""
    BenchmarkResult

Comparison of cohort costs to external benchmark.

# Fields
- cohort_name::String: Name of cohort being evaluated
- cohort_cost_per_patient::Float64: Average cost per patient in cohort
- benchmark_cost_per_patient::Float64: Reference benchmark cost
- difference::Float64: Absolute difference (cohort - benchmark)
- percent_difference::Float64: Relative difference ((cohort - benchmark) / benchmark × 100)
- efficiency_ratio::Float64: Cohort cost / benchmark cost (lower is better)
- interpretation::String: "Above benchmark", "Below benchmark", "At benchmark"
- recommendation::String: Action recommendation
"""
struct BenchmarkResult
    cohort_name::String
    cohort_cost_per_patient::Float64
    benchmark_cost_per_patient::Float64
    difference::Float64
    percent_difference::Float64
    efficiency_ratio::Float64
    interpretation::String
    recommendation::String
end

"""
    benchmark_cohort(
        cohort::PatientCohort,
        summary::CohortCostSummary,
        benchmark_cost::Float64;
        tolerance::Float64 = 0.10
    )::BenchmarkResult

Compare cohort costs against a reference benchmark.

# Arguments
- cohort: PatientCohort to evaluate
- summary: CohortCostSummary with calculated costs
- benchmark_cost: Reference cost per patient (in same year/currency)
- tolerance: Tolerance band around benchmark (default 10%)

# Returns
BenchmarkResult with interpretation and recommendations
"""
function benchmark_cohort(
    cohort::PatientCohort,
    summary::CohortCostSummary,
    benchmark_cost::Float64;
    tolerance::Float64 = 0.10
)::BenchmarkResult
    cohort_cost = summary.cost_per_patient
    difference = cohort_cost - benchmark_cost
    percent_diff = (difference / benchmark_cost) * 100
    efficiency = cohort_cost / benchmark_cost

    # Interpret
    if abs(percent_diff) <= tolerance * 100
        interpretation = "At benchmark"
        recommendation = "Current cost trajectory is appropriate — maintain current care pathways"
    elseif percent_diff > 0
        interpretation = "Above benchmark"
        if percent_diff <= 20
            recommendation = "Costs moderately above benchmark — review utilization patterns and consider targeted cost reduction"
        else
            recommendation = "Costs significantly above benchmark (>20%) — urgent review of care delivery and resource allocation needed"
        end
    else
        interpretation = "Below benchmark"
        recommendation = "Costs below benchmark — continue current practices or explore scaling to other service lines"
    end

    return BenchmarkResult(
        cohort.name,
        cohort_cost,
        benchmark_cost,
        difference,
        percent_diff,
        efficiency,
        interpretation,
        recommendation
    )
end

# ============================================================================
# BUDGET IMPACT ANALYSIS
# ============================================================================

"""
    BudgetImpactModel

Analysis of budget impact of an intervention.

# Fields
- intervention_name::String: Name of intervention
- baseline_cohort_size::Int: Size of population receiving intervention
- baseline_cost_per_patient::Float64: Current cost per patient
- intervention_cost_per_patient::Float64: Cost per patient WITH intervention
- cost_savings_per_patient::Float64: Savings per patient (baseline - intervention)
- total_cost_savings::Float64: Total savings for cohort
- roi::Float64: Return on investment (savings / intervention cost)
- payback_period_months::Float64: Months to break even
- budget_year::Int: Year this analysis applies to
"""
struct BudgetImpactModel
    intervention_name::String
    baseline_cohort_size::Int
    baseline_cost_per_patient::Float64
    intervention_cost_per_patient::Float64
    cost_savings_per_patient::Float64
    total_cost_savings::Float64
    roi::Float64
    payback_period_months::Float64
    budget_year::Int
end

"""
    calculate_budget_impact(
        intervention_name::String,
        cohort::PatientCohort,
        baseline_summary::CohortCostSummary,
        intervention_cost_per_patient::Float64;
        implementation_cost::Float64 = 0.0
    )::BudgetImpactModel

Calculate budget impact of an intervention.

# Arguments
- intervention_name: Description of intervention
- cohort: PatientCohort receiving intervention
- baseline_summary: CohortCostSummary before intervention
- intervention_cost_per_patient: Expected cost per patient with intervention
- implementation_cost: One-time implementation cost (amortized annually)

# Returns
BudgetImpactModel with financial impact analysis
"""
function calculate_budget_impact(
    intervention_name::String,
    cohort::PatientCohort,
    baseline_summary::CohortCostSummary,
    intervention_cost_per_patient::Float64;
    implementation_cost::Float64 = 0.0
)::BudgetImpactModel
    baseline_cost = baseline_summary.cost_per_patient
    savings_per_patient = baseline_cost - intervention_cost_per_patient
    total_savings = savings_per_patient * cohort.size
    total_intervention_cost = intervention_cost_per_patient * cohort.size + implementation_cost

    # ROI = (Total savings - implementation cost) / Total intervention cost
    roi = total_intervention_cost > 0 ? (total_savings - implementation_cost) / total_intervention_cost : 0.0

    # Payback period in months
    if savings_per_patient > 0
        payback_months = (implementation_cost / (savings_per_patient * cohort.size)) * 12
    else
        payback_months = Inf
    end

    return BudgetImpactModel(
        intervention_name,
        cohort.size,
        baseline_cost,
        intervention_cost_per_patient,
        savings_per_patient,
        total_savings,
        roi,
        payback_months,
        Dates.year(Dates.today())
    )
end

# ============================================================================
# COST DRIVERS & STRATIFICATION
# ============================================================================

"""
    HighCostPatientAnalysis

Identify and characterize high-cost patients in cohort.
"""
struct HighCostPatientAnalysis
    cohort_name::String
    percentile_threshold::Float64  # e.g., 90th percentile
    high_cost_count::Int
    high_cost_percent::Float64
    high_cost_total::Float64
    high_cost_mean::Float64
    low_cost_total::Float64
    high_cost_concentration_ratio::Float64  # % of total cost / % of patients
end

"""
    analyze_high_cost_patients(
        cohort::PatientCohort,
        encounters::Vector{PatientEncounter};
        percentile::Float64 = 0.9
    )::HighCostPatientAnalysis

Identify high-cost patients and their cost concentration.

# Arguments
- percentile: Cost percentile threshold (default 90th)

# Returns
HighCostPatientAnalysis showing cost concentration among high-cost patients
"""
function analyze_high_cost_patients(
    cohort::PatientCohort,
    encounters::Vector{PatientEncounter};
    percentile::Float64 = 0.9
)::HighCostPatientAnalysis
    cohort_encounters = [
        enc for enc in encounters
        if enc.encounter_id in cohort.encounter_ids
    ]

    if isempty(cohort_encounters)
        return HighCostPatientAnalysis(cohort.name, percentile, 0, 0.0, 0.0, 0.0, 0.0, 0.0)
    end

    costs = [enc.total_charges for enc in cohort_encounters]
    threshold = quantile(costs, percentile)

    high_cost_encounters = [enc for enc in cohort_encounters if enc.total_charges >= threshold]
    high_cost_total = sum(enc.total_charges for enc in high_cost_encounters)
    low_cost_total = sum(enc.total_charges for enc in cohort_encounters if enc.total_charges < threshold)
    total_cost = high_cost_total + low_cost_total

    high_cost_count = length(high_cost_encounters)
    high_cost_pct = (high_cost_count / length(cohort_encounters)) * 100
    concentration_ratio = (high_cost_total / total_cost) / (high_cost_count / length(cohort_encounters))

    return HighCostPatientAnalysis(
        cohort.name,
        percentile,
        high_cost_count,
        high_cost_pct,
        high_cost_total,
        high_cost_total / high_cost_count,
        low_cost_total,
        concentration_ratio
    )
end

# ============================================================================
# COST REPORTING & FORMATTING
# ============================================================================

"""
    format_cost_summary(summary::CohortCostSummary)::String

Format cost summary for reporting.
"""
function format_cost_summary(summary::CohortCostSummary)::String
    """
    Cost Summary (Base Year: $(summary.inflated_to_year))
    ═════════════════════════════════════════
    Cohort Size:              $(summary.cohort_size) patients
    Total Cost:               USD $(format_currency(summary.total_cost))
    Cost per Patient:         USD $(format_currency(summary.cost_per_patient))
    Median Cost per Patient:  USD $(format_currency(summary.cost_median))
    Std Dev:                  USD $(format_currency(summary.cost_std))
    Cost Range:               USD $(format_currency(summary.cost_min)) - USD $(format_currency(summary.cost_max))
    90th Percentile:          USD $(format_currency(summary.cost_percentile_90))
    """
end

"""
    format_benchmark_result(result::BenchmarkResult)::String

Format benchmark comparison for reporting.
"""
function format_benchmark_result(result::BenchmarkResult)::String
    """
    Benchmark Comparison: $(result.cohort_name)
    ═════════════════════════════════════════
    Cohort Cost:              USD $(format_currency(result.cohort_cost_per_patient))
    Benchmark Cost:           USD $(format_currency(result.benchmark_cost_per_patient))
    Difference:               USD $(format_currency(result.difference)) ($(round(result.percent_difference, digits=1))%)
    Efficiency Ratio:         $(round(result.efficiency_ratio, digits=3))
    Status:                   $(result.interpretation)

    Recommendation:
    $(result.recommendation)
    """
end

"""
    format_budget_impact(impact::BudgetImpactModel)::String

Format budget impact analysis for reporting.
"""
function format_budget_impact(impact::BudgetImpactModel)::String
    payback_str = isfinite(impact.payback_period_months) ?
        "$(round(Int, impact.payback_period_months)) months" : "N/A"

    """
    Budget Impact Analysis: $(impact.intervention_name)
    ═════════════════════════════════════════
    Population Size:          $(impact.baseline_cohort_size) patients
    Baseline Cost:            USD $(format_currency(impact.baseline_cost_per_patient)) per patient
    Intervention Cost:        USD $(format_currency(impact.intervention_cost_per_patient)) per patient
    Savings per Patient:      USD $(format_currency(impact.cost_savings_per_patient))

    Total Annual Savings:     USD $(format_currency(impact.total_cost_savings))
    ROI:                      $(round(impact.roi * 100, digits=1))%
    Payback Period:           $payback_str
    """
end

# ============================================================================
# UTILITY FORMATTING
# ============================================================================

"""
    format_currency(amount::Float64)::String

Format number as USD currency string.
"""
function format_currency(amount::Float64)::String
    if amount < 0
        return "-\$($(format_currency(-amount)))"
    elseif amount >= 1_000_000
        return "$(round(amount / 1_000_000, digits=1))M"
    elseif amount >= 1_000
        return "$(round(amount / 1_000, digits=1))K"
    else
        return "$(round(amount, digits=0))"
    end
end
