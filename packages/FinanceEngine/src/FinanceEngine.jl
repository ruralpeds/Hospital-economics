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
include("physician_employment.jl")
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

# Physician Employment vs IC Economics (Ch. 10g)
export MGMA_BENCHMARKS_2024,
       PhysEmploymentProfile, W2EmploymentModel, IndependentContractorModel, EmploymentComparison,
       total_w2_cost, total_ic_cost, compare_employment,
       mgma_benchmark_salary, physician_roi, staffing_gap_analysis, compensation_design

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

# MBA Domains B + D — Strategy & Risk/ML
include("service_line_portfolio.jl")
include("payer_negotiation_game.jl")
include("competitive_analytics.jl")
include("copula_mc.jl")
include("var_cvar_stress.jl")

# MBA B-03 — Service-Line Portfolio
export ServiceLine, PortfolioStats, EfficientFrontierPoint, ServiceLinePortfolioResult,
       compute_portfolio_stats, optimize_service_line_portfolio, portfolio_recommendation

# MBA B-06 — Nash Bargaining Payer Negotiation
export NashBargainInputs, NashBargainResult, nash_bargaining, kalai_smorodinsky,
       batna_sensitivity,
       RubinsteinParams, RubinsteinRound, RubinsteinResult, rubinstein_simulation,
       hospital_reservation_price

# MBA B-07 — Competitive Analytics
export compute_hhi, HHI_UNCONCENTRATED, HHI_MODERATELY_CONC,
       market_concentration_tier, hhi_merger_delta,
       HospitalCompetitor, MarketShareResult, analyze_market_share,
       geographic_overlap_score,
       HHITrendPoint, compute_hhi_trend,
       competitive_position_score

# MBA D-04 — Copula MC
export CopulaSpec, HOSPITAL_DEFAULT_CORRELATION,
       sample_gaussian_copula, sample_t_copula, sample_copula,
       CopulaMarginal, uniforms_to_marginals,
       CopulaMCParams, CopulaMCResult, CopulaMCSummary,
       run_copula_mc, compare_copula_vs_independent

# MBA D-05 + D-06 — VaR/CVaR + CCAR Stress Test
export VaRResult, compute_var_cvar, hospital_var_cvar,
       MacroScenario, CCAR_SCENARIOS_2024,
       StressTestYearResult, StressTestResult,
       HospitalStressTestInputs,
       run_stress_scenario, run_ccar_stress_test

# MBA P1 Bundle 1 — Working Capital, SFA, TDABC, Cox PH Closure, RHC AIR
include("working_capital.jl")
include("sfa.jl")
include("tdabc.jl")
include("cox_ph_closure.jl")
include("rhc_air_cap.jl")

# MBA A-10 — Working Capital Optimization
export WorkingCapitalInputs, WorkingCapitalMetrics, compute_working_capital,
       target_dso_model,
       ARAgingBucket, AR_COLLECTION_BENCHMARKS, ar_aging_analysis,
       working_capital_scenarios

# MBA C-02 — Stochastic Frontier Analysis
export SFAHospital, SFAResult, SFAAnalysis,
       build_translog_matrix, jlms_efficiency, run_sfa

# MBA C-05 — Time-Driven Activity-Based Costing
export ResourcePool, unused_capacity_minutes, unused_capacity_cost, capacity_utilisation,
       TimeEquation, evaluate_time_equation,
       TDABCEncounter, TDABCCostResult, TDABCModel,
       add_resource_pool!, add_time_equation!, cost_encounter, run_tdabc

# MBA D-01 — Cox PH Closure Hazard
export COX_PH_CLOSURE_COEFFICIENTS, RURAL_HOSPITAL_BASELINE_SURVIVAL,
       ClosureRiskInputs, ClosureRiskResult,
       cox_ph_closure_risk, cox_ph_portfolio_risk

# MBA E-04 — RHC AIR Cap & CAA 2021 Phase-In
export RHCType, independent, provider_based, grandfathered,
       CAA2021_PROVIDER_BASED_CAPS, INDEPENDENT_RHC_CAPS,
       RHCAIRInputs, RHCAIRPaymentResult,
       rhc_applicable_cap, calculate_rhc_air_payment,
       rhc_cap_projection, rhc_caa2021_summary

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

