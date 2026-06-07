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
