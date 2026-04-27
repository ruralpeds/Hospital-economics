"""
Route definitions for the Rural Hospital Economics Simulator V3.
Maps URL paths to handler functions and Stipple reactive page models.

Routes organized into:
- Core pages (dashboard, profile, scenarios, simulation, results, education)
- Analysis tools (27 interactive tools)
- Strategic tools (REH conversion, closure risk, optimization)
- API endpoints (simulation, optimization, risk, import/export)
"""
using Genie.Router, Genie.Renderer.Html, Genie.Requests, Genie.Responses
using JSON3

"""Return a safe error message — log internals but don't expose them to clients."""
function _safe_error(label::String, e::Exception)
    @error "$label failed" exception=(e, catch_backtrace())
    json(Dict("status" => "error", "message" => "$label failed. Check server logs for details."), status=400)
end

# ═══════════════════════════════════════════════════════════════════════════
# Core Page Routes
# ═══════════════════════════════════════════════════════════════════════════

route("/") do
    redirect("/dashboard")
end

route("/dashboard") do
    model = dashboard_model |> init
    page(model, ui_dashboard) |> html
end

route("/profile") do
    model = hospital_profile_model |> init
    page(model, ui_hospital_profile) |> html
end

route("/scenarios") do
    model = scenario_model |> init
    page(model, ui_scenarios) |> html
end

route("/simulate") do
    model = simulation_runner_model |> init
    page(model, ui_simulation_runner) |> html
end

route("/results") do
    model = results_model |> init
    page(model, ui_results) |> html
end

route("/education") do
    model = education_model |> init
    page(model, ui_education) |> html
end

# ═══════════════════════════════════════════════════════════════════════════
# Analysis Tool Routes
# ═══════════════════════════════════════════════════════════════════════════

route("/financial-sim") do
    model = financial_sim_model |> init
    page(model, ui_financial_sim) |> html
end

route("/cost-structure") do
    model = cost_structure_model |> init
    page(model, ui_cost_structure) |> html
end

route("/cost-reimbursement") do
    model = cost_reimbursement_model |> init
    page(model, ui_cost_reimbursement) |> html
end

route("/payer-margin") do
    model = payer_margin_model |> init
    page(model, ui_payer_margin) |> html
end

route("/service-lines") do
    model = service_line_model |> init
    page(model, ui_service_line) |> html
end

route("/340b") do
    model = program_340b_model |> init
    page(model, ui_program_340b) |> html
end

route("/revenue-cycle") do
    model = revenue_cycle_model |> init
    page(model, ui_revenue_cycle) |> html
end

route("/break-even") do
    model = break_even_model |> init
    page(model, ui_break_even) |> html
end

route("/cash-flow") do
    model = cash_flow_model |> init
    page(model, ui_cash_flow) |> html
end

route("/sensitivity") do
    model = sensitivity_model |> init
    page(model, ui_sensitivity) |> html
end

route("/debt-capacity") do
    model = debt_capacity_model |> init
    page(model, ui_debt_capacity) |> html
end

route("/workforce") do
    model = workforce_rvu_model |> init
    page(model, ui_workforce_rvu) |> html
end

route("/benchmark") do
    model = benchmark_model |> init
    page(model, ui_benchmark) |> html
end

route("/three-statement") do
    model = three_statement_model |> init
    page(model, ui_three_statement) |> html
end

route("/dupont") do
    model = dupont_model |> init
    page(model, ui_dupont) |> html
end

route("/distress-scoring") do
    model = distress_scoring_model |> init
    page(model, ui_distress_scoring) |> html
end

# ═══════════════════════════════════════════════════════════════════════════
# Strategic Tool Routes
# ═══════════════════════════════════════════════════════════════════════════

route("/conversion") do
    model = reh_wizard_model |> init
    page(model, ui_reh_wizard) |> html
end

route("/closure-risk") do
    model = closure_risk_model |> init
    page(model, ui_closure_risk) |> html
end

route("/staffing") do
    model = staffing_model |> init
    page(model, ui_staffing) |> html
end

route("/payer-negotiation") do
    model = payer_negotiation_model |> init
    page(model, ui_payer_negotiation) |> html
end

route("/community-impact") do
    model = community_impact_model |> init
    page(model, ui_community_impact) |> html
end

route("/strategic-plan") do
    model = strategic_planner_model |> init
    page(model, ui_strategic_planner) |> html
end

route("/policy") do
    model = policy_impact_model |> init
    page(model, ui_policy_impact) |> html
end

# ═══════════════════════════════════════════════════════════════════════════
# V3.1 Module Routes
# ═══════════════════════════════════════════════════════════════════════════

route("/team-bundled") do
    model = team_bundled_model |> init
    page(model, ui_team_bundled) |> html
end

route("/telehealth") do
    model = telehealth_model |> init
    page(model, ui_telehealth) |> html
end

route("/vbc-transition") do
    model = vbc_transition_model |> init
    page(model, ui_vbc_transition) |> html
end

route("/medicaid-supplemental") do
    model = medicaid_supplemental_model |> init
    page(model, ui_medicaid_supplemental) |> html
end

route("/rhc-optimization") do
    model = rhc_optimization_model |> init
    page(model, ui_rhc_optimization) |> html
end

