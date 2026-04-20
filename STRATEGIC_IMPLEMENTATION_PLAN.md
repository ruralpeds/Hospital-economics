# Strategic Implementation Plan: Comprehensive Healthcare Economics Research Platform

**Status**: Gap Analysis Complete → Strategic Planning Phase
**Date**: April 15, 2026
**Target Completion**: v1.0 by October 2026 (6 months, 2-3 FTE)
**Scope**: Hospital-level AND state/national policy simulation

---

## Executive Summary

The HospitalFinanceToolbox.jl currently provides **35-40% complete** healthcare economics capabilities. This plan outlines a 12-24 month roadmap to build a **comprehensive research platform** that:

1. **Integrates patient flow with financial outcomes** (currently disconnected)
2. **Scales from single hospital to state/national populations**
3. **Simulates healthcare policy interventions** at federal, state, and hospital levels
4. **Optimizes resource allocation** under budget/capacity constraints
5. **Produces publication-ready visualizations and reports**

### Current Capability Snapshot
- ✅ Health economics metrics (QALY, ICER, NMB)
- ✅ Simulation engines (MC, SD, ABM, DES)
- ✅ Hospital financial models (RVU, break-even, ratios)
- ✅ Service line profitability (Episode.jl modules)
- ✅ Risk quantification (closure, REH conversion)
- ❌ **Cost-to-episode linkage** (episodes defined, costs orphaned)
- ❌ **Patient flow simulation** (types only, no behavior)
- ❌ **State/national policy framework** (not started)
- ❌ **Optimization solvers** (JuMP templates only)
- ❌ **Interactive dashboards** (stubs only)

---

## Phase Structure: 3 Phases + 2 Tiers

### Phase 1: Foundation & Integration (Months 1-2)
**Goal**: Connect episodes to costs; enable patient flow simulation
**Output**: v0.3.0 with end-to-end hospital financial simulation

### Phase 2: Scaling & Optimization (Months 3-4)
**Goal**: Population-level simulation; outcome optimization
**Output**: v0.4.0 with multi-hospital networks and state-level models

### Phase 3: Policy & Production (Months 5-6)
**Goal**: Policy intervention simulation; publication-ready outputs
**Output**: v1.0 with policy analysis and dashboards

### Tier A: Extended Hospital Capabilities (Months 7-12)
**Goal**: Depth in single-hospital analysis
**Output**: Advanced CFO capabilities

### Tier B: Advanced Features (Months 13-24)
**Goal**: Research publication pipeline; advanced optimization
**Output**: Production research platform

---

## PHASE 1: Foundation & Integration (Months 1-2)

### 1.1 Complete Cost Model Implementation (Week 1-2, Priority HIGH)

**Current State**: Episode types defined, cost calculations missing

**Missing Functions**:
```julia
# In src/episode/EpisodeCostModels.jl (NEW)
function calculate_episode_cost(ep::Episode, model::DRGCostModel)::Float64
function calculate_episode_cost(ep::Episode, model::RVUCostModel)::Float64
function calculate_episode_cost(ep::Episode, model::ActivityBasedCostModel)::Float64
```

**Deliverables**:
- [ ] DRG cost calculation (based on comorbidity adjustment, severity, length of stay)
- [ ] RVU cost calculation (specialty-based, procedure intensity, resource utilization)
- [ ] Activity-based costing (overhead driver allocation: bed-days, procedures, resources)
- [ ] Cost accumulation across service lines
- [ ] 50+ unit tests validating all cost models
- [ ] Integration with Episode.jl

**Data Requirements**:
- CMS DRG relative weights (2026)
- RVU schedules by specialty
- Labor cost by department
- Supply cost by service line
- Overhead cost drivers

**Example Implementation Scope**:
```julia
struct DRGCostModel
    base_costs::Dict{String, Float64}  # Per DRG
    labor_rates::Dict{String, Float64}  # Per FTE type
    comorbidity_adjusters::Dict{String, Float64}  # CC/MCC factors
    hospital_wage_index::Float64  # Geographic adjustment
end

function calculate_episode_cost(ep::Episode, model::DRGCostModel)::Float64
    base = model.base_costs[ep.primary_drg]
    cc_adjustment = 1.0
    for dx in ep.secondary_diagnoses
        cc_adjustment *= get(model.comorbidity_adjusters, dx, 1.0)
    end
    los_adjustment = 1.0 + (ep.length_of_stay - 3) * 0.05  # 5% per extra day
    return base * cc_adjustment * los_adjustment * model.hospital_wage_index
end
```

**Testing Strategy**:
- Validate against CMS cost reports
- Benchmark against 10 reference hospitals
- Sensitivity analysis: ±20% on key drivers
- Compare methods (DRG vs RVU vs ABC) on same cases

**Estimated Effort**: 80 development hours (1 developer, 2 weeks)

---

