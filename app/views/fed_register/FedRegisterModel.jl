"""Federal Register Rate Extractor Model (F-07)."""
using Stipple, StippleUI, StipplePlotly
using ...FinanceEngine: build_fed_register_api_url, CMS_RULE_REGISTRY,
                        extract_rates_from_text, generate_constants_update,
                        validate_rate_extraction, RateExtraction
using Dates

@app begin
    @in selected_rule::String        = "IPPS_FY2026"
    @in manual_text::String          = ""
    @in prior_ipps::Float64          = 6_881.0
    @in prior_opps_cf::Float64       = 89.93
    @in prior_reh::Float64           = 272_866.0
    @in run_extract::Bool            = false

    @out api_url::String             = ""
    @out rule_title::String          = "Select a rule above"
    @out rule_doc_number::String     = "—"
    @out rule_effective::String      = "—"
    @out extraction_status::String   = "Ready"
    @out extracted_rates::Vector{Dict} = []
    @out validation_results::Vector{Dict} = []
    @out generated_constants::String = "# Run extraction to generate constants update"

    @out available_rules::Vector{Dict} = [Dict("value"=>k, "label"=>v.title)
        for (k,v) in CMS_RULE_REGISTRY]

    @in errors::Vector{String} = String[]

    @onchange run_extract begin
        if run_extract
            run_extract = false
            errors = String[]
            extraction_status = "Processing..."
            try
                rule = CMS_RULE_REGISTRY[selected_rule]
                rule_title      = rule.title
                rule_doc_number = rule.fr_doc
                rule_effective  = string(rule.effective)
                api_url         = build_fed_register_api_url()

                if isempty(strip(manual_text))
                    extraction_status = "Paste rule text to extract rates"
                else
                    exts = extract_rates_from_text(manual_text, selected_rule, rule.effective)
                    extracted_rates = [Dict("rate_type"=>string(e.rate_type),
                        "value"=>e.value, "unit"=>e.unit,
                        "confidence"=>string(e.confidence)) for e in exts]
                    prior = Dict(:ipps_base_rate=>prior_ipps, :opps_cf=>prior_opps_cf,
                                 :reh_monthly_payment=>prior_reh)
                    vr = validate_rate_extraction(exts; prior_year_rates=prior)
                    validation_results = [Dict("rate"=>string(v.rate_type),
                        "pct_chg"=>isnan(v.pct_change) ? "—" : "$(round(v.pct_change,digits=1))%",
                        "flag"=>string(v.flag)) for v in vr]
                    generated_constants = generate_constants_update(exts; current_constants=prior)
                    extraction_status = "$(length(exts)) rate(s) extracted"
                end
            catch e
                errors = ["$(sprint(showerror,e))"]
                extraction_status = "Error — see error panel"
            end
        end
    end
end
const fed_register_model = @init
