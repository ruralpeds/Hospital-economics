"""
Stipple reactive model for Strategic Financial Planner.
Projects 5-year financial trajectory with timed strategic initiatives.
Delegates to RuralHospitalSim.run_scenario_set() for multi-scenario projection.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: run_scenario_set, compare_scenario_set,
    SimulationScenario, ScenarioSet, DeterministicParams, project_financials


@app begin
    @in left_drawer_open::Bool = true
    # ── Base Financial Inputs ───────────────────────────────────────────
    @in base_revenue::Float64 = 18_500_000.0
    @in base_expenses::Float64 = 19_200_000.0
    @in revenue_growth_rate::Float64 = 0.02
    @in expense_growth_rate::Float64 = 0.035

    # ── Initiative 1 ────────────────────────────────────────────────────
    @in init1_name::String = "REH Conversion"
    @in init1_year::Int = 1
    @in init1_revenue_impact::Float64 = 800_000.0
    @in init1_cost_savings::Float64 = 400_000.0

    # ── Initiative 2 ────────────────────────────────────────────────────
    @in init2_name::String = "Outpatient Expansion"
    @in init2_year::Int = 2
    @in init2_revenue_impact::Float64 = 600_000.0
    @in init2_cost_savings::Float64 = 100_000.0

    # ── Initiative 3 ────────────────────────────────────────────────────
    @in init3_name::String = "Revenue Cycle Optimization"
    @in init3_year::Int = 1
    @in init3_revenue_impact::Float64 = 400_000.0
    @in init3_cost_savings::Float64 = 200_000.0

    # ── Initiative 4 ────────────────────────────────────────────────────
    @in init4_name::String = "Staffing Optimization"
    @in init4_year::Int = 1
    @in init4_revenue_impact::Float64 = 0.0
    @in init4_cost_savings::Float64 = 788_000.0

    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out year_labels::Vector{String} = ["Year 0", "Year 1", "Year 2", "Year 3", "Year 4", "Year 5"]
    @out projected_revenue::Vector{Float64} = [18.5, 20.3, 21.9, 22.7, 23.2, 23.6]
    @out projected_expenses::Vector{Float64} = [19.2, 18.8, 19.2, 19.9, 20.6, 21.3]
    @out projected_margin::Vector{Float64} = [-0.7, 1.5, 2.7, 2.8, 2.6, 2.3]
    @out cumulative_value::Float64 = 11_900_000.0
    @out breakeven_year::Int = 1
    @out year5_margin_pct::Float64 = 0.097

    # ── Chart Data ──────────────────────────────────────────────────────
    @out trajectory_data::Vector{PlotData} = [
        PlotData(
            x = ["Year 0", "Year 1", "Year 2", "Year 3", "Year 4", "Year 5"],
            y = [18.5, 20.3, 21.9, 22.7, 23.2, 23.6],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Revenue (\$M)", mode = "lines+markers"),
        PlotData(
            x = ["Year 0", "Year 1", "Year 2", "Year 3", "Year 4", "Year 5"],
            y = [19.2, 18.8, 19.2, 19.9, 20.6, 21.3],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Expenses (\$M)", mode = "lines+markers"),
        PlotData(
            x = ["Year 0", "Year 1", "Year 2", "Year 3", "Year 4", "Year 5"],
            y = [-0.7, 1.5, 2.7, 2.8, 2.6, 2.3],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Net Margin (\$M)"),
    ]
    @out trajectory_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "5-Year Strategic Financial Trajectory (\$M)"),
        xaxis = [PlotLayoutAxis(title = "Year")],
        yaxis = [PlotLayoutAxis(title = "\$ Millions")],
    )

    @out initiative_value_data::Vector{PlotData} = [
        PlotData(
            x = ["REH Conversion", "Outpatient Expansion", "Revenue Cycle", "Staffing Optimization"],
            y = [1200, 700, 600, 788],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Annual Value (\$K)",
            marker = Dict("color" => ["#2196F3", "#4CAF50", "#FF9800", "#9C27B0"]),
        )
    ]
    @out initiative_value_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Initiative Annual Value (\$K)"),
        xaxis = [PlotLayoutAxis(title = "Initiative")],
        yaxis = [PlotLayoutAxis(title = "\$K/Year")],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            # Build base financials for domain projection
            bf = (
                inpatient_revenue=base_revenue * 0.42,
                outpatient_revenue=base_revenue * 0.58,
                salary_expense=base_expenses * 0.55,
                supply_expense=base_expenses * 0.15,
                other_expense=base_expenses * 0.30,
                cash_reserves=5_000_000.0,
                depreciation=1_200_000.0,
                annual_debt_service=800_000.0,
                payer_mix_government=0.80,
            )

            # Build initiatives
            inits = [
                (init1_name, init1_year, init1_revenue_impact, init1_cost_savings),
                (init2_name, init2_year, init2_revenue_impact, init2_cost_savings),
                (init3_name, init3_year, init3_revenue_impact, init3_cost_savings),
                (init4_name, init4_year, init4_revenue_impact, init4_cost_savings),
            ]

            # Use domain engine for baseline projection
            params = DeterministicParams(; projection_years=5,
                volume_growth_rate=revenue_growth_rate,
                cost_inflation_rate=expense_growth_rate,
                salary_inflation_rate=expense_growth_rate + 0.005,
                supply_inflation_rate=expense_growth_rate + 0.01,
                reimbursement_adjustment=revenue_growth_rate, payer_mix_shift=0.005)
            baseline = project_financials(bf, params)

            # Layer strategic initiatives on top of domain projection
            rev = Float64[base_revenue]
            exp = Float64[base_expenses]
            for yr in 1:5
                r = yr <= length(baseline.projections) ? baseline.projections[yr].total_revenue : rev[end] * (1 + revenue_growth_rate)
                e = yr <= length(baseline.projections) ? baseline.projections[yr].total_expense : exp[end] * (1 + expense_growth_rate)
                for (_, iy, ri, cs) in inits
                    if yr >= iy
                        r += ri
                        e -= cs
                    end
                end
                push!(rev, r)
                push!(exp, e)
            end
            projected_revenue = round.(rev ./ 1e6, digits=1)
            projected_expenses = round.(exp ./ 1e6, digits=1)
            projected_margin = round.((rev .- exp) ./ 1e6, digits=1)
            cumulative_value = sum(rev[2:end] .- exp[2:end])
            breakeven_year = findfirst(m -> m > 0, rev[2:end] .- exp[2:end])
            breakeven_year = isnothing(breakeven_year) ? 6 : breakeven_year
            year5_margin_pct = (rev[6] - exp[6]) / max(rev[6], 1.0)

            trajectory_data = [
                PlotData(x=year_labels, y=projected_revenue, plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                    name="Revenue (\$M)", mode="lines+markers"),
                PlotData(x=year_labels, y=projected_expenses, plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                    name="Expenses (\$M)", mode="lines+markers"),
                PlotData(x=year_labels, y=projected_margin, plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                    name="Net Margin (\$M)"),
            ]

            init_names = [n for (n, _, _, _) in inits]
            init_values = round.([(ri + cs) for (_, _, ri, cs) in inits] ./ 1000, digits=0)
            initiative_value_data = [PlotData(x=init_names, y=init_values,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Annual Value (\$K)")]
            @info "Strategic plan (domain): cumulative 5yr value \$$(round(Int, cumulative_value/1e6))M"
        end
    end
end

const strategic_planner_model = @init