### 1.2 Patient Flow Integration with Cost Accumulation (Week 2-3, Priority HIGH)

**Current State**: PatientAgent.jl defined types, FlowSimulation.jl has stubs

**Missing Behavior**:
```julia
# In src/simulation/FlowSimulation.jl
function simulate_patient_flow!(sim::HospitalSimulation, num_days::Int)
function track_patient_cost_accumulation(patient::PatientAgent, model::DRGCostModel)
function route_patient_to_service(patient::PatientAgent, hospital::Hospital)
function discharge_patient_with_costs!(patient::PatientAgent)
```

**Deliverables**:
- [ ] Complete patient lifecycle (arrival → episodes → discharge)
- [ ] Cost accumulation during admission (daily costs, procedures, resources)
- [ ] Service line routing (ED → ward → OR → ICU patterns)
- [ ] Length of stay modeling (case-mix adjusted, comorbidity-sensitive)
- [ ] Real-time cost tracking per patient
- [ ] Integration with DES engine (queueing, resource constraints)
- [ ] 30+ unit tests, 3 integration tests

**Architecture**:
```julia
mutable struct PatientAgent
    id::String
    arrival_time::Float64
    admission_date::Date
    primary_diagnosis::String
    secondary_diagnoses::Vector{String}
    assigned_service_line::String
    location::String  # "waiting" | "ward" | "OR" | "ICU" | "discharged"
    length_of_stay::Int

    # Cost tracking
    cumulative_cost::Float64
    cost_by_day::Vector{Float64}
    resource_utilization::Dict{String, Float64}
end

mutable struct HospitalSimulation
    hospital::Hospital
    patients::Vector{PatientAgent}
    time_now::Float64
    cost_model::Union{DRGCostModel, RVUCostModel}
    cost_results::Dict{String, Float64}
end
```

**Simulation Flow**:
1. Patient arrives → assigned DRG/primary diagnosis
2. Patient routed to service line queue
3. Each day in hospital: accumulate costs (staff, supplies, overhead)
4. Procedures trigger additional costs
5. Discharge → final cost calculation
6. Cost attributed to service line + episode

**Testing Strategy**:
- 100-patient 30-day simulations
- Validate cost accumulation formulas
- Compare simulated costs vs. actual hospital data
- Stress test: 500+ concurrent patients

**Integration Points**:
- `Episode.jl` — patient maps to episode
- `ServiceLineTypes.jl` — track costs by service
- `ServiceLineCostAllocation.jl` — allocate overhead during simulation
- DES engine (via `Agents.jl`) — handle queues and resource constraints

**Estimated Effort**: 120 development hours (1.5 developers, 3 weeks)

---

### 1.3 Service Line Enhanced Analytics with Patient Cohorts (Week 3-4, Priority MEDIUM)

**Current State**: Service line analysis is static (aggregated annual data)

**New Capabilities**:
- [ ] Cohort-based profitability (age, sex, severity groups)
- [ ] Episode trajectory analysis (readmission, complications)
- [ ] Real-time cost tracking vs. actual
- [ ] Contribution margin by patient segment
- [ ] Quality-adjusted profitability (margin per QALY)

**New Module**: `src/episode/ServiceLinePatientCohorts.jl`

```julia
struct PatientCohort
    service_line_id::String
    cohort_name::String
    age_range::Tuple{Int, Int}
    severity_quintile::Int
    comorbidity_index::Float64

    patient_count::Int
    avg_revenue_per_patient::Float64
    avg_cost_per_patient::Float64
    readmission_rate::Float64
    qaly_per_patient::Float64
end

function analyze_service_line_by_cohort(sl::ServiceLine, patients::Vector{PatientAgent})::Dict{String, PatientCohort}
    # Group patients into cohorts
    # Calculate outcomes per cohort
    # Identify high-value, low-cost segments
end
```

**Estimated Effort**: 60 development hours (1 developer, 1.5 weeks)

---

### 1.4 Phase 1 Validation & Testing (End of Month 2)

**Integration Testing**:
- [ ] Full hospital simulation: 30 days, 1,000 patients, 8 service lines
- [ ] Cost validation: simulated vs. benchmark costs within ±5%
- [ ] Service line profitability: consistent with Phase 1 models
- [ ] Performance: <5 minutes for 30-day simulation

**Example Output**:
```
Hospital Simulation Results (30 days)
=====================================
Total Admissions: 1,047
Total Cost: $47.2M
  Labor: $28.1M (59.6%)
  Supplies: $12.3M (26.1%)
  Overhead: $6.8M (14.4%)

Service Line Profitability:
  Cardiology: $3.2M margin
  Orthopedics: $1.8M margin
  Emergency: -$0.9M loss
  Obstetrics: -$0.4M loss

Cost per Episode (mean ± SD):
  Cardiology: $28,400 ± $8,200
  Emergency: $3,800 ± $2,100
  Orthopedic Surgery: $31,200 ± $12,400
```

