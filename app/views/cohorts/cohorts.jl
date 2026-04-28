"""
Cohort Builder UI (E6) — inclusion/exclusion criteria, preview, save/load cohorts.
"""

function ui_cohorts(model)
    app_layout(model, "Cohort Builder", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Cohort Builder", class="q-mb-none"),
                p("Define patient cohorts using inclusion and exclusion criteria",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Preview Cohort", icon="group", color="primary",
                    @click(:run_preview),
                    var":loading"="running"),
                btn("Save Cohort", icon="save", color="secondary",
                    class="q-ml-sm", @click(:save_cohort),
                    var":disable"="running || matching_count === 0"),
            ]),
        ]),

        # Error banner
        template(var"v-if"="errors && errors.length > 0", [
            card(class="q-mb-md bg-red-1 text-red-9", [
                card_section([
                    p("Errors:", class="text-weight-bold q-mb-xs"),
                    template(var"v-for"="(err, idx) in errors", var":key"="idx", [
                        p(class="q-mb-none", ["{{ err }}"]),
                    ]),
                ]),
            ]),
        ]),

        # KPI: matching count
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Matching Patients", class="text-overline q-mb-none"),
                    h4("{{ matching_count.toLocaleString() }}", class="q-mb-none"),
                ])])
            ]),
            template(var"v-if"="cohort_stats && cohort_stats.age_min !== undefined", [
                cell(class="col-md-3 col-sm-6 col-xs-12", [
                    card([card_section(class="text-center", [
                        p("Age Range", class="text-overline q-mb-none"),
                        h4("{{ cohort_stats.age_min }}–{{ cohort_stats.age_max }}", class="q-mb-none"),
                    ])])
                ]),
                cell(class="col-md-3 col-sm-6 col-xs-12", [
                    card([card_section(class="text-center", [
                        p("LOS Range (days)", class="text-overline q-mb-none"),
                        h4("{{ cohort_stats.los_min }}–{{ cohort_stats.los_max }}", class="q-mb-none"),
                    ])])
                ]),
            ]),
        ]),

        # Source asset
        form_grid([
            (name=:asset_id, type=:numeric, label="Source Asset ID",
             help="Asset ID containing patient encounter data"),
            (name=:cohort_name,        type=:numeric, label="Cohort Name"),
            (name=:cohort_description, type=:numeric, label="Description"),
        ], title="Cohort Metadata"),

        # Inclusion criteria
        form_grid([
            (name=:inclusion_age_min,  type=:integer, label="Min Age",  min=0, max=120),
            (name=:inclusion_age_max,  type=:integer, label="Max Age",  min=0, max=120),
            (name=:inclusion_los_min,  type=:integer, label="Min LOS (days)", min=0, max=365),
            (name=:inclusion_los_max,  type=:integer, label="Max LOS (days)", min=0, max=365),
            (name=:inclusion_cost_min, type=:currency, label="Min Cost",  min=0.0),
            (name=:inclusion_cost_max, type=:currency, label="Max Cost"),
            (name=:inclusion_date_from, type=:date, label="Encounter From"),
            (name=:inclusion_date_to,   type=:date, label="Encounter To"),
            (name=:inclusion_dx, type=:code_search, label="Include Diagnoses (ICD-10)"),
            (name=:inclusion_px, type=:code_search, label="Include Procedures (CPT)"),
            (name=:inclusion_payers, type=:multiselect, label="Include Payers",
             options=[
                 Dict(:label=>"Medicare",   :value=>"medicare"),
                 Dict(:label=>"Medicaid",   :value=>"medicaid"),
                 Dict(:label=>"Commercial", :value=>"commercial"),
                 Dict(:label=>"Self-Pay",   :value=>"self_pay"),
                 Dict(:label=>"Other",      :value=>"other"),
             ]),
        ], title="Inclusion Criteria"),

        # Exclusion criteria
        form_grid([
            (name=:exclusion_dx, type=:code_search, label="Exclude Diagnoses (ICD-10)"),
            (name=:exclusion_px, type=:code_search, label="Exclude Procedures (CPT)"),
        ], title="Exclusion Criteria"),

        # Preview table
        template(var"v-if"="preview_rows && preview_rows.length > 0", [
            result_table(
                :preview_rows,
                columns=[
                    (name="patient_id",    label="Patient ID",    field="patient_id",    sortable=true),
                    (name="age",           label="Age",           field="age",           sortable=true),
                    (name="payer",         label="Payer",         field="payer",         sortable=true),
                    (name="los",           label="LOS",           field="los",           sortable=true),
                    (name="total_cost",    label="Total Cost",    field="total_cost",    sortable=true, format="currency"),
                    (name="primary_dx",    label="Primary DX",    field="primary_dx",    sortable=false),
                ],
                title="Patient Preview",
                rows_per_page=15,
            ),
        ]),

        # Saved cohorts table
        result_table(
            :saved_cohorts,
            columns=[
                (name="id",          label="ID",          field="id",          sortable=false),
                (name="name",        label="Name",        field="name",        sortable=true),
                (name="description", label="Description", field="description", sortable=false),
                (name="count",       label="Patients",    field="count",       sortable=true, format="number"),
            ],
            title="Saved Cohorts",
        ),
    ])
end
