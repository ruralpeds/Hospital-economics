"""
    RuralHospitalSim

A comprehensive simulation and projection tool for rural hospital economics,
with focus on Critical Access Hospitals (CAHs) and Rural Emergency Hospitals (REHs).

Provides deterministic financial projections, Monte Carlo simulation,
agent-based modeling, system dynamics, and mathematical optimization
for rural hospital strategic decision-making.

# Main Components
- **Type System**: Complete domain model for hospitals, financials, staffing, payer mix
- **Reimbursement Engine**: CMS Form 2552-10 cost report, Medicare/Medicaid/Commercial
- **Simulation Engines**: Deterministic, Monte Carlo, Agent-Based, System Dynamics, Optimization
- **Analysis**: Closure risk prediction, REH conversion analysis, sensitivity, benchmarking
- **Data**: HCRIS parser, import/export utilities
"""
module RuralHospitalSim

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
using DifferentialEquations
using StatsBase

# ═══════════════════════════════════════════════════════════════
# TYPE SYSTEM (must be loaded first, in dependency order)
# ═══════════════════════════════════════════════════════════════

include("types/abstract.jl")
include("types/service_lines.jl")
include("types/staffing.jl")
include("types/payer_mix.jl")
include("types/financial.jl")
include("types/hospital.jl")
include("types/scenarios.jl")
include("types/results.jl")

# ═══════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════

include("utils/constants.jl")
using .Constants
include("utils/validation.jl")
include("utils/formatting.jl")

# ═══════════════════════════════════════════════════════════════
# REIMBURSEMENT ENGINE
# ═══════════════════════════════════════════════════════════════

include("reimbursement/cost_report.jl")
include("reimbursement/medicare.jl")
include("reimbursement/medicaid.jl")
include("reimbursement/commercial.jl")
include("reimbursement/uncompensated.jl")
include("reimbursement/adjustments.jl")

# ═══════════════════════════════════════════════════════════════
# SIMULATION ENGINES
# ═══════════════════════════════════════════════════════════════

include("engines/deterministic.jl")
include("engines/monte_carlo.jl")
include("engines/agent_based.jl")
include("engines/system_dynamics.jl")
include("engines/optimization.jl")

# ═══════════════════════════════════════════════════════════════
# ANALYSIS MODULES
# ═══════════════════════════════════════════════════════════════

include("analysis/closure_risk.jl")
include("analysis/reh_conversion.jl")
include("analysis/sensitivity.jl")
include("analysis/benchmarking.jl")

# ═══════════════════════════════════════════════════════════════
# DATA IMPORT/EXPORT
# ═══════════════════════════════════════════════════════════════

include("data/hcris_parser.jl")
include("data/import_utils.jl")
include("data/export_utils.jl")

# ═══════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════

# Abstract types
export AbstractEntity, AbstractHospital, AbstractRuralHospital, AbstractUrbanHospital
export AbstractPaymentDesignation, CostBasedPayment, ProspectivePayment, REHPayment, SoleCommunityPayment
export AbstractSimulationParams, AbstractSimulationResult
export AbstractFinancialModel, AbstractReimbursementModel, AbstractCostModel

# Hospital types
export GeoLocation, ServiceArea
export CriticalAccessHospital, RuralEmergencyHospital, ProspectivePaymentHospital
export HealthSystem

# Financial types
export AnnualFinancials, CostReport, CostCenter, AllocationBasis
export CapitalAsset, CapitalPlan, CapitalProject
export MedicareReimbursement

# Staffing types
export StaffPosition, StaffingModel
export total_fte, total_salary_expense, total_compensation
export permanent_fte, travel_fte, travel_premium_cost

# Payer types
export PayerContract, PayerMix

# Service line types
export Department, ServiceLine

# Scenario types
export PolicyScenario, ConversionParams, StaffingConstraints, PortfolioParams

# Result types
export MonteCarloResult, MonteCarloSummary
export SystemDynamicsResult, StaffingOptimizationResult, PortfolioOptimizationResult
export ClosureRiskAssessment, REHConversionAnalysis

# Reimbursement functions
export step_down_allocation, calculate_medicare_cost_share
export calculate_medicare_reimbursement
export calculate_medicaid_reimbursement
export calculate_commercial_reimbursement
export calculate_uncompensated_care
export apply_wage_index, apply_sequestration, apply_bad_debt_adjustment
export default_cah_cost_centers, default_step_down_order

# Simulation engine functions
export DeterministicParams, project_financials, project_single_year
export MonteCarloParams, DistributionalParameter, run_monte_carlo
export probability_of_loss, value_at_risk
export ABMParams, initialize_abm, run_abm
export SystemDynamicsParams, run_system_dynamics, hospital_dynamics!
export optimize_staffing, optimize_service_portfolio

# Analysis functions
export MarketData, assess_closure_risk, estimate_distress_timeline
export analyze_reh_conversion, default_cah_assumptions, default_reh_assumptions
export SensitivityResult, run_sensitivity_analysis
export BenchmarkData, default_cah_benchmarks, compare_to_benchmarks

# Data functions
export parse_hcris_cost_report
export import_hospital_from_csv, import_hospital_from_json
export export_results_to_csv, export_results_to_json

# Utility functions
export format_currency, format_percentage, format_ratio
export validate_hospital, validate_payer_mix, validate_cost_report

# Constants (from Constants submodule)
export CAH_COST_REIMBURSEMENT_RATE, REH_MONTHLY_FACILITY_PAYMENT
export REH_OPPS_ADDON, SEQUESTRATION_RATE
export BAD_DEBT_REIMBURSEMENT_RATE

end # module RuralHospitalSim