**Estimated Effort**: 40 development hours

---

## PHASE 2: Scaling & Optimization (Months 3-4)

### 2.1 Population-Level Hospital Network Simulation (Week 5-8, Priority HIGH)

**Goal**: Scale from single hospital to 5-50 hospitals + patient referral patterns

**New Module**: `src/network/HospitalNetworkSimulation.jl`

**Deliverables**:
- [ ] Multi-hospital simulation with shared patient populations
- [ ] Patient routing across hospitals (referral networks)
- [ ] Inter-hospital cost tracking and attribution
- [ ] Regional financial outcome aggregation
- [ ] Capacity sharing and patient overflow handling
- [ ] Competitive dynamics (patient choice modeling)

**Architecture**:
```julia
struct HospitalNetwork
    hospitals::Dict{String, Hospital}
    service_availability::Dict{String, Set{String}}  # Which hospitals offer which services
    referral_probabilities::Matrix{Float64}  # Hospital-to-hospital routes
    patient_choice_model::String  # "distance" | "quality" | "cost" | "hybrid"
    shared_service_lines::Dict{String, Vector{String}}  # Specialized centers
end

function simulate_network!(network::HospitalNetwork, population::Population, days::Int)
    # Generate patients in geographic region
    # Route to hospital based on availability, distance, quality
    # Track costs across hospital system
    # Calculate regional outcomes
end
```

**Data Requirements**:
- Hospital geographic coordinates (for distance-based routing)
- Service line capabilities per hospital
- Referral patterns (historical data)
- Patient preference parameters
- Capacity constraints (beds, OR, ICU)

**Key Use Cases**:
1. Rural hospital closure impact on regional care costs
2. Specialized center consolidation (e.g., trauma, cardiac)
3. Integrated delivery network performance
4. Patient travel burden vs. cost-effectiveness

**Estimated Effort**: 160 development hours (2 developers, 4 weeks)

---

### 2.2 Outcome Optimization Under Constraints (Week 6-9, Priority MEDIUM)

**Goal**: Maximize patient outcomes subject to budget/capacity limits

**New Module**: `src/optimization/ValueBasedOptimization.jl`

**Optimization Problems**:
1. **Service Line Expansion**: Which services maximize profit + quality?
2. **Resource Allocation**: How to allocate $1M budget across departments?
3. **Network Optimization**: Which hospitals should offer which services?
4. **Staffing**: Optimal nurse-to-patient ratios by unit?

**Implementation Using JuMP**:
```julia
using JuMP, HiGHS

function optimize_service_allocation(hospital::Hospital, budget::Float64)::Dict{String, Float64}
    model = Model(HiGHS.Optimizer)

    # Decision: volume for each service line
    @variable(model, volume[sl in hospital.service_lines] >= 0)

    # Objective: maximize total margin
    @objective(model, Max, sum(
        margin_per_case[sl] * volume[sl] for sl in hospital.service_lines
    ))

    # Constraints
    @constraint(model, sum(
        cost_per_case[sl] * volume[sl] for sl in hospital.service_lines
    ) <= budget)

    @constraint(model, [sl in hospital.service_lines],
        volume[sl] <= capacity[sl])

    optimize!(model)

    return Dict(sl => value(volume[sl]) for sl in hospital.service_lines)
end
```

**Advanced Variants**:
- Multi-objective: Margin vs. Access vs. Quality
- Probabilistic: Handle uncertainty in cost/demand
- Network-level: Coordinate across hospitals
- Dynamic: Respond to patient flow in real-time

**Testing**:
- [ ] 10+ benchmark optimization problems
- [ ] Validate against known optimal solutions
- [ ] Performance: solve <10s for 20-hospital network
- [ ] Sensitivity: ±10% on constraints

**Estimated Effort**: 100 development hours

---

### 2.3 State-Level Population Health Policy Simulation Framework (Week 7-10, Priority HIGH)

**Goal**: Enable simulation of state healthcare policies (Medicaid expansion, rate-setting, etc.)

**New Module**: `src/policy/StateLevelPolicySimulation.jl`

**Policy Interventions Supported**:
```julia
abstract type PolicyIntervention end

struct MedicaidExpansion <: PolicyIntervention
    coverage_increase::Float64  # e.g., 0.15 = 15% more population
    payment_rate_multiplier::Float64  # 1.0 = current rates
    eligibility_age::Int  # e.g., 65 = everyone under 65
end

struct HospitalRateSetting <: PolicyIntervention
    target_margin::Float64  # e.g., 0.03 = 3%
    affected_payers::Set{String}  # Which payers' rates are regulated
    adjustment_period::Int  # Years to phase in
end

struct RuralHospitalSupport <: PolicyIntervention
    supplemental_payment_per_bed::Float64
    criteria::Function  # Which hospitals qualify
    funding_source::String  # State, federal, other
end

struct PayerMixShift <: PolicyIntervention
    from_payer::String  # "Medicare"
    to_payer::String  # "Medicaid"
    volume_shift::Float64  # 0.1 = 10% of Medicare volume → Medicaid
end
```

