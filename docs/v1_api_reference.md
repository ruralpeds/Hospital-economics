# HospitalFinanceToolbox.jl v1.0 — API Reference

**Complete reference for all public functions, types, and constants.**  
Julia 1.10+ LTS | Module: `HospitalFinanceToolbox`

---

## Table of Contents

- [Data Ingestion & Validation](#data-ingestion--validation)
- [Patient Cohort Builder](#patient-cohort-builder)
- [Episode Costing](#episode-costing)
- [Health Economics](#health-economics)
- [Patient Flow Simulation](#patient-flow-simulation)
- [Value-Based Care & Payer Models](#value-based-care--payer-models)
- [Comparative Effectiveness Analysis](#comparative-effectiveness-analysis)
- [Multi-Level Policy Coupling](#multi-level-policy-coupling)
- [Policy Validation](#policy-validation)
- [Release Preparation](#release-preparation)

---

## Data Ingestion & Validation

### Types

---

#### `PatientEncounter`

```julia
@kwdef mutable struct PatientEncounter
    encounter_id        :: String
    patient_id          :: String
    facility_id         :: String
    admission_date      :: Date
    discharge_date      :: Date
    primary_diagnosis   :: String          # ICD-10-CM
    secondary_diagnoses :: Vector{String}  # ICD-10-CM list
    procedures          :: Vector{String}  # CPT / ICD-10-PCS
    drg_code            :: String
    payer               :: Symbol          # :Medicare, :Medicaid, :Commercial, :SelfPay
    total_charges       :: Float64
    allowed_amount      :: Float64
    los_days            :: Int
    discharge_status    :: String          # HL7 discharge disposition code
end
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `encounter_id` | `String` | Unique encounter identifier |
| `patient_id` | `String` | De-identified patient identifier |
| `facility_id` | `String` | CMS provider number or internal ID |
| `admission_date` | `Date` | Admission date |
| `discharge_date` | `Date` | Discharge date |
| `primary_diagnosis` | `String` | ICD-10-CM principal diagnosis code |
| `secondary_diagnoses` | `Vector{String}` | Secondary ICD-10-CM codes |
| `procedures` | `Vector{String}` | CPT or ICD-10-PCS procedure codes |
| `drg_code` | `String` | CMS DRG classification |
| `payer` | `Symbol` | Payer type symbol |
| `total_charges` | `Float64` | Gross charges billed |
| `allowed_amount` | `Float64` | Net reimbursement amount |
| `los_days` | `Int` | Length of stay in days |
| `discharge_status` | `String` | HL7 discharge disposition code |

---

#### `IngestionConfig`

```julia
@kwdef struct IngestionConfig
    source_system   :: String
    facility_id     :: String
    data_class      :: Symbol     # :phi, :deidentified, :synthetic
    require_consent :: Bool
    anonymize       :: Bool
    encoding        :: String = "UTF-8"
    date_format     :: String = "yyyy-mm-dd"
end
```

---

#### `IngestionResult`

```julia
struct IngestionResult
    records_loaded      :: Int
    records_rejected    :: Int
    validation_errors   :: Vector{ValidationError}
    audit_entry         :: AuditLogEntry
    quality_report      :: QualityReport
end
```

---

#### `ValidationError`

```julia
struct ValidationError
    encounter_id :: String
    patient_id   :: String
    field        :: String
    code         :: String
    message      :: String
    severity     :: Symbol    # :error, :warning
end
```

---

#### `AuditLogEntry`

```julia
struct AuditLogEntry
    event_id        :: String          # UUID
    timestamp       :: DateTime
    facility_id     :: String
    event_type      :: Symbol
    records_affected :: Int
    user_id         :: Union{String, Nothing}
    metadata        :: Dict{String, Any}
    checksum        :: String          # SHA-256 of payload
end
```

---

#### `AuditLogStore`

Mutable container for audit log entries. Thread-safe.

```julia
mutable struct AuditLogStore
    entries  :: Vector{AuditLogEntry}
    lock     :: ReentrantLock
end

AuditLogStore()    # Construct empty store
```

---

### Functions

---

#### `ingest_csv`

```julia
ingest_csv(filepath::String, config::IngestionConfig) :: IngestionResult
```

Load patient encounter data from a CSV file with field-level validation and
optional HIPAA de-identification.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `filepath` | `String` | Absolute or relative path to CSV file |
| `config` | `IngestionConfig` | Ingestion configuration |

**Returns:** `IngestionResult`

**Example:**
```julia
config = IngestionConfig(source_system="Epic", facility_id="FAC001",
                          data_class=:phi, require_consent=false, anonymize=true)
result = ingest_csv("encounters.csv", config)
println(result.records_loaded)
```

---

#### `validate_icd10_code`

```julia
validate_icd10_code(code::String) :: Bool
```

Return `true` if `code` is a valid ICD-10-CM diagnosis code, `false` otherwise.

**Example:**
```julia
validate_icd10_code("I50.9")   # → true
validate_icd10_code("Z999999") # → false
```

---

#### `validate_cpt_code`

```julia
validate_cpt_code(code::String) :: Bool
```

Return `true` if `code` is a valid CPT procedure code (5-digit numeric or
Category II/III alphanumeric).

---

#### `validate_patient_encounter`

```julia
validate_patient_encounter(enc::PatientEncounter) :: ValidationResult
```

Run all validation rules against a single encounter. Returns a `ValidationResult`
with any errors or warnings.

---

#### `validate_encounters_batch`

```julia
validate_encounters_batch(encounters::Vector{PatientEncounter}) :: Vector{ValidationError}
```

Run validation against all encounters in the vector. Returns all errors found.

---

#### `deidentify_encounter`

```julia
deidentify_encounter(enc::PatientEncounter;
                     method::Symbol = :safe_harbor) :: PatientEncounter
```

Apply HIPAA Safe Harbor de-identification to a single encounter. Returns a new
(immutable) `PatientEncounter` with PHI fields replaced.

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enc` | `PatientEncounter` | — | Source encounter with PHI |
| `method` | `Symbol` | `:safe_harbor` | De-identification method; `:safe_harbor` or `:expert_determination` |

---

#### `generate_pseudonym`

```julia
generate_pseudonym(patient_id::String; salt::String = "") :: String
```

Generate a deterministic, collision-resistant pseudonym for a patient ID using
HMAC-SHA256. The same `patient_id` + `salt` always produces the same pseudonym,
enabling linkage without storing original IDs.

**Example:**
```julia
p1 = generate_pseudonym("PT_12345", salt = "study_2024")
p2 = generate_pseudonym("PT_12345", salt = "study_2024")
@assert p1 == p2    # Deterministic
```

---

#### `validate_deidentification`

```julia
validate_deidentification(enc::PatientEncounter) :: Bool
```

Return `true` if the encounter contains no detectable PHI (checks 18 HIPAA
Safe Harbor identifiers). Raises a warning for each remaining identifier.

---

#### `log_ingestion_event`

```julia
log_ingestion_event(store::AuditLogStore,
                    facility_id::String,
                    event_type::Symbol,
                    records_affected::Int;
                    user_id::Union{String,Nothing} = nothing,
                    metadata::Dict{String,Any} = Dict()) :: AuditLogEntry
```

Add an event to the audit log and return the new entry.

---

#### `audit_log_summary`

```julia
audit_log_summary(store::AuditLogStore) :: NamedTuple
```

Return a summary of all audit events: `(total_events, first_event_time, last_event_time, event_type_counts)`.

---

## Patient Cohort Builder

### Types

---

#### `CriterionType`

Abstract supertype for all inclusion/exclusion criteria.

```julia
abstract type CriterionType end
```

---

#### Concrete Criterion Types

| Type | Key Fields | Description |
|------|-----------|-------------|
| `AgeCriterion` | `min_age`, `max_age` | Age at admission (years) |
| `DiagnosisCriterion` | `codes::Vector{String}`, `match_mode::Symbol` | ICD-10 code matching (`:exact`, `:prefix`) |
| `ProcedureCriterion` | `codes::Vector{String}` | CPT / ICD-10-PCS code list |
| `CostCriterion` | `min_cost`, `max_cost` | Total charges or allowed amount range |
| `LengthOfStayCriterion` | `min_days`, `max_days` | LOS in days |
| `PayerCriterion` | `payers::Vector{Symbol}` | Payer type allowlist |
| `DateRangeCriterion` | `start::Date`, `stop::Date` | Admission date range |

---

#### `CohortDefinition`

```julia
@kwdef struct CohortDefinition
    name           :: String
    description    :: String = ""
    criteria       :: Vector{CriterionType}
    logic          :: Symbol = :all    # :all (AND) or :any (OR)
end
```

---

#### `CohortStatistics`

```julia
struct CohortStatistics
    n                   :: Int
    mean_age            :: Float64
    median_age          :: Float64
    mean_cost           :: Float64
    median_cost         :: Float64
    mean_los            :: Float64
    readmission_rate    :: Float64
    payer_distribution  :: Dict{Symbol, Float64}
    top_diagnoses       :: Vector{Tuple{String, Int}}
end
```

---

#### `PatientCohort`

```julia
struct PatientCohort
    cohort_id   :: String
    definition  :: CohortDefinition
    encounters  :: Vector{PatientEncounter}
    statistics  :: CohortStatistics
    created_at  :: DateTime
end
```

---

### Functions

---

#### `build_cohort`

```julia
build_cohort(encounters::Vector{PatientEncounter},
             definition::CohortDefinition) :: PatientCohort
```

Apply inclusion/exclusion criteria and return a `PatientCohort`.

**Example:**
```julia
def = CohortDefinition(
    name     = "HF_2024",
    criteria = [AgeCriterion(min_age=65), DiagnosisCriterion(codes=["I50.9"])]
)
cohort = build_cohort(encounters, def)
println(cohort.statistics.n)
```

---

#### `calculate_cohort_statistics`

```julia
calculate_cohort_statistics(encounters::Vector{PatientEncounter}) :: CohortStatistics
```

Compute descriptive and financial statistics for a vector of encounters.

---

## Episode Costing

### Types

---

#### `Episode`

```julia
@kwdef mutable struct Episode
    episode_id          :: String
    patient_id          :: String
    admission_date      :: Date
    discharge_date      :: Date
    primary_diagnosis   :: String
    drg_code            :: String
    secondary_diagnoses :: Vector{String} = String[]
    procedures          :: Vector{String} = String[]
    payer               :: Symbol = :Medicare
end
```

---

#### Cost Model Types

| Type | Key Fields | Description |
|------|-----------|-------------|
| `DRGCostModel` | `base_cost`, `wage_index`, `outlier_threshold` | CMS DRG-based payment |
| `DailyRateCostModel` | `icu_rate`, `step_down`, `med_surg`, `icu_days`, `step_down_days` | Per-diem cost model |
| `RVUCostModel` | `conversion_factor`, `practice_expense_rvu`, `malpractice_rvu` | RVU-based costing |
| `ActivityBasedCostModel` | `activities::Dict{String,Float64}` | Activity-based costing |

---

#### `EpisodeOutcomes`

```julia
@kwdef mutable struct EpisodeOutcomes
    survived            :: Bool
    qaly_gained         :: Float64
    readmitted_30day    :: Bool
    readmitted_90day    :: Bool = false
    complications       :: Vector{String} = String[]
    discharge_status    :: String = "01"
end
```

---

#### `EpisodeSummary`

```julia
struct EpisodeSummary
    episode_id      :: String
    total_cost      :: Float64
    qaly_gained     :: Float64
    icer            :: Float64
    cost_per_los    :: Float64
    readmission     :: Bool
end
```

---

### Functions

---

#### `calculate_episode_cost`

```julia
calculate_episode_cost(episode::Episode, model::M) :: Float64
    where M <: Union{DRGCostModel, DailyRateCostModel, RVUCostModel, ActivityBasedCostModel}
```

Calculate the total episode cost using the specified cost model.

**Example:**
```julia
cost = calculate_episode_cost(episode, DRGCostModel(base_cost = 10_000.0))
```

---

## Health Economics

### Functions

---

#### `calculate_qaly`

```julia
calculate_qaly(life_years::Float64, utility_weight::Float64) :: Float64
```

Compute undiscounted QALYs as `life_years × utility_weight`.

---

#### `calculate_discounted_qaly`

```julia
calculate_discounted_qaly(life_years::Float64,
                           utility_weight::Float64;
                           discount_rate::Float64 = 0.03) :: Float64
```

Compute time-discounted QALYs using continuous exponential discounting.

---

#### `calculate_icer`

```julia
calculate_icer(; intervention_cost   :: Float64,
                  intervention_effect :: Float64,
                  control_cost        :: Float64,
                  control_effect      :: Float64) :: Float64
```

Compute the Incremental Cost-Effectiveness Ratio.

**Formula:** `ICER = (intervention_cost − control_cost) / (intervention_effect − control_effect)`

Returns `Inf` if `intervention_effect == control_effect`.

---

#### `calculate_nmb`

```julia
calculate_nmb(; delta_cost   :: Float64,
                delta_effect  :: Float64,
                wtp_threshold :: Float64) :: Float64
```

Compute Net Monetary Benefit at a given willingness-to-pay threshold.

**Formula:** `NMB = wtp_threshold × delta_effect − delta_cost`

Positive NMB → cost-effective at threshold.

---

## Patient Flow Simulation

### Types

---

#### `PathwayStage`

```julia
@kwdef struct PathwayStage
    name        :: String
    mean_hours  :: Float64
    cost        :: Float64
    cv          :: Float64 = 0.3    # Coefficient of variation
end
```

---

#### `ClinicalPathway`

```julia
@kwdef struct ClinicalPathway
    name                     :: String
    stages                   :: Vector{PathwayStage}
    branching_probabilities  :: Dict{String, Dict{String, Float64}} = Dict()
end
```

---

#### `CohortSimulationConfig`

```julia
@kwdef struct CohortSimulationConfig
    n_patients   :: Int
    random_seed  :: Int = 0
    time_horizon :: Int = 30    # days
    n_threads    :: Int = 1
end
```

---

#### `CohortSimulationResults`

```julia
struct CohortSimulationResults
    costs        :: Vector{Float64}
    los_days     :: Vector{Float64}
    survived     :: Vector{Bool}
    readmitted   :: Vector{Bool}
    stage_times  :: Matrix{Float64}    # n_patients × n_stages
end
```

---

### Functions

---

#### `run_cohort_simulation`

```julia
run_cohort_simulation(pathway::ClinicalPathway,
                       config::CohortSimulationConfig) :: CohortSimulationResults
```

Run an agent-based cohort simulation through the pathway. Returns per-patient
cost, LOS, survival, and readmission outcomes.

---

## Value-Based Care & Payer Models

### Types

---

#### `VBCContract`

```julia
@kwdef struct VBCContract
    contract_id        :: String
    contract_type      :: Symbol    # :shared_savings, :shared_risk, :capitation, :bundled
    benchmark_cost     :: Float64
    savings_share      :: Float64
    quality_threshold  :: Float64
    performance_period :: Int
end
```

---

#### `BudgetImpactModel`

```julia
@kwdef struct BudgetImpactModel
    population_size  :: Int
    time_horizon     :: Int
    discount_rate    :: Float64
    payer_mix        :: Dict{Symbol, Float64}
end
```

---

### Functions

---

#### `calculate_financial_impact`

```julia
calculate_financial_impact(contract::VBCContract;
                            realized_cost  :: Float64,
                            quality_score  :: Float64) :: NamedTuple
```

Calculate net revenue change under a VBC contract given realized cost and
quality score.

**Returns:** `(net_revenue_change, shared_savings, quality_bonus, total)`

---

#### `run_budget_impact`

```julia
run_budget_impact(model::BudgetImpactModel,
                   intervention,
                   comparator) :: NamedTuple
```

Estimate 1-, 2-, and 3-year budget impact of switching from comparator to
intervention for the modeled population.

---

## Comparative Effectiveness Analysis

### Types

---

#### `CostEffectivenessResult`

```julia
struct CostEffectivenessResult
    icer            :: Float64
    delta_cost      :: Float64
    delta_effect    :: Float64
    dominant_at_50k :: Bool
    dominant_at_100k:: Bool
    nmb_at_50k      :: Float64
    nmb_at_100k     :: Float64
end
```

---

### Functions

---

#### `run_cea`

```julia
run_cea(; intervention, comparator, wtp_range) :: CostEffectivenessResult
```

Run a deterministic cost-effectiveness analysis.

---

#### `run_psa`

```julia
run_psa(; n_iterations   :: Int,
           cost_dist       :: Distribution,
           effect_dist     :: Distribution,
           control_cost    :: Distribution,
           control_effect  :: Distribution,
           random_seed     :: Int = 0) :: PSAResults
```

Run probabilistic sensitivity analysis using Monte Carlo sampling over
parameter distributions.

---

#### `compute_ceac`

```julia
compute_ceac(psa::PSAResults;
              wtp_thresholds :: AbstractRange) :: DataFrame
```

Compute cost-effectiveness acceptability curve from PSA results.

**Returns:** `DataFrame` with columns `wtp_threshold` and `probability_ce`.

---

#### `run_threshold_analysis`

```julia
run_threshold_analysis(; base_icer       :: Float64,
                          parameter        :: Symbol,
                          range            :: AbstractRange,
                          wtp_threshold    :: Float64) :: NamedTuple
```

One-way sensitivity analysis varying a single parameter over a range.

**Returns:** `(parameter_values, icers, breakeven_value)`

---

#### `run_tornado_analysis`

```julia
run_tornado_analysis(base_icer::Float64,
                      params::Vector{Tuple}) :: DataFrame
```

Run multi-parameter one-way sensitivity analysis for tornado diagram plotting.

**`params` format:** `Vector` of `(parameter_symbol, low_value, high_value)` tuples.

---

## Multi-Level Policy Coupling

### Types

---

#### Abstract Types

```julia
abstract type FederalPolicy  end
abstract type StatePolicy    end
abstract type HospitalStrategy end
```

---

#### Federal Policy Types

| Type | Key Fields | Description |
|------|-----------|-------------|
| `MedicarePaymentReform` | `drg_weight_changes`, `quality_incentive_pool`, `bundled_payment_rate`, `implementation_year` | Medicare DRG weight and quality incentive changes |
| `ProposedMLLRate` | `affects_services`, `national_rate`, `implementation_year` | Minimum Loss Ratio rate proposals |

---

#### State Policy Types

| Type | Key Fields | Description |
|------|-----------|-------------|
| `MedicaidExpansion` | `coverage_increase`, `payment_rate_multiplier`, `eligibility_age`, `implementation_year` | ACA Medicaid expansion |
| `HospitalRateSetting` | `target_margin`, `affected_payers`, `adjustment_period`, `implementation_year` | All-payer rate regulation |
| `RuralHospitalSupport` | `supplemental_payment_per_bed`, `criteria`, `funding_source`, `implementation_year` | Rural supplemental payments |
| `PayerMixShift` | `from_payer`, `to_payer`, `volume_shift`, `implementation_year` | Coverage transition modeling |

---

#### Hospital Strategy Types

| Type | Key Fields | Description |
|------|-----------|-------------|
| `ConservativeStrategy` | `cost_reduction_target`, `service_preservation_priority` | Minimize costs, preserve core services |
| `AggressiveExpansionStrategy` | `target_service_lines`, `marketing_budget`, `years_to_full_effect` | Invest in growth |
| `AccommodativeStrategy` | `quality_investment`, `value_alignment_rate` | Align with payer quality goals |

---

#### `MultiLevelPolicyScenario`

```julia
@kwdef mutable struct MultiLevelPolicyScenario
    federal_policies  :: Vector{FederalPolicy}
    state_policies    :: Vector{StatePolicy}
    hospitals         :: Vector{Any}
    simulation_years  :: Int
    base_year         :: Int = 2024
end
```

---

#### `PolicyCouplingOutcomes`

```julia
mutable struct PolicyCouplingOutcomes
    scenario_name           :: String
    simulation_years        :: Int
    federal_impact          :: Dict{String, Float64}
    state_impact            :: Dict{String, Float64}
    hospital_level_outcomes :: Dict{String, Dict{String, Float64}}
    equity_metrics          :: Dict{String, Float64}
    aggregate_financials    :: Dict{String, Float64}
end
```

---

### Functions

---

#### `simulate_policy_coupling!`

```julia
simulate_policy_coupling!(scenario::MultiLevelPolicyScenario) :: PolicyCouplingOutcomes
```

Run the multi-level policy cascade simulation and return hospital-level outcomes.

---

#### `analyze_policy_interactions`

```julia
analyze_policy_interactions(scenario::MultiLevelPolicyScenario,
                             outcomes::PolicyCouplingOutcomes) :: NamedTuple
```

Decompose total policy impact into federal, state, and interaction components.

---

#### `calculate_federal_impact`

```julia
calculate_federal_impact(policy::FederalPolicy, hospital) :: Dict{String, Float64}
```

Compute the direct financial impact of a single federal policy on one hospital.

---

#### `calculate_state_impact`

```julia
calculate_state_impact(policy::StatePolicy, hospital) :: Dict{String, Float64}
```

Compute the direct financial impact of a single state policy on one hospital.

---

## Policy Validation

### Types

---

#### `ValidationMetrics`

```julia
mutable struct ValidationMetrics
    mape                 :: Float64    # Mean absolute percentage error
    directional_accuracy :: Float64    # Fraction with correct direction
    rmse                 :: Float64    # Root mean squared error
    correlation          :: Float64    # Pearson r
    max_error            :: Float64    # Maximum absolute error
    metadata             :: Dict{String, Any}
end
```

---

#### `ValidationResult`

```julia
mutable struct ValidationResult
    case_study_name         :: String
    simulation_name         :: String
    metrics                 :: ValidationMetrics
    actual_outcomes         :: DataFrame
    simulated_outcomes      :: DataFrame
    hospital_level_results  :: Dict{String, Dict{String, Float64}}
    summary                 :: String
    timestamp               :: DateTime
end
```

---

#### Case Study Types

All case studies are subtypes of `CaseStudy`.

| Type | Period | Key Policy |
|------|--------|-----------|
| `KentuckyMedicaidExpansion` | 2014 | ACA Medicaid expansion |
| `MarylandAllPayerModel` | 2014–2018 | All-payer rate setting |
| `RuralHospitalClosureCase` | 2010–2023 | Rural closure dynamics |
| `COVID19ImpactCase` | 2020–2021 | Pandemic financial shock |

---

### Functions

---

#### `load_case_study`

```julia
load_case_study(case::CaseStudy) :: NamedTuple
```

Load the case study data structure containing actual observed outcomes.

---

#### `validate_simulation`

```julia
validate_simulation(case_study, simulation_fn::Function) :: ValidationResult
```

Run `simulation_fn` against the case study scenario and compute validation
metrics vs. actual observed outcomes.

---

#### `calculate_metrics`

```julia
calculate_metrics(actual::Vector{Float64},
                   predicted::Vector{Float64}) :: ValidationMetrics
```

Compute MAPE, directional accuracy, RMSE, and correlation between actual and
predicted values.

---

#### `generate_validation_report`

```julia
generate_validation_report(result::ValidationResult) :: String
```

Generate a formatted text validation report suitable for publication appendices.

---

#### `compare_outcomes`

```julia
compare_outcomes(actual::DataFrame,
                  simulated::DataFrame) :: DataFrame
```

Produce a side-by-side comparison DataFrame of actual vs. simulated outcomes
with residuals and percentage errors.

---

## Release Preparation

### Types

---

#### `ReleaseChecklistItem`

```julia
mutable struct ReleaseChecklistItem
    category    :: String
    item        :: String
    status      :: String    # "complete", "in_progress", "pending"
    target_date :: Union{Date, Nothing}
    notes       :: String
end
```

---

#### `PerformanceBenchmark`

```julia
mutable struct PerformanceBenchmark
    simulation_type      :: String
    execution_time_seconds :: Float64
    memory_usage_mb      :: Float64
    hospitals_simulated  :: Int
    years_simulated      :: Int
    performance_grade    :: String    # "excellent", "good", "acceptable", "needs_improvement"
end
```

Performance grading thresholds:

| Grade | Condition |
|-------|-----------|
| `"excellent"` | < 5 seconds |
| `"good"` | 5 – 30 seconds |
| `"acceptable"` | 30 – 120 seconds |
| `"needs_improvement"` | > 120 seconds |

---

#### `TestCoverageAnalysis`

```julia
mutable struct TestCoverageAnalysis
    total_tests     :: Int
    passing_tests   :: Int
    coverage_percent :: Float64
    phase_breakdown :: Dict{String, Dict{String, Int}}
    metadata        :: Dict{String, Any}
end
```

---

#### `ReleaseMetrics`

```julia
mutable struct ReleaseMetrics
    test_coverage            :: TestCoverageAnalysis
    performance              :: Vector{PerformanceBenchmark}
    validation_mape          :: Float64
    directional_accuracy     :: Float64
    documentation_complete   :: Bool
    reproducibility_verified :: Bool
end
```

---

#### `ReleaseReadinessReport`

```julia
mutable struct ReleaseReadinessReport
    release_version      :: String
    generation_timestamp :: DateTime
    checklist            :: Vector{ReleaseChecklistItem}
    metrics              :: ReleaseMetrics
    critical_issues      :: Vector{String}
    warnings             :: Vector{String}
    recommendations      :: Vector{String}
    overall_status       :: String    # "ready", "pending", "blocked"
end
```

**Status logic:**

| Condition | Status |
|-----------|--------|
| Any critical issue exists | `"blocked"` |
| > 2 warnings | `"pending"` |
| Otherwise | `"ready"` |

Critical issue triggers:
- `test_coverage.coverage_percent < 85%`
- `validation_mape > 10%`

Warning triggers:
- `directional_accuracy < 90%`
- Any `needs_improvement` benchmarks
- `documentation_complete == false`
- `reproducibility_verified == false`

---

### Functions

---

#### `validate_test_coverage`

```julia
validate_test_coverage(test_counts::Dict{String, Int}) :: TestCoverageAnalysis
```

Aggregate test counts from Phase 3 subphases and compute coverage metrics.

**Expected keys:** `"phase_31"`, `"phase_32"`, `"phase_33"`.

**Example:**
```julia
coverage = validate_test_coverage(Dict("phase_31"=>52, "phase_32"=>77, "phase_33"=>82))
# coverage.total_tests == 211
```

---

#### `benchmark_performance`

```julia
benchmark_performance(simulation_configs::Vector) :: Vector{PerformanceBenchmark}
```

Run performance benchmarks for each simulation configuration and return graded
results.

**Config dict keys:**

| Key | Type | Description |
|-----|------|-------------|
| `"type"` | `String` | Human-readable label |
| `"num_hospitals"` | `Int` | Number of hospitals to simulate |
| `"num_years"` | `Int` | Simulation time horizon (years) |

---

#### `check_release_readiness`

```julia
check_release_readiness(metrics::ReleaseMetrics) :: ReleaseReadinessReport
```

Evaluate all release criteria and return a comprehensive readiness report with
10 checklist items, critical issues, warnings, and overall status.

---

#### `generate_release_report`

```julia
generate_release_report(report::ReleaseReadinessReport) :: String
```

Format the release readiness report as a human-readable text document suitable
for stakeholder review.

---

## Constants

### Payer Symbols

```julia
const Medicare   = :Medicare
const Medicaid   = :Medicaid
const Commercial = :Commercial
const SelfPay    = :SelfPay
```

### Default Willingness-to-Pay Thresholds

| Threshold | Value |
|-----------|-------|
| ICER acceptability (US, low) | `$50,000/QALY` |
| ICER acceptability (US, high) | `$150,000/QALY` |
| WHO threshold (GDP per capita, US) | `$60,000/QALY` |

### Discount Rates

| Parameter | Default |
|-----------|---------|
| Cost discount rate | `0.03` (3%) |
| QALY discount rate | `0.03` (3%) |

---

*For complete source code, see `src/HospitalFinanceToolbox.jl` and its included modules.*
