"""
Rural Hospital Economics Simulator - Main Application Entry Point
A Genie.jl + Stipple.jl web application for modeling rural hospital financial viability.

V3.2 — 38 interactive tools, 6 simulation engines, full API, education center
"""
module HospitalEconomicsApp

using Genie, Genie.Router, Genie.Renderer.Html
using Stipple, StippleUI, StipplePlotly
using Logging, Dates, HTTP

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
    db_init_path = joinpath(APP_ROOT, "config", "initializers", "db.jl")
    isfile(db_init_path) && include(db_init_path)
    @info "Loaded configuration for environment: $env"
end

# ---------------------------------------------------------------------------
# Security modules (P0-1, P0-2)
# middleware.jl includes auth.jl and rbac.jl internally
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "..", "src", "security", "middleware.jl"))
include(joinpath(APP_ROOT, "..", "src", "security", "encryption.jl"))

using .SecurityMiddleware
using .SecurityMiddleware.Auth
using .SecurityMiddleware.RBAC
using .Encryption

# ---------------------------------------------------------------------------
# Observability (P0-6)
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "..", "src", "observability", "health.jl"))
using .Health

# ---------------------------------------------------------------------------
# Reusable component library  (app/components/)
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "components", "form_grid.jl"))
include(joinpath(APP_ROOT, "components", "result_table.jl"))
include(joinpath(APP_ROOT, "components", "plot_panel.jl"))
include(joinpath(APP_ROOT, "components", "export_bar.jl"))
include(joinpath(APP_ROOT, "components", "cohort_picker.jl"))
include(joinpath(APP_ROOT, "components", "scenario_picker.jl"))
include(joinpath(APP_ROOT, "components", "audit_log_viewer.jl"))
include(joinpath(APP_ROOT, "components", "upload.jl"))

# ---------------------------------------------------------------------------
# Include shared layout
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "layouts", "app_layout.jl"))

# ---------------------------------------------------------------------------
# Include shared component library (must come before view files)
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "components", "common.jl"))
include(joinpath(APP_ROOT, "components", "page_template.jl"))

# ---------------------------------------------------------------------------
# Include BugReport component + controller (E27)
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "components", "bug_report_redaction.jl"))
include(joinpath(APP_ROOT, "components", "bug_report.jl"))
include(joinpath(APP_ROOT, "controllers", "BugReportController.jl"))

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
# Include reactive models — MBA Analytics (M1 Starter)
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "three_statement", "ThreeStatementModel.jl"))
include(joinpath(APP_ROOT, "views", "dupont", "DuPontModel.jl"))
include(joinpath(APP_ROOT, "views", "distress_scoring", "DistressScoringModel.jl"))

# ---------------------------------------------------------------------------
# Include reactive models — V3.1 modules
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "team_bundled", "TEAMBundledModel.jl"))
include(joinpath(APP_ROOT, "views", "telehealth", "TelehealthModel.jl"))
include(joinpath(APP_ROOT, "views", "vbc_transition", "VBCTransitionModel.jl"))
include(joinpath(APP_ROOT, "views", "medicaid_supplemental", "MedicaidSupplementalModel.jl"))
include(joinpath(APP_ROOT, "views", "rhc_optimization", "RHCOptimizationModel.jl"))
include(joinpath(APP_ROOT, "views", "sdoh", "SDOHModel.jl"))
include(joinpath(APP_ROOT, "views", "geographic_access", "GeographicAccessModel.jl"))
include(joinpath(APP_ROOT, "views", "community_benefit", "CommunityBenefitModel.jl"))
include(joinpath(APP_ROOT, "views", "network_economics", "NetworkEconomicsModel.jl"))
include(joinpath(APP_ROOT, "views", "disaster_resilience", "DisasterResilienceModel.jl"))
include(joinpath(APP_ROOT, "views", "capital_scoring", "CapitalScoringModel.jl"))

# ---------------------------------------------------------------------------
# Include reactive models — E4–E9 new concept tabs
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "data_intake", "DataIntakeModel.jl"))
include(joinpath(APP_ROOT, "views", "data_prepare", "DataPrepareModel.jl"))
include(joinpath(APP_ROOT, "views", "cohorts", "CohortsModel.jl"))
include(joinpath(APP_ROOT, "views", "cost_analysis", "CostAnalysisModel.jl"))
include(joinpath(APP_ROOT, "views", "revenue", "RevenueModel.jl"))
include(joinpath(APP_ROOT, "views", "profitability", "ProfitabilityModel.jl"))

