# HospitalFinanceToolbox.jl — User Guide (v1.0)

**Healthcare Economics Research Platform**  
**Julia 1.10+ LTS | Production Release**

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Installation & Setup](#2-installation--setup)
3. [Quick Start Tutorial](#3-quick-start-tutorial)
4. [Data Ingestion & Validation](#4-data-ingestion--validation)
5. [Patient Cohort Analysis](#5-patient-cohort-analysis)
6. [Episode-Level Costing](#6-episode-level-costing)
7. [Health Economics Frameworks](#7-health-economics-frameworks)
8. [Patient Flow Simulation](#8-patient-flow-simulation)
9. [Value-Based Care & Payer Models](#9-value-based-care--payer-models)
10. [Comparative Effectiveness Analysis](#10-comparative-effectiveness-analysis)
11. [Multi-Level Policy Simulation](#11-multi-level-policy-simulation)
12. [Policy Analysis & Reporting](#12-policy-analysis--reporting)
13. [Real-World Policy Validation](#13-real-world-policy-validation)
14. [Network Simulation & Optimization](#14-network-simulation--optimization)
15. [Release Validation & Benchmarking](#15-release-validation--benchmarking)
16. [Workflow Examples](#16-workflow-examples)
17. [Troubleshooting](#17-troubleshooting)
18. [Glossary](#18-glossary)

---

## 1. Introduction

HospitalFinanceToolbox.jl is a production-grade Julia package for healthcare
economics research and hospital financial decision support. It provides a unified
platform for:

- **Episode and encounter-level costing** — DRG, daily-rate, RVU, and
  activity-based cost models applied to individual patient episodes
- **Health economics frameworks** — QALY calculations, ICER, NMB, and
  probabilistic cost-effectiveness analysis
- **Patient flow simulation** — Agent-based simulation with integrated cost
  tracking at the individual patient level
- **Multi-hospital network modeling** — Referral flow analysis, network-level
  cost roll-ups, and portfolio optimization
- **Multi-level policy simulation** — Federal → state → hospital cascade model
  with real-world validation
- **Publication-ready reporting** — Cost-effectiveness planes, tornado diagrams,
  network graphs, and equity analyses

### Who Should Use This Package

| User | Primary Use |
|------|-------------|
| Health economics researchers | CEA, PSA, ICER, CEAC analysis |
| Hospital CFOs / analysts | Financial projection, closure risk, portfolio optimization |
| Policy researchers | State/federal policy impact simulation |
| Clinical informatics | Patient cohort building, cost attribution |
| Graduate students | Training platform for healthcare economic methods |

### Design Principles

1. **Separation of concerns** — domain logic (`src/`) is independent of any web
   framework; all modules usable standalone
2. **Reproducibility** — random seeds, explicit parameter structs, versioned
   inputs ensure bit-identical results across runs
3. **HIPAA compliance** — de-identification and audit logging built in at the
   data ingestion layer
4. **Type safety** — strong Julia typing throughout; no dynamic dispatch in hot
   paths; `@kwdef` structs with documented fields
5. **Testability** — each module ships with ≥ 90% test coverage via `Test.jl`

---

## 2. Installation & Setup

### Prerequisites

- Julia 1.10 or later (LTS recommended)
- Git
- 4 GB RAM minimum (16 GB recommended for large network simulations)

### Installing from Source

```bash
git clone https://github.com/timothyhartzog/Hospital-economics.git
cd Hospital-economics
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Verifying the Installation

```julia
julia --project=. --startup-file=no -e '
    include("src/HospitalFinanceToolbox.jl")
    using .HospitalFinanceToolbox
    println("HospitalFinanceToolbox v1.0 loaded successfully")
'
```

### Running the Test Suite

```bash
# Full test suite (all 645+ tests)
julia --compiled-modules=no --startup-file=no --project=. test/runtests.jl

# Single module test
julia --compiled-modules=no --startup-file=no --project=. \
      test/test_release_preparation.jl
```

> **Note:** The `--compiled-modules=no` flag is required in environments with
> disk space constraints or restricted LLVM compilation. It has no effect on
> correctness.

### Docker (Optional)

```bash
cd docker/
docker compose up -d
# Access the web interface at http://localhost:8000
```

---

## 3. Quick Start Tutorial

This tutorial walks through a complete cost-effectiveness analysis comparing
two treatment protocols for heart failure patients.

### Step 1: Load the Package

```julia
using Dates
include("src/HospitalFinanceToolbox.jl")
using .HospitalFinanceToolbox
```

### Step 2: Define Patient Episodes

```julia
# Create two cohorts: standard care vs. enhanced care coordination
standard_episode = Episode(
    episode_id        = "HF_STD_001",
    patient_id        = "PT_001",
    admission_date    = Date(2024, 3, 1),
    discharge_date    = Date(2024, 3, 5),   # 5-day LOS
    primary_diagnosis = "I50.9",            # Heart failure, unspecified
    drg_code          = "291",              # Heart failure w/ MCC
    secondary_diagnoses = ["I10", "E11.9"], # HTN, DM2
    procedures        = ["99232"],           # Subsequent hospital care
    payer             = Medicare
)

enhanced_episode = Episode(
    episode_id        = "HF_EHC_001",
    patient_id        = "PT_001",
    admission_date    = Date(2024, 3, 1),
    discharge_date    = Date(2024, 3, 4),   # 4-day LOS (1 day shorter)
    primary_diagnosis = "I50.9",
    drg_code          = "292",              # Heart failure w/ CC
    secondary_diagnoses = ["I10", "E11.9"],
    procedures        = ["99232", "93306"], # + Echo
    payer             = Medicare
)
```

### Step 3: Calculate Costs

```julia
# DRG-based cost model
cost_model = DRGCostModel(base_cost = 9_000.0)

std_cost = calculate_episode_cost(standard_episode, cost_model)
enh_cost = calculate_episode_cost(enhanced_episode, cost_model)

println("Standard care cost:  \$$(round(std_cost, digits=2))")
println("Enhanced care cost:  \$$(round(enh_cost, digits=2))")
```

### Step 4: Estimate Outcomes

```julia
std_outcomes = EpisodeOutcomes(
    survived         = true,
    qaly_gained      = 0.72,
    readmitted_30day = true    # 24% baseline readmission rate
)

enh_outcomes = EpisodeOutcomes(
    survived         = true,
    qaly_gained      = 0.81,   # Improved by care coordination
    readmitted_30day = false
)
```

### Step 5: Calculate ICER

```julia
icer = calculate_icer(
    intervention_cost   = enh_cost,
    intervention_effect = enh_outcomes.qaly_gained,
    control_cost        = std_cost,
    control_effect      = std_outcomes.qaly_gained
)

println("ICER: \$$(round(icer, digits=0)) per QALY gained")
# Interpretation: below $50,000/QALY threshold → cost-effective
```

---

## 4. Data Ingestion & Validation

The data ingestion layer provides HIPAA-compliant loading, validation, and
de-identification of patient encounter data.

### 4.1 Loading Patient Data from CSV

```julia
config = IngestionConfig(
    source_system   = "Epic",
    facility_id     = "FAC_001",
    data_class      = :phi,           # PHI — triggers HIPAA audit
    require_consent = false,          # Research exception
    anonymize       = true
)

result = ingest_csv("data/encounters_2024.csv", config)
println("Loaded $(result.records_loaded) records")
println("Validation errors: $(length(result.validation_errors))")
```

### 4.2 Validating ICD-10 and CPT Codes

```julia
# Single code validation
is_valid = validate_icd10_code("I50.9")  # → true
is_valid = validate_icd10_code("Z99999") # → false

# Batch encounter validation
errors = validate_encounters_batch(encounters)
for err in errors
    println("[$(err.field)] $(err.message) — patient $(err.patient_id)")
end
```

### 4.3 HIPAA De-identification

```julia
# De-identify a single encounter (Safe Harbor method)
phi_encounter = PatientEncounter(...)
deidentified  = deidentify_encounter(phi_encounter)

# Verify de-identification
is_phi_free = validate_deidentification(deidentified)
@assert is_phi_free "De-identification incomplete"

# Generate stable pseudonyms for linkage studies
pseudonym = generate_pseudonym("PT_REAL_ID_001", salt = "study_2024")
```

### 4.4 Audit Logging

```julia
store = AuditLogStore()
log_ingestion_event(store, "FAC_001", :csv_import, 1500,
                     metadata = Dict("source_file" => "q1_2024.csv"))

summary = audit_log_summary(store)
println("Total events: $(summary.total_events)")
println("Last event:   $(summary.last_event_time)")
```

---

## 5. Patient Cohort Analysis

Build and analyze patient cohorts with flexible inclusion/exclusion criteria.

### 5.1 Defining a Cohort

```julia
# Heart failure patients aged 65+, Medicare, admitted in 2024
criteria = [
    AgeCriterion(min_age = 65),
    DiagnosisCriterion(codes = ["I50.0", "I50.1", "I50.9"]),
    PayerCriterion(payers = [Medicare]),
    DateRangeCriterion(start = Date(2024,1,1), stop = Date(2024,12,31))
]

definition = CohortDefinition(
    name     = "HF_Medicare_2024",
    criteria = criteria
)

cohort = build_cohort(all_encounters, definition)
```

### 5.2 Cohort Statistics

```julia
stats = cohort.statistics  # auto-calculated by build_cohort

println("N = $(stats.n)")
println("Mean age: $(round(stats.mean_age, digits=1))")
println("Mean cost: \$$(round(stats.mean_cost, digits=0))")
println("Mean LOS: $(round(stats.mean_los, digits=1)) days")
println("Readmission rate: $(round(stats.readmission_rate * 100, digits=1))%")
```

### 5.3 Sub-cohort Comparison

```julia
# Split by treatment arm
control_cohort     = build_cohort(cohort.encounters,
                                   [DiagnosisCriterion(codes=["I50.9"])])
intervention_cohort = build_cohort(cohort.encounters,
                                   [ProcedureCriterion(codes=["0JH604Z"])])

# Compare statistics
Δ_cost = intervention_cohort.statistics.mean_cost -
          control_cohort.statistics.mean_cost
println("Incremental cost: \$$(round(Δ_cost, digits=0))")
```

---

## 6. Episode-Level Costing

Four cost model types are supported, each implementing the `calculate_episode_cost`
interface.

### 6.1 DRG Cost Model

```julia
# Base cost scaled by DRG relative weight (fetched from CMS tables)
model = DRGCostModel(
    base_cost          = 10_000.0,    # Hospital base payment rate
    wage_index         = 1.12,        # Geographic wage adjustment
    outlier_threshold  = 3.0          # Standard deviations for outlier
)
cost = calculate_episode_cost(episode, model)
```

### 6.2 Daily Rate Cost Model

```julia
model = DailyRateCostModel(
    icu_rate    = 4_500.0,    # $/day in ICU
    step_down   = 2_200.0,    # $/day step-down
    med_surg    = 1_800.0,    # $/day med-surg
    icu_days    = 2,
    step_down_days = 1
)
cost = calculate_episode_cost(episode, model)
```

### 6.3 RVU-Based Cost Model

```julia
model = RVUCostModel(
    conversion_factor   = 36.04,   # CMS CF (2024)
    practice_expense_rvu = 0.41,   # PE RVU fraction
    malpractice_rvu      = 0.02    # PLI RVU fraction
)
cost = calculate_episode_cost(episode, model)
```

### 6.4 Activity-Based Cost Model

```julia
model = ActivityBasedCostModel(
    activities = Dict(
        "ED_triage"         => 85.0,
        "physician_visit"   => 320.0,
        "lab_panel"         => 145.0,
        "imaging_chest_xr"  => 210.0,
        "medication_admin"  => 45.0
    )
)
cost = calculate_episode_cost(episode, model)
```

---

## 7. Health Economics Frameworks

### 7.1 QALY Calculations

```julia
# Utility-weighted life years
qaly = calculate_qaly(
    life_years     = 5.0,
    utility_weight = 0.78    # EQ-5D score
)

# Time-discounted QALY
qaly_discounted = calculate_discounted_qaly(
    life_years     = 5.0,
    utility_weight = 0.78,
    discount_rate  = 0.03    # 3% annual discount
)
```

### 7.2 ICER Calculation

```julia
# Incremental cost-effectiveness ratio
icer = calculate_icer(
    intervention_cost   = 12_500.0,
    intervention_effect = 0.85,      # QALYs
    control_cost        = 9_800.0,
    control_effect      = 0.72
)
# ICER = (12500 - 9800) / (0.85 - 0.72) = $20,769/QALY
```

### 7.3 Net Monetary Benefit

```julia
# NMB = λ × ΔEffect - ΔCost, where λ = willingness-to-pay threshold
nmb = calculate_nmb(
    delta_cost   = 2_700.0,
    delta_effect = 0.13,
    wtp_threshold = 50_000.0
)
# NMB = 50000 × 0.13 - 2700 = $3,800 → cost-effective at $50k/QALY
```

---

## 8. Patient Flow Simulation

Agent-based patient flow simulation tracks individual patients through clinical
pathways with integrated cost accumulation.

### 8.1 Define a Clinical Pathway

```julia
pathway = ClinicalPathway(
    name   = "AMI_STEMI_pathway",
    stages = [
        PathwayStage("ED_arrival",     mean_hours = 0.5,  cost = 850.0),
        PathwayStage("Cath_lab",       mean_hours = 2.0,  cost = 12_000.0),
        PathwayStage("ICU",            mean_hours = 48.0, cost = 3_600.0),
        PathwayStage("Step_down",      mean_hours = 48.0, cost = 2_200.0),
        PathwayStage("Discharge_prep", mean_hours = 4.0,  cost = 400.0)
    ],
    branching_probabilities = Dict(
        "ED_arrival" => Dict("Cath_lab" => 0.85, "Med_management" => 0.15)
    )
)
```

### 8.2 Run a Cohort Simulation

```julia
sim_config = CohortSimulationConfig(
    n_patients   = 500,
    random_seed  = 42,
    time_horizon = 30    # days
)

results = run_cohort_simulation(pathway, sim_config)

println("Mean cost:      \$$(round(mean(results.costs), digits=0))")
println("Mean LOS:       $(round(mean(results.los_days), digits=1)) days")
println("30-day survival: $(round(mean(results.survived) * 100, digits=1))%")
```

---

## 9. Value-Based Care & Payer Models

### 9.1 Value-Based Care Contract

```julia
contract = VBCContract(
    contract_id        = "ACO_2024_001",
    contract_type      = :shared_savings,
    benchmark_cost     = 9_500.0,       # Per beneficiary per year
    savings_share      = 0.50,           # Hospital keeps 50% of savings
    quality_threshold  = 0.85,           # Must achieve 85% quality score
    performance_period = 2024
)

# Calculate financial impact
impact = calculate_financial_impact(contract, realized_cost = 8_900.0,
                                    quality_score = 0.89)
println("Net revenue change: \$$(round(impact.net_revenue_change, digits=0))")
```

### 9.2 Budget Impact Model

```julia
model = BudgetImpactModel(
    population_size   = 50_000,
    time_horizon      = 3,            # years
    discount_rate     = 0.03,
    payer_mix         = Dict(:Medicare => 0.55, :Medicaid => 0.20,
                              :Commercial => 0.18, :SelfPay => 0.07)
)

impact = run_budget_impact(model, intervention, comparator)
println("3-year budget impact: \$$(round(impact.total_3yr, digits=0))")
```

---

## 10. Comparative Effectiveness Analysis

### 10.1 Cost-Effectiveness Analysis

```julia
cea_result = run_cea(
    intervention = InterventionArm(name="Enhanced_protocol",
                                   cost = 12_500.0, effect = 0.85),
    comparator   = ComparatorArm(name="Standard_protocol",
                                  cost = 9_800.0,  effect = 0.72),
    wtp_range    = 0:5_000:150_000
)

println("ICER: \$$(round(cea_result.icer, digits=0))/QALY")
println("Dominant at \$50k threshold: $(cea_result.dominant_at_50k)")
```

### 10.2 Probabilistic Sensitivity Analysis

```julia
psa = run_psa(
    n_iterations   = 10_000,
    cost_dist      = LogNormal(log(12_500), 0.15),
    effect_dist    = Beta(17, 3),              # mean ≈ 0.85
    control_cost   = Normal(9_800, 800),
    control_effect = Beta(14.4, 2.6),          # mean ≈ 0.72
    random_seed    = 42
)

# Cost-effectiveness acceptability curve
ceac = compute_ceac(psa, wtp_thresholds = 0:5_000:150_000)
```

### 10.3 Threshold Analysis

```julia
threshold = run_threshold_analysis(
    base_icer       = 20_769.0,
    parameter       = :intervention_cost,
    range           = 8_000.0:500.0:20_000.0,
    wtp_threshold   = 50_000.0
)
println("Cost breakeven point: \$$(threshold.breakeven_value)")
```

---

## 11. Multi-Level Policy Simulation

### 11.1 Defining Policies

```julia
# Federal policy
medicare_reform = MedicarePaymentReform(
    drg_weight_changes   = Dict("291" => -0.03, "470" => 0.02),
    quality_incentive_pool = 0.015,   # 1.5% of total payments at risk
    bundled_payment_rate  = 0.95,
    implementation_year   = 2025
)

# State policy
medicaid_expansion = MedicaidExpansion(
    coverage_increase        = 0.12,   # +12 percentage points uninsured → Medicaid
    payment_rate_multiplier  = 0.95,   # Medicaid pays 95% of Medicare rate
    eligibility_age          = 65,
    implementation_year      = 2025
)

# Hospital strategy
strategy = AggressiveExpansionStrategy(
    target_service_lines = ["oncology", "orthopedics"],
    marketing_budget     = 500_000.0,
    years_to_full_effect = 3
)
```

### 11.2 Running the Coupled Simulation

```julia
scenario = MultiLevelPolicyScenario(
    federal_policies = [medicare_reform],
    state_policies   = [medicaid_expansion],
    hospitals        = hospital_network,
    simulation_years = 5
)

outcomes = simulate_policy_coupling!(scenario)

# Hospital-level results
for (hospital_id, results) in outcomes.hospital_level_outcomes
    rev_change = results["revenue_change"]
    println("$hospital_id: $(round(rev_change * 100, digits=1))% revenue change")
end
```

### 11.3 Interaction Analysis

```julia
interactions = analyze_policy_interactions(scenario, outcomes)
println("Federal contribution:   $(round(interactions.federal_share*100,digits=1))%")
println("State contribution:     $(round(interactions.state_share*100,digits=1))%")
println("Interaction term:       $(round(interactions.interaction*100,digits=1))%")
```

---

## 12. Policy Analysis & Reporting

### 12.1 Cost-Effectiveness Acceptability Curves

```julia
# Using PolicyAnalysisReporting module (src/analytics/)
ceac_data = generate_ceac(psa_results, wtp_range = 0:10_000:200_000)
plot_ceac(ceac_data, title = "CEAC: Enhanced vs. Standard Protocol")
```

### 12.2 Tornado Diagram

```julia
sensitivity_params = [
    (:intervention_cost, 10_000, 15_000),
    (:control_effect, 0.68, 0.76),
    (:discount_rate, 0.01, 0.05),
    (:time_horizon, 1, 10)
]

tornado = run_tornado_analysis(base_icer, sensitivity_params)
plot_tornado(tornado, title = "One-Way Sensitivity Analysis")
```

### 12.3 Budget Impact Report

```julia
report = generate_policy_report(
    title    = "Kentucky Medicaid Expansion Impact — Hospital-Level Analysis",
    scenario = scenario,
    outcomes = outcomes,
    format   = :text   # or :html, :markdown
)
println(report)
```

### 12.4 Equity Analysis

```julia
equity = run_equity_analysis(
    outcomes,
    demographic_groups = [:race_ethnicity, :income_quintile, :rural_urban],
    equity_metric      = :revenue_change
)

for group in equity.groups
    println("$(group.name): $(round(group.mean_impact, digits=1))%")
end
```

---

## 13. Real-World Policy Validation

### 13.1 Loading a Case Study

```julia
ky_case = load_case_study(KentuckyMedicaidExpansion())

println("Case: $(ky_case.name)")
println("Period: $(ky_case.start_year)–$(ky_case.end_year)")
println("Hospitals: $(ky_case.n_hospitals)")
```

### 13.2 Running Validation

```julia
result = validate_simulation(ky_case, my_simulation_function)

println("MAPE:                $(round(result.metrics.mape, digits=2))%")
println("Directional accuracy: $(round(result.metrics.directional_accuracy*100, digits=1))%")
println("RMSE:                $(round(result.metrics.rmse, digits=3))")
println("Correlation:         $(round(result.metrics.correlation, digits=3))")
```

### 13.3 Validation Report

```julia
validation_report = generate_validation_report(result)
println(validation_report)
```

---

## 14. Network Simulation & Optimization

### 14.1 Hospital Network Configuration

```julia
hospitals = [
    Hospital(id="H001", name="Regional Medical Center", beds=250,
              location=(37.09, -84.27), type=:PPS),
    Hospital(id="H002", name="Rural CAH East",          beds=25,
              location=(37.21, -83.98), type=:CAH),
    Hospital(id="H003", name="Rural CAH West",          beds=25,
              location=(36.88, -84.55), type=:CAH)
]

# Define referral flows (fraction of CAH patients referred to Regional)
referral_matrix = [
    0.0  0.0  0.0;   # H001 does not refer out
    0.15 0.0  0.0;   # H002 refers 15% to H001
    0.12 0.0  0.0    # H003 refers 12% to H001
]
network = HospitalNetwork(hospitals, referral_matrix)
```

### 14.2 Staffing Optimization

```julia
staffing_problem = StaffingOptimizationProblem(
    departments    = ["ED", "Med_Surg", "ICU", "Radiology"],
    shifts         = ["Day", "Evening", "Night"],
    demand         = demand_matrix,
    permanent_cost = permanent_salary_dict,
    travel_premium = 1.8,
    budget         = 12_000_000.0,
    required_min   = min_staffing_dict
)

solution = optimize_staffing(staffing_problem)
println("Optimal cost: \$$(round(solution.total_cost, digits=0))")
println("Solver status: $(solution.status)")
```

### 14.3 Service Portfolio Optimization

```julia
portfolio_problem = ServicePortfolioOptimization(
    services          = ["ED", "Surgery", "Obstetrics", "Imaging", "Lab"],
    revenue_per_unit  = revenue_dict,
    cost_per_unit     = cost_dict,
    volume_potential  = volume_dict,
    total_capacity    = 50,
    required_services = ["ED"],   # ED is mandatory
    community_weight  = 0.20
)

portfolio = optimize_portfolio(portfolio_problem)
println("Selected services: $(portfolio.active_services)")
println("Annual contribution margin: \$$(round(portfolio.contribution_margin, digits=0))")
```

---

## 15. Release Validation & Benchmarking

### 15.1 Validate Test Coverage

```julia
include("src/release/ReleasePreparation.jl")
using .ReleasePreparation

test_counts = Dict(
    "phase_31" => 52,
    "phase_32" => 77,
    "phase_33" => 82
)

coverage = validate_test_coverage(test_counts)
println("Total tests:    $(coverage.total_tests)")
println("Coverage:       $(coverage.coverage_percent)%")
```

### 15.2 Run Performance Benchmarks

```julia
configs = [
    Dict("type" => "Single-state simulation", "num_hospitals" => 50, "num_years" => 3),
    Dict("type" => "Multi-state simulation",  "num_hospitals" => 200, "num_years" => 5)
]

benchmarks = benchmark_performance(configs)
for b in benchmarks
    println("$(b.simulation_type): $(b.execution_time_seconds)s [$(b.performance_grade)]")
end
```

### 15.3 Check Release Readiness

```julia
metrics = ReleaseMetrics(
    coverage, benchmarks,
    5.2,   # validation MAPE
    0.95,  # directional accuracy
    true,  # documentation complete
    true   # reproducibility verified
)

report = check_release_readiness(metrics)
println(generate_release_report(report))
```

---

## 16. Workflow Examples

### Workflow 1: Annual Hospital Financial Planning

1. Load FY2024 encounter data with `ingest_csv`
2. Build service line cohorts with `build_cohort`
3. Calculate contribution margins per service line
4. Run `optimize_portfolio` to identify highest-value service mix
5. Use `benchmark_performance` to validate simulation runtime
6. Generate board presentation using `generate_policy_report`

### Workflow 2: Medicaid Policy Impact Analysis

1. Define `MedicaidExpansion` policy object
2. Configure `MultiLevelPolicyScenario` with state hospital network
3. Run `simulate_policy_coupling!`
4. Validate against `KentuckyMedicaidExpansion` case study
5. Generate equity analysis by rural/urban and income quintile
6. Produce publication-ready report

### Workflow 3: New Drug Cost-Effectiveness Submission

1. Define `Episode` objects for both arms from clinical trial data
2. Calculate costs with `DRGCostModel` (or `ActivityBasedCostModel` for novel
   pathways)
3. Run `run_psa` with 10,000 iterations
4. Compute `ceac` and plot cost-effectiveness plane
5. Run `run_threshold_analysis` for sensitivity reporting
6. Export results for HTA submission

### Workflow 4: Hospital Network Referral Optimization

1. Load network topology and referral matrix
2. Run `HospitalNetworkSimulation` with 1-year horizon
3. Run `optimize_portfolio` for each hospital in network
4. Identify bottleneck hospitals using capacity analysis
5. Simulate referral rerouting scenarios

---

## 17. Troubleshooting

### Common Errors

**`LoadError: type XYZ has no field abc`**
> You are accessing a field that was renamed in v1.0. See `MIGRATION_GUIDE.md`
> for the renamed fields.

**`ERROR: LLVM error during native compilation`**
> Add `--compiled-modules=no` to the Julia command line. This bypasses LLVM
> compilation in constrained environments without affecting results.

**`MethodError: no method matching calculate_icer(...)`**
> Ensure you are using keyword arguments in v1.0: `calculate_icer(intervention_cost=..., ...)`.

**`InfeasibleError` from JuMP optimization**
> Check that your demand values do not exceed total capacity. Also verify that
> required services are not excluded by cost constraints.

**Slow simulation performance**
> Use `--threads=auto` for multi-threaded runs. Monte Carlo simulations scale
> linearly with thread count.

### Getting Help

- GitHub Issues: https://github.com/timothyhartzog/Hospital-economics/issues
- See `examples/` directory for complete working examples
- Check `test/` for usage patterns of every public function

---

## 18. Glossary

| Term | Definition |
|------|-----------|
| **CEAC** | Cost-Effectiveness Acceptability Curve — probability of being cost-effective across WTP thresholds |
| **CAH** | Critical Access Hospital — rural hospital with ≤25 beds, 96-hr ALOS limit, cost-based Medicare |
| **DRG** | Diagnosis Related Group — Medicare payment classification by diagnosis/procedure |
| **ICER** | Incremental Cost-Effectiveness Ratio — ΔCost / ΔEffect |
| **NMB** | Net Monetary Benefit — λ × ΔEffect − ΔCost |
| **MAPE** | Mean Absolute Percentage Error — validation accuracy metric |
| **PSA** | Probabilistic Sensitivity Analysis — Monte Carlo over parameter uncertainty |
| **QALY** | Quality-Adjusted Life Year — utility-weighted life years |
| **REH** | Rural Emergency Hospital — no inpatient beds, monthly facility payment |
| **PPS** | Prospective Payment System — DRG-based Medicare payment |
| **VBC** | Value-Based Care — payment linked to quality and cost outcomes |
| **WTP** | Willingness-to-Pay — threshold for cost-effective interventions (commonly $50k–$150k/QALY) |
| **HCRIS** | Healthcare Cost Reporting Information System — CMS cost report database |
| **340B** | Federal drug discount program for eligible hospitals |
| **FTE** | Full-Time Equivalent — 2,080 hours/year |
| **LOS** | Length of Stay — inpatient days |
| **RVU** | Relative Value Unit — physician work measurement |
| **ACO** | Accountable Care Organization — value-based care entity |
