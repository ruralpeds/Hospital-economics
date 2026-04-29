"""Theory of Constraints UI."""
function ui_throughput(model)
    app_layout(model, "Throughput / TOC", [
        row(class="q-mb-md items-center", [
            cell(class="col", [h5("Throughput Accounting and Theory of Constraints", class="q-mb-none"),
                p("T = Revenue minus TVC | NP = T minus OE | ROI = NP/I", class="text-grey-7")]),
        ]),
        row(class="q-gutter-md q-mb-md", [
            cell(class="col-md-4 col-xs-12", [card([card_section([
                h6("Global Measures Inputs", class="q-mb-md"),
                textfield(:annual_revenue, label="Annual Revenue", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:tvc, label="Truly Variable Costs (TVC)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:operating_expense, label="Operating Expense (OE)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:investment, label="Total Investment (I)", type="number", filled=true, dense=true, class="q-mb-md"),
                btn("Calculate T/OE/I", icon="calculate", color="primary", @click(:recalculate)),
            ])])]),
            cell(class="col-md-8 col-xs-12", [card([card_section([
                h6("Global Measures", class="q-mb-md"),
                row(class="q-gutter-sm", [
                    cell(class="col-md-4 col-xs-6", [card(class="text-center", [card_section([p("Throughput (T)", class="text-overline text-caption q-mb-none"), h5("{{ (throughput/1e6).toFixed(2) }}M", class="q-mb-none text-indigo")])])]),
                    cell(class="col-md-4 col-xs-6", [card(class="text-center", [card_section([p("Net Profit (NP)", class="text-overline text-caption q-mb-none"), h5("{{ (net_profit/1000).toFixed(0) }}K", class="q-mb-none", var":class"="net_profit > 0 ? 'text-green' : 'text-red'")])])]),
                    cell(class="col-md-4 col-xs-6", [card(class="text-center", [card_section([p("ROI", class="text-overline text-caption q-mb-none"), h5("{{ roi }}%", class="q-mb-none")])])]),
                    cell(class="col-md-4 col-xs-6", [card(class="text-center", [card_section([p("Productivity T/OE", class="text-overline text-caption q-mb-none"), h5("{{ productivity }}", class="q-mb-none")])])]),
                    cell(class="col-md-4 col-xs-6", [card(class="text-center", [card_section([p("Investment Turns", class="text-overline text-caption q-mb-none"), h5("{{ investment_turns }}", class="q-mb-none")])])]),
                    cell(class="col-md-4 col-xs-6", [card(class="text-center", [card_section([p("TVC Ratio", class="text-overline text-caption q-mb-none"), h5("{{ tvc_ratio }}%", class="q-mb-none")])])]),
                ]),
            ])])]),
        ]),
        row(class="q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [card([card_section([
                h6("Constraint Identification", class="q-mb-md"),
                textfield(:ed_available, label="ED Capacity (visits/yr)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:ed_demanded,  label="ED Demand (visits/yr)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:or_available, label="OR Capacity (hrs/yr)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:or_demanded,  label="OR Demand (hrs/yr)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:lab_available, label="Lab Capacity (tests/yr)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:lab_demanded,  label="Lab Demand (tests/yr)", type="number", filled=true, dense=true, class="q-mb-md"),
                btn("Find Constraint", icon="search", color="secondary", @click(:run_constraint)),
            ])])]),
            cell(class="col-md-8 col-xs-12", [
                card(class="q-mb-md", [card_section([
                    plot(:util_chart, layout=:util_layout, config="{ responsive: true }"),
                ])]),
                card([card_section([
                    h6("System Constraint: {{ constraint_name }} ({{ constraint_util }}%)", class="q-mb-sm"),
                    p("Exploit: {{ exploit_rec }}", class="text-body2 q-mb-sm"),
                    p("Elevate: {{ elevate_rec }}", class="text-body2"),
                ])]),
            ]),
        ]),
    ])
end
