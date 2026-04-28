"""
Quality & Clinical Outcomes UI (E10) — readmission rates, mortality, HAI,
PSI composites, quality-of-life scores, and outcome disparities.
"""

function ui_quality(model)
    app_layout(model, "Quality & Clinical Outcomes", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Quality & Clinical Outcomes", class="q-mb-none"),
                p("Readmission rates, mortality, HAI, PSI composites, QoL, and disparities",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Run Analysis", icon="analytics", color="primary",
                    @click(:run),
                    var":loading"="running"),
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

        # Parameters
        form_grid([
            (name=:cohort_id,   type=:text, label="Cohort ID",   help="Asset ID from Cohort Builder"),
            (name=:facility_id, type=:text, label="Facility ID", help="Optional facility filter"),
            (name=:time_period, type=:select, label="Time Period",
             options=[
                 Dict("value"=>"3months",  "label"=>"3 Months"),
                 Dict("value"=>"6months",  "label"=>"6 Months"),
                 Dict("value"=>"12months", "label"=>"12 Months"),
                 Dict("value"=>"24months", "label"=>"24 Months"),
             ]),
        ], title="Cohort & Period"),

        # KPI cards
        row(class="q-mb-md q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Readmission Rate", class="text-overline q-mb-none"),
                    h4("{{ (readmission_rate * 100).toFixed(1) }}%", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Mortality Rate", class="text-overline q-mb-none"),
                    h4("{{ (mortality_rate * 100).toFixed(2) }}%", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Infection Rate", class="text-overline q-mb-none"),
                    h4("{{ (infection_rate * 100).toFixed(2) }}%", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("QoL Score", class="text-overline q-mb-none"),
                    h4("{{ qol_score.toFixed(3) }}", class="q-mb-none"),
                ])])
            ]),
        ]),

        # Sub-tabs
        qtabs(:active_sub_tab, class="q-mb-md", [
            qtab(name="readmissions", label="Readmissions"),
            qtab(name="mortality",    label="Mortality"),
            qtab(name="infections",   label="HAI"),
            qtab(name="psi",          label="PSI"),
            qtab(name="qol",          label="QoL"),
            qtab(name="disparities",  label="Disparities"),
        ]),
        qtabpanels(:active_sub_tab, [
            qtabpanel(name="readmissions", [
                form_grid([
                    (name=:procedure_code, type=:text, label="Procedure / DRG Code",
                     help="Filter by procedure or DRG (leave blank for all)"),
                ], title="Readmission Parameters"),
                result_table(
                    :outcome_rows,
                    columns=[
                        (name="cohort",     label="Cohort",         field="cohort",     sortable=true),
                        (name="n_patients", label="N Patients",     field="n_patients", sortable=true),
                        (name="rate_30d",   label="30-Day Rate",    field="rate_30d",   sortable=true, format="percent"),
                        (name="rate_90d",   label="90-Day Rate",    field="rate_90d",   sortable=true, format="percent"),
                        (name="benchmark",  label="Benchmark",      field="benchmark",  sortable=true, format="percent"),
                    ],
                    title="Readmission Rates",
                ),
            ]),
            qtabpanel(name="mortality", [
                row(class="q-mb-md", [
                    cell(class="col-xs-12", [
                        plot_panel(:km_data, :km_layout, preset=:line, title="Kaplan-Meier Survival Curve"),
                    ]),
                ]),
            ]),
            qtabpanel(name="infections", [
                form_grid([
                    (name=:infection_type, type=:select, label="Infection Type",
                     options=[
                         Dict("value"=>"clabsi", "label"=>"CLABSI"),
                         Dict("value"=>"cauti",  "label"=>"CAUTI"),
                         Dict("value"=>"ssi",    "label"=>"SSI"),
                         Dict("value"=>"cdiff",  "label"=>"C. diff"),
                     ]),
                ], title="HAI Type"),
            ]),
            qtabpanel(name="psi", [
                form_grid([
                    (name=:psi_measure, type=:select, label="PSI Measure",
                     options=[
                         Dict("value"=>"psi_03", "label"=>"PSI-03 Pressure Ulcer"),
                         Dict("value"=>"psi_06", "label"=>"PSI-06 Iatrogenic PTX"),
                         Dict("value"=>"psi_09", "label"=>"PSI-09 Periop Hemorrhage"),
                         Dict("value"=>"psi_11", "label"=>"PSI-11 Post-op Respiratory"),
                         Dict("value"=>"psi_90", "label"=>"PSI-90 Composite"),
                     ]),
                ], title="PSI Measure"),
            ]),
            qtabpanel(name="qol", [
                form_grid([
                    (name=:qol_scale, type=:select, label="QoL Instrument",
                     options=[
                         Dict("value"=>"eq5d",   "label"=>"EQ-5D"),
                         Dict("value"=>"sf36",   "label"=>"SF-36"),
                         Dict("value"=>"promis", "label"=>"PROMIS"),
                     ]),
                ], title="Quality-of-Life Scale"),
            ]),
            qtabpanel(name="disparities", [
                form_grid([
                    (name=:subgroup_variable, type=:select, label="Subgroup Variable",
                     options=[
                         Dict("value"=>"race",    "label"=>"Race/Ethnicity"),
                         Dict("value"=>"income",  "label"=>"Income Quintile"),
                         Dict("value"=>"zip",     "label"=>"Geography (ZIP)"),
                         Dict("value"=>"payer",   "label"=>"Payer Type"),
                     ]),
                ], title="Disparity Analysis"),
                row(class="q-mb-md", [
                    cell(class="col-xs-12", [
                        plot_panel(:disparities_data, :disparities_layout,
                            preset=:bar, title="Outcome Disparities by Subgroup"),
                    ]),
                ]),
            ]),
        ]),

        export_bar(csv_field=nothing, xlsx_field=nothing, json_field=nothing,
                   label="Export quality analysis"),
    ])
end
