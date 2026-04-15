"""
Stipple reactive model for Debt Capacity Calculator.
Computes maximum borrowing capacity, DSCR curves, and capital structure.
Delegates to RuralHospitalSim.calculate_debt_capacity() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: calculate_debt_capacity, debt_capacity_sensitivity,
    DebtCapacityParams, DebtCapacityResult


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

            # Call domain engine
            params = DebtCapacityParams(;
                ebitda=ebitda,
                current_debt=current_debt,
                annual_debt_service=annual_debt_service,
                interest_rate=interest_rate,
                loan_term_years=loan_term_years,
                target_dscr=target_dscr,
                total_assets=total_assets,
                total_equity=total_equity,
            )
            result = calculate_debt_capacity(params)

            # Map domain results
            current_dscr = result.current_dscr
            max_annual_debt_service = result.max_annual_debt_service
            max_new_borrowing = result.max_new_borrowing
            incremental_capacity = result.incremental_capacity
            debt_to_cap_current = result.debt_to_cap_current
            debt_to_cap_max = result.debt_to_cap_max

            # DSCR curve from domain sensitivity
            sensitivity = debt_capacity_sensitivity(params)
            dscr_debt_levels = [s.debt_level for s in sensitivity]
            dscr_values = [s.dscr for s in sensitivity]
            dscr_curve_data = [
                PlotData(x=round.(dscr_debt_levels ./ 1e6, digits=1), y=round.(dscr_values, digits=2),
                    plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER, name="DSCR at Debt Level",
                    mode="lines+markers"),
                PlotData(x=[0, round(maximum(dscr_debt_levels)/1e6, digits=1)], y=[target_dscr, target_dscr],
                    plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER, name="Target DSCR ($(target_dscr)x)",
                    mode="lines", line=PlotDataLine(dash="dash", color="red")),
            ]

            capital_structure_data = [PlotData(
                values = round.([current_debt, total_equity, incremental_capacity] ./ 1000, digits=0),
                labels = ["Current Debt", "Equity", "Available Capacity"],
                plot = StipplePlotly.Charts.PLOT_TYPE_PIE,
                hole = 0.5,
                name = "Capital Structure (\$K)",
            )]
            @info "Debt capacity (domain): max borrowing \$$(round(Int, max_new_borrowing/1e6))M, DSCR $(round(current_dscr, digits=2))x"
        end
    end
end

const debt_capacity_model = @init