# ---------------------------------------------------------------------------
# Include reactive models — E10–E24 new concept tabs
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "quality", "QualityModel.jl"))
include(joinpath(APP_ROOT, "views", "stats", "StatsModel.jl"))
include(joinpath(APP_ROOT, "views", "regression", "RegressionModel.jl"))
include(joinpath(APP_ROOT, "views", "causal", "CausalModel.jl"))
include(joinpath(APP_ROOT, "views", "cea", "CEAModel.jl"))
include(joinpath(APP_ROOT, "views", "cba", "CBAModel.jl"))
include(joinpath(APP_ROOT, "views", "comparative", "ComparativeModel.jl"))
include(joinpath(APP_ROOT, "views", "visualize", "VisualizeModel.jl"))
include(joinpath(APP_ROOT, "views", "reports", "ReportsModel.jl"))
include(joinpath(APP_ROOT, "views", "database", "DatabaseModel.jl"))
include(joinpath(APP_ROOT, "views", "ml", "MLModel.jl"))
include(joinpath(APP_ROOT, "views", "systems", "SystemsModel.jl"))
include(joinpath(APP_ROOT, "views", "scenario_lab", "ScenarioLabModel.jl"))
include(joinpath(APP_ROOT, "views", "functions", "FunctionsModel.jl"))
include(joinpath(APP_ROOT, "views", "audit", "AuditModel.jl"))

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
# Include view functions — MBA Analytics (M1 Starter)
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "three_statement", "three_statement.jl"))
include(joinpath(APP_ROOT, "views", "dupont", "dupont.jl"))
include(joinpath(APP_ROOT, "views", "distress_scoring", "distress_scoring.jl"))

# ---------------------------------------------------------------------------
# Include view functions — V3.1 modules
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "team_bundled", "team_bundled.jl"))
include(joinpath(APP_ROOT, "views", "telehealth", "telehealth.jl"))
include(joinpath(APP_ROOT, "views", "vbc_transition", "vbc_transition.jl"))
include(joinpath(APP_ROOT, "views", "medicaid_supplemental", "medicaid_supplemental.jl"))
include(joinpath(APP_ROOT, "views", "rhc_optimization", "rhc_optimization.jl"))
include(joinpath(APP_ROOT, "views", "sdoh", "sdoh.jl"))
include(joinpath(APP_ROOT, "views", "geographic_access", "geographic_access.jl"))
include(joinpath(APP_ROOT, "views", "community_benefit", "community_benefit.jl"))
include(joinpath(APP_ROOT, "views", "network_economics", "network_economics.jl"))
include(joinpath(APP_ROOT, "views", "disaster_resilience", "disaster_resilience.jl"))
include(joinpath(APP_ROOT, "views", "capital_scoring", "capital_scoring.jl"))

# ---------------------------------------------------------------------------
# Include view functions — E4–E9 new concept tabs
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "data_intake", "data_intake.jl"))
include(joinpath(APP_ROOT, "views", "data_prepare", "data_prepare.jl"))
include(joinpath(APP_ROOT, "views", "cohorts", "cohorts.jl"))
include(joinpath(APP_ROOT, "views", "cost_analysis", "cost_analysis.jl"))
include(joinpath(APP_ROOT, "views", "revenue", "revenue.jl"))
include(joinpath(APP_ROOT, "views", "profitability", "profitability.jl"))

# ---------------------------------------------------------------------------
# Include view functions — E10–E24 new concept tabs
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "views", "quality", "quality.jl"))
include(joinpath(APP_ROOT, "views", "stats", "stats.jl"))
include(joinpath(APP_ROOT, "views", "regression", "regression.jl"))
include(joinpath(APP_ROOT, "views", "causal", "causal.jl"))
include(joinpath(APP_ROOT, "views", "cea", "cea.jl"))
include(joinpath(APP_ROOT, "views", "cba", "cba.jl"))
include(joinpath(APP_ROOT, "views", "comparative", "comparative.jl"))
include(joinpath(APP_ROOT, "views", "visualize", "visualize.jl"))
include(joinpath(APP_ROOT, "views", "reports", "reports.jl"))
include(joinpath(APP_ROOT, "views", "database", "database.jl"))
include(joinpath(APP_ROOT, "views", "ml", "ml.jl"))
include(joinpath(APP_ROOT, "views", "systems", "systems.jl"))
include(joinpath(APP_ROOT, "views", "scenario_lab", "scenario_lab.jl"))
include(joinpath(APP_ROOT, "views", "functions", "functions.jl"))
include(joinpath(APP_ROOT, "views", "audit", "audit.jl"))

