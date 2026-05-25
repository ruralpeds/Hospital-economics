"""
Risk Stratification Dashboard View
"""
function ui_risk_stratification(model)
    app_layout(model, "Risk Stratification", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Patient Risk Stratification Dashboard", class="q-mb-none"),
                p("Analyze patient risk scores, readmission risk, and cost anomalies",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Generate Report", icon="description", color="secondary",
                    @click("report_generated = true"), class="q-mr-sm"),
            ]),
            cell(class="col-auto", [
                btn("Recalculate", icon="refresh", color="primary",
                    @click("recalculate = true")),
            ]),
        ]),

        # ── Controls ───────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                textfield(:cohort_filter, label="Cohort Filter", placeholder="all",
                          filled=true, dense=true, class="q-mb-sm"),
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                slider(:risk_threshold, label=true,
                       var":label-value"="'Threshold: ' + (risk_threshold * 100).toFixed(0) + '%'",
                       var":min"="0", var":max"="1", var":step"="0.1", class="q-mb-sm"),
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                textfield(:sort_by, label="Sort By", placeholder="risk",
                          filled=true, dense=true, class="q-mb-sm"),
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                textfield(:search_patient_id, label="Search Patient ID", placeholder="PT001",
                          filled=true, dense=true, class="q-mb-sm"),
            ]),
        ]),

        # ── Summary KPI Cards ──────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center bg-red-1", [
                    p("High Risk Patients", class="text-overline q-mb-none"),
                    h4("{{ high_risk_count }}", class="q-mb-none text-red text-weight-bold"),
                    p("Risk > 0.67", class="text-caption q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center bg-orange-1", [
                    p("Medium Risk Patients", class="text-overline q-mb-none"),
                    h4("{{ medium_risk_count }}", class="q-mb-none text-orange text-weight-bold"),
                    p("Risk 0.33-0.67", class="text-caption q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center bg-green-1", [
                    p("Low Risk Patients", class="text-overline q-mb-none"),
                    h4("{{ low_risk_count }}", class="q-mb-none text-green text-weight-bold"),
                    p("Risk < 0.33", class="text-caption q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center bg-blue-1", [
                    p("Average Risk", class="text-overline q-mb-none"),
                    h4("{{ (avg_risk_score * 100).toFixed(0) }}%", class="q-mb-none text-blue text-weight-bold"),
                    p("Cohort Mean", class="text-caption q-mb-none"),
                ])])
            ]),
        ]),

        # ── Charts ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-lg-6 col-xs-12", [
                card([card_section([
                    plot(:risk_distribution, layout=:risk_distribution_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-lg-6 col-xs-12", [
                card([card_section([
                    plot(:service_line_breakdown, layout=:service_line_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Risk Factors ───────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:risk_factors_frequency, layout=:risk_factors_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── High Risk Patient Table ────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("High Risk Patients (Top 20)", class="q-mb-md"),
                    p("{{ filtered_count }} patients shown", class="text-caption text-grey-8 q-mb-md"),
                    table(
                        :patient_risks,
                        table_columns=[
                            (name="patient_id", label="Patient ID", field="patient_id", align="left"),
                            (name="risk_score", label="Risk Score", field="risk_score", align="center"),
                            (name="readmission_risk", label="Readmission Risk", field="readmission_risk", align="center"),
                            (name="cost_flag", label="Cost Anomaly", field="cost_flag", align="center"),
                            (name="complication_risk", label="Complication Risk", field="complication_risk", align="center"),
                        ],
                        flat=true,
                        bordered=true,
                        dense=true,
                        pagination=attr(rowsPerPage=20)
                    )
                ])])
            ]),
        ]),

        # ── Metrics Summary ────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Readmission Metrics", class="q-mb-md"),
                    p("Readmission Rate: {{ (readmission_rate * 100).toFixed(1) }}%", class="text-body2"),
                    p("Cost Anomaly Rate: {{ (cost_anomaly_rate * 100).toFixed(1) }}%", class="text-body2"),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Risk Score Distribution", class="q-mb-md"),
                    p("Average Risk: {{ (avg_risk_score * 100).toFixed(1) }}%", class="text-body2"),
                    p("Median Risk: {{ (median_risk_score * 100).toFixed(1) }}%", class="text-body2"),
                ])])
            ]),
        ]),

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
