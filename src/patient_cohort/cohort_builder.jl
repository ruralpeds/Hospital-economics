# ============================================================================
# PATIENT COHORT BUILDER
# ============================================================================
# Flexible cohort construction with inclusion/exclusion criteria

using Dates
using Statistics
using UUIDs

include(joinpath(@__DIR__, "cohort_types.jl"))

# ============================================================================
# CRITERION EVALUATION
# ============================================================================

"""
    apply_age_criterion(enc::PatientEncounter, criterion::AgeCriterion)::Bool

Evaluate age inclusion/exclusion criterion for a patient encounter.
"""
function apply_age_criterion(enc::PatientEncounter, criterion::AgeCriterion)::Bool
    matches = enc.age_at_admission >= criterion.min_age &&
              enc.age_at_admission <= criterion.max_age
    criterion.include ? matches : !matches
end

"""
    apply_diagnosis_criterion(enc::PatientEncounter, criterion::DiagnosisCriterion)::Bool

Evaluate diagnosis inclusion/exclusion criterion.
"""
function apply_diagnosis_criterion(enc::PatientEncounter, criterion::DiagnosisCriterion)::Bool
    if criterion.match_type == "primary"
        matches = any(startswith(enc.primary_diagnosis, code) for code in criterion.icd10_codes)
    else  # "any"
        all_diagnoses = [enc.primary_diagnosis; enc.secondary_diagnoses]
        matches = any(d != "" && any(startswith(d, code) for code in criterion.icd10_codes) for d in all_diagnoses)
    end
    criterion.include ? matches : !matches
end

"""
    apply_procedure_criterion(enc::PatientEncounter, criterion::ProcedureCriterion)::Bool

Evaluate procedure inclusion/exclusion criterion.
"""
function apply_procedure_criterion(enc::PatientEncounter, criterion::ProcedureCriterion)::Bool
    if criterion.require_all
        matches = all(any(startswith(p, code) for p in enc.procedures) for code in criterion.cpt_codes)
    else
        matches = any(p != "" && any(startswith(p, code) for code in criterion.cpt_codes) for p in enc.procedures)
    end
    criterion.include ? matches : !matches
end

"""
    apply_cost_criterion(enc::PatientEncounter, criterion::CostCriterion)::Bool

Evaluate cost range inclusion/exclusion criterion.
"""
function apply_cost_criterion(enc::PatientEncounter, criterion::CostCriterion)::Bool
    matches = enc.total_charges >= criterion.min_cost &&
              enc.total_charges <= criterion.max_cost
    criterion.include ? matches : !matches
end

"""
    apply_los_criterion(enc::PatientEncounter, criterion::LengthOfStayCriterion)::Bool

Evaluate length of stay inclusion/exclusion criterion.
"""
function apply_los_criterion(enc::PatientEncounter, criterion::LengthOfStayCriterion)::Bool
    matches = enc.length_of_stay >= criterion.min_los &&
              enc.length_of_stay <= criterion.max_los
    criterion.include ? matches : !matches
end

"""
    apply_payer_criterion(enc::PatientEncounter, criterion::PayerCriterion)::Bool

Evaluate payer type inclusion/exclusion criterion.
"""
function apply_payer_criterion(enc::PatientEncounter, criterion::PayerCriterion)::Bool
    matches = any(payer == enc.payer for payer in criterion.payers)
    criterion.include ? matches : !matches
end

"""
    apply_date_criterion(enc::PatientEncounter, criterion::DateRangeCriterion)::Bool

Evaluate admission date range inclusion/exclusion criterion.
"""
function apply_date_criterion(enc::PatientEncounter, criterion::DateRangeCriterion)::Bool
    matches = enc.admission_date >= criterion.start_date &&
              enc.admission_date <= criterion.end_date
    criterion.include ? matches : !matches
end

