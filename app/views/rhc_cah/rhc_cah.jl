"""RHC/CAH DSL UI (A-08) - express version"""
function ui_rhc_cah()
    page(@current, partial=true, [
        heading("RHC vs CAH Reimbursement Analysis", class="text-h4 q-mb-md")
        row(cell(class="col-xs-12 col-sm-6", card(card_section([
            heading("RHC Visits", class="text-h6 q-mb-md")
            textfield(:rhc_visits_json, label="RHC visits (JSON)", placeholder="{\"initial_visit\":100}", class="full-width q-mb-md")
        ]))))
        row(cell(class="col-xs-12 col-sm-6", card(card_section([
            heading("CAH DRGs", class="text-h6 q-mb-md")
            textfield(:ar_volumes_json, label="AR volumes (JSON)", placeholder="{\"MDC01\":50}", class="full-width q-mb-md")
            textfield(:non_ar_volumes_json, label="Non-AR volumes (JSON)", placeholder="{}", class="full-width")
        ]))))
        row(cell(class="col-xs-12", card(card_section([
            textfield(:mileage_miles, label="Miles from nearest hospital", type="number", class="full-width q-mb-md")
            textfield(:conversion_cost, label="Conversion cost ($)", type="number", class="full-width")
        ]))))
        row(cell(class="col-xs-12 col-sm-3 q-offset-sm-9", button("Calculate", @click("calculate_btn"), color="primary", class="full-width q-mb-lg")))
        @if(!isempty(:error_message))
            row(cell(class="col-xs-12", card(card_section(class="bg-red-2", text(:error_message)))))
        @end
        @if(:rhc_revenue > 0)
            row(
                cell(class="col-xs-12 col-sm-3", card(card_section(class="text-center", [text("RHC Revenue"), heading(@text(:rhc_revenue, format(x)=Printf.@sprintf("%.0f", x)), class="text-h5 q-my-md")]))),
                cell(class="col-xs-12 col-sm-3", card(card_section(class="text-center", [text("CAH Revenue"), heading(@text(:cah_revenue, format(x)=Printf.@sprintf("%.0f", x)), class="text-h5 q-my-md")]))),
                cell(class="col-xs-12 col-sm-3", card(card_section(class="text-center", [text("Difference %"), heading(@text(:revenue_difference_pct, format(x)=Printf.@sprintf("%.1f%%", x)), class="text-h5 q-my-md")]))),
                cell(class="col-xs-12 col-sm-3", card(card_section(class="text-center", [text("Break-even"), heading(@text(:break_even_months, format(x)=Printf.@sprintf("%.1f mo", x)), class="text-h5 q-my-md")])))
            )
            row(cell(class="col-xs-12 q-mt-md", card(card_section(text(:recommendation, class="text-body1")))))
        @end
    ]) |> html
end
