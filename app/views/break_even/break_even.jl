"""
Break-Even Analysis UI - dual-axis chart, target volume indicator.
"""

function ui_break_even(model)
    app_layout(model, "Break-Even Analysis", [
        loading_overlay("is_loading"),

        page_header("Break-Even Analysis",
            "Calculate break-even volume and margin of safety",
            breadcrumbs=["Dashboard" => "/dashboard", "Finance" => "#", "Break-Even Analysis" => ""]),

        row(class="q-mb-md items-center", [
            cell(class="col-auto", [
                btn("Calculate", icon="balance", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── KPIs ────────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Break-Even Volume", class="text-overline q-mb-none"),
                    h5("{{ break_even_volume.toLocaleString() }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Current Volume", class="text-overline q-mb-none"),
                    h5("{{ current_volume.toLocaleString() }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Contribution/Unit", class="text-overline q-mb-none"),
                    h5("\${{ contribution_margin_per_unit.toFixed(0) }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Net Income", class="text-overline q-mb-none"),
                    h5("\${{ (current_net_income / 1e6).toFixed(2) }}M", class="q-mb-none",
                       var":class"="current_net_income < 0 ? 'text-red' : 'text-green'"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Volume Cushion", class="text-overline q-mb-none"),
                    h5("{{ cushion_encounters.toLocaleString() }}", class="q-mb-none text-green"),
                    p("{{ (cushion_pct * 100).toFixed(1) }}% margin", class="text-caption"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Margin of Safety", class="text-overline q-mb-none"),
                    h5("{{ (margin_of_safety * 100).toFixed(1) }}%", class="q-mb-none",
                       var":class"="margin_of_safety < 0.05 ? 'text-red' : 'text-green'"),
                ])])
            ]),
        ]),

        # ── Inputs and Chart ────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-xs-12", [
                card([card_section([
                    h6("Cost Structure", class="q-mb-md"),
                    textfield(:fixed_costs, label="Fixed Costs (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:variable_cost_per_encounter, label="Variable Cost/Encounter (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:revenue_per_encounter, label="Revenue/Encounter (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:current_volume, label="Current Annual Volume", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-9 col-xs-12", [
                card([card_section([
                    plot(:breakeven_chart_data, layout=:breakeven_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
