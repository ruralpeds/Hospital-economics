"""
Dev component demo UI — /dev/components
Storybook-style showcase for all reusable components.
Only active when GENIE_ENV != "prod".
"""

function ui_dev_components(model)
    app_layout(model, "Component Library (dev)", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Reusable Component Library", class="q-mb-none"),
                p("Dev-only showcase — disabled in production (GENIE_ENV=prod)",
                  class="text-grey-7 q-mb-none"),
            ]),
        ]),

        # ── Navigation chips ────────────────────────────────────────────
        row(class="q-gutter-sm q-mb-lg", [
            quasar(:chip, clickable=true, color="primary", text_color="white",
                   var"@click"="() => \$el.ownerDocument.getElementById('sec-formgrid').scrollIntoView({behavior:'smooth'})",
                   "FormGrid"),
            quasar(:chip, clickable=true, color="primary", text_color="white",
                   var"@click"="() => \$el.ownerDocument.getElementById('sec-resulttable').scrollIntoView({behavior:'smooth'})",
                   "ResultTable"),
            quasar(:chip, clickable=true, color="primary", text_color="white",
                   var"@click"="() => \$el.ownerDocument.getElementById('sec-plotpanel').scrollIntoView({behavior:'smooth'})",
                   "PlotPanel"),
            quasar(:chip, clickable=true, color="primary", text_color="white",
                   var"@click"="() => \$el.ownerDocument.getElementById('sec-exportbar').scrollIntoView({behavior:'smooth'})",
                   "ExportBar"),
            quasar(:chip, clickable=true, color="primary", text_color="white",
                   var"@click"="() => \$el.ownerDocument.getElementById('sec-cohortpicker').scrollIntoView({behavior:'smooth'})",
                   "CohortPicker"),
            quasar(:chip, clickable=true, color="primary", text_color="white",
                   var"@click"="() => \$el.ownerDocument.getElementById('sec-scenariopicker').scrollIntoView({behavior:'smooth'})",
                   "ScenarioPicker"),
            quasar(:chip, clickable=true, color="primary", text_color="white",
                   var"@click"="() => \$el.ownerDocument.getElementById('sec-auditlog').scrollIntoView({behavior:'smooth'})",
                   "AuditLogViewer"),
        ]),

        # ════════════════════════════════════════════════════════════════
        # FormGrid
        # ════════════════════════════════════════════════════════════════
        Html.div(id="sec-formgrid", class="q-mb-xl", [
            row(class="q-mb-sm", [
                cell(class="col", [
                    h6("FormGrid", class="q-mb-none text-primary"),
                    p("Auto-generated typed input form from a field spec vector.",
                      class="text-caption text-grey-7"),
                ]),
            ]),

            form_grid([
                (name=:fg_discount_rate, type=:percent,
                 label="Discount Rate",
                 default=3.0, min=0.0, max=15.0, step=0.1,
                 help="Annual discount rate for present-value calculations."),
                (name=:fg_time_horizon, type=:integer,
                 label="Time Horizon (years)",
                 default=10, min=1, max=50,
                 help="Number of projection years."),
                (name=:fg_date_start, type=:date, label="Start Date"),
                (name=:fg_date_end,   type=:date, label="End Date"),
                (name=:fg_category,   type=:select, label="Category",
                 options=[Dict(:label=>"Option A", :value=>"option_a"),
                          Dict(:label=>"Option B", :value=>"option_b"),
                          Dict(:label=>"Option C", :value=>"option_c")]),
                (name=:fg_toggle_flag, type=:toggle, label="Enable Feature"),
                (name=:fg_cohort,      type=:cohort_picker, label="Patient Cohort"),
            ],
            title="Sample Inputs",
            upload_model_field=:fg_fill_from_upload),
        ]),

        separator(class="q-mb-xl"),

        # ════════════════════════════════════════════════════════════════
        # ResultTable
        # ════════════════════════════════════════════════════════════════
        Html.div(id="sec-resulttable", class="q-mb-xl", [
            row(class="q-mb-sm", [
                cell(class="col", [
                    h6("ResultTable", class="q-mb-none text-primary"),
                    p("Sortable, filterable data table with export hooks.",
                      class="text-caption text-grey-7"),
                ]),
            ]),

            result_table(:rt_rows,
                columns=[
                    (name="year",    label="Year",           field="year",
                     sortable=true,  align="left"),
                    (name="revenue", label="Revenue (\$)",   field="revenue",
                     sortable=true,  align="right", format="currency"),
                    (name="cost",    label="Cost (\$)",      field="cost",
                     sortable=true,  align="right", format="currency"),
                    (name="margin",  label="Margin %",       field="margin",
                     sortable=true,  align="right"),
                ],
                title="5-Year Financial Projection",
                export_csv_field=:rt_export_csv,
                export_xlsx_field=:rt_export_xlsx,
                filter_field=:rt_filter,
                rows_per_page=10),
        ]),

        separator(class="q-mb-xl"),

        # ════════════════════════════════════════════════════════════════
        # PlotPanel
        # ════════════════════════════════════════════════════════════════
        Html.div(id="sec-plotpanel", class="q-mb-xl", [
            row(class="q-mb-sm", [
                cell(class="col", [
                    h6("PlotPanel", class="q-mb-none text-primary"),
                    p("StipplePlotly wrapper with palette, presets, and export buttons.",
                      class="text-caption text-grey-7"),
                ]),
            ]),

            row(class="q-gutter-md", [
                cell(class="col-md-8 col-xs-12", [
                    plot_panel(:pp_trend_data, :pp_trend_layout,
                        preset=:trend,
                        title="Trend — Operating Margin",
                        export_filename="margin_trend"),
                ]),
                cell(class="col-md-4 col-xs-12", [
                    plot_panel(:pp_pie_data, :pp_pie_layout,
                        preset=:pie,
                        title="Pie — Payer Mix",
                        height="300px",
                        export_filename="payer_mix"),
                ]),
            ]),

            row(class="q-mt-md", [
                cell(class="col-12", [
                    plot_panel(:pp_bar_data, :pp_bar_layout,
                        preset=:bar_breakdown,
                        title="Bar Breakdown — Revenue by Service Line",
                        export_filename="revenue_breakdown"),
                ]),
            ]),
        ]),

        separator(class="q-mb-xl"),

        # ════════════════════════════════════════════════════════════════
        # ExportBar
        # ════════════════════════════════════════════════════════════════
        Html.div(id="sec-exportbar", class="q-mb-xl", [
            row(class="q-mb-sm", [
                cell(class="col", [
                    h6("ExportBar", class="q-mb-none text-primary"),
                    p("Export action toolbar — CSV, XLSX, JSON, PDF, PNG, Copy methods.",
                      class="text-caption text-grey-7"),
                ]),
            ]),

            card(class="q-mb-sm", [
                card_section([
                    export_bar(
                        csv_field=:eb_export_csv,
                        xlsx_field=:eb_export_xlsx,
                        json_field=:eb_export_json,
                        pdf_field=:eb_export_pdf,
                        png_field=:eb_export_png,
                        methods_field=:eb_copy_methods,
                        label="Export:"),
                    p("Last action: {{ eb_last_action }}",
                      class="text-caption text-grey-6 q-mt-sm"),
                ]),
            ]),
        ]),

        separator(class="q-mb-xl"),

        # ════════════════════════════════════════════════════════════════
        # CohortPicker
        # ════════════════════════════════════════════════════════════════
        Html.div(id="sec-cohortpicker", class="q-mb-xl", [
            row(class="q-mb-sm", [
                cell(class="col", [
                    h6("CohortPicker", class="q-mb-none text-primary"),
                    p("Inclusion/exclusion criteria builder backed by cohort_builder.jl.",
                      class="text-caption text-grey-7"),
                ]),
            ]),

            row([
                cell(class="col-md-8 col-xs-12", [
                    cohort_picker(),
                ]),
                cell(class="col-md-4 col-xs-12", [
                    card([card_section([
                        p("Status", class="text-caption text-grey-7"),
                        p("{{ cohort_status }}", class="text-body2"),
                    ])]),
                ]),
            ]),
        ]),

        separator(class="q-mb-xl"),

        # ════════════════════════════════════════════════════════════════
        # ScenarioPicker
        # ════════════════════════════════════════════════════════════════
        Html.div(id="sec-scenariopicker", class="q-mb-xl", [
            row(class="q-mb-sm", [
                cell(class="col", [
                    h6("ScenarioPicker", class="q-mb-none text-primary"),
                    p("Drop-in chooser over saved scenarios.",
                      class="text-caption text-grey-7"),
                ]),
            ]),

            row([
                cell(class="col-md-6 col-xs-12", [
                    scenario_picker(),
                ]),
                cell(class="col-md-6 col-xs-12", [
                    card([card_section([
                        p("Status", class="text-caption text-grey-7"),
                        p("{{ scenario_status }}", class="text-body2"),
                    ])]),
                ]),
            ]),
        ]),

        separator(class="q-mb-xl"),

        # ════════════════════════════════════════════════════════════════
        # AuditLogViewer
        # ════════════════════════════════════════════════════════════════
        Html.div(id="sec-auditlog", class="q-mb-xl", [
            row(class="q-mb-sm", [
                cell(class="col", [
                    h6("AuditLogViewer", class="q-mb-none text-primary"),
                    p("HIPAA audit log table with user/action/date/status filters.",
                      class="text-caption text-grey-7"),
                ]),
            ]),

            audit_log_viewer(),
        ]),
    ])
end
