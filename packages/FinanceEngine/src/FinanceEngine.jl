"""
    FinanceEngine

Comprehensive healthcare financial modeling engine for the RuralHealthPlatform.
Covers hospital economics across 16 domains: core finance, econometrics,
Monte Carlo simulation, dynamic programming, financial monitoring, strategic
planning, value-based care, cost accounting, risk contracting, capital structure,
operational efficiency, population health economics, supply chain, performance
optimization, scenario persistence, and undo/redo.

Migrated from healthcare-finance-julia/src/ and expanded.
"""
module FinanceEngine

using RuralCore
using Statistics
using Random
using DataFrames
using LinearAlgebra

# ── Core engines ──────────────────────────────────────────────────────────
include("financial.jl")
include("dupont.jl")
include("distress_scoring.jl")
include("econometrics.jl")
include("simulation.jl")
include("optimization.jl")
include("financial_monitoring.jl")
include("strategic_planning.jl")
include("value_based_care.jl")
include("three_statement.jl")
include("vbc_bayesian.jl")

# ── New healthcare economics domains ──────────────────────────────────────
include("cost_accounting.jl")
include("risk_contracting.jl")
include("ma_risk.jl")
include("capital_structure.jl")
include("rhc_cah.jl")
include("program_340b.jl")
include("telehealth.jl")
include("medicaid_dsh.jl")
include("rhc_optimization.jl")
include("network_economics.jl")
include("physician_compensation.jl")
include("operational_efficiency.jl")
include("population_health.jl")
include("supply_chain.jl")
include("budgeting.jl")
include("accounting.jl")
include("actuarial.jl")
include("reimbursement.jl")
include("forecasting.jl")
include("cost_effectiveness.jl")

# ── Infrastructure ────────────────────────────────────────────────────────
include("performance_optimization.jl")
include("scenario_persistence.jl")
include("undo_redo.jl")

# MBA Domain A — Corporate Finance & Valuation (A-04, A-05 EAC, A-06, A-09)
include("nonprofit_wacc.jl")
include("real_options.jl")
include("treasury.jl")

# MBA Domain C — Operations Analytics (C-01 DEA, C-03 Variance, C-07 Benchmarking)
include("dea.jl")
include("variance_analysis.jl")
include("peer_benchmarking.jl")

# MBA Domain E — Reimbursement (E-01 CAH Outliers, E-03 Medicare Advantage, E-06 MIPS/VBP/HRRP)
include("cah_outlier_payments.jl")
include("medicare_advantage.jl")
include("mips_vbp_hrrp.jl")

# ═══════════════════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════════════════

# Core Financial (Ch. 1)
export npv, roi, operating_margin, cost_per_patient, break_even_units,
       payback_period, drg_revenue, weighted_payer_rate, net_collection_rate

# DuPont Decomposition (Ch. 1a)
export DuPont3Factor, DuPont5Factor, dupont_3factor, dupont_5factor

# Distress Scoring (Ch. 1c)
export AltmanZScore, BeneishMScore, altman_z_double_prime, beneish_m_score

# Three-Statement Projection (Ch. 1b)
export BalanceSheetSnapshot, ProjectionAssumptions, ThreeStatementProjection,
       project_three_statement, bs_balances

# Econometrics (Ch. 2)
export simple_linear_regression, predict_linear, r_squared, mean_absolute_error

# Simulation (Ch. 3)
export monte_carlo_mean, simulate_growth, arma_forecast, arma_stochastic_paths

# Optimization (Ch. 4)
export rouwenhorst_grid, optimal_bed_expansion, optimal_staffing

# Financial Monitoring (Ch. 5)
export initialize_kalman, kalman_filter_step, margin_tracker, early_warning_signal,
       hamilton_filter, liquidity_forecast, KalmanFilterState

# Strategic Planning (Ch. 6)
export cost_trajectory, merger_integration_plan, restructuring_plan, revenue_enhancement_plan

