"""
Stipple reactive model for Bayesian Beta-Binomial conjugate analysis.
Updates prior beliefs with observed data and visualizes posterior distribution.
Delegates to RuralHospitalSim.analyze_beta_binomial() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: analyze_beta_binomial, BayesianBetaBinomialInput, BayesianBetaBinomialResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in prior_alpha::Float64 = 1.0
    @in prior_beta::Float64 = 1.0
    @in observed_events::Int = 15
    @in total_observations::Int = 100
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out posterior_alpha::Float64 = 0.0
    @out posterior_beta_out::Float64 = 0.0
    @out posterior_mean::Float64 = 0.0
    @out posterior_std::Float64 = 0.0
    @out ci_lower::Float64 = 0.0
    @out ci_upper::Float64 = 0.0
    @out prior_mean::Float64 = 0.0

    @out density_chart_data::Vector{PlotData} = PlotData[]
    @out density_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Posterior Density"),
        xaxis=[PlotLayoutAxis(title="Probability")],
        yaxis=[PlotLayoutAxis(title="Density")],
        barmode="overlay",
    )

    # ── Handler ─────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            input = BayesianBetaBinomialInput(;
                prior_alpha=prior_alpha,
                prior_beta=prior_beta,
                observed_events=observed_events,
                total_observations=total_observations,
            )
            result = analyze_beta_binomial(input)

            posterior_alpha = result.posterior_alpha
            posterior_beta_out = result.posterior_beta
            posterior_mean = result.posterior_mean
            posterior_std = result.posterior_std
            ci_lower = result.credible_interval_95[1]
            ci_upper = result.credible_interval_95[2]
            prior_mean = result.prior_mean

            # Generate prior samples for comparison (stratified)
            prior_dist_alpha = prior_alpha
            prior_dist_beta = prior_beta
            n_bins = 50
            # Use posterior samples histogram
            posterior_samples = result.posterior_samples

            # Build prior density from Beta quantiles
            prior_samples = Vector{Float64}(undef, 1000)
            for i in 1:1000
                u = (i - 0.5) / 1000.0
                # Beta quantile approximation using posterior distribution
                # For the prior, we rebuild from prior params
                prior_samples[i] = u  # placeholder x-values
            end

            density_chart_data = [
                PlotData(x=posterior_samples,
                         plot=StipplePlotly.Charts.PLOT_TYPE_HISTOGRAM,
                         name="Posterior",
                         marker=Dict("color" => "rgba(33,150,243,0.6)"),
                         nbinsx=n_bins,
                         histnorm="probability density"),
                PlotData(x=[posterior_mean, posterior_mean],
                         y=[0, 50],
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         mode="lines",
                         name="Posterior Mean",
                         line=Dict("color" => "#2196F3", "width" => 3, "dash" => "dash")),
                PlotData(x=[prior_mean, prior_mean],
                         y=[0, 50],
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         mode="lines",
                         name="Prior Mean",
                         line=Dict("color" => "#FF9800", "width" => 2, "dash" => "dot")),
                PlotData(x=[ci_lower, ci_lower],
                         y=[0, 50],
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         mode="lines",
                         name="95% CI Lower",
                         line=Dict("color" => "#4CAF50", "width" => 1, "dash" => "dash")),
                PlotData(x=[ci_upper, ci_upper],
                         y=[0, 50],
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         mode="lines",
                         name="95% CI Upper",
                         line=Dict("color" => "#4CAF50", "width" => 1, "dash" => "dash")),
            ]

            @info "Bayesian: posterior Beta($(round(posterior_alpha, digits=1)), $(round(posterior_beta_out, digits=1))), mean=$(round(posterior_mean, digits=4)), 95% CI=[$(round(ci_lower, digits=4)), $(round(ci_upper, digits=4))]"
        end
    end
end

const bayesian_model = @init
