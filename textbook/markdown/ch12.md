# Chapter 12: Regression Discontinuity Design in Health Economics

## Introduction

Regression discontinuity design (RDD) exploits situations in which treatment assignment is determined — wholly or partly — by whether an observed variable (the running variable or forcing variable) crosses a known threshold. When individuals just above and just below the threshold are otherwise similar, the discontinuity in treatment at the threshold creates a local quasi-experiment that enables credible causal inference. The intuition is simple and powerful: if treatment assignment changes sharply at a cutoff while all other determinants of the outcome change smoothly through the cutoff, any discontinuity in the outcome at the cutoff can be attributed to the treatment.

Health economics offers a wealth of RDD applications because healthcare policy is replete with eligibility thresholds. Medicare eligibility at age 65 creates a sharp discontinuity in insurance coverage. Medicaid income thresholds determine coverage eligibility for low-income populations. Birth weight thresholds trigger NICU admission protocols and additional medical interventions. Hospital quality star ratings are assigned based on continuous composite scores crossing discrete cutoffs. Pay-for-performance programs reward or penalize providers based on whether quality metrics exceed target thresholds. Each of these thresholds creates a potential RDD, and the resulting estimates have produced some of the most credible causal evidence in health economics.

This chapter provides a comprehensive treatment of RDD for graduate health economics researchers. We develop the sharp and fuzzy RD designs, discuss estimation using local linear regression with optimal bandwidth selection, address validity testing, survey major health economics RDD applications, and introduce extensions including multi-cutoff designs, geographic RD, RD with discrete running variables, and the regression kink design. Mathematical derivations are provided for the key estimators, and detailed discussions of landmark health economics RDD papers illustrate methodological best practices.

## The Sharp Regression Discontinuity Design

### Setup and Identification

In the sharp RD design, treatment assignment is a deterministic function of the running variable crossing a threshold:

Dᵢ = 1{Xᵢ ≥ c}

where Dᵢ is the treatment indicator, Xᵢ is the running variable, and c is the cutoff. All individuals with Xᵢ ≥ c receive treatment; all individuals with Xᵢ < c do not. There is no partial compliance — treatment status switches from 0 to 1 exactly at the cutoff.

The RD assumption is that all potential confounders are continuous at the cutoff — no other variable relevant to the outcome changes discontinuously at c. Under this assumption, any discontinuity in the conditional expectation of the outcome at the cutoff is attributable to the treatment:

τ_RD = lim_{x↓c} E[Yᵢ | Xᵢ = x] - lim_{x↑c} E[Yᵢ | Xᵢ = x]

The RD estimand is a local average treatment effect at the cutoff — it identifies the effect of treatment for individuals with running variable values at or very near the threshold. This is both the strength and limitation of RDD: the estimate has very high internal validity (credible causal identification) but limited external validity (the effect at the cutoff may not generalize to individuals far from the cutoff).

### Local Randomization Interpretation

The RD design can be interpreted as a local randomized experiment in a neighborhood around the cutoff. If individuals cannot precisely manipulate their running variable to sort above or below the threshold, then among individuals very close to the cutoff, treatment assignment is effectively random. An individual with income at 99.5% of the poverty line and an individual at 100.5% are, in expectation, identical in all respects except that one qualifies for Medicaid and the other does not. Comparing outcomes between these nearly-identical individuals yields a credible causal estimate.

This local randomization interpretation provides the strongest intuitive justification for RDD and connects it to the experimental ideal. The key requirement is that individuals cannot precisely control their running variable — a condition called "no manipulation" — which is testable through the McCrary density test (discussed below).

## Estimation

### Local Linear Regression

The standard approach to RD estimation is local linear regression — fitting separate linear regressions on each side of the cutoff within a bandwidth h around the cutoff:

For observations with Xᵢ ∈ [c - h, c): Y = α_L + β_L(Xᵢ - c) + εᵢ
For observations with Xᵢ ∈ [c, c + h]: Y = α_R + β_R(Xᵢ - c) + εᵢ

The RD treatment effect estimate is τ̂ = α̂_R - α̂_L — the difference in intercepts at the cutoff. This is equivalent to a weighted least squares regression of Y on a treatment indicator D, the centered running variable (X - c), and their interaction, with a triangular or uniform kernel providing the weights:

