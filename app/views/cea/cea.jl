"""
Cost-Effectiveness Analysis UI (E14) — ICER, CE plane, CEAC, and tornado diagram.
"""

function ui_cea(model)
    app_layout(model, "Cost-Effectiveness Analysis (CEA)", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Cost-Effectiveness Analysis", class="q-mb-none"),
                p("ICER, cost-effectiveness plane, CEAC, net monetary benefit, and sensitivity",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Analyze", icon="balance", color="primary",
                    @click(:run),
                    var":loading"="running"),
            ]),
        ]),

        # Error banner
        template(var"v-if"="errors && errors.length > 0", [
            card(class="q-mb-md bg-red-1 text-red-9", [
                card_section([
                    p("Errors:", class="text-weight-bold q-mb-xs"),
                    template(var"v-for"="(err, idx) in errors", var":key"="idx", [
                        p(class="q-mb-none", ["{{ err }}"]),
                    ]),
                ]),
            ]),
        ]),

        # Parameters
        form_grid([
            (name=:wtp_threshold,  type=:currency, label="WTP Threshold (\$/QALY)",
             help="Willingness-to-pay per QALY gained"),
            (name=:n_simulations,  type=:numeric,  label="PSA Iterations",
             help="Monte Carlo simulations for uncertainty analysis"),
        ], title="Analysis Parameters"),

        # KPI cards
        row(class="q-mb-md q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Net Monetary Benefit", class="text-overline q-mb-none"),
                    h4("\${{ (nmb / 1000).toFixed(1) }}K", class="q-mb-none",
                        var":class"="nmb >= 0 ? 'text-positive' : 'text-negative'"),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Incremental Net Benefit", class="text-overline q-mb-none"),
                    h4("\${{ (inb / 1000).toFixed(1) }}K", class="q-mb-none",
                        var":class"="inb >= 0 ? 'text-positive' : 'text-negative'"),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Strategies", class="text-overline q-mb-none"),
                    h4("{{ strategy_rows.length }}", class="q-mb-none"),
                ])])
            ]),
        ]),

        # ICER table
        result_table(
            :icer_rows,
            columns=[
                (name="strategy",      label="Strategy",      field="strategy",      sortable=true),
                (name="cost",          label="Total Cost",    field="cost",          sortable=true, format="currency"),
                (name="effect",        label="Effect (QALY)", field="effect",        sortable=true),
                (name="incr_cost",     label="Incr. Cost",    field="incr_cost",     sortable=true, format="currency"),
                (name="incr_effect",   label="Incr. Effect",  field="incr_effect",   sortable=true),
                (name="icer",          label="ICER",          field="icer",          sortable=true, format="currency"),
                (name="dominated",     label="Dominated?",    field="dominated",     sortable=false),
            ],
            title="ICER Table",
        ),

        # Plots
        row(class="q-mb-md q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                plot_panel(:ce_plane_data, :ce_plane_layout,
                    preset=:scatter, title="Cost-Effectiveness Plane"),
            ]),
            cell(class="col-md-6 col-xs-12", [
                plot_panel(:ceac_data, :ceac_layout,
                    preset=:line, title="Cost-Effectiveness Acceptability Curve"),
            ]),
        ]),
        row(class="q-mb-md", [
            cell(class="col-xs-12", [
                plot_panel(:tornado_data, :tornado_layout,
                    preset=:bar_horizontal, title="Tornado Diagram — One-way Sensitivity"),
            ]),
        ]),

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
