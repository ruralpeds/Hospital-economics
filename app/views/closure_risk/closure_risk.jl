"""
Closure Risk Assessment UI - multi-factor risk scoring and mitigation recommendations.
"""

function ui_closure_risk(model)
    app_layout(model, "Closure Risk Assessment", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Closure Risk Assessment", class="q-mb-none"),
                p("Multi-factor analysis of hospital financial distress and closure probability",
                  class="text-grey-7"),
            ]),
            cell(class="col-md-3 col-xs-6", [
                q__select(:selected_hospital_id, options=:hospital_options,
                    label="Hospital", filled=true, dense=true,
                    var"emit-value"=true, var"map-options"=true)
            ]),
            cell(class="col-auto", [
                btn("Run Assessment", icon="assessment", color="primary",
                    @click(:run_assessment)),
            ]),
        ]),

        # ── Overall Risk Score ───────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Overall Risk Score", class="text-overline q-mb-sm"),
                    circular_progress(var":value"="overall_risk_score / 100",
                        size="120px", var":thickness"="0.25",
                        var":color"="""risk_level === 'critical' ? 'red' :
                                       risk_level === 'high' ? 'orange' :
                                       risk_level === 'moderate' ? 'yellow' : 'green'""",
                        show_value=true, class="q-mb-sm", [
                        span(class="text-h4 text-bold", "{{ overall_risk_score }}")
                    ]),
                    badge("{{ risk_level.toUpperCase() }}", size="lg",
                        var":color"="""risk_level === 'critical' ? 'red' :
                                       risk_level === 'high' ? 'orange' :
                                       risk_level === 'moderate' ? 'yellow-8' : 'green'"""),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Financial Distress Index", class="text-overline q-mb-sm"),
                    h3("{{ (financial_distress_index * 100).toFixed(0) }}",
                       class="q-mb-none",
                       var":class"="financial_distress_index > 0.7 ? 'text-red' : 'text-orange'"),
                    p("of 100", class="text-caption text-grey"),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    p("Closure Probability", class="text-overline q-mb-md"),
                    row(class="q-gutter-md text-center", [
                        cell(class="col", [
                            h4("{{ (closure_probability_1yr * 100).toFixed(0) }}%", class="q-mb-none"),
                            p("1-Year", class="text-caption"),
                            linear_progress(var":value"="closure_probability_1yr",
                                size="8px", rounded=true,
                                var":color"="closure_probability_1yr > 0.15 ? 'red' : 'orange'"),
                        ]),
                        cell(class="col", [
                            h4("{{ (closure_probability_3yr * 100).toFixed(0) }}%", class="q-mb-none"),
                            p("3-Year", class="text-caption"),
                            linear_progress(var":value"="closure_probability_3yr",
                                size="8px", rounded=true,
                                var":color"="closure_probability_3yr > 0.20 ? 'red' : 'orange'"),
                        ]),
                        cell(class="col", [
                            h4("{{ (closure_probability_5yr * 100).toFixed(0) }}%", class="q-mb-none"),
                            p("5-Year", class="text-caption"),
                            linear_progress(var":value"="closure_probability_5yr",
                                size="8px", rounded=true,
                                var":color"="closure_probability_5yr > 0.25 ? 'red' : 'orange'"),
                        ]),
                    ]),
                ])])
            ]),
        ]),

        # ── Risk Factor Table ────────────────────────────────────────────
        card(class="q-mb-lg", [
            card_section([
                h6("Risk Factor Breakdown", class="q-mb-md"),
                q__table(rows=:risk_factors, flat=true, dense=true,
                    var"row-key"="name",
                    columns="""[
                        {name:'name', label:'Factor', field:'name', align:'left', sortable:true},
                        {name:'score', label:'Score', field:'score', align:'center', sortable:true},
                        {name:'weight', label:'Weight', field:'weight', align:'center',
                         format: val => (val * 100).toFixed(0) + '%'},
                        {name:'weighted_score', label:'Weighted', field:'weighted_score', align:'center',
                         format: val => val.toFixed(1)},
                        {name:'severity', label:'Severity', field:'severity', align:'center'},
                        {name:'detail', label:'Detail', field:'detail', align:'left'}
                    ]""",
                    [
                        template("", var"v-slot:body-cell-score"="props", [
                            q__td(props="props", [
                                linear_progress(var":value"="props.value / 100", size="20px",
                                    rounded=true,
                                    var":color"="""props.value >= 70 ? 'red' :
                                                    props.value >= 50 ? 'orange' : 'green'""",
                                    [
                                        span(class="absolute-full flex flex-center text-caption",
                                             "{{ props.value }}")
                                    ]),
                            ])
                        ]),
                        template("", var"v-slot:body-cell-severity"="props", [
                            q__td(props="props", [
                                badge("{{ props.value }}",
                                    var":color"="""props.value === 'critical' ? 'red' :
                                                    props.value === 'high' ? 'orange' :
                                                    props.value === 'moderate' ? 'yellow-8' : 'green'""")
                            ])
                        ]),
                    ]
                ),
            ])
        ]),

        # ── Charts ───────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:risk_trend_data, layout=:risk_trend_layout,
                         config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:radar_data, layout=:radar_layout,
                         config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Mitigation Recommendations ───────────────────────────────────
        card(class="q-mb-md", [
            card_section([
                h6("Mitigation Recommendations", class="q-mb-md"),
                q__list(separator=true, [
                    item(var"v-for"="rec in recommendations", key!="rec.action", [
                        item_section(avatar=true, [
                            avatar(var":color"="""rec.priority === 'high' ? 'red' :
                                                   rec.priority === 'medium' ? 'orange' : 'blue'""",
                                   var"text-color"="white", [
                                q__icon(var":name"="""rec.priority === 'high' ? 'priority_high' :
                                                       rec.priority === 'medium' ? 'drag_handle' : 'low_priority'""")
                            ])
                        ]),
                        item_section([
                            item_label("{{ rec.action }}"),
                            item_label(caption=true,
                                "Impact: {{ rec.impact }} | Timeline: {{ rec.timeline }} | Category: {{ rec.category }}"),
                        ]),
                        item_section(side=true, [
                            badge("{{ rec.priority }}", var":color"="""
                                rec.priority === 'high' ? 'red' :
                                rec.priority === 'medium' ? 'orange' : 'blue'""")
                        ]),
                    ]),
                ])
            ])
        ]),
    ])
end
