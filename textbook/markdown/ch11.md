# Chapter 11: Difference-in-Differences and Synthetic Control Methods

## Introduction

Difference-in-differences (DiD) is the most widely used quasi-experimental method in health economics and health policy research. Its appeal is both conceptual and practical: DiD exploits the natural variation created when a policy or intervention is adopted in some geographic units (states, hospitals, markets) but not others, comparing the change in outcomes over time in treated units to the change in untreated units. The method requires neither randomization nor an instrumental variable — only the assumption that, absent the treatment, outcomes in the treated and untreated groups would have followed parallel trajectories over time.

Health economics is particularly well-suited to DiD analysis because health policy in the United States is largely implemented at the state level, creating a rich landscape of natural variation. Medicaid expansion decisions, scope of practice regulations, certificate of need laws, Medicaid payment rates, insurance market regulations, and public health interventions all vary across states and over time, providing the treatment variation that DiD requires. The staggered adoption of these policies — with different states adopting at different times — has become the dominant research design in health policy evaluation, generating a literature that has fundamentally shaped our understanding of coverage expansion, payment reform, and regulatory effects.

However, recent econometric research has revealed that the standard two-way fixed effects (TWFE) estimator — the workhorse implementation of DiD for decades — produces biased estimates when treatment effects are heterogeneous across units or over time and when treatment timing is staggered. This finding has prompted a revolution in DiD methodology, with new estimators developed by Callaway and Sant'Anna (2021), Sun and Abraham (2021), Borusyak, Jaravel, and Spiess (2024), and others that address the heterogeneity and staggering problems. Understanding both the traditional and modern DiD approaches is now essential for any health economics researcher.

This chapter provides a comprehensive treatment of DiD and synthetic control methods. We cover the canonical 2×2 DiD, regression-based DiD with covariates, testing parallel trends, the staggered DiD problem and modern solutions, triple differences, the synthetic control method, and recent extensions. Health economics applications illustrate each method.

## The Canonical 2×2 Difference-in-Differences

### Setup and Identification

The simplest DiD design involves two groups (treated and control) observed at two time periods (before and after treatment). The four cell means are:

|  | Pre-treatment | Post-treatment |
|---|---|---|
| Treated group | Ȳ_T,pre | Ȳ_T,post |
| Control group | Ȳ_C,pre | Ȳ_C,post |

The DiD estimator is:

τ̂_DiD = (Ȳ_T,post - Ȳ_T,pre) - (Ȳ_C,post - Ȳ_C,pre)

The first difference (Ȳ_T,post - Ȳ_T,pre) captures the change in the treated group, which includes both the treatment effect and any time trend. The second difference (Ȳ_C,post - Ȳ_C,pre) captures the time trend in the control group. The difference of these two differences removes the common time trend, isolating the treatment effect.

Formally, define the potential outcomes:

Y_it(0) = αᵢ + λₜ + εᵢₜ (untreated potential outcome)
Y_it(1) = Y_it(0) + τᵢₜ (treated potential outcome)

where αᵢ is a unit fixed effect, λₜ is a time fixed effect, and τᵢₜ is the individual treatment effect. The observed outcome is Y_it = Y_it(0) + Dᵢₜ × τᵢₜ, where Dᵢₜ is the treatment indicator.

The DiD estimator identifies the average treatment effect on the treated (ATT) under the parallel trends assumption:

E[Y_it(0) | Dᵢ = 1, t = post] - E[Y_it(0) | Dᵢ = 1, t = pre] = E[Y_it(0) | Dᵢ = 0, t = post] - E[Y_it(0) | Dᵢ = 0, t = pre]

This assumption states that in the absence of treatment, the treated group's outcome would have changed by the same amount as the control group's outcome — the treated and control groups would have followed parallel paths. Parallel trends does not require that the treated and control groups have the same level of the outcome (that would be a much stronger assumption), only that they experience the same change over time.

### Regression Implementation

The 2×2 DiD estimator can be implemented as a regression:

