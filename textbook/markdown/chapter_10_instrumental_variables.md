# Chapter 10: Instrumental Variables and Natural Experiments in Health Economics

## Introduction

Instrumental variables estimation is the primary econometric strategy for addressing endogeneity — the correlation between a treatment variable and the unobserved determinants of the outcome — in observational health economics research. When randomized experiments are infeasible and the treatment of interest is endogenous, IV methods exploit exogenous variation in a variable (the instrument) that affects the outcome only through its effect on the treatment, thereby isolating the causal component of the treatment-outcome relationship from the confounding component.

The IV approach has generated some of the most influential findings in health economics. McClellan, McNeil, and Newhouse (1994) used distance to a catheterization-capable hospital as an instrument for receipt of cardiac catheterization, establishing the canonical application of IV in clinical effectiveness research. Card, Dobkin, and Maestas (2008, 2009) exploited the Medicare eligibility discontinuity at age 65 as a natural experiment to estimate the effects of near-universal insurance on utilization and health outcomes. Finkelstein and colleagues used the Oregon Medicaid lottery as an instrument for Medicaid coverage. In each case, the key methodological insight was the identification of a source of exogenous variation in the treatment that could be used to overcome the selection bias inherent in observational comparisons.

This chapter provides a comprehensive treatment of IV methods for graduate health economics researchers. We develop the IV framework from first principles, derive the two-stage least squares estimator, introduce the local average treatment effect (LATE) interpretation, discuss instrument validity testing, survey classic IV applications in health economics, introduce shift-share instruments and fuzzy regression discontinuity as IV, and provide practical guidance on arguing for instrument validity in applied research. Mathematical derivations are provided for key results, and detailed walkthroughs of seminal health economics IV papers illustrate the methodology in practice.

## The Instrumental Variables Framework

### Motivation from Endogeneity

Consider the structural equation of interest:

Yᵢ = β₀ + β₁Dᵢ + X'ᵢγ + εᵢ

where Yᵢ is the outcome, Dᵢ is the endogenous treatment, Xᵢ is a vector of exogenous covariates, and εᵢ is the structural error. The OLS estimator of β₁ is biased and inconsistent if Cov(Dᵢ, εᵢ) ≠ 0 — that is, if the treatment is correlated with unobserved determinants of the outcome.

An instrumental variable Zᵢ resolves this problem by providing a source of variation in Dᵢ that is uncorrelated with εᵢ. Formally, a valid instrument satisfies two conditions:

**Relevance**: Cov(Zᵢ, Dᵢ) ≠ 0. The instrument must be correlated with the endogenous treatment. This condition is testable from the data.

**Exogeneity (exclusion restriction)**: Cov(Zᵢ, εᵢ) = 0. The instrument must be uncorrelated with the structural error — it affects the outcome only through its effect on the treatment. This condition is fundamentally untestable because εᵢ is unobservable, and must be argued on theoretical grounds.

### The Wald Estimator

In the simplest case — a binary instrument Z ∈ {0, 1} and a binary treatment D ∈ {0, 1} — the IV estimator reduces to the Wald estimator:

β̂_IV = [E(Y | Z = 1) - E(Y | Z = 0)] / [E(D | Z = 1) - E(D | Z = 0)]

The numerator is the reduced-form effect of the instrument on the outcome. The denominator is the first-stage effect of the instrument on the treatment. The ratio — reduced form divided by first stage — isolates the causal effect of the treatment on the outcome, using only the variation in treatment that is induced by the instrument.

The intuition is straightforward. The instrument creates exogenous variation in the treatment. Some individuals are induced to change their treatment status by the instrument (the "compliers"), while others are not affected (the "always-takers" and "never-takers"). The Wald estimator scales the reduced-form effect (which averages across all individuals) by the compliance rate (the fraction of individuals whose treatment status is changed by the instrument), yielding the causal effect for the compliers.

### Two-Stage Least Squares

The two-stage least squares (2SLS) estimator generalizes the Wald estimator to continuous instruments, multiple instruments, and models with covariates.

**First stage**: Regress the endogenous treatment on the instrument(s) and covariates:

Dᵢ = π₀ + π₁Zᵢ + X'ᵢπ₂ + vᵢ

**Second stage**: Replace the endogenous treatment with its first-stage predicted value D̂ᵢ and estimate the structural equation:

