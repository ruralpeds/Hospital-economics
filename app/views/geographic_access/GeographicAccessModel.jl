"""
Stipple reactive model for Geographic Access Modeling.
2SFCA catchment analysis and closure impact assessment for rural facilities.
"""
using Stipple, StippleUI, StipplePlotly


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
            R = 6371.0
            pops = [(pop1_name, pop1_lat, pop1_lon, pop1_population, pop1_pct_over_65),
                    (pop2_name, pop2_lat, pop2_lon, pop2_population, pop2_pct_over_65),
                    (pop3_name, pop3_lat, pop3_lon, pop3_population, pop3_pct_over_65)]

            names = String[]
            populations = Int[]
            times = Float64[]
            total_pop = 0
            weighted_demand = 0.0
            wt_sum = 0.0

            for (nm, lat, lon, pop, o65) in pops
                dlat = deg2rad(lat - facility_lat)
                dlon = deg2rad(lon - facility_lon)
                a = sin(dlat/2)^2 + cos(deg2rad(facility_lat))*cos(deg2rad(lat))*sin(dlon/2)^2
                dist = 2R * asin(sqrt(clamp(a, 0.0, 1.0)))
                mins = (dist * 1.3 / 80.0) * 60.0

                if mins <= max_drive_minutes
                    decay = exp(-0.05 * mins)
                    demand = pop * decay * (1.0 + o65)
                    total_pop += pop
                    weighted_demand += demand
                    wt_sum += mins * pop
                end
                push!(names, nm)
                push!(populations, pop)
                push!(times, round(mins, digits=1))
            end

            catchment_population = total_pop
            avg_drive_time = total_pop > 0 ? round(wt_sum / total_pop, digits=1) : 0.0
            access_score = weighted_demand > 0 ? round(facility_capacity / weighted_demand, digits=6) : 0.0
            market_share = clamp(round(access_score * 1000.0, digits=4), 0.0, 1.0)
            volume_estimate = round(total_pop * 0.10 * market_share, digits=0)

            access_chart_data = [PlotData(x=names, y=populations,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Population",
                marker=Dict("color" => "#2196F3"))]
            drive_time_data = [PlotData(x=names, y=times,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Drive Time (min)",
                marker=Dict("color" => "#FF9800"))]
            @info "Geographic access: catchment $(catchment_population), volume $(volume_estimate)"
        end
    end
end

const geographic_access_model = @init