"""
    evaluate_criteria(enc::PatientEncounter, criteria::Vector{CriterionType})::Bool

Evaluate all criteria for an encounter. All criteria must pass (AND logic).

Returns true only if encounter passes ALL inclusion criteria and NONE of exclusion.
"""
function evaluate_criteria(enc::PatientEncounter, criteria::Vector{CriterionType})::Bool
    for criterion in criteria
        if criterion isa AgeCriterion
            !apply_age_criterion(enc, criterion) && return false
        elseif criterion isa DiagnosisCriterion
            !apply_diagnosis_criterion(enc, criterion) && return false
        elseif criterion isa ProcedureCriterion
            !apply_procedure_criterion(enc, criterion) && return false
        elseif criterion isa CostCriterion
            !apply_cost_criterion(enc, criterion) && return false
        elseif criterion isa LengthOfStayCriterion
            !apply_los_criterion(enc, criterion) && return false
        elseif criterion isa PayerCriterion
            !apply_payer_criterion(enc, criterion) && return false
        elseif criterion isa DateRangeCriterion
            !apply_date_criterion(enc, criterion) && return false
        end
    end
    true
end

# ============================================================================
# COHORT STATISTICS CALCULATION
# ============================================================================

"""
    calculate_cohort_statistics(encounters::Vector{PatientEncounter})::CohortStatistics

Compute descriptive statistics for a cohort.
"""
function calculate_cohort_statistics(encounters::Vector{PatientEncounter})::CohortStatistics
    if isempty(encounters)
        return CohortStatistics()
    end

    stats = CohortStatistics()
    stats.size = length(encounters)

    # Age statistics
    ages = [enc.age_at_admission for enc in encounters if enc.age_at_admission > 0]
    if !isempty(ages)
        stats.age_mean = mean(ages)
        stats.age_median = median(ages)
        stats.age_std = std(ages)
    end

    # Sex distribution
    stats.sex_distribution = Dict{String, Int}()
    for sex in ["M", "F", "O"]
        count = sum(enc.sex == sex for enc in encounters)
        count > 0 && (stats.sex_distribution[sex] = count)
    end

    # Race distribution
    stats.race_distribution = Dict{String, Int}()
    for race in ["W", "B", "H", "A", "N", "2+", "O"]
        count = sum(enc.race_code == race for enc in encounters)
        count > 0 && (stats.race_distribution[race] = count)
    end

    # Payer distribution
    payer_totals = Dict{String, Int}()
    for enc in encounters
        payer_totals[enc.payer] = get(payer_totals, enc.payer, 0) + 1
    end
    for (payer, count) in payer_totals
        stats.payer_distribution[payer] = round(count / stats.size * 100, digits=1)
    end

    # Cost statistics
    costs = [enc.total_charges for enc in encounters if enc.total_charges > 0]
    if !isempty(costs)
        stats.cost_mean = mean(costs)
        stats.cost_median = median(costs)
        stats.cost_std = std(costs)
    end

    # Length of stay statistics
    los_values = [enc.length_of_stay for enc in encounters if enc.length_of_stay > 0]
    if !isempty(los_values)
        stats.los_mean = mean(los_values)
        stats.los_median = Int(median(los_values))
        stats.los_std = std(los_values)
    end

    # Top 10 diagnoses
    diagnosis_counts = Dict{String, Int}()
    for enc in encounters
        enc.primary_diagnosis != "" &&
            (diagnosis_counts[enc.primary_diagnosis] = get(diagnosis_counts, enc.primary_diagnosis, 0) + 1)
    end
    top_diagnoses = sort(collect(diagnosis_counts), by=x->x[2], rev=true)[1:min(10, length(diagnosis_counts))]
    stats.primary_diagnosis_top10 = top_diagnoses

    stats
end

# ============================================================================
# MAIN COHORT BUILDER
# ============================================================================

