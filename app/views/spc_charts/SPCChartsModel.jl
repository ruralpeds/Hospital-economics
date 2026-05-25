"""
Stipple reactive model for Statistical Process Control (SPC) Charts.
Supports 11 chart types: I-MR, p, u, c, np, Laney p', Laney u', g, t, CUSUM, EWMA.
Delegates to RuralHospitalSim SPC functions for computation.
"""
using Stipple, StippleUI, StipplePlotly

using ...RuralHospitalSim: calculate_imr, calculate_p_chart, calculate_u_chart,
    calculate_c_chart, calculate_np_chart, calculate_laney_p_prime,
    calculate_laney_u_prime, calculate_g_chart, calculate_t_chart,
    calculate_cusum, calculate_ewma,
    IMRResult, PChartResult, UChartResult, CChartResult, NPChartResult,
    LaneyResult, GChartResult, TChartResult, CUSUMResult, EWMAResult


@app begin
    @in left_drawer_open::Bool = true

    # ── Inputs ─────────────────────────────────────────────────────
    @in chart_type::String = "IMR"
    @out chart_type_options::Vector{Dict{String,Any}} = [
        Dict("label" => "I-MR (Individual & Moving Range)", "value" => "IMR"),
        Dict("label" => "p-Chart (Proportion Defective)", "value" => "p"),
        Dict("label" => "u-Chart (Defects per Unit)", "value" => "u"),
        Dict("label" => "c-Chart (Defect Count)", "value" => "c"),
        Dict("label" => "np-Chart (Count Defective)", "value" => "np"),
        Dict("label" => "Laney p' (Overdispersion-Adjusted)", "value" => "laney_p"),
        Dict("label" => "Laney u' (Overdispersion-Adjusted)", "value" => "laney_u"),
        Dict("label" => "g-Chart (Counts Between Events)", "value" => "g"),
        Dict("label" => "t-Chart (Time Between Events)", "value" => "t"),
        Dict("label" => "CUSUM (Cumulative Sum)", "value" => "CUSUM"),
        Dict("label" => "EWMA (Exponentially Weighted MA)", "value" => "EWMA"),
    ]

    @in data_input::String = "25.1, 24.8, 25.3, 24.9, 25.5, 24.7, 25.0, 25.2, 24.6, 25.8, 25.1, 24.5, 25.4, 25.0, 24.3, 25.7, 24.9, 25.6, 25.2, 24.8"
    @in sample_sizes_input::String = "100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100"
    @in np_sample_size::Int = 100
    @in cusum_target::Float64 = 25.0
    @in cusum_k::Float64 = 0.5
    @in cusum_h::Float64 = 5.0
    @in ewma_lambda::Float64 = 0.2
    @in ewma_L::Float64 = 3.0

    @in recalculate::Bool = false

    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    # ── Outputs ────────────────────────────────────────────────────
    @out center_line_val::String = ""
    @out ucl_val::String = ""
    @out lcl_val::String = ""
    @out signals_count::Int = 0
    @out signals_text::String = "No signals detected"
    @out chart_description::String = "Individual & Moving Range chart for continuous data"

    @out spc_chart_data::Vector{PlotData} = PlotData[]
    @out spc_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="SPC Control Chart"),
        xaxis=[PlotLayoutAxis(title="Observation")],
        yaxis=[PlotLayoutAxis(title="Value")],
    )

    # ── Handler ────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            try
                # Parse data input
                raw_vals = tryparse.(Float64, strip.(split(data_input, ",")))
                valid_vals = Float64[v for v in raw_vals if v !== nothing]

                if isempty(valid_vals)
                    center_line_val = "Error"
                    ucl_val = "No valid data"
                    lcl_val = ""
                    signals_count = 0
                    signals_text = "Enter comma-separated numeric values"
                    return
                end

                # Parse sample sizes for attribute charts
                raw_ss = tryparse.(Int, strip.(split(sample_sizes_input, ",")))
                valid_ss = Int[v for v in raw_ss if v !== nothing]

                int_vals = Int.(round.(valid_vals))

                traces = PlotData[]
                x_indices = collect(1:length(valid_vals))

                if chart_type == "IMR"
                    res = calculate_imr(valid_vals)
                    res === nothing && error("Need at least 2 observations for I-MR chart")
                    center_line_val = string(round(res.center_line, digits=3))
                    ucl_val = string(round(res.ucl, digits=3))
                    lcl_val = string(round(res.lcl, digits=3))
                    signals_count = length(res.signals)
                    chart_description = "I-MR: Individuals chart with 3-sigma limits"

                    # Data points
                    push!(traces, PlotData(x=x_indices, y=res.values, name="Individuals",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#2196F3", "size" => 6)))
                    # Center line
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.center_line, res.center_line],
                        name="CL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#4CAF50"), mode="lines"))
                    # UCL
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.ucl, res.ucl],
                        name="UCL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                    # LCL
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.lcl, res.lcl],
                        name="LCL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                    # Signal points
                    if !isempty(res.signals)
                        push!(traces, PlotData(x=res.signals, y=[res.values[i] for i in res.signals],
                            name="Signals", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                            mode="markers", marker=Dict("color" => "#F44336", "size" => 10, "symbol" => "diamond")))
                    end

                elseif chart_type == "p"
                    length(valid_ss) == length(int_vals) || error("Sample sizes must match data length for p-chart")
                    res = calculate_p_chart(int_vals, valid_ss)
                    res === nothing && error("Invalid input for p-chart")
                    center_line_val = string(round(res.center_line, digits=4))
                    ucl_val = "Variable (per subgroup)"
                    lcl_val = "Variable (per subgroup)"
                    signals_count = length(res.signals)
                    chart_description = "p-Chart: Proportion defective with variable subgroup sizes"

                    push!(traces, PlotData(x=x_indices, y=res.values, name="Proportion",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#2196F3", "size" => 6)))
                    push!(traces, PlotData(x=x_indices, y=fill(res.center_line, length(valid_vals)),
                        name="CL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#4CAF50"), mode="lines"))
                    push!(traces, PlotData(x=x_indices, y=res.ucl, name="UCL",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                    push!(traces, PlotData(x=x_indices, y=res.lcl, name="LCL",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))

                elseif chart_type == "u"
                    length(valid_ss) == length(int_vals) || error("Units must match data length for u-chart")
                    res = calculate_u_chart(int_vals, valid_ss)
                    res === nothing && error("Invalid input for u-chart")
                    center_line_val = string(round(res.center_line, digits=4))
                    ucl_val = "Variable (per subgroup)"
                    lcl_val = "Variable (per subgroup)"
                    signals_count = length(res.signals)
                    chart_description = "u-Chart: Defects per unit with variable sizes"

                    push!(traces, PlotData(x=x_indices, y=res.values, name="Defects/Unit",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#2196F3", "size" => 6)))
                    push!(traces, PlotData(x=x_indices, y=fill(res.center_line, length(valid_vals)),
                        name="CL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#4CAF50"), mode="lines"))
                    push!(traces, PlotData(x=x_indices, y=res.ucl, name="UCL",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                    push!(traces, PlotData(x=x_indices, y=res.lcl, name="LCL",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))

                elseif chart_type == "c"
                    res = calculate_c_chart(int_vals)
                    res === nothing && error("Invalid input for c-chart")
                    center_line_val = string(round(res.center_line, digits=3))
                    ucl_val = string(round(res.ucl, digits=3))
                    lcl_val = string(round(res.lcl, digits=3))
                    signals_count = length(res.signals)
                    chart_description = "c-Chart: Defect counts with fixed opportunity"

                    push!(traces, PlotData(x=x_indices, y=res.values, name="Count",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#2196F3", "size" => 6)))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.center_line, res.center_line],
                        name="CL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#4CAF50"), mode="lines"))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.ucl, res.ucl],
                        name="UCL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.lcl, res.lcl],
                        name="LCL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))

                elseif chart_type == "np"
                    res = calculate_np_chart(int_vals, np_sample_size)
                    res === nothing && error("Invalid input for np-chart")
                    center_line_val = string(round(res.center_line, digits=3))
                    ucl_val = string(round(res.ucl, digits=3))
                    lcl_val = string(round(res.lcl, digits=3))
                    signals_count = length(res.signals)
                    chart_description = "np-Chart: Count defective with fixed sample size"

                    push!(traces, PlotData(x=x_indices, y=res.values, name="Count Defective",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#2196F3", "size" => 6)))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.center_line, res.center_line],
                        name="CL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#4CAF50"), mode="lines"))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.ucl, res.ucl],
                        name="UCL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.lcl, res.lcl],
                        name="LCL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))

                elseif chart_type == "laney_p"
                    length(valid_ss) == length(int_vals) || error("Sample sizes must match data for Laney p'")
                    res = calculate_laney_p_prime(int_vals, valid_ss)
                    res === nothing && error("Need >= 2 points for Laney p' chart")
                    center_line_val = string(round(res.center_line, digits=4))
                    ucl_val = "Variable (sigma_Z=$(round(res.sigma_z, digits=3)))"
                    lcl_val = "Variable (adjusted)"
                    signals_count = length(res.signals)
                    chart_description = "Laney p': Overdispersion-adjusted proportion chart"

                    push!(traces, PlotData(x=x_indices, y=res.values, name="Proportion",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#2196F3", "size" => 6)))
                    push!(traces, PlotData(x=x_indices, y=fill(res.center_line, length(valid_vals)),
                        name="CL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#4CAF50"), mode="lines"))
                    push!(traces, PlotData(x=x_indices, y=res.ucl, name="UCL",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                    push!(traces, PlotData(x=x_indices, y=res.lcl, name="LCL",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))

                elseif chart_type == "laney_u"
                    length(valid_ss) == length(int_vals) || error("Units must match data for Laney u'")
                    res = calculate_laney_u_prime(int_vals, valid_ss)
                    res === nothing && error("Need >= 2 points for Laney u' chart")
                    center_line_val = string(round(res.center_line, digits=4))
                    ucl_val = "Variable (sigma_Z=$(round(res.sigma_z, digits=3)))"
                    lcl_val = "Variable (adjusted)"
                    signals_count = length(res.signals)
                    chart_description = "Laney u': Overdispersion-adjusted rate chart"

                    push!(traces, PlotData(x=x_indices, y=res.values, name="Rate",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#2196F3", "size" => 6)))
                    push!(traces, PlotData(x=x_indices, y=fill(res.center_line, length(valid_vals)),
                        name="CL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#4CAF50"), mode="lines"))
                    push!(traces, PlotData(x=x_indices, y=res.ucl, name="UCL",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                    push!(traces, PlotData(x=x_indices, y=res.lcl, name="LCL",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))

                elseif chart_type == "g"
                    res = calculate_g_chart(int_vals)
                    res === nothing && error("Invalid input for g-chart")
                    center_line_val = string(round(res.center_line, digits=3))
                    ucl_val = string(round(res.ucl, digits=3))
                    lcl_val = string(round(res.lcl, digits=3))
                    signals_count = length(res.signals)
                    chart_description = "g-Chart: Counts between rare events (geometric)"

                    push!(traces, PlotData(x=x_indices, y=res.values, name="Count Between",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#2196F3", "size" => 6)))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.center_line, res.center_line],
                        name="CL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#4CAF50"), mode="lines"))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.ucl, res.ucl],
                        name="UCL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.lcl, res.lcl],
                        name="LCL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))

                elseif chart_type == "t"
                    res = calculate_t_chart(valid_vals)
                    res === nothing && error("Need >= 2 positive values for t-chart")
                    center_line_val = string(round(res.center_line, digits=3))
                    ucl_val = string(round(res.ucl, digits=3))
                    lcl_val = string(round(res.lcl, digits=3))
                    signals_count = length(res.signals)
                    chart_description = "t-Chart: Time between events (log-normal)"

                    push!(traces, PlotData(x=x_indices, y=res.values, name="Time Between",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#2196F3", "size" => 6)))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.center_line, res.center_line],
                        name="CL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#4CAF50"), mode="lines"))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.ucl, res.ucl],
                        name="UCL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.lcl, res.lcl],
                        name="LCL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))

                elseif chart_type == "CUSUM"
                    res = calculate_cusum(valid_vals; target=cusum_target, k=cusum_k, h=cusum_h)
                    res === nothing && error("Need >= 2 values for CUSUM chart")
                    center_line_val = string(round(res.center_line, digits=3))
                    ucl_val = string(round(res.ucl, digits=3))
                    lcl_val = string(round(res.lcl, digits=3))
                    signals_count = length(res.signals)
                    chart_description = "CUSUM: Two-sided cumulative sum (target=$(cusum_target))"

                    push!(traces, PlotData(x=x_indices, y=res.upper_cusum, name="C+ (Upper)",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#2196F3")))
                    push!(traces, PlotData(x=x_indices, y=res.lower_cusum, name="C- (Lower)",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#FF9800")))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[res.ucl, res.ucl],
                        name="H", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                    push!(traces, PlotData(x=[1, length(valid_vals)], y=[0.0, 0.0],
                        name="Zero", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#9E9E9E"), mode="lines"))

                elseif chart_type == "EWMA"
                    res = calculate_ewma(valid_vals; lambda=ewma_lambda, L=ewma_L)
                    res === nothing && error("Need >= 2 values for EWMA chart")
                    center_line_val = string(round(res.center_line, digits=3))
                    ucl_val = "Variable (time-varying)"
                    lcl_val = "Variable (time-varying)"
                    signals_count = length(res.signals)
                    chart_description = "EWMA: lambda=$(ewma_lambda), L=$(ewma_L)"

                    push!(traces, PlotData(x=x_indices, y=res.ewma, name="EWMA",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#2196F3", "size" => 6)))
                    push!(traces, PlotData(x=x_indices, y=fill(res.center_line, length(valid_vals)),
                        name="CL", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#4CAF50"), mode="lines"))
                    push!(traces, PlotData(x=x_indices, y=res.ucl, name="UCL",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                    push!(traces, PlotData(x=x_indices, y=res.lcl, name="LCL",
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                        marker=Dict("color" => "#F44336"), mode="lines",
                        line=Dict("dash" => "dash")))
                end

                signals_text = signals_count > 0 ?
                    "$(signals_count) out-of-control signal(s) detected" :
                    "Process in control — no signals detected"

                spc_chart_data = traces
                spc_chart_layout = PlotLayout(
                    title=PlotLayoutTitle(text="SPC $(chart_type) Control Chart"),
                    xaxis=[PlotLayoutAxis(title="Observation")],
                    yaxis=[PlotLayoutAxis(title="Value")],
                )

                @info "SPC chart ($(chart_type)): CL=$(center_line_val), signals=$(signals_count)"
            catch err
                center_line_val = "Error"
                ucl_val = sprint(showerror, err)
                lcl_val = ""
                signals_count = 0
                signals_text = "Calculation failed — check inputs"
                @error "SPC chart error" exception=(err, catch_backtrace())
            end
        end
    end
end

const spc_charts_model = @init
