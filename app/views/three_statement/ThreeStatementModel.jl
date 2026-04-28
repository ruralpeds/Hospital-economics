"""
Stipple reactive model for the three-statement projection view.
Delegates to AnalyticsController.handle_three_statement() for projection computation.
"""
using Stipple, StippleUI, StipplePlotly
using Dates

# Import analytics controller
using ...RuralHospitalSim: AnalyticsController

@app begin
    @in left_drawer_open::Bool = true

    # ── Input: Hospital & Time Period ────────────────────────────────────
    @in fiscal_year::Int = 2024
    @in ccn::String = ""

    # ── Input: Baseline Financials ───────────────────────────────────────
    @in baseline_revenue::Float64 = 20_000_000.0
    @in baseline_expenses::Float64 = 19_000_000.0

    # ── Input: Starting Balance Sheet ────────────────────────────────────
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

    # ── Input: Projection Assumptions ────────────────────────────────────
    @in horizon_years::Int = 5
    @in rev_growth_yr1::Float64 = 2.0
    @in rev_growth_yr2::Float64 = 2.0
    @in rev_growth_yr3::Float64 = 2.0
    @in rev_growth_yr4::Float64 = 1.0
    @in rev_growth_yr5::Float64 = 1.0

    @in exp_growth_yr1::Float64 = 3.0
    @in exp_growth_yr2::Float64 = 3.0
    @in exp_growth_yr3::Float64 = 2.0
    @in exp_growth_yr4::Float64 = 2.0
    @in exp_growth_yr5::Float64 = 2.0

    @in capex_pct_of_revenue::Float64 = 4.0
    @in interest_rate::Float64 = 5.0
    @in days_in_ar::Float64 = 50.0
    @in days_in_inventory::Float64 = 25.0
    @in days_in_ap::Float64 = 35.0
    @in debt_amort_years::Int = 20

    # ── Control ──────────────────────────────────────────────────────────
    @in run_projection::Bool = false

    # ── Output: Results ──────────────────────────────────────────────────
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out is_loading::Bool = false
    @out error_message::String = ""
    @out projection_data::Union{Dict, Nothing} = nothing

    # Data for charts
    @out chart_net_assets::Vector{Real} = Real[]
    @out chart_revenue::Vector{Real} = Real[]
    @out chart_years::Vector{Int} = Int[]

    # Table data
    @out is_table::Vector{Dict} = Dict[]
    @out bs_table::Vector{Dict} = Dict[]
    @out cf_table::Vector{Dict} = Dict[]

    @out all_bs_balance::Bool = true

    @onchange run_projection begin
        if run_projection
            is_loading = true
            error_message = ""
            try
                # Build payload
                payload = Dict(
                    "baseline_revenue" => baseline_revenue,
                    "baseline_expenses" => baseline_expenses,
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
                    "horizon_years" => horizon_years,
                    "revenue_growth" => [rev_growth_yr1, rev_growth_yr2, rev_growth_yr3, rev_growth_yr4, rev_growth_yr5][1:horizon_years] ./ 100.0,
                    "expense_growth" => [exp_growth_yr1, exp_growth_yr2, exp_growth_yr3, exp_growth_yr4, exp_growth_yr5][1:horizon_years] ./ 100.0,
                    "capex_pct" => capex_pct_of_revenue / 100.0,
                    "interest_rate" => interest_rate / 100.0,
                    "days_in_ar" => days_in_ar,
                    "days_in_inventory" => days_in_inventory,
                    "days_in_ap" => days_in_ap,
                    "debt_amort_years" => debt_amort_years
                )

                # Call controller
                result = AnalyticsController.handle_three_statement(payload)

                if result["status"] == "success"
                    projection_data = result

                    # Extract data for charts
                    chart_years = collect(1:horizon_years)
                    chart_revenue = [is["revenue"] for is in result["income_statements"]]
                    chart_net_assets = [bs["net_assets"] for bs in result["balance_sheets"]]

                    # Build IS table
                    is_table = result["income_statements"]

                    # Build BS table
                    bs_table = result["balance_sheets"]
                    all_bs_balance = all(bs["balances"] for bs in bs_table)

                    # Build CF table
                    cf_table = result["cash_flows"]

                    error_message = ""
                else
                    error_message = get(result, "message", "Unknown error")
                    projection_data = nothing
                    chart_years = Int[]
                    chart_revenue = Real[]
                    chart_net_assets = Real[]
                    is_table = Dict[]
                    bs_table = Dict[]
                    cf_table = Dict[]
                    all_bs_balance = false
                end
            catch err
                error_message = sprint(showerror, err)
                projection_data = nothing
                chart_years = Int[]
                chart_revenue = Real[]
                chart_net_assets = Real[]
                is_table = Dict[]
                bs_table = Dict[]
                cf_table = Dict[]
                all_bs_balance = false
            end
            is_loading = false
            run_projection = false  # Reset button
        end
    end
end