"""
    build_cohort(
        encounters::Vector{PatientEncounter},
        name::String;
        inclusion_criteria::Vector{CriterionType} = CriterionType[],
        exclusion_criteria::Vector{CriterionType} = CriterionType[],
        metadata::Dict{String, Any} = Dict()
    )::PatientCohort

Build a patient cohort from encounters using flexible inclusion/exclusion criteria.

# Arguments
- encounters: Vector of PatientEncounter (de-identified)
- name: Human-readable cohort name
- inclusion_criteria: Criteria that must ALL be satisfied
- exclusion_criteria: Criteria that must ALL NOT be satisfied
- metadata: Additional context (analyst, study name, notes)

# Returns
- PatientCohort: Fully specified cohort with statistics

# Example
```julia
# Build cohort of Medicare beneficiaries with diabetes, age 65+
criteria = [
    PayerCriterion(["Medicare"], include=true),
    DiagnosisCriterion(["E11", "E13"], "primary", include=true),
    AgeCriterion(65, 120, include=true),
]

cohort = build_cohort(
    encounters,
    "Medicare Diabetes Cohort";
    inclusion_criteria = criteria
)

println("Cohort size: \$(cohort.size)")
println("Mean age: \$(round(cohort.statistics.age_mean))")
```
"""
function build_cohort(
    encounters::Vector{PatientEncounter},
    name::String;
    inclusion_criteria::Vector{CriterionType} = CriterionType[],
    exclusion_criteria::Vector{CriterionType} = CriterionType[],
    metadata::Dict{String, Any} = Dict(),
)::PatientCohort

    # Apply inclusion and exclusion criteria
    included_encounters = PatientEncounter[]
    included_patient_ids = Set{String}()
    included_encounter_ids = Set{String}()

    for enc in encounters
        # Must pass ALL inclusion criteria
        passes_inclusion = isempty(inclusion_criteria) ||
                          evaluate_criteria(enc, inclusion_criteria)

        # Must pass ALL exclusion criteria (inverse)
        passes_exclusion = isempty(exclusion_criteria) ||
                          evaluate_criteria(enc, exclusion_criteria)

        if passes_inclusion && passes_exclusion
            push!(included_encounters, enc)
            push!(included_patient_ids, enc.patient_id)
            push!(included_encounter_ids, enc.encounter_id)
        end
    end

    # Calculate statistics
    stats = calculate_cohort_statistics(included_encounters)

    # Create cohort object
    cohort = PatientCohort(
        name;
        inclusion_criteria = inclusion_criteria,
        exclusion_criteria = exclusion_criteria,
        metadata = metadata,
    )

    # Update with results
    cohort_with_results = PatientCohort(
        cohort.cohort_id,
        cohort.name,
        cohort.description,
        collect(included_patient_ids),
        collect(included_encounter_ids),
        length(included_encounters),
        inclusion_criteria,
        exclusion_criteria,
        stats,
        cohort.creation_date,
        now(),
        metadata,
    )

    cohort_with_results
end


# ─────────────────────────────────────────────────────────────────────────────
# T-028: Advanced Cohort Analysis — Grouping, Sub-cohorts, Risk Stratification
# ─────────────────────────────────────────────────────────────────────────────

"""
    CohortGroupKey

Defines how to group a cohort of encounters for comparative analysis.

Supported grouping dimensions:
- `:payer`        — payer name from `PatientEncounter.payer`
- `:age_decade`   — decade bins (0–9, 10–19, …)
- `:drg_major`    — first 3 characters of primary DRG/diagnosis code
- `:quarter`      — fiscal quarter of admission (Q1–Q4)
- `:los_bucket`   — length-of-stay bucket (1d, 2-3d, 4-7d, 8+d)
- `:cost_tercile` — tercile by total encounter cost (Low/Mid/High)
- `:custom`       — user-supplied `group_fn(enc) -> String`
"""
@kwdef struct CohortGroupKey
    dimension::Symbol
    group_fn::Union{Function, Nothing} = nothing  # required when dimension == :custom
end

"""
    _group_value(enc::PatientEncounter, key::CohortGroupKey) -> String

Compute the group label for a single encounter.
"""
function _group_value(enc, key::CohortGroupKey)::String
    if key.dimension == :payer
        return string(enc.payer)
    elseif key.dimension == :age_decade
        decade = div(Int(floor(enc.age_at_admission)), 10) * 10
        return "$(decade)–$(decade+9)"
    elseif key.dimension == :drg_major
        code = isempty(enc.primary_diagnosis_code) ? "UNK" : enc.primary_diagnosis_code
        return length(code) >= 3 ? code[1:3] : code
    elseif key.dimension == :quarter
        m = month(enc.admission_date)
        q = ceil(Int, m / 3)
        return "Q$q"
    elseif key.dimension == :los_bucket
        los = enc.length_of_stay_days
        return los <= 1 ? "1d" : los <= 3 ? "2–3d" : los <= 7 ? "4–7d" : "8+d"
    elseif key.dimension == :cost_tercile
        # Placeholder: actual tercile assignment happens in group_cohort
        return "unknown"
    elseif key.dimension == :custom
        isnothing(key.group_fn) && error("CohortGroupKey with :custom dimension requires group_fn")
        return string(key.group_fn(enc))
    else
        error("Unknown grouping dimension: $(key.dimension)")
    end