Yᵢ = α + τDᵢ + β₁(Xᵢ - c) + β₂Dᵢ(Xᵢ - c) + εᵢ

estimated on observations with |Xᵢ - c| ≤ h, with kernel-based weights.

Local linear regression has two key advantages over higher-order polynomial specifications. First, it eliminates the boundary bias that affects local constant (Nadaraya-Watson) estimation at the cutoff — a critical concern because the RD estimate is inherently a boundary estimate. Second, it avoids the overfitting and instability problems associated with high-order global polynomial specifications, which Gelman and Imbens (2019) demonstrated can produce misleading RD estimates.

### Bandwidth Selection

The bandwidth h determines the window of data used for estimation and controls the bias-variance tradeoff. A smaller bandwidth reduces bias (because the linear approximation is more accurate in a narrow window) but increases variance (because fewer observations are used). A larger bandwidth reduces variance but increases bias.

**Imbens-Kalyanaraman (IK) optimal bandwidth.** Imbens and Kalyanaraman (2012) derived the asymptotically optimal bandwidth that minimizes the mean squared error of the RD estimator. The IK bandwidth balances the squared bias (which decreases with bandwidth at rate h⁴) against the variance (which decreases with bandwidth at rate 1/(nh)):

h_IK = C × n^(-1/5)

where C depends on the curvature of the conditional expectation function, the density of the running variable at the cutoff, and the conditional variance of the outcome.

**Calonico-Cattaneo-Titiunik (CCT) robust bandwidth.** Calonico, Cattaneo, and Titiunik (2014) proposed a bias-corrected RD estimator with robust confidence intervals that account for the estimation error in the bias correction. Their procedure selects two bandwidths: a main bandwidth for the point estimate and a pilot bandwidth for the bias correction. The CCT approach has become the standard implementation, available in the rdrobust software package (which has implementations in R, Stata, and Python; the Julia implementation is discussed in Chapter 21).

### Kernel Choice

The kernel function assigns weights to observations based on their distance from the cutoff. Common choices include:

**Triangular kernel**: K(u) = (1 - |u|) × 1{|u| ≤ 1}. Places maximum weight on observations at the cutoff and linearly declining weight on observations farther away. The triangular kernel is MSE-optimal for boundary estimation and is the default choice for RD.

**Uniform kernel**: K(u) = 0.5 × 1{|u| ≤ 1}. Assigns equal weight to all observations within the bandwidth. The uniform kernel is simpler but less efficient than the triangular kernel.

**Epanechnikov kernel**: K(u) = 0.75(1 - u²) × 1{|u| ≤ 1}. A compromise between triangular and uniform.

In practice, the choice of kernel has modest effects on RD estimates relative to the choice of bandwidth. The triangular kernel is the conventional default.

### The Dangers of High-Order Global Polynomials

Gelman and Imbens (2019) argued forcefully against the use of high-order global polynomial specifications in RD estimation — an approach that was common in earlier applied work. In this approach, the analyst fits a single polynomial regression of Y on X (and its interactions with D) using all data, relying on the polynomial to flexibly capture the relationship between X and Y.

The problems with global polynomials are threefold. First, high-order polynomials are sensitive to observations far from the cutoff, which should be irrelevant for the RD estimate but can substantially influence the polynomial fit at the cutoff. Second, high-order polynomials can generate overfitting and Runge's phenomenon (oscillation near the boundaries), producing spurious discontinuities. Third, the polynomial order is typically chosen without formal guidance, introducing researcher discretion that undermines the objectivity of the design.

The current consensus strongly favors local linear (or local quadratic) regression with data-driven bandwidth selection over global polynomial approaches.

## The Fuzzy Regression Discontinuity Design

### Partial Compliance at the Cutoff

In many health economics applications, crossing the threshold increases the probability of treatment but does not determine it perfectly. Medicare eligibility at age 65 sharply increases insurance coverage, but some individuals below 65 already have coverage (through employers, Medicaid, or the individual market), and a small number above 65 may remain uninsured. Medicaid income thresholds create eligibility, but not all eligible individuals enroll. These settings create a fuzzy RD design, in which the probability of treatment jumps at the cutoff but does not change from 0 to 1.

In the fuzzy RD:

E[Dᵢ | Xᵢ = c⁺] - E[Dᵢ | Xᵢ = c⁻] = π < 1

