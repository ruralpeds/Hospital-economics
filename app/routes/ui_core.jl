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

# F-03: CFO 1-Pager Dashboard
route("/cfo") do
    model = cfo_dashboard_model |> init
    page(model, ui_cfo_dashboard) |> html
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
# V3.1 Module Routes
# ═══════════════════════════════════════════════════════════════════════════

route("/team-bundled") do
    model = team_bundled_model |> init
    page(model, ui_team_bundled) |> html
end


route("/vbc-transition") do
    model = vbc_transition_model |> init
    page(model, ui_vbc_transition) |> html
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
