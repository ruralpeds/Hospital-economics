"""
Stipple reactive model for Value-at-Risk (VaR) and Conditional VaR (CVaR).
Historical simulation approach with configurable confidence and holding period.
Delegates to RuralHospitalSim.calculate_var_cvar() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: calculate_var_cvar, VaRInput, VaRResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in returns_input::String = "-0.02, 0.01, -0.03, 0.02, -0.01, 0.03, -0.04, 0.015, -0.005, 0.025, -0.015, 0.01, -0.035, 0.02, -0.01, 0.005, -0.02, 0.03, -0.025, 0.015"
    @in confidence::Float64 = 0.95
    @in holding_period::Int = 1
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out var_amount::Float64 = 0.0
    @out cvar_amount::Float64 = 0.0
    @out var_pct::Float64 = 0.0
    @out cvar_pct::Float64 = 0.0
    @out n_observations::Int = 0

    @out histogram_data::Vector{PlotData} = PlotData[]
    @out histogram_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Return Distribution with VaR/CVaR"),
        xaxis=[PlotLayoutAxis(title="Return")],
        yaxis=[PlotLayoutAxis(title="Frequency")],
        barmode="overlay",
    )

    # ── Handler ─────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            # Parse comma-separated returns
            parts = split(strip(returns_input), r"[,;\s]+")
            returns = Float64[]
            for p in parts
                s = strip(p)
                isempty(s) && continue
                push!(returns, parse(Float64, s))
            end

            if length(returns) < 2
                @warn "VaR/CVaR requires at least 2 observations"
                return
            end

            input = VaRInput(;
                returns=returns,
                confidence=confidence,
                holding_period=holding_period,
            )
            result = calculate_var_cvar(input)

            var_amount = result.var_amount
            cvar_amount = result.cvar_amount
            var_pct = result.var_pct
            cvar_pct = result.cvar_pct
            n_observations = result.n_observations

            # Histogram of returns with VaR/CVaR lines
            histogram_data = [
                PlotData(x=returns,
                         plot=StipplePlotly.Charts.PLOT_TYPE_HISTOGRAM,
                         name="Returns",
                         marker=Dict("color" => "rgba(33,150,243,0.6)"),
                         nbinsx=15),
                PlotData(x=[-var_pct, -var_pct],
                         y=[0, length(returns) / 3],
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         mode="lines",
                         name="VaR ($(round(confidence * 100, digits=0))%)",
                         line=Dict("color" => "#F44336", "width" => 3, "dash" => "dash")),
                PlotData(x=[-cvar_pct, -cvar_pct],
                         y=[0, length(returns) / 3],
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         mode="lines",
                         name="CVaR (ES)",
                         line=Dict("color" => "#FF9800", "width" => 3, "dash" => "dot")),
            ]

            @info "VaR/CVaR: VaR=$(round(var_pct * 100, digits=2))%, CVaR=$(round(cvar_pct * 100, digits=2))%, n=$(n_observations)"
        end
    end
end

const var_cvar_model = @init
