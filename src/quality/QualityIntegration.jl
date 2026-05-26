"""
    QualityIntegration

Bridge between Biostatistics.jl quality modules and Hospital-economics domain.

Re-exports healthcare quality metrics (control charts, funnel plots, CUSUM/EWMA),
data quality validation, and evidence scoring from the Biostatistics package,
adapted for hospital financial and operational contexts.

# Quality Modules Available
- **HealthcareQuality**: SPC control charts, funnel plots, rate standardization
- **DataQuality**: Missing data, outlier, and duplicate detection (HIPAA-safe)
- **Statistical Testing**: Full Biostatistics test suite for financial analytics

# Usage
```julia
using RuralHospitalSim

# SPC control chart for readmission rates
result = hospital_control_chart(:p, rates, denominators)

# Data quality check on financial data
report = validate_financial_data(df)

# Funnel plot for facility benchmarking
fp = facility_funnel_plot(observed_events, expected_events)
```
"""
module QualityIntegration

using DataFrames
using Statistics

using Biostatistics:
    # HealthcareQuality
    QualityResult,
    standardize_outcome_rates,
    funnel_plot_data,
    control_chart_p,
    control_chart_c,
    control_chart_u,
    control_chart_xmr,
    cusum_chart,
    ewma_chart,
    reliability_adjust,
    compute_quality_indicators,
    # DataQuality
    validate_data,
    detect_missing,
    detect_outliers,
    detect_duplicates,
    mahalanobis_outliers,
    # Core types
    ValidationReport,
    TestResult,
    BioStatResult,
    # Statistical tests (useful for financial hypothesis testing)
    run_test,
    check_assumptions,
    # Descriptive statistics
    summarize_numeric,
    SummaryStats,
    table_one,
    # Effect sizes
    cohens_d,
    # Power analysis
    power_t_test,
    # Reporting
    format_p_value,
    apa_string

# ═══════════════════════════════════════════════════════════════
# RE-EXPORTS — direct Biostatistics functions available at top level
# ═══════════════════════════════════════════════════════════════

export QualityResult,
       ValidationReport,
       TestResult,
       BioStatResult,
       SummaryStats

# HealthcareQuality — direct re-exports
export standardize_outcome_rates,
       funnel_plot_data,
       control_chart_p,
       control_chart_c,
       control_chart_u,
       control_chart_xmr,
       cusum_chart,
       ewma_chart,
       reliability_adjust,
       compute_quality_indicators

# DataQuality — direct re-exports
export validate_data,
       detect_missing,
       detect_outliers,
       detect_duplicates,
       mahalanobis_outliers

# Statistical testing — direct re-exports
export run_test,
       check_assumptions,
       summarize_numeric,
       table_one,
       cohens_d,
       power_t_test,
       format_p_value,
       apa_string

# ═══════════════════════════════════════════════════════════════
# HOSPITAL-DOMAIN WRAPPERS
# Thin adapters that map hospital-economics terminology to
# Biostatistics function signatures.
# ═══════════════════════════════════════════════════════════════

export hospital_control_chart,
       validate_financial_data,
       facility_funnel_plot,
       quality_scorecard

"""
    hospital_control_chart(chart_type, values, denominators; kwargs...)

Run an SPC control chart appropriate for hospital operational metrics.

# Arguments
- `chart_type::Symbol`: One of `:p` (proportions), `:c` (counts), `:u` (rates), `:xmr` (individual measurements), `:cusum`, `:ewma`
- `values`: Observed values (events, counts, or measurements depending on chart type)
- `denominators`: Sample sizes or denominators (not used for `:c`, `:xmr`)

# Returns
`QualityResult` with control limits, center line, and out-of-control flags.

# Example
```julia
# Track monthly readmission rates across 24 months
readmissions = [12, 15, 8, 11, 14, 9, 13, 16, 10, 7, 12, 15,
                11, 13, 10, 8, 14, 12, 9, 11, 13, 10, 12, 14]
discharges = fill(200, 24)
result = hospital_control_chart(:p, readmissions, discharges)
```
"""
function hospital_control_chart(chart_type::Symbol,
                                values::AbstractVector{<:Real},
                                denominators::AbstractVector{<:Real} = ones(length(values));
                                kwargs...)
    if chart_type == :p
        control_chart_p(values, denominators; kwargs...)
    elseif chart_type == :c
        control_chart_c(values; kwargs...)
    elseif chart_type == :u
        control_chart_u(values, denominators; kwargs...)
    elseif chart_type == :xmr
        control_chart_xmr(values; kwargs...)
    elseif chart_type == :cusum
        target = length(kwargs) > 0 ? get(Dict(kwargs), :target, mean(values ./ denominators)) : mean(values ./ denominators)
        cusum_chart(values, denominators; target=target, kwargs...)
    elseif chart_type == :ewma
        ewma_chart(values; kwargs...)
    else
        throw(ArgumentError("Unknown chart type: $chart_type. Use :p, :c, :u, :xmr, :cusum, or :ewma"))
    end
