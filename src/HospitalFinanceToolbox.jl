"""
    HospitalFinanceToolbox

A comprehensive Julia toolkit for patient-level healthcare economic evaluation,
cost-effectiveness analysis, and clinical-economic integrated modeling.

Extends hospital organization-level economics (via RuralHospitalSim.jl) with:
- Episode and encounter-level costing (DRG, daily-rate, activity-based)
- Health economics frameworks (QALY, ICER, cost-effectiveness)
- Clinical outcome integration (mortality, morbidity, readmission, quality)
- Patient flow simulation with automatic cost tracking
- Budget impact modeling for healthcare interventions
- Value-based care contract analysis
- Physiological model coupling (for PedNeoSim.jl-like integrations)

# Main Components

- **Episode Costing**: DRG-based, daily-rate, RVU-based, activity-based costing
- **Health Economics**: QALY calculations, ICER, NMB, cost-effectiveness analysis
- **Patient Flow**: Agents.jl-based simulation with integrated cost tracking
- **Clinical Integration**: Interface for physiological models with economic state
- **Outcome Tracking**: Mortality, morbidity, readmission, quality metrics
- **Optimization**: JuMP-based outcome maximization under budget constraints
- **Payer Models**: Risk-sharing contracts, bundled payments, capitation
- **Scenario Analysis**: Multi-scenario evaluation with sensitivity analysis
- **Visualization**: Cost-effectiveness planes, dashboards, publication figures

# Quick Start

```julia
using HospitalFinanceToolbox

# Define an episode of care
episode = Episode(
    episode_id = "EP001",
    patient_id = "PT001",
    primary_diagnosis = "I10",  # ICD-10
    drg_code = "291",           # AHRQ DRG
    los = 5,
    payer = :Medicare
)

# Calculate costs
cost_model = DRGCostModel(base_cost=8000.0)
cost = calculate_episode_cost(episode, cost_model)

# Track outcomes
outcomes = EpisodeOutcomes(
    survived = true,
    qaly_gained = 0.85,
    readmitted_30day = false
)

# Calculate cost-effectiveness
icer = calculate_icer(
    intervention_cost = cost,
    intervention_effect = outcomes.qaly_gained,
    control_cost = 7500.0,
    control_effect = 0.80
)
```

See examples/ for complete working examples including NICU economics, 
readmission prevention, and value-based care simulations.
"""
module HospitalFinanceToolbox

using Dates
using UUIDs
using Statistics
using Random
using Distributions
using DataFrames
using CSV
using JSON3
using JuMP
using HiGHS
using StatsBase
using Agents
using Plots
using StatsPlots

# ═══════════════════════════════════════════════════════════════
# CONSTANTS & UTILITIES
# ═══════════════════════════════════════════════════════════════

include("utils/constants.jl")
include("utils/types.jl")
# validation.jl is not included here as it requires hospital model types
# that are defined in RuralHospitalSim.jl, not HospitalFinanceToolbox.jl

# ═══════════════════════════════════════════════════════════════
# EPISODE COSTING
# ═══════════════════════════════════════════════════════════════

include("episode/Episode.jl")
# ═══════════════════════════════════════════════════════════════
# DATA INGESTION & VALIDATION (HIPAA-COMPLIANT)
# ═══════════════════════════════════════════════════════════════

include("data_ingestion/types.jl")
include("data_ingestion/validators.jl")
include("data_ingestion/deidentifiers.jl")
include("data_ingestion/audit_logger.jl")
include("data_ingestion/ingestion_api.jl")

# ═══════════════════════════════════════════════════════════════
# PATIENT COHORT BUILDING & ANALYTICS
# ═══════════════════════════════════════════════════════════════

include("patient_cohort/cohort_builder.jl")

# ═══════════════════════════════════════════════════════════════
# COST ANALYSIS ENGINE (Module 3: Cohort-Level Cost Analysis)
# ═══════════════════════════════════════════════════════════════

