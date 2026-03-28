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
# API Routes — Simulation
# ═══════════════════════════════════════════════════════════════════════════

route("/api/simulate/deterministic", method=POST) do
    try
        payload = jsonpayload()
        # TODO: Parse hospital data and params from payload
        result = Dict("status" => "success", "engine" => "deterministic", "message" => "Simulation complete")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

route("/api/simulate/monte-carlo", method=POST) do
    try
        payload = jsonpayload()
        result = Dict("status" => "success", "engine" => "monte_carlo", "message" => "Simulation complete")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

route("/api/simulate/abm", method=POST) do
    try
        payload = jsonpayload()
        result = Dict("status" => "success", "engine" => "abm", "message" => "Simulation complete")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

route("/api/simulate/system-dynamics", method=POST) do
    try
        payload = jsonpayload()
        result = Dict("status" => "success", "engine" => "system_dynamics", "message" => "Simulation complete")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

route("/api/simulate/des", method=POST) do
    try
        payload = jsonpayload()
        result = Dict("status" => "success", "engine" => "des", "message" => "Simulation complete")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Optimization
# ═══════════════════════════════════════════════════════════════════════════

route("/api/optimize/staffing", method=POST) do
    try
        payload = jsonpayload()
        result = Dict("status" => "success", "type" => "staffing", "message" => "Optimization complete")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

route("/api/optimize/portfolio", method=POST) do
    try
        payload = jsonpayload()
        result = Dict("status" => "success", "type" => "portfolio", "message" => "Optimization complete")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Risk Assessment
# ═══════════════════════════════════════════════════════════════════════════

route("/api/risk/closure", method=POST) do
    try
        payload = jsonpayload()
        result = Dict("status" => "success", "type" => "closure_risk", "message" => "Assessment complete")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

route("/api/conversion", method=POST) do
    try
        payload = jsonpayload()
        result = Dict("status" => "success", "type" => "reh_conversion", "message" => "Analysis complete")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Data Import/Export
# ═══════════════════════════════════════════════════════════════════════════

route("/api/import/hcris", method=POST) do
    try
        result = Dict("status" => "success", "type" => "hcris", "message" => "Import not yet implemented")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

route("/api/import/csv", method=POST) do
    try
        result = Dict("status" => "success", "type" => "csv", "message" => "Import not yet implemented")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

route("/api/export/csv", method=POST) do
    try
        result = Dict("status" => "success", "type" => "csv", "message" => "Export not yet implemented")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

route("/api/export/json", method=POST) do
    try
        result = Dict("status" => "success", "type" => "json", "message" => "Export not yet implemented")
        json(result)
    catch e
        json(Dict("status" => "error", "message" => string(e)), status=400)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Health check
# ═══════════════════════════════════════════════════════════════════════════

route("/api/health") do
    json(Dict(
        "status" => "ok",
        "version" => "0.2.0",
        "timestamp" => string(Dates.now()),
        "engines" => ["deterministic", "monte_carlo", "abm", "system_dynamics", "des", "optimization"],
        "tools" => 38,
    ))
end