route("/sdoh") do
    model = sdoh_model |> init
    page(model, ui_sdoh) |> html
end

route("/geographic-access") do
    model = geographic_access_model |> init
    page(model, ui_geographic_access) |> html
end

route("/community-benefit") do
    model = community_benefit_model |> init
    page(model, ui_community_benefit) |> html
end

route("/network-economics") do
    model = network_economics_model |> init
    page(model, ui_network_economics) |> html
end

route("/disaster-resilience") do
    model = disaster_resilience_model |> init
    page(model, ui_disaster_resilience) |> html
end

route("/capital-scoring") do
    model = capital_scoring_model |> init
    page(model, ui_capital_scoring) |> html
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Simulation (delegated to SimulationController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/simulate/deterministic", method=POST) do
    try
        payload = jsonpayload()
        result = SimulationController.handle_deterministic(payload)
        json(result)
    catch e
        _safe_error("Deterministic simulation", e)
    end
end

route("/api/simulate/monte-carlo", method=POST) do
    try
        payload = jsonpayload()
        result = SimulationController.handle_monte_carlo(payload)
        json(result)
    catch e
        _safe_error("Monte Carlo simulation", e)
    end
end

route("/api/simulate/abm", method=POST) do
    try
        payload = jsonpayload()
        result = SimulationController.handle_abm(payload)
        json(result)
    catch e
        _safe_error("ABM simulation", e)
    end
end

route("/api/simulate/system-dynamics", method=POST) do
    try
        payload = jsonpayload()
        result = SimulationController.handle_system_dynamics(payload)
        json(result)
    catch e
        _safe_error("System dynamics simulation", e)
    end
end

route("/api/simulate/des", method=POST) do
    try
        payload = jsonpayload()
        result = SimulationController.handle_des(payload)
        json(result)
    catch e
        _safe_error("DES simulation", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Optimization (delegated to OptimizationController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/optimize/staffing", method=POST) do
    try
        payload = jsonpayload()
        result = OptimizationController.handle_staffing_optimization(payload)
        json(result)
    catch e
        _safe_error("Staffing optimization", e)
    end
end

route("/api/optimize/portfolio", method=POST) do
    try
        payload = jsonpayload()
        result = OptimizationController.handle_portfolio_optimization(payload)
        json(result)
    catch e
        _safe_error("Portfolio optimization", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Risk Assessment (delegated to RiskController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/risk/closure", method=POST) do
    try
        payload = jsonpayload()
        result = RiskController.handle_closure_risk(payload)
        json(result)
    catch e
        _safe_error("Closure risk assessment", e)
    end
end

route("/api/conversion", method=POST) do
    try
        payload = jsonpayload()
        result = RiskController.handle_reh_conversion(payload)
        json(result)
    catch e
        _safe_error("REH conversion analysis", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — MBA Analytics (delegated to AnalyticsController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/analytics/three-statement", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_three_statement(payload)
        json(result)
    catch e
        _safe_error("Three-statement projection", e)
    end
end

route("/api/analytics/dupont", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_dupont(payload)
        json(result)
    catch e
        _safe_error("DuPont decomposition", e)
    end
end

route("/api/analytics/distress-scoring", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_distress_scoring(payload)
        json(result)
    catch e
        _safe_error("Distress scoring", e)
    end
end

route("/api/import/hcris-auto", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_hcris_import(payload)
        json(result)
    catch e
        _safe_error("HCRIS import", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Data Import/Export (delegated to DataController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/import/hcris", method=POST) do
    try
        payload = jsonpayload()
        result = DataController.handle_hcris_import(payload)
        json(result)
    catch e
        _safe_error("HCRIS import", e)
    end
end

route("/api/import/csv", method=POST) do
    try
        payload = jsonpayload()
        result = DataController.handle_csv_import(payload)
        json(result)
    catch e
        _safe_error("CSV import", e)
    end
end

route("/api/export/csv", method=POST) do
    try
        payload = jsonpayload()
        result = DataController.handle_csv_export(payload)
        json(result)
    catch e
        _safe_error("CSV export", e)
    end
end

route("/api/export/json", method=POST) do
    try
        payload = jsonpayload()
        result = DataController.handle_json_export(payload)
        json(result)
    catch e
        _safe_error("JSON export", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Health check
# ═══════════════════════════════════════════════════════════════════════════

const APP_VERSION = let
    toml_path = joinpath(@__DIR__, "..", "Project.toml")
    m = match(r"version\s*=\s*\"([^\"]+)\"", read(toml_path, String))
    isnothing(m) ? "0.0.0" : m.captures[1]
end

const SIMULATION_ENGINES = ["deterministic", "monte_carlo", "abm", "system_dynamics", "des"]
const OPTIMIZER_ENGINES  = ["staffing", "portfolio"]
const RISK_MODELS        = ["closure_risk", "reh_conversion"]
const TOOL_COUNT         = 38

route("/api/health") do
    json(Dict(
        "status"     => "ok",
        "version"    => APP_VERSION,
        "timestamp"  => string(Dates.now()),
        "engines"    => SIMULATION_ENGINES,
        "optimizers" => OPTIMIZER_ENGINES,
        "risk_models" => RISK_MODELS,
        "tools"      => TOOL_COUNT,
    ))
end
