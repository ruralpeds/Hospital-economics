"""
Service Line Analytics Dashboard View
"""
function ui_service_line_analytics(model)
    app_layout(model, "Service Lines", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Service Line Analytics Dashboard", class="q-mb-none"),
                p("Analyze cost, risk, quality, and volume across hospital service lines",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Recalculate", icon="refresh", color="primary",
                    @click("recalculate = true")),
            ]),
        ]),

        # ── Controls ───────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                textfield(:selected_service_line, label="Select Service Line", placeholder="all",
                          filled=true, dense=true, class="q-mb-sm"),
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                textfield(:comparison_type, label="Comparison Type", placeholder="cost_vs_risk",
                          filled=true, dense=true, class="q-mb-sm"),
            ]),
        ]),

        # ── Selected Service Line Summary ──────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section(class="bg-blue-1", [
                    h6("{{ selected_service_name }}", class="q-mb-sm"),
                    p("Cases: {{ case_volume }} | Avg Cost: \${{ Math.round(avg_cost) }} | Avg LOS: {{ avg_los.toFixed(1) }} days | Quality: {{ (quality_score * 100).toFixed(0) }}%",
                      class="text-caption text-grey-8"),
                ])])
            ]),
        ]),

        # ── Key Metrics Cards ──────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Case Volume", class="text-overline q-mb-none"),
                    h5("{{ case_volume }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Avg Cost", class="text-overline q-mb-none"),
                    h5("\${{ Math.round(avg_cost) }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Avg LOS", class="text-overline q-mb-none"),
                    h5("{{ avg_los.toFixed(1) }} days", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Quality Score", class="text-overline q-mb-none"),
                    h5("{{ (quality_score * 100).toFixed(0) }}%", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Readmission Rate", class="text-overline q-mb-none"),
                    h5("{{ (readmission_rate * 100).toFixed(0) }}%", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Avg Risk", class="text-overline q-mb-none"),
                    h5("{{ (avg_risk_score * 100).toFixed(0) }}%", class="q-mb-none"),
                ])])
            ]),
        ]),

        # ── Charts ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-lg-6 col-xs-12", [
                card([card_section([
                    plot(:cost_vs_risk_scatter, layout=:cost_vs_risk_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-lg-6 col-xs-12", [
                card([card_section([
                    plot(:comparison_radar, layout=:comparison_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Comparison Table ───────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Service Line Comparison", class="q-mb-md"),
                    table(
                        :comparison_table,
                        table_columns=[
                            (name="service_line", label="Service Line", field="service_line", align="left"),
                            (name="case_volume", label="Cases", field="case_volume", align="center"),
                            (name="avg_cost", label="Avg Cost", field="avg_cost", align="right"),
                            (name="avg_los", label="Avg LOS", field="avg_los", align="center"),
                            (name="quality_score", label="Quality", field="quality_score", align="center"),
                            (name="readmission_rate", label="Readmission", field="readmission_rate", align="center"),
                            (name="avg_risk_score", label="Avg Risk", field="avg_risk_score", align="center"),
                        ],
                        flat=true,
                        bordered=true,
                        dense=true,
                    )
                ])])
            ]),
        ]),

        # ── Cost Efficiency & Risk Factors ─────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Cost Efficiency", class="q-mb-md"),
                    p("Efficiency Score: \${{ Math.round(cost_efficiency.efficiency_score || 0) }} per quality point",
                      class="text-body2"),
                    p("Rank: {{ cost_efficiency.rank || 0 }} / 6",
                      class="text-body2"),
                    p("Percentile: {{ Math.round(cost_efficiency.percentile || 0) }}th",
                      class="text-body2"),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Top Risk Factors", class="q-mb-md"),
                    table(
                        :top_risk_factors,
                        table_columns=[
                            (name="factor", label="Factor", field="factor", align="left"),
                            (name="count", label="Patients", field="count", align="right"),
                        ],
                        flat=true,
                        bordered=true,
                        dense=true,
                    )
                ])])
            ]),
        ]),

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
