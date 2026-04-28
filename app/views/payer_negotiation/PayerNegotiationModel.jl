"""
Stipple reactive model for Payer Negotiation Simulator.
Models rate changes across service categories and projects revenue impact.
Delegates to RuralHospitalSim.simulate_negotiation() for rate modeling.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: simulate_negotiation, optimal_rate_target,
    NegotiationCategory, NegotiationResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Category Inputs (5 categories x volume, charges, current rate, proposed rate) ──
    @in cat1_name::String = "Inpatient"
    @in cat1_volume::Int = 620
    @in cat1_charges::Float64 = 9_350.0
    @in cat1_current_rate::Float64 = 0.42
    @in cat1_proposed_rate::Float64 = 0.47

    @in cat2_name::String = "Outpatient Surgery"
    @in cat2_volume::Int = 1400
    @in cat2_charges::Float64 = 4_200.0
    @in cat2_current_rate::Float64 = 0.48
    @in cat2_proposed_rate::Float64 = 0.52

    @in cat3_name::String = "ED"
    @in cat3_volume::Int = 4200
    @in cat3_charges::Float64 = 1_850.0
    @in cat3_current_rate::Float64 = 0.38
    @in cat3_proposed_rate::Float64 = 0.43

    @in cat4_name::String = "Imaging"
    @in cat4_volume::Int = 6200
    @in cat4_charges::Float64 = 680.0
    @in cat4_current_rate::Float64 = 0.52
    @in cat4_proposed_rate::Float64 = 0.55

    @in cat5_name::String = "Lab"
    @in cat5_volume::Int = 18500
    @in cat5_charges::Float64 = 85.0
    @in cat5_current_rate::Float64 = 0.45
    @in cat5_proposed_rate::Float64 = 0.50

    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out total_current_revenue::Float64 = 8_420_000.0
    @out total_proposed_revenue::Float64 = 9_185_000.0
    @out total_revenue_increase::Float64 = 765_000.0
    @out overall_rate_improvement::Float64 = 0.043

    @out category_detail::Vector{Dict{String,Any}} = [
        Dict("name"=>"Inpatient", "current_rev"=>2_435_100, "proposed_rev"=>2_724_745, "increase"=>289_645),
        Dict("name"=>"Outpatient Surgery", "current_rev"=>2_822_400, "proposed_rev"=>3_057_600, "increase"=>235_200),
        Dict("name"=>"ED", "current_rev"=>2_952_600, "proposed_rev"=>3_340_350, "increase"=>387_750),
        Dict("name"=>"Imaging", "current_rev"=>2_191_520, "proposed_rev"=>2_318_600, "increase"=>127_080),
        Dict("name"=>"Lab", "current_rev"=>707_625, "proposed_rev"=>786_250, "increase"=>78_625),
    ]

    # ── Chart Data ──────────────────────────────────────────────────────
    @out revenue_comparison_data::Vector{PlotData} = [
        PlotData(
            x = ["Inpatient", "OP Surgery", "ED", "Imaging", "Lab"],
            y = [2435, 2822, 2953, 2192, 708],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Current Revenue (\$K)"),
        PlotData(
            x = ["Inpatient", "OP Surgery", "ED", "Imaging", "Lab"],
            y = [2725, 3058, 3340, 2319, 786],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Proposed Revenue (\$K)"),
    ]
    @out revenue_comparison_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Revenue by Category: Current vs Proposed (\$K)"),
        barmode = "group",
        xaxis = [PlotLayoutAxis(title = "Category")],
        yaxis = [PlotLayoutAxis(title = "\$K")],
    )

    @out increase_data::Vector{PlotData} = [
        PlotData(
            x = ["Inpatient", "OP Surgery", "ED", "Imaging", "Lab"],
            y = [290, 235, 388, 127, 79],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Revenue Increase (\$K)",
            marker = Dict("color" => "#4CAF50"),
        )
    ]
    @out increase_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Revenue Increase by Category (\$K)"),
        xaxis = [PlotLayoutAxis(title = "Category")],
        yaxis = [PlotLayoutAxis(title = "\$K Increase")],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            # Build negotiation categories for domain engine
            categories = [
                NegotiationCategory(cat1_name, cat1_volume, cat1_charges, cat1_current_rate, cat1_proposed_rate),
                NegotiationCategory(cat2_name, cat2_volume, cat2_charges, cat2_current_rate, cat2_proposed_rate),
                NegotiationCategory(cat3_name, cat3_volume, cat3_charges, cat3_current_rate, cat3_proposed_rate),
                NegotiationCategory(cat4_name, cat4_volume, cat4_charges, cat4_current_rate, cat4_proposed_rate),
                NegotiationCategory(cat5_name, cat5_volume, cat5_charges, cat5_current_rate, cat5_proposed_rate),
            ]

            # Call domain engine
            result = simulate_negotiation(categories)

            # Map domain results
            total_current_revenue = result.total_current_revenue
            total_proposed_revenue = result.total_proposed_revenue
            total_revenue_increase = result.total_revenue_increase
            overall_rate_improvement = result.overall_rate_improvement

            names = [cat1_name, cat2_name, cat3_name, cat4_name, cat5_name]
            cur_revs = [c.current_revenue for c in result.categories]
            prop_revs = [c.proposed_revenue for c in result.categories]
            increases = [c.revenue_increase for c in result.categories]

            category_detail = [Dict{String,Any}(
                "name"=>c.name, "current_rev"=>round(Int, c.current_revenue),
                "proposed_rev"=>round(Int, c.proposed_revenue), "increase"=>round(Int, c.revenue_increase))
                for c in result.categories]

            revenue_comparison_data = [
                PlotData(x=names, y=round.(cur_revs ./ 1000, digits=0),
                    plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Current Revenue (\$K)"),
                PlotData(x=names, y=round.(prop_revs ./ 1000, digits=0),
                    plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Proposed Revenue (\$K)"),
            ]
            increase_data = [PlotData(x=names, y=round.(increases ./ 1000, digits=0),
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Revenue Increase (\$K)",
                marker=Dict("color"=>"#4CAF50"))]
            @info "Payer negotiation (domain): +\$$(round(Int, total_revenue_increase/1000))K revenue"
        end
    end
end

const payer_negotiation_model = @init
