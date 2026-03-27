"""
Hospital Profile UI - comprehensive form for editing all hospital parameters.
"""

function ui_hospital_profile(model)
    app_layout(model, "Hospital Profile", [
        # ── Header & Status ──────────────────────────────────────────────
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Hospital Profile Editor", class="q-mb-none"),
                p("Enter or update hospital operating and financial data", class="text-grey-7"),
            ]),
            cell(class="col-auto q-gutter-sm", [
                btn("Save Profile", icon="save", color="primary", @click(:save_profile)),
                btn("Reset", icon="restart_alt", color="grey", flat=true, @click(:reset_profile)),
            ]),
        ]),

        # Status messages
        quasar(:banner, var"v-if"="save_status !== ''",
            class="q-mb-md", dense=true, rounded=true,
            var":class"="validation_errors.length > 0 ? 'bg-red-1' : 'bg-green-1'", [
            span("{{ save_status }}"),
        ]),
        quasar(:banner, var"v-for"="err in validation_errors", class="q-mb-xs bg-red-1 text-red-9",
            dense=true, rounded=true, [span("{{ err }}")]),

        # ── Section 1: Identification ────────────────────────────────────
        card(class="q-mb-md", [
            card_section([
                h6("Hospital Identification", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-4 col-xs-12", [
                        textfield(:hospital_name, label="Hospital Name", filled=true, dense=true,
                            rules="[val => val.length > 0 || 'Required']")
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        textfield(:hospital_state, label="State", filled=true, dense=true)
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        textfield(:hospital_county, label="County", filled=true, dense=true)
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        textfield(:hospital_zip, label="ZIP Code", filled=true, dense=true)
                    ]),
                ]),
                row(class="q-gutter-md q-mt-sm", [
                    cell(class="col-md-3 col-xs-6", [
                        q__select(:hospital_type,
                            options=[:CAH=>"Critical Access (CAH)", :PPS=>"PPS Hospital",
                                     :REH=>"Rural Emergency (REH)", :SCH=>"Sole Community"],
                            label="Hospital Type", filled=true, dense=true,
                            var"emit-value"=true, var"map-options"=true)
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        textfield(:provider_number, label="Provider Number", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:ruca_code, label="RUCA Code", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        toggle(:is_sole_community, label="Sole Community Provider")
                    ]),
                ]),
            ])
        ]),

        # ── Section 2: Beds & Facility ───────────────────────────────────
        card(class="q-mb-md", [
            card_section([
                h6("Facility Information", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:licensed_beds, label="Licensed Beds", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:staffed_beds, label="Staffed Beds", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:icu_beds, label="ICU Beds", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:facility_sq_ft, label="Sq Footage", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:year_built, label="Year Built", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:last_renovation_year, label="Last Renovation", filled=true, dense=true)
                    ]),
                ]),
            ])
        ]),

        # ── Section 3: Financial Data ────────────────────────────────────
        card(class="q-mb-md", [
            card_section([
                h6("Financial Data (Annual)", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:total_revenue, label="Total Revenue (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:net_patient_revenue, label="Net Patient Revenue (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:total_operating_expenses, label="Total Operating Expenses (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:non_operating_income, label="Non-Operating Income (\$)", filled=true, dense=true)
                    ]),
                ]),
                separator(class="q-my-md"),
                p("Expense Breakdown", class="text-subtitle2"),
                row(class="q-gutter-md", [
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:salary_wages, label="Salaries (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:benefits_expense, label="Benefits (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:supply_expense, label="Supplies (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:depreciation, label="Depreciation (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:interest_expense, label="Interest (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:other_operating_expense, label="Other OpEx (\$)", filled=true, dense=true)
                    ]),
                ]),
                separator(class="q-my-md"),
                p("Balance Sheet", class="text-subtitle2"),
                row(class="q-gutter-md", [
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:total_assets, label="Total Assets (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:total_liabilities, label="Total Liabilities (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:long_term_debt, label="Long-Term Debt (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:cash_and_investments, label="Cash & Investments (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:property_plant_equipment, label="PP&E (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:accumulated_depreciation, label="Accum Depreciation (\$)", filled=true, dense=true)
                    ]),
                ]),
                separator(class="q-my-md"),
                p("Supplemental Revenue", class="text-subtitle2"),
                row(class="q-gutter-md", [
                    cell(class="col-md-4 col-xs-6", [
                        numberfield(:dsh_payments, label="DSH Payments (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-4 col-xs-6", [
                        numberfield(:supplemental_payments, label="Supplemental Payments (\$)", filled=true, dense=true)
                    ]),
                    cell(class="col-md-4 col-xs-6", [
                        numberfield(:grant_income, label="Grant Income (\$)", filled=true, dense=true)
                    ]),
                ]),
            ])
        ]),

        # ── Section 4: Volume Data ───────────────────────────────────────
        card(class="q-mb-md", [
            card_section([
                h6("Volume & Utilization Data (Annual)", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:inpatient_discharges, label="IP Discharges", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:inpatient_days, label="IP Days", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:ed_visits, label="ED Visits", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:outpatient_visits, label="OP Visits", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:surgical_cases, label="Surgical Cases", filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:births, label="Births", filled=true, dense=true)
                    ]),
                ]),
                row(class="q-gutter-md q-mt-sm", [
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:case_mix_index, label="Case Mix Index", filled=true, dense=true, step="0.01")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:avg_length_of_stay, label="Avg LOS (days)", filled=true, dense=true, step="0.1")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:readmission_rate, label="Readmission Rate (%)", filled=true, dense=true, step="0.1")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:observation_hours, label="Observation Hours", filled=true, dense=true)
                    ]),
                ]),
            ])
        ]),

        # ── Section 5: Payer Mix ─────────────────────────────────────────
        card(class="q-mb-md", [
            card_section([
                h6("Payer Mix (% of Revenue)", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-3 col-xs-6", [
                        slider(:medicare_pct, label=true, var"label-value"="Medicare: {{ medicare_pct }}%",
                            min=0, max=100, step=0.5, color="blue")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        slider(:medicaid_pct, label=true, var"label-value"="Medicaid: {{ medicaid_pct }}%",
                            min=0, max=100, step=0.5, color="teal")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        slider(:commercial_pct, label=true, var"label-value"="Commercial: {{ commercial_pct }}%",
                            min=0, max=100, step=0.5, color="green")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        slider(:self_pay_pct, label=true, var"label-value"="Self-Pay: {{ self_pay_pct }}%",
                            min=0, max=100, step=0.5, color="orange")
                    ]),
                ]),
                p(var":class"="Math.abs(medicare_pct + medicaid_pct + commercial_pct + self_pay_pct - 100) > 1 ? 'text-red' : 'text-green'",
                  "Total: {{ (medicare_pct + medicaid_pct + commercial_pct + self_pay_pct).toFixed(1) }}%"),
            ])
        ]),

        # ── Section 6: Services ──────────────────────────────────────────
        card(class="q-mb-md", [
            card_section([
                h6("Services Offered", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-3 col-xs-6", [toggle(:has_emergency, label="Emergency Dept")]),
                    cell(class="col-md-3 col-xs-6", [toggle(:has_surgery, label="Surgery")]),
                    cell(class="col-md-3 col-xs-6", [toggle(:has_obstetrics, label="Obstetrics")]),
                    cell(class="col-md-3 col-xs-6", [toggle(:has_imaging, label="Imaging")]),
                    cell(class="col-md-3 col-xs-6", [toggle(:has_lab, label="Laboratory")]),
                    cell(class="col-md-3 col-xs-6", [toggle(:has_pharmacy, label="Pharmacy")]),
                    cell(class="col-md-3 col-xs-6", [toggle(:has_rehab, label="Rehabilitation")]),
                    cell(class="col-md-3 col-xs-6", [toggle(:has_telehealth, label="Telehealth")]),
                    cell(class="col-md-3 col-xs-6", [toggle(:has_home_health, label="Home Health")]),
                    cell(class="col-md-3 col-xs-6", [toggle(:has_swing_beds, label="Swing Beds")]),
                    cell(class="col-md-3 col-xs-6", [toggle(:has_snf, label="Skilled Nursing")]),
                    cell(class="col-md-3 col-xs-6", [toggle(:has_rural_health_clinic, label="Rural Health Clinic")]),
                ]),
            ])
        ]),

        # ── Computed Metrics Preview ─────────────────────────────────────
        card(class="q-mb-md bg-grey-1", [
            card_section([
                h6("Computed Metrics (auto-calculated)", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-2", [
                        p("Operating Margin", class="text-overline q-mb-none"),
                        h6("{{ (computed_operating_margin * 100).toFixed(1) }}%",
                           var":class"="computed_operating_margin < 0 ? 'text-red' : 'text-green'"),
                    ]),
                    cell(class="col-md-2", [
                        p("Days Cash", class="text-overline q-mb-none"),
                        h6("{{ computed_days_cash }}"),
                    ]),
                    cell(class="col-md-2", [
                        p("FTE/AOB", class="text-overline q-mb-none"),
                        h6("{{ computed_fte_per_aob.toFixed(1) }}"),
                    ]),
                    cell(class="col-md-2", [
                        p("Avg Age Plant", class="text-overline q-mb-none"),
                        h6("{{ computed_avg_age_plant.toFixed(1) }} yrs"),
                    ]),
                    cell(class="col-md-2", [
                        p("Labor Cost %", class="text-overline q-mb-none"),
                        h6("{{ (computed_labor_cost_pct * 100).toFixed(1) }}%"),
                    ]),
                ]),
            ])
        ]),
    ])
end