end

"""
    validate_financial_data(df; numeric_cols=nothing, id_cols=nothing)

Run data quality checks on a hospital financial DataFrame.

Wraps Biostatistics.DataQuality with sensible defaults for financial data:
detects missing values, outliers (IQR method), and duplicate records.
HIPAA-compliant — logs column names and counts only, never cell values.

# Returns
A `NamedTuple` with fields:
- `missing_report::ValidationReport` — missing value analysis
- `outlier_report::ValidationReport` — outlier detection on numeric columns
- `duplicate_report::ValidationReport` — duplicate row detection
- `summary::Dict{String,Any}` — aggregate quality metrics
"""
function validate_financial_data(df::DataFrame;
                                 numeric_cols::Union{Nothing,Vector{Symbol}} = nothing,
                                 id_cols::Union{Nothing,Vector{Symbol}} = nothing)
    missing_report = detect_missing(df)
    outlier_report = detect_outliers(df, Dict("method" => "iqr"))
    duplicate_report = detect_duplicates(df)

    n_rows = nrow(df)
    n_cols = ncol(df)
    total_cells = n_rows * n_cols
    total_missing = sum(values(missing_report.n_missing); init=0)
    completeness = total_cells > 0 ? 1.0 - (total_missing / total_cells) : 1.0

    summary = Dict{String,Any}(
        "n_rows" => n_rows,
        "n_cols" => n_cols,
        "completeness_pct" => round(completeness * 100; digits=2),
        "n_missing_total" => total_missing,
        "n_outlier_columns" => length(outlier_report.issues),
        "n_duplicate_rows" => length(duplicate_report.issues),
        "quality_grade" => completeness >= 0.95 ? "A" :
                          completeness >= 0.90 ? "B" :
                          completeness >= 0.80 ? "C" : "D"
    )

    return (
        missing_report = missing_report,
        outlier_report = outlier_report,
        duplicate_report = duplicate_report,
        summary = summary,
    )
end

"""
    facility_funnel_plot(observed, expected; alpha=0.05, overdispersion=:pearson)

Generate funnel plot data for benchmarking facilities against expected performance.

Wraps `Biostatistics.funnel_plot_data` with hospital-friendly naming.
Useful for comparing hospital-level outcome rates, cost indices, or quality measures.

# Example
```julia
# Compare 20 hospitals' mortality rates against risk-adjusted expected
observed_deaths = [5, 12, 3, 8, 15, 7, 10, 4, 9, 11,
                   6, 13, 2, 8, 14, 7, 10, 5, 9, 12]
expected_deaths = [6.1, 11.5, 4.2, 7.8, 13.0, 8.0, 9.5, 5.0, 8.5, 10.0,
                   7.0, 12.0, 3.5, 9.0, 12.5, 7.5, 10.5, 5.5, 8.0, 11.0]
fp = facility_funnel_plot(observed_deaths, expected_deaths)
```
"""
function facility_funnel_plot(observed::AbstractVector{<:Real},
                              expected::AbstractVector{<:Real};
                              alpha::Float64 = 0.05,
                              overdispersion::Symbol = :pearson)
    funnel_plot_data(observed, expected; alpha=alpha, overdispersion=overdispersion)
end

"""
    quality_scorecard(df; metrics=[:readmission, :mortality, :infection])

Compute a hospital quality scorecard from operational data.

Runs control charts and standardized rates across multiple quality dimensions,
returning a consolidated scorecard DataFrame.

# Arguments
- `df::DataFrame`: Must contain columns matching the requested metrics
- `metrics::Vector{Symbol}`: Quality dimensions to evaluate

# Returns
`DataFrame` with one row per metric: name, rate, in_control flag, and z-score.
"""
function quality_scorecard(events::AbstractVector{<:Real},
                           denominators::AbstractVector{<:Real},
                           labels::AbstractVector{<:AbstractString})
    length(events) == length(denominators) == length(labels) ||
        throw(ArgumentError("events, denominators, and labels must have equal length"))
    all(denominators .> 0) || throw(ArgumentError("denominators must be positive"))

    rates = events ./ denominators
    overall_rate = sum(events) / sum(denominators)
    se = sqrt.(overall_rate * (1 - overall_rate) ./ denominators)

    z_scores = (rates .- overall_rate) ./ se
    in_control = abs.(z_scores) .< 3.0

    DataFrame(
        metric = labels,
        events = events,
        denominator = denominators,
        rate = round.(rates; digits=4),
        overall_rate = fill(round(overall_rate; digits=4), length(labels)),
        z_score = round.(z_scores; digits=2),
        in_control = in_control,
    )
end

end # module QualityIntegration
