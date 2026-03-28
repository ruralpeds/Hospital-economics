"""
Stipple reactive model for 7-Slider Financial Simulator.
Projects 5-year financials based on 7 key operational sliders.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── 7 Slider Inputs ─────────────────────────────────────────────────
    @in ed_visits::Int = 4200
    @in ip_discharges::Int = 620
    @in medicare_pct::Float64 = 0.62
    @in commercial_pct::Float64 = 0.12
    @in inflation_rate::Float64 = 0.035
    @in travel_nurse_pct::Float64 = 0.08
    @in avg_length_of_stay::Float64 = 3.8
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out year_labels::Vector{String} = ["Year 1", "Year 2", "Year 3", "Year 4", "Year 5"]
    @out projected_revenue::Vector{Float64} = [18.5, 18.9, 19.3, 19.7, 20.1]
    @out projected_expenses::Vector{Float64} = [19.2, 19.9, 20.6, 21.3, 22.0]
    @out projected_margin_pct::Vector{Float64} = [-3.8, -5.3, -6.7, -8.1, -9.5]
    @out year1_revenue::Float64 = 18_500_000.0
    @out year5_revenue::Float64 = 20_100_000.0
    @out year5_margin::Float64 = -0.095
    @out total_5yr_gap::Float64 = -6_700_000.0

    @out payer_breakdown::Vector{Float64} = [62, 18, 12, 8]
    @out payer_labels::Vector{String} = ["Medicare", "Medicaid", "Commercial", "Self-Pay"]

    # ── Chart Data ──────────────────────────────────────────────────────
    @out margin_trajectory_data::Vector{PlotData} = [
        PlotData(
            x = ["Year 1", "Year 2", "Year 3", "Year 4", "Year 5"],
            y = [18.5, 18.9, 19.3, 19.7, 20.1],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Revenue (\$M)", mode = "lines+markers"),
        PlotData(
            x = ["Year 1", "Year 2", "Year 3", "Year 4", "Year 5"],
            y = [19.2, 19.9, 20.6, 21.3, 22.0],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Expenses (\$M)", mode = "lines+markers"),
        PlotData(
            x = ["Year 1", "Year 2", "Year 3", "Year 4", "Year 5"],
            y = [-3.8, -5.3, -6.7, -8.1, -9.5],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Margin %"),
    ]
    @out margin_trajectory_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "5-Year Financial Projection"),
        xaxis = [PlotLayoutAxis(title = "Year")],
        yaxis = [PlotLayoutAxis(title = "\$M / Margin %")],
    )

    @out payer_doughnut_data::Vector{PlotData} = [
        PlotData(
            values = [62, 18, 12, 8],
            labels = ["Medicare", "Medicaid", "Commercial", "Self-Pay"],
            plot = StipplePlotly.Charts.PLOT_TYPE_PIE,
            hole = 0.5,
            name = "Payer Mix",
        )
    ]
    @out payer_doughnut_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Payer Mix Distribution"),
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            # Revenue model: volume-driven with payer-mix weighting
            base_rev = ed_visits * 1850 * 0.42 + ip_discharges * 9350 * 0.48 +
                       (ed_visits * 3.0) * 680 * 0.52  # outpatient proxy
            travel_premium = 1.0 + travel_nurse_pct * 2.5  # travel nurses cost 2.5x
            labor_base = base_rev * 0.527 * travel_premium
            non_labor = base_rev * 0.30
            base_exp = labor_base + non_labor + 1_200_000  # fixed overhead

            rev_list = Float64[]
            exp_list = Float64[]
            for yr in 1:5
                r = base_rev * (1 + 0.02)^yr
                e = base_exp * (1 + inflation_rate)^yr
                push!(rev_list, r)
                push!(exp_list, e)
            end

            projected_revenue = round.(rev_list ./ 1e6, digits=1)
            projected_expenses = round.(exp_list ./ 1e6, digits=1)
            projected_margin_pct = round.((rev_list .- exp_list) ./ rev_list .* 100, digits=1)
            year1_revenue = rev_list[1]
            year5_revenue = rev_list[5]
            year5_margin = (rev_list[5] - exp_list[5]) / rev_list[5]
            total_5yr_gap = sum(rev_list .- exp_list)

            medicaid_pct = max(0, 1.0 - medicare_pct - commercial_pct - 0.08)
            payer_breakdown = round.([medicare_pct, medicaid_pct, commercial_pct, 0.08] .* 100, digits=0)

            margin_trajectory_data = [
                PlotData(x=year_labels, y=projected_revenue,
                    plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER, name="Revenue (\$M)", mode="lines+markers"),
                PlotData(x=year_labels, y=projected_expenses,
                    plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER, name="Expenses (\$M)", mode="lines+markers"),
                PlotData(x=year_labels, y=projected_margin_pct,
                    plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Margin %"),
            ]
            payer_doughnut_data = [PlotData(
                values=payer_breakdown, labels=payer_labels,
                plot=StipplePlotly.Charts.PLOT_TYPE_PIE, hole=0.5, name="Payer Mix")]
            @info "Financial sim: Y5 margin $(round(year5_margin*100, digits=1))%"
        end
    end
end

const financial_sim_model = @init