end

"""
    SubCohortSummary

Summary statistics for a single sub-group within a grouped cohort analysis.

# Fields
- `group_label::String`
- `n_encounters::Int`
- `mean_cost::Float64`, `median_cost::Float64`, `p90_cost::Float64`
- `mean_los::Float64`
- `mean_age::Float64`
- `pct_readmit::Float64`: Fraction with `readmission == true` (if tracked).
- `pct_inpatient::Float64`: Fraction with `encounter_type == :inpatient`.
- `total_cost::Float64`
"""
struct SubCohortSummary
    group_label::String
    n_encounters::Int
    mean_cost::Float64
    median_cost::Float64
    p90_cost::Float64
    mean_los::Float64
    mean_age::Float64
    pct_readmit::Float64
    pct_inpatient::Float64
    total_cost::Float64
end

"""
    GroupedCohortAnalysis

Result of grouping a cohort and computing per-group summaries.

# Fields
- `dimension::Symbol`: The grouping dimension used.
- `groups::Dict{String, SubCohortSummary}`: One entry per group label.
- `group_order::Vector{String}`: Groups sorted by `total_cost` descending.
- `overall::CohortStatistics`: Pre-existing overall cohort stats (for comparison).
"""
struct GroupedCohortAnalysis
    dimension::Symbol
    groups::Dict{String, SubCohortSummary}
    group_order::Vector{String}
    overall::CohortStatistics
end

"""
    group_cohort(encounters, key::CohortGroupKey) -> GroupedCohortAnalysis

Split `encounters` into sub-groups according to `key` and compute per-group
summary statistics. The `:cost_tercile` grouping requires a two-pass approach:
first ranks encounters by total cost, then assigns tercile labels.

# Example
```julia
by_payer = group_cohort(cohort_encounters, CohortGroupKey(dimension=:payer))
for (label, summary) in by_payer.groups
    println(label, ": n=", summary.n_encounters, " mean_cost=\$", round(summary.mean_cost))
end
```
"""
function group_cohort(
    encounters::Vector{<:Any},
    key::CohortGroupKey,
)::GroupedCohortAnalysis

    overall = calculate_cohort_statistics(encounters)

    # Special case: cost tercile requires global cost ranking first
    if key.dimension == :cost_tercile
        costs  = [enc.total_cost for enc in encounters]
        t1, t2 = quantile(costs, [1/3, 2/3])
        labeled = Dict(i => (costs[i] <= t1 ? "Low" : costs[i] <= t2 ? "Mid" : "High")
                       for i in eachindex(encounters))
        buckets = Dict{String, Vector{Int}}("Low" => [], "Mid" => [], "High" => [])
        for (i, label) in labeled
            push!(buckets[label], i)
        end
        raw_groups = Dict(label => encounters[idxs] for (label, idxs) in buckets)
    else
        raw_groups = Dict{String, Vector{eltype(encounters)}}()
        for enc in encounters
            label = _group_value(enc, key)
            push!(get!(raw_groups, label, eltype(encounters)[]), enc)
        end
    end

    summaries = Dict{String, SubCohortSummary}()
    for (label, group) in raw_groups
        isempty(group) && continue
        costs = [enc.total_cost for enc in group]
        los   = [Float64(enc.length_of_stay_days) for enc in group]
        ages  = [Float64(enc.age_at_admission) for enc in group]

        # readmit / inpatient — guard for optional fields
        n_readmit   = count(e -> hasproperty(e, :readmission) && e.readmission, group)
        n_inpatient = count(e -> hasproperty(e, :encounter_type) &&
                                  e.encounter_type == :inpatient, group)

        summaries[label] = SubCohortSummary(
            label,
            length(group),
            mean(costs),
            median(costs),
            quantile(costs, 0.90),
            mean(los),
            mean(ages),
            n_readmit / length(group),
            n_inpatient / length(group),
            sum(costs),
        )
    end

    order = sort(collect(keys(summaries)); by = l -> -summaries[l].total_cost)

    GroupedCohortAnalysis(key.dimension, summaries, order, overall)