where π is the jump in the probability of treatment at the cutoff (the first-stage discontinuity).

### Fuzzy RD as IV

The fuzzy RD is econometrically equivalent to an IV analysis in which the instrument is the indicator 1{Xᵢ ≥ c} and the estimation is restricted to observations near the cutoff. The RD treatment effect is:

τ_FRD = [lim_{x↓c} E[Yᵢ | Xᵢ = x] - lim_{x↑c} E[Yᵢ | Xᵢ = x]] / [lim_{x↓c} E[Dᵢ | Xᵢ = x] - lim_{x↑c} E[Dᵢ | Xᵢ = x]]

This is the ratio of the reduced-form discontinuity in the outcome to the first-stage discontinuity in treatment — exactly the Wald/IV estimator applied locally at the cutoff. The estimate has a LATE interpretation: it identifies the average treatment effect for individuals whose treatment status is changed by crossing the threshold (the local compliers at the cutoff).

Implementation uses 2SLS within the bandwidth:

**First stage**: Dᵢ = π₀ + π₁ × 1{Xᵢ ≥ c} + f(Xᵢ - c) + εᵢ
**Second stage**: Yᵢ = β₀ + τ × D̂ᵢ + g(Xᵢ - c) + ηᵢ

where f(·) and g(·) are flexible functions of the running variable (typically local linear with separate slopes on each side of the cutoff).

## Validity Tests

### The McCrary Density Test

If individuals can precisely manipulate their running variable to sort above or below the cutoff, the local randomization interpretation of RD breaks down. The McCrary (2008) density test checks for manipulation by testing whether the density of the running variable is continuous at the cutoff. A discontinuity in the density — more observations bunching on one side — suggests manipulation.

The test estimates the density of X separately on each side of the cutoff using local polynomial density estimation, then tests whether the densities are equal at the cutoff. A significant McCrary test is a red flag for RD validity.

In health economics, manipulation is a concern for income-based thresholds (individuals may underreport income to qualify for Medicaid), but is typically not a concern for age-based thresholds (individuals cannot manipulate their age), clinical measurement thresholds (birth weight is measured, not chosen), or provider-level performance thresholds (individual providers have limited ability to precisely control their quality scores to cross specific cutoffs).

Cattaneo, Jansson, and Ma (2020) developed an improved density discontinuity test (the rddensity test) that uses local polynomial density estimation with robust bias-corrected inference, providing more reliable tests than the original McCrary approach.

### Covariate Balance at the Cutoff

If the RD design is valid, pre-determined covariates should be continuous at the cutoff — there should be no jumps in age, sex, race, baseline health status, or other variables that are determined before the running variable is realized. Testing for covariate balance at the cutoff provides a falsification test analogous to the covariate balance tests used in randomized experiments.

The test is implemented by running the RD estimation procedure with each pre-determined covariate as the dependent variable. If any covariate shows a statistically significant discontinuity at the cutoff, this suggests either manipulation or a violation of the smoothness assumption.

### Sensitivity to Bandwidth Choice

A credible RD estimate should be robust to reasonable variations in bandwidth. Standard practice is to report estimates at the optimal bandwidth and at bandwidths that are 50%, 75%, 125%, 150%, and 200% of the optimal bandwidth. If the estimate changes substantially with bandwidth, this suggests sensitivity to the functional form specification or to observations far from the cutoff, reducing confidence in the result.

### Donut-Hole RD

When manipulation is suspected but limited to observations very close to the cutoff, the donut-hole RD excludes observations within a small window around the cutoff (e.g., dropping observations with |X - c| < δ for some small δ) and estimates the RD from the remaining observations. If the estimate is similar with and without the donut, this suggests that any manipulation near the cutoff does not materially affect the results.

## RD Applications in Health Economics

### Medicare Eligibility at Age 65

The Card, Dobkin, and Maestas (2008, 2009) studies of Medicare eligibility represent the most influential RD application in health economics. The running variable is age, with the cutoff at exactly 65 years old. The first-stage discontinuity in insurance coverage at age 65 is dramatic: the fraction of Americans with health insurance jumps from approximately 85% just below age 65 to approximately 99% just above. This 14-percentage-point increase in coverage provides a strong first stage for the fuzzy RD.

