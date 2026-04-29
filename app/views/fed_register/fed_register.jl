"""Federal Register Parser UI."""
function ui_fed_register(model)
    app_layout(model, "Fed Register Parser", [
        row(class="q-mb-md items-center", [
            cell(class="col", [h5("CMS Federal Register Rate Extractor", class="q-mb-none"),
                p("Extract payment rates from CMS annual rules for constants.jl update", class="text-grey-7")]),
            cell(class="col-auto", [btn("Extract", icon="search", color="primary", @click(:run_extract))]),
        ]),
        row(class="q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [card([card_section([
                h6("Configuration", class="q-mb-md"),
                quasar(:q_select, var"v-model"=:selected_rule, label="CMS Rule",
                    var":options"="available_rules", option_value="value",
                    option_label="label", filled=true, dense=true, emit_value=true,
                    map_options=true, class="q-mb-sm"),
                textfield(:prior_ipps, label="Prior IPPS Base Rate", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:prior_opps_cf, label="Prior OPPS CF", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:prior_reh, label="Prior REH Monthly Payment", type="number", filled=true, dense=true, class="q-mb-md"),
                separator(class="q-mb-sm"),
                p("Rule: {{ rule_title }}", class="text-caption"),
                p("Doc: {{ rule_doc_number }} | Effective: {{ rule_effective }}", class="text-caption"),
                p("Status: {{ extraction_status }}", class="text-caption text-weight-bold"),
            ])])]),
            cell(class="col-md-8 col-xs-12", [
                card(class="q-mb-md", [card_section([
                    h6("Paste CMS Rule Text", class="q-mb-sm"),
                    quasar(:q_input, var"v-model"=:manual_text, type="textarea", filled=true,
                        rows=5, placeholder="Paste relevant section from the Federal Register PDF or HTML here (rate tables, standardized amount paragraphs, etc.)"),
                ])]),
                card(class="q-mb-md", [card_section([
                    h6("Extracted Rates", class="q-mb-sm"),
                    quasar(:q_table, var"flat"=true, dense=true,
                        var":rows"="extracted_rates",
                        var":columns"="[
                            {name:'rate_type',label:'Rate Type',field:'rate_type'},
                            {name:'value',label:'Value',field:'value'},
                            {name:'unit',label:'Unit',field:'unit'},
                            {name:'confidence',label:'Confidence',field:'confidence'},
                        ]", row_key="rate_type"),
                ])]),
                card([card_section([
                    h6("Generated constants.jl Snippet (review before committing)", class="q-mb-sm"),
                    quasar(:q_input, var"v-model"=:generated_constants, type="textarea",
                        filled=true, readonly=true, rows=6,
                        style="font-family: monospace; font-size: 12px"),
                ])]),
            ]),
        ]),
    ])
end
