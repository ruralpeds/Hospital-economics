"""
Revenue & Reimbursement UI (E8) — total revenue KPIs, payer mix, denied claims, waterfall.
"""

function ui_revenue(model)
    app_layout(model, "Revenue & Reimbursement", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Revenue & Reimbursement", class="q-mb-none"),
                p("Total revenue, payer mix, denied claims, and provider payment simulation",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Run Simulation", icon="currency_exchange", color="primary",
                    @click(:run_sim),
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
            (name=:claims_asset_id,       type=:numeric, label="Claims Asset ID",
             help="Asset ID for claims data from Data Intake"),
            (name=:fee_schedule_asset_id, type=:numeric, label="Fee Schedule Asset ID",
             help="Asset ID for fee schedule / contract rates"),
            (name=:scenario, type=:select, label="Policy Scenario",
             options=[
                 Dict(:label=>"Current",     :value=>"current"),
                 Dict(:label=>"Optimistic",  :value=>"optimistic"),
                 Dict(:label=>"Pessimistic", :value=>"pessimistic"),
                 Dict(:label=>"Custom",      :value=>"custom"),
             ]),
            (name=:policy_knob_1, type=:percent, label="Rate Adjustment (%)",
             min=-0.20, max=0.20, step=0.005,
             visible_when="scenario === 'custom'",
             help="Adjustment to contracted payment rates"),
            (name=:policy_knob_2, type=:percent, label="Denial Rate Delta (%)",
             min=-0.10, max=0.10, step=0.005,
             visible_when="scenario === 'custom'",
             help="Change in claim denial rate"),
        ], title="Simulation Parameters"),

        # KPI cards
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total Revenue", class="text-overline q-mb-none"),
                    h4("\${{ (total_revenue / 1e6).toFixed(2) }}M", class="q-mb-none text-positive"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total Denied", class="text-overline q-mb-none"),
                    h4("\${{ (denied_total / 1e6).toFixed(2) }}M", class="q-mb-none text-negative"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Denial Rate", class="text-overline q-mb-none"),
                    h4("{{ (denial_rate * 100).toFixed(1) }}%", class="q-mb-none",
                        var":class"="denial_rate > 0.05 ? 'text-negative' : 'text-positive'"),
                ])])
            ]),
        ]),

        # Payer mix chart + table
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-5 col-xs-12", [
                plot_panel(:payor_mix_data, :payor_mix_layout,
                    preset=:pie, title="Payer Mix"),
            ]),
            cell(class="col-md-7 col-xs-12", [
                result_table(
                    :payor_mix_rows,
                    columns=[
                        (name="payer",       label="Payer",          field="payer",       sortable=true),
                        (name="revenue",     label="Revenue",        field="revenue",     sortable=true, format="currency"),
                        (name="pct_total",   label="% of Total",     field="pct_total",   sortable=true, format="percent"),
                        (name="denial_rate", label="Denial Rate",    field="denial_rate", sortable=true, format="percent"),
                        (name="avg_payment", label="Avg Payment",    field="avg_payment", sortable=true, format="currency"),
                    ],
                    title="Payer Mix Detail",
                ),
            ]),
        ]),

        # Waterfall chart
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-xs-12", [
                plot_panel(:waterfall_data, :waterfall_layout,
                    preset=:bar_breakdown, title="Revenue Waterfall"),
            ]),
        ]),

        # Denial categories table
        result_table(
            :denial_categories,
            columns=[
                (name="category",   label="Denial Category", field="category",   sortable=true),
                (name="count",      label="Count",           field="count",      sortable=true, format="number"),
                (name="amount",     label="Amount",          field="amount",     sortable=true, format="currency"),
                (name="pct_denied", label="% of Denials",    field="pct_denied", sortable=true, format="percent"),
            ],
            title="Denial Categories",
        ),

        # Export bar
        export_bar(csv_field=nothing, xlsx_field=nothing, json_field=nothing,
                   label="Export revenue analysis"),
    ])
end
