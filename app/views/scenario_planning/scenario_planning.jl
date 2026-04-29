"""Scenario Planning UI."""
function ui_scenario_planning(model)
    app_layout(model, "Scenario Planning", [
        row(class="q-mb-md items-center", [
            cell(class="col", [h5("Competitive Scenario Planning", class="q-mb-none"),
                p("Porter Five Forces + 2x2 Rural Hospital Scenario Matrix", class="text-grey-7")]),
            cell(class="col-auto", [btn("Analyse", icon="explore", color="primary", @click(:run_five_forces))]),
        ]),
        row(class="q-gutter-md q-mb-md", [
            cell(class="col-md-3 col-xs-12", [card([card_section([
                h6("Five Forces (1–10)", class="q-mb-md"),
                textfield(:rivalry_score, label="Competitive Rivalry", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:new_entrants_score, label="Threat: New Entrants", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:substitutes_score, label="Threat: Substitutes", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:buyer_power_score, label="Buyer / Payer Power", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:supplier_power_score, label="Supplier / Labour Power", type="number", filled=true, dense=true),
            ])])]),
            cell(class="col-md-4 col-xs-12", [card([card_section([
                plot(:forces_chart, layout=:forces_layout, config="{ responsive: true }"),
            ])])]),
            cell(class="col-md-5 col-xs-12", [card([card_section([
                h6("Summary", class="q-mb-sm"),
                row(class="q-gutter-sm q-mb-md", [
                    cell(class="col-6", [card(class="text-center", [card_section([p("Avg Intensity", class="text-overline text-caption q-mb-none"), h5("{{ overall_intensity }}/10")])])]),
                    cell(class="col-6", [card(class="text-center", [card_section([p("Tier", class="text-overline text-caption q-mb-none"), h5("{{ intensity_tier }}", class="text-red")])])]),
                ]),
                p("{{ strategic_summary }}", class="text-body2"),
            ])])]),
        ]),
        card(class="q-mb-md", [card_section([
            h6("2x2 Rural Hospital Scenario Matrix", class="q-mb-md"),
            row(class="q-gutter-sm", [
                cell(class="col-md-3 col-xs-6", var"v-for"="(name, i) in scenario_names", [
                    card(class="full-height q-pa-sm",
                        var":class"="[{'bg-green-1':i===0},{'bg-blue-1':i===1},{'bg-orange-1':i===2},{'bg-red-1':i===3}]", [
                        h6("{{ name }}", class="q-mb-xs"),
                        badge("{{ scenario_probs[i] }}%", color="grey", class="q-mb-sm"),
                        p("{{ scenario_narratives[i] }}", class="text-caption"),
                    ]),
                ]),
            ]),
        ])]),
        card([card_section([
            h6("Robust Strategies (work in all scenarios)", class="q-mb-sm"),
            quasar(:q_list, dense=true, [
                quasar(:q_item, var"v-for"="s in robust_strategies", [
                    quasar(:q_item_section, avatar=true, [icon("check_circle", color="green")]),
                    quasar(:q_item_section, "{{ s }}"),
                ]),
            ]),
        ])]),
    ])
end
