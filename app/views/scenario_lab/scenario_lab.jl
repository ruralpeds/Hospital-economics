"""
Scenario & Sensitivity Lab UI (E22) — best/base/worst-case analysis,
one-way tornado, two-way heatmap, and probabilistic sensitivity analysis (PSA).
"""

function ui_scenario_lab(model)
    app_layout(model, "Scenario & Sensitivity Lab", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Scenario & Sensitivity Lab", class="q-mb-none"),
                p("Best/base/worst cases, one-way tornado, two-way sensitivity, and Monte Carlo PSA",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto q-gutter-sm row", [
                btn("Run Scenarios", icon="play_arrow", color="primary",
                    @click(:run_scenarios), var":loading"="running"),
                btn("Tornado", icon="compare_arrows", color="secondary",
                    @click(:run_tornado), outline=true),
                btn("2-Way", icon="grid_on", color="secondary",
                    @click(:run_2way), outline=true),
                btn("PSA", icon="scatter_plot", color="secondary",
                    @click(:run_psa), outline=true),
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

        # PSA iterations parameter
        form_grid([
            (name=:n_psa_iterations, type=:numeric, label="PSA Iterations",
             help="Number of Monte Carlo samples (e.g. 1000)"),
            (name=:param1_name,      type=:text,    label="2-Way Param 1 Name"),
            (name=:param2_name,      type=:text,    label="2-Way Param 2 Name"),
        ], title="Analysis Parameters"),

        # Best / Base / Worst deck
        row(class="q-mb-md q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [
                card(class="bg-green-1", [
                    card_section([
                        h6("Best Case", class="q-mb-sm text-positive"),
                        p("NPV: \${{ (best_case.npv / 1e6 || 0).toFixed(2) }}M"),
                        p("ROI: {{ ((best_case.roi || 0) * 100).toFixed(1) }}%"),
                    ]),
                ]),
            ]),
            cell(class="col-md-4 col-xs-12", [
                card(class="bg-blue-1", [
                    card_section([
                        h6("Base Case", class="q-mb-sm text-primary"),
                        p("NPV: \${{ (base_case.npv / 1e6 || 0).toFixed(2) }}M"),
                        p("ROI: {{ ((base_case.roi || 0) * 100).toFixed(1) }}%"),
                    ]),
                ]),
            ]),
            cell(class="col-md-4 col-xs-12", [
                card(class="bg-red-1", [
                    card_section([
                        h6("Worst Case", class="q-mb-sm text-negative"),
                        p("NPV: \${{ (worst_case.npv / 1e6 || 0).toFixed(2) }}M"),
                        p("ROI: {{ ((worst_case.roi || 0) * 100).toFixed(1) }}%"),
                    ]),
                ]),
            ]),
        ]),

        # Tornado chart
        row(class="q-mb-md", [
            cell(class="col-xs-12", [
                plot_panel(:tornado_data, :tornado_layout,
                    preset=:bar_horizontal, title="Tornado Diagram — One-way Sensitivity"),
            ]),
        ]),

        # Two-way heatmap
        row(class="q-mb-md", [
            cell(class="col-xs-12", [
                plot_panel(:heatmap_data, :heatmap_layout,
                    preset=:heatmap, title="Two-way Sensitivity Heatmap"),
            ]),
        ]),

        # PSA scatter
        row(class="q-mb-md", [
            cell(class="col-xs-12", [
                plot_panel(:psa_data, :psa_layout,
                    preset=:scatter, title="Probabilistic Sensitivity Analysis (Monte Carlo)"),
            ]),
        ]),

        export_bar(csv_field=nothing, xlsx_field=nothing, json_field=nothing,
                   label="Export scenario analysis"),
    ])
end