**Simulation Architecture**:
```julia
struct StateHealthcareSystem
    hospitals::Vector{Hospital}
    state_population::Int
    payer_mix::Dict{String, Float64}  # % Medicare, Medicaid, Commercial, Uninsured
    baseline_utilization::Dict{String, Float64}  # Admission rates by service
    baseline_outcomes::Dict{String, Float64}  # Mortality, readmission rates
end

function simulate_policy_intervention!(
    state::StateHealthcareSystem,
    policy::PolicyIntervention,
    years::Int
)::PolicyOutcomes
    # Run baseline scenario (years 0-1)
    # Apply policy (starting year 2)
    # Track: margins, access, quality, patient outcomes
    # Return: impact analysis
end
```

**Policy Impact Analysis**:
```julia
struct PolicyOutcomes
    hospital_margins::Dict{String, Vector{Float64}}  # By year
    patient_access::Dict{String, Vector{Float64}}  # % with coverage
    quality_metrics::Dict{String, Vector{Float64}}  # Mortality, readmission
    financial_impact::Dict{String, Float64}  # State/federal cost
    equity_analysis::Dict{String, Float64}  # Disparities by race/income
    provider_closures::Int  # Hospitals unable to survive
end
```

**Key Policies to Model**:
1. **Medicaid Expansion** (like ACA in 2014)
   - Impact on uninsured volume
   - Payment rate change (Medicaid < Medicare)
   - Rural hospital survival

2. **All-Payer Payment Reform** (like Maryland)
   - Global budgets by hospital
   - Quality incentives
   - Rate regulation across all payers

3. **Price Transparency Rules**
   - Impact on cost-conscious utilization
   - Profit margin changes
   - Equity implications

4. **Rural Hospital Closure Prevention**
   - Supplemental payments
   - Service line consolidation
   - Network affiliation requirements

**Data Requirements for State Model**:
- Population by age, income, insurance status
- Disease prevalence (diabetes, heart disease, etc.)
- Hospital capacity and capabilities (50-200 hospitals typical for large state)
- Payer mix (% Medicare, Medicaid, Commercial, Uninsured)
- Baseline utilization rates
- Baseline quality metrics (mortality, readmission)

**Validation**:
- Compare simulated outcomes vs. actual state transitions
- Example: Model 2014 Medicaid Expansion in Kentucky, compare to actual results
- Sensitivity on key assumptions: elasticity of demand, hospital response behavior

**Estimated Effort**: 200 development hours (2 developers, 5 weeks)

---

### 2.4 Phase 2 Validation (End of Month 4)

**Multi-Hospital Network Validation**:
- [ ] 10-hospital network simulation: 90 days, realistic patient flow
- [ ] Cost attribution accuracy: ±5% vs. benchmark
- [ ] Referral routing: realistic patterns vs. actual data
- [ ] Performance: <30 seconds for 10 hospitals × 90 days

**Optimization Validation**:
- [ ] 10 test problems with known optimal solutions
- [ ] Algorithm convergence: <10 seconds
- [ ] Solution quality: within 1% of theoretical optimum
- [ ] Robustness: maintain solution under ±10% constraint perturbation

**Policy Simulation Validation**:
- [ ] Model 2014 Medicaid Expansion in Kentucky
- [ ] Compare outcomes to actual CMS, state reports
- [ ] Validate mechanism: coverage → utilization → costs
- [ ] Sensitivity analysis on key elasticities

**Estimated Effort**: 60 development hours

---

## PHASE 3: Policy & Production (Months 5-6)

### 3.1 Multi-Level Policy Simulation: Federal + State + Hospital (Week 11-15, Priority MEDIUM)

**Goal**: Couple federal, state, and hospital-level policies

**New Module**: `src/policy/MultiLevelPolicyCoupling.jl`

**Policy Coupling Example**:
```julia
struct MultiLevelPolicyScenario
    federal_policies::Vector{FederalPolicy}  # Medicare rate changes, mandates
    state_policies::Vector{StatePolicy}  # Medicaid, insurance mandates
    hospital_strategies::Dict{String, HospitalStrategy}  # Response behaviors

    # Coupling parameters
    hospital_demand_elasticity::Float64  # Responsiveness to price
    insurance_demand_elasticity::Float64  # Responsiveness to coverage
    provider_exit_threshold::Float64  # Margin below which hospitals close
end

# Examples of federal policies
struct MedicarePaymentReform <: FederalPolicy
    drg_weight_changes::Dict{String, Float64}  # Increase/decrease by DRG
    quality_incentive_pool::Float64  # % of Medicare payment withheld for quality
    bundled_payment_rate::Float64  # Shift from FFS to bundled for select conditions
end

struct ProposedMLLRate <: FederalPolicy  # Medicare Laboratory Locality Rates
    affects_services::Set{String}  # Lab, pathology, imaging
    national_rate::Float64  # Applies same rate nationwide
    implementation_year::Int
end
```

