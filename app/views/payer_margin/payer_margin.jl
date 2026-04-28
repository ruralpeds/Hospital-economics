"""
Payer-Specific Margin Analysis UI - margin bars, waterfall chart.
"""

function ui_payer_margin(model)
    app_layout(model, "Payer Margin Analysis", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Payer-Specific Margin Analysis", class="q-mb-none"),
                p("Analyze profitability by payer class and identify cross-subsidization",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Analyze", icon="payments", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── KPIs ────────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Blended Margin", class="text-overline q-mb-none"),
                    h4("{{ (blended_margin_pct * 100).toFixed(1) }}%", class="q-mb-none",
                       var":class"="blended_margin_pct < 0 ? 'text-red' : 'text-green'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total Revenue", class="text-overline q-mb-none"),
                    h4("\${{ (total_revenue / 1e6).toFixed(1) }}M", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Best Payer", class="text-overline q-mb-none"),
                    h4("{{ best_payer }}", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Worst Payer", class="text-overline q-mb-none"),
                    h4("{{ worst_payer }}", class="q-mb-none text-red"),
                ])])
            ]),
        ]),

        # ── Inputs ──────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-xs-12", [
                card([card_section([
                    h6("Revenue by Payer", class="q-mb-md"),
                    textfield(:revenue_medicare, label="Medicare Revenue", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:revenue_medicaid, label="Medicaid Revenue", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:revenue_commercial, label="Commercial Revenue", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:revenue_self_pay, label="Self-Pay Revenue", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-3 col-xs-12", [
                card([card_section([
                    h6("Cost-to-Revenue Ratios", class="q-mb-md"),
                    p("Medicare: {{ cost_ratio_medicare.toFixed(2) }}x", class="q-mb-none"),
                    slider(:cost_ratio_medicare, min=0.70, max=1.30, step=0.01, label=true, class="q-mb-md"),
                    p("Medicaid: {{ cost_ratio_medicaid.toFixed(2) }}x", class="q-mb-none"),
                    slider(:cost_ratio_medicaid, min=0.80, max=1.50, step=0.01, label=true, class="q-mb-md"),
                    p("Commercial: {{ cost_ratio_commercial.toFixed(2) }}x", class="q-mb-none"),
                    slider(:cost_ratio_commercial, min=0.50, max=1.20, step=0.01, label=true, class="q-mb-md"),
                    p("Self-Pay: {{ cost_ratio_self_pay.toFixed(2) }}x", class="q-mb-none"),
                    slider(:cost_ratio_self_pay, min=0.80, max=2.00, step=0.01, label=true),
                ])])
            ]),
            cell(class="col-md-3 col-xs-12", [
                card([card_section([
                    plot(:margin_bar_data, layout=:margin_bar_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-3 col-xs-12", [
                card([card_section([
                    plot(:waterfall_data, layout=:waterfall_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Detail Table ────────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Payer Detail", class="q-mb-md"),
                    table(class="q-table", [
                        thead([tr([th("Payer"), th("Revenue"), th("Cost"), th("Margin"), th("Margin %"), th("% of Revenue")])]),
                        tbody([
                            tr(var"v-for"="(p, idx) in margin_by_payer", key!="idx", [
                                td(class="text-bold", "{{ p.payer }}"),
                                td("\${{ (p.revenue / 1e6).toFixed(2) }}M"),
                                td("\${{ (p.cost / 1e6).toFixed(2) }}M"),
                                td(var":class"="p.margin < 0 ? 'text-red' : 'text-green'",
                                   "\${{ (p.margin / 1e3).toFixed(0) }}K"),
                                td(var":class"="p.margin_pct < 0 ? 'text-red' : 'text-green'",
                                   "{{ p.margin_pct.toFixed(1) }}%"),
                                td("{{ p.pct_revenue.toFixed(1) }}%"),
                            ])
                        ]),
                    ])
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
