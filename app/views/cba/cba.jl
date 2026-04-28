"""
Cost-Benefit Analysis & Budget Impact UI (E15) — NPV, ROI, BCR, IRR,
break-even, and 5-year budget impact model.
"""

function ui_cba(model)
    app_layout(model, "Cost-Benefit Analysis & Budget Impact", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Cost-Benefit Analysis & Budget Impact", class="q-mb-none"),
                p("NPV, ROI, benefit-cost ratio, IRR, break-even year, and budget impact",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate", icon="calculate", color="primary",
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
            (name=:discount_rate,       type=:numeric, label="Discount Rate",     help="Annual discount rate (e.g. 0.03)"),
            (name=:cost_year,           type=:numeric, label="Cost Reference Year"),
            (name=:time_horizon,        type=:numeric, label="Time Horizon (Years)"),
            (name=:population_size,     type=:numeric, label="Population Size"),
            (name=:adoption_rate_start, type=:numeric, label="Initial Adoption Rate"),
            (name=:adoption_rate_max,   type=:numeric, label="Max Adoption Rate"),
            (name=:cost_per_patient,    type=:currency, label="Cost per Patient"),
            (name=:population_growth,   type=:numeric, label="Population Growth Rate"),
        ], title="Parameters"),

        # KPI cards
        row(class="q-mb-md q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("NPV", class="text-overline q-mb-none"),
                    h5("\${{ (npv / 1e6).toFixed(2) }}M", class="q-mb-none",
                        var":class"="npv >= 0 ? 'text-positive' : 'text-negative'"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("ROI", class="text-overline q-mb-none"),
                    h5("{{ (roi * 100).toFixed(1) }}%", class="q-mb-none",
                        var":class"="roi >= 0 ? 'text-positive' : 'text-negative'"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("BCR", class="text-overline q-mb-none"),
                    h5("{{ bcr.toFixed(2) }}", class="q-mb-none",
                        var":class"="bcr >= 1 ? 'text-positive' : 'text-negative'"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("IRR", class="text-overline q-mb-none"),
                    h5("{{ (irr * 100).toFixed(1) }}%", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-4 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Break-Even Year", class="text-overline q-mb-none"),
                    h5("Year {{ break_even_year }}", class="q-mb-none"),
                ])])
            ]),
        ]),

        # Plots
        row(class="q-mb-md q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                plot_panel(:cashflow_plot_data, :cashflow_plot_layout,
                    preset=:bar_breakdown, title="Discounted Cash Flow"),
            ]),
            cell(class="col-md-6 col-xs-12", [
                plot_panel(:budget_impact_data, :budget_impact_layout,
                    preset=:line, title="5-Year Budget Impact"),
            ]),
        ]),

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