# F-03: CFO 1-Pager Dashboard
include(joinpath(APP_ROOT, "views", "cfo_dashboard", "CFODashboardModel.jl"))
include(joinpath(APP_ROOT, "views", "cfo_dashboard", "cfo_dashboard.jl"))

# ---------------------------------------------------------------------------
# Include API controllers
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "controllers", "SimulationController.jl"))
include(joinpath(APP_ROOT, "controllers", "OptimizationController.jl"))
include(joinpath(APP_ROOT, "controllers", "RiskController.jl"))
include(joinpath(APP_ROOT, "controllers", "DataController.jl"))
include(joinpath(APP_ROOT, "controllers", "AnalyticsController.jl"))

# ---------------------------------------------------------------------------
# Include API controllers — E4–E9 new concept tabs
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "controllers", "IngestionController.jl"))
include(joinpath(APP_ROOT, "controllers", "PreparationController.jl"))
include(joinpath(APP_ROOT, "controllers", "CohortsController.jl"))
include(joinpath(APP_ROOT, "controllers", "CostAnalysisController.jl"))
include(joinpath(APP_ROOT, "controllers", "RevenueController.jl"))
include(joinpath(APP_ROOT, "controllers", "ProfitabilityController.jl"))

# ---------------------------------------------------------------------------
# Include API controllers — E10–E24 new concept tabs
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "controllers", "QualityController.jl"))
include(joinpath(APP_ROOT, "controllers", "StatsController.jl"))
include(joinpath(APP_ROOT, "controllers", "RegressionController.jl"))
include(joinpath(APP_ROOT, "controllers", "CausalController.jl"))
include(joinpath(APP_ROOT, "controllers", "CEAController.jl"))
include(joinpath(APP_ROOT, "controllers", "CBAController.jl"))
include(joinpath(APP_ROOT, "controllers", "ComparativeController.jl"))
include(joinpath(APP_ROOT, "controllers", "VisualizeController.jl"))
include(joinpath(APP_ROOT, "controllers", "ReportsController.jl"))
include(joinpath(APP_ROOT, "controllers", "DatabaseController.jl"))
include(joinpath(APP_ROOT, "controllers", "MLController.jl"))
include(joinpath(APP_ROOT, "controllers", "SystemsController.jl"))
include(joinpath(APP_ROOT, "controllers", "ScenarioLabController.jl"))
include(joinpath(APP_ROOT, "..", "src", "utils", "function_registry.jl"))
include(joinpath(APP_ROOT, "controllers", "FunctionController.jl"))
include(joinpath(APP_ROOT, "controllers", "AuditController.jl"))

# ---------------------------------------------------------------------------
# Dev-only component library demo (disabled in production)
# ---------------------------------------------------------------------------
if get(ENV, "GENIE_ENV", "dev") != "prod"
    include(joinpath(APP_ROOT, "views", "dev", "DevComponentsModel.jl"))
    include(joinpath(APP_ROOT, "views", "dev", "dev_components.jl"))
end

# ---------------------------------------------------------------------------
# Include routes
# ---------------------------------------------------------------------------
include(joinpath(APP_ROOT, "routes.jl"))

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------
function start(; port::Int = 8000, host::String = "0.0.0.0", async::Bool = false)
    load_config()
    @info "Starting Rural Hospital Economics Simulator v1.1.0 on $host:$port"
    @info "38 interactive tools | 6 simulation engines | Full API | Education center"
    Genie.config.run_as_server = true
    Genie.config.server_host = host
    Genie.config.server_port = port
    allowed_origin = get(ENV, "ALLOWED_ORIGIN", "*")
    Genie.config.cors_headers["Access-Control-Allow-Origin"] = allowed_origin
    Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"

    # Register middleware stack (P0-1)
    if get(ENV, "RHSIM_AUTH_ENABLED", "true") == "true"
        Genie.Router.push_middleware!(SecurityMiddleware.auth_middleware)
        @info "Auth middleware enabled"
    end
    Genie.Router.push_middleware!(SecurityMiddleware.security_headers_middleware)
    @info "Security headers middleware enabled"

    up(port; async = async)
end

export start

end # module
