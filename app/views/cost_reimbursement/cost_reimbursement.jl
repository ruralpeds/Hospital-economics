"""
Cost-Based Reimbursement Simulator UI - allocation flow table, CCR bar chart.
"""

function ui_cost_reimbursement(model)
    app_layout(model, "Cost-Based Reimbursement", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Cost-Based Reimbursement Simulator", class="q-mb-none"),
                p("Model step-down cost allocation and cost-to-charge ratios for CAH 101% reimbursement",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate", icon="account_tree", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── KPIs ────────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total Costs", class="text-overline q-mb-none"),
                    h4("\${{ (total_costs / 1e6).toFixed(1) }}M", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Overall CCR", class="text-overline q-mb-none"),
                    h4("{{ (overall_ccr * 100).toFixed(1) }}%", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("101% Reimbursement", class="text-overline q-mb-none"),
                    h4("\${{ (reimbursement_101pct / 1e6).toFixed(2) }}M", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Reimbursement Gap (1%)", class="text-overline q-mb-none"),
                    h4("\${{ (reimbursement_gap / 1e3).toFixed(0) }}K", class="q-mb-none text-green"),
                ])])
            ]),
        ]),

        # ── Inputs ──────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Department Costs", class="q-mb-md"),
                    textfield(:cost_admin, label="Administration", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cost_nursing, label="Nursing", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cost_ancillary, label="Ancillary", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cost_pharmacy, label="Pharmacy", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cost_lab, label="Lab", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cost_imaging, label="Imaging", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cost_ed, label="Emergency Dept", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cost_dietary, label="Dietary", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cost_plant, label="Plant Operations", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Revenue Center Charges", class="q-mb-md"),
                    textfield(:charges_inpatient, label="Inpatient Charges", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:charges_outpatient, label="Outpatient Charges", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:charges_ed, label="ED Charges", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:charges_lab, label="Lab Charges", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:charges_imaging, label="Imaging Charges", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:charges_pharmacy, label="Pharmacy Charges", type="number", filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── CCR Chart ───────────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:ccr_chart_data, layout=:ccr_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Step-Down Allocation Table ──────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Step-Down Cost Allocation (\$K)", class="q-mb-md"),
                    table(class="q-table", [
                        thead([tr([th("Department"), th("Direct Cost"), th("Allocated"), th("Total"), th("Method")])]),
                        tbody([
                            tr(var"v-for"="(row, idx) in step_down_table", key!="idx", [
                                td("{{ row.dept }}"),
                                td("\${{ row.direct_cost }}K"),
                                td("\${{ row.allocated }}K"),
                                td(class="text-bold", "\${{ row.total }}K"),
                                td(class="text-caption text-grey", "{{ row.method }}"),
                            ])
                        ]),
                    ])
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
