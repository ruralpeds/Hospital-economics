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

# A-04 & A-05: Nonprofit WACC and Capital Budgeting
route("/wacc") do
    include("views/wacc/WACCModel.jl")
    model = wacc_model |> init
    page(model, ui_wacc) |> html
end

route("/capex") do
    include("views/capex/CapexModel.jl")
    model = capex_model |> init
    page(model, ui_capex) |> html
end

# A-06: Medicare Advantage Risk Adjustment
route("/ma-risk") do
    include("views/ma_risk/MARiskModel.jl")
    model = ma_risk_model |> init
    page(model, ui_ma_risk) |> html
end

# A-08: RHC & CAH Reimbursement Comparison
route("/rhc-cah") do
    include("views/rhc_cah/RHCCAHModel.jl")
    model = rhc_cah_model |> init
    page(model, ui_rhc_cah) |> html
end

# A-07: VBC Bayesian Scenario Modeling
route("/vbc-bayesian") do
    include("views/vbc_bayesian/VBCBayesianModel.jl")
    model = vbc_bayesian_model |> init
    page(model, ui_vbc_bayesian) |> html
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

route("/drug-program-340b") do
    include("views/program_340b/Program340BModel.jl")
    model = program_340b_model |> init
    page(model, ui_program_340b) |> html
end

route("/telehealth") do
    include("views/telehealth/TelehealthModel.jl")
    model = telehealth_model |> init
    page(model, ui_telehealth) |> html
end

route("/medicaid-supplemental") do
    include("views/medicaid_supplemental/MedicaidSupplementalModel.jl")
    model = medicaid_supplemental_model |> init
    page(model, ui_medicaid_supplemental) |> html
end

route("/rhc-optimization") do
    model = rhc_optimization_model |> init
    page(model, ui_rhc_optimization) |> html
end

# ═══════════════════════════════════════════════════════════════════════════
# Concept Routes — Data
# ═══════════════════════════════════════════════════════════════════════════

route("/data/intake") do
    model = data_intake_model |> init
    page(model, ui_data_intake) |> html
end

route("/data/prepare") do
    model = data_prepare_model |> init
    page(model, ui_data_prepare) |> html
end

route("/cohorts") do
    model = cohorts_model |> init
    page(model, ui_cohorts) |> html
end

# ═══════════════════════════════════════════════════════════════════════════
# Concept Routes — Financial
# ═══════════════════════════════════════════════════════════════════════════

route("/cost-analysis") do
    model = cost_analysis_model |> init
    page(model, ui_cost_analysis) |> html
end

route("/revenue") do
    model = revenue_model |> init
    page(model, ui_revenue) |> html
end

route("/profitability") do
    model = profitability_model |> init
    page(model, ui_profitability) |> html
end

# ═══════════════════════════════════════════════════════════════════════════
# Concept Routes — Clinical
# ═══════════════════════════════════════════════════════════════════════════

route("/quality") do
    model = quality_model |> init
    page(model, ui_quality) |> html
end

# ═══════════════════════════════════════════════════════════════════════════
# Concept Routes — Statistical
# ═══════════════════════════════════════════════════════════════════════════

route("/stats") do
    model = stats_model |> init
    page(model, ui_stats) |> html
end

route("/regression") do
    model = regression_model |> init
    page(model, ui_regression) |> html
end

route("/causal") do
    model = causal_model |> init
    page(model, ui_causal) |> html
end

# ═══════════════════════════════════════════════════════════════════════════
# Concept Routes — Economic Evaluation
# ═══════════════════════════════════════════════════════════════════════════

route("/cea") do
    model = cea_model |> init
    page(model, ui_cea) |> html
end

route("/cba") do
    model = cba_model |> init
    page(model, ui_cba) |> html
end

route("/comparative") do
    model = comparative_model |> init
    page(model, ui_comparative) |> html
end

# ═══════════════════════════════════════════════════════════════════════════
# Concept Routes — Advanced
# ═══════════════════════════════════════════════════════════════════════════

route("/visualize") do
    model = visualize_model |> init
    page(model, ui_visualize) |> html
end

route("/reports") do
    model = reports_model |> init
    page(model, ui_reports) |> html
end

route("/database") do
    model = database_model |> init
    page(model, ui_database) |> html
end

route("/ml") do
    model = ml_model |> init
    page(model, ui_ml) |> html
end

route("/systems") do
    model = systems_model |> init
    page(model, ui_systems) |> html
end