**Scenarios to Model**:
1. **ACA Repeal & Replace Scenarios**
   - Medicaid expansion repealed
   - Individual mandate eliminated
   - Modified Community Rating rules
   - Impact on rural hospitals

2. **Medicare Advantage Transformation**
   - Shift to risk-adjusted capitation
   - Impact on traditional Medicare
   - Rural vs. urban implications

3. **Consolidated Delivery Systems**
   - Vertical integration requirements
   - Impact on competition
   - Equity and access concerns

4. **Price Regulation Models**
   - German/Dutch-style negotiations
   - Australian-style ACHS funding
   - All-Payer Model expansion (Maryland style)

**Estimated Effort**: 120 development hours

---

### 3.2 Publication-Ready Visualization & Reporting (Week 13-18, Priority HIGH)

**Goal**: Generate figures suitable for peer-reviewed healthcare economics journals

**New Module**: `src/visualization/PolicyAnalysisReporting.jl`

**Standard Healthcare Economics Figures**:

1. **Cost-Effectiveness Plane with CEAC Curve**
```julia
function plot_ceac_curves(scenarios::Vector{PolicyScenario}, wtp_range::Vector{Float64})
    # CEAC = Probability (intervention is cost-effective at WTP threshold)
    # X-axis: Willingness-to-pay ($/QALY)
    # Y-axis: Probability cost-effective
    # Multiple curves: one per policy scenario
end
```

2. **Net Benefit Curves (Alternative to CEAC)**
```julia
function plot_net_benefit_curves(scenarios::Vector{PolicyScenario}, wtp_range::Vector{Float64})
    # Net Benefit = Benefit (QALYs × WTP) - Cost
    # Shows which scenario is best at each WTP threshold
end
```

3. **Budget Impact Model Projections**
```julia
function plot_budget_impact(
    scenarios::Vector{PolicyScenario},
    years::Int,
    budget_baseline::Float64
)
    # Y-axis: Incremental budget impact ($ millions)
    # X-axis: Year
    # Shows cumulative cost/savings over time
end
```

4. **Equity Analysis: Disparities by Race/Income**
```julia
function plot_equity_analysis(outcomes::PolicyOutcomes)
    # Show health and financial outcomes by demographic group
    # Identify policies that increase/decrease equity
end
```

5. **Sensitivity Analysis Tornado Plot**
```julia
function plot_sensitivity_tornado(
    base_case::PolicyOutcome,
    sensitivity_results::Dict{String, Tuple{Float64, Float64}}
)
    # Shows which parameters have largest impact on outcomes
    # Base case value ± one-way sensitivity range
end
```

6. **Network Visualization**
```julia
function plot_hospital_network(network::HospitalNetwork)
    # Hospitals as nodes, referral flows as edges
    # Node color: margin/profitability
    # Edge thickness: volume
    # Shows network structure and financial health
end
```

**Dashboard Components** (via Makie.jl or interactive HTML):
- [ ] Policy scenario comparison (side-by-side outcomes)
- [ ] Time series: financial impact over 5-10 years
- [ ] Geographic: state map with hospital closure risk
- [ ] Drill-down: click hospital → service line → patient cohort details

**Output Formats**:
- [ ] Publication-ready PNG/PDF (high resolution, color-blind safe)
- [ ] Interactive HTML (Pluto notebooks, Makie WebGL)
- [ ] Summary tables for supplemental appendices
- [ ] Data downloads (CSV for replication)

**Estimated Effort**: 100 development hours

---

### 3.3 Validation on Real-World Policy Cases (Week 15-20, Priority HIGH)

**Goal**: Validate model against actual policy implementations

**Case Studies**:
1. **Kentucky Medicaid Expansion (2014)**
   - Actual: 400,000+ new Medicaid enrollees
   - Simulated: Same population shock
   - Validate: Hospital revenue changes, margins, closures
   - Data source: Kentucky Hospital Association reports, CMS

2. **Maryland All-Payer Model (2014-2018)**
   - Actual: All payers shift toward global budgets + quality incentives
   - Simulated: Same policy combination
   - Validate: Total cost, margins, quality improvements
   - Data source: Maryland Health Care Commission reports

3. **Rural Hospital Closures (2010-2023)**
   - Actual: ~100 rural hospital closures nationwide
   - Simulated: Model which hospital closures with baseline policies
   - Validate: Margin thresholds, service line profitability
   - Data source: American Hospital Association, Sheps Center

