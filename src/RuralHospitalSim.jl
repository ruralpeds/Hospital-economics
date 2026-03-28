"""
    RuralHospitalSim

A comprehensive simulation and projection tool for rural hospital economics,
with focus on Critical Access Hospitals (CAHs) and Rural Emergency Hospitals (REHs).

Provides deterministic financial projections, Monte Carlo simulation,
agent-based modeling, system dynamics, discrete event simulation,
mathematical optimization, and interactive educational tools
for rural hospital strategic decision-making.

# Main Components
- **Domain Model**: Complete type system for hospitals, financials, staffing, payer mix
- **Finance Engine**: CMS 2552-10 cost report, reimbursement, ratios, depreciation, 340B
- **Simulation Engines**: Deterministic, Monte Carlo, Agent-Based, System Dynamics, DES
- **Optimization**: JuMP.jl staffing and service portfolio optimization
- **Risk Assessment**: Closure risk prediction, REH conversion analysis
- **Analysis**: Sensitivity, benchmarking, community impact, payer negotiation, scenario comparison
- **Data**: HCRIS parser, CSV/Excel import, export utilities
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
# DOMAIN MODEL (must be loaded first, in dependency order)
# ═══════════════════════════════════════════════════════════════

include("models/abstract.jl")
include("models/department.jl")
include("models/staffing.jl")
include("models/payer.jl")
include("models/financial.jl")
include("models/capital.jl")
include("models/hospital.jl")
include("models/scenarios.jl")
include("models/results.jl")

# ═══════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════

include("utils/constants.jl")
using .Constants
include("utils/validation.jl")
include("utils/formatting.jl")

# ═══════════════════════════════════════════════════════════════
# FINANCE ENGINE
# ═══════════════════════════════════════════════════════════════

include("finance/costreport.jl")
include("finance/reimbursement.jl")
include("finance/ratios.jl")
include("finance/depreciation.jl")
include("finance/breakeven.jl")
include("finance/cashflow.jl")
include("finance/program340b.jl")

# ═══════════════════════════════════════════════════════════════
# SIMULATION ENGINES
# ═══════════════════════════════════════════════════════════════

include("simulation/deterministic.jl")
include("simulation/montecarlo.jl")
include("simulation/abm.jl")
include("simulation/systemdynamics.jl")
include("simulation/des.jl")
include("simulation/scenarios.jl")

# ═══════════════════════════════════════════════════════════════
# OPTIMIZATION (JuMP.jl)
# ═══════════════════════════════════════════════════════════════

include("optimization/staffing.jl")
include("optimization/portfolio.jl")

# ═══════════════════════════════════════════════════════════════
# RISK ASSESSMENT
# ═══════════════════════════════════════════════════════════════

include("risk/closure.jl")
include("risk/conversion.jl")

# ═══════════════════════════════════════════════════════════════
# ANALYSIS
# ═══════════════════════════════════════════════════════════════

include("finance/sensitivity.jl")
include("analysis/comparison.jl")
include("analysis/community.jl")
include("analysis/payer_negotiation.jl")

# ═══════════════════════════════════════════════════════════════
# DATA IMPORT/EXPORT
# ═══════════════════════════════════════════════════════════════

include("data/import_hcris.jl")
include("data/import_csv.jl")
include("data/export.jl")
include("data/benchmarks.jl")

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

# Finance functions
export step_down_allocation, calculate_medicare_cost_share
export calculate_medicare_reimbursement
export calculate_medicaid_reimbursement
export calculate_commercial_reimbursement
export calculate_uncompensated_care
export apply_wage_index, apply_sequestration, apply_bad_debt_adjustment
export default_cah_cost_centers, default_step_down_order

# Financial ratios
export compute_operating_margin, compute_total_margin, compute_days_cash_on_hand
export compute_current_ratio, compute_debt_to_capitalization
export compute_average_age_of_plant, compute_fte_per_adjusted_occupied_bed
export compute_salary_to_revenue, compute_outpatient_revenue_share
export compute_medicare_cost_to_charge_ratio, compute_all_ratios

# Depreciation
export straight_line_depreciation, declining_balance_depreciation
export depreciation_schedule, total_annual_depreciation, replacement_needs

# Break-even
export BreakEvenResult, calculate_break_even, break_even_by_payer, target_margin_volume

# Cash flow
export MonthlyCashFlow, project_monthly_cash_flow, find_cash_nadir, line_of_credit_needed

# 340B
export Program340BParams, Program340BResult, calculate_340b_impact, policy_risk_scenarios

# Simulation engine functions
export DeterministicParams, DeterministicResult, project_financials, project_single_year
export MonteCarloParams, DistributionalParameter, run_monte_carlo
export probability_of_loss, value_at_risk
export ABMParams, ABMResult, initialize_abm, run_abm
export SystemDynamicsParams, run_system_dynamics, hospital_dynamics!
export DESParams, DESResult, run_des
export SimulationScenario, ScenarioSet, run_scenario_set, compare_scenario_set

# Optimization functions
export optimize_staffing, optimize_service_portfolio

# Risk assessment functions
export MarketData, assess_closure_risk, estimate_distress_timeline
export analyze_reh_conversion, default_cah_assumptions, default_reh_assumptions

# Analysis functions
export SensitivityResult, run_sensitivity_analysis, build_tornado_data
export ScenarioComparison, compare_scenarios, rank_scenarios, scenario_delta
export CommunityImpactParams, CommunityImpactResult
export calculate_community_impact, closure_impact_projection
export NegotiationCategory, NegotiationResult
export simulate_negotiation, optimal_rate_target
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
