"""
Stipple reactive model for Hospital LBO Analysis (A-08).
Provides IRR, MOIC, exit scenario table, and debt-paydown waterfall.
"""
using Stipple, StippleUI, StipplePlotly
using ...FinanceEngine: LBOInputs, hospital_lbo

@app begin
    # ── Inputs ────────────────────────────────────────────────────────────
    @in purchase_price::Float64      = 42_000_000.0
    @in ebitda_entry::Float64        = 5_200_000.0
    @in ebitda_growth_rate::Float64  = 4.0   # shown as %
    @in senior_leverage::Float64     = 4.0
    @in mezz_leverage::Float64       = 1.5
    @in senior_rate::Float64         = 7.5   # shown as %
    @in mezz_rate::Float64           = 12.5
    @in hold_years::Int              = 5
    @in recalculate::Bool            = false

    # ── Key metrics ────────────────────────────────────────────────────────
    @out entry_multiple::Float64     = 8.1
    @out senior_debt::Float64        = 20_800_000.0
    @out mezz_debt::Float64          = 7_800_000.0
    @out equity_contribution::Float64 = 13_400_000.0
    @out equity_pct::Float64         = 31.9
    @out debt_to_ebitda::Float64     = 5.5
    @out base_irr::Float64           = 18.4
    @out base_moic::Float64          = 2.3

    # ── Exit scenario table ───────────────────────────────────────────────
    @out exit_table_data::Vector{Dict} = []

    # ── Debt waterfall chart ─────────────────────────────────────────────
    @out debt_chart_data::Vector{PlotData} = []
    @out debt_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Debt Paydown Schedule"),
        xaxis=[PlotLayoutAxis(title="Year")],
        yaxis=[PlotLayoutAxis(title="Balance (\$M)")],
        barmode="stack",
    )

    # ── IRR sensitivity (hold years × exit multiple) ──────────────────────
    @out irr_heatmap::Vector{PlotData} = []
    @out irr_heatmap_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="IRR Sensitivity — Exit Multiple × Hold Years"),
    )

    @in errors::Vector{String} = String[]

    @onchange recalculate begin
        if recalculate
            recalculate = false
            errors = String[]
            try
                inputs = LBOInputs(
                    hospital_name          = "LBO Target",
                    purchase_price         = purchase_price,
                    ebitda_entry           = ebitda_entry,
                    ebitda_growth_rate     = ebitda_growth_rate / 100.0,
                    senior_leverage_multiple = senior_leverage,
                    mezz_leverage_multiple   = mezz_leverage,
                    senior_interest_rate   = senior_rate / 100.0,
                    mezz_interest_rate     = mezz_rate / 100.0,
                    hold_years             = hold_years,
                    exit_multiple_range    = [4.0, 5.0, 6.0, 7.0, 8.0, 9.0],
                )
                r = hospital_lbo(inputs)
                su = r.sources_uses

                # Key metrics
                entry_multiple    = round(su.entry_multiple, digits=1)
                senior_debt       = su.senior_debt
                mezz_debt         = su.mezz_debt
                equity_contribution = su.equity_contribution
                equity_pct        = round(su.equity_pct * 100, digits=1)
                debt_to_ebitda    = round(su.debt_to_ebitda, digits=2)
                base_irr          = round(r.base_irr * 100, digits=1)
                base_moic         = round(r.base_moic, digits=2)

                # Exit scenario table
                exit_table_data = [Dict(
                    "exit_multiple" => s.exit_multiple,
                    "exit_ev" => round(s.exit_ev / 1e6, digits=1),
                    "equity_proceeds" => round(s.sponsor_equity_proceeds / 1e6, digits=1),
                    "moic" => round(s.moic, digits=2),
                    "irr" => round(s.irr * 100, digits=1),
                ) for s in r.exit_scenarios]

                # Debt paydown chart
                yrs = [yr.year for yr in r.annual_results]
                push!(yrs, 0, 1)  # include entry
                s_bals = [su.senior_debt; [yr.senior_balance_eoy for yr in r.annual_results]] ./ 1e6
                m_bals = [su.mezz_debt;   [yr.mezz_balance_eoy   for yr in r.annual_results]] ./ 1e6
                x_years = vcat([0], yrs)
                debt_chart_data = [
                    PlotData(x=x_years, y=s_bals,
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        name="Senior Debt", marker=Dict("color"=>"#ef4444")),
                    PlotData(x=x_years, y=m_bals,
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        name="Mezz Debt", marker=Dict("color"=>"#f97316")),
                ]

            catch e
                errors = ["Calculation error: $(sprint(showerror, e))"]
            end
        end
    end
end

const lbo_model = @init
