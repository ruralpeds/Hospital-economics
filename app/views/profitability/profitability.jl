"""
Profitability & Operations UI (E9) — contribution margin, break-even,
operating margin, departmental profitability, waterfall decomposition.
"""

function ui_profitability(model)
    app_layout(model, "Profitability & Operations", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Profitability & Operations", class="q-mb-none"),
                p("Contribution margin, break-even analysis, operating margin, and cost structure",
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
            (name=:financial_asset_id, type=:numeric, label="Financial Asset ID",
             help="Asset ID from Data Intake (GL or trial balance)"),
            (name=:period_from,      type=:date,     label="Period From"),
            (name=:period_to,        type=:date,     label="Period To"),
            (name=:revenue,          type=:currency, label="Total Revenue",          min=0.0),
            (name=:variable_costs,   type=:currency, label="Total Variable Costs",   min=0.0),
            (name=:fixed_costs,      type=:currency, label="Total Fixed Costs",      min=0.0),
            (name=:operating_income, type=:currency, label="Operating Income/(Loss)"),
        ], title="Financial Inputs"),

        # Volume sensitivity slider
        card(class="q-mb-md", [
            card_section([
                h6("Volume Sensitivity", class="q-mb-md"),
                p("Volume multiplier: {{ (volume_slider * 100).toFixed(0) }}%", class="q-mb-none"),
                slider(:volume_slider, min=0.5, max=1.5, step=0.05, label=true),
            ]),
        ]),

        # KPI cards
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Contribution Margin", class="text-overline q-mb-none"),
                    h4("\${{ (contribution_margin / 1e6).toFixed(2) }}M", class="q-mb-none",
                        var":class"="contribution_margin >= 0 ? 'text-positive' : 'text-negative'"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Break-Even Volume", class="text-overline q-mb-none"),
                    h4("{{ (break_even_volume * 100).toFixed(1) }}%", class="q-mb-none"),
                    p("of current volume", class="text-caption text-grey-6"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Operating Margin", class="text-overline q-mb-none"),
                    h4("{{ (operating_margin * 100).toFixed(1) }}%", class="q-mb-none",
                        var":class"="operating_margin >= 0 ? 'text-positive' : 'text-negative'"),
                ])])
            ]),
        ]),

        # Waterfall chart
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-xs-12", [
                plot_panel(:waterfall_data, :waterfall_layout,
                    preset=:bar_breakdown, title="Profitability Waterfall"),
            ]),
        ]),

        # Departmental table
        result_table(
            :departmental_rows,
            columns=[
                (name="department",         label="Department",         field="department",         sortable=true),
                (name="revenue",            label="Revenue",            field="revenue",            sortable=true, format="currency"),
                (name="variable_costs",     label="Variable Costs",     field="variable_costs",     sortable=true, format="currency"),
                (name="fixed_costs",        label="Fixed Costs",        field="fixed_costs",        sortable=true, format="currency"),
                (name="contribution_margin",label="Contribution Margin",field="contribution_margin",sortable=true, format="currency"),
                (name="operating_margin",   label="Operating Margin",   field="operating_margin",   sortable=true, format="percent"),
            ],
            title="Departmental Profitability",
        ),

        # Export bar
        export_bar(csv_field=nothing, xlsx_field=nothing, json_field=nothing,
                   label="Export profitability analysis"),
    ])
end