# Value-Based Care (Ch. 7) — now exports ALL functions
export value_score, qalys, quality_score, efficiency_score, readmission_penalty,
       VBCScenario, BayesianVBCPost, fit_vbc_prior, sample_vbc_posterior, compare_scenarios

# Cost Accounting (Ch. 8)
export cost_to_charge_ratio, estimate_cost_from_charges, step_down_allocation,
       activity_based_cost, marginal_cost, department_profitability

# Risk Contracting (Ch. 9)
export pmpm, shared_savings, shared_risk, risk_corridor,
       hcc_risk_score, case_mix_index, capitation_rate, medical_loss_ratio,
       HCCDiagnosis, MARAFScore, parse_hcc_coefficients, calculate_member_raf,
       aggregate_cohort_raf

# Capital Structure (Ch. 10)
export debt_service_coverage_ratio, days_cash_on_hand, current_ratio,
       debt_to_capitalization, wacc, bond_price, bond_yield_to_maturity,
       capital_budget_ranking, financial_health_scorecard,
       irr, mirr, discounted_payback_period, interest_coverage_ratio,
       profitability_index, modified_duration, lease_vs_buy,
       WACCCalibration, calculate_wacc,
       CapexProject, CapexMetrics, calculate_capex_metrics, rank_projects,
       RHCReimbursement, CAHReimbursement, ReimburseComparison,
       load_rhc_schedule, load_cah_schedule, project_rhc_revenue, project_cah_revenue, compare_reimbursement

# Drug Economics (Ch. 10a) — 340B Program
export Drug340B, DrugProgramMetrics, DrugOptimizationResult,
       load_340b_formulary, estimate_340b_savings, optimize_drug_mix

# Telehealth & RPM (Ch. 10b)
export TelehealthService, RPMDevice, TelehealthMetrics, RPMFinancialImpact,
       calculate_telehealth_metrics, calculate_rpm_financial_impact, compare_telehealth_scenarios

# Medicaid DSH & Supplemental Payments (Ch. 10c)
export HospitalCharacteristics, DSHCalculation, SupplementalPaymentImpact,
       calculate_medicaid_caseload_percentage, calculate_low_income_percentage,
       calculate_dsh_index, calculate_dsh_payment, calculate_supplemental_impacts

# RHC Service Line Optimization (Ch. 10d)
export RHCServiceLine, RHCServiceMetrics, RHCPortfolioOptimization,
       calculate_rhc_service_metrics, optimize_rhc_portfolio, compare_service_line_scenarios

# Network Economics (Ch. 10e)
export HospitalNode, NetworkTransfer, NetworkEconomics, NetworkAnalysisResult,
       calculate_network_margin_impact, analyze_network_system

# Physician Compensation (Ch. 10f)
export PhysicianProfile, CompensationModel, PhysicianCompensation, SpecialtyBenchmarks,
       calculate_physician_compensation, benchmark_specialty, identify_outliers

# Budgeting (Ch. 10b)
export operating_budget, flex_budget, volume_variance, price_variance,
       efficiency_variance, mix_variance, rate_volume_variance,
       budget_to_actual_variance, capital_budget_rank,
       zero_based_budget_score, rolling_forecast_update

# Operational Efficiency (Ch. 11)
export length_of_stay_analysis, bed_turnover_rate, ed_throughput,
       surgical_utilization, capacity_planning, staffing_ratio

# Population Health Economics (Ch. 12)
export preventive_care_roi, telehealth_cost_effectiveness,
       sdoh_impact_model, chronic_disease_management_savings

# Supply Chain (Ch. 13)
export economic_order_quantity, safety_stock, inventory_turnover,
       pharmaceutical_cost_analysis, stockout_cost, vendor_scorecard

# Accounting (Ch. 11)
export income_statement, ebitda, ebitda_margin, total_margin,
       operating_margin_hfma, operating_leverage, balance_sheet_ratios,
       quick_ratio, debt_to_equity, equity_multiplier, cash_flow_indirect,
       straight_line_depreciation, macrs_depreciation_schedule,
       net_assets_change, fund_accounting_summary, charitable_community_benefit_rate

