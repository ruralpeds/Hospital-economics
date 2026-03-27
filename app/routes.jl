"""
Route definitions for the Rural Hospital Economics Simulator.
Maps URL paths to handler functions and Stipple reactive page models.
"""
using Genie.Router, Genie.Renderer.Html, Genie.Requests, Genie.Responses
using JSON3

# ═══════════════════════════════════════════════════════════════════════════
# Page Routes - each renders a Stipple reactive page inside the app layout
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

# ═══════════════════════════════════════════════════════════════════════════
# API Endpoints - JSON data for AJAX / programmatic access
# ═══════════════════════════════════════════════════════════════════════════

route("/api/v1/hospitals", method = GET) do
    hospitals = [
        Dict("id" => 1, "name" => "Prairie View Community Hospital", "state" => "KS",
             "beds" => 25, "type" => "CAH", "status" => "active"),
        Dict("id" => 2, "name" => "Mountain Valley Medical Center", "state" => "MT",
             "beds" => 15, "type" => "CAH", "status" => "active"),
        Dict("id" => 3, "name" => "Delta Regional Hospital", "state" => "MS",
             "beds" => 49, "type" => "PPS", "status" => "at_risk"),
        Dict("id" => 4, "name" => "High Plains Health", "state" => "NE",
             "beds" => 20, "type" => "CAH", "status" => "active"),
    ]
    json(hospitals)
end

route("/api/v1/hospitals/:id", method = GET) do
    id = parse(Int, payload(:id))
    hospital = Dict(
        "id" => id, "name" => "Prairie View Community Hospital",
        "state" => "KS", "beds" => 25, "type" => "CAH",
        "annual_revenue" => 18_500_000, "annual_expenses" => 19_200_000,
        "operating_margin" => -0.038, "case_mix_index" => 0.85,
        "medicare_pct" => 0.62, "medicaid_pct" => 0.18,
        "commercial_pct" => 0.12, "self_pay_pct" => 0.08,
        "fte_count" => 142, "avg_daily_census" => 8.3,
        "ed_visits_annual" => 4200, "outpatient_visits" => 12800,
    )
    json(hospital)
end

route("/api/v1/kpis/:hospital_id", method = GET) do
    hid = parse(Int, payload(:hospital_id))
    kpis = Dict(
        "hospital_id" => hid,
        "operating_margin" => -0.038,
        "total_margin" => -0.021,
        "days_cash_on_hand" => 42,
        "current_ratio" => 1.35,
        "debt_to_capitalization" => 0.48,
        "net_patient_revenue" => 18_500_000,
        "cost_per_adjusted_discharge" => 12_450,
        "fte_per_aob" => 5.8,
        "average_age_of_plant" => 14.2,
        "medicare_cost_report_margin" => -0.052,
        "outpatient_revenue_pct" => 0.58,
        "ed_visits" => 4200,
        "avg_daily_census" => 8.3,
        "case_mix_index" => 0.85,
        "bad_debt_pct" => 0.062,
    )
    json(kpis)
end

route("/api/v1/scenarios", method = GET) do
    scenarios = [
        Dict("id" => 1, "name" => "Baseline", "description" => "Current trajectory, no changes",
             "created_at" => "2026-01-15", "status" => "completed"),
        Dict("id" => 2, "name" => "REH Conversion", "description" => "Convert to Rural Emergency Hospital",
             "created_at" => "2026-02-01", "status" => "completed"),
        Dict("id" => 3, "name" => "Telehealth Expansion", "description" => "Add telehealth services",
             "created_at" => "2026-02-20", "status" => "draft"),
    ]
    json(scenarios)
end

route("/api/v1/simulate", method = POST) do
    payload = jsonpayload()
    result = Dict(
        "simulation_id" => "sim_" * string(rand(10000:99999)),
        "status" => "running",
        "methodology" => get(payload, "methodology", "monte_carlo"),
        "iterations" => get(payload, "iterations", 1000),
        "started_at" => string(Dates.now()),
    )
    json(result)
end

route("/api/v1/simulate/:sim_id/status", method = GET) do
    sim_id = payload(:sim_id)
    status = Dict(
        "simulation_id" => sim_id,
        "status" => "completed",
        "progress" => 100,
        "iterations_completed" => 1000,
        "elapsed_seconds" => 12.4,
    )
    json(status)
