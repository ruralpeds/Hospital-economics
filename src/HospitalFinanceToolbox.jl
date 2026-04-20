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
# HEALTH ECONOMICS FRAMEWORKS (CORE IMPLEMENTATION)
# ═══════════════════════════════════════════════════════════════

include("health_economics/QALY.jl")
include("health_economics/ICER.jl")

# ═══════════════════════════════════════════════════════════════
# ADDITIONAL MODULES (Scaffolding for Future Implementation)
# ═══════════════════════════════════════════════════════════════
# The following modules are scaffolded and ready for implementation:
# - episode/CostModels.jl, OutcomeTracking.jl
# - health_economics/NMB.jl, Uncertainty.jl
# - patient_flow/PatientAgent.jl, ClinicalPathway.jl, FlowSimulation.jl
# - clinical_integration/PhysiologicalModel.jl, ClinicalEconomicCoupling.jl
# - optimization/ValueBasedOptimization.jl, ResourceAllocation.jl
# - payer_models/ValueBasedCare.jl, BudgetImpactModel.jl
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

# Utilities
export format_currency, format_percentage, format_ratio
export Payer, OutcomeStatus, ReadmissionStatus
export Medicare, Medicaid, Commercial, Uninsured, Tricare, VeteransAffairs
export Alive, Dead, Transferred, LongTermCare

# Additional modules will be available as development progresses
# See ROADMAP.md for planned features

end  # module HospitalFinanceToolbox