Yᵢₜ = β₀ + β₁ × Treatᵢ + β₂ × Postₜ + β₃ × (Treatᵢ × Postₜ) + εᵢₜ

where Treatᵢ is a binary indicator for the treated group, Postₜ is a binary indicator for the post-treatment period, and the interaction term Treatᵢ × Postₜ is the DiD treatment indicator. The coefficient β₃ is the DiD estimate of the ATT.

The regression implementation has several advantages over the simple 2×2 cell mean comparison: it easily accommodates covariates (by adding Xᵢₜ to the regression), it produces standard errors directly (which can be clustered at the appropriate level), and it extends naturally to multiple groups and time periods.

## Regression-Based DiD with Covariates

### When Covariates Help

Adding covariates to the DiD regression can improve precision (by absorbing residual variation in the outcome) and may help support the parallel trends assumption (by controlling for time-varying confounders that differentially affect treated and control groups).

The augmented DiD regression is:

Yᵢₜ = β₀ + β₁ × Treatᵢ + β₂ × Postₜ + β₃ × (Treatᵢ × Postₜ) + X'ᵢₜγ + εᵢₜ

Covariates that are pre-determined (not affected by the treatment) and that predict both treatment assignment and the outcome can improve the credibility of the parallel trends assumption. For example, when evaluating the effect of Medicaid expansion on insurance coverage, controlling for state-level unemployment rates, poverty rates, and demographic composition can account for differential economic trends that might confound the expansion effect.

### When Covariates Are "Bad Controls"

Not all covariates are beneficial. A "bad control" is a variable that is itself affected by the treatment and that mediates the treatment's effect on the outcome. Including bad controls biases the DiD estimate by absorbing part of the treatment effect.

For example, when estimating the effect of Medicaid expansion on mortality, controlling for insurance coverage after expansion would absorb the mechanism through which expansion affects mortality (by increasing coverage). The resulting estimate would capture only the effect of expansion on mortality conditional on coverage — a fundamentally different and misleading parameter. The guidance is: include covariates that are pre-determined or evolve independently of the treatment; exclude covariates that are post-treatment mediators.

## Testing and Validating Parallel Trends

### Pre-Treatment Trend Plots

The most important validation exercise for any DiD analysis is visual inspection of pre-treatment trends. Plotting the outcome variable separately for the treated and control groups over time, including several pre-treatment periods, allows the researcher and reader to assess whether the two groups were on parallel trajectories before the treatment occurred.

