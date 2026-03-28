"""
Stipple reactive model for Community Economic Impact analysis.
Estimates total economic footprint and closure devastation metrics.
"""
using Stipple, StippleUI, StipplePlotly

@appname CommunityImpactApp

@app begin
    # ── Inputs ──────────────────────────────────────────────────────────
    @in annual_payroll::Float64 = 9_760_000.0
    @in employee_count::Int = 142
    @in local_purchasing::Float64 = 3_200_000.0
    @in economic_multiplier::Float64 = 1.6
    @in county_population::Int = 8500
    @in median_household_income::Float64 = 42_000.0
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out total_economic_impact::Float64 = 20_736_000.0
    @out direct_impact::Float64 = 12_960_000.0
    @out indirect_impact::Float64 = 7_776_000.0
    @out jobs_supported::Int = 213
    @out impact_per_capita::Float64 = 2_440.0
    @out pct_county_employment::Float64 = 0.068

    # ── Closure Devastation Metrics ─────────────────────────────────────
    @out closure_job_loss::Int = 213
    @out closure_income_loss::Float64 = 20_736_000.0
    @out closure_population_decline_pct::Float64 = 0.04
    @out closure_property_value_decline::Float64 = 0.06
    @out closure_nearest_er_miles::Float64 = 35.0
    @out closure_mortality_impact::String = "Estimated 6-8% increase in mortality for time-sensitive conditions"

    # ── Chart Data ──────────────────────────────────────────────────────
    @out impact_breakdown_data::Vector{PlotData} = [
        PlotData(
            values = [9760, 3200, 7776],
            labels = ["Payroll", "Local Purchasing", "Multiplier Effect"],
            plot = StipplePlotly.Charts.PLOT_TYPE_PIE,
            hole = 0.4,
            name = "Economic Impact",
        )
    ]
    @out impact_breakdown_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Economic Impact Breakdown (\$K)"),
    )

    @out closure_gauge_data::Vector{PlotData} = [
        PlotData(
            values = [72, 28],
            labels = ["Devastation Score", ""],
            plot = StipplePlotly.Charts.PLOT_TYPE_PIE,
            hole = 0.7,
            marker = Dict("colors" => ["#F44336", "#E0E0E0"]),
            name = "Closure Devastation",
            textinfo = "none",
            direction = "clockwise",
            rotation = 270,
        )
    ]
    @out closure_gauge_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Community Closure Devastation Index"),
        annotations = [Dict("text" => "72/100", "x" => 0.5, "y" => 0.5,
                            "font" => Dict("size" => 28), "showarrow" => false)],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            direct_impact = annual_payroll + local_purchasing
            indirect_impact = round(direct_impact * (economic_multiplier - 1.0), digits=0)
            total_economic_impact = direct_impact + indirect_impact
            jobs_supported = round(Int, employee_count * economic_multiplier)
            impact_per_capita = round(total_economic_impact / max(county_population, 1), digits=0)
            pct_county_employment = round(employee_count / (county_population * 0.45), digits=3)

            closure_job_loss = jobs_supported
            closure_income_loss = total_economic_impact
            closure_population_decline_pct = round(employee_count / max(county_population, 1) * 0.8, digits=3)

            impact_breakdown_data = [PlotData(
                values = round.([annual_payroll, local_purchasing, indirect_impact] ./ 1000, digits=0),
                labels = ["Payroll", "Local Purchasing", "Multiplier Effect"],
                plot = StipplePlotly.Charts.PLOT_TYPE_PIE,
                hole = 0.4,
                name = "Economic Impact (\$K)",
            )]
            @info "Community impact: \$$(round(Int, total_economic_impact/1e6))M total, $(jobs_supported) jobs"
        end
    end
end

const community_impact_model = @init
