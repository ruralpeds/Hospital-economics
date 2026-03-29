"""
SimulationController — API handlers for simulation engine endpoints.

Routes:
  POST /api/simulate/deterministic
  POST /api/simulate/monte-carlo
  POST /api/simulate/abm
  POST /api/simulate/system-dynamics
  POST /api/simulate/des
"""
module SimulationController

using JSON3, Dates, UUIDs
using ...RuralHospitalSim

# ═══════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════

"""Build a NamedTuple of base financials from a JSON payload dict."""
function _parse_base_financials(data::Dict)
    (
        inpatient_revenue  = Float64(get(data, "inpatient_revenue", 8_000_000.0)),
        outpatient_revenue = Float64(get(data, "outpatient_revenue", 12_000_000.0)),
        salary_expense     = Float64(get(data, "salary_expense", 11_000_000.0)),
        supply_expense     = Float64(get(data, "supply_expense", 3_000_000.0)),
        other_expense      = Float64(get(data, "other_expense", 4_000_000.0)),
        cash_reserves      = Float64(get(data, "cash_reserves", 5_000_000.0)),
        depreciation       = Float64(get(data, "depreciation", 1_200_000.0)),
        annual_debt_service = Float64(get(data, "annual_debt_service", 800_000.0)),
        payer_mix_government = Float64(get(data, "payer_mix_government", 0.73)),
    )
end

