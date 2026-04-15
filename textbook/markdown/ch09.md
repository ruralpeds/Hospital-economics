# Chapter 9: Econometric Foundations for Health Economics Research

## Introduction

The transition from economic theory to empirical evidence requires econometric methods capable of distinguishing causal relationships from mere correlations in observational data. This distinction is the central challenge of empirical health economics. Does insurance coverage improve health, or do healthier individuals select into coverage? Does hospital competition reduce prices, or do hospitals with lower costs attract more competitors? Does physician supply drive utilization, or does high demand attract physicians? In each case, the observed correlation between the variables of interest reflects a mixture of causal effects, reverse causation, and confounding — and without methods to disentangle these components, empirical analysis cannot inform policy.

This chapter establishes the econometric foundations upon which the quasi-experimental methods of Chapters 10-12 and the specialized models of Chapters 13-17 are built. We begin with the identification problem and the potential outcomes framework that formalizes causal inference. We then develop the core estimation methods used in health economics research: ordinary least squares and its assumptions, maximum likelihood estimation, generalized linear models for healthcare cost data, two-part models for healthcare expenditures with mass at zero, the sources and consequences of endogeneity, and panel data methods for controlling unobserved heterogeneity. Throughout, we emphasize the specific challenges that health economics data present — skewed expenditure distributions, zero-inflated utilization counts, selection into treatment, clustered observations — and the econometric solutions that have been developed to address them.

The target audience is graduate researchers with foundational training in statistics and econometrics who seek to understand the specific methodological challenges and solutions relevant to empirical health economics. Mathematical derivations are provided for key estimators, and health economics applications illustrate every method.

## The Identification Problem in Health Economics

### Correlation, Causation, and the Policy Question

Health economics research is fundamentally concerned with causal questions: What is the effect of insurance on utilization? What is the effect of a payment reform on quality? What is the effect of hospital closure on mortality? Answering these questions requires isolating the causal effect of the treatment (insurance, payment reform, closure) from the confounding factors that are correlated with both the treatment and the outcome.

The identification problem arises because in observational data, individuals who receive treatment differ systematically from those who do not. Individuals who have health insurance differ from the uninsured in income, education, health status, risk preferences, and employment — all of which independently affect health outcomes. A simple comparison of outcomes between insured and uninsured individuals therefore reflects both the causal effect of insurance and the selection differences between the two groups. Without a strategy to address selection, the causal effect is not identified.

### The Rubin Causal Model and Potential Outcomes

The Rubin causal model (RCM), also called the potential outcomes framework, provides the formal structure for defining and analyzing causal effects. For each individual i, we define two potential outcomes:

Y₁ᵢ = the outcome individual i would experience if treated (e.g., insured)
Y₀ᵢ = the outcome individual i would experience if not treated (e.g., uninsured)

The individual treatment effect is τᵢ = Y₁ᵢ - Y₀ᵢ. The average treatment effect (ATE) is E[Y₁ᵢ - Y₀ᵢ], and the average treatment effect on the treated (ATT) is E[Y₁ᵢ - Y₀ᵢ | Dᵢ = 1], where Dᵢ is a binary treatment indicator.

### The Fundamental Problem of Causal Inference

The fundamental problem is that we observe only one potential outcome for each individual: Y₁ᵢ if the individual is treated, or Y₀ᵢ if not treated. The unobserved potential outcome is the counterfactual — what would have happened to the treated individual had they not been treated, or vice versa. Because the counterfactual is never observed, the individual treatment effect τᵢ is fundamentally unidentifiable.

The naive estimator of the ATE — the difference in mean outcomes between treated and untreated groups — can be decomposed as:

E[Yᵢ | Dᵢ = 1] - E[Yᵢ | Dᵢ = 0] = ATT + {E[Y₀ᵢ | Dᵢ = 1] - E[Y₀ᵢ | Dᵢ = 0]}

The second term is the selection bias — the difference in untreated potential outcomes between the treated and untreated groups. If selection into treatment is correlated with potential outcomes (as is almost always the case in observational health data), the naive estimator is biased. The magnitude and sign of the bias depend on the nature of the selection process.

