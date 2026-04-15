# Chapter 13: Count Data, Duration Models, and Healthcare Utilization

## Introduction

Healthcare utilization data present distinctive statistical challenges that standard linear regression cannot adequately address. Physician visits, hospitalizations, emergency department encounters, and prescription fills are count variables — non-negative integers with distributions that are right-skewed, overdispersed, and frequently exhibit excess zeros. Hospital length of stay, time to readmission, time to insurance enrollment, and duration of disability episodes are duration variables — non-negative continuous measures subject to censoring, with hazard rates that may change over time. Healthcare expenditures, as discussed in Chapter 9, combine a discrete mass at zero with a continuous right-skewed distribution for positive values.

Each of these data types requires specialized econometric models that respect the mathematical properties of the outcome variable while providing interpretable estimates of the effects of covariates. Using OLS on count data produces predicted values that can be negative, ignores the discrete nature of the outcome, and yields inefficient estimates when the variance structure departs from homoscedasticity. Using OLS on duration data ignores censoring and may produce biased estimates of hazard rates and survival probabilities. The models developed in this chapter — Poisson, negative binomial, zero-inflated, hurdle, Cox proportional hazards, and parametric survival — address these challenges with statistical frameworks designed specifically for the data structures that health economics research encounters.

This chapter provides a comprehensive treatment of count data and duration models for graduate health economics researchers. We derive each model from its distributional assumptions, discuss estimation and interpretation, provide guidance on model selection, and illustrate every method with healthcare applications. The Julia implementations are covered in Chapter 21.

## Count Data Models for Healthcare Utilization

### Poisson Regression

The Poisson regression model is the foundational count data model, derived from the assumption that the number of events (e.g., physician visits) follows a Poisson distribution conditional on covariates.

The Poisson probability mass function is:

Pr(Yᵢ = y | Xᵢ) = exp(-μᵢ) × μᵢʸ / y!

where μᵢ = E[Yᵢ | Xᵢ] = exp(X'ᵢβ) is the conditional mean, specified as an exponential function of the linear predictor to ensure non-negativity. The log-likelihood for a sample of n independent observations is:

ℓ(β) = Σᵢ [Yᵢ X'ᵢβ - exp(X'ᵢβ) - ln(Yᵢ!)]

The MLE β̂ solves the first-order conditions:

∂ℓ/∂β = Σᵢ (Yᵢ - exp(X'ᵢβ)) Xᵢ = 0

The Poisson model has the property of equidispersion: the conditional variance equals the conditional mean, Var(Yᵢ | Xᵢ) = μᵢ. This is a strong restriction that is frequently violated in healthcare data, where the variance typically exceeds the mean (overdispersion).

**Interpretation.** Coefficients in Poisson regression are interpreted as semi-elasticities of the conditional mean. For a continuous covariate xₖ:

∂E[Y | X] / ∂xₖ = βₖ × exp(X'β) = βₖ × μ

A one-unit increase in xₖ multiplies the expected count by exp(βₖ). For example, if β̂ = 0.15 for a binary indicator of chronic disease, having the chronic disease is associated with a exp(0.15) = 1.162 multiplicative increase in the expected number of visits — a 16.2% increase. This multiplicative interpretation is expressed as the incidence rate ratio (IRR): IRR = exp(βₖ).

**Robustness of Poisson MLE.** A remarkable property of the Poisson MLE, demonstrated by Gourieroux, Monfort, and Trognon (1984), is that it consistently estimates β even when the data are not Poisson-distributed, provided that the conditional mean is correctly specified as E[Y | X] = exp(X'β). This "quasi-MLE" or "pseudo-MLE" property means that Poisson regression with robust (sandwich) standard errors provides valid inference even under overdispersion or underdispersion, as long as the mean function is correct. This robustness result is the basis for the widespread use of Poisson regression in health economics, even when the equidispersion assumption is clearly violated.

### Negative Binomial Regression

When the data exhibit overdispersion (Var(Y | X) > E[Y | X]), the Poisson model's equidispersion assumption is violated, and the standard Poisson standard errors understate the true sampling variability. The negative binomial (NB) model accommodates overdispersion by introducing a latent heterogeneity term.

The NB model assumes that the conditional mean is:

μᵢ = exp(X'ᵢβ + εᵢ)

where exp(εᵢ) follows a gamma distribution with mean 1 and variance α. Integrating out the latent heterogeneity yields the negative binomial probability mass function:

Pr(Yᵢ = y | Xᵢ) = [Γ(y + 1/α) / (Γ(1/α) × y!)] × (1/(1 + αμᵢ))^(1/α) × (αμᵢ/(1 + αμᵢ))^y

The parameter α is the overdispersion parameter. When α = 0, the NB reduces to the Poisson. The conditional variance is:

**NB2 (Cameron and Trivedi)**: Var(Y | X) = μ + αμ² (variance is quadratic in mean)
**NB1**: Var(Y | X) = μ(1 + α) (variance is linear in mean)

The NB2 parameterization is the default in most software and is appropriate when overdispersion increases with the mean, which is the typical pattern in healthcare utilization data.

**Testing for overdispersion.** Cameron and Trivedi (1990) proposed a regression-based test for overdispersion in Poisson models. The test regresses (Yᵢ - μ̂ᵢ)² - Yᵢ on a function of μ̂ᵢ (typically μ̂ᵢ or μ̂ᵢ²) and tests whether the coefficient is significantly different from zero. A significant positive coefficient indicates overdispersion. Alternatively, the likelihood ratio test comparing the Poisson to the NB model (testing H₀: α = 0) provides a direct test, though the test is on the boundary of the parameter space (α ≥ 0), requiring a mixed chi-squared distribution for critical values.

### Zero-Inflated Models

Healthcare utilization data frequently exhibit excess zeros — more zero observations than the Poisson or negative binomial distributions predict. In a dataset of annual physician visits, some individuals have zero visits because they are healthy and had no need for care (structural zeros), while others had zero visits despite having healthcare needs because of access barriers, lack of insurance, or behavioral factors (sampling zeros). Standard count models treat all zeros as arising from the same process, potentially misspecifying the data-generating mechanism.

**Zero-inflated Poisson (ZIP).** The ZIP model assumes that the population consists of two latent groups: a "zero group" that always produces zeros (with probability πᵢ) and a "count group" that generates counts from a Poisson distribution (with probability 1 - πᵢ):

Pr(Yᵢ = 0) = πᵢ + (1 - πᵢ) × exp(-μᵢ)
Pr(Yᵢ = y) = (1 - πᵢ) × exp(-μᵢ) × μᵢʸ / y!  for y > 0

The zero-inflation probability πᵢ is modeled as a function of covariates through a logit (or probit) link:

logit(πᵢ) = Z'ᵢγ

where Zᵢ may include the same covariates as the count model or different covariates that specifically predict the zero-inflation process (e.g., insurance status may predict whether an individual is in the "never-visit" group).

**Zero-inflated negative binomial (ZINB).** The ZINB extends the ZIP by replacing the Poisson count process with a negative binomial, accommodating both excess zeros and overdispersion in the count process.

The ZIP and ZINB models are estimated by maximum likelihood. The log-likelihood is a mixture:

ℓ = Σᵢ {1(Yᵢ = 0) × ln[πᵢ + (1 - πᵢ) × f(0 | μᵢ)] + 1(Yᵢ > 0) × ln[(1 - πᵢ) × f(Yᵢ | μᵢ)]}

where f(· | μᵢ) is the Poisson or NB density.

### Hurdle Models

Hurdle models (also called two-part count models) provide an alternative to zero-inflated models for handling excess zeros. The hurdle model separates the data-generating process into two parts:

**Part 1 (the hurdle)**: A binary model (logit/probit) for whether the count is zero or positive.
**Part 2 (the count)**: A truncated-at-zero count model for the positive counts only.

The key difference between hurdle and zero-inflated models is conceptual. Zero-inflated models assume that zeros come from two sources (a structural zero process and the count process), while hurdle models assume that a single process determines whether the hurdle is crossed (any utilization), and a separate process determines the amount conditional on crossing the hurdle. In health economics, the hurdle model interpretation is often more natural: the decision to seek any care (the hurdle) may involve different factors than the number of visits conditional on initiating care.

The probability of a positive count in the hurdle model is:

Pr(Yᵢ = y | Yᵢ > 0) = f(y | μᵢ) / (1 - f(0 | μᵢ))  for y = 1, 2, 3, ...

where f(·) is the Poisson or NB density and the denominator normalizes the truncated distribution.

### Choosing Among Count Models

Selecting the appropriate count model requires assessing the features of the data:

**Equidispersion test.** If the Poisson equidispersion assumption is not rejected (rare in healthcare data), Poisson regression is adequate. If overdispersion is detected, NB is preferred.

**Vuong test for zero-inflation.** The Vuong (1989) test compares the fit of the standard model (Poisson or NB) against the zero-inflated version. A significant positive test statistic favors the zero-inflated model; a significant negative statistic favors the standard model.

**AIC/BIC comparison.** Information criteria provide model comparison across non-nested alternatives (e.g., hurdle vs. ZIP). Lower AIC or BIC values indicate better fit, penalized for complexity.

In practice, the NB model with robust standard errors is a reasonable default for healthcare count data, with zero-inflated or hurdle models reserved for situations where the proportion of zeros substantially exceeds the NB prediction and where the zero-generating process has a clear substantive interpretation.

---

**Key Concepts Box: Count Data Model Selection**

| Data Feature | Recommended Model | Rationale |
|---|---|---|
| Equidispersed counts | Poisson | Simplest adequate model |
| Overdispersed counts | Negative binomial (NB2) | Accommodates Var > Mean |
| Excess zeros + equidispersion | Zero-inflated Poisson (ZIP) | Two-process zero generation |
| Excess zeros + overdispersion | Zero-inflated NB (ZINB) | Handles both problems |
| Separate extensive/intensive decisions | Hurdle model | Different factors drive any-use vs. amount |
| Mean function correctly specified | Poisson with robust SE | Quasi-MLE consistency regardless of distribution |

---

## Healthcare Expenditure Models

### The Challenge of Skewness and Heteroscedasticity

As introduced in Chapter 9, healthcare expenditure distributions are characterized by a mass at zero, extreme right skewness (the top 5% of spenders account for approximately 50% of total expenditures), and heteroscedasticity (variance increases with predicted spending). This section extends the Chapter 9 discussion with additional detail on model comparison and the extended estimating equations approach.

### Retransformation Approaches Compared

When using log-OLS (Yᵢ = ln(expenditureᵢ)), predicted values on the original dollar scale require retransformation. Three approaches are available:

**Naive retransformation**: Ê[Y] = exp(X'β̂). This ignores Jensen's inequality and systematically underestimates the conditional mean.

**Duan's smearing estimator**: Ê[Y] = exp(X'β̂) × (1/n Σᵢ exp(ε̂ᵢ)). Valid under homoscedastic log-scale errors.

**Subgroup-specific smearing**: Compute smearing factors separately for subgroups (e.g., by age, sex, chronic condition status) when log-scale errors are heteroscedastic across subgroups.

Manning and Mullahy (2001) recommended comparing log-OLS with smearing against GLM using the Hosmer-Lemeshow-type goodness-of-fit test and the Pregibon link test. Their guidance was that neither approach dominates in all settings; the appropriate choice depends on the specific distributional properties of the data.

### The Extended Estimating Equations Approach

Basu and Rathouz (2005) developed the extended estimating equations (EEE) approach, which nests both the log-OLS and GLM approaches within a single framework. The EEE simultaneously estimates the link function parameter (the transformation of the conditional mean) and the variance function parameter (the relationship between variance and mean), allowing the data to determine the appropriate specification rather than imposing it a priori.

The EEE approach is computationally more demanding than standard GLM but provides a principled way to resolve the model selection problem. It is particularly useful when the researcher is uncertain whether log-OLS or GLM is more appropriate and wants to let the data determine the answer.

## Survival Analysis and Duration Models

### Fundamental Concepts

Duration data (also called survival data or time-to-event data) measure the time from a well-defined origin to the occurrence of an event of interest. In health economics, common applications include time from hospital discharge to readmission, time from diagnosis to treatment initiation, time from insurance enrollment to first healthcare utilization, duration of hospital stay, time on a medication before discontinuation, and time from diagnosis to death.

Duration data have two defining features that require specialized methods:

**Censoring.** Observations are censored when the event has not occurred by the end of the observation period. Right censoring (the most common form) occurs when follow-up ends before the event — the patient is still alive at the end of the study, the individual has not been readmitted by the end of the observation window, or the beneficiary is still enrolled in the insurance plan when the data are extracted. Ignoring censoring by dropping censored observations or by treating them as having experienced the event at the censoring time produces biased estimates.

**Non-negative support.** Duration variables are strictly non-negative, and their distributions are typically right-skewed. The normal distribution assumed by OLS is inappropriate.

### Hazard Functions

The hazard function h(t) is the instantaneous rate of event occurrence at time t, conditional on survival to time t:

h(t) = lim_{Δt→0} Pr(t ≤ T < t + Δt | T ≥ t) / Δt = f(t) / S(t)

where f(t) is the density function and S(t) = Pr(T ≥ t) = 1 - F(t) is the survival function.

The hazard function is the fundamental quantity in duration analysis because it directly models the risk of event occurrence as a function of time. Different hazard shapes have different clinical interpretations:

**Constant hazard**: h(t) = λ. The event rate is the same at all durations (memoryless property). Corresponds to the exponential distribution.

**Increasing hazard**: h(t) increases with t. Risk increases the longer the individual has been "at risk." Common for age-related mortality, device failure.

**Decreasing hazard**: h(t) decreases with t. Risk is highest initially and declines over time. Common for post-surgical mortality (highest risk immediately after surgery), infant mortality (highest in the first days of life).

**Non-monotonic hazard**: h(t) first increases then decreases, or vice versa. Common for some cancer types (initial treatment reduces risk, then risk increases as treatment effects wane).

The cumulative hazard function H(t) = ∫₀ᵗ h(s) ds is related to the survival function by S(t) = exp(-H(t)).

### Kaplan-Meier Estimation

The Kaplan-Meier (KM) estimator is the nonparametric maximum likelihood estimator of the survival function. At each observed event time tⱼ, the KM estimator updates the survival probability:

Ŝ(t) = Π_{tⱼ ≤ t} (1 - dⱼ / nⱼ)

where dⱼ is the number of events at time tⱼ and nⱼ is the number of individuals at risk just before tⱼ (including those who will be censored at tⱼ). The KM estimator produces a step function that decreases at each event time, with the step size proportional to the number of events relative to the number at risk.

The KM estimator properly handles censoring by removing censored observations from the risk set at the censoring time, thereby adjusting the denominator of the survival probability. The log-rank test provides a nonparametric comparison of KM survival curves between groups, testing the null hypothesis that the survival functions are identical.

In health economics, KM curves are used to visualize time-to-event distributions — survival after diagnosis, time to readmission, duration of insurance enrollment — and the log-rank test is used for unadjusted group comparisons (e.g., comparing readmission rates between hospitals, survival between treatment arms).

### Cox Proportional Hazards Model

The Cox proportional hazards (PH) model, introduced by Cox (1972), is the most widely used regression model for duration data. The Cox model specifies the hazard function as:

h(t | Xᵢ) = h₀(t) × exp(X'ᵢβ)

where h₀(t) is the baseline hazard function (the hazard for an individual with all covariates equal to zero) and exp(X'ᵢβ) is the relative hazard (hazard ratio) associated with the covariates.

The key feature of the Cox model is that the baseline hazard h₀(t) is left completely unspecified — it is treated as a nuisance function. This semiparametric approach avoids the need to assume a specific parametric form for the hazard function, providing robustness against misspecification of the time dependence.

**Partial likelihood estimation.** Cox showed that β can be estimated by maximizing the partial likelihood, which conditions on the observed event times and thereby eliminates the baseline hazard:

L(β) = Π_{j: uncensored} [exp(X'ⱼβ) / Σᵢ∈R(tⱼ) exp(X'ᵢβ)]

where the product is over all uncensored event times, and R(tⱼ) is the risk set at time tⱼ (all individuals still under observation at tⱼ). The partial likelihood depends only on β, not on h₀(t), enabling estimation of covariate effects without specifying the baseline hazard.

**Interpretation.** Coefficients in the Cox model are interpreted as log hazard ratios. The hazard ratio for a one-unit increase in covariate xₖ is HR = exp(βₖ). A hazard ratio greater than 1 indicates increased risk (shorter expected duration); a hazard ratio less than 1 indicates decreased risk (longer expected duration). For example, a hazard ratio of 1.35 for a comorbidity indicator means that individuals with the comorbidity have a 35% higher instantaneous risk of the event at any point in time.

**The proportional hazards assumption.** The Cox model assumes that hazard ratios are constant over time — the effect of covariates is to multiply the baseline hazard by a constant factor at all time points. This assumption can be tested using Schoenfeld residuals, the complementary log-log plot (plotting ln(-ln(S(t))) against ln(t) for each group — parallel curves support PH), or by including covariate-time interactions.

When the PH assumption is violated, several alternatives are available: stratified Cox models (which allow different baseline hazards for different strata), time-varying coefficients (interactions between covariates and functions of time), or parametric models that do not impose proportional hazards (e.g., the accelerated failure time family).

### Parametric Duration Models

Parametric survival models specify a distributional form for the survival time, providing a complete characterization of the hazard and survival functions. Common parametric families include:

**Exponential**: h(t) = λ. Constant hazard, memoryless. The simplest duration model, appropriate when the event rate does not depend on elapsed time. Rarely appropriate in health economics.

**Weibull**: h(t) = λp(λt)^(p-1). Allows monotonically increasing (p > 1) or decreasing (p < 1) hazards. Reduces to exponential when p = 1. Widely used in health economics because it accommodates duration dependence while remaining tractable.

**Log-normal**: The log of survival time follows a normal distribution. Produces a non-monotonic hazard (increasing then decreasing), which may be appropriate for some post-treatment survival outcomes.

**Generalized gamma**: Nests the exponential, Weibull, log-normal, and gamma as special cases. Provides a flexible family for testing distributional assumptions through nested model comparisons.

**Gompertz**: h(t) = λ exp(γt). The hazard is exponentially increasing (when γ > 0), which closely approximates adult human mortality patterns (the Gompertz-Makeham law of mortality). Widely used in actuarial science and in health economics studies of mortality.

Parametric models can be estimated by maximum likelihood, incorporating censoring through the survival function:

ℓ(θ) = Σᵢ [δᵢ × ln f(tᵢ | Xᵢ, θ) + (1 - δᵢ) × ln S(tᵢ | Xᵢ, θ)]

where δᵢ is the event indicator (1 = event observed, 0 = censored).

### Accelerated Failure Time Interpretation

Parametric models can be expressed in the accelerated failure time (AFT) framework:

ln(Tᵢ) = X'ᵢβ + σεᵢ

where εᵢ follows a specified distribution (extreme value for Weibull, standard normal for log-normal, generalized extreme value for generalized gamma). The AFT interpretation is that covariates accelerate or decelerate the time to event: a coefficient βₖ > 0 means the covariate extends the expected survival time (decelerates failure), while βₖ < 0 means the covariate shortens survival (accelerates failure).

The AFT interpretation is often more intuitive than the hazard ratio interpretation in health economics: a medication that "extends survival by 30%" is more meaningful to patients and clinicians than one that "reduces the hazard by 25%."

### Competing Risks

In many health economics applications, individuals are at risk of multiple types of events that compete with each other. A hospitalized patient may be discharged to home, discharged to a skilled nursing facility, or die — these are competing events, and the occurrence of one precludes the occurrence of the others. A beneficiary may disenroll from an insurance plan due to employment change, eligibility loss, or death.

The standard Kaplan-Meier estimator treats competing events as censoring, which overstates the cumulative incidence of any single event type (because it assumes that censored individuals remain at risk). The cumulative incidence function (CIF), estimated by the Aalen-Johansen estimator, properly accounts for competing risks by tracking the probability of each event type as a function of time.

Regression models for competing risks include the Fine-Gray subdistribution hazard model, which directly models the cumulative incidence, and cause-specific hazard models, which fit separate Cox models for each event type, treating competing events as censoring.

### Recurrent Event Analysis

Many healthcare events are recurrent — patients may experience multiple hospitalizations, multiple ED visits, or multiple exacerbations of a chronic condition. Standard survival analysis assumes a single event per individual and is not directly applicable to recurrent events.

The Andersen-Gill (AG) extension of the Cox model handles recurrent events by treating each event as a separate observation, with the risk set for each event including all individuals currently at risk:

h(t | Xᵢ, history) = h₀(t) × exp(X'ᵢβ)

The AG model assumes that event history does not affect future event risk (the conditional independence assumption). When this assumption is violated — as is often the case in healthcare, where prior hospitalizations predict future hospitalizations — frailty models provide an alternative.

**Frailty models** introduce a random effect (frailty) that captures unobserved heterogeneity in event risk across individuals:

h(t | Xᵢ, ωᵢ) = ωᵢ × h₀(t) × exp(X'ᵢβ)

where ωᵢ is the frailty for individual i, typically assumed to follow a gamma or log-normal distribution. The frailty induces within-individual correlation among recurrent events and captures the tendency of some individuals to be persistently high-utilizers.

---

**Table 13.1: Duration Model Selection Guide**

| Setting | Recommended Model | Rationale |
|---|---|---|
| No distributional assumption needed | Cox PH | Semiparametric; baseline hazard unspecified |
| Monotonic hazard, known direction | Weibull | Flexible monotonic hazard; nests exponential |
| Non-monotonic hazard | Log-normal or generalized gamma | Accommodates increasing-then-decreasing hazard |
| Adult mortality | Gompertz | Exponentially increasing hazard matches human mortality |
| Multiple event types | Fine-Gray or cause-specific Cox | Competing risks handled properly |
| Repeated events | Andersen-Gill or frailty model | Recurrent event framework |
| PH assumption violated | Stratified Cox or AFT | Relaxes constant hazard ratio |

---

## Applications in Health Economics

### Modeling Hospital Readmission Rates

Hospital readmission is a count (number of readmissions within 30 or 90 days) or a duration (time to first readmission). The count approach uses Poisson or NB regression with patient and hospital characteristics as covariates. The duration approach uses Cox PH or parametric survival models with the same covariates. Both approaches yield substantively similar conclusions about the effects of patient risk factors and hospital characteristics on readmission, but the duration approach provides additional information about the timing of readmission events.

CMS's Hospital Readmissions Reduction Program uses hierarchical generalized linear models (essentially mixed-effects logistic regression with hospital random effects) to estimate risk-standardized readmission rates, combining patient-level risk adjustment with hospital-level shrinkage estimation.

### Length of Stay Analysis

Hospital length of stay (LOS) is a count variable (measured in days) or a continuous duration variable (measured in hours or fractional days). LOS analysis typically uses one of three approaches: NB regression on the count of days, log-OLS or GLM on continuous LOS, or survival analysis treating discharge as the event and modeling the hazard of discharge as a function of patient and hospital characteristics.

The survival approach has the advantage of handling censoring (patients transferred or who die before discharge) and accommodating time-varying covariates (clinical status changes during hospitalization). Competing risks models are appropriate when discharge destination matters (home vs. SNF vs. death).

### Prescription Refill Patterns and Medication Adherence

Medication adherence is commonly measured using pharmacy claims data through metrics such as the proportion of days covered (PDC) or the medication possession ratio (MPR). Duration models can analyze the time to first gap in medication supply, the time to discontinuation, or the duration of continuous therapy.

The recurrent event framework is particularly useful for medications with intermittent adherence patterns — the Andersen-Gill model can estimate the hazard of a coverage gap at any point during therapy, accounting for patient characteristics and the accumulation of prior gaps.

## Conclusion

The specialized models developed in this chapter — Poisson and negative binomial regression for counts, zero-inflated and hurdle models for excess zeros, Kaplan-Meier and Cox proportional hazards for durations, parametric survival models for specific hazard shapes, and recurrent event models for repeated healthcare encounters — constitute the statistical toolkit for analyzing healthcare utilization data. Each model addresses specific features of the data, and the choice among models should be guided by the distributional properties of the outcome, the substantive interpretation of the generating process, and the specific research question.

The unifying theme is that healthcare utilization data have distinctive statistical properties — non-negativity, discreteness, skewness, censoring, excess zeros, and recurrence — that require models tailored to these properties. Standard linear regression, while convenient, can produce misleading results when applied to data that violate its assumptions. The models in this chapter provide the tools for rigorous analysis of the utilization data that are central to health economics research.

The Julia implementations of all models discussed in this chapter — including Poisson, NB, ZIP, ZINB, hurdle, Cox PH, Weibull, and frailty models — are provided in Chapter 21.

## References

1. Andersen, P. K., & Gill, R. D. (1982). Cox's regression model for counting processes: A large sample study. *Annals of Statistics*, 10(4), 1100-1120.

2. Basu, A., & Rathouz, P. J. (2005). Estimating marginal and incremental effects on health outcomes using flexible link and variance function models. *Biostatistics*, 6(1), 93-109.

3. Cameron, A. C., & Trivedi, P. K. (1986). Econometric models based on count data: Comparisons and applications of some estimators and tests. *Journal of Applied Econometrics*, 1(1), 29-53.

4. Cameron, A. C., & Trivedi, P. K. (1990). Regression-based tests for overdispersion in the Poisson model. *Journal of Econometrics*, 46(3), 347-364.

5. Cameron, A. C., & Trivedi, P. K. (2013). *Regression Analysis of Count Data* (2nd ed.). Cambridge University Press.

6. Cox, D. R. (1972). Regression models and life-tables. *Journal of the Royal Statistical Society: Series B*, 34(2), 187-220.

7. Duan, N. (1983). Smearing estimate: A nonparametric retransformation method. *Journal of the American Statistical Association*, 78(383), 605-610.

8. Fine, J. P., & Gray, R. J. (1999). A proportional hazards model for the subdistribution of a competing risk. *Journal of the American Statistical Association*, 94(446), 496-509.

9. Gourieroux, C., Monfort, A., & Trognon, A. (1984). Pseudo maximum likelihood methods: Theory. *Econometrica*, 52(3), 681-700.

10. Manning, W. G., & Mullahy, J. (2001). Estimating log models: To transform or not to transform? *Journal of Health Economics*, 20(4), 461-494.

11. Mullahy, J. (1986). Specification and testing of some modified count data models. *Journal of Econometrics*, 33(3), 341-365.

12. Vuong, Q. H. (1989). Likelihood ratio tests for model selection and non-nested hypotheses. *Econometrica*, 57(2), 307-333.
