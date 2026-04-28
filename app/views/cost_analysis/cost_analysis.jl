"""
Cost Analysis UI (E7) — total cost KPIs, breakdown chart+table, trend, high-cost patients.
"""

function ui_cost_analysis(model)
    app_layout(model, "Cost Analysis", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Cost Analysis", class="q-mb-none"),
                p("Total cost of care, episode costs, high-cost patient identification",
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
            (name=:cohort_id,      type=:cohort_picker, label="Cohort"),
            (name=:date_from,      type=:date,          label="Date From"),
            (name=:date_to,        type=:date,          label="Date To"),
            (name=:cost_year,      type=:integer,       label="Cost Year",      min=2000, max=2030),
            (name=:discount_rate,  type=:percent,       label="Discount Rate",  min=0.0, max=0.15, step=0.005,
             help="Annual discount rate for cost projections"),
            (name=:high_cost_pct,  type=:percent,       label="High-Cost Threshold",
             min=0.01, max=0.25, step=0.01,
             help="Top N% of patients by cost to flag as high-cost"),
            (name=:categories,     type=:multiselect,   label="Cost Categories",
             options=[
                 Dict(:label=>"Inpatient",  :value=>"inpatient"),
                 Dict(:label=>"Outpatient", :value=>"outpatient"),
                 Dict(:label=>"Pharmacy",   :value=>"pharmacy"),
                 Dict(:label=>"Imaging",    :value=>"imaging"),
                 Dict(:label=>"Lab",        :value=>"lab"),
                 Dict(:label=>"DME",        :value=>"dme"),
             ]),
        ], title="Analysis Parameters"),

        # KPI cards
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total Cost", class="text-overline q-mb-none"),
                    h4("\${{ (total_cost / 1e6).toFixed(2) }}M", class="q-mb-none"),
                    p("95% CI: \${{ (total_cost_ci_low / 1e6).toFixed(2) }}M–\${{ (total_cost_ci_high / 1e6).toFixed(2) }}M",
                      class="text-caption text-grey-6"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Cost per QALY", class="text-overline q-mb-none"),
                    h4("\${{ cost_per_qaly.toLocaleString('en-US', {maximumFractionDigits: 0}) }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("High-Cost Patients", class="text-overline q-mb-none"),
                    h4("{{ n_high_cost_patients.toLocaleString() }}", class="q-mb-none"),
                ])])
            ]),
        ]),

        # Breakdown chart + table
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                plot_panel(:breakdown_data, :breakdown_layout,
                    preset=:bar_breakdown, title="Cost Breakdown by Category"),
            ]),
            cell(class="col-md-6 col-xs-12", [
                result_table(
                    :breakdown_rows,
                    columns=[
                        (name="category",   label="Category",   field="category",   sortable=true),
                        (name="total_cost", label="Total Cost", field="total_cost", sortable=true, format="currency"),
                        (name="pct_total",  label="% of Total", field="pct_total",  sortable=true, format="percent"),
                        (name="per_member", label="PMPM",       field="per_member", sortable=true, format="currency"),
                    ],
                    title="Cost Breakdown",
                ),
            ]),
        ]),

        # Trend chart
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-xs-12", [
                plot_panel(:trend_data, :trend_layout,
                    preset=:trend, title="Cost Trend Over Time"),
            ]),
        ]),

        # High-cost patients table
        result_table(
            :high_cost_rows,
            columns=[
                (name="patient_id",  label="Patient ID",  field="patient_id",  sortable=false),
                (name="total_cost",  label="Total Cost",  field="total_cost",  sortable=true, format="currency"),
                (name="primary_dx",  label="Primary DX",  field="primary_dx",  sortable=false),
                (name="payer",       label="Payer",       field="payer",       sortable=true),
                (name="admits",      label="Admits",      field="admits",      sortable=true, format="number"),
            ],
            title="High-Cost Patients",
            rows_per_page=15,
        ),

        # Export bar
        export_bar(csv_field=nothing, xlsx_field=nothing, json_field=nothing,
                   label="Export cost analysis"),
    ])
end
