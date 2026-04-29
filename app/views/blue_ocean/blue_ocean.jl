"""Blue Ocean Strategy UI."""
function ui_blue_ocean(model)
    app_layout(model, "Blue Ocean Strategy", [
        row(class="q-mb-md items-center", [
            cell(class="col", [h5("Blue Ocean Strategic Canvas", class="q-mb-none"),
                p("ERRC grid + value curve differentiation analysis", class="text-grey-7")]),
            cell(class="col-auto", [btn("Analyse", icon="waves", color="primary", @click(:run_analysis))]),
        ]),
        row(class="q-gutter-sm q-mb-md", [
            cell(class="col-md-3 col-sm-6", [card([card_section(class="text-center", [
                p("Differentiation Index", class="text-overline q-mb-none"),
                h4("{{ differentiation_index }}/100", class="q-mb-none text-indigo"),
            ])])]),
            cell(class="col-md-3 col-sm-6", [card([card_section(class="text-center", [
                p("Value Innovation Score", class="text-overline q-mb-none"),
                h4("{{ value_innovation_score.toFixed(1) }}", class="q-mb-none text-green"),
            ])])]),
            cell(class="col-md-6", [card([card_section([
                h6("Top Opportunities", class="q-mb-xs"),
                quasar(:q_list, dense=true, [quasar(:q_item, var"v-for"="opp in top_opportunities",
                    [quasar(:q_item_section, "{{ opp }}")])]),
            ])])]),
        ]),
        row(class="q-gutter-md", [
            cell(class="col-md-8 col-xs-12", [card([card_section([
                plot(:canvas_chart, layout=:canvas_layout, config="{ responsive: true }"),
            ])])]),
            cell(class="col-md-4 col-xs-12", [card([card_section([
                h6("Convergence Warnings", class="q-mb-sm"),
                quasar(:q_list, dense=true, [
                    quasar(:q_item, var"v-if"="convergence_warnings.length === 0",
                        [quasar(:q_item_section, "No strategic overlap detected")]),
                    quasar(:q_item, var"v-for"="w in convergence_warnings", class="text-orange",
                        [quasar(:q_item_section, "{{ w }}")]),
                ]),
            ])])]),
        ]),
    ])
end
