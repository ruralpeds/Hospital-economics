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
# API Routes — Health check & Observability
# ═══════════════════════════════════════════════════════════════════════════

# Include metrics module
include(joinpath(@__DIR__, "..", "..", "src", "observability", "metrics.jl"))
using .Metrics

const APP_VERSION = let
    toml_path = joinpath(@__DIR__, "..", "..", "Project.toml")
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

route("/healthz") do
    "OK"
end

route("/readyz") do
    if Metrics.check_db_ready()
        "OK"
    else
        json(Dict("status" => "error", "message" => "Database not ready"), status=503)
    end
end

route("/metrics") do
    Genie.Renderer.respond(Metrics.get_metrics_exposition(), Dict("Content-Type" => "text/plain; version=0.0.4"))
end
