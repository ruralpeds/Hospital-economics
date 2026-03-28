"""
Stipple reactive model for Cost Structure Model.
Analyzes fixed vs variable cost breakdown and operating leverage.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in beds::Int = 25
    @in avg_daily_census::Float64 = 8.3
    @in ed_visits::Int = 4200
    @in op_visits::Int = 12800
    @in fte_count::Float64 = 142.0
    @in avg_salary::Float64 = 68_500.0
    @in travel_pct::Float64 = 0.08
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out total_cost::Float64 = 19_200_000.0
    @out fixed_costs::Float64 = 12_480_000.0
    @out variable_costs::Float64 = 6_720_000.0
    @out fixed_pct::Float64 = 0.65
    @out variable_pct::Float64 = 0.35
    @out cost_per_adjusted_discharge::Float64 = 12_450.0
    @out cost_per_ed_visit::Float64 = 1_120.0
    @out cost_per_op_visit::Float64 = 385.0
    @out operating_leverage::Float64 = 1.86
    @out labor_cost_total::Float64 = 10_118_000.0
    @out non_labor_cost::Float64 = 9_082_000.0

    @out cost_categories::Vector{Dict{String,Any}} = [
        Dict("category"=>"Salaries & Wages", "amount"=>9_727_000, "pct"=>50.7, "type"=>"fixed"),
        Dict("category"=>"Benefits", "amount"=>2_432_000, "pct"=>12.7, "type"=>"fixed"),
        Dict("category"=>"Contract Labor", "amount"=>778_000, "pct"=>4.1, "type"=>"variable"),
        Dict("category"=>"Supplies", "amount"=>2_880_000, "pct"=>15.0, "type"=>"variable"),
        Dict("category"=>"Purchased Services", "amount"=>1_152_000, "pct"=>6.0, "type"=>"variable"),
        Dict("category"=>"Depreciation", "amount"=>960_000, "pct"=>5.0, "type"=>"fixed"),
        Dict("category"=>"Utilities & Insurance", "amount"=>576_000, "pct"=>3.0, "type"=>"fixed"),
        Dict("category"=>"Other", "amount"=>695_000, "pct"=>3.5, "type"=>"mixed"),
    ]

    # ── Chart Data ──────────────────────────────────────────────────────
    @out cost_breakdown_data::Vector{PlotData} = [
        PlotData(
            x = ["Total Costs"],
            y = [12_480],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Fixed (\$K)",
            marker = Dict("color" => "#2196F3"),
        ),
        PlotData(
            x = ["Total Costs"],
            y = [6_720],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Variable (\$K)",
            marker = Dict("color" => "#FF9800"),
        ),
    ]
    @out cost_breakdown_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Fixed vs Variable Cost Structure (\$K)"),
        barmode = "stack",
        xaxis = [PlotLayoutAxis(title = "")],
        yaxis = [PlotLayoutAxis(title = "\$K")],
    )

    @out category_chart_data::Vector{PlotData} = [
        PlotData(
            values = [9727, 2432, 778, 2880, 1152, 960, 576, 695],
            labels = ["Salaries", "Benefits", "Contract Labor", "Supplies",
                      "Purchased Svcs", "Depreciation", "Utilities", "Other"],
            plot = StipplePlotly.Charts.PLOT_TYPE_PIE,
            hole = 0.4,
            name = "Cost Categories",
        )
    ]
    @out category_chart_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Cost Distribution by Category"),
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            labor_base = fte_count * avg_salary
            travel_premium = labor_base * travel_pct * 1.5  # travel nurses cost 150% more
            labor_cost_total = round(labor_base + travel_premium, digits=0)
            supply_cost = (ed_visits * 120 + op_visits * 85 + avg_daily_census * 365 * 180)
            non_labor_cost = round(supply_cost + 960_000 + 576_000 + 695_000, digits=0)
            total_cost = labor_cost_total + non_labor_cost

            fixed_costs = round(labor_base * 0.85 + 960_000 + 576_000 + 400_000, digits=0)
            variable_costs = total_cost - fixed_costs
            fixed_pct = round(fixed_costs / max(total_cost, 1), digits=2)
            variable_pct = 1.0 - fixed_pct

            total_encounters = ed_visits + op_visits + round(Int, avg_daily_census * 365 / 3.8)
            cost_per_adjusted_discharge = round(total_cost / max(round(Int, avg_daily_census * 365 / 3.8), 1), digits=0)
            cost_per_ed_visit = round(total_cost * 0.22 / max(ed_visits, 1), digits=0)
            cost_per_op_visit = round(total_cost * 0.16 / max(op_visits, 1), digits=0)

            # Operating leverage = % change in operating income / % change in revenue
            operating_leverage = round(fixed_costs / max(variable_costs, 1), digits=2)

            cost_breakdown_data = [
                PlotData(x=["Total Costs"], y=[round(fixed_costs/1000)],
                    plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Fixed (\$K)",
                    marker=Dict("color"=>"#2196F3")),
                PlotData(x=["Total Costs"], y=[round(variable_costs/1000)],
                    plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Variable (\$K)",
                    marker=Dict("color"=>"#FF9800")),
            ]
            @info "Cost structure: $(round(fixed_pct*100))% fixed, leverage $(operating_leverage)x"
        end
    end
end

const cost_structure_model = @init
