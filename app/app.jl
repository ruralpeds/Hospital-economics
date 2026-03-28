"""
Rural Hospital Economics Simulator - Main Application Entry Point
A Genie.jl + Stipple.jl web application for modeling rural hospital financial viability.

V3.0 — 27 interactive tools, 6 simulation engines, education center
"""
module HospitalEconomicsApp

using Genie, Genie.Router, Genie.Renderer.Html
using Stipple, StippleUI, StipplePlotly
using Logging, Dates

# ---------------------------------------------------------------------------
# Bootstrap helpers
# ---------------------------------------------------------------------------
const APP_ROOT = @__DIR__

function load_config()
    env = get(ENV, "GENIE_ENV", "dev")
    cfg_path = joinpath(APP_ROOT, "config", "env", "$(env).jl")
    isfile(cfg_path) && include(cfg_path)
    init_path = joinpath(APP_ROOT, "config", "initializers", "logging.jl")
    isfile(init_path) && include(init_path)
    @info "Loaded configuration for environment: $env"
end

# ---------------------------------------------------------------------------
# Include shared layout
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "layouts", "app_layout.jl"))

# ---------------------------------------------------------------------------
# Include reactive models — Core views
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "dashboard", "DashboardModel.jl"))
include(joinpath(APP_ROOT, "views", "hospital_profile", "HospitalProfileModel.jl"))
include(joinpath(APP_ROOT, "views", "scenarios", "ScenarioModel.jl"))
include(joinpath(APP_ROOT, "views", "simulation_runner", "SimulationRunnerModel.jl"))
include(joinpath(APP_ROOT, "views", "results", "ResultsModel.jl"))
include(joinpath(APP_ROOT, "views", "education", "EducationModel.jl"))

# ---------------------------------------------------------------------------
# Include reactive models — Analysis tools
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "financial_sim", "FinancialSimModel.jl"))
include(joinpath(APP_ROOT, "views", "cost_structure", "CostStructureModel.jl"))
include(joinpath(APP_ROOT, "views", "cost_reimbursement", "CostReimbursementModel.jl"))
include(joinpath(APP_ROOT, "views", "payer_margin", "PayerMarginModel.jl"))
include(joinpath(APP_ROOT, "views", "service_line", "ServiceLineModel.jl"))
include(joinpath(APP_ROOT, "views", "program_340b", "Program340BModel.jl"))
include(joinpath(APP_ROOT, "views", "revenue_cycle", "RevenueCycleModel.jl"))
include(joinpath(APP_ROOT, "views", "break_even", "BreakEvenModel.jl"))
include(joinpath(APP_ROOT, "views", "cash_flow", "CashFlowModel.jl"))
include(joinpath(APP_ROOT, "views", "sensitivity", "SensitivityModel.jl"))
include(joinpath(APP_ROOT, "views", "debt_capacity", "DebtCapacityModel.jl"))
include(joinpath(APP_ROOT, "views", "workforce_rvu", "WorkforceRVUModel.jl"))
include(joinpath(APP_ROOT, "views", "benchmark", "BenchmarkModel.jl"))

# ---------------------------------------------------------------------------
# Include reactive models — Strategic tools
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "reh_wizard", "REHWizardModel.jl"))
include(joinpath(APP_ROOT, "views", "closure_risk", "ClosureRiskModel.jl"))
include(joinpath(APP_ROOT, "views", "staffing", "StaffingModel.jl"))
include(joinpath(APP_ROOT, "views", "payer_negotiation", "PayerNegotiationModel.jl"))
include(joinpath(APP_ROOT, "views", "community_impact", "CommunityImpactModel.jl"))
include(joinpath(APP_ROOT, "views", "strategic_planner", "StrategicPlannerModel.jl"))
include(joinpath(APP_ROOT, "views", "policy_impact", "PolicyImpactModel.jl"))

# ---------------------------------------------------------------------------
# Include view functions — Core views
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "dashboard", "dashboard.jl"))
include(joinpath(APP_ROOT, "views", "hospital_profile", "hospital_profile.jl"))
include(joinpath(APP_ROOT, "views", "scenarios", "scenarios.jl"))
include(joinpath(APP_ROOT, "views", "simulation_runner", "simulation_runner.jl"))
include(joinpath(APP_ROOT, "views", "results", "results.jl"))
include(joinpath(APP_ROOT, "views", "education", "education.jl"))

# ---------------------------------------------------------------------------
# Include view functions — Analysis tools
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "financial_sim", "financial_sim.jl"))
include(joinpath(APP_ROOT, "views", "cost_structure", "cost_structure.jl"))
include(joinpath(APP_ROOT, "views", "cost_reimbursement", "cost_reimbursement.jl"))
include(joinpath(APP_ROOT, "views", "payer_margin", "payer_margin.jl"))
include(joinpath(APP_ROOT, "views", "service_line", "service_line.jl"))
include(joinpath(APP_ROOT, "views", "program_340b", "program_340b.jl"))
include(joinpath(APP_ROOT, "views", "revenue_cycle", "revenue_cycle.jl"))
include(joinpath(APP_ROOT, "views", "break_even", "break_even.jl"))
include(joinpath(APP_ROOT, "views", "cash_flow", "cash_flow.jl"))
include(joinpath(APP_ROOT, "views", "sensitivity", "sensitivity.jl"))
include(joinpath(APP_ROOT, "views", "debt_capacity", "debt_capacity.jl"))
include(joinpath(APP_ROOT, "views", "workforce_rvu", "workforce_rvu.jl"))
include(joinpath(APP_ROOT, "views", "benchmark", "benchmark.jl"))

# ---------------------------------------------------------------------------
# Include view functions — Strategic tools
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "reh_wizard", "reh_wizard.jl"))
include(joinpath(APP_ROOT, "views", "closure_risk", "closure_risk.jl"))
include(joinpath(APP_ROOT, "views", "staffing", "staffing.jl"))
include(joinpath(APP_ROOT, "views", "payer_negotiation", "payer_negotiation.jl"))
include(joinpath(APP_ROOT, "views", "community_impact", "community_impact.jl"))
include(joinpath(APP_ROOT, "views", "strategic_planner", "strategic_planner.jl"))
include(joinpath(APP_ROOT, "views", "policy_impact", "policy_impact.jl"))

# ---------------------------------------------------------------------------
# Include routes
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "routes.jl"))

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------
function start(; port::Int = 8000, host::String = "0.0.0.0", async::Bool = false)
    load_config()
    @info "Starting Rural Hospital Economics Simulator v0.2.0 on $host:$port"
    @info "27 interactive tools | 6 simulation engines | Education center"
    Genie.config.run_as_server = true
    Genie.config.server_host = host
    Genie.config.server_port = port
    Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
    Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"

    up(port; async = async)
end

export start

end # module
