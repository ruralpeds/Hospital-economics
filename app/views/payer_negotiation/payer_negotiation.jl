"""
Payer Negotiation Simulator UI - editable rate table, revenue comparison bars.
"""

function ui_payer_negotiation(model)
    app_layout(model, "Payer Negotiation Simulator", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Payer Negotiation Simulator", class="q-mb-none"),
                p("Model rate changes by service category and project revenue impact",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate", icon="handshake", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Summary KPIs ────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Current Revenue", class="text-overline q-mb-none"),
                    h4("\${{ (total_current_revenue / 1e6).toFixed(2) }}M", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Proposed Revenue", class="text-overline q-mb-none"),
                    h4("\${{ (total_proposed_revenue / 1e6).toFixed(2) }}M", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Revenue Increase", class="text-overline q-mb-none"),
                    h4("+\${{ (total_revenue_increase / 1e3).toFixed(0) }}K", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Overall Rate Improvement", class="text-overline q-mb-none"),
                    h4("+{{ (overall_rate_improvement * 100).toFixed(1) }}%", class="q-mb-none text-green"),
                ])])
            ]),
        ]),

        # ── Category Inputs ─────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Service Category Rate Table", class="q-mb-md"),
                    row(class="q-gutter-sm q-mb-sm text-bold", [
                        cell(class="col-2", [span("Category")]),
                        cell(class="col-2", [span("Volume")]),
                        cell(class="col-2", [span("Avg Charge")]),
                        cell(class="col-2", [span("Current Rate")]),
                        cell(class="col-2", [span("Proposed Rate")]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-2", [textfield(:cat1_name, dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat1_volume, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat1_charges, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat1_current_rate, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat1_proposed_rate, type="number", dense=true, filled=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-2", [textfield(:cat2_name, dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat2_volume, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat2_charges, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat2_current_rate, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat2_proposed_rate, type="number", dense=true, filled=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-2", [textfield(:cat3_name, dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat3_volume, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat3_charges, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat3_current_rate, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat3_proposed_rate, type="number", dense=true, filled=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-2", [textfield(:cat4_name, dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat4_volume, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat4_charges, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat4_current_rate, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat4_proposed_rate, type="number", dense=true, filled=true)]),
                    ]),
                    row(class="q-gutter-sm", [
                        cell(class="col-2", [textfield(:cat5_name, dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat5_volume, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat5_charges, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat5_current_rate, type="number", dense=true, filled=true)]),
                        cell(class="col-2", [textfield(:cat5_proposed_rate, type="number", dense=true, filled=true)]),
                    ]),
                ])])
            ]),
        ]),

        # ── Charts ──────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:revenue_comparison_data, layout=:revenue_comparison_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:increase_data, layout=:increase_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