4. **COVID-19 Impact (2020-2021)**
   - Actual: Rural hospital margins, service mix shifts
   - Simulated: Volume shocks, cost structure changes
   - Validate: Which hospitals survived, which closed
   - Data source: Healthcare Cost & Utilization Project (HCUP)

**Validation Metrics**:
- [ ] Mean absolute percentage error (MAPE) < 10% on key outcomes
- [ ] Directional accuracy: ≥90% on up/down predictions
- [ ] Heterogeneity: accurately predict which hospitals affected most

**Estimated Effort**: 80 development hours

---

### 3.4 Phase 3 Validation & v1.0 Release (End of Month 6)

**Readiness Criteria**:
- [ ] All 3 phases complete with >90% test coverage
- [ ] Documentation: user guide + API docs + 5+ case studies
- [ ] Performance: single-state simulation <5 minutes
- [ ] Validation: MAPE <10% on 4 real-world case studies
- [ ] Reproducibility: all results published with code/data

**Example v1.0 Release Announcement**:
```
HospitalFinanceToolbox.jl v1.0: Comprehensive Healthcare Economics Research Platform

New Capabilities:
✅ Hospital financial simulation with patient-level cost tracking
✅ Multi-hospital network modeling with referral flows
✅ State-level policy simulation framework
✅ Outcome optimization under budget/capacity constraints
✅ 50+ publication-ready visualizations
✅ Validated on 4 real-world policy cases

Performance:
• Single hospital (250 beds): 30-day simulation in <1 second
• State network (100 hospitals): 1-year simulation in <5 minutes
• Policy sensitivity analysis: 100 scenarios in <10 minutes

Documentation:
• User Guide (100 pages)
• API Reference (50 pages)
• Case Studies (5 full examples)
• Validation Report (30 pages)

Estimated Time to Impact:
• Hospital CFO analysis: 2-4 hours
• State policy analysis: 1-2 weeks
• Research publication: 8-12 weeks
```

**Estimated Effort**: 60 development hours (integration, docs, testing)

---

## TIER A: Extended Hospital Capabilities (Months 7-12)

### A.1 Advanced Patient Segmentation & Risk Stratification

**New Module**: `src/analytics/PatientRiskModels.jl`

**Deliverables**:
- [ ] Readmission risk prediction (machine learning)
- [ ] Complication risk by procedure type
- [ ] High-cost patient identification
- [ ] Length of stay prediction
- [ ] Patient lifetime value calculation

**Use Cases**:
- Target interventions to high-risk, high-cost patients
- Improve case mix coding accuracy
- Identify hidden safety risks
- Predict patient profitability

**Estimated Effort**: 120 development hours

---

### A.2 Quality-Adjusted Profitability Analysis

**New Module**: `src/episode/QualityAdjustedProfitability.jl`

**Metrics**:
- Profit per QALY
- Profit per life-year saved
- Risk-adjusted profitability (adjust margins for unobserved heterogeneity)

**Use Cases**:
- Identify services that are "high-profit, high-quality" vs. "high-profit, low-quality"
- Ethical service line decisions
- Align hospital mission with finance

**Estimated Effort**: 80 development hours

---

### A.3 Departmental Operational Optimization

**New Module**: `src/optimization/DepartmentalOptimization.jl`

**Problems**:
- OR scheduling: maximize utilization, minimize wait times
- Staffing: nurse-to-patient ratios by shift
- Inventory: just-in-time vs. stockpiling
- Bed management: allocation across units

**Estimated Effort**: 160 development hours

---

### A.4 Telemedicine & Hybrid Delivery Models

**New Module**: `src/delivery/TelemedicineEconomics.jl`

**Model**:
- Telemedicine costs vs. in-person
- Patient demand shift
- Quality/access implications
- Profitability under different reimbursement

**Estimated Effort**: 100 development hours

---

## TIER B: Advanced Research Features (Months 13-24)

### B.1 Machine Learning for Cost Prediction & Anomaly Detection

- [ ] Cost forecasting (ARIMA, Prophet, neural networks)
- [ ] Anomaly detection in billing (fraud, coding errors)
- [ ] Readmission prediction with SHAP interpretability
- [ ] Treatment outcome modeling

**Estimated Effort**: 200 development hours

---

### B.2 Causal Inference Framework

**Goal**: Move beyond correlation → causal effects of interventions

- [ ] Difference-in-differences analysis (state policy evaluation)
- [ ] Synthetic control methods (compare to similar non-adopting states)
- [ ] Instrumental variables (address endogeneity)
- [ ] Regression discontinuity (natural experiments at policy thresholds)

**Estimated Effort**: 160 development hours

---

### B.3 Agent-Based Model for Market Dynamics

**Current**: ABM available but not applied to healthcare markets

**New**: Model hospital competition, patient choice, provider consolidation

- [ ] Patient choice under different information regimes
- [ ] Hospital competition on price vs. quality
- [ ] Vertical integration incentives
- [ ] Mergers & acquisitions impact

