"""
    FinanceEngine

Healthcare financial modeling engine for the RuralHealthPlatform.
Provides NPV, ROI, DRG revenue, payer mix, econometrics, simulation,
and value-based care calculations.

Migrated from healthcare-finance-julia/src/.
"""
module FinanceEngine

using RuralCore
using Statistics
using Random

# ── Sub-engines (each is a self-contained module) ──────────────────────────

include("financial.jl")
include("econometrics.jl")
include("simulation.jl")
include("optimization.jl")
include("financial_monitoring.jl")
include("strategic_planning.jl")
include("value_based_care.jl")

# ── Re-exports ─────────────────────────────────────────────────────────────

# Financial
export npv, roi, operating_margin, cost_per_patient, break_even_units,
       payback_period, drg_revenue, weighted_payer_rate, net_collection_rate

# Econometrics
export simple_linear_regression, predict_linear, r_squared, mean_absolute_error

# Simulation
export monte_carlo_mean, simulate_growth, arma_forecast, arma_stochastic_paths

# Optimization
export rouwenhorst_grid, optimal_bed_expansion, optimal_staffing

# Financial Monitoring
export initialize_kalman, kalman_filter_step, margin_tracker, early_warning_signal,
       hamilton_filter, liquidity_forecast, KalmanFilterState

# Strategic Planning
export cost_trajectory, merger_integration_plan, restructuring_plan, revenue_enhancement_plan

# Value-Based Care
export value_score, qalys

end  # module FinanceEngine