# MBA P1 Bundle 3 — 340B Contract Pharmacy, TEAM, Medicaid SDPs, Bayesian VBC MSSP
include("b340_contract_pharmacy.jl")
include("team_bundled_payment.jl")
include("medicaid_sdp.jl")
include("vbc_bayesian_mssp.jl")

# MBA E-05 — 340B Contract Pharmacy
export CoveredEntityType, cah_340b, dsh_hospital, rural_referral, fqhc_340b, ryan_white,
       ManufacturerRestrictionPolicy, MANUFACTURER_RESTRICTION_POLICIES_2026,
       ContractPharmacy, ContractPharmacyDrugRecord, ContractPharmacyDrugResult,
       calculate_contract_pharmacy_savings, compare_inhouse_vs_contract

# MBA E-07 — TEAM FY2026
export TEAMEpisodeType, lejr, shff, sf, cdi, cabg,
       TEAM_DRG_MAP, TEAM_QUALITY_ADJUSTMENTS, TEAM_REGIONAL_BENCHMARKS_FY2026,
       TEAMEpisode, TEAMTargetPriceInputs,
       TEAMEpisodeResult, TEAMPortfolioResult,
       calculate_team_target_price, team_episode_reconciliation,
       team_portfolio_analysis, team_annual_projection

# MBA E-08 — Medicaid State Directed Payments
export SDPType, atb_all_hospitals, safety_net_directed, rural_cah_directed,
       transition_directed, value_based_directed,
       SDPEligibilityTier, tier_1_cah_sole_community, tier_2_rural_hospital,
       tier_3_safety_net_urban, tier_4_all_eligible,
       SDPHospitalInputs, SDPProgramInputs, SDPPaymentResult,
       sdp_eligibility_tier, calculate_sdp_payment, sdp_portfolio_analysis

# MBA D-03 — Bayesian VBC / MSSP
export MSSPTrack, mssp_basic_a, mssp_basic_b, mssp_basic_c, mssp_basic_d,
       mssp_basic_e, mssp_enhanced, reach_aco,
       MSSP_TRACK_PARAMETERS, MSSP_EMPIRICAL_PRIORS,
       MSSPHospitalInputs, MSSPBayesianResult,
       mssp_bayesian_analysis, mssp_track_comparison, bayesian_update_cycle

# MBA P1 Final Reporting — Rating Memo, Tornado API, Scenario Diff
include("rating_agency_memo.jl")
include("sensitivity_tornado.jl")
include("scenario_diff.jl")

# MBA F-02 — Rating Agency Memo
export RatingMemoInputs,
       generate_rating_memo_markdown, generate_rating_memo_typst, rating_memo_data

# MBA F-04 — Sensitivity Tornado
export TornadoRow, TornadoResult,
       one_way_sensitivity, two_way_sensitivity,
       break_even_analysis, scenario_sensitivity, tornado_chart_data

# MBA F-05 — Scenario Diff / Compare
export ScenarioSnapshot, ScenarioDiffRow, ScenarioDiff,
       STANDARD_METRIC_DIRECTIONS, compare_scenarios,
       WaterfallStep, build_waterfall,
       ScenarioSet, scenario_set_diff,
       rank_scenarios, scenario_diff_table

# ─── P2 MBA Gaps ──────────────────────────────────────────────────────────────
include("lbo_analysis.jl")
include("blue_ocean.jl")
include("reh_real_options.jl")
include("scenario_planning.jl")
include("theory_of_constraints.jl")
include("readmission_risk.jl")
include("climate_risk.jl")
include("nsa_idr.jl")
include("fed_register_parser.jl")

# A-08 — LBO Analysis
export LBOInputs, LBOSourcesUses, LBOYearResult, LBOExitScenario, LBOResult,
       hospital_lbo

# B-02 — Blue Ocean Strategy
export CompetitiveFactor, StrategicCanvas, ERRCGrid, BlueOceanResult,
       build_errc_grid, blue_ocean_analysis

# B-04 — REH Real Options
export CAHFinancialProfile, REHConversionResult, analyze_cah_to_reh_conversion,
       REH_MONTHLY_FACILITY_PAYMENT_FY2026