route("/scenario-lab") do
    model = scenario_lab_model |> init
    page(model, ui_scenario_lab) |> html
end

route("/functions") do
    model = functions_model |> init
    page(model, ui_functions) |> html
end

# ═══════════════════════════════════════════════════════════════════════════
# Concept Routes — Governance
# ═══════════════════════════════════════════════════════════════════════════

route("/audit") do
    model = audit_model |> init
    page(model, ui_audit) |> html
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

# A-06: Medicare Advantage Risk Adjustment
route("/api/risk/ma-risk", method=POST) do
    try
        payload = jsonpayload()
        result = RiskController.handle_ma_risk(payload)
        json(result)
    catch e
        _safe_error("MA risk adjustment", e)
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

# A-04: Nonprofit WACC Calculator
route("/api/analytics/wacc", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_wacc(payload)
        json(result)
    catch e
        _safe_error("WACC calculation", e)
    end
end

# A-05: Capital Budgeting
route("/api/optimize/capex-ranking", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_capex_ranking(payload)
        json(result)
    catch e
        _safe_error("CapEx ranking", e)
    end
end

route("/api/analytics/rhc-cah", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_rhc_cah_comparison(payload)
        json(result)
    catch e
        _safe_error("RHC/CAH comparison", e)
    end
end

route("/api/analytics/vbc-bayesian", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_vbc_bayesian(payload)
        json(result)
    catch e
        _safe_error("VBC Bayesian sampling", e)
    end
end

route("/api/analytics/vbc-compare-scenarios", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_vbc_compare_scenarios(payload)
        json(result)
    catch e
        _safe_error("VBC scenario comparison", e)
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

route("/api/analytics/340b-savings", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_340b_savings(payload)
        json(result)
    catch e
        _safe_error("340B savings estimation", e)
    end
end

route("/api/analytics/telehealth-valuation", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_telehealth_valuation(payload)
        json(result)
    catch e
        _safe_error("Telehealth valuation", e)
    end
end

route("/api/analytics/rpm-impact", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_rpm_impact(payload)
        json(result)
    catch e
        _safe_error("RPM impact assessment", e)
    end
end

route("/api/analytics/medicaid-dsh", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_medicaid_dsh_analysis(payload)
        json(result)
    catch e
        _safe_error("Medicaid DSH analysis", e)
    end
end

route("/api/analytics/rhc-optimization", method=POST) do
    try
        payload = jsonpayload()
        result = AnalyticsController.handle_rhc_optimization(payload)
        json(result)
    catch e
        _safe_error("RHC optimization", e)
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

route("/api/data/upload", method=POST) do
    try
        payload = jsonpayload()
        result = DataController.handle_universal_upload(payload)
        json(result)
    catch e
        _safe_error("Universal upload", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Bug Report (public, no auth required)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/bugreport", method=POST) do
    try
        payload    = jsonpayload()
        remote_ip  = string(get(Genie.Requests.header("X-Forwarded-For"), "0.0.0.0"))
        session_id = let c = Genie.Cookies.get("_session_id")
            isnothing(c) ? "anonymous" : string(c)
        end
        result = BugReportController.handle_submit(
            payload isa AbstractDict ? payload : Dict{String,Any}();
            remote_ip  = remote_ip,
            session_id = session_id,
        )
        json(result["body"], status=result["status"])
    catch e
        _safe_error("Bug report submission", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Universal upload (E2 component-library intake)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/data/upload", method=POST) do
    try
        payload = jsonpayload()
        result = DataController.handle_universal_upload(payload)
        json(result)
    catch e
        _safe_error("Universal upload", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Bug report submission (E27 BugReport component → GitHub issue)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/bugreport", method=POST) do
    try
        payload    = jsonpayload()
        remote_ip  = string(get(Genie.Requests.header("X-Forwarded-For"), "0.0.0.0"))
        session_id = let c = Genie.Cookies.get("_session_id")
            isnothing(c) ? "anonymous" : string(c)
        end
        result = BugReportController.handle_submit(
            payload isa AbstractDict ? payload : Dict{String,Any}();
            remote_ip  = remote_ip,
            session_id = session_id,
        )
        json(result["body"], status=result["status"])
    catch e
        _safe_error("Bug report submission", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# Dev-only routes — Component library showcase  (disabled when GENIE_ENV=prod)
# ═══════════════════════════════════════════════════════════════════════════

if get(ENV, "GENIE_ENV", "dev") != "prod"
    route("/dev/components") do
        model = dev_components_model |> init
        page(model, ui_dev_components) |> html
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

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Data Ingestion (E4, delegated to IngestionController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/ingest/hospital", method=POST) do
    try
        payload = jsonpayload()
        result = IngestionController.handle_hospital(payload)
        json(result)
    catch e
        _safe_error("Hospital data ingestion", e)
    end
end

route("/api/ingest/claims", method=POST) do
    try
        payload = jsonpayload()
        result = IngestionController.handle_claims(payload)
        json(result)
    catch e
        _safe_error("Claims data ingestion", e)
    end
end

route("/api/ingest/clinical", method=POST) do
    try
        payload = jsonpayload()
        result = IngestionController.handle_clinical(payload)
        json(result)
    catch e
        _safe_error("Clinical data ingestion", e)
    end
end

route("/api/ingest/financial", method=POST) do
    try
        payload = jsonpayload()
        result = IngestionController.handle_financial(payload)
        json(result)
    catch e
        _safe_error("Financial data ingestion", e)
    end
end

route("/api/ingest/registry", method=POST) do
    try
        payload = jsonpayload()
        result = IngestionController.handle_registry(payload)
        json(result)
    catch e
        _safe_error("Registry data ingestion", e)
    end
end

route("/api/ingest/validate", method=POST) do
    try
        payload = jsonpayload()
        result = IngestionController.handle_validate(payload)
        json(result)
    catch e
        _safe_error("Data validation", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Data Preparation (E5, delegated to PreparationController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/prepare/normalize", method=POST) do
    try
        payload = jsonpayload()
        result = PreparationController.handle_normalize(payload)
        json(result)
    catch e
        _safe_error("ID normalization", e)
    end
end

route("/api/prepare/standardize", method=POST) do
    try
        payload = jsonpayload()
        result = PreparationController.handle_standardize(payload)
        json(result)
    catch e
        _safe_error("Code standardization", e)
    end
end

route("/api/prepare/aggregate", method=POST) do
    try
        payload = jsonpayload()
        result = PreparationController.handle_aggregate(payload)
        json(result)
    catch e
        _safe_error("Episode aggregation", e)
    end
end

route("/api/prepare/risk-adjust", method=POST) do
    try
        payload = jsonpayload()
        result = PreparationController.handle_risk_adjust(payload)
        json(result)
    catch e
        _safe_error("Risk adjustment", e)
    end
end

route("/api/prepare/impute", method=POST) do
    try
        payload = jsonpayload()
        result = PreparationController.handle_impute(payload)
        json(result)
    catch e
        _safe_error("Imputation", e)
    end
end

route("/api/prepare/time-series", method=POST) do
    try
        payload = jsonpayload()
        result = PreparationController.handle_time_series(payload)
        json(result)
    catch e
        _safe_error("Time-series formatting", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Cohort Builder (E6, delegated to CohortsController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/cohorts/preview", method=POST) do
    try
        payload = jsonpayload()
        result = CohortsController.handle_preview(payload)
        json(result)
    catch e
        _safe_error("Cohort preview", e)
    end
end

route("/api/cohorts/save", method=POST) do
    try
        payload = jsonpayload()
        result = CohortsController.handle_save(payload)
        json(result)
    catch e
        _safe_error("Cohort save", e)
    end
end

route("/api/cohorts", method=GET) do
    try
        result = CohortsController.handle_list()
        json(result)
    catch e
        _safe_error("Cohort list", e)
    end
end

route("/api/cohorts/:id", method=GET) do
    try
        result = CohortsController.handle_get(params(:id))
        json(result)
    catch e
        _safe_error("Cohort get", e)
    end
end

route("/api/cohorts/:id", method=DELETE) do
    try
        result = CohortsController.handle_delete(params(:id))
        json(result)
    catch e
        _safe_error("Cohort delete", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Cost Analysis (E7, delegated to CostAnalysisController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/cost-analysis/total", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_total(payload)
        json(result)
    catch e
        _safe_error("Cost total", e)
    end
end

route("/api/cost-analysis/breakdown", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_breakdown(payload)
        json(result)
    catch e
        _safe_error("Cost breakdown", e)
    end
end

route("/api/cost-analysis/per-episode", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_per_episode(payload)
        json(result)
    catch e
        _safe_error("Per-episode cost", e)
    end
end

route("/api/cost-analysis/cpq", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_cpq(payload)
        json(result)
    catch e
        _safe_error("Cost per QALY", e)
    end
end

route("/api/cost-analysis/high-cost", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_high_cost(payload)
        json(result)
    catch e
        _safe_error("High-cost patient identification", e)
    end
end

route("/api/cost-analysis/project", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_project(payload)
        json(result)
    catch e
        _safe_error("Cost projection", e)
    end
end

route("/api/cost-analysis/inflate", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_inflate(payload)
        json(result)
    catch e
        _safe_error("Cost inflation adjustment", e)
    end
end

route("/api/cost-analysis/cohort-summary", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_cohort_summary(payload)
        json(result)
    catch e
        _safe_error("Cohort cost summary", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Revenue & Reimbursement (E8, delegated to RevenueController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/revenue/total", method=POST) do
    try
        payload = jsonpayload()
        result = RevenueController.handle_total(payload)
        json(result)
    catch e
        _safe_error("Revenue total", e)
    end
end

route("/api/revenue/denied", method=POST) do
    try
        payload = jsonpayload()
        result = RevenueController.handle_denied(payload)
        json(result)
    catch e
        _safe_error("Denied claims analysis", e)
    end
end

route("/api/revenue/payor-mix", method=POST) do
    try
        payload = jsonpayload()
        result = RevenueController.handle_payor_mix(payload)
        json(result)
    catch e
        _safe_error("Payer mix analysis", e)
    end
end

route("/api/revenue/provider-payment", method=POST) do
    try
        payload = jsonpayload()
        result = RevenueController.handle_provider_payment(payload)
        json(result)
    catch e
        _safe_error("Provider payment analysis", e)
    end
end

route("/api/revenue/simulate", method=POST) do
    try
        payload = jsonpayload()
        result = RevenueController.handle_simulate(payload)
        json(result)
    catch e
        _safe_error("Revenue simulation", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Profitability & Operations (E9, delegated to ProfitabilityController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/profitability/contrib-margin", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_contrib_margin(payload)
        json(result)
    catch e
        _safe_error("Contribution margin", e)
    end
end

route("/api/profitability/by-dept", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_by_dept(payload)
        json(result)
    catch e
        _safe_error("Departmental profitability", e)
    end
end

route("/api/profitability/fixed-variable", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_fixed_variable(payload)
        json(result)
    catch e
        _safe_error("Fixed-variable decomposition", e)
    end
end

route("/api/profitability/break-even", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_break_even(payload)
        json(result)
    catch e
        _safe_error("Break-even analysis", e)
    end
end

route("/api/profitability/operating-margin", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_operating_margin(payload)
        json(result)
    catch e
        _safe_error("Operating margin", e)
    end
end

route("/api/profitability/margin-decomp", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_margin_decomp(payload)
        json(result)
    catch e
        _safe_error("Margin decomposition", e)
    end
end

route("/api/profitability/ratios", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_ratios(payload)
        json(result)
    catch e
        _safe_error("Profitability ratios", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Quality & Clinical Outcomes (E10)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/quality/readmission", method=POST) do
    try
        payload = jsonpayload()
        result = QualityController.handle_readmission(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Quality readmission", e)
    end
end

route("/api/quality/mortality", method=POST) do
    try
        payload = jsonpayload()
        result = QualityController.handle_mortality(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Quality mortality", e)
    end
end

route("/api/quality/infection", method=POST) do
    try
        payload = jsonpayload()
        result = QualityController.handle_infection(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Quality infection", e)
    end
end

route("/api/quality/psi", method=POST) do
    try
        payload = jsonpayload()
        result = QualityController.handle_psi(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Quality PSI", e)
    end
end

route("/api/quality/qol", method=POST) do
    try
        payload = jsonpayload()
        result = QualityController.handle_qol(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Quality QoL", e)
    end
end

route("/api/quality/disparities", method=POST) do
    try
        payload = jsonpayload()
        result = QualityController.handle_disparities(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Quality disparities", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Statistics (E11)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/stats/descriptive", method=POST) do
    try; result = StatsController.handle_descriptive(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats descriptive", e); end
end

route("/api/stats/ttest", method=POST) do
    try; result = StatsController.handle_ttest(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats t-test", e); end
end

route("/api/stats/anova", method=POST) do
    try; result = StatsController.handle_anova(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats ANOVA", e); end
end

route("/api/stats/chisquare", method=POST) do
    try; result = StatsController.handle_chisquare(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats chi-square", e); end
end

route("/api/stats/logrank", method=POST) do
    try; result = StatsController.handle_logrank(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats log-rank", e); end
end

route("/api/stats/ci", method=POST) do
    try; result = StatsController.handle_ci(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats CI", e); end
end

route("/api/stats/table1", method=POST) do
    try; result = StatsController.handle_table1(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats Table1", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Regression (E12)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/regression/ols", method=POST) do
    try; result = RegressionController.handle_ols(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Regression OLS", e); end
end

route("/api/regression/logistic", method=POST) do
    try; result = RegressionController.handle_logistic(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Regression logistic", e); end
end

route("/api/regression/poisson", method=POST) do
    try; result = RegressionController.handle_poisson(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Regression Poisson", e); end
end

route("/api/regression/negbin", method=POST) do
    try; result = RegressionController.handle_negbin(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Regression NegBin", e); end
end

route("/api/regression/cox", method=POST) do
    try; result = RegressionController.handle_cox(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Regression Cox", e); end
end

route("/api/regression/diagnostics", method=POST) do
    try; result = RegressionController.handle_diagnostics(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Regression diagnostics", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Causal Inference (E13)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/causal/psm", method=POST) do
    try; result = CausalController.handle_psm(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Causal PSM", e); end
end

route("/api/causal/iv", method=POST) do
    try; result = CausalController.handle_iv(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Causal IV", e); end
end

route("/api/causal/did", method=POST) do
    try; result = CausalController.handle_did(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Causal DiD", e); end
end

route("/api/causal/rdd", method=POST) do
    try; result = CausalController.handle_rdd(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Causal RDD", e); end
end

route("/api/causal/hte", method=POST) do
    try; result = CausalController.handle_hte(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Causal HTE", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — CEA (E14)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/cea/icer", method=POST) do
    try; result = CEAController.handle_icer(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CEA ICER", e); end
end

route("/api/cea/ceac", method=POST) do
    try; result = CEAController.handle_ceac(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CEA CEAC", e); end
end

route("/api/cea/sensitivity", method=POST) do
    try; result = CEAController.handle_sensitivity(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CEA sensitivity", e); end
end

route("/api/cea/monte-carlo", method=POST) do
    try; result = CEAController.handle_monte_carlo(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CEA Monte Carlo", e); end
end

route("/api/cea/analyze", method=POST) do
    try; result = CEAController.handle_analyze(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CEA analyze", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — CBA (E15)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/cba/npv", method=POST) do
    try; result = CBAController.handle_npv(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CBA NPV", e); end
end

route("/api/cba/roi", method=POST) do
    try; result = CBAController.handle_roi(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CBA ROI", e); end
end

route("/api/cba/bcr", method=POST) do
    try; result = CBAController.handle_bcr(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CBA BCR", e); end
end

route("/api/cba/break-even", method=POST) do
    try; result = CBAController.handle_break_even(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CBA break-even", e); end
end

route("/api/cba/budget-impact", method=POST) do
    try; result = CBAController.handle_budget_impact(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CBA budget impact", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Comparative Effectiveness (E16)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/comparative/outcomes", method=POST) do
    try; result = ComparativeController.handle_outcomes(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative outcomes", e); end
end

route("/api/comparative/patterns", method=POST) do
    try; result = ComparativeController.handle_patterns(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative patterns", e); end
end

route("/api/comparative/variation", method=POST) do
    try; result = ComparativeController.handle_variation(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative variation", e); end
end

route("/api/comparative/benchmark", method=POST) do
    try; result = ComparativeController.handle_benchmark(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative benchmark", e); end
end

route("/api/comparative/smr", method=POST) do
    try; result = ComparativeController.handle_smr(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative SMR", e); end
end

route("/api/comparative/subgroup", method=POST) do
    try; result = ComparativeController.handle_subgroup(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative subgroup", e); end
end

route("/api/comparative/interaction", method=POST) do
    try; result = ComparativeController.handle_interaction(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative interaction", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Visualization (E17)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/visualize/render", method=POST) do
    try; result = VisualizeController.handle_render(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Visualize render", e); end
end

route("/api/visualize/export", method=POST) do
    try; result = VisualizeController.handle_export(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Visualize export", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Reports (E18)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/reports/generate", method=POST) do
    try; result = ReportsController.handle_generate(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Reports generate", e); end
end

route("/api/reports/export-pdf", method=POST) do
    try; result = ReportsController.handle_export_pdf(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Reports export PDF", e); end
end

route("/api/reports/export-xlsx", method=POST) do
    try; result = ReportsController.handle_export_xlsx(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Reports export XLSX", e); end
end

route("/api/reports/preview", method=POST) do
    try; result = ReportsController.handle_preview(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Reports preview", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Database (E19)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/database/query-patients", method=POST) do
    try; result = DatabaseController.handle_query_patients(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database query patients", e); end
end

route("/api/database/query-claims", method=POST) do
    try; result = DatabaseController.handle_query_claims(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database query claims", e); end
end

route("/api/database/query-encounters", method=POST) do
    try; result = DatabaseController.handle_query_encounters(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database query encounters", e); end
end

route("/api/database/query-financial", method=POST) do
    try; result = DatabaseController.handle_query_financial(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database query financial", e); end
end

route("/api/database/save-result", method=POST) do
    try; result = DatabaseController.handle_save_result(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database save result", e); end
end

route("/api/database/save-version", method=POST) do
    try; result = DatabaseController.handle_save_version(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database save version", e); end
end

route("/api/database/retrieve-archived", method=POST) do
    try; result = DatabaseController.handle_retrieve_archived(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database retrieve archived", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — ML (E20)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/ml/train", method=POST) do
    try; result = MLController.handle_train(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("ML train", e); end
end

route("/api/ml/predict", method=POST) do
    try; result = MLController.handle_predict(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("ML predict", e); end
end

route("/api/ml/predict-batch", method=POST) do
    try; result = MLController.handle_predict_batch(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("ML predict batch", e); end
end

route("/api/ml/anomaly", method=POST) do
    try; result = MLController.handle_anomaly(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("ML anomaly", e); end
end

route("/api/ml/stratify", method=POST) do
    try; result = MLController.handle_stratify(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("ML stratify", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Systems (E21)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/systems/referral-network", method=POST) do
    try; result = SystemsController.handle_referral_network(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Systems referral network", e); end
end

route("/api/systems/care-gaps", method=POST) do
    try; result = SystemsController.handle_care_gaps(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Systems care gaps", e); end
end

route("/api/systems/team-composition", method=POST) do
    try; result = SystemsController.handle_team_composition(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Systems team composition", e); end
end

route("/api/systems/simulate-pathway", method=POST) do
    try; result = SystemsController.handle_simulate_pathway(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Systems simulate pathway", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Scenario Lab (E22)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/scenario/best-case", method=POST) do
    try; result = ScenarioLabController.handle_best_case(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Scenario best-case", e); end
end

route("/api/scenario/base-case", method=POST) do
    try; result = ScenarioLabController.handle_base_case(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Scenario base-case", e); end
end

route("/api/scenario/worst-case", method=POST) do
    try; result = ScenarioLabController.handle_worst_case(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Scenario worst-case", e); end
end

route("/api/scenario/one-way", method=POST) do
    try; result = ScenarioLabController.handle_one_way(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Scenario one-way", e); end
end

route("/api/scenario/two-way", method=POST) do
    try; result = ScenarioLabController.handle_two_way(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Scenario two-way", e); end
end

route("/api/scenario/psa", method=POST) do
    try; result = ScenarioLabController.handle_psa(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Scenario PSA", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Function Explorer (E23)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/fn/:name", method=POST) do
    try
        payload = jsonpayload()
        result = FunctionController.handle_invoke(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Function invoke", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Audit (E24)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/audit/set-config", method=POST) do
    try; result = AuditController.handle_set_config(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Audit set config", e); end
end

route("/api/audit/log", method=POST) do
    try; result = AuditController.handle_log(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Audit log", e); end
end

route("/api/audit/generate-log", method=POST) do
    try; result = AuditController.handle_generate_log(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Audit generate log", e); end
end

route("/api/audit/deidentify", method=POST) do
    try; result = AuditController.handle_deidentify(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Audit deidentify", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# Dev-only routes — Component Library showcase
# Disabled in production (GENIE_ENV == "prod")
# ═══════════════════════════════════════════════════════════════════════════

if get(ENV, "GENIE_ENV", "dev") != "prod"
    route("/dev/components") do
        model = dev_components_model |> init
        page(model, ui_dev_components) |> html
    end

    # Individual component demo sub-routes (alias to same page with hash)
    for comp in ["form_grid", "result_table", "plot_panel",
                 "export_bar", "cohort_picker", "scenario_picker",
                 "audit_log_viewer"]
        local _comp = comp
        route("/dev/components/$(_comp)") do
            redirect("/dev/components#sec-$(replace(_comp, "_" => ""))")
        end
    end
end
