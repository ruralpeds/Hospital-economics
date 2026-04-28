"""
Stipple reactive model for Community Economic Impact analysis.
Estimates total economic footprint and closure devastation metrics.
Delegates to RuralHospitalSim.calculate_community_impact() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: calculate_community_impact, closure_impact_projection,
    CommunityImpactParams, CommunityImpactResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in annual_payroll::Float64 = 9_760_000.0
    @in employee_count::Int = 142
    @in local_purchasing::Float64 = 3_200_000.0
    @in economic_multiplier::Float64 = 1.6
    @in county_population::Int = 8500
    @in median_household_income::Float64 = 42_000.0
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

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

            # Call domain engine
            params = CommunityImpactParams(;
                annual_payroll=annual_payroll,
                employee_count=employee_count,
                local_purchasing=local_purchasing,
                economic_multiplier=economic_multiplier,
                county_population=county_population,
                median_household_income=median_household_income,
            )
            result = calculate_community_impact(params)

            # Map domain results
            direct_impact = result.direct_impact
            indirect_impact = result.indirect_impact
            total_economic_impact = result.total_economic_impact
            jobs_supported = result.jobs_supported
            impact_per_capita = result.impact_per_capita
            pct_county_employment = result.pct_county_employment

            # Closure impact from domain
            closure_proj = closure_impact_projection(params)
            closure_job_loss = closure_proj.job_loss
            closure_income_loss = closure_proj.income_loss
            closure_population_decline_pct = closure_proj.population_decline_pct
            closure_property_value_decline = closure_proj.property_value_decline

            # Devastation index
            dev_score = round(Int, clamp(
                40 * pct_county_employment / 0.10 +
                30 * min(1.0, total_economic_impact / (county_population * median_household_income * 0.5)) +
                30 * min(1.0, closure_nearest_er_miles / 45.0),
                0, 100))

            impact_breakdown_data = [PlotData(
                values = round.([annual_payroll, local_purchasing, indirect_impact] ./ 1000, digits=0),
                labels = ["Payroll", "Local Purchasing", "Multiplier Effect"],
                plot = StipplePlotly.Charts.PLOT_TYPE_PIE,
                hole = 0.4,
                name = "Economic Impact (\$K)",
            )]
            closure_gauge_data = [PlotData(
                values=[dev_score, 100-dev_score], labels=["Devastation Score", ""],
                plot=StipplePlotly.Charts.PLOT_TYPE_PIE, hole=0.7,
                marker=Dict("colors" => ["#F44336", "#E0E0E0"]),
                name="Closure Devastation", textinfo="none", direction="clockwise", rotation=270)]
            closure_gauge_layout = PlotLayout(
                title=PlotLayoutTitle(text="Community Closure Devastation Index"),
                annotations=[Dict("text" => "$(dev_score)/100", "x" => 0.5, "y" => 0.5,
                    "font" => Dict("size" => 28), "showarrow" => false)])
            @info "Community impact (domain): \$$(round(Int, total_economic_impact/1e6))M total, $(jobs_supported) jobs"
        end
    end
end

const community_impact_model = @init
