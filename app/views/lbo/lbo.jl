"""LBO Analysis UI — sources/uses, debt schedule, exit scenario table, IRR."""

function ui_lbo(model)
    app_layout(model, "LBO Analysis", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Hospital LBO Analysis", class="q-mb-none"),
                p("Leveraged buyout economics: debt capacity, IRR, exit scenarios", class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Run LBO", icon="analytics", color="primary", @click(:recalculate)),
            ]),
        ]),

        # KPI strip
        row(class="q-mb-lg q-gutter-sm", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [card([card_section(class="text-center q-pa-sm", [
                p("Entry Multiple", class="text-overline q-mb-none"),
                h5("{{ entry_multiple.toFixed(1) }}×", class="q-mb-none"),
            ])])]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [card([card_section(class="text-center q-pa-sm", [
                p("Senior Debt", class="text-overline q-mb-none"),
                h5("\${{ (senior_debt/1e6).toFixed(1) }}M", class="q-mb-none text-red"),
            ])])]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [card([card_section(class="text-center q-pa-sm", [
                p("Equity", class="text-overline q-mb-none"),
                h5("\${{ (equity_contribution/1e6).toFixed(1) }}M ({{ equity_pct }}%)", class="q-mb-none text-blue"),
            ])])]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [card([card_section(class="text-center q-pa-sm", [
                p("Debt / EBITDA", class="text-overline q-mb-none"),
                h5("{{ debt_to_ebitda.toFixed(1) }}×", class="q-mb-none",
                   var":class"="debt_to_ebitda > 6 ? 'text-red' : 'text-green'"),
            ])])]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [card([card_section(class="text-center q-pa-sm", [
                p("Base IRR", class="text-overline q-mb-none"),
                h5("{{ base_irr }}%", class="q-mb-none",
                   var":class"="base_irr >= 20 ? 'text-green' : base_irr >= 15 ? 'text-orange' : 'text-red'"),
            ])])]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [card([card_section(class="text-center q-pa-sm", [
                p("Base MOIC", class="text-overline q-mb-none"),
                h5("{{ base_moic.toFixed(2) }}×", class="q-mb-none text-green"),
            ])])]),
        ]),

        row(class="q-gutter-md", [
            # Inputs
            cell(class="col-md-3 col-xs-12", [card([card_section([
                h6("Deal Structure", class="q-mb-md"),
                textfield(:purchase_price, label="Purchase Price (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:ebitda_entry, label="EBITDA Entry (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:ebitda_growth_rate, label="EBITDA Growth (%/yr)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:senior_leverage, label="Senior Leverage (×)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:mezz_leverage, label="Mezz Leverage (×)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:senior_rate, label="Senior Rate (%)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:mezz_rate, label="Mezz Rate (%)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:hold_years, label="Hold Period (years)", type="number", filled=true, dense=true),
            ])])]),

            # Debt chart + exit table
            cell(class="col-md-9 col-xs-12", [
                card(class="q-mb-md", [card_section([
                    plot(:debt_chart_data, layout=:debt_chart_layout, config="{ responsive: true }"),
                ])]),
                card([card_section([
                    h6("Exit Scenario Analysis", class="q-mb-sm"),
                    quasar(:q_table,
                        var"flat"=true, dense=true,
                        var":rows"="exit_table_data",
                        var":columns"="[
                            {name:'exit_multiple',label:'Exit Multiple',field:'exit_multiple',format:v=>v+'×'},
                            {name:'exit_ev',label:'Exit EV',field:'exit_ev',format:v=>'\$'+v+'M'},
                            {name:'equity_proceeds',label:'Sponsor Equity',field:'equity_proceeds',format:v=>'\$'+v+'M'},
                            {name:'moic',label:'MOIC',field:'moic',format:v=>v+'×'},
                            {name:'irr',label:'IRR',field:'irr',format:v=>v+'%'},
                        ]",
                        row_key="exit_multiple",
                    ),
                ])]),
            ]),
        ]),
    ])
end
