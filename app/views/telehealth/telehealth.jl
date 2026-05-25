"""Telehealth & RPM Financial Valuation DSL UI"""
function ui_telehealth(model)
    app_layout(model, "Telehealth ROI", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Telehealth & Remote Patient Monitoring Financial Valuation", class="q-mb-none"),
                p("Evaluate telehealth service ROI and RPM program financial impact",
                  class="text-grey-7"),
            ]),
        ]),

        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-xs-12 col-sm-6", [
                card([card_section([
                    h6("Telehealth Service Configuration", class="q-mb-md"),
                    textfield(:selected_service, label="Select CPT code",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:patient_volume, label="Annual patient volume", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
            cell(class="col-xs-12 col-sm-6", [
                card([card_section([
                    h6("RPM Program Parameters", class="q-mb-md"),
                    textfield(:enrolled_rpm_patients, label="Enrolled RPM patients", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:rpm_monthly_cost, label="Monthly monitoring cost per patient (\$)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:rpm_monthly_reimbursement, label="Monthly reimbursement per patient (\$)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:readmission_reduction, label="Readmission reduction % (0-1)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
        ]),

        @if(!isempty(:error_message))
            row([cell(class="col-xs-12", [card([card_section(class="bg-red-2", [text(:error_message)])])])])
        @end

        @if(:annual_visits > 0)
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("Annual Visits"), heading(@text(:annual_visits, format(x)=Printf.@sprintf("%d", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("Annual Revenue"), heading(@text(:annual_revenue, format(x)=Printf.@sprintf("\$%.0f", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("Annual Costs"), heading(@text(:annual_costs, format(x)=Printf.@sprintf("\$%.0f", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("Margin %"), heading(@text(:gross_margin_pct, format(x)=Printf.@sprintf("%.1f%%", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("ROI %"), heading(@text(:roi_pct, format(x)=Printf.@sprintf("%.1f%%", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("Payback"), heading(@text(:payback_months, format(x)=Printf.@sprintf("%.1f mo", x)), class="text-h6 q-my-md")])])]),
            ])
            row(class="q-mb-lg", [cell(class="col-xs-12", [card([card_section([
                text("Break-even volume: ", @text(:break_even_volume, format(x)=Printf.@sprintf("%d visits/month", x)), class="text-body2"),
            ])])])])
        @end

        @if(:rpm_total_value > 0)
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("Annual Direct Benefit"), heading(@text(:rpm_annual_direct_benefit, format(x)=Printf.@sprintf("\$%.0f", x)), class="text-h5 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("Readmission Avoidance"), heading(@text(:rpm_readmission_avoidance, format(x)=Printf.@sprintf("\$%.0f", x)), class="text-h5 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("Total Annual Value"), heading(@text(:rpm_total_value, format(x)=Printf.@sprintf("\$%.0f", x)), class="text-h5 q-my-md")])])]),
            ])
        @end

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
