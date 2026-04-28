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

# ── New healthcare economics domains ──────────────────────────────────────
include("cost_accounting.jl")
include("risk_contracting.jl")
include("capital_structure.jl")
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
export value_score, qalys, quality_score, efficiency_score, readmission_penalty

# Cost Accounting (Ch. 8)
export cost_to_charge_ratio, estimate_cost_from_charges, step_down_allocation,
       activity_based_cost, marginal_cost, department_profitability

# Risk Contracting (Ch. 9)
export pmpm, shared_savings, shared_risk, risk_corridor,
       hcc_risk_score, case_mix_index, capitation_rate, medical_loss_ratio

# Capital Structure (Ch. 10)
export debt_service_coverage_ratio, days_cash_on_hand, current_ratio,
       debt_to_capitalization, wacc, bond_price, bond_yield_to_maturity,
       capital_budget_ranking, financial_health_scorecard,
       irr, mirr, discounted_payback_period, interest_coverage_ratio,
       profitability_index, modified_duration, lease_vs_buy

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

end  # module FinanceEngine
