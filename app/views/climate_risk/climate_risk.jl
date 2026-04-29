"""Climate Risk / TCFD Dashboard UI."""
function ui_climate_risk(model)
    app_layout(model, "Climate Risk", [
        row(class="q-mb-md items-center", [
            cell(class="col", [h5("Climate Risk and TCFD Disclosure", class="q-mb-none"),
                p("Physical and transition risk across IPCC scenarios", class="text-grey-7")]),
            cell(class="col-auto", [btn("Run Analysis", icon="eco", color="green", @click(:run_analysis))]),
        ]),
        row(class="q-gutter-md q-mb-md", [
            cell(class="col-md-3 col-xs-12", [card([card_section([
                h6("Physical Risk (0–10 scale)", class="q-mb-md"),
                textfield(:flood_score, label="Flood Hazard", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:wildfire_score, label="Wildfire Hazard", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:heat_score, label="Extreme Heat", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:weather_score, label="Severe Weather", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:replacement_value, label="Replacement Value", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:generator_hours, label="Generator Backup (hrs)", type="number", filled=true, dense=true),
                separator(class="q-my-sm"),
                h6("Transition Risk", class="q-mb-sm"),
                textfield(:scope1, label="Scope 1 (tCO2e)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:scope2, label="Scope 2 (tCO2e)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:energy_spend, label="Energy Spend", type="number", filled=true, dense=true),
            ])])]),
            cell(class="col-md-9 col-xs-12", [
                row(class="q-gutter-sm q-mb-md", [
                    cell(class="col-md-3 col-xs-6", [card(class="text-center", [card_section([p("Physical Risk", class="text-overline text-caption q-mb-none"), h5("{{ composite_risk }}/10", class="q-mb-none"), badge("{{ risk_tier }}", color="red")])])]),
                    cell(class="col-md-3 col-xs-6", [card(class="text-center", [card_section([p("Expected Annual Loss", class="text-overline text-caption q-mb-none"), p("{{ (expected_annual_loss/1000).toFixed(0) }}K/yr", class="text-weight-bold text-red")])])]),
                    cell(class="col-md-3 col-xs-6", [card(class="text-center", [card_section([p("Carbon Cost 2030", class="text-overline text-caption q-mb-none"), p("{{ (carbon_cost_2030/1000).toFixed(0) }}K", class="text-weight-bold text-orange")])])]),
                    cell(class="col-md-3 col-xs-6", [card(class="text-center", [card_section([p("EV Annual Risk", class="text-overline text-caption q-mb-none"), p("{{ (ev_risk/1000).toFixed(0) }}K", class="text-weight-bold")])])]),
                ]),
                card(class="q-mb-md", [card_section([
                    plot(:scenario_chart, layout=:scenario_layout, config="{ responsive: true }"),
                ])]),
                card([card_section([
                    h6("Priority Resilience Investments", class="q-mb-sm"),
                    quasar(:q_list, dense=true, [
                        quasar(:q_item, var"v-for"="inv in priority_investments", [
                            quasar(:q_item_section, avatar=true, [icon("warning", color="orange")]),
                            quasar(:q_item_section, "{{ inv }}"),
                        ]),
                    ]),
                ])]),
            ]),
        ]),
    ])
end
