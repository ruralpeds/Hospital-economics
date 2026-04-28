"""Telehealth & RPM Financial Valuation DSL UI"""
function ui_telehealth()
    page(@current, partial=true, [
        heading("Telehealth & Remote Patient Monitoring Financial Valuation", class="text-h4 q-mb-md")
        row(cell(class="col-xs-12 col-sm-6", card(card_section([
            heading("Telehealth Service Configuration", class="text-h6 q-mb-md")
            textfield(:selected_service, label="Select CPT code", class="full-width q-mb-md")
            textfield(:patient_volume, label="Annual patient volume", type="number", class="full-width")
        ]))))
        row(cell(class="col-xs-12 col-sm-6", card(card_section([
            heading("RPM Program Parameters", class="text-h6 q-mb-md")
            textfield(:enrolled_rpm_patients, label="Enrolled RPM patients", type="number", class="full-width q-mb-md")
            textfield(:rpm_monthly_cost, label="Monthly monitoring cost per patient ($)", type="number", class="full-width q-mb-md")
            textfield(:rpm_monthly_reimbursement, label="Monthly reimbursement per patient ($)", type="number", class="full-width q-mb-md")
            textfield(:readmission_reduction, label="Readmission reduction % (0-1)", type="number", class="full-width")
        ]))))
        @if(!isempty(:error_message))
            row(cell(class="col-xs-12", card(card_section(class="bg-red-2", text(:error_message)))))
        @end
        @if(:annual_visits > 0)
            row(
                cell(class="col-xs-12 col-sm-2", card(card_section(class="text-center", [text("Annual Visits"), heading(@text(:annual_visits, format(x)=Printf.@sprintf("%d", x)), class="text-h6 q-my-md")]))),
                cell(class="col-xs-12 col-sm-2", card(card_section(class="text-center", [text("Annual Revenue"), heading(@text(:annual_revenue, format(x)=Printf.@sprintf("$%.0f", x)), class="text-h6 q-my-md")]))),
                cell(class="col-xs-12 col-sm-2", card(card_section(class="text-center", [text("Annual Costs"), heading(@text(:annual_costs, format(x)=Printf.@sprintf("$%.0f", x)), class="text-h6 q-my-md")]))),
                cell(class="col-xs-12 col-sm-2", card(card_section(class="text-center", [text("Margin %"), heading(@text(:gross_margin_pct, format(x)=Printf.@sprintf("%.1f%%", x)), class="text-h6 q-my-md")]))),
                cell(class="col-xs-12 col-sm-2", card(card_section(class="text-center", [text("ROI %"), heading(@text(:roi_pct, format(x)=Printf.@sprintf("%.1f%%", x)), class="text-h6 q-my-md")]))),
                cell(class="col-xs-12 col-sm-2", card(card_section(class="text-center", [text("Payback"), heading(@text(:payback_months, format(x)=Printf.@sprintf("%.1f mo", x)), class="text-h6 q-my-md")])))
            )
            row(cell(class="col-xs-12", card(card_section([
                text("Break-even volume: ", @text(:break_even_volume, format(x)=Printf.@sprintf("%d visits/month", x)), class="text-body2")
            ]))))
        @end
        @if(:rpm_total_value > 0)
            row(
                cell(class="col-xs-12 col-sm-3", card(card_section(class="text-center", [text("Annual Direct Benefit"), heading(@text(:rpm_annual_direct_benefit, format(x)=Printf.@sprintf("$%.0f", x)), class="text-h5 q-my-md")]))),
                cell(class="col-xs-12 col-sm-3", card(card_section(class="text-center", [text("Readmission Avoidance"), heading(@text(:rpm_readmission_avoidance, format(x)=Printf.@sprintf("$%.0f", x)), class="text-h5 q-my-md")]))),
                cell(class="col-xs-12 col-sm-3", card(card_section(class="text-center", [text("Total Annual Value"), heading(@text(:rpm_total_value, format(x)=Printf.@sprintf("$%.0f", x)), class="text-h5 q-my-md")])))
            )
        @end
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ]) |> html
end
