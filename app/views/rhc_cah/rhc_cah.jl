"""RHC/CAH DSL UI (A-08) - express version"""
function ui_rhc_cah(model)
    app_layout(model, "RHC vs CAH Comparison", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("RHC vs CAH Reimbursement Analysis", class="q-mb-none"),
                p("Compare Rural Health Clinic and Critical Access Hospital reimbursement models",
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
                    h6("RHC Visits", class="q-mb-md"),
                    textfield(:rhc_visits_json, label="RHC visits (JSON)", placeholder="{\"initial_visit\":100}",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
            cell(class="col-xs-12 col-sm-6", [
                card([card_section([
                    h6("CAH DRGs", class="q-mb-md"),
                    textfield(:ar_volumes_json, label="AR volumes (JSON)", placeholder="{\"MDC01\":50}",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:non_ar_volumes_json, label="Non-AR volumes (JSON)", placeholder="{}",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
        ]),

        row(class="q-mb-lg", [
            cell(class="col-xs-12", [
                card([card_section([
                    textfield(:mileage_miles, label="Miles from nearest hospital", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:conversion_cost, label="Conversion cost (\$)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
        ]),

        @if(!isempty(:error_message))
            row([cell(class="col-xs-12", [card([card_section(class="bg-red-2", [text(:error_message)])])])])
        @end

        @if(:rhc_revenue > 0)
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("RHC Revenue"), heading(@text(:rhc_revenue, format(x)=Printf.@sprintf("%.0f", x)), class="text-h5 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("CAH Revenue"), heading(@text(:cah_revenue, format(x)=Printf.@sprintf("%.0f", x)), class="text-h5 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("Difference %"), heading(@text(:revenue_difference_pct, format(x)=Printf.@sprintf("%.1f%%", x)), class="text-h5 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("Break-even"), heading(@text(:break_even_months, format(x)=Printf.@sprintf("%.1f mo", x)), class="text-h5 q-my-md")])])]),
            ])
            row([cell(class="col-xs-12 q-mt-md", [card([card_section([text(:recommendation, class="text-body1")])])])])
        @end

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
