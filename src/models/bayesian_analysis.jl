# ============================================================================
# Bayesian Beta-Binomial Conjugate Analysis
# ============================================================================

using Distributions
using Random

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    BayesianBetaBinomialInput

Input parameters for a Bayesian Beta-Binomial conjugate analysis.

# Fields
- `prior_alpha::Float64`: Beta prior shape parameter alpha (default 1.0 = uniform)
- `prior_beta::Float64`: Beta prior shape parameter beta (default 1.0 = uniform)
- `observed_events::Int`: number of observed successes / events
- `total_observations::Int`: total number of trials / observations
"""
@kwdef struct BayesianBetaBinomialInput
    prior_alpha::Float64       = 1.0
    prior_beta::Float64        = 1.0
    observed_events::Int
    total_observations::Int
end

"""
    BayesianBetaBinomialResult

Result of a Bayesian Beta-Binomial conjugate analysis.

# Fields
- `posterior_alpha::Float64`: posterior Beta shape alpha
- `posterior_beta::Float64`: posterior Beta shape beta
- `posterior_mean::Float64`: posterior mean = alpha' / (alpha' + beta')
- `posterior_std::Float64`: posterior standard deviation
- `credible_interval_95::Tuple{Float64,Float64}`: 95% credible interval (2.5th, 97.5th percentiles)
- `prior_mean::Float64`: prior mean = alpha / (alpha + beta)
- `posterior_samples::Vector{Float64}`: 1000 samples from the posterior for plotting
"""
struct BayesianBetaBinomialResult
    posterior_alpha::Float64
    posterior_beta::Float64
    posterior_mean::Float64
    posterior_std::Float64
    credible_interval_95::Tuple{Float64,Float64}
    prior_mean::Float64
    posterior_samples::Vector{Float64}
end

# ---------------------------------------------------------------------------
# Core analysis
# ---------------------------------------------------------------------------

"""
    analyze_beta_binomial(input::BayesianBetaBinomialInput) -> BayesianBetaBinomialResult

Perform Bayesian conjugate updating for a Beta-Binomial model.

## Posterior derivation
Given a Beta(alpha, beta) prior and observing `k` events out of `n` trials,
the posterior is:

    Beta(alpha + k, beta + n - k)

The posterior mean is alpha' / (alpha' + beta') and the variance is
alpha' * beta' / ((alpha' + beta')^2 * (alpha' + beta' + 1)).

The 95% credible interval uses the exact Beta quantile function.
1000 posterior samples are generated for plotting.
"""
function analyze_beta_binomial(input::BayesianBetaBinomialInput)
    # Posterior parameters (conjugate update)
    post_alpha = input.prior_alpha + input.observed_events
    post_beta = input.prior_beta + (input.total_observations - input.observed_events)

    # Posterior distribution
    posterior = Beta(post_alpha, post_beta)

    # Summary statistics
    posterior_mean = post_alpha / (post_alpha + post_beta)
    variance = (post_alpha * post_beta) /
               ((post_alpha + post_beta)^2 * (post_alpha + post_beta + 1.0))
    posterior_std = sqrt(variance)

    # 95% credible interval via exact Beta quantiles
    ci_lower = quantile(posterior, 0.025)
    ci_upper = quantile(posterior, 0.975)

    # Prior mean
    prior_mean = input.prior_alpha / (input.prior_alpha + input.prior_beta)

    # Generate 1000 posterior samples (deterministic stratified for reproducibility)
    samples = Vector{Float64}(undef, 1000)
    for i in 1:1000
        u = (i - 0.5) / 1000.0
        samples[i] = quantile(posterior, u)
    end

    return BayesianBetaBinomialResult(
        post_alpha,
        post_beta,
        posterior_mean,
        posterior_std,
        (ci_lower, ci_upper),
        prior_mean,
        samples,
    )
end
