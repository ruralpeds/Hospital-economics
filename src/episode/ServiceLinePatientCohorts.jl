# episode/ServiceLinePatientCohorts.jl
# Service line cohort analysis with patient segmentation and profitability

using Dates
using Statistics

"""
    PatientCohort

Represents a cohort of patients within a service line, segmented by demographics and severity.

# Fields
- `service_line_id::String` — Service line identifier
- `cohort_name::String` — Human-readable cohort name
- `age_range::Tuple{Int, Int}` — Age range (min, max) in years
- `severity_quintile::Int` — Severity level 1-5 (1=lowest, 5=highest)
- `comorbidity_count::Int` — Number of secondary diagnoses
- `patient_count::Int` — Number of patients in cohort
- `avg_los::Float64` — Average length of stay
- `avg_revenue_per_patient::Float64` — Mean revenue per patient
- `avg_cost_per_patient::Float64` — Mean cost per patient
- `contribution_margin::Float64` — Revenue - Cost per patient
- `margin_pct::Float64` — Contribution margin as % of revenue
- `readmission_rate::Float64` — 30-day readmission rate (0-1)
- `mortality_rate::Float64` — In-hospital mortality rate (0-1)
- `complication_rate::Float64` — Rate of complications (0-1)
- `qaly_per_patient::Float64` — Quality-adjusted life years per patient
- `margin_per_qaly::Float64` — Financial margin per QALY gained
"""
struct PatientCohort
    service_line_id::String
    cohort_name::String
    age_range::Tuple{Int, Int}
    severity_quintile::Int
    comorbidity_count::Int
    patient_count::Int
    avg_los::Float64
    avg_revenue_per_patient::Float64
    avg_cost_per_patient::Float64
    contribution_margin::Float64
    margin_pct::Float64
    readmission_rate::Float64
    mortality_rate::Float64
    complication_rate::Float64
    qaly_per_patient::Float64
    margin_per_qaly::Float64
end

"""
    ServiceLineAnalysis

Complete profitability and quality analysis for a service line across cohorts.

# Fields
- `service_line_name::String` — Service line identifier
- `total_patients::Int` — Total patients served
- `total_cost::Float64` — Total costs
- `total_revenue::Float64` — Total revenue
- `total_margin::Float64` — Total contribution margin
- `total_qalys::Float64` — Total QALYs generated
- `cohorts::Vector{PatientCohort}` — All patient cohorts
- `profitability_ranking::Vector{String}` — Cohorts ranked by margin
- `quality_ranking::Vector{String}` — Cohorts ranked by quality (mortality + readmission)
- `value_ranking::Vector{String}` — Cohorts ranked by margin per QALY
"""
struct ServiceLineAnalysis
    service_line_name::String
    total_patients::Int
    total_cost::Float64
    total_revenue::Float64
    total_margin::Float64
    total_qalys::Float64
    cohorts::Vector{PatientCohort}
    profitability_ranking::Vector{String}
    quality_ranking::Vector{String}
    value_ranking::Vector{String}
end

"""
    segment_patients_by_age(patients::Vector{PatientAgent})::Dict{String, Vector{PatientAgent}}

Segment patients into age groups: <25, 25-40, 40-55, 55-65, 65-75, 75+
"""
function segment_patients_by_age(patients::Vector{PatientAgent})::Dict{String, Vector{PatientAgent}}
    segments = Dict(
        "0-24" => PatientAgent[],
        "25-40" => PatientAgent[],
        "41-55" => PatientAgent[],
        "56-65" => PatientAgent[],
        "66-75" => PatientAgent[],
        "75+" => PatientAgent[]
    )

    for patient in patients
        # Estimate age from admission date (using year difference)
        admission_year = year(patient.admission_date)
        age = 2026 - admission_year  # Rough estimate

        if age < 25
            push!(segments["0-24"], patient)
        elseif age < 41
            push!(segments["25-40"], patient)
        elseif age < 56
            push!(segments["41-55"], patient)
        elseif age < 66
            push!(segments["56-65"], patient)
        elseif age < 76
            push!(segments["66-75"], patient)
        else
            push!(segments["75+"], patient)
        end
    end

    return segments
end

"""
    segment_patients_by_severity(patients::Vector{PatientAgent})::Dict{String, Vector{PatientAgent}}

Segment patients into severity quintiles based on comorbidity count.
"""
function segment_patients_by_severity(patients::Vector{PatientAgent})::Dict{String, Vector{PatientAgent}}
    segments = Dict(
        "Q1 (Lowest)" => PatientAgent[],
        "Q2" => PatientAgent[],
        "Q3 (Medium)" => PatientAgent[],
        "Q4" => PatientAgent[],
        "Q5 (Highest)" => PatientAgent[]
    )

    # Sort by comorbidity count
    sorted = sort(patients; by=p -> p.comorbidity_count)
    n = length(sorted)

    # Divide into quintiles
    q_size = div(n, 5)
    for i in 1:5
        start_idx = (i - 1) * q_size + 1
        if i == 5
            end_idx = n
        else
            end_idx = i * q_size
        end

        q_label = ["Q1 (Lowest)", "Q2", "Q3 (Medium)", "Q4", "Q5 (Highest)"][i]
        segments[q_label] = sorted[start_idx:end_idx]
    end

    return segments