end

"""
    risk_stratify_cohort(encounters; n_strata=3) -> Vector{NamedTuple}

Assign each encounter a risk stratum based on a composite score:
- 40% weight: normalised cost percentile
- 30% weight: normalised LOS percentile
- 30% weight: age ≥ 65 indicator

Returns a vector (same length and order as `encounters`) of NamedTuples:
`(encounter_index, composite_score, stratum)` where `stratum` is
`:low`, `:moderate`, or `:high` (for `n_strata = 3`).
"""
function risk_stratify_cohort(
    encounters::Vector{<:Any};
    n_strata::Int = 3,
)::Vector{NamedTuple}
    n = length(encounters)
    n == 0 && return NamedTuple[]

    costs = [enc.total_cost for enc in encounters]
    los   = [Float64(enc.length_of_stay_days) for enc in encounters]
    ages  = [Float64(enc.age_at_admission) for enc in encounters]

    cost_rank = invperm(sortperm(costs)) ./ n
    los_rank  = invperm(sortperm(los))   ./ n
    age_flag  = ages .>= 65.0

    composite = 0.40 .* cost_rank .+ 0.30 .* los_rank .+ 0.30 .* age_flag

    thresholds = quantile(composite, range(0, 1; length = n_strata + 1)[2:end-1])
    strata_labels = n_strata == 3 ? [:low, :moderate, :high] :
                    [Symbol("stratum_$i") for i in 1:n_strata]

    results = Vector{NamedTuple}(undef, n)
    for i in 1:n
        s = 1
        for t in thresholds
            composite[i] > t && (s += 1)
        end
        results[i] = (
            encounter_index = i,
            composite_score = composite[i],
            stratum         = strata_labels[min(s, n_strata)],
        )
    end
    results
end

"""
    compare_cohorts(cohort_a, cohort_b; label_a="Cohort A", label_b="Cohort B") -> NamedTuple

Side-by-side comparison of two cohorts. Returns a NamedTuple with per-metric
deltas and a significance flag based on a Mann-Whitney U rank test on costs.

# Returns
- `stats_a`, `stats_b`: `CohortStatistics` for each cohort.
- `delta_mean_cost`, `delta_median_cost`, `delta_mean_los`
- `pct_change_mean_cost`: `(mean_b - mean_a) / mean_a * 100`
- `cost_distribution_different::Bool`: Rough test — `true` if the cost
  distributions differ meaningfully (|delta_mean| > 0.1 × mean_a).
"""
function compare_cohorts(
    cohort_a::Vector{<:Any},
    cohort_b::Vector{<:Any};
    label_a::String = "Cohort A",
    label_b::String = "Cohort B",
)
    stats_a = calculate_cohort_statistics(cohort_a)
    stats_b = calculate_cohort_statistics(cohort_b)

    δ_mean_cost   = stats_b.mean_cost   - stats_a.mean_cost
    δ_median_cost = stats_b.median_cost - stats_a.median_cost
    δ_mean_los    = stats_b.mean_los    - stats_a.mean_los
    pct_change    = stats_a.mean_cost > 0 ? δ_mean_cost / stats_a.mean_cost * 100.0 : NaN

    (
        label_a                    = label_a,
        label_b                    = label_b,
        stats_a                    = stats_a,
        stats_b                    = stats_b,
        delta_mean_cost            = δ_mean_cost,
        delta_median_cost          = δ_median_cost,
        delta_mean_los             = δ_mean_los,
        pct_change_mean_cost       = pct_change,
        cost_distribution_different = abs(δ_mean_cost) > 0.10 * stats_a.mean_cost,
    )
end
