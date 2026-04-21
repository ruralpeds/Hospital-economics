"""
    PolicyValidation

Module for validating multi-level policy simulations against real-world case studies.

Implements validation for four major U.S. healthcare policy events:
1. Kentucky Medicaid Expansion (2014)
2. Maryland All-Payer Model (2014-2018)
3. Rural Hospital Closures (2010-2023)
4. COVID-19 Impact (2020-2021)

Provides infrastructure for:
- Loading actual policy outcomes
- Comparing simulated vs. actual results
- Calculating validation metrics (MAPE, directional accuracy)
- Identifying heterogeneous impacts (which hospitals affected most)
- Generating validation reports
"""

module PolicyValidation

export CaseStudy, ValidationMetrics, ValidationResult, OutcomeRow, ComparisonRow
export KentuckyMedicaidExpansion, MarylandAllPayerModel
export RuralHospitalClosureCase, COVID19ImpactCase
export load_case_study, validate_simulation, calculate_metrics
export generate_validation_report, compare_outcomes

using Statistics
using Dates

# ====================================
# Lightweight table types (no DataFrames dependency)
# ====================================

"""
    OutcomeRow

A single row in an outcomes table: outcome name, numeric value, and direction.
"""
struct OutcomeRow
    outcome::String
    outcome_value::Float64
    outcome_change::Float64
end

"""
    ComparisonRow

Hospital-level comparison row: id, actual margin, simulated margin, absolute error,
and percentage error.
"""
struct ComparisonRow
    hospital_id::String
    actual_margin::Float64
    simulated_margin::Float64
    error::Float64
    error_pct::Float64
end

# ====================================
# Validation Data Structures
# ====================================

"""
    ValidationMetrics

Metrics comparing simulated vs. actual outcomes.
"""
mutable struct ValidationMetrics
    mape::Float64                          # Mean absolute percentage error
    directional_accuracy::Float64          # % correct direction predictions
    rmse::Float64                          # Root mean squared error
    correlation::Float64                   # Pearson correlation
    max_error::Float64                     # Maximum absolute error
    metadata::Dict{String, Any}
end

"""
    ValidationResult

Results of validating a simulation against case study data.
"""
mutable struct ValidationResult
    case_study_name::String
    simulation_name::String
    metrics::ValidationMetrics
    actual_outcomes::Vector{OutcomeRow}
    simulated_outcomes::Vector{OutcomeRow}
    hospital_level_results::Dict{String, Dict{String, Float64}}
    summary::String
    timestamp::DateTime
end

"""
    CaseStudy

Abstract type for policy case studies.
"""
abstract type CaseStudy end

# ====================================
# Case Study Implementations
# ====================================

"""
    KentuckyMedicaidExpansion

Kentucky Medicaid Expansion (2014)
- 400,000+ new Medicaid enrollees
- Impact on hospital revenues, margins, service capacity
"""
mutable struct KentuckyMedicaidExpansion <: CaseStudy
    name::String
    year::Int
    new_enrollees::Int
    affected_hospitals::Int
    baseline_margin::Float64
    actual_margin_changes::Dict{String, Float64}  # Hospital ID -> margin change %
    actual_closures::Vector{String}               # Hospital IDs that closed
    metadata::Dict{String, Any}
end

"""
    MarylandAllPayerModel

Maryland All-Payer Model (2014-2018)
- Global budgets for hospital care
- Quality incentive pools
- Bundled payments
"""
mutable struct MarylandAllPayerModel <: CaseStudy
    name::String
    year_start::Int
    year_end::Int
    affected_hospitals::Int
    global_budget_growth_limit::Float64   # Annual growth cap
    quality_incentive_pool_pct::Float64
    actual_cost_growth::Float64            # vs. baseline
    actual_margin_changes::Dict{String, Float64}
    actual_quality_improvements::Dict{String, Float64}
    metadata::Dict{String, Any}
end

"""
    RuralHospitalClosureCase

Rural Hospital Closures (2010-2023)
- ~100 closures nationwide
- Validates margin thresholds and service line sustainability
"""
mutable struct RuralHospitalClosureCase <: CaseStudy
    name::String
    year_start::Int
    year_end::Int
    actual_closures::Vector{String}       # Hospital IDs that closed
    closure_years::Dict{String, Int}      # Hospital ID -> year closed
    pre_closure_margins::Dict{String, Float64}
    pre_closure_services::Dict{String, Vector{String}}
    region_data::Dict{String, Dict{String, Any}}  # Regional context
    metadata::Dict{String, Any}
end

"""
    COVID19ImpactCase

COVID-19 Impact (2020-2021)
- Volume shocks to inpatient and elective services
- Cost structure changes
- Rural hospital viability crisis
"""
mutable struct COVID19ImpactCase <: CaseStudy
    name::String
    year_start::Int
    year_end::Int
    volume_shock_percent::Float64          # Overall patient volume change
    inpatient_shock::Float64
    elective_shock::Float64
    icu_surge_capacity_cost::Float64
    supply_cost_increase::Float64
    actual_margin_changes::Dict{String, Float64}
    actual_closures::Vector{String}
    metadata::Dict{String, Any}