**Estimated Effort**: 240 development hours

---

### B.4 System Dynamics for Chronic Disease Prevention

**Goal**: Long-term population health planning

- [ ] Disease prevalence modeling (diabetes, obesity, hypertension)
- [ ] Prevention intervention effects
- [ ] Healthcare cost trajectories
- [ ] ROI on population health programs

**Estimated Effort**: 180 development hours

---

## Implementation Timeline: Gantt View

```
PHASE 1 (Months 1-2): Foundation & Integration
├── M1W1-2: Cost Models                          ████████░░░░░░░░░░░░ 80 hrs
├── M1W2-3: Patient Flow Integration             ██████████████░░░░░░░ 120 hrs
├── M2W3-4: Cohort Analytics                     ████████░░░░░░░░░░░░ 60 hrs
└── M2W4  : Validation & Testing                 ███████░░░░░░░░░░░░░░ 40 hrs
    Subtotal: 300 hrs (1.5 developers, 8 weeks)

PHASE 2 (Months 3-4): Scaling & Optimization
├── M3W5-8: Network Simulation                   ██████████████████░░░ 160 hrs
├── M3W6-9: Optimization Solvers                 ████████████░░░░░░░░░ 100 hrs
├── M4W7-10: State Policy Framework              ██████████████████░░░ 200 hrs
└── M4W10  : Validation & Testing                ███████░░░░░░░░░░░░░░ 60 hrs
    Subtotal: 520 hrs (2.5 developers, 8 weeks)

PHASE 3 (Months 5-6): Policy & Production
├── M5W11-15: Multi-Level Coupling               ███████████░░░░░░░░░░ 120 hrs
├── M5W13-18: Visualizations & Reporting         █████████████░░░░░░░░ 100 hrs
├── M6W15-20: Real-World Validation              ██████████░░░░░░░░░░░ 80 hrs
└── M6W20   : Docs & v1.0 Release                ███████░░░░░░░░░░░░░░ 60 hrs
    Subtotal: 360 hrs (2 developers, 8 weeks)

TIER A (Months 7-12): Hospital Depth
├── Advanced Segmentation                        ████████████░░░░░░░░░ 120 hrs
├── Quality-Adjusted Profitability               █████████░░░░░░░░░░░░ 80 hrs
├── Departmental Optimization                    ██████████████████░░░ 160 hrs
└── Telemedicine Economics                       ████████████░░░░░░░░░ 100 hrs
    Subtotal: 460 hrs (1 developer, 24 weeks)

TIER B (Months 13-24): Research Pipeline
├── ML Cost Prediction                           ██████████████████░░░ 200 hrs
├── Causal Inference                             ████████████████░░░░░ 160 hrs
├── ABM Market Dynamics                          ███████████████████░░ 240 hrs
└── System Dynamics                              ██████████████████░░░ 180 hrs
    Subtotal: 780 hrs (1.5 developers, 24 weeks)

Total: 2,120 hours (4-6 developers, 52 weeks)
Expected: 6-8 months with 2-3 FTE
```

---

## Resource & Staffing Requirements

### Core Team (Months 1-6, v1.0 Release)
- **Lead Developer** (Julia ecosystem expert): 1.0 FTE
  - Responsible: Phase 1-2, architecture decisions, code quality

- **Healthcare Domain Expert**: 0.5 FTE
  - Responsible: Data requirements, validation, case studies

- **Data Engineer**: 0.5 FTE
  - Responsible: Data pipelines, state-level data integration

- **QA/Testing**: 0.5 FTE
  - Responsible: Test coverage, validation against real data

**Subtotal**: 2.5 FTE (or 1 person for 12 months)

### Extended Team (Months 7-12, Tiers A)
- Add **Data Scientist**: 1.0 FTE (ML, risk models, advanced analytics)

### Research Team (Months 13-24, Tier B)
- Add **Economist**: 1.0 FTE (causal inference, policy analysis)
- Add **Visualization Specialist**: 0.5 FTE (dashboards, publication graphics)

---

## Data Requirements & Sources

### Hospital-Level Data
| Data Element | Source | Frequency | Cost |
|---|---|---|---|
| Financial (revenue, costs by service) | Hospital accounting systems | Annual | Internal |
| Patient claims (episodes, DRGs) | CMS, state claims data | Annual | $0 (academic) - $50K |
| Quality metrics (mortality, readmission) | CMS Hospital Compare, HCUP | Annual | Free |
| Staffing (FTE by department) | Bureau of Labor Statistics | Annual | Free |
| Capacity (beds, OR, ICU) | AHA Annual Survey | Annual | Free ($500/year) |

### State-Level Data
| Data Element | Source | Frequency | Cost |
|---|---|---|---|
| Population demographics | US Census | Annual | Free |
| Insurance coverage rates | Current Population Survey | Annual | Free |
| Hospital closures/openings | Sheps Center database | Real-time | Free |
| Medicaid policy | State Medicaid agencies | As updated | Free |
| Hospital finances | State reporting systems | Annual | $0-$5K |

