"""340B Drug Program Savings Estimator DSL UI"""
function ui_program_340b(model)
    app_layout(model, "340B Program", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("340B Drug Program Savings Estimator", class="q-mb-none"),
                p("Estimate savings and optimize drug mix under the 340B program",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Optimize Drug Mix", icon="tune", color="accent",
                    @click("optimize_mix_btn")),
            ]),
        ]),

        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-xs-12 col-sm-6", [
                card([card_section([
                    h6("Formulary Control", class="q-mb-md"),
                    btn("Load Sample Formulary", color="primary", class="full-width q-mb-md",
                        @click("load_sample_btn")),
                    textfield(:upload_csv, label="Or upload CSV",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
            cell(class="col-xs-12 col-sm-6", [
                card([card_section([
                    h6("Program Parameters", class="q-mb-md"),
                    textfield(:managed_care_cap, label="Managed care discount cap", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:budget_constraint, label="Annual budget constraint (\$)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
        ]),

        @if(!isempty(:error_message))
            row([cell(class="col-xs-12", [card([card_section(class="bg-red-2", [text(:error_message)])])])])
        @end

        @if(:total_annual_usage > 0)
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("Annual Units"), heading(@text(:total_annual_usage, format(x)=Printf.@sprintf("%.0f", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("Avg Discount %"), heading(@text(:avg_discount_pct, format(x)=Printf.@sprintf("%.1f%%", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("Est. Annual Savings"), heading(@text(:estimated_savings, format(x)=Printf.@sprintf("\$%.0f", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-2", [card([card_section(class="text-center", [text("Ceiling/AWP Ratio"), heading(@text(:ceiling_ratio, format(x)=Printf.@sprintf("%.2f", x)), class="text-h6 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("MAC Applicable"), heading(@text(:managed_care_applicability, format(x)=Printf.@sprintf("%.1f%%", x)), class="text-h6 q-my-md")])])]),
            ])
        @end

        @if(:optimized_drug_count > 0)
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("Selected Drugs"), heading(@text(:optimized_drug_count, format(x)=Printf.@sprintf("%d", x)), class="text-h5 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("Optimization Savings"), heading(@text(:optimization_savings, format(x)=Printf.@sprintf("\$%.0f", x)), class="text-h5 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("Budget Remaining"), heading(@text(:budget_remaining, format(x)=Printf.@sprintf("\$%.0f", x)), class="text-h5 q-my-md")])])]),
                cell(class="col-xs-12 col-sm-3", [card([card_section(class="text-center", [text("Optimized Units"), heading(@text(:optimization_units, format(x)=Printf.@sprintf("%.0f", x)), class="text-h5 q-my-md")])])]),
            ])
        @end

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
