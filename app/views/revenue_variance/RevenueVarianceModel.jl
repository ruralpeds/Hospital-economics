"""
Stipple reactive model for Revenue Variance Bridge Analysis.
Decomposes revenue variance into price, volume, and mix components by service line.
Delegates to RuralHospitalSim.calculate_revenue_variance() for computation.
"""
using Stipple, StippleUI, StipplePlotly

using ...RuralHospitalSim: calculate_revenue_variance, ServiceLineRevenue, RevenueVarianceResult


@app begin
    @in left_drawer_open::Bool = true

    # ── Service line inputs (up to 6 rows) ─────────────────────────
    @in svc1_name::String = "Cardiology"
    @in svc1_prior_vol::Float64 = 1200.0
    @in svc1_current_vol::Float64 = 1300.0
    @in svc1_prior_price::Float64 = 5000.0
    @in svc1_current_price::Float64 = 5200.0

    @in svc2_name::String = "Orthopedics"
    @in svc2_prior_vol::Float64 = 800.0
    @in svc2_current_vol::Float64 = 750.0
    @in svc2_prior_price::Float64 = 8000.0
    @in svc2_current_price::Float64 = 8500.0

    @in svc3_name::String = "Emergency"
    @in svc3_prior_vol::Float64 = 5000.0
    @in svc3_current_vol::Float64 = 5200.0
    @in svc3_prior_price::Float64 = 1500.0
    @in svc3_current_price::Float64 = 1450.0

    @in svc4_name::String = "Primary Care"
    @in svc4_prior_vol::Float64 = 10000.0
    @in svc4_current_vol::Float64 = 10500.0
    @in svc4_prior_price::Float64 = 200.0
    @in svc4_current_price::Float64 = 210.0

    @in svc5_name::String = ""
    @in svc5_prior_vol::Float64 = 0.0
    @in svc5_current_vol::Float64 = 0.0
    @in svc5_prior_price::Float64 = 0.0
    @in svc5_current_price::Float64 = 0.0

    @in svc6_name::String = ""
    @in svc6_prior_vol::Float64 = 0.0
    @in svc6_current_vol::Float64 = 0.0
    @in svc6_prior_price::Float64 = 0.0
    @in svc6_current_price::Float64 = 0.0

    @in recalculate::Bool = false

    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    # ── Outputs ────────────────────────────────────────────────────
    @out total_variance_str::String = "\$0"
    @out price_variance_str::String = "\$0"
    @out volume_variance_str::String = "\$0"
    @out mix_variance_str::String = "\$0"
    @out price_pct_str::String = "0.0%"
    @out volume_pct_str::String = "0.0%"
    @out mix_pct_str::String = "0.0%"
    @out service_details::Vector{Dict{String,Any}} = Dict{String,Any}[]

    @out waterfall_chart_data::Vector{PlotData} = PlotData[]
    @out waterfall_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Revenue Variance Bridge"),
        yaxis=[PlotLayoutAxis(title="Variance (\$)")],
    )

    @out detail_chart_data::Vector{PlotData} = PlotData[]
    @out detail_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Variance by Service Line"),
        yaxis=[PlotLayoutAxis(title="Variance (\$)")],
        barmode="group",
    )

    # ── Handler ────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            try
                # Build service lines from non-empty rows
                services = ServiceLineRevenue[]
                for (name, pv, cv, pp, cp) in [
                    (svc1_name, svc1_prior_vol, svc1_current_vol, svc1_prior_price, svc1_current_price),
                    (svc2_name, svc2_prior_vol, svc2_current_vol, svc2_prior_price, svc2_current_price),
                    (svc3_name, svc3_prior_vol, svc3_current_vol, svc3_prior_price, svc3_current_price),
                    (svc4_name, svc4_prior_vol, svc4_current_vol, svc4_prior_price, svc4_current_price),
                    (svc5_name, svc5_prior_vol, svc5_current_vol, svc5_prior_price, svc5_current_price),
                    (svc6_name, svc6_prior_vol, svc6_current_vol, svc6_prior_price, svc6_current_price),
                ]
                    if !isempty(strip(name)) && (pv > 0.0 || cv > 0.0)
                        push!(services, ServiceLineRevenue(
                            name=name, prior_volume=pv, current_volume=cv,
                            prior_price=pp, current_price=cp))
                    end
                end

                if isempty(services)
                    total_variance_str = "N/A"
                    price_variance_str = "N/A"
                    volume_variance_str = "N/A"
                    mix_variance_str = "N/A"
                    service_details = Dict{String,Any}[]
                    return
                end

                result = calculate_revenue_variance(services)

                total_variance_str = "\$$(round(Int, result.total_variance) |> x -> string(x))"
                price_variance_str = "\$$(round(Int, result.price_variance) |> x -> string(x))"
                volume_variance_str = "\$$(round(Int, result.volume_variance) |> x -> string(x))"
                mix_variance_str = "\$$(round(Int, result.mix_variance) |> x -> string(x))"
                price_pct_str = "$(round(result.price_pct, digits=1))%"
                volume_pct_str = "$(round(result.volume_pct, digits=1))%"
                mix_pct_str = "$(round(result.mix_pct, digits=1))%"

                # Build service details
                service_details = [Dict{String,Any}(
                    "name" => d.name,
                    "price_var" => round(Int, d.price_var),
                    "volume_var" => round(Int, d.volume_var),
                    "mix_var" => round(Int, d.mix_var),
                    "total_var" => round(Int, d.price_var + d.volume_var + d.mix_var),
                ) for d in result.service_details]

                # Waterfall chart: Price -> Volume -> Mix -> Total
                waterfall_vals = [result.price_variance, result.volume_variance,
                                  result.mix_variance, result.total_variance]
                waterfall_colors = [v >= 0 ? "#4CAF50" : "#F44336" for v in waterfall_vals]
                waterfall_chart_data = [PlotData(
                    x=["Price Variance", "Volume Variance", "Mix Variance", "Total Variance"],
                    y=waterfall_vals,
                    plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                    marker=Dict("color" => waterfall_colors))]
                waterfall_chart_layout = PlotLayout(
                    title=PlotLayoutTitle(text="Revenue Variance Waterfall"),
                    yaxis=[PlotLayoutAxis(title="Variance (\$)")],
                )

                # Detail chart by service line
                svc_names = [d.name for d in result.service_details]
                price_vars = [d.price_var for d in result.service_details]
                vol_vars = [d.volume_var for d in result.service_details]
                mix_vars = [d.mix_var for d in result.service_details]

                detail_chart_data = [
                    PlotData(x=svc_names, y=price_vars, name="Price",
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=Dict("color" => "#2196F3")),
                    PlotData(x=svc_names, y=vol_vars, name="Volume",
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=Dict("color" => "#FF9800")),
                    PlotData(x=svc_names, y=mix_vars, name="Mix",
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=Dict("color" => "#9C27B0")),
                ]
                detail_chart_layout = PlotLayout(
                    title=PlotLayoutTitle(text="Variance by Service Line"),
                    xaxis=[PlotLayoutAxis(title="Service Line")],
                    yaxis=[PlotLayoutAxis(title="Variance (\$)")],
                    barmode="group",
                )

                @info "Revenue variance: total=\$$(round(Int, result.total_variance))"
            catch err
                total_variance_str = "Error"
                price_variance_str = sprint(showerror, err)
                volume_variance_str = ""
                mix_variance_str = ""
                @error "Revenue variance error" exception=(err, catch_backtrace())
            end
        end
    end
end

const revenue_variance_model = @init
