"""
Stipple reactive model for Policy Impact Simulator.
Toggle federal/state policy scenarios and see stacked 5-year revenue impact.
References RuralHospitalSim constants for policy parameters.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer constants
using ...RuralHospitalSim: SEQUESTRATION_RATE, PolicyScenario


@app begin
    @in left_drawer_open::Bool = true
    # ── Policy Toggle Inputs ────────────────────────────────────────────
    @in sequestration::Bool = true
    @in bad_debt_reduction::Bool = false
    @in ptc_expansion::Bool = false
    @in medicaid_expansion::Bool = false
    @in ma_growth::Bool = true
    @in rural_health_redesign::Bool = false
    @in base_revenue::Float64 = 18_500_000.0
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out total_revenue_impact_yr1::Float64 = -185_000.0
    @out total_margin_change::Float64 = -0.010
    @out net_5yr_impact::Float64 = -925_000.0

    @out policy_impacts::Vector{Dict{String,Any}} = [
        Dict("policy"=>"Medicare Sequestration (2%)", "annual_impact"=>-370_000,
             "direction"=>"negative", "active"=>true),
        Dict("policy"=>"Bad Debt Reduction Program", "annual_impact"=>220_000,
             "direction"=>"positive", "active"=>false),
        Dict("policy"=>"PTC/DSH Expansion", "annual_impact"=>185_000,
             "direction"=>"positive", "active"=>false),
        Dict("policy"=>"Medicaid Expansion", "annual_impact"=>480_000,
             "direction"=>"positive", "active"=>false),
        Dict("policy"=>"Medicare Advantage Growth", "annual_impact"=>-185_000,
             "direction"=>"negative", "active"=>true),
        Dict("policy"=>"Rural Health Redesign", "annual_impact"=>350_000,
             "direction"=>"positive", "active"=>false),
    ]

    # ── Chart Data ──────────────────────────────────────────────────────
    @out stacked_5yr_data::Vector{PlotData} = [
        PlotData(
            x = ["Year 1", "Year 2", "Year 3", "Year 4", "Year 5"],
            y = [-370, -370, -370, -370, -370],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Sequestration"),
        PlotData(
            x = ["Year 1", "Year 2", "Year 3", "Year 4", "Year 5"],
            y = [-185, -195, -205, -215, -225],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "MA Growth"),
    ]
    @out stacked_5yr_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "5-Year Cumulative Policy Impact (\$K)"),
        barmode = "relative",
        xaxis = [PlotLayoutAxis(title = "Year")],
        yaxis = [PlotLayoutAxis(title = "\$K Impact")],
    )

    @out impact_summary_data::Vector{PlotData} = [
        PlotData(
            x = ["Sequestration", "Bad Debt", "PTC/DSH", "Medicaid Exp", "MA Growth", "Rural Redesign"],
            y = [-370, 0, 0, 0, -185, 0],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Annual Impact (\$K)",
            marker = Dict("color" => ["#F44336","#E0E0E0","#E0E0E0","#E0E0E0","#F44336","#E0E0E0"]),
        )
    ]
    @out impact_summary_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Policy Impact by Category (\$K/Year)"),
        xaxis = [PlotLayoutAxis(title = "Policy")],
        yaxis = [PlotLayoutAxis(title = "\$K")],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            impacts = Dict{String,Float64}()
            impacts["Sequestration"] = sequestration ? -base_revenue * 0.02 : 0.0
            impacts["Bad Debt"] = bad_debt_reduction ? base_revenue * 0.012 : 0.0
            impacts["PTC/DSH"] = ptc_expansion ? base_revenue * 0.01 : 0.0
            impacts["Medicaid Exp"] = medicaid_expansion ? base_revenue * 0.026 : 0.0
            impacts["MA Growth"] = ma_growth ? -base_revenue * 0.01 : 0.0
            impacts["Rural Redesign"] = rural_health_redesign ? base_revenue * 0.019 : 0.0

            total_revenue_impact_yr1 = sum(values(impacts))
            total_margin_change = total_revenue_impact_yr1 / max(base_revenue, 1.0)
            net_5yr_impact = total_revenue_impact_yr1 * 5

            policy_names = ["Sequestration", "Bad Debt", "PTC/DSH", "Medicaid Exp", "MA Growth", "Rural Redesign"]
            annual_vals = [impacts[n] for n in policy_names]
            colors = [v < 0 ? "#F44336" : v > 0 ? "#4CAF50" : "#E0E0E0" for v in annual_vals]

            impact_summary_data = [PlotData(
                x=policy_names, y=round.(annual_vals ./ 1000, digits=0),
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Annual Impact (\$K)",
                marker=Dict("color"=>colors))]

            # Build stacked 5yr for active policies
            traces = PlotData[]
            for (n, v) in zip(policy_names, annual_vals)
                if v != 0
                    yearly = round.([v * yr / 1000 for yr in 1:5], digits=0)
                    push!(traces, PlotData(
                        x=["Year 1","Year 2","Year 3","Year 4","Year 5"],
                        y=round.([v / 1000 for _ in 1:5], digits=0),
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name=n))
                end
            end
            stacked_5yr_data = isempty(traces) ? [PlotData(x=["Year 1"], y=[0],
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="No active policies")] : traces
            @info "Policy impact: \$$(round(Int, total_revenue_impact_yr1/1000))K/year"
        end
    end
end

const policy_impact_model = @init
