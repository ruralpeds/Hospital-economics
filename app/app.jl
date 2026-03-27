"""
Rural Hospital Economics Simulator - Main Application Entry Point
A Genie.jl + Stipple.jl web application for modeling rural hospital financial viability.
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
# Include reactive models
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "dashboard", "DashboardModel.jl"))
include(joinpath(APP_ROOT, "views", "hospital_profile", "HospitalProfileModel.jl"))
include(joinpath(APP_ROOT, "views", "scenarios", "ScenarioModel.jl"))
include(joinpath(APP_ROOT, "views", "simulation_runner", "SimulationRunnerModel.jl"))
include(joinpath(APP_ROOT, "views", "results", "ResultsModel.jl"))
include(joinpath(APP_ROOT, "views", "education", "EducationModel.jl"))
include(joinpath(APP_ROOT, "views", "reh_wizard", "REHWizardModel.jl"))
include(joinpath(APP_ROOT, "views", "closure_risk", "ClosureRiskModel.jl"))
include(joinpath(APP_ROOT, "views", "staffing", "StaffingModel.jl"))

# ---------------------------------------------------------------------------
# Include view functions
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "dashboard", "dashboard.jl"))
include(joinpath(APP_ROOT, "views", "hospital_profile", "hospital_profile.jl"))
include(joinpath(APP_ROOT, "views", "scenarios", "scenarios.jl"))
include(joinpath(APP_ROOT, "views", "simulation_runner", "simulation_runner.jl"))
include(joinpath(APP_ROOT, "views", "results", "results.jl"))
include(joinpath(APP_ROOT, "views", "education", "education.jl"))
include(joinpath(APP_ROOT, "views", "reh_wizard", "reh_wizard.jl"))
include(joinpath(APP_ROOT, "views", "closure_risk", "closure_risk.jl"))
include(joinpath(APP_ROOT, "views", "staffing", "staffing.jl"))

# ---------------------------------------------------------------------------
# Include routes
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "routes.jl"))

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------
function start(; port::Int = 8000, host::String = "0.0.0.0", async::Bool = false)
    load_config()
    @info "Starting Rural Hospital Economics Simulator on $host:$port"
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
