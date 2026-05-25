"""
FMEA Risk Assessment UI — IEC 62304 / ISO 14971 failure mode analysis.
"""

function ui_fmea(model)
    app_layout(model, "FMEA Risk Assessment", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("FMEA Risk Assessment", class="q-mb-none"),
                p("Failure Mode and Effects Analysis per IEC 62304 / ISO 14971",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto q-gutter-sm", [
                btn("Generate Report", icon="assessment", color="primary", @click(:recalculate)),
                btn("Clear All", icon="delete", color="negative", flat=true, @click(:clear_modes)),
            ]),
        ]),

        # ── Report Summary Cards ───────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("High Risk Count", class="text-overline q-mb-none"),
                    h4("{{ high_risk_count }}", class="q-mb-none text-red"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Average RPN", class="text-overline q-mb-none"),
                    h4("{{ average_rpn.toFixed(1) }}", class="q-mb-none text-orange"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Max RPN", class="text-overline q-mb-none"),
                    h4("{{ max_rpn }}", class="q-mb-none text-primary"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Risk Reduction", class="text-overline q-mb-none"),
                    h4("{{ risk_reduction_pct.toFixed(1) }}%", class="q-mb-none text-green"),
                ])])
            ]),
        ]),

        # ── Failure Mode Entry ─────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Add Failure Mode ({{ modes_count }} added)", class="q-mb-md"),
                    row(class="q-gutter-sm items-end", [
                        cell(class="col-md-1 col-xs-6", [
                            textfield(:fm_id, label="ID", filled=true, dense=true),
                        ]),
                        cell(class="col-md-3 col-xs-6", [
                            textfield(:fm_description, label="Description", filled=true, dense=true),
                        ]),
                        cell(class="col-md-2 col-xs-6", [
                            textfield(:fm_component, label="Component", filled=true, dense=true),
                        ]),
                        cell(class="col-md-1 col-xs-4", [
                            textfield(:fm_severity, label="Severity (1-5)", type="number",
                                      filled=true, dense=true),
                        ]),
                        cell(class="col-md-1 col-xs-4", [
                            textfield(:fm_probability, label="Probability (1-5)", type="number",
                                      filled=true, dense=true),
                        ]),
                        cell(class="col-md-2 col-xs-4", [
                            textfield(:fm_detectability, label="Detectability (1-5)", type="number",
                                      filled=true, dense=true),
                        ]),
                        cell(class="col-md-2 col-xs-12", [
                            btn("Add Mode", icon="add", color="secondary", @click(:add_mode),
                                class="full-width"),
                        ]),
                    ]),
                ])])
            ]),
        ]),

        # ── Heatmap ───────────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:heatmap_data, layout=:heatmap_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Prioritized Failure Modes Table ────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Prioritized Failure Modes (by RPN)", class="q-mb-md"),
                    table(var":rows"="prioritized_table",
                          var":columns"="[
                              {name: 'id', label: 'ID', field: 'id', align: 'left', sortable: true},
                              {name: 'description', label: 'Description', field: 'description', align: 'left'},
                              {name: 'component', label: 'Component', field: 'component', align: 'left'},
                              {name: 'severity', label: 'S', field: 'severity', align: 'center', sortable: true},
                              {name: 'probability', label: 'P', field: 'probability', align: 'center', sortable: true},
                              {name: 'detectability', label: 'D', field: 'detectability', align: 'center', sortable: true},
                              {name: 'rpn', label: 'RPN', field: 'rpn', align: 'center', sortable: true},
                              {name: 'risk_level', label: 'Risk Level', field: 'risk_level', align: 'center'}
                          ]",
                          flat=true, bordered=true, dense=true,
                          var"row-key"="'id'"),
                ])])
            ]),
        ]),
    ])
end