Yᵢ = β₀ + β₁D̂ᵢ + X'ᵢγ + ηᵢ

The 2SLS estimator uses only the variation in D that is predicted by Z — the exogenous component — to estimate β₁. Variation in D that is due to selection (the endogenous component) is absorbed into the first-stage residual vᵢ and does not contaminate the second-stage estimate.

The matrix formula for the 2SLS estimator is:

β̂_2SLS = (X̃'P_Z X̃)⁻¹ X̃'P_Z Y

where X̃ = [D X] is the matrix of endogenous and exogenous regressors, and P_Z = Z(Z'Z)⁻¹Z' is the projection matrix onto the instrument space. Standard errors for the second stage must be computed using the original (not predicted) values of D, as using D̂ would understate the true standard errors.

### Derivation of Consistency

The consistency of the IV estimator can be demonstrated using the moment conditions. Under the assumptions that E[Zᵢεᵢ] = 0 (instrument exogeneity) and E[ZᵢDᵢ] ≠ 0 (instrument relevance), the IV estimator is:

β̂_IV = (Z'D)⁻¹Z'Y = (Z'D)⁻¹Z'(Dβ₁ + ε) = β₁ + (Z'D)⁻¹Z'ε

Taking probability limits:

plim β̂_IV = β₁ + Cov(Z, ε) / Cov(Z, D) = β₁ + 0 / Cov(Z, D) = β₁

The IV estimator is consistent because the numerator of the bias term, Cov(Z, ε), is zero by the exogeneity assumption. Note that if the instrument is weak (Cov(Z, D) is small), the denominator approaches zero and the estimator becomes imprecise, with finite-sample bias toward the OLS estimate.

## The Local Average Treatment Effect

### Compliers, Always-Takers, Never-Takers, and Defiers

Imbens and Angrist (1994) provided the definitive interpretation of the IV estimator in the context of heterogeneous treatment effects. When the treatment effect varies across individuals (β₁ᵢ rather than a constant β₁), the IV estimator does not identify the average treatment effect (ATE) for the entire population. Instead, it identifies the local average treatment effect (LATE) — the average treatment effect for the subpopulation of "compliers" whose treatment status is changed by the instrument.

To formalize this, Imbens and Angrist defined four types of individuals based on their potential treatment status under different instrument values:

**Compliers**: Dᵢ(Z = 1) = 1, Dᵢ(Z = 0) = 0. Individuals who are treated when the instrument takes its "encouragement" value and untreated when it takes its "discouragement" value. These are the individuals whose behavior is actually changed by the instrument.

**Always-takers**: Dᵢ(Z = 1) = 1, Dᵢ(Z = 0) = 1. Individuals who are treated regardless of the instrument value. The instrument does not affect their treatment status.

**Never-takers**: Dᵢ(Z = 1) = 0, Dᵢ(Z = 0) = 0. Individuals who are never treated regardless of the instrument value.

**Defiers**: Dᵢ(Z = 1) = 0, Dᵢ(Z = 0) = 1. Individuals who do the opposite of what the instrument "encourages." Defiers are ruled out by the monotonicity assumption.

### The Monotonicity Assumption

The LATE interpretation requires the monotonicity assumption: the instrument affects all individuals' treatment probability in the same direction. Formally, either Dᵢ(Z = 1) ≥ Dᵢ(Z = 0) for all i (the instrument weakly increases treatment for everyone) or Dᵢ(Z = 1) ≤ Dᵢ(Z = 0) for all i (the instrument weakly decreases treatment for everyone). Monotonicity rules out defiers and ensures that the first-stage effect is non-negative for all individuals.

In health economics, monotonicity is often plausible. Living closer to a catheterization hospital cannot make anyone less likely to receive catheterization (McClellan et al., 1994). Being offered Medicaid through the Oregon lottery cannot make anyone less likely to have Medicaid. Reaching age 65 cannot make anyone less likely to have Medicare. In each case, the instrument operates in one direction for all individuals, satisfying monotonicity.

### LATE vs. ATE: Implications for Policy

The LATE is the average treatment effect for compliers — a subpopulation defined by the instrument. This creates two challenges for policy interpretation.

First, the complier population is not directly observable. We cannot identify which individuals in the data are compliers, always-takers, or never-takers; we can only estimate the proportions. The characteristics of compliers can be partially identified through comparisons of the first-stage effect across subgroups, but the complier population remains a statistical construct rather than a directly observable group.

Second, the LATE may differ from the ATE or the ATT if treatment effect heterogeneity is correlated with compliance behavior. Individuals who are induced to change treatment by a marginal instrument (e.g., living slightly closer to a hospital) may have different treatment effects than individuals who are always-takers (e.g., those who seek treatment regardless of distance) or never-takers (e.g., those who refuse treatment regardless of access). The policy relevance of the LATE depends on whether the policy being evaluated affects a population similar to the complier population.

For the Oregon Medicaid experiment, the LATE is the effect of Medicaid on individuals who enrolled because they won the lottery — a population that may differ from individuals who would have enrolled under an automatic enrollment policy or a mandate. For the age-65 Medicare discontinuity, the LATE is the effect of Medicare on individuals who gain insurance at age 65 — which is nearly the entire population, making the LATE close to the ATE.

## Testing Instrument Validity

### First-Stage F-Statistic and Weak Instruments

The relevance condition is testable through the first-stage regression. The conventional diagnostic is the F-statistic for the excluded instrument(s) in the first-stage regression. Staiger and Stock (1997) proposed the rule of thumb that the first-stage F-statistic should exceed 10 to avoid significant weak instrument bias. With a first-stage F below 10, the 2SLS estimator is biased toward the OLS estimate, and standard confidence intervals have poor coverage properties.

Stock and Yogo (2005) provided formal critical values for the weak instrument test based on the acceptable level of bias or size distortion. For a single endogenous regressor with one instrument, the critical value for 10% maximal bias relative to OLS is 16.38 — substantially more stringent than the "rule of 10."

When instruments are weak, several remedies are available. The Anderson-Rubin (AR) test provides valid inference regardless of instrument strength by testing the null hypothesis that the structural coefficient equals a specific value, constructing a confidence set by inverting the AR test. The conditional likelihood ratio (CLR) test of Moreira (2003) offers higher power than the AR test. Limited information maximum likelihood (LIML) estimation is more robust to weak instruments than 2SLS, though it can have heavier-tailed distributions.

### Over-Identification Tests

When the number of instruments exceeds the number of endogenous regressors (the model is over-identified), the Sargan-Hansen J-test can assess instrument validity. The J-statistic tests the null hypothesis that all instruments are exogenous:

J = n × R² from regression of 2SLS residuals on all instruments and exogenous covariates

Under the null, J ~ χ²(m - k), where m is the number of instruments and k is the number of endogenous regressors.

A significant J-statistic indicates that at least one instrument is invalid — correlated with the structural error. However, the test has limited power and cannot identify which instrument is invalid. Moreover, it tests a joint hypothesis: if all instruments are invalid (but correlated with each other), the J-test may fail to reject. The J-test is therefore a necessary but not sufficient condition for instrument validity.

### Falsification Tests

Because the exclusion restriction is fundamentally untestable, researchers rely on indirect evidence — falsification tests — to support instrument validity:

**Covariate balance.** If the instrument is as-good-as-random, it should be uncorrelated with observable covariates. Testing whether the instrument predicts pre-treatment covariates (age, sex, baseline health status, socioeconomic characteristics) provides indirect evidence on whether the instrument might be correlated with unobservable confounders.

**Placebo outcomes.** Testing whether the instrument predicts outcomes that should not be affected by the treatment provides a falsification test. If distance to a catheterization hospital predicts cardiac outcomes (plausible, through the treatment channel) but also predicts non-cardiac outcomes (implausible, unless the instrument is correlated with confounders), the exclusion restriction is called into question.

**Reduced-form stability.** The reduced-form effect of the instrument on the outcome should be robust to the inclusion of additional covariates. If the reduced-form estimate changes substantially when covariates are added, this suggests that the instrument is correlated with confounders that the covariates partially capture.

## Classic IV Applications in Health Economics

### Distance as Instrument: McClellan, McNeil, and Newhouse (1994)

The McClellan, McNeil, and Newhouse (1994) study of cardiac catheterization is the canonical IV application in health economics. The research question was whether intensive treatment of acute myocardial infarction (cardiac catheterization within 90 days of admission) improves survival relative to conservative management.

Naive comparison of outcomes between catheterized and non-catheterized patients is confounded by selection: catheterization is more likely to be performed on patients with favorable anatomy (treatable lesions) and better overall health status, creating a positive selection bias that makes catheterization appear more beneficial than it truly is.

McClellan and colleagues used differential distance — the distance from the patient's residence to the nearest catheterization hospital minus the distance to the nearest non-catheterization hospital — as an instrument for catheterization receipt. The identifying assumption is that differential distance affects the probability of catheterization (patients closer to catheterization hospitals are more likely to receive the procedure) but does not directly affect cardiac outcomes (after controlling for observable patient characteristics).

The first stage was strong: patients living closer to catheterization hospitals were substantially more likely to receive catheterization. The IV estimate of the effect of catheterization on survival was smaller and statistically insignificant, suggesting that the OLS estimate was upwardly biased by selection and that the causal benefit of catheterization for the marginal patient (the LATE for compliers — patients whose catheterization status was changed by proximity) was modest.

The exclusion restriction has been debated. If patients living closer to catheterization hospitals are systematically different in unobservable ways (e.g., living in areas with better overall healthcare infrastructure), differential distance may be correlated with the structural error, violating the exclusion restriction. McClellan and colleagues addressed this concern by controlling for a rich set of patient and area characteristics and by conducting falsification tests, but the exclusion restriction ultimately rests on a judgment about the plausibility of the identifying assumption.

### The Oregon Medicaid Lottery

The Oregon Health Insurance Experiment (discussed in Chapter 2) used lottery selection for Medicaid eligibility as an instrument for Medicaid enrollment. The lottery provides an unusually clean instrument because selection is genuinely random, satisfying the exclusion restriction by design.

The first stage is the effect of winning the lottery on Medicaid enrollment. Not all lottery winners enrolled in Medicaid (some were found ineligible, some did not complete the application process), so the lottery is an imperfect instrument — creating a fuzzy first stage with compliance well below 100%. The first-stage F-statistic was very large (exceeding 100), ruling out weak instrument concerns.

The IV estimates — the LATE for individuals who enrolled in Medicaid because they won the lottery — showed increased utilization, improved financial protection, improved mental health, and no statistically significant improvement in measured physical health outcomes at two years. The complier population (individuals who enrolled when selected but would not have enrolled otherwise) is broadly representative of the low-income uninsured population eligible for the program, making the LATE particularly policy-relevant.

### Medicare Eligibility at Age 65

Card, Dobkin, and Maestas (2008, 2009) exploited the sharp increase in insurance coverage at age 65 — when Americans become eligible for Medicare — as a natural experiment to estimate the effects of insurance on healthcare utilization and health outcomes. This design is a regression discontinuity (covered in depth in Chapter 12) but can also be interpreted as an IV analysis, with age-65 eligibility as the instrument for insurance coverage.

The first stage is dramatic: insurance coverage jumps from approximately 85% just below age 65 to approximately 99% just above age 65. The IV estimates (fuzzy RD estimates, which are equivalent to LATE for individuals who gain coverage at 65) show sharp increases in hospital admissions and procedures at age 65, with reductions in out-of-pocket spending and improvements in self-reported health.

### Physician Preference as Instrument

A more recent development in health economics IV research is the use of physician preference — the tendency of a physician to favor one treatment over another, independent of patient characteristics — as an instrument for treatment receipt. The logic is that patients assigned to (or cared for by) a physician with a strong preference for treatment A are more likely to receive treatment A, and this preference-based variation is plausibly exogenous to individual patient outcomes if physician assignment is not based on patient-specific factors.

Brookhart and colleagues (2006) formalized the physician preference instrument in the context of comparative effectiveness research, using it to compare the effects of COX-2 inhibitors versus non-selective NSAIDs. The approach has since been applied to a wide range of treatment comparisons, including surgical vs. medical management of various conditions.

The exclusion restriction for the physician preference instrument requires that physician preference affects outcomes only through its effect on treatment choice — not through other channels (e.g., physicians who prefer one treatment may also differ in skill, experience, or other prescribing patterns). This assumption is more plausible in settings where physician assignment is quasi-random (e.g., emergency departments with rotating on-call schedules) than in settings where patients select physicians based on reputation or specialty.

## Shift-Share Instruments in Health Economics

### Construction and Recent Debates

Shift-share (Bartik) instruments exploit the interaction between local industry composition (the "shares") and national industry-specific shocks (the "shifts") to generate predicted variation in local economic conditions. In health economics, the approach has been applied to study the effects of local economic conditions on health outcomes, healthcare spending, and insurance coverage.

The generic shift-share instrument for area j is:

B_j = Σ_k s_jk × g_k

where s_jk is the share of industry k in area j's economy (measured at baseline) and g_k is the national growth rate of industry k (excluding area j). The instrument varies across areas because of differences in baseline industry composition (the shares), even though the national shocks (the shifts) are common.

Recent econometric work has scrutinized the identification assumptions underlying shift-share instruments. Goldsmith-Pinkham, Sorkin, and Swift (2020) showed that the identifying variation in shift-share instruments comes from the shares (not the shifts), and that exogeneity of the shares is the relevant assumption. Borusyak, Hull, and Jaravel (2022) showed that under an alternative assumption — exogeneity of the shocks — the instrument is valid even if the shares are endogenous, provided the number of shocks is large.

For health economics applications, the choice between the "shares" and "shocks" identification strategies depends on the specific research design. When using variation in healthcare workforce composition across areas, the shares approach requires that baseline workforce composition is unrelated to unobserved determinants of outcomes. When using national policy shocks that differentially affect areas based on pre-existing characteristics, the shocks approach requires that the policy shocks are exogenous.

## Practical Guidance for Applied IV Research

### How to Argue for Instrument Validity

The exclusion restriction — the assumption that the instrument affects the outcome only through the treatment — is the most critical and most controversial assumption in IV research. Because it is untestable, convincing the reader that the exclusion restriction holds requires a combination of theoretical argument, institutional knowledge, and empirical evidence.

**Theoretical argument.** Articulate a clear causal pathway from the instrument to the treatment, and explain why there is no plausible direct pathway from the instrument to the outcome (other than through the treatment). The argument should address specific potential violations and explain why they are unlikely.

**Institutional knowledge.** Describe the institutional features that generate the instrument's variation. For natural experiments (lottery, policy discontinuity, eligibility threshold), explain the institutional mechanism that makes the assignment plausibly exogenous. For constructed instruments (distance, physician preference, shift-share), explain why the source of variation is independent of the outcome determinants.

**Empirical evidence.** Present falsification tests (covariate balance, placebo outcomes, reduced-form stability) that support the exclusion restriction. While no single test can prove the assumption, a preponderance of supporting evidence increases credibility.

**Robustness.** Show that the IV estimate is robust to alternative specifications (different sets of covariates, different functional forms, different definitions of the instrument). If the estimate changes substantially with reasonable specification changes, the reader may suspect that the results depend on fragile assumptions.

### Common Critiques and Responses

Applied IV papers in health economics face several recurring critiques:

**"The instrument is correlated with X."** If the instrument is correlated with an observable confounder X, the solution is to include X as a covariate. If the instrument is potentially correlated with an unobservable confounder, the critique is more serious and must be addressed through falsification tests and theoretical argument.

**"The first stage is too weak."** Report the first-stage F-statistic and compare to Stock-Yogo critical values. If the instrument is weak, consider LIML estimation, AR confidence sets, or finding a stronger instrument.

**"The LATE is not the parameter of interest."** Acknowledge that the IV estimate identifies the LATE for compliers, characterize the complier population as fully as possible, and discuss the extent to which the LATE is informative for the policy question at hand.

**"The exclusion restriction is implausible."** This is the most serious critique because it cannot be resolved empirically. Respond with theoretical argument, institutional detail, falsification tests, and sensitivity analysis (e.g., Conley, Hansen, and Rossi's (2012) plausibly exogenous instruments framework, which allows for small violations of the exclusion restriction).

---

**Table 10.1: Classic IV Applications in Health Economics**

| Study | Treatment | Instrument | First Stage F | Key Finding |
|---|---|---|---|---|
| McClellan et al. (1994) | Cardiac catheterization | Differential distance to cath hospital | Strong | OLS overstates benefit; IV shows modest/null survival effect |
| Card, Dobkin, Maestas (2008) | Insurance coverage | Medicare eligibility at age 65 | Very strong (>100) | Insurance increases utilization, improves outcomes |
| Finkelstein et al. (2012) | Medicaid enrollment | Oregon lottery selection | Very strong (>100) | Medicaid increases utilization, financial protection, mental health |
| Gruber & Owings (1996) | C-section delivery | Declining fertility rates | Moderate | Supply-induced demand for C-sections |
| Brookhart et al. (2006) | COX-2 vs. NSAID | Physician prescribing preference | Strong | Comparable outcomes; selection bias in observational estimates |

---

## Conclusion

Instrumental variables methods provide the primary strategy for causal inference in observational health economics when treatment is endogenous and experimental evidence is unavailable. The power of IV lies in its ability to isolate exogenous variation in treatment from the endogenous variation that confounds OLS estimates. The challenge lies in finding instruments that satisfy both relevance (testable) and the exclusion restriction (untestable) — a challenge that requires creativity, institutional knowledge, and rigorous empirical argumentation.

The LATE interpretation of IV, while sometimes viewed as a limitation (the estimate applies to compliers rather than the entire population), is also a strength: it provides a clear, well-defined causal parameter for a specific subpopulation. When the complier population is policy-relevant — as in the Oregon lottery (marginal Medicaid enrollees) or the age-65 discontinuity (near-universal Medicare eligibility) — the LATE directly answers the policy question.

The practical implementation of IV estimation in Julia is covered in Chapter 21, including 2SLS with robust and clustered standard errors, first-stage diagnostics, weak instrument-robust inference, and the construction of shift-share instruments from healthcare workforce data. The next chapter extends the quasi-experimental toolkit to difference-in-differences methods, which exploit temporal variation in policy adoption for causal identification.

## References

1. Anderson, T. W., & Rubin, H. (1949). Estimation of the parameters of a single equation in a complete system of stochastic equations. *Annals of Mathematical Statistics*, 20(1), 46-63.

2. Angrist, J. D., Imbens, G. W., & Rubin, D. B. (1996). Identification of causal effects using instrumental variables. *Journal of the American Statistical Association*, 91(434), 444-455.

3. Borusyak, K., Hull, P., & Jaravel, X. (2022). Quasi-experimental shift-share research designs. *Review of Economic Studies*, 89(1), 181-213.

4. Brookhart, M. A., Wang, P. S., Solomon, D. H., & Schneeweiss, S. (2006). Evaluating short-term drug effects using a physician-specific prescribing preference as an instrumental variable. *Epidemiology*, 17(3), 268-275.

5. Card, D., Dobkin, C., & Maestas, N. (2008). The impact of nearly universal insurance coverage on health care utilization: Evidence from Medicare. *American Economic Review*, 98(5), 2242-2258.

6. Card, D., Dobkin, C., & Maestas, N. (2009). Does Medicare save lives? *Quarterly Journal of Economics*, 124(2), 597-636.

7. Conley, T. G., Hansen, C. B., & Rossi, P. E. (2012). Plausibly exogenous. *Review of Economics and Statistics*, 94(1), 260-272.

8. Finkelstein, A., Taubman, S., Wright, B., et al. (2012). The Oregon Health Insurance Experiment: Evidence from the first year. *Quarterly Journal of Economics*, 127(3), 1057-1106.

9. Goldsmith-Pinkham, P., Sorkin, I., & Swift, H. (2020). Bartik instruments: What, when, why, and how. *American Economic Review*, 110(8), 2586-2624.

10. Imbens, G. W., & Angrist, J. D. (1994). Identification and estimation of local average treatment effects. *Econometrica*, 62(2), 467-475.

11. McClellan, M., McNeil, B. J., & Newhouse, J. P. (1994). Does more intensive treatment of acute myocardial infarction in the elderly reduce mortality? Analysis using instrumental variables. *JAMA*, 272(11), 859-866.

12. Moreira, M. J. (2003). A conditional likelihood ratio test for structural models. *Econometrica*, 71(4), 1027-1048.

13. Staiger, D., & Stock, J. H. (1997). Instrumental variables regression with weak instruments. *Econometrica*, 65(3), 557-586.

14. Stock, J. H., & Yogo, M. (2005). Testing for weak instruments in linear IV regression. In D. W. K. Andrews & J. H. Stock (Eds.), *Identification and Inference for Econometric Models* (pp. 80-108). Cambridge University Press.
