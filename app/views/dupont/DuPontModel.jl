"""
Stipple reactive model for the DuPont decomposition view.
"""
using Stipple, StippleUI, StipplePlotly
using Dates

using ...RuralHospitalSim: AnalyticsController

@app begin
    @in left_drawer_open::Bool = true

    # ── Inputs: Financials ───────────────────────────────────────────────
    @in baseline_revenue::Float64 = 20_000_000.0
    @in ebit::Float64 = 1_000_000.0
    @in interest_expense::Float64 = 500_000.0
    @in ebt::Float64 = 500_000.0
    @in net_income::Float64 = 500_000.0

    # ── Inputs: Balance Sheet ────────────────────────────────────────────
    @in bs_cash::Float64 = 2_000_000.0
    @in bs_short_term_inv::Float64 = 1_000_000.0
    @in bs_ar::Float64 = 3_000_000.0
    @in bs_inventory::Float64 = 500_000.0
    @in bs_gross_ppe::Float64 = 50_000_000.0
    @in bs_accumulated_depr::Float64 = 10_000_000.0
    @in bs_lt_inv::Float64 = 5_000_000.0
    @in bs_ap::Float64 = 2_000_000.0
    @in bs_accrued_exp::Float64 = 1_000_000.0
    @in bs_cp_debt::Float64 = 500_000.0
    @in bs_lt_debt::Float64 = 20_000_000.0
    @in bs_net_assets::Float64 = 25_000_000.0

    @in tax_exempt::Bool = true

    # ── Control ──────────────────────────────────────────────────────────
    @in run_analysis::Bool = false

    # ── Output ───────────────────────────────────────────────────────────
    @out is_loading::Bool = false
    @out error_message::String = ""
    @out three_factor::Union{Dict, Nothing} = nothing
    @out five_factor::Union{Dict, Nothing} = nothing
    @out metadata::Union{Dict, Nothing} = nothing

    # Chart data for bar chart
    @out chart_labels::Vector{String} = String[]
    @out chart_3f_values::Vector{Float64} = Float64[]
    @out chart_5f_values::Vector{Float64} = Float64[]

    @onchange run_analysis begin
        if run_analysis
            is_loading = true
            error_message = ""
            try
                payload = Dict(
                    "baseline_revenue" => baseline_revenue,
                    "ebit" => ebit,
                    "interest_expense" => interest_expense,
                    "ebt" => ebt,
                    "net_income" => net_income,
                    "bs_cash" => bs_cash,
                    "bs_short_term_inv" => bs_short_term_inv,
                    "bs_ar" => bs_ar,
                    "bs_inventory" => bs_inventory,
                    "bs_gross_ppe" => bs_gross_ppe,
                    "bs_accumulated_depr" => bs_accumulated_depr,
                    "bs_lt_inv" => bs_lt_inv,
                    "bs_ap" => bs_ap,
                    "bs_accrued_exp" => bs_accrued_exp,
                    "bs_cp_debt" => bs_cp_debt,
                    "bs_lt_debt" => bs_lt_debt,
                    "bs_net_assets" => bs_net_assets,
                    "tax_exempt" => tax_exempt
                )

                result = AnalyticsController.handle_dupont(payload)

                if result["status"] == "success"
                    three_factor = result["three_factor"]
                    five_factor = result["five_factor"]
                    metadata = result["metadata"]

                    # Build chart data
                    chart_labels = [
                        "NPM", "ATO", "EM", "RONA (3F)",
                        "OM", "IB", "TB", "RONA (5F)"
                    ]
                    chart_3f_values = [
                        three_factor["net_profit_margin"],
                        three_factor["asset_turnover"],
                        three_factor["equity_multiplier"],
                        three_factor["return_on_net_assets"]
                    ]
                    chart_5f_values = [
                        five_factor["operating_margin"],
                        five_factor["interest_burden"],
                        five_factor["tax_burden"],
                        five_factor["return_on_net_assets"]
                    ]

                    error_message = ""
                else
                    error_message = get(result, "message", "Unknown error")
                    three_factor = nothing
                    five_factor = nothing
                    metadata = nothing
                    chart_labels = String[]
                    chart_3f_values = Float64[]
                    chart_5f_values = Float64[]
                end
            catch err
                error_message = sprint(showerror, err)
                three_factor = nothing
                five_factor = nothing
                metadata = nothing
                chart_labels = String[]
                chart_3f_values = Float64[]
                chart_5f_values = Float64[]
            end
            is_loading = false
            run_analysis = false
        end
    end
end