The reduced-form estimates show sharp increases in hospital admissions, cardiac procedures, and other high-cost interventions at age 65, with the discontinuities concentrated among individuals who were previously uninsured. The fuzzy RD estimates (treatment effect of insurance coverage on utilization) imply large utilization effects: gaining Medicare coverage increases hospital admissions by approximately 20% and increases the probability of receiving cardiac interventions by approximately 10-15%.

The 2009 study examined mortality and found a small but statistically significant reduction in 7-day mortality for emergency admissions among patients just above age 65 relative to those just below, suggesting that the additional care enabled by Medicare coverage produces genuine health benefits for acute conditions.

The age-65 RD has subsequently been used to study a wide range of outcomes including prescription drug utilization, mental health service use, preventive care, diagnostic testing patterns, and labor supply effects of Medicare eligibility.

### Birth Weight Thresholds

Almond and colleagues (2010) exploited the administrative threshold of 1,500 grams (very low birth weight, VLBW) to study the effects of additional medical interventions on infant mortality. Newborns weighing just below 1,500 grams receive substantially more intensive medical care — longer NICU stays, more diagnostic testing, more specialist consultations — than newborns just above the threshold, reflecting clinical protocols and insurance reimbursement rules that are triggered by the VLBW classification.

The RD estimates show that the additional medical interventions induced by the 1,500-gram threshold reduce infant mortality by approximately 0.7 to 1.0 percentage points — a large effect relative to the baseline mortality rate for infants near this weight. The study provided compelling evidence that marginal medical interventions for vulnerable newborns are effective and potentially cost-effective.

The birth weight RD has been critiqued on the grounds that birth weight may be subject to measurement error (heaping at round numbers) and that the 1,500-gram threshold may trigger behavioral responses from providers that go beyond the discrete classification (e.g., differential recording of birth weight). Subsequent studies have addressed these concerns through donut-hole specifications and alternative bandwidth choices, with results that are generally robust.

### Hospital Quality Star Ratings

CMS's Hospital Star Ratings assign hospitals a summary quality score (1 to 5 stars) based on a continuous composite measure. Hospitals whose composite scores fall just above vs. just below a star rating cutoff are essentially identical in quality but receive different public ratings. This creates an RD design for studying the effects of public quality reporting on patient behavior (do patients respond to star ratings by choosing higher-rated hospitals?) and hospital behavior (do hospitals near a cutoff invest in quality improvement to achieve the higher rating?).

Studies using the star rating RD have found modest effects of star ratings on patient hospital choice — patients are somewhat more likely to choose hospitals with higher star ratings, but the effect is small relative to the influence of distance, physician referral patterns, and insurance network constraints.

### Pay-for-Performance Threshold Effects

P4P programs that reward or penalize providers based on whether performance metrics exceed a threshold create RD designs. The Hospital Readmissions Reduction Program (HRRP) penalizes hospitals with excess readmission ratios above 1.0 (worse than the national average after risk adjustment). Hospitals just above the threshold receive penalties; hospitals just below do not. The RD around this threshold can estimate whether the penalty regime induces differential quality improvement behavior.

Studies of P4P threshold effects have generally found small behavioral responses concentrated among hospitals near the threshold, consistent with the theoretical prediction that threshold-based incentives create strong motivation near the threshold but weak motivation for hospitals far from it.

## Extensions

### Multi-Cutoff and Multi-Score RD

Some settings involve multiple cutoffs applied to the same running variable, or multiple running variables with separate cutoffs. For example, income-based eligibility for different public programs may create multiple thresholds at different income levels. Hospitals may face quality thresholds for multiple pay-for-performance programs simultaneously.

Multi-cutoff RD pools data from multiple cutoffs to increase statistical power, under the assumption that the treatment effect at each cutoff is drawn from a common distribution. Cattaneo and colleagues (2016) formalized the multi-cutoff RD framework, providing methods for pooling estimates across cutoffs and testing for heterogeneity in treatment effects across cutoffs.

Multi-score RD arises when treatment is determined by the intersection of two or more running variables crossing their respective thresholds (e.g., income below threshold A and assets below threshold B). Estimation requires modeling the joint distribution of the running variables and identifying the treatment effect at the boundary of the eligibility region.

### RD with Discrete Running Variables