include("analytics/CostAnalysis.jl")

# ═══════════════════════════════════════════════════════════════
# ADVANCED ANALYTICS (Phase 4A: Machine Learning & Stratification)
# ═══════════════════════════════════════════════════════════════

include("analytics/AdvancedAnalytics.jl")

# ═══════════════════════════════════════════════════════════════
# HEALTH ECONOMICS FRAMEWORKS (CORE IMPLEMENTATION)
# ═══════════════════════════════════════════════════════════════

include("health_economics/QALY.jl")
include("health_economics/ICER.jl")

# ═══════════════════════════════════════════════════════════════
# PATIENT FLOW SIMULATION (Module 4: Clinical Pathways & Outcomes)
# ═══════════════════════════════════════════════════════════════

include("patient_flow/ClinicalPathway.jl")
include("patient_flow/PatientAgent.jl")
include("patient_flow/CohortSimulation.jl")

# ═══════════════════════════════════════════════════════════════
# VALUE-BASED CARE CONTRACTS (Module 5: Financial Impact Analysis)
# ═══════════════════════════════════════════════════════════════

include("payer_models/ValueBasedCare.jl")
include("payer_models/QualityMetrics.jl")
include("payer_models/FinancialImpact.jl")
include("payer_models/BudgetImpactModel.jl")

# ═══════════════════════════════════════════════════════════════
# COMPARATIVE EFFECTIVENESS ANALYSIS (Module 6)
# ═══════════════════════════════════════════════════════════════

include("comparative_effectiveness/CostEffectivenessAnalysis.jl")
include("comparative_effectiveness/QualYCalculator.jl")
include("comparative_effectiveness/SensitivityAnalysis.jl")
include("comparative_effectiveness/ThresholdAnalysis.jl")
include("comparative_effectiveness/ComparativeEffectiveness.jl")

# ═══════════════════════════════════════════════════════════════
# ADDITIONAL MODULES (Scaffolding for Future Implementation)
# ═══════════════════════════════════════════════════════════════
# The following modules are scaffolded and ready for implementation:
# - episode/CostModels.jl, OutcomeTracking.jl
# - health_economics/NMB.jl, Uncertainty.jl
# - patient_flow/FlowSimulation.jl (discrete-event simulation engine)
# - clinical_integration/PhysiologicalModel.jl, ClinicalEconomicCoupling.jl
# - optimization/ValueBasedOptimization.jl, ResourceAllocation.jl
# - visualization/CostEffectiveness.jl, Dashboards.jl
#
# See docs/ for implementation roadmap

# ═══════════════════════════════════════════════════════════════
# EXPORTS (Core Implemented Modules)
# ═══════════════════════════════════════════════════════════════

# Data Ingestion & Validation Types
export PatientEncounter, IngestionConfig, IngestionResult
export AuditLogEntry, ValidationResult, ValidationError, QualityReport
export AuditLogStore

# Data Ingestion & Validation Functions
export ingest_csv
export validate_icd10_code, validate_cpt_code, validate_patient_encounter, validate_encounters_batch
export generate_pseudonym, deidentify_encounter, validate_deidentification
export log_ingestion_event, audit_log_summary

# Patient Cohort Types
export PatientCohort, CohortStatistics, CohortDefinition
export CriterionType
export AgeCriterion, DiagnosisCriterion, ProcedureCriterion, CostCriterion
export LengthOfStayCriterion, PayerCriterion, DateRangeCriterion

# Patient Cohort Functions
export build_cohort, calculate_cohort_statistics

# Types
export Episode, EpisodeOutcomes, EpisodeSummary
export DRGCostModel, DailyRateCostModel, RVUCostModel, ActivityBasedCostModel
export CostEffectivenessResult

# Functions - Cost Accounting
export calculate_episode_cost, episode_cost_breakdown