end

route("/api/v1/results/:sim_id", method = GET) do
    sim_id = payload(:sim_id)
    results = Dict(
        "simulation_id" => sim_id,
        "summary" => Dict(
            "mean_operating_margin" => -0.025,
            "median_operating_margin" => -0.022,
            "p10_margin" => -0.089,
            "p90_margin" => 0.031,
            "probability_positive_margin" => 0.32,
            "probability_closure" => 0.18,
            "breakeven_year" => 2028,
            "npv_10yr" => -2_340_000,
        ),
        "annual_projections" => [
            Dict("year" => 2026, "revenue" => 18_800_000, "expenses" => 19_100_000, "margin" => -0.016),
            Dict("year" => 2027, "revenue" => 19_200_000, "expenses" => 19_400_000, "margin" => -0.010),
            Dict("year" => 2028, "revenue" => 19_700_000, "expenses" => 19_650_000, "margin" => 0.003),
            Dict("year" => 2029, "revenue" => 20_100_000, "expenses" => 19_900_000, "margin" => 0.010),
            Dict("year" => 2030, "revenue" => 20_600_000, "expenses" => 20_200_000, "margin" => 0.019),
        ],
    )
    json(results)
end

route("/api/v1/closure-risk/:hospital_id", method = GET) do
    hid = parse(Int, payload(:hospital_id))
    risk = Dict(
        "hospital_id" => hid,
        "overall_risk_score" => 72,
        "risk_level" => "high",
        "financial_distress_index" => 0.78,
        "factors" => [
            Dict("name" => "Operating Margin Trend", "score" => 85, "weight" => 0.25),
            Dict("name" => "Cash Reserves", "score" => 70, "weight" => 0.20),
            Dict("name" => "Volume Trends", "score" => 65, "weight" => 0.15),
            Dict("name" => "Payer Mix", "score" => 75, "weight" => 0.15),
            Dict("name" => "Community Demographics", "score" => 60, "weight" => 0.10),
            Dict("name" => "Competition/Proximity", "score" => 55, "weight" => 0.10),
            Dict("name" => "Regulatory Environment", "score" => 50, "weight" => 0.05),
        ],
    )
    json(risk)
end

route("/api/v1/staffing/:hospital_id", method = GET) do
    hid = parse(Int, payload(:hospital_id))
    staffing = Dict(
        "hospital_id" => hid,
        "total_fte" => 142.5,
        "departments" => [
            Dict("name" => "Nursing", "fte" => 52.0, "benchmark" => 48.0, "variance" => 4.0),
            Dict("name" => "Administration", "fte" => 18.5, "benchmark" => 15.0, "variance" => 3.5),
            Dict("name" => "Ancillary", "fte" => 24.0, "benchmark" => 22.0, "variance" => 2.0),
            Dict("name" => "Support Services", "fte" => 28.0, "benchmark" => 26.0, "variance" => 2.0),
            Dict("name" => "Physicians/Providers", "fte" => 12.0, "benchmark" => 12.0, "variance" => 0.0),
            Dict("name" => "Emergency", "fte" => 8.0, "benchmark" => 8.0, "variance" => 0.0),
        ],
        "cost_per_fte" => 68_500,
        "labor_cost_pct_revenue" => 0.527,
    )
    json(staffing)
end

# ═══════════════════════════════════════════════════════════════════════════
# Export endpoint for downloadable reports
# ═══════════════════════════════════════════════════════════════════════════

route("/api/v1/export/:sim_id", method = GET) do
    sim_id = payload(:sim_id)
    format = params(:format, "csv")
    content_type = format == "csv" ? "text/csv" : "application/json"
    Genie.Responses.setheaders(Dict("Content-Type" => content_type,
                                     "Content-Disposition" => "attachment; filename=\"simulation_$(sim_id).$(format)\""))
    if format == "csv"
        return "Year,Revenue,Expenses,Margin\n2026,18800000,19100000,-0.016\n2027,19200000,19400000,-0.010\n2028,19700000,19650000,0.003\n"
    else
        json(Dict("simulation_id" => sim_id, "exported_at" => string(Dates.now())))
    end
end