If the pre-treatment trends are visually parallel, this supports (but does not prove) the parallel trends assumption. If the trends diverge before treatment, the assumption is questionable and the DiD estimate may be biased. Common divergence patterns include differential pre-trends (the treated group's outcome was already changing relative to the control group before treatment), which suggest that the groups were on different trajectories for reasons unrelated to the treatment.

### Event Study Specifications

The event study (or dynamic DiD) specification replaces the single post-treatment indicator with a set of period-specific treatment indicators, allowing the researcher to estimate the treatment effect separately for each period relative to the treatment date:

Yᵢₜ = αᵢ + λₜ + Σₖ βₖ × 1{t - Eᵢ = k} × Treatᵢ + X'ᵢₜγ + εᵢₜ

where Eᵢ is the treatment date for unit i, and k indexes periods relative to treatment (k < 0 for pre-treatment, k ≥ 0 for post-treatment). One pre-treatment period (typically k = -1) is omitted as the reference period, and all coefficients are estimated relative to this baseline.

The event study specification serves two purposes. First, the pre-treatment coefficients (βₖ for k < 0) provide a formal test of parallel trends: under the null hypothesis of parallel trends, all pre-treatment coefficients should be zero. Jointly testing whether the pre-treatment coefficients are statistically different from zero provides a pre-trends test. Second, the post-treatment coefficients (βₖ for k ≥ 0) trace out the dynamic treatment effect, showing how the effect evolves over time — whether it appears immediately, grows gradually, or fades.

### Placebo Tests

Placebo tests (falsification tests) provide additional evidence on the validity of the parallel trends assumption:

**Placebo treatment dates.** Re-estimate the DiD model using a fake treatment date that precedes the actual treatment. If the placebo DiD estimate is statistically significant, this suggests that the treated and control groups were on different trends before the actual treatment — undermining the parallel trends assumption.

**Placebo outcomes.** Estimate the DiD model using outcomes that should not be affected by the treatment. If Medicaid expansion affects mortality from ambulatory care-sensitive conditions (plausible, through improved access) but also affects mortality from car accidents (implausible, as car accidents are unrelated to healthcare access), the expansion effect on the plausible outcome may reflect confounding rather than causation.

**Placebo treatment groups.** Apply the DiD analysis to a control group that was not exposed to the treatment but is otherwise similar. If the "treatment effect" appears in the placebo group, this suggests that the estimated effect reflects differential trends rather than treatment effects.

## The Staggered DiD Problem

### Two-Way Fixed Effects and Its Limitations

Most DiD analyses in health economics involve multiple groups (states, hospitals) that adopt treatment at different times — the staggered adoption design. The standard implementation uses two-way fixed effects (TWFE) regression:

Yᵢₜ = αᵢ + λₜ + β × Dᵢₜ + X'ᵢₜγ + εᵢₜ

where αᵢ are unit fixed effects, λₜ are time fixed effects, and Dᵢₜ is the treatment indicator (equal to 1 for unit i in periods after it adopts the treatment, 0 otherwise). The coefficient β is interpreted as the average treatment effect.

Recent econometric research has demonstrated that the TWFE estimator produces biased estimates of the ATT when treatment effects are heterogeneous across units or over time and treatment timing is staggered. The source of the bias is that TWFE uses already-treated units as controls for newly-treated units — and if treatment effects change over time (dynamic effects), this comparison is contaminated.

### The Goodman-Bacon (2021) Decomposition

Goodman-Bacon (2021) provided a foundational analysis of what TWFE actually estimates in the staggered setting. He showed that the TWFE coefficient is a weighted average of all possible 2×2 DiD estimates formed from pairs of groups and time periods, with weights that depend on the group sizes and the variance of the treatment indicator.

Critically, some of these 2×2 DiD estimates use already-treated units as the comparison group — comparing newly-treated units to units that were treated earlier. When treatment effects are dynamic (growing or fading over time), these "bad comparisons" produce biased estimates because the already-treated units' outcomes are still evolving due to the treatment, making them poor counterfactuals for the newly-treated units.

The decomposition reveals three types of 2×2 comparisons embedded in TWFE:

1. **Earlier treated vs. never treated**: Clean comparison, no bias.
2. **Later treated vs. never treated**: Clean comparison, no bias.
3. **Earlier treated vs. later treated** (and vice versa): Potentially biased because earlier-treated units' outcomes include their own treatment effect, which contaminates the counterfactual.

When treatment effects are homogeneous (constant across units and over time), the bad comparisons are harmless because the treatment effect in the already-treated comparison group is the same as in the newly-treated group. But when effects are heterogeneous — as is generally the case in health economics — the bad comparisons introduce bias, and the sign and magnitude of the bias depend on the pattern of treatment effect heterogeneity.

### Negative Weighting

De Chaisemartin and D'Haultfoeuille (2020) formalized the negative weighting problem: some of the implicit 2×2 DiD comparisons in TWFE receive negative weights, meaning that a positive treatment effect for one group can enter the overall estimate with a negative sign. Negative weights arise specifically in comparisons where already-treated units serve as controls. When negative weights are present, the TWFE coefficient can be the opposite sign of the true ATT — a deeply problematic result.

De Chaisemartin and D'Haultfoeuille developed a diagnostic test that decomposes the TWFE coefficient into its component weights and identifies the proportion of negative weights. If a substantial fraction of weights are negative, the TWFE estimate is unreliable and modern estimators should be used.

## New DiD Estimators

### Callaway and Sant'Anna (2021)

Callaway and Sant'Anna (CS) proposed an estimator that computes group-time average treatment effects — ATT(g, t) — for each cohort g (defined by treatment timing) at each time period t. The CS estimator avoids the bad comparison problem by using only never-treated (or not-yet-treated) units as the control group for each cohort-period pair.

The ATT(g, t) for cohort g at time t is estimated using a standard 2×2 DiD (or augmented with inverse probability weighting or outcome regression for covariate adjustment) comparing cohort g to the control group between the baseline period and period t.

The individual ATT(g, t) estimates can then be aggregated into summary parameters:

**Simple average**: ATT = (1/K) Σ ATT(g, t), averaging across all cohort-period combinations with equal weights.

**Dynamic/event-study**: ATT(e) for each event-time e (periods since treatment), averaging across cohorts at the same event-time.

**Cohort-specific**: ATT(g), averaging across post-treatment periods for each cohort.

CS provides valid inference through a multiplier bootstrap procedure that accounts for the multi-step estimation process.

### Sun and Abraham (2021)

Sun and Abraham (SA) proposed an interaction-weighted estimator that addresses the contamination problem in TWFE event study specifications. They showed that the standard TWFE event study coefficients are contaminated by treatment effects from other periods, producing biased dynamic treatment effect estimates even when the event study plot appears clean.

The SA estimator uses a two-step procedure: (1) estimate cohort-specific event study coefficients using interactions between cohort indicators and event-time indicators, and (2) aggregate the cohort-specific coefficients using appropriate weights. The resulting estimates are uncontaminated and provide valid inference for dynamic treatment effects.

### Borusyak, Jaravel, and Spiess (2024)

Borusyak, Jaravel, and Spiess (BJS) proposed an imputation estimator that directly models the untreated potential outcomes for treated units and imputes what would have happened absent treatment. The estimator:

1. Estimates a TWFE model using only untreated observations (never-treated units and pre-treatment periods of eventually-treated units).
2. Uses the estimated model to predict untreated potential outcomes for treated observations.
3. Computes treatment effects as the difference between actual and predicted outcomes for treated observations.

The BJS approach is conceptually transparent — it explicitly constructs the counterfactual for each treated observation — and is computationally efficient. It nests the standard TWFE estimator as a special case when treatment effects are homogeneous and produces unbiased estimates under treatment effect heterogeneity.

### When and Why to Use Each

The choice among modern DiD estimators depends on the research context:

**Callaway-Sant'Anna** is the most flexible, accommodating covariates through multiple adjustment methods (regression, IPW, doubly robust), allowing both never-treated and not-yet-treated comparison groups, and providing clean aggregation into multiple summary parameters. It is the default recommendation for most staggered DiD applications.

**Sun-Abraham** is particularly useful when the primary interest is in dynamic treatment effects (event study plots) and when the researcher wants to maintain the familiar event study regression framework while correcting for contamination.

**Borusyak-Jaravel-Spiess** is computationally efficient, conceptually transparent, and performs well with large numbers of cohorts. It is particularly useful when the number of treatment cohorts is large relative to the number of time periods.

All three estimators produce similar results in well-behaved settings. The most important practical step is to report results from at least one modern estimator alongside the traditional TWFE estimate, allowing readers to assess the extent of bias from treatment effect heterogeneity.

## DiD Applications in Health Economics

### Medicaid Expansion Studies

The staggered adoption of the ACA Medicaid expansion across states — with 25 states expanding in January 2014, additional states expanding in subsequent years, and approximately 10 states still not expanded as of 2024 — has generated the largest body of DiD evidence in health economics.

**Coverage effects.** Sommers and colleagues (2012, 2017) used DiD comparing expansion and non-expansion states to estimate that Medicaid expansion increased insurance coverage by approximately 5 to 7 percentage points among the low-income adult population, with corresponding reductions in the uninsured rate.

**Health effects.** Miller, Johnson, and Wherry (2021) used a DiD design with synthetic control methods to estimate that Medicaid expansion reduced mortality among 55-64 year olds by approximately 0.13 percentage points, corresponding to approximately 4,800 lives saved annually among near-elderly adults.

**Hospital financial effects.** Blavin (2016) and others used DiD to estimate that Medicaid expansion reduced hospital uncompensated care costs by approximately 30-40%, improved hospital operating margins, and reduced the probability of rural hospital closure (as discussed in Chapter 8).

### ACA Provision Evaluations

DiD has been used extensively to evaluate individual ACA provisions:

**Dependent coverage mandate.** The ACA's provision allowing young adults to remain on their parents' insurance until age 26 was implemented nationally in September 2010, but affected only individuals aged 19-25 (the treated group), with slightly older individuals (aged 27-30) serving as the comparison group. Sommers and colleagues (2013) found that the mandate increased coverage among 19-25 year olds by approximately 3 percentage points.

**Essential health benefit mandates.** The ACA's requirement that individual and small group plans cover mental health, substance use disorder, and maternity services (among other categories) was evaluated using DiD designs comparing states that already mandated these benefits (control) with states that did not (treated by the ACA mandate).

## Triple Differences

### When Single DiD Fails

Triple differences (DDD) adds a third differencing dimension to address violations of the parallel trends assumption. The approach is useful when the treated and control groups may differ in their underlying trends, but a within-group comparison can be used to net out the differential trend.

The DDD estimator is:

τ̂_DDD = {(Ȳ_T,A,post - Ȳ_T,A,pre) - (Ȳ_T,B,post - Ȳ_T,B,pre)} - {(Ȳ_C,A,post - Ȳ_C,A,pre) - (Ȳ_C,B,post - Ȳ_C,B,pre)}

where A denotes the affected subgroup and B denotes the unaffected subgroup within each treatment and control unit. The DDD computes DiD within the treated group (comparing affected and unaffected subgroups), DiD within the control group (same comparison), and differences these two DiD estimates.

### Health Economics Applications

DDD is commonly used when evaluating policies that affect specific demographic subgroups. For example, the ACA dependent coverage mandate affected 19-25 year olds (subgroup A) but not 27-30 year olds (subgroup B). The DDD uses both the age comparison (19-25 vs. 27-30) and a time comparison (before vs. after September 2010), netting out both age-specific trends and time-specific shocks that affect all ages equally.

The regression implementation of DDD includes all main effects, two-way interactions, and the three-way interaction:

Yᵢₜ = β₀ + β₁Treatᵢ + β₂Postₜ + β₃Affectedᵢ + β₄(Treatᵢ × Postₜ) + β₅(Treatᵢ × Affectedᵢ) + β₆(Postₜ × Affectedᵢ) + β₇(Treatᵢ × Postₜ × Affectedᵢ) + εᵢₜ

The coefficient β₇ is the DDD estimate.

## The Synthetic Control Method

### Abadie-Diamond-Hainmueller Framework

The synthetic control method (SCM), developed by Abadie and Gardeazabal (2003) and formalized by Abadie, Diamond, and Hainmueller (2010, 2015), constructs a counterfactual for a single treated unit using a weighted combination of control units that best matches the treated unit's pre-treatment characteristics and outcomes.

The synthetic control for treated unit 1 is a weighted average of the J control units:

Ŷ₁ₜ(0) = Σⱼ₌₂ᴶ⁺¹ wⱼ × Yⱼₜ

where the weights w = (w₂, ..., wJ+1) are chosen to minimize the distance between the treated unit's pre-treatment outcomes and the weighted average of control units' pre-treatment outcomes:

min_w ‖X₁ - X₀w‖ subject to wⱼ ≥ 0, Σwⱼ = 1

where X₁ is a vector of pre-treatment characteristics (including pre-treatment outcome values) for the treated unit and X₀ is the corresponding matrix for the control units.

The treatment effect is estimated as the gap between the treated unit's actual outcome and the synthetic control's outcome in the post-treatment period:

τ̂₁ₜ = Y₁ₜ - Ŷ₁ₜ(0) for t > T₀

### Inference via Permutation

Because SCM typically involves a single treated unit, standard frequentist inference is not applicable. Abadie and colleagues proposed a permutation-based inference procedure:

1. Estimate the treatment effect for the actual treated unit.
2. Iteratively apply the SCM procedure to each control unit (as if it were treated), constructing a placebo synthetic control and placebo treatment effect.
3. Compare the treated unit's effect to the distribution of placebo effects. If the treated unit's effect is extreme relative to the placebo distribution (e.g., larger than all or nearly all placebo effects), the effect is considered statistically significant.

The resulting p-value is:

p = (rank of treated unit's effect) / (J + 1)

where the rank is computed among the treated and all J placebo effects. With 20 control units, the smallest achievable p-value is 1/21 ≈ 0.048.

### SCM Advantages Over DiD

SCM has several advantages for health economics applications:

**Transparency.** The weights assigned to each control unit are reported, making the counterfactual construction transparent and verifiable. The researcher and reader can assess whether the synthetic control is a credible counterfactual based on the pre-treatment match quality.

**No parallel trends assumption.** SCM does not assume that any single control unit follows the same trend as the treated unit. Instead, it constructs a weighted combination that matches the treated unit's trajectory, potentially using control units with very different individual trends.

**Single-treated-unit designs.** SCM is specifically designed for settings with a single treated unit (e.g., one state that adopts a policy), where DiD with a single treated unit and multiple controls may produce imprecise estimates.

### SCM Applications in Health Economics

**State-level Medicaid expansion.** For states that expanded Medicaid before the ACA's 2014 implementation (e.g., Massachusetts in 2006), SCM can construct a synthetic Massachusetts from non-expanding states to estimate the effect of early expansion on coverage, utilization, and health outcomes.

**Hospital closures.** SCM can construct a synthetic community from communities that did not experience a hospital closure, matching on pre-closure health outcomes, demographics, and economic characteristics, to estimate the effect of closure on community health and economic outcomes.

**Certificate of need repeal.** When a single state repeals its CON law, SCM can construct a synthetic version of that state from states that retained CON, estimating the effect of repeal on hospital capacity, spending, and quality.

## Recent Extensions

### Augmented Synthetic Control

Ben-Michael, Feller, and Rothstein (2021) proposed the augmented synthetic control method (ASCM), which combines SCM with an outcome model to improve pre-treatment fit and reduce bias when the standard SCM cannot achieve a close match. ASCM adds a bias correction term based on a ridge regression of the outcome on pre-treatment covariates:

τ̂_ASCM = (Y₁,post - Ŷ₁,post^SCM) - (Y₁,pre - Ŷ₁,pre^SCM)' × β̂_ridge

The augmentation term corrects for any residual pre-treatment imbalance, reducing the sensitivity of the estimate to imperfect matching.

### Synthetic Difference-in-Differences

Arkhangelsky and colleagues (2021) proposed synthetic DiD (SDiD), which combines elements of SCM (reweighting control units to match the treated unit's pre-treatment trajectory) with DiD (differencing out unit and time fixed effects). SDiD uses two sets of weights: unit weights (as in SCM) that match pre-treatment outcomes, and time weights that focus on pre-treatment periods most similar to the post-treatment period.

SDiD has been shown to perform well across a range of data generating processes and is particularly useful when neither pure DiD (which may suffer from parallel trends violations) nor pure SCM (which may suffer from poor pre-treatment fit) performs well individually.

---

**Key Concepts Box: Choosing Among DiD Estimators**

| Estimator | Best For | Key Assumption | Handles Staggering | Handles Dynamic Effects |
|---|---|---|---|---|
| Classic 2×2 DiD | Two groups, two periods | Parallel trends | No | No |
| TWFE | Multiple groups, staggered adoption | Parallel trends + homogeneous effects | Biased if heterogeneous | Biased in event study |
| Callaway-Sant'Anna | Staggered with heterogeneity | Parallel trends for each cohort | Yes | Yes |
| Sun-Abraham | Staggered event studies | Parallel trends for each cohort | Yes | Yes |
| Borusyak-Jaravel-Spiess | Large staggered designs | Parallel trends (imputation) | Yes | Yes |
| Synthetic control | Single treated unit | Pre-treatment match quality | N/A | Yes |
| Synthetic DiD | Panel data, moderate N | Unit + time weighting | Yes | Yes |

---

## Conclusion

Difference-in-differences and synthetic control methods are the primary tools for evaluating health policies that are adopted across geographic units at different times. The staggered adoption of Medicaid expansion, payment reforms, scope of practice regulations, and other health policies has created a rich empirical landscape for DiD analysis, and the resulting evidence has profoundly shaped health policy understanding and decision-making.

The recent revolution in DiD econometrics — driven by the discovery that TWFE produces biased estimates under treatment effect heterogeneity — has raised the methodological bar for applied research. Health economics researchers should now routinely implement modern estimators (Callaway-Sant'Anna, Sun-Abraham, or Borusyak-Jaravel-Spiess) alongside traditional TWFE, report diagnostic tests for negative weighting and pre-treatment trends, and present dynamic treatment effects through event study plots.

The synthetic control method complements DiD by providing a transparent and powerful approach for single-treated-unit settings that are common in state-level health policy evaluation. The recent extensions — augmented SCM and synthetic DiD — bridge the gap between the two methods, offering flexible tools for a wider range of research designs.

The Julia implementation of all DiD and SCM estimators discussed in this chapter is provided in Chapter 21, including the Callaway-Sant'Anna estimator, event study plots, and the synthetic control method with permutation inference.

## References

1. Abadie, A., Diamond, A., & Hainmueller, J. (2010). Synthetic control methods for comparative case studies: Estimating the effect of California's tobacco control program. *Journal of the American Statistical Association*, 105(490), 493-505.

2. Abadie, A., Diamond, A., & Hainmueller, J. (2015). Comparative politics and the synthetic control method. *American Journal of Political Science*, 59(2), 495-510.

3. Arkhangelsky, D., Athey, S., Hirshberg, D. A., Imbens, G. W., & Wager, S. (2021). Synthetic difference-in-differences. *American Economic Review*, 111(12), 4088-4118.

4. Ben-Michael, E., Feller, A., & Rothstein, J. (2021). The augmented synthetic control method. *Journal of the American Statistical Association*, 116(536), 1789-1803.

5. Blavin, F. (2016). Association between the 2014 Medicaid expansion and US hospital finances. *JAMA*, 316(14), 1475-1483.

6. Borusyak, K., Jaravel, X., & Spiess, J. (2024). Revisiting event-study designs: Robust and efficient estimation. *Review of Economic Studies*, 91(6), 3253-3285.

7. Callaway, B., & Sant'Anna, P. H. C. (2021). Difference-in-differences with multiple time periods. *Journal of Econometrics*, 225(2), 200-230.

8. de Chaisemartin, C., & D'Haultfoeuille, X. (2020). Two-way fixed effects estimators with heterogeneous treatment effects. *American Economic Review*, 110(9), 2964-2996.

9. Goodman-Bacon, A. (2021). Difference-in-differences with variation in treatment timing. *Journal of Econometrics*, 225(2), 254-277.

10. Miller, S., Johnson, N., & Wherry, L. R. (2021). Medicaid and mortality: New evidence from linked survey and administrative data. *Quarterly Journal of Economics*, 136(3), 1783-1829.

11. Sommers, B. D., Baicker, K., & Epstein, A. M. (2012). Mortality and access to care among adults after state Medicaid expansions. *New England Journal of Medicine*, 367(11), 1025-1034.

12. Sun, L., & Abraham, S. (2021). Estimating dynamic treatment effects in event studies with heterogeneous treatment effects. *Journal of Econometrics*, 225(2), 175-199.
