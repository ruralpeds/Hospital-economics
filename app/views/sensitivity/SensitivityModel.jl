"""
Stipple reactive model for Sensitivity / Tornado Analysis.
Delegates to RuralHospitalSim.run_sensitivity_analysis() for perturbation analysis.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: run_sensitivity_analysis, build_tornado_data, SensitivityResult


@app begin
    @in left_drawer_open::Bool = true
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
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out is_loading::Bool = false

    @out base_net_income::Float64 = -700_000.0
    @out most_sensitive_variable::String = "Patient Volume"
    @out max_swing::Float64 = 3_700_000.0

    @out ranked_impacts::Vector{Dict{String,Any}} = Dict{String,Any}[]

    # ── Tornado Chart Data ──────────────────────────────────────────────
    @out tornado_data::Vector{PlotData} = PlotData[]
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
            is_loading = true
            try
            base_net_income = base_revenue - base_expenses

            # Build parameter dict for domain engine
            names_list = [var1_name, var2_name, var3_name, var4_name, var5_name,
                          var6_name, var7_name, var8_name, var9_name, var10_name]
            pcts = [var1_pct, var2_pct, var3_pct, var4_pct, var5_pct,
                    var6_pct, var7_pct, var8_pct, var9_pct, var10_pct]

            # Revenue-affecting vs cost-affecting variables
            rev_vars = Set([1, 2, 5, 7, 8])

            # Build base params for the sensitivity engine
            base_params = Dict{String,Float64}()
            for i in 1:10
                base_params[names_list[i]] = i in rev_vars ? base_revenue * pcts[i] : base_expenses * pcts[i]
            end

            # Define the model function: net income given parameter perturbations
            model_fn(params::Dict{String,Float64}) = begin
                rev_delta = sum(get(params, names_list[i], 0.0) for i in 1:10 if i in rev_vars)
                exp_delta = sum(get(params, names_list[i], 0.0) for i in 1:10 if !(i in rev_vars))
                base_revenue + rev_delta - (base_expenses + exp_delta)
            end

            # Call domain engine
            results = run_sensitivity_analysis(model_fn, base_params;
                perturbation=0.10, outcome_name="net_income")

            # Build tornado data from domain results
            tornado = build_tornado_data(results; top_n=10)

            # Sort by swing for display
            sorted = sort(results, by=r -> r.swing)
            sorted_names = [r.parameter_name for r in sorted]
            sorted_up = [round(max(r.high_outcome - r.base_outcome, r.base_outcome - r.low_outcome) / 1000, digits=0) for r in sorted]
            sorted_down = [-round(max(r.base_outcome - r.low_outcome, r.high_outcome - r.base_outcome) / 1000, digits=0) for r in sorted]

            most_sensitive_variable = sorted[end].parameter_name
            max_swing = sorted[end].swing

            ranked_impacts = [Dict{String,Any}(
                "variable" => r.parameter_name,
                "upside" => round(r.high_outcome - r.base_outcome, digits=0),
                "downside" => round(r.low_outcome - r.base_outcome, digits=0),
                "swing" => round(r.swing, digits=0),
            ) for r in reverse(sorted)]

            tornado_data = [
                PlotData(y=sorted_names, x=sorted_up, plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                    name="Upside (\$K)", orientation="h", marker=Dict("color"=>"#4CAF50")),
                PlotData(y=sorted_names, x=sorted_down, plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                    name="Downside (\$K)", orientation="h", marker=Dict("color"=>"#F44336")),
            ]
            @info "Sensitivity analysis: most sensitive to $(most_sensitive_variable), swing=\$$(round(Int, max_swing))"
            catch e
                push!(errors, string(e))
            finally
                is_loading = false
            end
        end
    end
end

const sensitivity_model = @init