"""Convert a YearlyProjection to a Dict for JSON serialization."""
function _projection_to_dict(p)
    Dict(
        "year"                  => p.year,
        "inpatient_revenue"     => round(p.inpatient_revenue, digits=2),
        "outpatient_revenue"    => round(p.outpatient_revenue, digits=2),
        "total_revenue"         => round(p.total_revenue, digits=2),
        "salary_expense"        => round(p.salary_expense, digits=2),
        "supply_expense"        => round(p.supply_expense, digits=2),
        "other_expense"         => round(p.other_expense, digits=2),
        "total_expense"         => round(p.total_expense, digits=2),
        "operating_income"      => round(p.operating_income, digits=2),
        "operating_margin"      => round(p.operating_margin, digits=4),
        "days_cash_on_hand"     => round(p.days_cash_on_hand, digits=1),
        "debt_service_coverage" => round(p.debt_service_coverage, digits=2),
        "patient_volume"        => round(p.patient_volume, digits=4),
        "payer_mix_government"  => round(p.payer_mix_government, digits=4),
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# Deterministic projection
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_deterministic(payload::Dict) -> Dict

Run a deterministic financial projection from JSON payload.

Expected payload keys:
  - `base_financials`: dict of base-year financial values
  - `params`: dict with projection_years, volume_growth_rate, cost_inflation_rate, etc.
"""
function handle_deterministic(payload::Dict)
    bf = _parse_base_financials(get(payload, "base_financials", Dict()))

    p = get(payload, "params", Dict())
    params = DeterministicParams(;
        projection_years        = Int(get(p, "projection_years", 10)),
        volume_growth_rate      = Float64(get(p, "volume_growth_rate", -0.01)),
        cost_inflation_rate     = Float64(get(p, "cost_inflation_rate", 0.03)),
        salary_inflation_rate   = Float64(get(p, "salary_inflation_rate", 0.035)),
        supply_inflation_rate   = Float64(get(p, "supply_inflation_rate", 0.04)),
        reimbursement_adjustment = Float64(get(p, "reimbursement_adjustment", 0.015)),
        payer_mix_shift         = Float64(get(p, "payer_mix_shift", 0.005)),
    )

    result = project_financials(bf, params)

    Dict(
        "status"                   => "success",
        "engine"                   => "deterministic",
        "run_id"                   => string(uuid4()),
        "timestamp"                => string(now()),
        "cumulative_operating_income" => round(result.cumulative_operating_income, digits=2),
        "terminal_operating_margin"  => round(result.terminal_operating_margin, digits=4),
        "closure_risk_year"          => result.closure_risk_year,
        "projections"                => [_projection_to_dict(p) for p in result.projections],
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# Monte Carlo simulation
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_monte_carlo(payload::Dict) -> Dict

Run a Monte Carlo simulation from JSON payload.

Expected payload keys:
  - `hospital` or `base_financials`: hospital data
  - `params`: n_iterations, projection_years, random_seed, distribution parameters
"""
function handle_monte_carlo(payload::Dict)
    bf = _parse_base_financials(get(payload, "base_financials", Dict()))

    p = get(payload, "params", Dict())
    n_iterations    = Int(get(p, "n_iterations", 1000))
    projection_years = Int(get(p, "projection_years", 5))
    random_seed     = Int(get(p, "random_seed", 42))

    params = MonteCarloParams(;
        n_iterations     = n_iterations,
        projection_years = projection_years,
        random_seed      = random_seed,
    )

    result = run_monte_carlo(bf, params)

    Dict(
        "status"               => "success",
        "engine"               => "monte_carlo",
        "run_id"               => string(uuid4()),
        "timestamp"            => string(now()),
        "n_iterations"         => n_iterations,
        "projection_years"     => projection_years,
        "mean_terminal_margin" => round(result.mean_terminal_margin, digits=4),
        "median_terminal_margin" => round(result.median_terminal_margin, digits=4),
        "probability_of_loss"  => round(result.probability_of_loss, digits=4),
        "percentiles"          => Dict(
            "p5"  => round(result.percentile_5_margin, digits=4),
            "p25" => round(result.percentile_25_margin, digits=4),
            "p50" => round(result.median_terminal_margin, digits=4),
            "p75" => round(result.percentile_75_margin, digits=4),
            "p95" => round(result.percentile_95_margin, digits=4),
        ),
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# Agent-Based Model
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_abm(payload::Dict) -> Dict

Run an agent-based simulation from JSON payload.
"""
function handle_abm(payload::Dict)
    p = get(payload, "params", Dict())

    params = ABMParams(;
        n_patients       = Int(get(p, "n_patients", 500)),
        n_providers      = Int(get(p, "n_providers", 20)),
        simulation_days  = Int(get(p, "simulation_days", 365)),
        random_seed      = Int(get(p, "random_seed", 42)),
    )

    hospitals = get(payload, "hospitals", [])
    result = run_abm(params, hospitals)

    Dict(
        "status"              => "success",
        "engine"              => "abm",
        "run_id"              => string(uuid4()),
        "timestamp"           => string(now()),
        "simulation_days"     => params.simulation_days,
        "total_patients"      => params.n_patients,
        "total_providers"     => params.n_providers,
        "final_volume_index"  => round(result.final_volume_index, digits=4),
        "final_staff_count"   => result.final_staff_count,
        "closure_occurred"    => result.closure_occurred,
        "closure_day"         => result.closure_day,
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# System Dynamics
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_system_dynamics(payload::Dict) -> Dict

Run a system dynamics ODE simulation from JSON payload.
"""
function handle_system_dynamics(payload::Dict)
    p = get(payload, "params", Dict())

    params = SystemDynamicsParams(;
        time_horizon_years       = Float64(get(p, "time_horizon_years", 10.0)),
        volume_growth_rate       = Float64(get(p, "volume_growth_rate", -0.02)),
        revenue_per_patient      = Float64(get(p, "revenue_per_patient", 3500.0)),
        cost_per_fte             = Float64(get(p, "cost_per_fte", 85000.0)),
        staff_turnover_rate      = Float64(get(p, "staff_turnover_rate", 0.15)),
        quality_volume_elasticity = Float64(get(p, "quality_volume_elasticity", 0.3)),
        community_health_impact  = Float64(get(p, "community_health_impact", 0.1)),
    )

    result = run_system_dynamics(params)

    Dict(
        "status"            => "success",
        "engine"            => "system_dynamics",
        "run_id"            => string(uuid4()),
        "timestamp"         => string(now()),
        "time_horizon"      => params.time_horizon_years,
        "final_volume"      => round(result.final_volume, digits=2),
        "final_revenue"     => round(result.final_revenue, digits=2),
        "final_staff"       => round(result.final_staff, digits=1),
        "final_quality"     => round(result.final_quality, digits=3),
        "final_cash"        => round(result.final_cash, digits=2),
        "equilibrium_reached" => result.equilibrium_reached,
        "time_series_length"  => length(result.time_points),
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# Discrete Event Simulation
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_des(payload::Dict) -> Dict

Run a discrete event simulation (ED throughput) from JSON payload.
"""
function handle_des(payload::Dict)
    p = get(payload, "params", Dict())

    params = DESParams(;
        simulation_hours    = Int(get(p, "simulation_hours", 720)),
        mean_arrival_rate   = Float64(get(p, "mean_arrival_rate", 2.5)),
        mean_triage_time    = Float64(get(p, "mean_triage_time", 0.25)),
        mean_treatment_time = Float64(get(p, "mean_treatment_time", 2.0)),
        mean_admission_time = Float64(get(p, "mean_admission_time", 4.0)),
        ed_beds             = Int(get(p, "ed_beds", 8)),
        admit_probability   = Float64(get(p, "admit_probability", 0.15)),
        random_seed         = Int(get(p, "random_seed", 42)),
    )

    result = run_des(params)

    Dict(
        "status"                 => "success",
        "engine"                 => "des",
        "run_id"                 => string(uuid4()),
        "timestamp"              => string(now()),
        "simulation_hours"       => params.simulation_hours,
        "total_patients"         => result.total_patients,
        "avg_wait_time"          => round(result.avg_wait_time, digits=2),
        "avg_length_of_stay"     => round(result.avg_length_of_stay, digits=2),
        "max_occupancy"          => result.max_occupancy,
        "patients_left_without_treatment" => result.lwbs_count,
        "bed_utilization"        => round(result.bed_utilization, digits=4),
    )
end

end # module SimulationController
