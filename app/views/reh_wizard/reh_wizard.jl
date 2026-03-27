"""
REH Conversion Wizard UI - 4-step guided evaluation of CAH-to-REH conversion.
"""

function ui_reh_wizard(model)
    app_layout(model, "REH Conversion Wizard", [
        row(class="q-mb-md", [
            cell(class="col", [
                h5("Rural Emergency Hospital (REH) Conversion Wizard", class="q-mb-none"),
                p("Evaluate the financial impact of converting from CAH to REH designation",
                  class="text-grey-7"),
            ]),
        ]),

        # ── Progress Indicator ───────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                linear_progress(var":value"="wizard_step / total_steps",
                    size="12px", rounded=true, color="primary"),
                p(class="text-center text-caption q-mt-xs",
                  "Step {{ wizard_step }} of {{ total_steps }}"),
            ]),
        ]),

        # ═══════════════════════════════════════════════════════════════
        # Step 1: Select Hospital
        # ═══════════════════════════════════════════════════════════════
        card(var"v-if"="wizard_step === 1", class="q-mb-md", [
            card_section([
                h6("Step 1: Select Hospital", class="q-mb-md"),
                p("Choose a hospital to evaluate for REH conversion. Only CAH and small rural hospitals (<=50 beds) are eligible.", class="q-mb-md"),

                q__select(:selected_hospital_id, options=:hospital_options,
                    label="Hospital", filled=true,
                    var"emit-value"=true, var"map-options"=true),

                # Eligibility checks
                card(class="q-mt-lg bg-grey-1", [
                    card_section([
                        h6("Eligibility Assessment", class="q-mb-md"),
                        q__list(dense=true, [
                            item(var"v-for"="check in eligibility_check.checks", [
                                item_section(avatar=true, [
                                    q__icon(var":name"="check.pass ? 'check_circle' : 'cancel'",
                                            var":color"="check.pass ? 'green' : 'red'")
                                ]),
                                item_section([
                                    item_label("{{ check.item }}"),
                                ]),
                            ]),
                        ]),
                        quasar(:banner, var"v-if"="eligibility_check.eligible",
                            class="q-mt-md bg-green-1", dense=true, rounded=true, [
                            span("This hospital is eligible for REH conversion")
                        ]),
                    ])
                ]),

                # Current financials summary
                card(class="q-mt-md bg-grey-1", [
                    card_section([
                        h6("Current Financial Summary", class="q-mb-md"),
                        row(class="q-gutter-md text-center", [
                            cell(class="col-md-2", [
                                p("Revenue", class="text-overline q-mb-none"),
                                h6("\${{ (current_revenue / 1e6).toFixed(1) }}M"),
                            ]),
                            cell(class="col-md-2", [
                                p("Expenses", class="text-overline q-mb-none"),
                                h6("\${{ (current_expenses / 1e6).toFixed(1) }}M"),
                            ]),
                            cell(class="col-md-2", [
                                p("Margin", class="text-overline q-mb-none"),
                                h6(var":class"="current_margin < 0 ? 'text-red' : 'text-green'",
                                   "{{ (current_margin * 100).toFixed(1) }}%"),
                            ]),
                            cell(class="col-md-2", [
                                p("IP Revenue", class="text-overline q-mb-none"),
                                h6("{{ (current_inpatient_pct * 100).toFixed(0) }}%"),
                            ]),
                            cell(class="col-md-2", [
                                p("Beds", class="text-overline q-mb-none"),
                                h6("{{ current_beds }}"),
                            ]),
                            cell(class="col-md-2", [
                                p("ED Visits", class="text-overline q-mb-none"),
                                h6("{{ current_ed_visits.toLocaleString() }}"),
                            ]),
                        ]),
                    ])
                ]),

                row(class="q-mt-lg justify-end", [
                    btn("Next: Assumptions", color="primary", icon_right="arrow_forward",
                        var":disable"="!eligibility_check.eligible",
                        @click("wizard_step = 2")),
                ]),
            ])
        ]),

        # ═══════════════════════════════════════════════════════════════
        # Step 2: Conversion Assumptions
        # ═══════════════════════════════════════════════════════════════
        card(var"v-if"="wizard_step === 2", class="q-mb-md", [
            card_section([
                h6("Step 2: Conversion Assumptions", class="q-mb-md"),

                p("REH Revenue Parameters", class="text-subtitle2 q-mt-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-4 col-xs-6", [
                        numberfield(:reh_monthly_facility_payment,
                            label="Monthly Facility Payment (\$)", filled=true, dense=true,
                            hint="CMS-determined facility-specific payment")
                    ]),
                    cell(class="col-md-4 col-xs-6", [
                        numberfield(:reh_opps_rate_increase,
                            label="OPPS Rate Increase (%)", filled=true, dense=true,
                            hint="Additional % above standard OPPS rates")
                    ]),
                    cell(class="col-md-4 col-xs-6", [
                        numberfield(:outpatient_volume_change,
                            label="Outpatient Volume Change (%)", filled=true, dense=true)
                    ]),
                ]),

                row(class="q-gutter-md q-mt-sm", [
                    cell(class="col-md-4 col-xs-6", [
                        numberfield(:inpatient_revenue_retained_pct,
                            label="IP Revenue Retained (%)", filled=true, dense=true,
                            hint="Revenue kept via observation/outpatient conversion")
                    ]),
                    cell(class="col-md-4 col-xs-6", [
                        numberfield(:ed_volume_change,
                            label="ED Volume Change (%)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-4 col-xs-6", [
                        numberfield(:observation_volume_increase,
                            label="Observation Volume Increase (%)", filled=true, dense=true)
                    ]),
                ]),

                separator(class="q-my-lg"),
                p("Cost Reduction Parameters", class="text-subtitle2"),
                row(class="q-gutter-md", [
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:nursing_fte_reduction,
                            label="Nursing FTE Reduction", filled=true, dense=true)
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:inpatient_staff_reduction,
                            label="IP Staff FTE Reduction", filled=true, dense=true)
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:support_staff_reduction,
                            label="Support FTE Reduction", filled=true, dense=true)
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:avg_fte_cost_savings,
                            label="Avg FTE Cost (\$)", filled=true, dense=true)
                    ]),
                ]),
                row(class="q-gutter-md q-mt-sm", [
                    cell(class="col-md-4 col-xs-6", [
                        numberfield(:supply_cost_reduction_pct,
                            label="Supply Cost Reduction (%)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-4 col-xs-6", [
                        numberfield(:conversion_costs,
                            label="One-Time Conversion Costs (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-4 col-xs-6", [
                        numberfield(:capital_avoidance,
                            label="Capital Avoidance (\$)", filled=true, dense=true,
                            hint="Deferred capital projects no longer needed")
                    ]),
                ]),

                row(class="q-mt-lg justify-between", [
                    btn("Back", flat=true, @click("wizard_step = 1")),
                    btn("Next: Projection Settings", color="primary", icon_right="arrow_forward",
                        @click("wizard_step = 3")),
                ]),
            ])
        ]),

        # ═══════════════════════════════════════════════════════════════
        # Step 3: Projection Settings
        # ═══════════════════════════════════════════════════════════════
        card(var"v-if"="wizard_step === 3", class="q-mb-md", [
            card_section([
                h6("Step 3: Projection Settings", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:projection_years, label="Projection Years",
                            filled=true, dense=true, min="1", max="10")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:annual_rate_escalation, label="Annual Rate Escalation (%)",
                            filled=true, dense=true, step="0.1")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:cost_inflation_rate, label="Cost Inflation (%)",
                            filled=true, dense=true, step="0.1")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:discount_rate, label="Discount Rate (%)",
                            filled=true, dense=true, step="0.1")
                    ]),
                ]),

                row(class="q-mt-lg justify-between", [
                    btn("Back", flat=true, @click("wizard_step = 2")),
                    btn("Run Analysis", color="primary", icon="play_arrow",
                        @click(:run_projection)),
                ]),
            ])
        ]),

        # ═══════════════════════════════════════════════════════════════
        # Step 4: Results
        # ═══════════════════════════════════════════════════════════════
        section(var"v-if"="wizard_step === 4", [
            # Recommendation banner
            quasar(:banner, class="q-mb-md", dense=true, rounded=true,
                var":class"="reh_recommendation === 'favorable' ? 'bg-green-1 text-green-9' : 'bg-red-1 text-red-9'", [
                h6(var"v-if"="reh_recommendation === 'favorable'",
                   "REH conversion appears financially favorable for this hospital", class="q-mb-none"),
                h6(var"v-if"="reh_recommendation !== 'favorable'",
                   "REH conversion does not appear financially favorable — further analysis recommended", class="q-mb-none"),
            ]),

            # Financial impact summary
            card(class="q-mb-md", [
                card_section([
                    h6("Financial Impact Summary", class="q-mb-md"),
                    row(class="q-gutter-md text-center", [
                        cell(class="col-md-2 col-sm-4", [
                            p("Net Annual Impact", class="text-overline q-mb-none"),
                            h5(var":class"="reh_net_financial_impact > 0 ? 'text-green' : 'text-red'",
                               "\${{ (reh_net_financial_impact / 1e3).toFixed(0) }}K"),
                        ]),
                        cell(class="col-md-2 col-sm-4", [
                            p("Year-1 Margin", class="text-overline q-mb-none"),
                            h5(var":class"="reh_year1_margin > 0 ? 'text-green' : 'text-red'",
                               "{{ (reh_year1_margin * 100).toFixed(1) }}%"),
                        ]),
                        cell(class="col-md-2 col-sm-4", [
                            p("{{ projection_years }}-Year NPV", class="text-overline q-mb-none"),
                            h5(var":class"="reh_5yr_npv > 0 ? 'text-green' : 'text-red'",
                               "\${{ (reh_5yr_npv / 1e6).toFixed(1) }}M"),
                        ]),
                        cell(class="col-md-2 col-sm-4", [
                            p("Breakeven", class="text-overline q-mb-none"),
                            h5("{{ reh_breakeven_month }} months"),
                        ]),
                        cell(class="col-md-2 col-sm-4", [
                            p("Facility Payment", class="text-overline q-mb-none"),
                            h5("\${{ (reh_annual_facility_payment / 1e6).toFixed(1) }}M/yr"),
                        ]),
                        cell(class="col-md-2 col-sm-4", [
                            p("Labor Savings", class="text-overline q-mb-none"),
                            h5("\${{ (reh_labor_savings / 1e6).toFixed(1) }}M/yr"),
                        ]),
                    ]),
                ])
            ]),

            # Charts
            row(class="q-gutter-md q-mb-md", [
                cell(class="col-md-6 col-xs-12", [
                    card([card_section([
                        plot(:comparison_chart_data, layout=:comparison_chart_layout,
                             config="{ responsive: true }")
                    ])])
                ]),
                cell(class="col-md-6 col-xs-12", [
                    card([card_section([
                        plot(:revenue_waterfall_data, layout=:waterfall_layout,
                             config="{ responsive: true }")
                    ])])
                ]),
            ]),

            # Revenue / Expense Detail
            row(class="q-gutter-md q-mb-md", [
                cell(class="col-md-6", [
                    card([card_section([
                        h6("Revenue Changes", class="q-mb-md"),
                        q__list(dense=true, separator=true, [
                            item([
                                item_section([item_label("REH Facility Payments (annual)")]),
                                item_section(side=true, [
                                    span(class="text-green", "+\${{ (reh_annual_facility_payment / 1e6).toFixed(2) }}M")
                                ]),
                            ]),
                            item([
                                item_section([item_label("OPPS Rate Increase")]),
                                item_section(side=true, [
                                    span(class="text-green", "+\${{ (reh_opps_revenue_increase / 1e3).toFixed(0) }}K")
                                ]),
                            ]),
                            item([
                                item_section([item_label("Lost Inpatient Revenue")]),
                                item_section(side=true, [
                                    span(class="text-red", "\${{ (reh_inpatient_revenue_lost / 1e6).toFixed(2) }}M")
                                ]),
                            ]),
                            separator(),
                            item([
                                item_section([item_label("Net Revenue Change", class="text-bold")]),
                                item_section(side=true, [
                                    span(var":class"="reh_net_revenue_change > 0 ? 'text-green text-bold' : 'text-red text-bold'",
                                         "\${{ (reh_net_revenue_change / 1e6).toFixed(2) }}M")
                                ]),
                            ]),
                        ])
                    ])])
                ]),
                cell(class="col-md-6", [
                    card([card_section([
                        h6("Expense Reductions", class="q-mb-md"),
                        q__list(dense=true, separator=true, [
                            item([
                                item_section([item_label("Labor Cost Savings")]),
                                item_section(side=true, [
                                    span(class="text-green", "+\${{ (reh_labor_savings / 1e6).toFixed(2) }}M")
                                ]),
                            ]),
                            item([
                                item_section([item_label("Supply Cost Savings")]),
                                item_section(side=true, [
                                    span(class="text-green", "+\${{ (reh_supply_savings / 1e3).toFixed(0) }}K")
                                ]),
                            ]),
                            item([
                                item_section([item_label("Facility Savings")]),
                                item_section(side=true, [
                                    span(class="text-green", "+\${{ (reh_facility_savings / 1e3).toFixed(0) }}K")
                                ]),
                            ]),
                            separator(),
                            item([
                                item_section([item_label("Total Expense Reduction", class="text-bold")]),
                                item_section(side=true, [
                                    span(class="text-green text-bold",
                                         "+\${{ (reh_total_expense_reduction / 1e6).toFixed(2) }}M")
                                ]),
                            ]),
                        ])
                    ])])
                ]),
            ]),

            # Community Impact
            card(class="q-mb-md", [
                card_section([
                    h6("Community Impact Assessment", class="q-mb-md"),
                    q__table(rows=:community_impacts, flat=true, dense=true,
                        var"row-key"="area",
                        columns="""[
                            {name:'area', label:'Service Area', field:'area', align:'left'},
                            {name:'impact', label:'Impact', field:'impact', align:'center'},
                            {name:'detail', label:'Details', field:'detail', align:'left'}
                        ]""",
                        [
                            template("", var"v-slot:body-cell-impact"="props", [
                                q__td(props="props", [
                                    badge("{{ props.value }}",
                                        var":color"="""props.value === 'Maintained' ? 'green' :
                                                        props.value === 'Enhanced' || props.value === 'Expanded' ? 'blue' :
                                                        props.value === 'Eliminated' ? 'red' : 'orange'""")
                                ])
                            ]),
                        ]
                    )
                ])
            ]),

            # Navigation
            row(class="q-mt-lg justify-between", [
                btn("Back to Settings", flat=true, @click("wizard_step = 3")),
                btn("Start Over", icon="refresh", color="grey", flat=true,
                    @click("wizard_step = 1")),
                btn("Export Report", icon="download", color="primary"),
            ]),
        ]),
    ])
end