# Functions - Health Economics
export calculate_qaly, qaly_from_utility, qaly_gain
export calculate_icer, calculate_nce, calculate_incremental_cost, calculate_incremental_effect
export cost_effectiveness_analysis, build_ceac, recommend_intervention
export SimpleUtility, EQ5DUtility, get_utility
export quality_adjusted_survival, disability_adjusted_life_years, health_adjusted_life_expectancy

# Cost Analysis Engine Types
export CohortCostSummary, BenchmarkResult, BudgetImpactModel, HighCostPatientAnalysis

# Cost Analysis Engine Functions
export calculate_cohort_total_cost, calculate_cohort_cost_summary
export inflate_cost, inflate_cohort_costs
export benchmark_cohort, calculate_budget_impact
export analyze_high_cost_patients
export format_cost_summary, format_benchmark_result, format_budget_impact

# Patient Flow Simulation (Module 4)
export PatientAgent
export ClinicalPathway
export CohortSimulationResult
export get_clinical_pathways, route_to_pathway, get_default_pathway
export initialize_patient_cost_tracking, accumulate_daily_cost!, add_procedure_cost!
export route_patient_to_service!, discharge_patient!, get_patient_summary, patient_to_episode
export simulate_patient_outcomes!, calculate_quality_score
export simulate_cohort, format_cohort_simulation_result

# Value-Based Care Contracts (Module 5)
export PayerContract
export FeeForServiceContract, CapitationContract, BundledPaymentContract
export SharedSavingsContract, QualityBasedPaymentContract
export contract_type_name, get_annual_revenue

export QualityMetrics
export calculate_quality_metrics, calculate_quality_adjustment
export get_quality_rating, compare_metrics, format_quality_metrics

export AnnualContractFinancials
export ThreeYearContractAnalysis
export format_contract_analysis, format_annual_financials, compare_contracts

export project_contract_financials, apply_risk_adjustment, calculate_quality_penalty

# Comparative Effectiveness Analysis (Module 6)
export CostEffectivenessResult, CostEffectivenessPlane, ThresholdAnalysis
export calculate_icer, calculate_net_monetary_benefit, classify_dominance
export analyze_cost_effectiveness, format_cost_effectiveness_result

export QALYCalculation, HealthState
export get_utility_weight, get_utility_by_diagnosis, calculate_qaly
export calculate_life_years, calculate_cohort_qalys, calculate_qalys_per_patient
export sensitivity_qaly_to_utility, sensitivity_qaly_to_mortality

export SensitivityParameter, OneWaySensitivityResult, TwoWaySensitivityResult
export ProbabilisticSensitivityResult
export conduct_one_way_sensitivity, tornado_analysis
export conduct_two_way_sensitivity
export conduct_probabilistic_sensitivity
export calculate_ceac_at_wtp, get_ceac_confidence_interval
export summarize_icer_distribution

export BreakEvenAnalysis, WTPThreshold, EffectivenessMilepost
export calculate_break_even_wtp, analyze_break_even
export evaluate_at_wtp_threshold, find_optimal_wtp
export analyze_effectiveness_trajectory
export calculate_ceac, find_ceac_crossover
export format_threshold_analysis

export ComparisonScenario, StrategyProfile
export compare_strategies, build_strategy_profiles
export format_comparison_summary, format_strategy_profiles

# Advanced Analytics (Phase 4A)
export ReadmissionRiskModel, AnomalyDetectionResult, RiskStratificationResult
export build_readmission_model, predict_readmission_risk
export build_anomaly_detector, detect_cost_anomalies
export stratify_patient_risk, generate_risk_report

# Utilities
export format_currency, format_percentage, format_ratio
export Payer, OutcomeStatus, ReadmissionStatus
export Medicare, Medicaid, Commercial, Uninsured, Tricare, VeteransAffairs
export Alive, Dead, Transferred, LongTermCare

# Additional modules will be available as development progresses
# See ROADMAP.md for planned features

end  # module HospitalFinanceToolbox
