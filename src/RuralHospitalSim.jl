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
using Agents

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
include("finance/team_bundled.jl")
include("finance/telehealth.jl")
include("finance/vbc_transition.jl")
include("finance/medicaid_supplemental.jl")
include("finance/debt_capacity.jl")
include("finance/margin_decomposition.jl")
include("finance/rhc_optimization.jl")

# ═══════════════════════════════════════════════════════════════
# SIMULATION ENGINES
# ═══════════════════════════════════════════════════════════════

include("simulation/deterministic.jl")
include("simulation/montecarlo.jl")
include("simulation/abm.jl")
include("simulation/systemdynamics.jl")
include("simulation/des.jl")

# ═══════════════════════════════════════════════════════════════
# OPTIMIZATION (JuMP.jl)
# ═══════════════════════════════════════════════════════════════

include("optimization/staffing.jl")
include("optimization/portfolio.jl")
include("optimization/capital_scoring.jl")

# ═══════════════════════════════════════════════════════════════
# RISK ASSESSMENT
# ═══════════════════════════════════════════════════════════════

include("risk/closure.jl")
include("risk/conversion.jl")
include("risk/closure_ml.jl")
include("risk/disaster_resilience.jl")

# ═══════════════════════════════════════════════════════════════
# ANALYSIS
# ═══════════════════════════════════════════════════════════════

include("finance/sensitivity.jl")
include("analysis/comparison.jl")
include("analysis/community.jl")
include("analysis/payer_negotiation.jl")
include("analysis/sdoh.jl")
include("analysis/geographic_access.jl")
include("analysis/community_benefit.jl")
include("analysis/network_economics.jl")

# ═══════════════════════════════════════════════════════════════
# SCENARIO FRAMEWORK (depends on simulation engines + analysis)
# ═══════════════════════════════════════════════════════════════

include("simulation/scenarios.jl")

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
export operating_margin, total_margin, days_cash_on_hand
export current_ratio, debt_to_capitalization
export average_age_of_plant, fte_per_adjusted_occupied_bed
export salary_to_revenue, outpatient_revenue_share
export medicare_cost_to_charge_ratio, compute_all_ratios

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
export DeterministicParams, DeterministicResult, project_financials, project_single_year, base_financials
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

# V3.1 — TEAM Bundled Payment
export TEAMEpisode, TEAMParams, TEAMResult
export calculate_team_reconciliation, team_episode_summary

# V3.1 — Telehealth Economics
export TelehealthService, TelehealthInvestment, TelehealthROI
export calculate_telehealth_roi, telehealth_service_comparison

# V3.1 — Value-Based Care Transition
export VBCParams, VBCResult
export calculate_vbc_outcome, vbc_transition_timeline

# V3.1 — Medicaid Supplemental Payments
export MedicaidSupplementalParams, MedicaidSupplementalResult
export calculate_medicaid_supplemental, medicaid_reform_scenarios

# V3.1 — Stochastic Debt Capacity
export DebtCapacityParams, DebtCapacityResult
export calculate_debt_capacity, debt_capacity_sensitivity

# V3.1 — Payer Margin Decomposition
export PayerMarginComponent, MarginDecomposition
export decompose_margin, dupont_analysis, margin_waterfall

# V3.1 — RHC Optimization
export RHCParams, RHCOptimizationResult
export optimize_rhc_revenue, rhc_vs_hopd_comparison

# V3.1 — SDOH Integration
export SDOHProfile, SDOHAdjustment
export calculate_sdoh_adjustments, sdoh_financial_impact, sdoh_risk_tier

# V3.1 — Geographic Access
export FacilityLocation, PopulationCenter, AccessResult
export haversine_distance, estimate_drive_time
export calculate_catchment, closure_access_impact

# V3.1 — Community Benefit (IRS Schedule H)
export CommunityBenefitData, CommunityBenefitResult
export calculate_community_benefit, community_benefit_comparison

# V3.1 — Network Economics
export NetworkMember, SharedService, NetworkResult
export evaluate_network, network_aco_formation, joint_purchasing_savings

# V3.1 — ML Closure Prediction
export ClosureMLFeatures, ClosureMLResult
export predict_closure_logistic, chartis_vulnerability_score, closure_risk_trend

# V3.1 — Disaster Resilience
export DisasterProfile, DisasterImpactResult
export assess_disaster_resilience, disaster_stress_test

# V3.1 — Capital Replacement Scoring (MCDA)
export CapitalRequest, CapitalScoreResult
export score_capital_projects, select_within_budget, replacement_priority_report

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