# Actuarial (Ch. 12)
export loss_development_factors, claims_triangle_development, ibnr_reserve,
       hcc_prospective_score, pmpm_by_category, admin_expense_ratio,
       premium_rate_development, community_rating_premium,
       utilization_rate, admissions_per_thousand, ed_visits_per_thousand,
       claim_frequency, claim_severity, pure_premium,
       credibility_weight, blended_rate

# Reimbursement (Ch. 13)
export drg_payment, ms_drg_payment, apr_drg_payment, opps_apc_payment,
       rvu_to_payment, rbrvs_payment, capitation_pmpm, pmpm_trend,
       payer_contract_net, days_in_ar, denial_rate, clean_claim_rate,
       gross_collection_rate, cash_collection_efficiency,
       bad_debt_rate, charity_care_rate, uncompensated_care_rate,
       revenue_cycle_scorecard

# Forecasting (Ch. 14)
export simple_exponential_smoothing, holt_double_exponential,
       holt_winters_additive, weighted_moving_average,
       seasonal_indices, deseasonalize, reseasonalize,
       budget_variance, budget_variance_pct, flexible_budget_variance,
       forecast_rmse, forecast_mape, forecast_bias

# Cost-Effectiveness Analysis (Ch. 15)
export markov_cohort, markov_cycle_traces, icer, cea_dominant,
       net_monetary_benefit, willingness_to_pay_threshold,
       daly, life_years_gained, qaly_adjusted_life_years,
       budget_impact_analysis, decision_tree_ev,
       probabilistic_sensitivity_analysis, tornado_diagram_inputs

# Performance Optimization
export ProfileResult, CacheLayer, parallelize_sweep, benchmark_abm, setup_worker_pool,
       get_cached, set_cached, clear_cache, vectorized_demand_forecast, batch_compute_stockout_risk

# Scenario Persistence (Phase 7)
export Scenario, ScenarioStorage, save_scenario, load_scenario, list_scenarios,
       delete_scenario, toggle_favorite, export_scenario_to_json, import_scenario_from_json

# Undo/Redo (Phase 7)
export Command, ParameterChangeCommand, CommandHistory,
       execute!, undo!, redo!, description, can_undo, can_redo,
       next_undo_description, next_redo_description, clear_history!,
       get_history, get_state, execute_and_record!

# MBA A-04 — Nonprofit WACC, MADS, Synthetic Rating
export MMD_AAA_CURVE, HOSPITAL_SECTOR_SPREADS, mmd_yield,
       hamada_unlever, hamada_relever,
       NonprofitWACCInputs, NonprofitWACCResult, nonprofit_wacc,
       DebtCovenantInputs, CovenantCompliance, CovenantDashboard,
       mads_headroom, covenant_dashboard,
       SyntheticRatingInputs, synthetic_rating,
       equivalent_annual_cost

# MBA A-06 — Real Options
export RealOptionBSM, BSMResult, bsm_real_option,
       RealOptionBinomial, BinomialResult, binomial_real_option,
       ServiceLineOption, ServiceLineOptionResult,
       value_service_line_option, hospital_real_options_portfolio,
       estimate_real_asset_volatility

# MBA A-09 — Treasury & Liquidity
export WeeklyOperatingProfile, WeeklyForecastRow, ThirteenWeekForecast,
       thirteen_week_forecast,
       MedicareDelayScenario, MedicareDelayStressResult,
       medicare_delay_stress, run_medicare_delay_scenarios,
       LOCHeadroomInputs, LOCHeadroomResult, loc_headroom,
       LiquidityDashboard, liquidity_dashboard

# MBA C-01 — Data Envelopment Analysis
export DEAUnit, DEAResult, DEAAnalysis,
       dea, dea_ccr, dea_bcc, scale_efficiency, dea_summary_table

