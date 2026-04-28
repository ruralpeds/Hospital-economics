"""
Staffing Optimizer UI - workforce analysis, benchmarking, and optimization.
"""

function ui_staffing(model)
    app_layout(model, "Staffing Optimizer", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Staffing Optimizer", class="q-mb-none"),
                p("Analyze workforce levels and identify labor cost optimization opportunities",
                  class="text-grey-7"),
            ]),
            cell(class="col-md-3 col-xs-6", [
                q__select(:selected_hospital_id, options=:hospital_options,
                    label="Hospital", filled=true, dense=true,
                    var"emit-value"=true, var"map-options"=true)
            ]),
            cell(class="col-md-2 col-xs-6", [
                q__select(:optimization_target, options=:target_options,
                    label="Optimization Target", filled=true, dense=true,
                    var"emit-value"=true, var"map-options"=true)
            ]),
            cell(class="col-auto", [
                btn("Optimize", icon="auto_fix_high", color="primary",
                    @click(:run_optimization)),
            ]),
        ]),

        # ── Overview KPIs ────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [card_section(class="q-pa-sm text-center", [
                    p("Total FTE", class="text-overline q-mb-none"),
                    h5("{{ total_fte.toFixed(1) }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [card_section(class="q-pa-sm text-center", [
                    p("Labor Cost", class="text-overline q-mb-none"),
                    h5("\${{ (total_labor_cost / 1e6).toFixed(1) }}M", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [card_section(class="q-pa-sm text-center", [
                    p("Labor % Revenue", class="text-overline q-mb-none"),
                    h5("{{ (labor_cost_pct_revenue * 100).toFixed(1) }}%", class="q-mb-none",
                       var":class"="labor_cost_pct_revenue > 0.55 ? 'text-red' : ''"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [card_section(class="q-pa-sm text-center", [
                    p("Vacancy Rate", class="text-overline q-mb-none"),
                    h5("{{ (vacancy_rate * 100).toFixed(1) }}%", class="q-mb-none",
                       var":class"="vacancy_rate > 0.10 ? 'text-orange' : ''"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [card_section(class="q-pa-sm text-center", [
                    p("Turnover Rate", class="text-overline q-mb-none"),
                    h5("{{ (turnover_rate * 100).toFixed(0) }}%", class="q-mb-none",
                       var":class"="turnover_rate > 0.20 ? 'text-red' : ''"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [card_section(class="q-pa-sm text-center", [
                    p("FTE/AOB", class="text-overline q-mb-none"),
                    h5("{{ fte_per_aob.toFixed(1) }}", class="q-mb-none"),
                ])])
            ]),
        ]),

        # ── Department Table ─────────────────────────────────────────────
        card(class="q-mb-lg", [
            card_section([
                h6("Department Staffing Analysis", class="q-mb-md"),
                q__table(rows=:departments, flat=true, dense=true,
                    var"row-key"="name",
                    columns="""[
                        {name:'name', label:'Department', field:'name', align:'left'},
                        {name:'current_fte', label:'Current FTE', field:'current_fte', align:'center'},
                        {name:'benchmark_fte', label:'Benchmark', field:'benchmark_fte', align:'center'},
                        {name:'variance', label:'Variance', field:'variance', align:'center',
                         format: val => val > 0 ? '+' + val.toFixed(1) : val.toFixed(1)},
                        {name:'cost', label:'Labor Cost', field:'cost', align:'right',
                         format: val => '\\$' + (val/1000).toFixed(0) + 'K'},
                        {name:'vacancy', label:'Vacancy', field:'vacancy', align:'center',
                         format: val => (val*100).toFixed(0) + '%'},
                        {name:'turnover', label:'Turnover', field:'turnover', align:'center',
                         format: val => (val*100).toFixed(0) + '%'},
                        {name:'contract_pct', label:'Contract %', field:'contract_pct', align:'center',
                         format: val => (val*100).toFixed(0) + '%'}
                    ]""",
                    [
                        template("", var"v-slot:body-cell-variance"="props", [
                            q__td(props="props", [
                                span(var":class"="props.value > 0 ? 'text-red' : props.value < 0 ? 'text-green' : ''",
                                     "{{ props.value > 0 ? '+' : '' }}{{ props.value.toFixed(1) }}")
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
                    plot(:staffing_comparison_data, layout=:staffing_comparison_layout,
                         config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:labor_cost_breakdown_data, layout=:labor_cost_layout,
                         config="{ responsive: true }")
                ])])
            ]),
        ]),

        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:vacancy_turnover_data, layout=:vacancy_layout,
                         config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Optimization Results ─────────────────────────────────────────
        quasar(:banner, var"v-if"="optimization_status !== ''",
            class="q-mb-md bg-green-1", dense=true, rounded=true, [
            span("{{ optimization_status }}")
        ]),

        card(var"v-if"="optimization_status !== ''", class="q-mb-md", [
            card_section([
                h6("Optimization Results", class="q-mb-md"),
                row(class="q-gutter-md text-center q-mb-lg", [
                    cell(class="col-md-2 col-sm-4", [
                        p("FTE Reduction", class="text-overline q-mb-none"),
                        h5("{{ fte_reduction.toFixed(1) }}", class="text-green q-mb-none"),
                    ]),
                    cell(class="col-md-2 col-sm-4", [
                        p("Annual Savings", class="text-overline q-mb-none"),
                        h5("\${{ (annual_savings / 1e3).toFixed(0) }}K", class="text-green q-mb-none"),
                    ]),
                    cell(class="col-md-2 col-sm-4", [
                        p("New FTE Total", class="text-overline q-mb-none"),
                        h5("{{ optimized_total_fte.toFixed(1) }}", class="q-mb-none"),
                    ]),
                    cell(class="col-md-2 col-sm-4", [
                        p("New Labor %", class="text-overline q-mb-none"),
                        h5("{{ (new_labor_cost_pct * 100).toFixed(1) }}%", class="q-mb-none"),
                    ]),
                    cell(class="col-md-2 col-sm-4", [
                        p("Payback", class="text-overline q-mb-none"),
                        h5("{{ payback_months }} mo", class="q-mb-none"),
                    ]),
                    cell(class="col-md-2 col-sm-4", [
                        p("Quality Impact", class="text-overline q-mb-none"),
                        badge("{{ quality_impact }}",
                            var":color"="""quality_impact === 'minimal' ? 'green' :
                                           quality_impact === 'positive' ? 'blue' : 'orange'""",
                            size="lg"),
                    ]),
                ]),

                separator(class="q-my-md"),
                h6("Recommended Actions", class="q-mb-md"),
                q__list(separator=true, [
                    item(var"v-for"="action in optimization_actions", key!="action.department", [
                        item_section(avatar=true, [
                            avatar(var":color"="""action.risk === 'low' ? 'green' :
                                                   action.risk === 'medium' ? 'orange' : 'red'""",
                                   var"text-color"="white", font_size="12px", [
                                span("{{ action.department.substring(0,2) }}")
                            ])
                        ]),
                        item_section([
                            item_label("{{ action.department }}: {{ action.action }}"),
                            item_label(caption=true,
                                "Savings: \${{ (action.savings/1000).toFixed(0) }}K | Timeline: {{ action.timeline }} | Risk: {{ action.risk }}"),
                        ]),
                    ]),
                ]),
            ])
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
