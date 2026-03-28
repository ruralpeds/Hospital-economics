"""
RHC Optimization UI - Rural Health Clinic AIR revenue optimization.
"""

function ui_rhc_optimization(model)
    app_layout(model, "RHC Optimization", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Rural Health Clinic Optimization", class="q-mb-none"),
                p("AIR revenue optimization with service line expansion modeling", class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Optimize", icon="tune", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Current AIR", class="text-overline q-mb-none"),
                    h4("\${{ current_air.toFixed(2) }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Optimized AIR", class="text-overline q-mb-none"),
                    h4("\${{ optimized_air.toFixed(2) }}", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Revenue Increase", class="text-overline q-mb-none"),
                    h4("+\${{ (revenue_increase / 1e3).toFixed(0) }}K", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Optimized Revenue", class="text-overline q-mb-none"),
                    h4("\${{ (optimized_revenue / 1e6).toFixed(2) }}M", class="q-mb-none text-blue"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Current Operations", class="q-mb-md"),
                    textfield(:annual_visits, label="Annual Visits", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:current_cost_per_visit, label="Current Cost/Visit (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:payment_cap_per_visit, label="Payment Cap/Visit (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:opps_rate, label="OPPS Rate for Comparison (\$)", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Service Expansion", class="q-mb-md"),
                    textfield(:behavioral_health_visits, label="Behavioral Health Visits/Year", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:telehealth_visits, label="Telehealth Visits/Year", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:ccm_eligible_patients, label="CCM Eligible Patients", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:ccm_monthly_revenue, label="CCM Monthly Revenue (\$)", type="number", filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Recommendations ────────────────────────────────────────────
        card(class="q-mb-lg", [card_section([
            h6("Recommendations", class="q-mb-md"),
            q__list(dense=true, [
                item(var"v-for"="(rec, idx) in recommendations", key!="idx", [
                    item_section(avatar=true, [q__icon(name="lightbulb", color="amber")]),
                    item_section([item_label("{{ rec }}")]),
                ]),
            ]),
        ])]),

        # ── Charts ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:revenue_chart_data, layout=:revenue_chart_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:comparison_data, layout=:comparison_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
