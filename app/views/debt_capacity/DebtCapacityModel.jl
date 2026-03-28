"""
Stipple reactive model for Debt Capacity Calculator.
Computes maximum borrowing capacity, DSCR curves, and capital structure.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in ebitda::Float64 = 1_200_000.0
    @in current_debt::Float64 = 3_500_000.0
    @in annual_debt_service::Float64 = 450_000.0
    @in interest_rate::Float64 = 0.055
    @in loan_term_years::Int = 20
    @in target_dscr::Float64 = 1.40
    @in total_assets::Float64 = 22_000_000.0
    @in total_equity::Float64 = 8_500_000.0
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out current_dscr::Float64 = 2.67
    @out max_annual_debt_service::Float64 = 857_143.0
    @out max_new_borrowing::Float64 = 9_850_000.0
    @out incremental_capacity::Float64 = 6_350_000.0
    @out debt_to_cap_current::Float64 = 0.41
    @out debt_to_cap_max::Float64 = 0.61

    # ── DSCR Curve Chart ────────────────────────────────────────────────
    @out dscr_curve_data::Vector{PlotData} = [
        PlotData(
            x = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            y = [10.0, 4.8, 3.2, 2.4, 2.0, 1.7, 1.5, 1.35, 1.2, 1.1, 1.0],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "DSCR at Debt Level",
            mode = "lines+markers",
        ),
        PlotData(
            x = [0, 10],
            y = [1.4, 1.4],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Target DSCR (1.40x)",
            mode = "lines",
            line = PlotDataLine(dash="dash", color="red"),
        ),
    ]
    @out dscr_curve_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "DSCR vs Total Debt (\$M)"),
        xaxis = [PlotLayoutAxis(title = "Total Debt (\$M)")],
        yaxis = [PlotLayoutAxis(title = "DSCR")],
    )

    # ── Capital Structure Doughnut ──────────────────────────────────────
    @out capital_structure_data::Vector{PlotData} = [
        PlotData(
            values = [3500, 8500, 10000],
            labels = ["Current Debt", "Equity", "Available Capacity"],
            plot = StipplePlotly.Charts.PLOT_TYPE_PIE,
            hole = 0.5,
            name = "Capital Structure",
        )
    ]
    @out capital_structure_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Capital Structure"),
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            current_dscr = ebitda / max(annual_debt_service, 1.0)
            max_annual_debt_service = ebitda / target_dscr

            # PMT approximation: PV = PMT * (1 - (1+r)^-n) / r
            r = interest_rate
            n = loan_term_years
            pv_factor = (1.0 - (1.0 + r)^(-n)) / r
            max_new_borrowing = round(max_annual_debt_service * pv_factor, digits=0)
            incremental_capacity = max(0, max_new_borrowing - current_debt)

            debt_to_cap_current = current_debt / (current_debt + total_equity)
            debt_to_cap_max = max_new_borrowing / (max_new_borrowing + total_equity)

            capital_structure_data = [PlotData(
                values = round.([current_debt, total_equity, incremental_capacity] ./ 1000, digits=0),
                labels = ["Current Debt", "Equity", "Available Capacity"],
                plot = StipplePlotly.Charts.PLOT_TYPE_PIE,
                hole = 0.5,
                name = "Capital Structure (\$K)",
            )]
            @info "Debt capacity: max borrowing \$$(round(Int, max_new_borrowing/1e6))M, DSCR $(round(current_dscr, digits=2))x"
        end
    end
end

const debt_capacity_model = @init
