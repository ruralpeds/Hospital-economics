"""
Stipple reactive model for Gaussian Copula Monte Carlo simulation.
Generates correlated bivariate samples and displays scatter/correlation analysis.
Delegates to RuralHospitalSim.generate_copula_samples() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: generate_copula_samples, CopulaInput, CopulaResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in n_simulations::Int = 1000
    @in var1_mean::Float64 = 100.0
    @in var1_std::Float64 = 15.0
    @in var2_mean::Float64 = 50.0
    @in var2_std::Float64 = 10.0
    @in correlation::Float64 = 0.6
    @in random_seed::Int = 42
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out empirical_corr_12::Float64 = 0.0
    @out var1_emp_mean::Float64 = 0.0
    @out var1_emp_std::Float64 = 0.0
    @out var1_emp_min::Float64 = 0.0
    @out var1_emp_max::Float64 = 0.0
    @out var2_emp_mean::Float64 = 0.0
    @out var2_emp_std::Float64 = 0.0
    @out var2_emp_min::Float64 = 0.0
    @out var2_emp_max::Float64 = 0.0

    @out summary_table::Vector{Dict{String,Any}} = Dict{String,Any}[]

    @out scatter_data::Vector{PlotData} = PlotData[]
    @out scatter_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Copula Samples Scatter Plot"),
        xaxis=[PlotLayoutAxis(title="Variable 1")],
        yaxis=[PlotLayoutAxis(title="Variable 2")],
    )

    # ── Handler ─────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            corr_matrix = [1.0 correlation; correlation 1.0]
            input = CopulaInput(;
                n_simulations=n_simulations,
                marginal_params=[(var1_mean, var1_std), (var2_mean, var2_std)],
                correlation_matrix=corr_matrix,
                random_seed=random_seed,
            )
            result = generate_copula_samples(input)

            empirical_corr_12 = result.empirical_correlation[1, 2]

            # Summary stats
            s1 = result.summary_stats[1]
            s2 = result.summary_stats[2]
            var1_emp_mean = s1.mean
            var1_emp_std = s1.std
            var1_emp_min = s1.min
            var1_emp_max = s1.max
            var2_emp_mean = s2.mean
            var2_emp_std = s2.std
            var2_emp_min = s2.min
            var2_emp_max = s2.max

            summary_table = [
                Dict("variable" => "Variable 1", "mean" => round(s1.mean, digits=2),
                     "std" => round(s1.std, digits=2), "min" => round(s1.min, digits=2),
                     "max" => round(s1.max, digits=2)),
                Dict("variable" => "Variable 2", "mean" => round(s2.mean, digits=2),
                     "std" => round(s2.std, digits=2), "min" => round(s2.min, digits=2),
                     "max" => round(s2.max, digits=2)),
            ]

            # Scatter plot
            scatter_data = [
                PlotData(x=result.samples[:, 1], y=result.samples[:, 2],
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         mode="markers",
                         name="Samples",
                         marker=Dict("color" => "rgba(33,150,243,0.4)", "size" => 4)),
            ]

            @info "Copula MC: empirical rho=$(round(empirical_corr_12, digits=4)), n=$(n_simulations)"
        end
    end
end

const copula_mc_model = @init