end

# ====================================
# Constructors
# ====================================

function KentuckyMedicaidExpansion(;
    year=2014,
    new_enrollees=400000,
    affected_hospitals=100,
    baseline_margin=0.03,
    actual_margin_changes=Dict{String, Float64}(),
    actual_closures=String[],
    metadata=Dict{String, Any}())

    KentuckyMedicaidExpansion(
        "Kentucky Medicaid Expansion (2014)",
        year, new_enrollees, affected_hospitals, baseline_margin,
        actual_margin_changes, actual_closures, metadata
    )
end

function MarylandAllPayerModel(;
    year_start=2014,
    year_end=2018,
    affected_hospitals=60,
    global_budget_growth_limit=0.02,
    quality_incentive_pool_pct=0.02,
    actual_cost_growth=-0.05,
    actual_margin_changes=Dict{String, Float64}(),
    actual_quality_improvements=Dict{String, Float64}(),
    metadata=Dict{String, Any}())

    MarylandAllPayerModel(
        "Maryland All-Payer Model (2014-2018)",
        year_start, year_end, affected_hospitals,
        global_budget_growth_limit, quality_incentive_pool_pct,
        actual_cost_growth, actual_margin_changes,
        actual_quality_improvements, metadata
    )
end

function RuralHospitalClosureCase(;
    year_start=2010,
    year_end=2023,
    actual_closures=String[],
    closure_years=Dict{String, Int}(),
    pre_closure_margins=Dict{String, Float64}(),
    pre_closure_services=Dict{String, Vector{String}}(),
    region_data=Dict{String, Dict{String, Any}}(),
    metadata=Dict{String, Any}())

    RuralHospitalClosureCase(
        "Rural Hospital Closures (2010-2023)",
        year_start, year_end, actual_closures, closure_years,
        pre_closure_margins, pre_closure_services, region_data, metadata
    )
end

function COVID19ImpactCase(;
    year_start=2020,
    year_end=2021,
    volume_shock_percent=-0.25,
    inpatient_shock=-0.20,
    elective_shock=-0.60,
    icu_surge_capacity_cost=500000.0,
    supply_cost_increase=0.15,
    actual_margin_changes=Dict{String, Float64}(),
    actual_closures=String[],
    metadata=Dict{String, Any}())

    COVID19ImpactCase(
        "COVID-19 Impact (2020-2021)",
        year_start, year_end, volume_shock_percent, inpatient_shock,
        elective_shock, icu_surge_capacity_cost, supply_cost_increase,
        actual_margin_changes, actual_closures, metadata
    )
end

# ====================================
# Validation Functions
# ====================================

"""
    load_case_study(case_type::Type{<:CaseStudy})::CaseStudy

Load actual outcome data for a case study.
"""
function load_case_study(case_type::Type{<:CaseStudy})::CaseStudy
    # Placeholder implementation - in real use would load from data files
    if case_type == KentuckyMedicaidExpansion
        return KentuckyMedicaidExpansion()
    elseif case_type == MarylandAllPayerModel
        return MarylandAllPayerModel()
    elseif case_type == RuralHospitalClosureCase
        return RuralHospitalClosureCase()
    elseif case_type == COVID19ImpactCase
        return COVID19ImpactCase()
    else
        error("Unknown case study type: $case_type")
    end
end

"""
    calculate_metrics(actual::Vector{OutcomeRow}, simulated::Vector{OutcomeRow})::ValidationMetrics

Calculate validation metrics comparing simulated vs. actual outcomes.
"""
function calculate_metrics(actual::Vector{OutcomeRow}, simulated::Vector{OutcomeRow})::ValidationMetrics

    # Ensure matching dimensions
    if length(actual) != length(simulated)
        error("Actual and simulated outcome vectors must have the same length")
    end

    n = length(actual)

    # Calculate MAPE (Mean Absolute Percentage Error)
    errors = Float64[]
    directions_correct = 0
    total_directions = 0

    for i in 1:n
        if actual[i].outcome_value != 0.0
            err = abs(simulated[i].outcome_value - actual[i].outcome_value) /
                  abs(actual[i].outcome_value)
            push!(errors, err)
        end

        # Check directional accuracy: compare sign of simulated vs actual
        simulated_sign = sign(simulated[i].outcome_value)
        actual_sign    = sign(actual[i].outcome_value)

        if simulated_sign == actual_sign
            directions_correct += 1
        end
        total_directions += 1
    end

    mape = isempty(errors) ? 0.0 : mean(errors) * 100.0
    directional_accuracy = total_directions > 0 ? directions_correct / total_directions : 0.0

    # Calculate RMSE
    actual_vals    = [r.outcome_value for r in actual]
    simulated_vals = [r.outcome_value for r in simulated]
    residuals = simulated_vals .- actual_vals
    rmse = sqrt(mean(residuals .^ 2))

    # Calculate correlation (guard against constant arrays)
    correlation = if n > 1 && std(actual_vals) > 0.0 && std(simulated_vals) > 0.0
        cor(actual_vals, simulated_vals)
    else
        1.0
    end

    # Maximum error
    max_error = maximum(abs.(residuals))

    return ValidationMetrics(
        mape, directional_accuracy, rmse, correlation, max_error,
        Dict{String, Any}("n_observations" => n)
    )
