"""
Stipple reactive model for Pharmacokinetic ODE Simulation.
Two-compartment PK model with oral absorption and IV bolus support.
Delegates to RuralHospitalSim.simulate_pk() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: simulate_pk, PKParams, PKResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in dose::Float64 = 500.0
    @in bioavailability::Float64 = 0.85
    @in ka::Float64 = 1.5
    @in cl_central::Float64 = 10.0
    @in cl_peripheral::Float64 = 5.0
    @in v_central::Float64 = 20.0
    @in v_peripheral::Float64 = 40.0
    @in t_end::Float64 = 24.0
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out peak_concentration::Float64 = 0.0
    @out time_to_peak::Float64 = 0.0
    @out terminal_half_life::Float64 = 0.0
    @out auc::Float64 = 0.0

    @out pk_chart_data::Vector{PlotData} = PlotData[]
    @out pk_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Concentration-Time Curve"),
        xaxis=[PlotLayoutAxis(title="Time (hours)")],
        yaxis=[PlotLayoutAxis(title="Concentration (mg/L)")],
    )

    # ── Handler ─────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            params = PKParams(;
                dose=dose,
                bioavailability=bioavailability,
                ka=ka,
                cl_central=cl_central,
                cl_peripheral=cl_peripheral,
                v_central=v_central,
                v_peripheral=v_peripheral,
            )
            result = simulate_pk(params; t_end=t_end)

            peak_concentration = result.peak_concentration
            time_to_peak = result.time_to_peak
            terminal_half_life = result.terminal_half_life
            auc = result.auc

            # Downsample for plotting (every 5th point to keep chart responsive)
            step = max(1, length(result.times) ÷ 200)
            idx = 1:step:length(result.times)
            t_plot = result.times[idx]
            c1_plot = result.central_conc[idx]
            c2_plot = result.peripheral_conc[idx]

            pk_chart_data = [
                PlotData(x=t_plot, y=c1_plot,
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         mode="lines",
                         name="Central Compartment",
                         line=Dict("color" => "#2196F3", "width" => 2)),
                PlotData(x=t_plot, y=c2_plot,
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         mode="lines",
                         name="Peripheral Compartment",
                         line=Dict("color" => "#FF9800", "width" => 2, "dash" => "dash")),
            ]

            @info "PK Simulation: Cmax=$(round(peak_concentration, digits=2)) mg/L, Tmax=$(round(time_to_peak, digits=1)) hr, T½=$(round(terminal_half_life, digits=1)) hr, AUC=$(round(auc, digits=1))"
        end
    end
end

const pk_ode_model = @init
