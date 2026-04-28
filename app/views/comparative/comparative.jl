"""
Comparative Effectiveness UI (E16) — forest plots, funnel plots, SMR,
and subgroup analysis.
"""

function ui_comparative(model)
    app_layout(model, "Comparative Effectiveness", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Comparative Effectiveness", class="q-mb-none"),
                p("Treatment outcome comparisons, practice variation, SMR, and subgroup analysis",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Compare", icon="compare", color="primary",
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
            (name=:cohort_id,     type=:text,   label="Cohort Asset ID"),
            (name=:treatment_col, type=:text,   label="Treatment Column"),
            (name=:outcome_col,   type=:text,   label="Outcome Column"),
            (name=:facility_id,   type=:text,   label="Facility ID",        help="Optional facility filter"),
            (name=:provider_col,  type=:text,   label="Provider Column",    help="For practice variation analysis"),
            (name=:measure_col,   type=:text,   label="Quality Measure",    help="Column with quality score"),
            (name=:subgroup_col,  type=:text,   label="Subgroup Column"),
            (name=:modifier_col,  type=:text,   label="Effect Modifier",    help="For interaction testing"),
            (name=:time_period,   type=:select, label="Time Period",
             options=[
                 Dict("value"=>"3months",  "label"=>"3 Months"),
                 Dict("value"=>"6months",  "label"=>"6 Months"),
                 Dict("value"=>"12months", "label"=>"12 Months"),
             ]),
        ], title="Comparison Parameters"),

        # Results table
        result_table(
            :result_rows,
            columns=[
                (name="group",        label="Group",        field="group",        sortable=true),
                (name="n",            label="N",            field="n",            sortable=true),
                (name="effect",       label="Effect",       field="effect",       sortable=true),
                (name="ci_low",       label="CI Low",       field="ci_low",       sortable=true),
                (name="ci_high",      label="CI High",      field="ci_high",      sortable=true),
                (name="p_value",      label="p-value",      field="p_value",      sortable=true),
                (name="heterogeneity",label="I²",           field="heterogeneity",sortable=true),
            ],
            title="Comparative Results",
        ),

        # Plots
        row(class="q-mb-md q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                plot_panel(:forest_data, :forest_layout,
                    preset=:scatter, title="Forest Plot"),
            ]),
            cell(class="col-md-6 col-xs-12", [
                plot_panel(:funnel_data, :funnel_layout,
                    preset=:scatter, title="Funnel Plot (Publication Bias)"),
            ]),
        ]),
        row(class="q-mb-md", [
            cell(class="col-xs-12", [
                plot_panel(:smr_data, :smr_layout,
                    preset=:bar, title="Standardized Mortality Ratio (SMR) by Provider"),
            ]),
        ]),

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
