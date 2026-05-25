"""Medicaid DSH & Supplemental Payment Analyzer UI"""
function ui_medicaid_supplemental(model)
    app_layout(model, "Medicaid Supplemental", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Medicaid DSH & Supplemental Payment Analyzer", class="q-mb-none"),
                p("Calculate DSH adjustments and supplemental payment impacts",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate", icon="calculate", color="primary",
                    @click("calculate_btn")),
            ]),
        ]),

        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-xs-12 col-sm-6", [
                card([card_section([
                    h6("Hospital Characteristics", class="q-mb-md"),
                    textfield(:hospital_name, label="Hospital name",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:medicare_cases, label="Annual Medicare cases", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:medicaid_cases, label="Annual Medicaid cases", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:uninsured_cases, label="Annual uninsured cases", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
            cell(class="col-xs-12 col-sm-6", [
                card([card_section([
                    h6("Low-Income & Volume Metrics", class="q-mb-md"),
                    textfield(:low_income_pct, label="Low-income % of uninsured", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:medicaid_bed_days, label="Annual Medicaid bed days", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:total_bed_days, label="Total annual bed days", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:base_medicaid_payment, label="Base Medicaid payment (\$)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
        ]),

        row(class="q-mb-lg", [
            cell(class="col-xs-12", [
                card([card_section([
                    h6("Program Options", class="q-mb-md"),
                    toggle(:include_dsh, label="Include DSH adjustment"),
                    toggle(:include_upl, label="Include UPL adjustment"),
                ])])
            ]),
        ]),

        @if(!isempty(:error_message))
            row([cell(class="col-xs-12", [card([card_section(class="bg-red-2", [text(:error_message)])])])])
        @end

        @if(:dsh_index > 0)
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("Medicaid %"), heading(@text(:medicaid_caseload_pct, format(x)=Printf.@sprintf("%.1f%%", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("Low-Income %"), heading(@text(:low_income_utilization_pct, format(x)=Printf.@sprintf("%.1f%%", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("DSH Index"), heading(@text(:dsh_index, format(x)=Printf.@sprintf("%.2f", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("Est. DSH Payment"), heading(@text(:estimated_dsh_payment, format(x)=Printf.@sprintf("\$%.0f", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("DSH Range"), heading(@text(:dsh_floor, format(x)=Printf.@sprintf("\$%.0f", x)), class="text-body2 q-my-md"), text(" - "), @text(:dsh_ceiling, format(x)=Printf.@sprintf("\$%.0f", x))])])]),
            ])
        @end

        @if(:total_supplemental > 0)
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("Total Supplemental"), heading(@text(:total_supplemental, format(x)=Printf.@sprintf("\$%.0f", x)), class="text-h5 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("Supplemental %"), heading(@text(:supplemental_as_pct, format(x)=Printf.@sprintf("%.2f%%", x)), class="text-h5 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-6", [card([card_section(class="text-center", [text("Total Medicaid Revenue"), heading(@text(:total_medicaid_revenue, format(x)=Printf.@sprintf("\$%.0f", x)), class="text-h5 q-my-md")])])]),
            ])
            row(class="q-mb-lg", [cell(class="col-xs-12", [card([card_section([text(:supplemental_detail, class="text-body2")])])])])
        @end

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