end

"""
    validate_simulation(case_study::CaseStudy,
                       simulated_outcomes::Dict)::ValidationResult

Validate a simulation against a case study.
"""
function validate_simulation(case_study::CaseStudy,
                             simulated_outcomes::Dict)::ValidationResult

    # Get actual margin changes based on case study type
    actual_margin_dict = if case_study isa KentuckyMedicaidExpansion
        case_study.actual_margin_changes
    elseif case_study isa MarylandAllPayerModel
        case_study.actual_margin_changes
    elseif case_study isa RuralHospitalClosureCase
        case_study.pre_closure_margins
    elseif case_study isa COVID19ImpactCase
        case_study.actual_margin_changes
    else
        Dict{String, Float64}()
    end

    # Build outcome vectors from case study
    actual_avg = length(actual_margin_dict) > 0 ? mean(values(actual_margin_dict)) : 0.0
    actual_data = [OutcomeRow("margin_change", actual_avg, actual_avg < 0 ? -1.0 : 1.0)]

    simulated_avg = get(simulated_outcomes, "avg_margin_change", 0.0)
    simulated_direction = get(simulated_outcomes, "margin_change_direction", 0.0)
    simulated_data = [OutcomeRow("margin_change", simulated_avg, simulated_direction)]

    # Calculate metrics
    metrics = calculate_metrics(actual_data, simulated_data)

    # Hospital-level results
    hospital_results = Dict{String, Dict{String, Float64}}()
    for (hospital_id, actual_margin) in actual_margin_dict
        simulated_margin = get(simulated_outcomes, "hospital_$hospital_id", 0.0)
        hospital_results[hospital_id] = Dict(
            "actual"    => actual_margin,
            "simulated" => simulated_margin,
            "error"     => abs(simulated_margin - actual_margin)
        )
    end

    # Summary text
    summary = "Validation against $(case_study.name): MAPE=$(round(metrics.mape, digits=2))%, Accuracy=$(round(metrics.directional_accuracy*100, digits=1))%"

    return ValidationResult(
        case_study.name,
        "Simulation",
        metrics,
        actual_data,
        simulated_data,
        hospital_results,
        summary,
        now()
    )
end

"""
    compare_outcomes(actual::Dict, simulated::Dict)::Vector{ComparisonRow}

Compare actual vs. simulated outcomes at hospital level.
Returns a vector of ComparisonRow sorted by hospital_id.
"""
function compare_outcomes(actual::Dict, simulated::Dict)::Vector{ComparisonRow}

    hospitals = sort(collect(union(keys(actual), keys(simulated))))

    results = ComparisonRow[]
    for hospital_id in hospitals
        actual_val    = get(actual,    hospital_id, 0.0)
        simulated_val = get(simulated, hospital_id, 0.0)
        err     = simulated_val - actual_val
        err_pct = actual_val != 0.0 ? (err / actual_val) * 100.0 : 0.0
        push!(results, ComparisonRow(hospital_id, actual_val, simulated_val, err, err_pct))
    end

    return results
end

"""
    generate_validation_report(result::ValidationResult)::String

Generate a validation report from results.
"""
function generate_validation_report(result::ValidationResult)::String

    report = """
    VALIDATION REPORT
    ==================

    Case Study: $(result.case_study_name)
    Simulation: $(result.simulation_name)
    Timestamp: $(result.timestamp)

    VALIDATION METRICS
    ==================
    Mean Absolute Percentage Error (MAPE): $(round(result.metrics.mape, digits=2))%
    Directional Accuracy: $(round(result.metrics.directional_accuracy*100, digits=1))%
    Root Mean Squared Error: $(round(result.metrics.rmse, digits=4))
    Correlation: $(round(result.metrics.correlation, digits=4))
    Maximum Error: $(round(result.metrics.max_error, digits=4))

    SUMMARY
    =======
    $(result.summary)

    HOSPITAL-LEVEL RESULTS
    ======================
    $(length(result.hospital_level_results) > 0 ? "Hospitals analyzed: $(length(result.hospital_level_results))" : "No hospital-level data")
    """

    return report
end

end  # module
