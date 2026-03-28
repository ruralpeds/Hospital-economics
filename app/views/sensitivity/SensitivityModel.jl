"""
Stipple reactive model for Sensitivity / Tornado Analysis.
Ranks variable impacts on net income through perturbation analysis.
"""
using Stipple, StippleUI, StipplePlotly

@appname SensitivityApp

@app begin
    # ── Base Inputs ─────────────────────────────────────────────────────
    @in base_revenue::Float64 = 18_500_000.0
    @in base_expenses::Float64 = 19_200_000.0

    # ── Variable Perturbations (10 variables, pct swing) ────────────────
    @in var1_name::String = "Patient Volume"
    @in var1_pct::Float64 = 0.10
    @in var2_name::String = "Medicare Rate"
    @in var2_pct::Float64 = 0.05
    @in var3_name::String = "Labor Cost"
    @in var3_pct::Float64 = 0.08
    @in var4_name::String = "Supply Cost"
    @in var4_pct::Float64 = 0.12
    @in var5_name::String = "Payer Mix Shift"
    @in var5_pct::Float64 = 0.06
    @in var6_name::String = "Length of Stay"
    @in var6_pct::Float64 = 0.07
    @in var7_name::String = "Outpatient Volume"
    @in var7_pct::Float64 = 0.10
    @in var8_name::String = "Bad Debt Rate"
    @in var8_pct::Float64 = 0.15
    @in var9_name::String = "Contract Labor"
    @in var9_pct::Float64 = 0.20
    @in var10_name::String = "Drug Costs"
    @in var10_pct::Float64 = 0.10

    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out base_net_income::Float64 = -700_000.0
    @out most_sensitive_variable::String = "Patient Volume"
    @out max_swing::Float64 = 3_700_000.0

    @out ranked_impacts::Vector{Dict{String,Any}} = [
        Dict("variable" => "Patient Volume", "upside" => 1_150_000, "downside" => -2_550_000, "swing" => 3_700_000),
        Dict("variable" => "Labor Cost", "upside" => 836_000, "downside" => -2_236_000, "swing" => 3_072_000),
        Dict("variable" => "Outpatient Volume", "upside" => 1_150_000, "downside" => -2_550_000, "swing" => 3_700_000),
        Dict("variable" => "Contract Labor", "upside" => 480_000, "downside" => -1_880_000, "swing" => 2_360_000),
        Dict("variable" => "Bad Debt Rate", "upside" => 975_000, "downside" => -2_375_000, "swing" => 3_350_000),
    ]

    # ── Tornado Chart Data ──────────────────────────────────────────────
    @out tornado_data::Vector{PlotData} = [
        PlotData(
            y = ["Drug Costs", "Contract Labor", "Bad Debt", "Payer Mix", "LOS",
                 "Medicare Rate", "Supply Cost", "Outpatient Vol", "Labor Cost", "Patient Volume"],
            x = [185, 480, 975, 555, 648, 462, 1152, 1150, 836, 1150],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Upside (\$K)",
            orientation = "h",
            marker = Dict("color" => "#4CAF50"),
        ),
        PlotData(
            y = ["Drug Costs", "Contract Labor", "Bad Debt", "Payer Mix", "LOS",
                 "Medicare Rate", "Supply Cost", "Outpatient Vol", "Labor Cost", "Patient Volume"],
            x = [-185, -480, -975, -555, -648, -462, -1152, -1150, -836, -1150],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Downside (\$K)",
            orientation = "h",
            marker = Dict("color" => "#F44336"),
        ),
    ]
    @out tornado_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Sensitivity Tornado Diagram (\$K Impact)"),
        barmode = "overlay",
        xaxis = [PlotLayoutAxis(title = "\$K Impact on Net Income")],
        yaxis = [PlotLayoutAxis(title = "")],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            base_net_income = base_revenue - base_expenses

            names_list = [var1_name, var2_name, var3_name, var4_name, var5_name,
                          var6_name, var7_name, var8_name, var9_name, var10_name]
            pcts = [var1_pct, var2_pct, var3_pct, var4_pct, var5_pct,
                    var6_pct, var7_pct, var8_pct, var9_pct, var10_pct]

            # Simple sensitivity: revenue variables get revenue swing, cost vars get expense swing
            rev_vars = Set([1, 2, 5, 7, 8])
            upsides = Float64[]
            downsides = Float64[]
            for i in 1:10
                if i in rev_vars
                    up = base_revenue * pcts[i]
                    push!(upsides, round(up, digits=0))
                    push!(downsides, round(-up, digits=0))
                else
                    up = base_expenses * pcts[i]
                    push!(upsides, round(up, digits=0))
                    push!(downsides, round(-up, digits=0))
                end
            end

            swings = upsides .- downsides
            order = sortperm(swings)
            sorted_names = names_list[order]
            sorted_up = round.(upsides[order] ./ 1000, digits=0)
            sorted_down = round.(downsides[order] ./ 1000, digits=0)

            most_sensitive_variable = sorted_names[end]
            max_swing = swings[order[end]]

            tornado_data = [
                PlotData(y=sorted_names, x=sorted_up, plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                    name="Upside (\$K)", orientation="h", marker=Dict("color"=>"#4CAF50")),
                PlotData(y=sorted_names, x=sorted_down, plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                    name="Downside (\$K)", orientation="h", marker=Dict("color"=>"#F44336")),
            ]
            @info "Sensitivity analysis: most sensitive to $(most_sensitive_variable)"
        end
    end
end

const sensitivity_model = @init