# B-05 — Scenario Planning
export FiveForce, FiveForcesResult, analyze_five_forces,
       PESTLEFactor, PESTLEResult, analyze_pestle,
       UncertaintyAxis, Scenario, ScenarioMatrix,
       build_scenario_matrix, default_rural_hospital_scenarios

# C-04 — Theory of Constraints
export ThroughputInputs, ThroughputMetrics, compute_throughput_metrics,
       HospitalResource, ConstraintAnalysis, identify_constraint,
       throughput_vs_cost_decision

# D-02 — Readmission Risk
export lace_score, lace_l_score,
       PatientDischarge, ReadmissionRiskResult,
       logistic_readmission_prob, score_population,
       readmission_population_summary, hrrp_cm_impact

# D-07 — Climate Risk / TCFD
export PhysicalRiskInputs, PhysicalRiskResult, assess_physical_risk,
       TransitionRiskInputs, TransitionRiskResult, assess_transition_risk,
       ClimateScenario, IPCC_SCENARIOS, tcfd_scenario_analysis

# E-09 — NSA-IDR
export IDRClaimInputs, IDRClaimResult,
       analyze_idr_claim, batch_idr_claims, idr_portfolio_opportunity,
       estimated_qpa, IDR_ADMIN_FEE_STANDARD, IDR_ADMIN_FEE_COMPLEX

# F-07 — Federal Register Parser
export CMS_RULE_REGISTRY, FedRegisterDocument, RateExtraction,
       build_fed_register_api_url, parse_fed_register_response,
       extract_rates_from_text, generate_constants_update, validate_rate_extraction

# ─── Managed Care Tiered Contracting ─────────────────────────────────────────
include("managed_care_contracting.jl")

# Managed Care Contracting — Types
export CONTRACT_TYPES, REIMBURSEMENT_METHODS,
       TieredCapitation, ContractTerms, ContractAnalysis, ManagedCarePortfolio

# Managed Care Contracting — Functions
export analyze_contract, compare_contracts,
       tiered_capitation_model, capitation_adequacy,
       ffs_to_capitation_bridge, risk_pool_analysis,
       contract_negotiation_prep, payer_mix_optimization,
       rural_hospital_benchmarks

# Managed Care Contracting — Benchmark Data
export CMS_COMMERCIAL_PMPM_BENCHMARKS, DEMOGRAPHIC_RISK_FACTORS,
       UTILIZATION_BENCHMARKS

# ─── Charity Care / Financial Assistance Policy ─────────────────────────────
include("charity_care.jl")

export FPLTier, FinancialAssistancePolicy, CommunityProfile, CharityCareResult,
       default_fap, calculate_charity_volume, optimize_fap,
       community_benefit_report, bad_debt_vs_charity,
       presumptive_eligibility_model, tax_exemption_analysis,
       fap_compliance_check

# ─── ED Throughput Revenue Linkage ───────────────────────────────────────────
include("ed_throughput.jl")

export EDConfig, EDRevenueModel, EDThroughputResult,
       ed_revenue_analysis, lwbs_revenue_impact, boarding_cost_analysis,
       throughput_optimization, fast_track_roi, staffing_revenue_model,
       emtala_compliance_cost, ed_expansion_business_case

# ─── Hospital Exit / Transition Planning ─────────────────────────────────────
include("exit_planning.jl")

export HospitalProfile, ExitScenario, CommunityImpactAssessment, TransitionPlan,
       assess_viability, community_impact, asset_liquidation,
       reh_conversion_analysis, merger_analysis, service_line_reduction,
       regulatory_requirements, transition_timeline, patient_migration_model

# ─── ACO Compliance & Reporting ──────────────────────────────────────────────
include("aco_compliance.jl")

export ACOTrack, ACOFinancials, ACOPerformance, QualityMeasureResult,
       mssp_tracks, aco_reach_tracks, calculate_performance,
       benchmark_calculation, quality_scorecard, aco_quality_measures,
       financial_reconciliation, rural_aco_considerations,
       aco_readiness_assessment, track_recommendation

end  # module FinanceEngine