In health economics, selection bias is typically positive for insurance-outcome relationships (sicker individuals select into more generous coverage, making insurance appear less beneficial) and ambiguous for provider-outcome relationships (sicker patients may be referred to higher-quality specialists, creating positive selection, or may be unable to access high-quality providers, creating negative selection).

### The Stable Unit Treatment Value Assumption

The stable unit treatment value assumption (SUTVA) requires that each individual's potential outcomes depend only on their own treatment status, not on the treatment status of other individuals. SUTVA rules out interference effects (spillovers) and requires that the treatment is well-defined (no hidden variations in treatment).

SUTVA may be violated in health economics settings where treatment effects spill over across individuals. Vaccination creates herd immunity that protects unvaccinated individuals. Hospital quality improvement may benefit patients at neighboring hospitals through knowledge diffusion. Insurance coverage expansion may affect the uninsured by altering provider behavior, crowding out private coverage, or changing the composition of the risk pool. When SUTVA violations are suspected, researchers must either model the interference structure explicitly or restrict the analysis to settings where spillovers are minimal.

## Ordinary Least Squares in Health Economics

### The Classical Linear Model

The multiple regression model specifies the conditional expectation of the outcome Y as a linear function of observable covariates X and the treatment variable D:

Yᵢ = β₀ + β₁Dᵢ + X'ᵢγ + εᵢ

where β₁ is the coefficient of interest (the estimated treatment effect), γ is a vector of coefficients on control variables, and εᵢ is the error term. The OLS estimator minimizes the sum of squared residuals:

β̂_OLS = (X'X)⁻¹X'Y

where X is the design matrix including the treatment indicator and all covariates.

Under the classical assumptions — linearity, random sampling, no perfect multicollinearity, zero conditional mean of errors (E[εᵢ | Xᵢ, Dᵢ] = 0), and homoscedasticity — OLS is the best linear unbiased estimator (BLUE) by the Gauss-Markov theorem, and β₁ has a causal interpretation as the average treatment effect conditional on covariates.

### Violations in Health Economics Data

Health economics data routinely violate one or more classical assumptions, requiring modified estimation and inference procedures.

**Heteroscedasticity.** Healthcare expenditure data exhibit severe heteroscedasticity — the variance of expenditures increases with the level of expenditures, with predicted values, and with patient characteristics such as age and comorbidity burden. Under heteroscedasticity, OLS remains unbiased and consistent but its standard errors are incorrect, leading to invalid inference.

The standard remedy is Huber-White heteroscedasticity-robust standard errors (also called sandwich estimators or HC standard errors). The robust variance estimator is:

V̂_robust = (X'X)⁻¹ (Σᵢ ε̂ᵢ² xᵢx'ᵢ) (X'X)⁻¹

where ε̂ᵢ are OLS residuals. Robust standard errors should be used as a default in health economics applications; there is no cost to using them when errors are homoscedastic and a substantial cost to not using them when errors are heteroscedastic.

**Clustered standard errors.** Health economics data are frequently clustered — patients within hospitals, employees within firms, beneficiaries within states — and observations within clusters may be correlated due to shared unobserved factors. Clustering violates the independence assumption and causes standard errors (including heteroscedasticity-robust standard errors) to understate the true sampling variability.

Cluster-robust standard errors, which allow for arbitrary within-cluster correlation, are computed by replacing the middle matrix in the sandwich estimator with cluster-level sums of outer products:

V̂_cluster = (X'X)⁻¹ (Σ_g ûg û'g) (X'X)⁻¹

where ûg = Σᵢ∈g ε̂ᵢxᵢ is the cluster-level score for cluster g.

The choice of clustering level is consequential. Bertrand, Duflo, and Mullainathan (2004) demonstrated that failing to cluster at the appropriate level (the level at which the treatment varies) in difference-in-differences analyses leads to dramatic over-rejection of the null hypothesis — false positive rates of 45% or higher at the 5% nominal level. Their paper established the standard practice of clustering at the state level for state-level policy evaluations, but the appropriate clustering level depends on the specific research design.

**Non-normal errors.** Healthcare expenditure data are heavily right-skewed, with a small number of high-cost patients generating a disproportionate share of total spending. While non-normality does not affect the unbiasedness or consistency of OLS, it can reduce efficiency and affect finite-sample inference. Log transformation of the dependent variable is a common response, but introduces complications for retransformation to the original scale (the smearing problem, discussed below).

## Maximum Likelihood Estimation

### Derivation and Properties

Maximum likelihood estimation (MLE) is the primary estimation method for the nonlinear models widely used in health economics — logistic regression, Poisson regression, negative binomial regression, and other generalized linear models. MLE chooses parameter estimates that maximize the likelihood of observing the data under the assumed model.

For a sample of n independent observations with joint density f(y₁, ..., yₙ | θ), the log-likelihood function is:

ℓ(θ) = Σᵢ ln f(yᵢ | xᵢ, θ)

The MLE θ̂ solves the score equations:

∂ℓ/∂θ = Σᵢ ∂ ln f(yᵢ | xᵢ, θ) / ∂θ = 0

Under regularity conditions (correct model specification, compact parameter space, identification), MLE has desirable asymptotic properties: consistency (θ̂ → θ₀ in probability), asymptotic normality (√n(θ̂ - θ₀) → N(0, I(θ₀)⁻¹)), and asymptotic efficiency (achieves the Cramér-Rao lower bound).

The information matrix I(θ) = -E[∂²ℓ/∂θ∂θ'] provides the basis for standard error estimation. Three asymptotically equivalent test statistics are available: the likelihood ratio test (comparing log-likelihoods of restricted and unrestricted models), the Wald test (testing parameter restrictions using the unrestricted estimates and their standard errors), and the Lagrange multiplier test (testing the score evaluated at the restricted estimates).

### Application to Binary Choice Models

Binary choice models — logistic regression (logit) and probit — are workhorses of health economics for modeling binary outcomes: insurance coverage (yes/no), hospitalization (yes/no), mortality (yes/no), treatment receipt (yes/no).

The logit model specifies:

Pr(Yᵢ = 1 | Xᵢ) = Λ(X'ᵢβ) = exp(X'ᵢβ) / (1 + exp(X'ᵢβ))

where Λ(·) is the logistic CDF. The probit model uses the standard normal CDF:

Pr(Yᵢ = 1 | Xᵢ) = Φ(X'ᵢβ)

Both models are estimated by MLE. The coefficients β are not directly interpretable as marginal effects because the link function is nonlinear. Marginal effects — the change in probability associated with a one-unit change in a covariate — must be computed as:

Marginal effect of xₖ = ∂Pr(Y = 1 | X) / ∂xₖ = f(X'β) × βₖ

where f(·) is the density function (logistic or normal). Two conventions are used: marginal effects at the means (MEM), which evaluate the derivative at the sample means of all covariates, and average marginal effects (AME), which average the individual-specific marginal effects across all observations. AME is generally preferred because it does not depend on the potentially unrepresentative "average" covariate profile.

## Generalized Linear Models for Healthcare Costs

### The GLM Framework

Generalized linear models (GLMs) extend the linear model to accommodate non-normal error distributions and nonlinear relationships between the conditional mean and the linear predictor. A GLM is specified by three components:

1. **Random component**: The distribution of the outcome variable (normal, Poisson, gamma, binomial, etc.).
2. **Systematic component**: The linear predictor η = X'β.
3. **Link function**: The function g(·) that relates the conditional mean μ = E[Y | X] to the linear predictor: g(μ) = X'β.

For healthcare cost modeling, the most commonly used GLM specification is the gamma distribution with a log link:

g(μ) = ln(μ), so μ = exp(X'β)

This specification has two important properties. First, the log link ensures that predicted costs are strictly positive, which is appropriate for expenditure data. Second, the gamma distribution accommodates the right skewness and increasing variance that characterize healthcare cost distributions.

### The Log-OLS vs. GLM Debate

A long-standing debate in health economics concerns the choice between log-OLS (OLS regression on the log-transformed dependent variable) and GLM for modeling healthcare costs. Manning and Mullahy (2001) provided the definitive treatment of this comparison.

**Log-OLS** estimates ln(Yᵢ) = X'ᵢβ + εᵢ, where εᵢ is assumed to be normally distributed. The estimated coefficients are directly interpretable as semi-elasticities (percentage changes in cost associated with unit changes in covariates). However, obtaining predictions on the original (dollar) scale requires retransformation, and the standard retransformation E[Y | X] = exp(X'β) × E[exp(ε)] is valid only if ε is independent of X — an assumption violated under heteroscedasticity.

Duan's (1983) smearing estimator provides a nonparametric correction:

Ê[Y | X] = exp(X'β̂) × (1/n Σᵢ exp(ε̂ᵢ))

The smearing factor (the average of exponentiated residuals) corrects for the retransformation bias under homoscedastic errors. When errors are heteroscedastic, the smearing factor should be computed separately for relevant subgroups.

**GLM with log link** directly models E[Y | X] = exp(X'β), avoiding the retransformation problem entirely. Predictions on the dollar scale are obtained directly from the model without any adjustment. GLM also accommodates heteroscedasticity through the specification of the variance function.

### Variance Function Selection: The Modified Park Test

The choice of GLM family (normal, Poisson, gamma, inverse Gaussian) determines the relationship between the conditional variance and the conditional mean. Manning and Mullahy (2001) proposed the modified Park test for selecting the appropriate variance function.

The Park test regresses the squared raw-scale residuals on the predicted mean:

ln(ε̂ᵢ²) = α₀ + α₁ ln(μ̂ᵢ) + vᵢ

The estimated coefficient α̂₁ indicates the appropriate variance function:

- α̂₁ ≈ 0: constant variance (normal/Gaussian family)
- α̂₁ ≈ 1: variance proportional to mean (Poisson family)
- α̂₁ ≈ 2: variance proportional to mean squared (gamma family)
- α̂₁ ≈ 3: variance proportional to mean cubed (inverse Gaussian/Wald family)

For healthcare expenditure data, the gamma family (α₁ ≈ 2) is the most common empirical finding, though the Poisson family sometimes provides a better fit, particularly for less skewed distributions.

## Two-Part Models for Healthcare Expenditures

### The Zero Mass Problem

Healthcare expenditure distributions have a distinctive feature: a substantial fraction of individuals in any given period incur zero expenditures. In a typical annual claims dataset, 15% to 30% of individuals have no healthcare utilization and therefore zero expenditures. This mass at zero creates a mixed distribution — a discrete probability mass at zero combined with a continuous distribution for positive values — that is poorly accommodated by standard regression models.

### The Two-Part Model

The two-part model (also called the hurdle model) addresses the zero mass by decomposing the expenditure distribution into two components estimated separately:

**Part 1 (extensive margin)**: A binary choice model (logit or probit) for the probability of any expenditure:

Pr(Yᵢ > 0 | Xᵢ) = Φ(X'ᵢα) or Λ(X'ᵢα)

**Part 2 (intensive margin)**: A regression model for the level of expenditures, conditional on positive expenditure:

E[Yᵢ | Yᵢ > 0, Xᵢ] = h(X'ᵢβ)

where h(·) may be specified as a log-linear model (ln(Y) = X'β + ε for log-OLS) or a GLM (E[Y | Y > 0, X] = exp(X'β) for GLM).

The unconditional expected expenditure is the product of the two parts:

E[Yᵢ | Xᵢ] = Pr(Yᵢ > 0 | Xᵢ) × E[Yᵢ | Yᵢ > 0, Xᵢ]

The total marginal effect of a covariate on unconditional expenditures combines the extensive margin effect (change in probability of any spending) and the intensive margin effect (change in spending conditional on positive spending).

### Comparison with the Heckman Selection Model

The two-part model is sometimes confused with the Heckman selection model (Heckman, 1979), but the two models address different problems and make different assumptions. The Heckman model is appropriate when the zero observations result from a selection process — for example, wages are observed only for individuals who choose to participate in the labor force, and the participation decision is correlated with the wage equation error through a bivariate normal joint distribution.

In healthcare, zeros typically reflect a corner solution (the individual optimally chooses zero utilization given their health status and prices) rather than a selection process (the individual has a latent positive expenditure that is censored at zero). When zeros reflect corner solutions, the two-part model is appropriate and the Heckman selection model is not. Dow and Norton (2003) and others have argued that the two-part model is the appropriate default for healthcare expenditure modeling, and the Heckman model should be used only when there is a clear theoretical basis for the selection interpretation and a credible exclusion restriction.

### Bootstrap Inference for Combined Predictions

Because the two-part model combines predictions from two separately estimated equations, the standard errors for combined predictions (unconditional means, marginal effects) must account for the estimation uncertainty in both parts. The standard approach is the nonparametric bootstrap: resample the data with replacement, re-estimate both parts of the model on each bootstrap sample, compute the statistic of interest, and construct confidence intervals from the bootstrap distribution.

The bootstrap is particularly valuable for the two-part model because the combined prediction is a nonlinear function of the parameters from two different models, making analytical standard error derivation complex. With modern computing (including Julia, as covered in Chapter 21), bootstrap inference with 1,000 to 5,000 replications is computationally straightforward.

---

**Key Concepts Box: Choosing Among Healthcare Cost Models**

| Model | When to Use | Advantages | Disadvantages |
|---|---|---|---|
| OLS on raw costs | Rarely (non-skewed data only) | Simple, direct interpretation | Sensitive to outliers; poor fit for skewed data |
| Log-OLS | Homoscedastic log-scale errors | Simple; direct semi-elasticity interpretation | Retransformation bias; log(0) undefined |
| GLM (gamma, log link) | Default for positive healthcare costs | No retransformation; handles heteroscedasticity | Requires variance function selection |
| Two-part model | Data with mass at zero | Separates extensive/intensive margins | Requires bootstrap for combined inference |
| Heckman selection | True sample selection (rare in health) | Corrects for selection bias | Requires valid exclusion restriction; assumes bivariate normality |

---

## Endogeneity in Health Economics

### Sources of Endogeneity

Endogeneity — correlation between the treatment or explanatory variable and the error term — is the most pervasive threat to causal inference in observational health economics. Three primary sources of endogeneity are:

**Omitted variable bias.** The regression omits a variable that is correlated with both the treatment and the outcome. In health economics, unobserved health status is the most common omitted variable: sicker individuals both utilize more healthcare (the outcome) and are more likely to have insurance (the treatment), creating upward bias in naive estimates of the insurance-utilization relationship.

The direction and magnitude of omitted variable bias can be analyzed using the formula:

bias(β̂₁) = γ₁ × δ₁

where γ₁ is the coefficient of the omitted variable in the outcome equation and δ₁ is the coefficient of the treatment variable in a regression of the omitted variable on the treatment. If sicker individuals are more likely to be insured (δ₁ > 0) and sickness increases utilization (γ₁ > 0), the bias is positive — the naive estimate overstates the causal effect of insurance on utilization.

**Simultaneity (reverse causation).** The outcome variable feeds back to affect the explanatory variable. In health economics, utilization may affect insurance status (high utilizers are more likely to maintain coverage), health outcomes may affect physician supply (areas with worse outcomes may attract more physicians through policy responses), and hospital quality may affect market share (better hospitals attract more patients, which further improves quality through volume-outcome effects).

**Measurement error.** When explanatory variables are measured with error, the resulting "errors-in-variables" bias generally attenuates the estimated coefficient toward zero. In health economics, self-reported health status, insurance coverage status, and healthcare utilization are all measured with error, potentially biasing estimated relationships.

### Instrumental Variables Preview

The primary econometric solution to endogeneity is instrumental variables (IV) estimation, which is covered in depth in Chapter 10. Briefly, an instrument Z is a variable that is correlated with the endogenous treatment D (relevance) but is uncorrelated with the error term in the outcome equation (exogeneity/exclusion restriction). The IV estimator uses only the variation in D that is predicted by Z — the exogenous variation — to estimate the causal effect of D on Y.

The two-stage least squares (2SLS) estimator proceeds in two steps:

**First stage**: Dᵢ = π₀ + π₁Zᵢ + X'ᵢπ₂ + vᵢ

**Second stage**: Yᵢ = β₀ + β₁D̂ᵢ + X'ᵢγ + εᵢ

where D̂ᵢ is the predicted value from the first stage. The coefficient β₁ from the second stage has a causal interpretation under the assumptions that the instrument is relevant (π₁ ≠ 0), exogenous (Cov(Zᵢ, εᵢ) = 0), and satisfies the exclusion restriction (Z affects Y only through D). Chapter 10 develops the IV framework in full detail, including the local average treatment effect (LATE) interpretation, weak instrument diagnostics, and applications to health economics.

## Panel Data Methods

### Fixed Effects Estimation

Panel data — repeated observations on the same units (individuals, hospitals, states) over time — enable control for time-invariant unobserved heterogeneity through fixed effects estimation. The fixed effects model includes unit-specific intercepts that absorb all time-invariant characteristics of each unit:

Yᵢₜ = αᵢ + β₁Dᵢₜ + X'ᵢₜγ + εᵢₜ

where αᵢ is the unit fixed effect. The fixed effects estimator is equivalent to the within-group estimator, which demeans all variables by their unit-specific means:

(Yᵢₜ - Ȳᵢ) = β₁(Dᵢₜ - D̄ᵢ) + (X'ᵢₜ - X̄'ᵢ)γ + (εᵢₜ - ε̄ᵢ)

Fixed effects eliminate all time-invariant confounders — both observed and unobserved. In health economics, this is a powerful advantage because many confounders (genetic predisposition, baseline health status, stable socioeconomic characteristics, geographic fixed factors) are time-invariant. Hospital fixed effects control for all stable hospital characteristics (ownership, teaching status, market position) that might confound the relationship between a time-varying treatment (payment reform, quality program participation) and outcomes.

The limitation of fixed effects is that it cannot identify the effects of time-invariant variables (which are absorbed by the fixed effects) and it relies for identification on within-unit variation over time. If the treatment variable has little within-unit variation (e.g., a hospital either participates in a program throughout the panel or never participates), fixed effects estimation will have limited power.

### Random Effects Estimation

The random effects model treats unit-specific effects as random draws from a population distribution rather than as fixed parameters:

Yᵢₜ = β₀ + β₁Dᵢₜ + X'ᵢₜγ + αᵢ + εᵢₜ

where αᵢ ~ N(0, σ²_α) is independent of Xᵢₜ and Dᵢₜ. The random effects estimator is a weighted combination of the within-group (fixed effects) and between-group estimators, with weights determined by the relative magnitudes of σ²_α and σ²_ε.

The critical assumption of the random effects model is that the unit effects αᵢ are uncorrelated with the explanatory variables. If this assumption is satisfied, random effects is more efficient than fixed effects (it uses both within and between variation). If the assumption is violated — as it typically is in health economics — random effects produces biased estimates, and fixed effects is preferred.

### The Hausman Test

The Hausman test compares the fixed effects and random effects estimators to assess whether the unit effects are correlated with the explanatory variables. Under the null hypothesis of no correlation (random effects is consistent and efficient), the fixed effects and random effects estimates should be similar. Under the alternative (random effects is inconsistent), the estimates will diverge. The test statistic is:

H = (β̂_FE - β̂_RE)' [V̂(β̂_FE) - V̂(β̂_RE)]⁻¹ (β̂_FE - β̂_RE) ~ χ²(k)

A significant Hausman test indicates that random effects is inconsistent due to correlation between unit effects and covariates, and fixed effects should be preferred. In practice, the Hausman test nearly always rejects random effects in health economics applications, and fixed effects is the default specification for panel data analyses.

### The Mundlak (Correlated Random Effects) Approach

The Mundlak (1978) approach offers a compromise between fixed and random effects by including the group means of time-varying covariates as additional regressors in the random effects model:

Yᵢₜ = β₀ + β₁Dᵢₜ + X'ᵢₜγ + X̄'ᵢδ + αᵢ + εᵢₜ

This specification allows the unit effects to be correlated with the covariates through the group means, while retaining the ability to estimate effects of time-invariant variables. The coefficient γ has the same interpretation as the fixed effects estimator (the within-unit effect), while δ captures the between-unit effect. The Mundlak approach is increasingly used in health economics because it combines the consistency of fixed effects with the ability to estimate effects of time-invariant covariates.

---

**Table 9.1: Summary of Estimation Methods for Health Economics**

| Method | Primary Application | Key Assumption | Health Economics Example |
|---|---|---|---|
| OLS with robust SE | Linear models, continuous outcomes | Conditional mean independence | Effect of income on health spending |
| Logit/Probit | Binary outcomes | Correct link function | Probability of hospitalization |
| GLM (gamma, log) | Positive healthcare costs | Correct mean and variance function | Medicare expenditure modeling |
| Two-part model | Expenditures with mass at zero | Parts are separable | Total annual healthcare spending |
| Fixed effects | Panel data with time-invariant confounders | Strict exogeneity within unit | Hospital payment reform effects |
| Random effects | Panel data with uncorrelated unit effects | Unit effects independent of covariates | Rarely appropriate in health econ |
| 2SLS/IV | Endogenous treatment | Valid instrument available | Effect of insurance on utilization |

---

## Conclusion

The econometric methods developed in this chapter — OLS with appropriate standard errors, MLE for nonlinear models, GLM for healthcare costs, two-part models for zero-inflated expenditures, and panel data methods for controlling unobserved heterogeneity — constitute the baseline toolkit of the empirical health economist. Each method addresses specific features of health economics data, and the choice among methods should be guided by the characteristics of the outcome variable (continuous, binary, count, censored), the structure of the data (cross-sectional, panel, clustered), and the nature of the identification challenge (selection on observables, selection on unobservables, time-invariant confounders).

However, these methods are generally insufficient to establish causality from observational data when treatment is endogenous. The quasi-experimental methods developed in the next three chapters — instrumental variables (Chapter 10), difference-in-differences (Chapter 11), and regression discontinuity (Chapter 12) — provide the identification strategies that enable causal inference in the presence of endogeneity. The specialized models of Chapters 13-14 extend the framework to the distinctive data types (counts, durations, discrete choices) that arise in healthcare utilization and provider choice analysis. And the Bayesian (Chapter 15), machine learning (Chapter 16), and structural (Chapter 17) approaches offer complementary perspectives on estimation, prediction, and policy counterfactual analysis.

The Julia implementations of every method discussed in this chapter are provided in Chapter 21, with complete code examples using simulated and real health economics datasets.

## References

1. Angrist, J. D., & Pischke, J.-S. (2009). *Mostly Harmless Econometrics: An Empiricist's Companion*. Princeton University Press.

2. Bertrand, M., Duflo, E., & Mullainathan, S. (2004). How much should we trust differences-in-differences estimates? *Quarterly Journal of Economics*, 119(1), 249-275.

3. Cameron, A. C., & Trivedi, P. K. (2005). *Microeconometrics: Methods and Applications*. Cambridge University Press.

4. Dow, W. H., & Norton, E. C. (2003). Choosing between and interpreting the Heckit and two-part models for corner solutions. *Health Services and Outcomes Research Methodology*, 4(1), 5-18.

5. Duan, N. (1983). Smearing estimate: A nonparametric retransformation method. *Journal of the American Statistical Association*, 78(383), 605-610.

6. Greene, W. H. (2018). *Econometric Analysis* (8th ed.). Pearson.

7. Heckman, J. J. (1979). Sample selection bias as a specification error. *Econometrica*, 47(1), 153-161.

8. Holland, P. W. (1986). Statistics and causal inference. *Journal of the American Statistical Association*, 81(396), 945-960.

9. Manning, W. G., & Mullahy, J. (2001). Estimating log models: To transform or not to transform? *Journal of Health Economics*, 20(4), 461-494.

10. Mundlak, Y. (1978). On the pooling of time series and cross section data. *Econometrica*, 46(1), 69-85.

11. Rubin, D. B. (1974). Estimating causal effects of treatments in randomized and nonrandomized studies. *Journal of Educational Psychology*, 66(5), 688-701.

12. Wooldridge, J. M. (2010). *Econometric Analysis of Cross Section and Panel Data* (2nd ed.). MIT Press.
