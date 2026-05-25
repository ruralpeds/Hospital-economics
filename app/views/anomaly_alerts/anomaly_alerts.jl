"""
Anomaly Alert Board Dashboard View
"""
function ui_anomaly_alerts(model)
    app_layout(model, "Anomaly Alerts", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Real-Time Anomaly Alert Board", class="q-mb-none"),
                p("Monitor readmission risk, cost anomalies, and complications in real time",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                textfield(:alert_severity, label="Severity Filter", placeholder="all",
                          filled=true, dense=true, class="q-mr-sm"),
            ]),
            cell(class="col-auto", [
                btn("Refresh", icon="refresh", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center bg-red-1", [
                    p("Critical Alerts", class="text-overline q-mb-none"),
                    h4("{{ critical_count }}", class="q-mb-none text-red text-weight-bold"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center bg-orange-1", [
                    p("High Alerts", class="text-overline q-mb-none"),
                    h4("{{ high_count }}", class="q-mb-none text-orange text-weight-bold"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center bg-yellow-1", [
                    p("Medium Alerts", class="text-overline q-mb-none"),
                    h4("{{ medium_count }}", class="q-mb-none text-weight-bold"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center bg-blue-1", [
                    p("Unacknowledged", class="text-overline q-mb-none"),
                    h4("{{ unacknowledged_count }}", class="q-mb-none text-blue text-weight-bold"),
                ])])
            ]),
        ]),

        # ── Charts ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-lg-6 col-xs-12", [
                card([card_section([
                    plot(:alert_timeline, layout=:timeline_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-lg-6 col-xs-12", [
                card([card_section([
                    plot(:alert_categories, layout=:categories_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Active Alerts Table ────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Active Alerts", class="q-mb-md"),
                    table(
                        :active_alerts,
                        table_columns=[
                            (name="patient_id", label="Patient", field="patient_id", align="left"),
                            (name="alert_type", label="Type", field="alert_type", align="left"),
                            (name="severity", label="Severity", field="severity", align="center"),
                            (name="timestamp", label="Time", field="timestamp", align="left"),
                            (name="description", label="Description", field="description", align="left"),
                        ],
                        flat=true,
                        bordered=true,
                        dense=true,
                        pagination=attr(rowsPerPage=25)
                    )
                ])])
            ]),
        ]),

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
