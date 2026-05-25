"""
CMS Quality Payment Programs UI — VBP, HACRP, HRRP, MIPS, HAI, Star Ratings, Combined.
"""

function ui_cms_programs(model)
    app_layout(model, "CMS Quality Payment Programs", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("CMS Quality Payment Programs", class="q-mb-none"),
                p("Calculate payment adjustments across CMS quality programs",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate", icon="calculate", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── Program Selector ──────────────────────────────────────
        row(class="q-mb-md", [
            cell(class="col-md-6 col-xs-12", [
                q__select(:program_selector, options=:program_options,
                          label="Select CMS Program", filled=true, dense=true,
                          var"emit-value"=true, var"map-options"=true),
            ]),
        ]),

        # ── KPI Cards ─────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("{{ result_label }}", class="text-overline q-mb-none"),
                    h4("{{ result_primary }}", class="q-mb-none text-primary"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Secondary Metric", class="text-overline q-mb-none"),
                    h6("{{ result_secondary }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Detail", class="text-overline q-mb-none"),
                    h6("{{ result_detail }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Additional Info", class="text-overline q-mb-none"),
                    h6("{{ result_extra }}", class="q-mb-none text-grey-8"),
                ])])
            ]),
        ]),

        # ── VBP Inputs ────────────────────────────────────────────
        Html.div(var"v-show"="program_selector == 'VBP' || program_selector == 'Combined'", [
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-md-6 col-xs-12", [
                    card([card_section([
                        h6("VBP Domain Achievement Points (0-10)", class="q-mb-md"),
                        textfield(:vbp_clinical_points, label="Clinical Outcomes", type="number",
                                  filled=true, dense=true, class="q-mb-sm"),
                        textfield(:vbp_safety_points, label="Safety", type="number",
                                  filled=true, dense=true, class="q-mb-sm"),
                        textfield(:vbp_person_points, label="Person & Community Engagement", type="number",
                                  filled=true, dense=true, class="q-mb-sm"),
                        textfield(:vbp_efficiency_points, label="Efficiency & Cost Reduction", type="number",
                                  filled=true, dense=true, class="q-mb-sm"),
                    ])])
                ]),
                cell(class="col-md-6 col-xs-12", [
                    card([card_section([
                        h6("VBP Payment Parameters", class="q-mb-md"),
                        textfield(:vbp_base_drg_amount, label="Base DRG Operating Amount (\$)", type="number",
                                  filled=true, dense=true),
                    ])])
                ]),
            ]),
        ]),

        # ── HACRP Inputs ──────────────────────────────────────────
        Html.div(var"v-show"="program_selector == 'HACRP' || program_selector == 'Combined'", [
            row(class="q-mb-lg", [
                cell(class="col-12", [
                    card([card_section([
                        h6("HACRP Measure Z-Scores", class="q-mb-md"),
                        row(class="q-gutter-md", [
                            cell(class="col-md-4 col-sm-6", [
                                textfield(:hacrp_psi90_zscore, label="PSI-90 Z-Score", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-4 col-sm-6", [
                                textfield(:hacrp_clabsi_zscore, label="CLABSI Z-Score", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-4 col-sm-6", [
                                textfield(:hacrp_cauti_zscore, label="CAUTI Z-Score", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-4 col-sm-6", [
                                textfield(:hacrp_ssi_zscore, label="SSI Z-Score", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-4 col-sm-6", [
                                textfield(:hacrp_mrsa_zscore, label="MRSA Z-Score", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-4 col-sm-6", [
                                textfield(:hacrp_cdi_zscore, label="CDI Z-Score", type="number",
                                          filled=true, dense=true),
                            ]),
                        ]),
                    ])])
                ]),
            ]),
        ]),

        # ── HRRP Inputs ──────────────────────────────────────────
        Html.div(var"v-show"="program_selector == 'HRRP' || program_selector == 'Combined'", [
            row(class="q-mb-lg", [
                cell(class="col-12", [
                    card([card_section([
                        h6("HRRP Condition Readmission Data", class="q-mb-md"),
                        row(class="q-gutter-md", [
                            cell(class="col-md-3 col-sm-6", [
                                textfield(:hrrp_ami_predicted, label="AMI Predicted", type="number",
                                          filled=true, dense=true, class="q-mb-sm"),
                                textfield(:hrrp_ami_expected, label="AMI Expected", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-3 col-sm-6", [
                                textfield(:hrrp_hf_predicted, label="HF Predicted", type="number",
                                          filled=true, dense=true, class="q-mb-sm"),
                                textfield(:hrrp_hf_expected, label="HF Expected", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-3 col-sm-6", [
                                textfield(:hrrp_pn_predicted, label="PN Predicted", type="number",
                                          filled=true, dense=true, class="q-mb-sm"),
                                textfield(:hrrp_pn_expected, label="PN Expected", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-3 col-sm-6", [
                                textfield(:hrrp_copd_predicted, label="COPD Predicted", type="number",
                                          filled=true, dense=true, class="q-mb-sm"),
                                textfield(:hrrp_copd_expected, label="COPD Expected", type="number",
                                          filled=true, dense=true),
                            ]),
                        ]),
                        textfield(:hrrp_base_drg, label="Base DRG Payments (\$)", type="number",
                                  filled=true, dense=true, class="q-mt-md"),
                    ])])
                ]),
            ]),
        ]),

        # ── MIPS Inputs ──────────────────────────────────────────
        Html.div(var"v-show"="program_selector == 'MIPS'", [
            row(class="q-mb-lg", [
                cell(class="col-12", [
                    card([card_section([
                        h6("MIPS Category Scores (0-100)", class="q-mb-md"),
                        row(class="q-gutter-md", [
                            cell(class="col-md-3 col-sm-6", [
                                textfield(:mips_quality_score, label="Quality (30%)", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-3 col-sm-6", [
                                textfield(:mips_cost_score, label="Cost (30%)", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-3 col-sm-6", [
                                textfield(:mips_pi_score, label="Promoting Interop (25%)", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-3 col-sm-6", [
                                textfield(:mips_ia_score, label="Improvement Activities (15%)", type="number",
                                          filled=true, dense=true),
                            ]),
                        ]),
                    ])])
                ]),
            ]),
        ]),

        # ── HAI Inputs ───────────────────────────────────────────
        Html.div(var"v-show"="program_selector == 'HAI'", [
            row(class="q-mb-lg", [
                cell(class="col-12", [
                    card([card_section([
                        h6("Healthcare-Associated Infection Data", class="q-mb-md"),
                        row(class="q-gutter-md", [
                            cell(class="col-md-3 col-sm-6", [
                                q__select(:hai_infection_type, options=:hai_type_options,
                                          label="Infection Type", filled=true, dense=true,
                                          var"emit-value"=true, var"map-options"=true),
                            ]),
                            cell(class="col-md-3 col-sm-6", [
                                textfield(:hai_observed, label="Observed Events", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-3 col-sm-6", [
                                textfield(:hai_predicted, label="Predicted Events", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-3 col-sm-6", [
                                textfield(:hai_device_days, label="Device/Patient Days", type="number",
                                          filled=true, dense=true),
                            ]),
                        ]),
                    ])])
                ]),
            ]),
        ]),

        # ── Combined base DRG ────────────────────────────────────
        Html.div(var"v-show"="program_selector == 'Combined'", [
            row(class="q-mb-lg", [
                cell(class="col-md-6 col-xs-12", [
                    card([card_section([
                        h6("Combined Analysis Parameters", class="q-mb-md"),
                        textfield(:combined_base_drg, label="Base DRG Payments (\$)", type="number",
                                  filled=true, dense=true),
                    ])])
                ]),
            ]),
        ]),

        # ── Chart ─────────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:payment_chart_data, layout=:payment_chart_layout,
                         config="{ responsive: true }")
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
