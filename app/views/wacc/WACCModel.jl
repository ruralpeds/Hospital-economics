"""
    WACCModel — A-04 Nonprofit WACC Calculator

Stipple reactive model for calculating weighted average cost of capital
tailored for rural nonprofit hospitals.
"""
@app begin
    # ──────── Inputs ────────
    @in ccn::String = ""
    @in fiscal_year::Int = 2023
    @in cost_of_equity_model::String = "capm"
    @in risk_free_rate::Float64 = 0.04
    @in market_risk_premium::Float64 = 0.06
    @in beta::Float64 = 1.0
    @in sp_rating::String = "B"

    @in use_hcris::Bool = true
    @in manual_equity_pct::Float64 = 0.55
    @in manual_debt_pct::Float64 = 0.45
    @in manual_lt_debt::Float64 = 20_000_000.0
    @in manual_net_assets::Float64 = 25_000_000.0

    # ──────── State ────────
    @in is_loading::Bool = false
    @in error_message::String = ""

    # ──────── Outputs ────────
    @out wacc_value::Float64 = 0.0
    @out cost_of_equity::Float64 = 0.0
    @out cost_of_debt::Float64 = 0.0
    @out target_debt_ratio::Float64 = 0.0
    @out equity_ratio::Float64 = 1.0

    @out peer_median_wacc::Float64 = 0.065
    @out peer_std_wacc::Float64 = 0.015
    @out relative_position::String = "At median"

    @out show_advanced::Bool = false

    # ──────── UI state ────────
    @out chart_data::Vector = []
    @out table_data::Vector = []

    # ──────── Handlers ────────
    @onchange ccn, fiscal_year, use_hcris begin
        if use_hcris && !isempty(ccn) && fiscal_year > 0
            is_loading = true
            error_message = ""
        end
    end

    @onchange cost_of_equity_model, beta, risk_free_rate, market_risk_premium,
             sp_rating, manual_equity_pct, manual_debt_pct,
             manual_lt_debt, manual_net_assets begin
        is_loading = true
        error_message = ""
    end

    @onbutton calculate_wacc_btn begin
        is_loading = true
        error_message = ""

        try
            # Build balance sheet (either from HCRIS or manual)
            if use_hcris && !isempty(ccn)
                # Would call: import_hcris(ccn, fiscal_year)
                # For now, use manual inputs
                pass
            end

            # Create NamedTuple for financials
            financials = (
                total_operating_revenue = 20_000_000.0,
                total_operating_expenses = 19_000_000.0
            )

            # Create balance sheet
            bs = BalanceSheetSnapshot(
                as_of_date = Date(fiscal_year, 12, 31),
                cash_and_equivalents = 2_000_000.0,
                short_term_investments = 1_000_000.0,
                accounts_receivable_net = 3_000_000.0,
                inventory = 500_000.0,
                gross_ppe = 50_000_000.0,
                accumulated_depreciation = 10_000_000.0,
                long_term_investments = 5_000_000.0,
                accounts_payable = 2_000_000.0,
                accrued_expenses = 1_000_000.0,
                current_portion_lt_debt = 500_000.0,
                long_term_debt = manual_lt_debt,
                net_assets_unrestricted = manual_net_assets
            )

            # Call API
            payload = Dict(
                "cost_of_equity_model" => cost_of_equity_model,
                "risk_free_rate" => risk_free_rate,
                "market_risk_premium" => market_risk_premium,
                "beta" => beta,
                "rating" => sp_rating
            )

            result = request(:post, "/api/analytics/wacc", payload)
            if haskey(result, "error")
                error_message = get(result, "error", "Unknown error")
            else
                wacc_value = Float64(get(result, "wacc", 0.0))
                cost_of_equity = Float64(get(result, "cost_of_equity", 0.0))
                cost_of_debt = Float64(get(result, "cost_of_debt", 0.0))
                target_debt_ratio = Float64(get(result, "target_debt_ratio", 0.3))
                equity_ratio = 1.0 - target_debt_ratio

                # Position relative to peer median (benchmark)
                if wacc_value < peer_median_wacc - peer_std_wacc
                    relative_position = "Below peer median (favorable)"
                elseif wacc_value > peer_median_wacc + peer_std_wacc
                    relative_position = "Above peer median (challenging)"
                else
                    relative_position = "At peer median"
                end
            end
        catch e
            error_message = "Error calculating WACC: $(sprint(showerror, e))"
        finally
            is_loading = false
        end
    end

    # Advanced view toggle
    @onbutton toggle_advanced_btn begin
        show_advanced = !show_advanced
    end

end