end

"""
    calculate_cohort_profitability(
        cohort_patients::Vector{PatientAgent},
        service_line_id::String,
        cohort_name::String,
        age_range::Tuple{Int, Int},
        severity_quintile::Int
    )::PatientCohort

Calculate profitability metrics for a patient cohort.
"""
function calculate_cohort_profitability(
    cohort_patients::Vector{PatientAgent},
    service_line_id::String,
    cohort_name::String,
    age_range::Tuple{Int, Int},
    severity_quintile::Int
)::PatientCohort
    n_patients = length(cohort_patients)

    if n_patients == 0
        return PatientCohort(
            service_line_id, cohort_name, age_range, severity_quintile, 0,
            0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
        )
    end

    # Calculate cost metrics
    total_cost = sum(p.cumulative_cost for p in cohort_patients)
    avg_cost = total_cost / n_patients

    # Assume 1.3x cost multiplier for revenue
    avg_revenue = avg_cost * 1.3
    total_revenue = avg_revenue * n_patients
    contribution_margin = avg_revenue - avg_cost
    margin_pct = contribution_margin / avg_revenue

    # Length of stay
    discharged = [p for p in cohort_patients if p.location == "discharged"]
    if !isempty(discharged)
        avg_los = mean([Dates.value(p.discharge_date - p.admission_date) for p in discharged])
    else
        avg_los = mean([p.los_target for p in cohort_patients])
    end

    # Quality metrics (simulated)
    avg_comorbidities = mean(p.comorbidity_count for p in cohort_patients)
    readmission_rate = 0.05 + 0.02 * (avg_comorbidities / 2)  # Increases with comorbidities
    mortality_rate = 0.01 + 0.01 * (avg_comorbidities / 2)
    complication_rate = 0.10 + 0.05 * (avg_comorbidities / 2)

    # QALYs (simulated: baseline 0.8, reduced by complications/mortality)
    qaly_base = 0.8
    qaly_adjusted = qaly_base * (1 - mortality_rate) * (1 - complication_rate * 0.1)
    total_qalys = qaly_adjusted * n_patients

    # Financial value per QALY
    margin_per_qaly = total_revenue > 0 ? contribution_margin / max(qaly_adjusted, 0.01) : 0.0

    return PatientCohort(
        service_line_id, cohort_name, age_range, severity_quintile,
        Int(round(avg_comorbidities)),
        n_patients, avg_los, avg_revenue, avg_cost, contribution_margin, margin_pct * 100,
        readmission_rate, mortality_rate, complication_rate,
        qaly_adjusted, margin_per_qaly
    )
end

"""
    analyze_service_line_by_cohort(
        service_line_id::String,
        patients::Vector{PatientAgent}
    )::ServiceLineAnalysis

Perform comprehensive cohort-based analysis of a service line.
"""
function analyze_service_line_by_cohort(
    service_line_id::String,
    patients::Vector{PatientAgent}
)::ServiceLineAnalysis
    # Filter to service line patients
    service_patients = [p for p in patients if p.assigned_service_line == service_line_id]

    if isempty(service_patients)
        return ServiceLineAnalysis(
            service_line_id, 0, 0.0, 0.0, 0.0, 0.0,
            PatientCohort[], String[], String[], String[]
        )
    end

    # Segment by age
    age_segments = segment_patients_by_age(service_patients)
    age_cohorts = PatientCohort[]

    age_ranges = [
        ("0-24", (0, 24)),
        ("25-40", (25, 40)),
        ("41-55", (41, 55)),
        ("56-65", (56, 65)),
        ("66-75", (66, 75)),
        ("75+", (75, 120))
    ]

    for (label, range) in age_ranges
        cohort = calculate_cohort_profitability(
            age_segments[label], service_line_id, "Age $label", range, 3
        )
        push!(age_cohorts, cohort)
    end

    # Segment by severity
    severity_segments = segment_patients_by_severity(service_patients)
    severity_cohorts = PatientCohort[]

    severity_labels = [
        ("Q1 (Lowest)", 1),
        ("Q2", 2),
        ("Q3 (Medium)", 3),
        ("Q4", 4),
        ("Q5 (Highest)", 5)
    ]

    for (label, quintile) in severity_labels
        cohort = calculate_cohort_profitability(
            severity_segments[label], service_line_id, "Severity $label", (0, 120), quintile
        )
        push!(severity_cohorts, cohort)
    end

    # Combine all cohorts
    all_cohorts = vcat(age_cohorts, severity_cohorts)

    # Calculate service line totals
    total_cost = sum(p.avg_cost_per_patient * p.patient_count for p in all_cohorts)
    total_revenue = sum(p.avg_revenue_per_patient * p.patient_count for p in all_cohorts)
    total_margin = total_revenue - total_cost
    total_qalys = sum(p.qaly_per_patient * p.patient_count for p in all_cohorts)
    total_patients = length(service_patients)

    # Rankings
    profitability_ranking = [c.cohort_name for c in sort(all_cohorts, by=c -> c.contribution_margin, rev=true)]
    quality_ranking = [c.cohort_name for c in sort(all_cohorts, by=c -> c.readmission_rate + c.mortality_rate)]
    value_ranking = [c.cohort_name for c in sort(all_cohorts, by=c -> c.margin_per_qaly, rev=true)]

    return ServiceLineAnalysis(
        service_line_id, total_patients, total_cost, total_revenue, total_margin, total_qalys,
        all_cohorts, profitability_ranking, quality_ranking, value_ranking
    )