When the running variable takes on a small number of distinct values (e.g., age measured in years, hospital quality scores with limited precision), the standard RD asymptotics — which assume a continuous running variable — may not apply. Lee and Card (2008) analyzed this problem and proposed specification tests and inference procedures that account for the discrete nature of the running variable.

The practical concern is that with a discrete running variable, the local polynomial cannot be evaluated at the cutoff with increasing precision as the sample grows — the "bandwidth" is effectively fixed by the discreteness of the running variable. Lee and Card recommend clustering standard errors at the running variable value level and using a small number of distinct values on each side of the cutoff for estimation.

In health economics, age (measured in years or even months) is a common discrete running variable. The age-65 Medicare RD typically uses age measured in quarters or months to increase the effective resolution of the running variable, and clusters standard errors at the age level.

### The Regression Kink Design

The regression kink design (RKD), developed by Card, Lee, Pei, and Weber (2015), exploits discontinuities in the slope (rather than the level) of the relationship between a policy variable and a running variable. If a policy creates a kink (change in slope) in the treatment intensity at a threshold — such as a change in the marginal tax rate, a change in the cost-sharing schedule, or a change in the benefit formula — the RKD estimates the treatment effect as the ratio of the kink in the outcome to the kink in the treatment.

Formally, the RKD estimand is:

τ_RKD = [lim_{x↓c} dE[Y|X=x]/dx - lim_{x↑c} dE[Y|X=x]/dx] / [lim_{x↓c} dE[D|X=x]/dx - lim_{x↑c} dE[D|X=x]/dx]

RKD is applicable in health insurance settings where cost-sharing schedules create kinks. For example, the Medicare Part D coverage gap creates a kink in the out-of-pocket price schedule at the point where the gap begins — the marginal out-of-pocket cost jumps from approximately 25% to 100% of the drug price. The RKD at this kink can estimate the effect of the price change on prescription drug utilization, using the change in slope of utilization at the kink relative to the change in slope of the price.

RKD requires smoothness of all potential confounders through the kink point (analogous to the RD smoothness assumption) and no manipulation of the running variable at the kink. The estimation is more demanding than standard RD because it requires estimation of derivatives rather than levels, typically requiring larger samples for adequate precision.

---

**Key Concepts Box: RD Design Checklist**

| Validity Check | Method | Interpretation |
|---|---|---|
| No manipulation | McCrary/rddensity test | Continuous density at cutoff = no sorting |
| Covariate balance | RD with covariates as outcomes | No jumps in pre-determined variables |
| Bandwidth sensitivity | Multiple bandwidth estimates | Stable estimates across bandwidths |
| Placebo cutoffs | RD at non-threshold values | No effects at placebo cutoffs |
| Donut-hole | Exclude observations near cutoff | Robust to dropping potential manipulators |
| Visual inspection | RD plot with binned means + fit | Visible discontinuity at cutoff |

---

**Table 12.1: RD Applications in Health Economics**

| Study | Running Variable | Cutoff | Treatment | Key Finding |
|---|---|---|---|---|
| Card, Dobkin, Maestas (2008) | Age | 65 years | Medicare eligibility | Insurance ↑ 14pp; admissions ↑ 20% |
| Card, Dobkin, Maestas (2009) | Age | 65 years | Medicare eligibility | Small reduction in 7-day mortality |
| Almond et al. (2010) | Birth weight | 1,500g | VLBW classification → intensive NICU | Mortality ↓ 0.7-1.0pp from additional treatment |
| Barreca et al. (2011) | Birth weight | 1,500g | VLBW classification | Confirmed Almond; robust to heaping |
| Dafny & Gruber (2005) | Medicaid income | State thresholds | Medicaid eligibility | Coverage ↑; crowd-out of private insurance |
| CMS Star Ratings studies | Quality composite | Star cutoffs | Public quality rating | Modest patient choice effects |
| HRRP threshold studies | Readmission ratio | 1.0 | Financial penalty | Small behavioral response near threshold |

---

## Practical Implementation

### RD Plots

The RD plot — a scatter plot of the outcome against the running variable with fitted regression lines on each side of the cutoff — is the most important visual tool in RD analysis. Best practices for RD plots include:

**Binned scatter plots.** Rather than plotting individual observations (which may be too numerous or too noisy for visual interpretation), bin the running variable into narrow intervals and plot the mean outcome within each bin. The bin width should be narrow enough to reveal the shape of the relationship but wide enough to reduce noise. Calonico, Cattaneo, and Titiunik (2015) provided data-driven methods for optimal bin selection.

**Fitted lines.** Overlay the local linear (or local polynomial) regression fits on each side of the cutoff, using the selected bandwidth. The visual gap between the fitted lines at the cutoff represents the estimated treatment effect.

**Confidence intervals.** Display confidence bands around the fitted lines to convey the uncertainty of the estimates.

**Raw data range.** Show the full range of the running variable (not just the bandwidth window) to allow the reader to assess the global relationship between the running variable and the outcome.

### Reporting Standards

A well-reported RD analysis should include: the RD plot with binned means and fitted lines; the point estimate and confidence interval at the optimal bandwidth; sensitivity analysis across alternative bandwidths; McCrary density test results; covariate balance tests; the first-stage discontinuity (for fuzzy RD); placebo cutoff tests; and the effective sample size within the bandwidth.

## Conclusion

Regression discontinuity design offers some of the most credible causal estimates in observational health economics, achieving internal validity that approaches that of randomized experiments. The design's credibility derives from the transparency of the identification strategy — treatment assignment is determined by a known, observable threshold — and from the availability of direct validity tests (density tests, covariate balance, bandwidth sensitivity) that allow the researcher and reader to assess the plausibility of the identifying assumptions.

The limitations of RD are equally clear: the estimates are local to the cutoff (limiting external validity), the design requires a threshold-based treatment assignment (limiting applicability), and the estimates may be imprecise when the first-stage discontinuity is small (fuzzy RD) or the sample near the cutoff is limited. These limitations make RD a complement to, rather than a substitute for, the other quasi-experimental methods (IV, DiD) discussed in this textbook.

The Julia implementation of RD estimation — including local linear regression, CCT bandwidth selection, McCrary density tests, fuzzy RD via 2SLS, and RD plot generation — is provided in Chapter 21.

## References

1. Almond, D., Doyle, J. J., Kowalski, A. E., & Williams, H. (2010). Estimating marginal returns to medical care: Evidence from at-risk newborns. *Quarterly Journal of Economics*, 125(2), 591-634.

2. Calonico, S., Cattaneo, M. D., & Titiunik, R. (2014). Robust nonparametric confidence intervals for regression-discontinuity designs. *Econometrica*, 82(6), 2295-2326.

3. Calonico, S., Cattaneo, M. D., & Titiunik, R. (2015). Optimal data-driven regression discontinuity plots. *Journal of the American Statistical Association*, 110(512), 1753-1769.

4. Card, D., Dobkin, C., & Maestas, N. (2008). The impact of nearly universal insurance coverage on health care utilization: Evidence from Medicare. *American Economic Review*, 98(5), 2242-2258.

5. Card, D., Dobkin, C., & Maestas, N. (2009). Does Medicare save lives? *Quarterly Journal of Economics*, 124(2), 597-636.

6. Card, D., Lee, D. S., Pei, Z., & Weber, A. (2015). Inference on causal effects in a generalized regression kink design. *Econometrica*, 83(6), 2453-2483.

7. Cattaneo, M. D., Jansson, M., & Ma, X. (2020). Simple local polynomial density estimators. *Journal of the American Statistical Association*, 115(531), 1449-1455.

8. Cattaneo, M. D., Keele, L., Titiunik, R., & Vazquez-Bare, G. (2016). Interpreting regression discontinuity designs with multiple cutoffs. *Journal of Politics*, 78(4), 1229-1248.

9. Gelman, A., & Imbens, G. (2019). Why high-order polynomials should not be used in regression discontinuity designs. *Journal of Business and Economic Statistics*, 37(3), 447-456.

10. Imbens, G. W., & Kalyanaraman, K. (2012). Optimal bandwidth choice for the regression discontinuity estimator. *Review of Economic Studies*, 79(3), 933-959.

11. Lee, D. S., & Card, D. (2008). Regression discontinuity inference with specification error. *Journal of Econometrics*, 142(2), 655-674.

12. McCrary, J. (2008). Manipulation of the running variable in the regression discontinuity design: A density test. *Journal of Econometrics*, 142(2), 698-714.
