"""Readmission Risk UI — LACE scorer + HRRP programme ROI calculator."""

function ui_readmission_risk(model)
    app_layout(model, "Readmission Risk", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Readmission Risk & HRRP Impact", class="q-mb-none"),
                p("LACE index scoring + care management programme ROI", class="text-grey-7"),
            ]),
        ]),

        row(class="q-gutter-md", [
            # LACE individual scorer
            cell(class="col-md-4 col-xs-12", [card([card_section([
                h6("LACE Individual Risk Score", class="q-mb-md"),
                textfield(:los_days, label="Length of Stay (days)", type="number", filled=true, dense=true, class="q-mb-sm"),
                quasar(:q_toggle, var"v-model"=:ed_admission, label="ED Admission (vs elective)", class="q-mb-sm"),
                textfield(:charlson_index, label="Charlson Comorbidity Index (0–10)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:ed_visits_6mo, label="ED Visits in Past 6 Months", type="number", filled=true, dense=true, class="q-mb-md"),
                btn("Score Patient", icon="personal_injury", color="primary", @click(:score_patient)),
                separator(class="q-my-md"),
                row(class="text-center q-mt-md", [
                    cell([
                        p("LACE Score", class="text-overline q-mb-none"),
                        h3("{{ lace_total }}/19", class="q-mb-none",
                           var":class"="'text-' + lace_color"),
                        badge("{{ lace_tier }}", var":color"="lace_color", class="q-mb-sm"),
                        p("≈ {{ lace_readmit_pct.toFixed(1) }}% 30-day readmission rate",
                          class="text-caption"),
                    ]),
                ]),
            ])])]),

            # Risk distribution + HRRP calculator
            cell(class="col-md-8 col-xs-12", [
                card(class="q-mb-md", [card_section([
                    plot(:tier_chart_data, layout=:tier_chart_layout, config="{ responsive: true }"),
                ])]),
                card([card_section([
                    h6("HRRP Penalty Reduction Calculator", class="q-mb-md"),
                    row(class="q-gutter-sm q-mb-md", [
                        cell(class="col-md-4 col-xs-6", [textfield(:hrrp_discharges, label="Annual Discharges", type="number", filled=true, dense=true)]),
                        cell(class="col-md-4 col-xs-6", [textfield(:current_readmit_rate, label="Current Readmit Rate (%)", type="number", filled=true, dense=true)]),
                        cell(class="col-md-4 col-xs-6", [textfield(:cm_effectiveness, label="CM Effectiveness (%)", type="number", filled=true, dense=true)]),
                        cell(class="col-md-4 col-xs-6", [textfield(:cm_cost_annual, label="CM Programme Cost (\$)", type="number", filled=true, dense=true)]),
                        cell(class="col-md-4 col-xs-6", [textfield(:base_payment, label="Hospital Base Payment (\$)", type="number", filled=true, dense=true)]),
                        cell(class="col-md-4 col-xs-6", [textfield(:hrrp_penalty_rate, label="HRRP Penalty Rate (%)", type="number", filled=true, dense=true)]),
                    ]),
                    btn("Calculate HRRP Impact", icon="savings", color="secondary", @click(:run_hrrp)),
                    separator(class="q-my-md"),
                    row(class="q-gutter-sm", [
                        cell(class="col-md-2 col-xs-4", [card(class="text-center", [card_section([
                            p("Current Penalty", class="text-overline text-caption q-mb-none"),
                            p("\${{ (penalty_current/1000).toFixed(0) }}K", class="text-red text-weight-bold q-mb-none"),
                        ])])]),
                        cell(class="col-md-2 col-xs-4", [card(class="text-center", [card_section([
                            p("Projected Penalty", class="text-overline text-caption q-mb-none"),
                            p("\${{ (penalty_projected/1000).toFixed(0) }}K", class="text-orange text-weight-bold q-mb-none"),
                        ])])]),
                        cell(class="col-md-2 col-xs-4", [card(class="text-center", [card_section([
                            p("Penalty Reduction", class="text-overline text-caption q-mb-none"),
                            p("\${{ (penalty_reduction/1000).toFixed(0) }}K", class="text-green text-weight-bold q-mb-none"),
                        ])])]),
                        cell(class="col-md-2 col-xs-4", [card(class="text-center", [card_section([
                            p("Readmits Prevented", class="text-overline text-caption q-mb-none"),
                            p("{{ readmits_prevented }}", class="text-blue text-weight-bold q-mb-none"),
                        ])])]),
                        cell(class="col-md-2 col-xs-4", [card(class="text-center", [card_section([
                            p("Net Benefit", class="text-overline text-caption q-mb-none"),
                            p("\${{ (net_benefit/1000).toFixed(0) }}K", class="text-weight-bold q-mb-none",
                              var":class"="net_benefit > 0 ? 'text-green' : 'text-red'"),
                        ])])]),
                        cell(class="col-md-2 col-xs-4", [card(class="text-center", [card_section([
                            p("ROI", class="text-overline text-caption q-mb-none"),
                            p("{{ cm_roi_pct.toFixed(0) }}%", class="text-weight-bold q-mb-none",
                              var":class"="cm_roi_pct > 0 ? 'text-green' : 'text-red'"),
                        ])])]),
                    ]),
                ])]),
            ]),
        ]),
    ])
end