end

"""
    get_high_value_cohorts(analysis::ServiceLineAnalysis)::Vector{PatientCohort}

Identify cohorts with both high profitability AND high quality (high margin per QALY).
"""
function get_high_value_cohorts(analysis::ServiceLineAnalysis)::Vector{PatientCohort}
    if isempty(analysis.cohorts)
        return PatientCohort[]
    end

    # Rank by margin per QALY
    sorted = sort(analysis.cohorts, by=c -> c.margin_per_qaly, rev=true)

    # Return top 30% as "high value"
    n_high_value = max(1, div(length(sorted), 3))
    return sorted[1:n_high_value]
end

"""
    get_low_margin_cohorts(analysis::ServiceLineAnalysis)::Vector{PatientCohort}

Identify cohorts with negative or low contribution margins (unprofitable segments).
"""
function get_low_margin_cohorts(analysis::ServiceLineAnalysis)::Vector{PatientCohort}
    unprofitable = [c for c in analysis.cohorts if c.contribution_margin < 0]
    low_margin = [c for c in analysis.cohorts if c.contribution_margin >= 0 && c.margin_pct < 10]
    return vcat(unprofitable, low_margin)
end

"""
    get_quality_leaders(analysis::ServiceLineAnalysis)::Vector{PatientCohort}

Identify cohorts with best quality outcomes (lowest readmission + mortality).
"""
function get_quality_leaders(analysis::ServiceLineAnalysis)::Vector{PatientCohort}
    if isempty(analysis.cohorts)
        return PatientCohort[]
    end

    sorted = sort(analysis.cohorts; by=c -> c.readmission_rate + c.mortality_rate)
    n_quality = max(1, div(length(sorted), 3))
    return sorted[1:n_quality]
end

"""
    compare_cohort_to_service_line_avg(cohort::PatientCohort, analysis::ServiceLineAnalysis)::Dict{String, Float64}

Compare a cohort's performance to service line averages.
"""
function compare_cohort_to_service_line_avg(
    cohort::PatientCohort,
    analysis::ServiceLineAnalysis
)::Dict{String, Float64}
    avg_cost = analysis.total_cost / max(1, analysis.total_patients)
    avg_revenue = analysis.total_revenue / max(1, analysis.total_patients)
    avg_margin = analysis.total_margin / max(1, analysis.total_patients)

    return Dict(
        "cost_variance" => (cohort.avg_cost_per_patient - avg_cost) / avg_cost,
        "revenue_variance" => (cohort.avg_revenue_per_patient - avg_revenue) / avg_revenue,
        "margin_variance" => (cohort.contribution_margin - avg_margin) / max(avg_margin, 1.0),
        "readmission_vs_avg" => cohort.readmission_rate / 0.08,  # Benchmark: 8% average
        "mortality_vs_avg" => cohort.mortality_rate / 0.02,  # Benchmark: 2% average
        "volume_pct" => cohort.patient_count / analysis.total_patients * 100
    )
end

"""
    service_line_cohort_summary(analysis::ServiceLineAnalysis)::Dict{String, Any}

Generate summary statistics and insights from cohort analysis.
"""
function service_line_cohort_summary(analysis::ServiceLineAnalysis)::Dict{String, Any}
    if isempty(analysis.cohorts)
        return Dict{String, Any}()
    end

    high_value = get_high_value_cohorts(analysis)
    low_margin = get_low_margin_cohorts(analysis)
    quality_leaders = get_quality_leaders(analysis)

    # Overall margins
    overall_margin_pct = analysis.total_revenue > 0 ? (analysis.total_margin / analysis.total_revenue * 100) : 0.0

    return Dict(
        "service_line" => analysis.service_line_name,
        "total_patients" => analysis.total_patients,
        "total_margin" => analysis.total_margin,
        "margin_percentage" => overall_margin_pct,
        "total_qalys" => analysis.total_qalys,
        "qalys_per_patient" => analysis.total_qalys / max(1, analysis.total_patients),
        "high_value_cohorts" => [c.cohort_name for c in high_value],
        "unprofitable_cohorts" => [c.cohort_name for c in low_margin],
        "quality_leaders" => [c.cohort_name for c in quality_leaders],
        "num_cohorts" => length(analysis.cohorts),
        "profitability_ranking" => analysis.profitability_ranking,
        "quality_ranking" => analysis.quality_ranking,
        "value_ranking" => analysis.value_ranking
    )
end