### National/Federal Data
| Data Element | Source | Frequency | Cost |
|---|---|---|---|
| Medicare rates (DRG weights, RVUs) | CMS | Annual | Free |
| Benchmark costs | HCUP, Healthcare Cost Institute | Annual | Free |
| Disease prevalence | National Health Interview Survey | Annual | Free |
| Quality of life (utility weights) | HTA literature | One-time | Free (published) |

**Total Annual Data Cost**: $5K-$15K for academic research

---

## Success Metrics & Evaluation

### Technical Success
- [ ] >90% code test coverage
- [ ] Performance: single-state simulation <5 minutes
- [ ] Reproducibility: all results publishable
- [ ] Documentation: >95% API coverage

### Validation Success
- [ ] MAPE <10% on 4 real-world policy cases
- [ ] Directional accuracy ≥90%
- [ ] Heterogeneous effects correctly predicted
- [ ] Plausibility check: results align with domain expertise

### Impact Success
- [ ] 2+ peer-reviewed publications in top healthcare economics journals
- [ ] 5+ case studies adopted by state/hospital partners
- [ ] GitHub stars: >500 (indicates research community interest)
- [ ] Downloads/citations: track growth over time

### Adoption Success
- [ ] 3-5 state Medicaid agencies run simulations
- [ ] 10+ rural hospitals use for financial planning
- [ ] Used in 2+ graduate courses (teaching impact)
- [ ] Community contributions: 20+ external contributors

---

## Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Data availability (state claims) | Medium | High | Start with public CMS data, add state partners incrementally |
| Model validation (real data mismatch) | Medium | High | Continuous validation against actual hospital changes; sensitivity analysis |
| Team turnover | Low-Med | High | Documentation-driven, modular architecture, knowledge transfer |
| Scope creep | High | Medium | Strict prioritization; defer Tier B features; feature flags for experimental code |
| Julia ecosystem churn | Low | Low | Target LTS versions; test compatibility with latest Julia release quarterly |
| Policy changes during development | Med | Low | Modular policy framework; easy to add new policy types |

---

## Budget Estimate

### Development (Months 1-24)
- **Salaries** (2.5 FTE @ $120K avg): $2,400,000
- **Infrastructure** (AWS, data): $150,000
- **Data access** (state claims, benchmarks): $100,000
- **Travel** (validation partnerships): $30,000
- **Total**: **$2.68M**

### Phased Approach (Get to v1.0 faster)
- **Phase 1-3 only** (Months 1-6, v1.0): $1.2M
- **Add Tier A** (Months 7-12): +$550K
- **Add Tier B** (Months 13-24): +$780K

### Academic Route (Lower cost)
- Grant funding: NIH R01 ($250K/year × 3 years = $750K)
- Graduate students (4 PhD students): $600K over 3 years
- University infrastructure (compute, data): $100K
- **Total**: **$1.45M** (0.5 institutional matches + grant)

---

## Next Steps (Immediately Upon Approval)

### Week 1 (Before Starting Phase 1)
- [ ] Finalize data sources (CMS data access, state partnerships)
- [ ] Set up development infrastructure (CI/CD, testing framework)
- [ ] Create detailed API specifications for Phase 1 modules
- [ ] Establish validation framework and baseline benchmarks

### Week 2-3 (Start Phase 1 Development)
- [ ] Complete Cost Model Implementation (1.1)
- [ ] Begin Patient Flow Integration (1.2)
- [ ] Set up test infrastructure

### Ongoing
- [ ] Weekly team syncs (Tuesday 2pm)
- [ ] Bi-weekly progress reviews with stakeholders
- [ ] Monthly publication of progress reports
- [ ] GitHub milestone tracking

---

## Conclusion

This strategic plan transforms HospitalFinanceToolbox.jl from a **hospital financial analysis tool** into a **comprehensive healthcare economics research platform** capable of:

1. **Simulating realistic hospital operations** (patient flow + costs)
2. **Analyzing multi-hospital networks** (referral flows, consolidation)
3. **Evaluating state healthcare policies** (Medicaid, rate-setting, closures)
4. **Optimizing resource allocation** (budgets, staffing, services)
5. **Producing publication-ready research** (peer-reviewed journals)

**Timeline**: 6 months to v1.0 (minimum viable research platform)
**Effort**: 2-3 FTE developers
**Budget**: $1.2M-$2.7M depending on scope
**Impact**: Enable rural hospital CFOs and state policymakers to make evidence-based decisions using rigorous economic simulation

---

## Document History

**Author**: Claude Code (AI)
**Date**: April 15, 2026
**Status**: Strategic Plan (Ready for approval)
**Next Review**: Upon completion of Phase 1

