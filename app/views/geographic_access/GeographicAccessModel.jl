"""
Stipple reactive model for Geographic Access Modeling.
2SFCA catchment analysis and closure impact assessment for rural facilities.
Delegates to RuralHospitalSim.calculate_catchment() for 2SFCA computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: calculate_catchment, haversine_distance, estimate_drive_time,
    closure_access_impact, FacilityLocation, PopulationCenter, AccessResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Facility Inputs ─────────────────────────────────────────────────
    @in facility_name::String = "Prairie View Hospital"
    @in facility_lat::Float64 = 39.50
    @in facility_lon::Float64 = -99.30
    @in facility_capacity::Float64 = 1.0
    @in max_drive_minutes::Float64 = 30.0

    # ── Population Centers (simplified 3-center model) ──────────────────
    @in pop1_name::String = "Town A"
    @in pop1_lat::Float64 = 39.52
    @in pop1_lon::Float64 = -99.28
    @in pop1_population::Int = 3500
    @in pop1_pct_over_65::Float64 = 0.20

    @in pop2_name::String = "Town B"
    @in pop2_lat::Float64 = 39.45
    @in pop2_lon::Float64 = -99.45
    @in pop2_population::Int = 2200
    @in pop2_pct_over_65::Float64 = 0.18

    @in pop3_name::String = "Town C"
    @in pop3_lat::Float64 = 39.60
    @in pop3_lon::Float64 = -99.15
    @in pop3_population::Int = 1800
    @in pop3_pct_over_65::Float64 = 0.25

    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out catchment_population::Int = 7500
    @out avg_drive_time::Float64 = 12.5
    @out access_score::Float64 = 0.0012
    @out market_share::Float64 = 0.85
    @out volume_estimate::Float64 = 638.0

    @out access_chart_data::Vector{PlotData} = [
        PlotData(x=["Town A", "Town B", "Town C"],
                 y=[3500, 2200, 1800],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 name="Population", marker=Dict("color" => "#2196F3")),
    ]
    @out access_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Catchment Population by Center"),
        yaxis=[PlotLayoutAxis(title="Population")],
    )

    @out drive_time_data::Vector{PlotData} = [
        PlotData(x=["Town A", "Town B", "Town C"],
                 y=[5.0, 15.0, 12.0],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 name="Drive Time (min)", marker=Dict("color" => "#FF9800"))
    ]
    @out drive_time_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Drive Time to Facility"),
        yaxis=[PlotLayoutAxis(title="Minutes")],
    )

    @onchange recalculate begin
        if recalculate
            recalculate = false

            # Build domain types
            facility = FacilityLocation(facility_name, facility_lat, facility_lon, facility_capacity)
            pop_centers = [
                PopulationCenter(pop1_name, pop1_lat, pop1_lon, pop1_population, pop1_pct_over_65),
                PopulationCenter(pop2_name, pop2_lat, pop2_lon, pop2_population, pop2_pct_over_65),
                PopulationCenter(pop3_name, pop3_lat, pop3_lon, pop3_population, pop3_pct_over_65),
            ]

            # Call domain engine for 2SFCA catchment analysis
            result = calculate_catchment(facility, pop_centers; max_drive_minutes=max_drive_minutes)

            # Map domain results
            catchment_population = result.catchment_population
            avg_drive_time = result.avg_drive_time
            access_score = result.access_score
            market_share = result.market_share
            volume_estimate = result.volume_estimate

            names = [p.name for p in pop_centers]
            populations = [p.population for p in pop_centers]
            times = [round(estimate_drive_time(
                haversine_distance(facility_lat, facility_lon, p.latitude, p.longitude)), digits=1)
                for p in pop_centers]

            access_chart_data = [PlotData(x=names, y=populations,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Population",
                marker=Dict("color" => "#2196F3"))]
            drive_time_data = [PlotData(x=names, y=times,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Drive Time (min)",
                marker=Dict("color" => "#FF9800"))]
            @info "Geographic access (domain): catchment $(catchment_population), volume $(volume_estimate)"
        end
    end
end

const geographic_access_model = @init