# MBA C-03 — Revenue Cycle Variance Analysis
export RevenuePeriod, VarianceBridge, revenue_variance_bridge,
       PayerRevenuePeriod, PayerVarianceRow, PayerVarianceBridge, payer_variance_bridge,
       ExpenseVarianceBridge, expense_variance, multi_category_variance

# MBA C-07 — Peer Benchmarking
export FLEX_MONITORING_2022, AHA_RURAL_2023, MGMA_2023,
       BenchmarkComparison, PeerBenchmarkReport,
       benchmark_flex_monitoring, benchmark_aha_rural,
       benchmark_mgma_physician, comprehensive_benchmark,
       benchmark_report_text

# MBA E-01 — CAH Outlier & TEFRA
export CAH_OUTLIER_FIXED_LOSS_THRESHOLD_FY2026, CAH_OUTLIER_MARGINAL_RATE,
       CAH_BAD_DEBT_REIMBURSEMENT_RATE, TEFRA_INCENTIVE_RATE,
       CAHOutlierCase, CAHOutlierPayment, cah_outlier_payment, cah_outlier_analysis,
       TEFRAHospitalData, TEFRAPaymentResult, tefra_payment,
       cah_bad_debt_reimbursement, cah_swing_bed_payment,
       CAHWorksheetE1Inputs, cah_worksheet_e1

# MBA E-03 — Medicare Advantage v28
export HCC_V28_CNA_COEFFICIENTS, HCC_V28_INTERACTION_COEFFICIENTS,
       MA_NORMALIZATION_FACTORS, ma_normalization_factor,
       ma_demographic_factor,
       MAMemberRAF, MARAFResult, calculate_ma_raf,
       MA_RURAL_PASSTHROUGH_RATE, ma_rural_passthrough_payment,
       MACountyCapitationInputs, MACapitationResult, ma_county_capitation,
       ma_penetration_revenue_impact

# MBA E-06 — MIPS / Hospital VBP / HRRP / HACRP
export MIPS_WEIGHTS_CY2025, MIPS_THRESHOLDS_CY2025,
       MIPSScores, MIPSResult, calculate_mips,
       VBP_DOMAIN_WEIGHTS_FY2026, VBPDomainScores, VBPResult, calculate_vbp,
       HRRP_MEASURES_FY2026, HRRPMeasure, HRRPResult, calculate_hrrp,
       HACRP_DOMAIN_WEIGHTS_FY2026, HACRPInputs, HACRPResult, calculate_hacrp,
       HospitalQualityPaymentImpact, hospital_quality_payment_impact

# MBA P1 Bundle 2 — M&A Valuation, Balanced Scorecard, Reciprocal Cost Allocation
include("ma_valuation.jl")
include("balanced_scorecard.jl")
include("reciprocal_cost_allocation.jl")

# MBA A-07 — Hospital M&A Valuation
export RURAL_HOSPITAL_TRANSACTION_MULTIPLES,
       TargetHospitalFinancials, MAValuationInputs,
       DCFValuationResult, ComparableTransactionResult,
       AssetBasedValuationResult, MAValuationResult,
       dcf_valuation, comparable_transactions, asset_based_valuation,
       synergy_npv, hospital_ma_valuation, ma_sensitivity_table

# MBA B-01 — Balanced Scorecard
export BSCPerspective, financial, patient_community, internal_process, learning_growth,
       KPIDirection, higher_better, lower_better, target_range,
       BSCKPIDefinition, BSCKPIMeasurement, CAH_STANDARD_KPI_LIBRARY,
       StrategicInitiative, BalancedScorecard,
       measure_kpi!, rag_status_for_kpi, performance_score_for_kpi,
       BSCSummary, summarise_bsc, bsc_report_text

# MBA C-06 — Reciprocal Cost Allocation
export CostCenterType, overhead, patient_care,
       CostCenter, AllocationBase, CostAllocationModel,
       AllocationResult, AllocationSummary,
       step_down_allocation, reciprocal_allocation,
       compare_allocation_methods

end  # module FinanceEngine
