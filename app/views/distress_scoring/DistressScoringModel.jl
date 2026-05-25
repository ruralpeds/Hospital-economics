"""
Stipple reactive model for distress scoring (Altman Z″ + Beneish M).
"""
using Stipple, StippleUI, StipplePlotly

using ...RuralHospitalSim: AnalyticsController

@app begin
    @in left_drawer_open::Bool = true

    # Financials (current year)
    @in revenue_current::Float64 = 20_000_000.0
    @in expenses_current::Float64 = 19_000_000.0
    @in ebit_current::Float64 = 1_000_000.0
    @in interest_current::Float64 = 500_000.0

    # Key BS items (current)
    @in cash_curr::Float64 = 2_000_000.0
    @in ar_curr::Float64 = 3_000_000.0
    @in ppe_gross_curr::Float64 = 50_000_000.0
    @in depr_accum_curr::Float64 = 10_000_000.0
    @in ap_curr::Float64 = 2_000_000.0
    @in ltd_curr::Float64 = 20_000_000.0
    @in na_curr::Float64 = 25_000_000.0

    # Prior year (defaults to same)
    @in revenue_prior::Float64 = 19_500_000.0
    @in ebit_prior::Float64 = 1_000_000.0
    @in cash_prior::Float64 = 2_000_000.0
    @in ar_prior::Float64 = 3_000_000.0
    @in ltd_prior::Float64 = 20_500_000.0
    @in na_prior::Float64 = 24_500_000.0

    @in run_analysis::Bool = false

    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out is_loading::Bool = false
    @out error_message::String = ""
    @out altman::Union{Dict, Nothing} = nothing
    @out beneish::Union{Dict, Nothing} = nothing

    @onchange run_analysis begin
        if run_analysis
            run_analysis = false
            is_loading = true
            error_message = ""
            try
                payload = Dict(
                    "revenue_current" => revenue_current,
                    "expenses_current" => expenses_current,
                    "ebit_current" => ebit_current,
                    "interest_current" => interest_current,
                    "revenue_prior" => revenue_prior,
                    "ebit_prior" => ebit_prior,
                    "cash_curr" => cash_curr,
                    "ar_curr" => ar_curr,
                    "ppe_gross_curr" => ppe_gross_curr,
                    "depr_accum_curr" => depr_accum_curr,
                    "ap_curr" => ap_curr,
                    "ltd_curr" => ltd_curr,
                    "na_curr" => na_curr,
                    "cash_prior" => cash_prior,
                    "ar_prior" => ar_prior,
                    "ltd_prior" => ltd_prior,
                    "na_prior" => na_prior
                )

                result = AnalyticsController.handle_distress_scoring(payload)

                if result["status"] == "success"
                    altman = result["altman"]
                    beneish = result["beneish"]
                    error_message = ""
                else
                    error_message = get(result, "message", "Unknown error")
                    altman = nothing
                    beneish = nothing
                end
            catch e
                push!(errors, string(e))
                error_message = sprint(showerror, e)
                altman = nothing
                beneish = nothing
            finally
                is_loading = false
            end
        end
    end
end
