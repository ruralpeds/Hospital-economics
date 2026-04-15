# Chapter 2: Healthcare Demand: Theory and Empirical Evidence

## Introduction

The demand for healthcare is among the most extensively studied topics in applied economics, and for good reason. Healthcare expenditures constitute nearly one-fifth of United States gross domestic product, and understanding the forces that drive utilization — prices, insurance, income, information, behavioral biases — is essential for designing policies that improve both efficiency and equity. Yet healthcare demand defies easy analysis. Unlike demand for most consumer goods, the demand for medical care is heavily mediated by insurance, shaped by provider recommendations, influenced by health shocks that are largely unpredictable, and complicated by the distinction between the demand for health itself and the derived demand for healthcare services.

This chapter provides a comprehensive treatment of healthcare demand theory and the empirical evidence that tests and refines it. We begin with the application of consumer theory to healthcare, building on the Grossman model introduced in Chapter 1. We then examine the landmark experimental evidence on price sensitivity — the RAND Health Insurance Experiment and the Oregon Health Insurance Experiment — before turning to the economics of moral hazard, physician-induced demand, non-monetary barriers to access, and the growing influence of behavioral economics on our understanding of healthcare utilization decisions. Throughout, we ground theoretical models in the empirical evidence, emphasizing both the methodological challenges of demand estimation and the policy implications of the findings.

The target audience is graduate researchers in health economics and health services research who have completed a first course in microeconomic theory and are familiar with the foundational concepts from Chapter 1, including the Grossman model, moral hazard, adverse selection, and the agency relationship between providers and patients.

## Consumer Theory Applied to Healthcare

### Utility Maximization and the Budget Constraint

The standard consumer theory framework assumes that individuals maximize a utility function subject to a budget constraint. In the simplest healthcare demand model, an individual allocates income *Y* between medical care *M* (at price *pM*) and all other goods *X* (at price *pX*, normalized to 1):

max U(H(M), X) subject to pM × M + X ≤ Y

where *H(M)* is the health production function relating medical care inputs to health status. The first-order condition for an interior solution equates the marginal rate of substitution between health and other goods to the relative price ratio:

(∂U/∂H)(∂H/∂M) / (∂U/∂X) = pM

This condition states that the individual consumes medical care up to the point where the marginal utility of the last dollar spent on health (via medical care) equals the marginal utility of the last dollar spent on all other goods.

Several features of this simple model are noteworthy. First, the demand for medical care is a derived demand — individuals do not value medical care for its own sake but for the health it produces. This is the central insight of the Grossman model. Second, the relevant price for the insured individual is the out-of-pocket price (copayment, coinsurance, deductible), not the full price of the service. Insurance drives a wedge between the price the provider receives and the price the consumer pays, fundamentally altering the demand curve. Third, the utility function may incorporate not only the level of health but also uncertainty about future health states, generating demand for both medical care and health insurance.

### The Grossman Model Revisited: Demand for Health vs. Demand for Medical Care

As established in Chapter 1, the Grossman (1972) model distinguishes between the demand for health capital *H* and the derived demand for medical care *M*. In the investment version of the model, the individual chooses a time path of health investment to maximize lifetime utility:

max Σt βt U(φ(Ht), Xt)

subject to the health capital accumulation equation:

Ht+1 = Ht + I(Mt, THt; E) - δt Ht

and the lifetime budget constraint. Here βt is the discount factor, φ(Ht) converts health capital into healthy time available for consumption and market work, δt is the age-dependent depreciation rate, and I(·) is the gross health investment production function.

The model yields the equilibrium condition that the individual invests in health until the marginal cost of health capital equals its user cost:

πH(t) = (r + δt) × Ct-1

where πH(t) is the marginal cost of a unit of health capital, r is the interest rate, δt is the depreciation rate, and Ct-1 is the capital cost of health investment. The marginal benefit of health capital includes both the monetary return (wage rate times marginal product of health in producing healthy time) and the direct utility return (marginal utility of healthy time times marginal product of health).

Several empirically relevant predictions follow from this framework. The demand for medical care increases with age, because the depreciation rate of health capital rises with age, requiring greater investment to maintain any given health stock. The demand for medical care is inversely related to its price, but the magnitude of the response depends on the elasticity of the health production function and the degree of insurance coverage. Education increases the efficiency of health production, so more educated individuals can achieve the same health stock with fewer medical care inputs — or they may demand a higher health stock, with ambiguous net effects on medical care demand.

### Income Effects and the Income Elasticity of Healthcare Demand

The relationship between income and healthcare demand has important implications for the financing and distribution of healthcare. At the individual level, higher-income individuals generally consume more healthcare, but the income elasticity of demand is a matter of empirical debate. Most micro-level studies estimate the income elasticity of healthcare demand to be between 0.0 and 0.5, suggesting that healthcare is a normal good but not a luxury at the individual level (Getzen, 2000).

At the aggregate (national) level, however, the income elasticity of health expenditure appears to be close to or greater than one, implying that healthcare may be a luxury good in cross-country comparisons. The apparent paradox — individual-level necessity vs. aggregate-level luxury — can be resolved by recognizing that aggregate health expenditure growth reflects not only individual demand responses to income but also supply-side factors: technological change, provider market power, administrative cost growth, and policy decisions about coverage generosity that are correlated with national income.

The distinction matters for policy. If healthcare is a necessity (income elasticity less than one), then healthcare spending as a share of income falls as income rises, and healthcare financing is regressive unless explicitly designed otherwise. If healthcare is a luxury (income elasticity greater than one), then wealthier nations naturally devote larger shares of their income to healthcare, and the rapid growth of US health spending may simply reflect rising national income rather than inefficiency.

## The RAND Health Insurance Experiment

### Experimental Design

The RAND Health Insurance Experiment (HIE), conducted between 1974 and 1982, remains the most influential study in the history of health economics. Designed by Joseph Newhouse and colleagues at the RAND Corporation, the HIE randomly assigned approximately 2,750 families (nearly 7,700 individuals) in six geographic sites to one of fourteen insurance plans that varied in the degree of cost-sharing. The key plans included:

1. **Free care plan**: Zero cost-sharing for all services.
2. **25% coinsurance plan**: Patients paid 25% of all charges up to a maximum dollar expenditure (MDE).
3. **50% coinsurance plan**: 50% coinsurance up to the MDE.
4. **95% coinsurance plan**: Near-catastrophic coverage only — 95% coinsurance up to the MDE.
5. **Individual deductible plan**: Free outpatient care but with a deductible for inpatient care.

The maximum dollar expenditure cap was set at $1,000 per family (in 1973 dollars), scaled to 5%, 10%, or 15% of family income, ensuring that no family faced catastrophic financial exposure regardless of assignment. Participants were enrolled for three to five years, creating a panel dataset of healthcare utilization, expenditures, and health outcomes under exogenously assigned insurance coverage levels.

The random assignment design is the critical methodological feature. Observational studies of the relationship between insurance generosity and healthcare utilization are confounded by adverse selection — sicker individuals may choose more generous coverage. The RAND HIE eliminated this confound through randomization, providing unbiased estimates of the causal effect of cost-sharing on utilization.

### Key Findings

The RAND HIE produced several findings that have profoundly shaped health economics and health policy.

**Price elasticity of demand.** The central finding was that cost-sharing significantly reduces healthcare utilization. Individuals assigned to the free care plan used approximately 30% more healthcare (in expenditure terms) than those in the 95% coinsurance plan. The estimated arc price elasticity of demand for medical care was approximately -0.2, meaning that a 10% increase in the out-of-pocket price reduces utilization by approximately 2%. This estimate has been cited thousands of times and remains the benchmark for healthcare demand elasticity.

Importantly, the demand response was not uniform across service types. Outpatient care was more price-sensitive than inpatient care, and dental care and mental health services were more price-sensitive than general medical care. Preventive care utilization also declined with cost-sharing, although the effects were somewhat smaller than for acute care.

**Health outcomes.** For the average participant, the additional healthcare consumed under free care produced only modest improvements in health outcomes. The major exception was among low-income individuals with hypertension, for whom free care significantly improved blood pressure control and vision correction. This finding has been interpreted both as evidence that much of the additional care consumed under free care is of marginal value (supporting the moral hazard interpretation) and as evidence that cost-sharing creates meaningful access barriers for vulnerable populations (supporting equity concerns).

**Appropriateness of care reductions.** A critical follow-up analysis by Lohr and colleagues (1986) examined whether cost-sharing caused patients to reduce "appropriate" and "inappropriate" care differentially. The finding was that cost-sharing reduced both appropriate and inappropriate care roughly proportionately — patients did not selectively reduce low-value services while preserving high-value ones. This result has important implications for the design of cost-sharing policies: simple, uniform cost-sharing instruments (flat coinsurance rates) are blunt tools that reduce both wasteful and beneficial utilization.

### Critiques and Limitations

Despite its enormous influence, the RAND HIE has been subject to important critiques.

**Generalizability.** The experiment was conducted in the 1970s and early 1980s, when the healthcare delivery system, technology, and price levels were substantially different from today. Medical care in 2026 includes many high-cost treatments (biologics, immunotherapies, advanced imaging) that did not exist during the HIE, and the price elasticity of demand for these services may differ from the aggregate estimates. The HIE also excluded the elderly (Medicare-eligible), the very poor (Medicaid-eligible at the time), and institutionalized populations.

**Duration.** The experiment lasted three to five years. The long-run effects of sustained cost-sharing on health capital accumulation, chronic disease management, and mortality cannot be reliably extrapolated from this relatively short experimental period.

**Attrition and compliance.** Approximately 10% of participants dropped out of the experiment, and there is some evidence of differential attrition by plan assignment. While the researchers conducted extensive analyses to assess the sensitivity of results to attrition, the possibility of bias cannot be entirely eliminated.

**Statistical power for subgroup effects.** While the HIE detected average effects with high precision, it was underpowered to detect meaningful effects in many subgroups of clinical and policy interest. The beneficial health effects among low-income hypertensives were detected only because this subgroup was pre-specified and the effect was large.

## The Oregon Health Insurance Experiment

### Design and Context

The Oregon Health Insurance Experiment (OHIE), launched in 2008, represents the second major randomized experiment in health insurance. In 2008, Oregon opened a waiting list for its Medicaid program (Oregon Health Plan Standard) to uninsured adults below 100% of the federal poverty level who were not categorically eligible for traditional Medicaid. Approximately 90,000 individuals signed up for the waiting list, and the state randomly selected approximately 30,000 individuals to apply for Medicaid coverage, of whom about 10,000 ultimately enrolled.

Researchers led by Amy Finkelstein and Katherine Baicker used this lottery as the basis for a large-scale randomized controlled trial, comparing outcomes for lottery winners (the treatment group, who gained access to Medicaid) and lottery losers (the control group, who remained uninsured). The study combined administrative data (hospital discharge records, credit reports, mortality records) with a detailed follow-up survey administered approximately one year after the lottery.

### Key Findings

The OHIE produced results that both confirmed and challenged findings from the RAND HIE.

**Healthcare utilization.** Medicaid coverage substantially increased healthcare utilization across all categories. Outpatient visits increased by approximately 35%, prescription drug use increased by 15%, and hospitalizations increased by 30%. Emergency department use also increased significantly — contradicting the common policy claim that providing insurance would reduce expensive ED utilization by enabling access to primary care.

**Financial protection.** Medicaid coverage dramatically improved financial outcomes. Catastrophic out-of-pocket medical expenditures (exceeding $1,500 annually) fell by approximately 80%. Medical collections declined significantly, and financial strain indicators improved markedly. The evidence for financial protection was among the strongest and most unambiguous findings of the study.

**Physical health outcomes.** The most controversial finding was that Medicaid coverage did not produce statistically significant improvements in measured physical health outcomes — blood pressure, cholesterol levels, and glycated hemoglobin (HbA1c) — at the two-year follow-up. This null result generated enormous debate. Defenders of Medicaid argued that the study was underpowered for clinical outcomes (the confidence intervals did not exclude clinically meaningful improvements), that two years was too short to detect health effects of insurance, and that the study population was relatively young and healthy. Critics argued that the results demonstrated the limited value of Medicaid coverage and questioned the cost-effectiveness of coverage expansion.

**Mental health.** In contrast to the null physical health findings, Medicaid coverage produced large and statistically significant improvements in mental health. Depression rates fell by approximately 30%, and self-reported mental health improved substantially. This finding highlighted the importance of financial security and healthcare access for psychological well-being, a dimension often underemphasized in economic analyses focused on physical health endpoints.

**Self-reported health.** Lottery winners were substantially more likely to report their health as "good," "very good," or "excellent," suggesting that the subjective experience of having insurance coverage — including reduced anxiety about medical bills and the ability to seek care when needed — has value that may not be captured by clinical biomarkers.

### Comparing the RAND HIE and the Oregon Experiment

The two experiments address different but complementary questions. The RAND HIE examined the intensive margin of demand — how variations in cost-sharing affect utilization among the insured. The Oregon experiment examined the extensive margin — what happens when previously uninsured individuals gain coverage. The RAND HIE studied a broad population with varying insurance generosity levels. The Oregon experiment studied a low-income, previously uninsured population gaining Medicaid.

The finding that healthcare utilization is price-sensitive (RAND) and that gaining coverage increases utilization substantially (Oregon) are fully consistent. Together, they establish that insurance matters enormously for utilization, financial protection, and subjective well-being, while the relationship between insurance coverage and measured physical health outcomes is more nuanced and likely depends on the population, the conditions studied, and the time horizon.

## Moral Hazard in Health Insurance

### Ex-Ante and Ex-Post Moral Hazard

Moral hazard in health insurance takes two forms that are analytically distinct.

**Ex-ante moral hazard** refers to the effect of insurance on health-related behavior before illness occurs. If individuals are insured against the financial consequences of illness, they may invest less in prevention and health maintenance — exercising less, eating poorly, engaging in risky behavior — because the costs of poor health are partially transferred to the insurer. The empirical evidence for ex-ante moral hazard is mixed. While some studies find that insurance coverage is associated with increased risky behavior (Dave and Kaestner, 2009), the effects are generally small. The primary reason is that the non-financial costs of illness — pain, disability, mortality — are not insured, so even fully insured individuals retain strong incentives to maintain their health.

**Ex-post moral hazard** (sometimes called "moral hazard in consumption") refers to the increased consumption of medical care when insurance reduces the out-of-pocket price at the point of service. This is the form of moral hazard documented by the RAND HIE and is the primary focus of most health economics discussions of moral hazard. Ex-post moral hazard is substantial: the RAND HIE demonstrated that moving from full cost-sharing to free care increases expenditures by approximately 30%.

### The Welfare Economics of Moral Hazard

The welfare implications of moral hazard have been the subject of one of the most important theoretical debates in health economics.

**The Pauly (1968) framework.** Mark Pauly's seminal 1968 paper established the standard economic analysis of moral hazard in health insurance. Pauly argued that the additional medical care consumed due to insurance represents a welfare loss, analogous to the deadweight loss from a price subsidy. The logic is as follows: in the absence of insurance, individuals consume medical care up to the point where the marginal value of the last unit equals its marginal cost. Insurance reduces the out-of-pocket price below the marginal cost, inducing consumption of units whose marginal value to the consumer (as revealed by their willingness to pay) is less than their marginal cost of production. The resulting welfare loss is approximately:

DWL ≈ ½ × ΔP × ΔM

where ΔP is the reduction in out-of-pocket price due to insurance and ΔM is the induced increase in consumption. This "welfare triangle" represents the net social loss from moral hazard — the excess of production costs over consumer value for the additional units consumed.

Pauly's analysis implies that optimal insurance design must balance risk protection (the welfare gain from reducing financial uncertainty) against moral hazard (the welfare loss from price-induced overconsumption). The optimal coinsurance rate is not zero (full insurance) nor one (no insurance) but somewhere in between, depending on the degree of risk aversion, the price elasticity of demand, and the variance of healthcare expenditures.

**The Nyman (2003) access value theory.** John Nyman challenged the Pauly framework with his "access value" theory of health insurance demand. Nyman observed that Pauly's analysis assumes that all insurance-induced utilization is due to the price effect — consumers moving down their demand curve in response to a lower out-of-pocket price. However, Nyman argued that insurance also creates an income effect: by transferring income from healthy states (when premiums are paid) to sick states (when claims are paid), insurance enables the consumption of expensive treatments that individuals could not otherwise afford.

For example, a patient who develops cancer and requires a $200,000 course of treatment could not afford this care out of pocket on a typical income. Insurance makes this treatment accessible by pooling risk across the insured population. The additional utilization enabled by this income transfer is not a welfare loss — it represents access to high-value care that improves welfare. Nyman termed this the "access value" of insurance and argued that the traditional moral hazard welfare triangle substantially overstates the true welfare loss because it conflates the price effect (welfare-reducing) with the income/access effect (welfare-enhancing).

The empirical relevance of the Nyman critique depends on the proportion of insurance-induced utilization that is due to the income/access effect versus the pure price effect. For low-cost, discretionary services (an extra physician visit for a minor complaint), the price effect likely dominates. For high-cost, non-discretionary services (cancer treatment, cardiac surgery, organ transplantation), the access effect is likely dominant. The aggregate welfare implications of moral hazard thus depend on the composition of insurance-induced utilization across these categories.

**The Einav-Finkelstein-Cullen (2010) sufficient statistics approach.** More recent theoretical work by Einav, Finkelstein, and Cullen (2010) developed a "sufficient statistics" framework for evaluating welfare in insurance markets that accommodates both adverse selection and moral hazard. Their approach identifies the key empirical moments — the demand curve for insurance and the cost curve as a function of insurance generosity — that are sufficient for calculating the welfare effects of alternative insurance designs, without requiring a full structural model of consumer behavior. This framework has become the standard tool for empirical welfare analysis in insurance markets and is discussed further in Chapter 4.

### Optimal Insurance Design Under Moral Hazard

The optimal insurance problem under moral hazard can be formalized as a principal-agent problem in which the insurer (principal) designs a contract to maximize the expected welfare of the insured individual (agent), subject to the constraint that insurance induces behavioral responses.

Zeckhauser (1970) demonstrated that the optimal insurance contract under moral hazard is not a simple coinsurance rate but rather a state-contingent contract that conditions coverage on the type of service and the clinical circumstances. This theoretical insight underlies the concept of **value-based insurance design (VBID)**, which reduces cost-sharing for high-value services (where the welfare gain from increased utilization exceeds the welfare loss from moral hazard) and increases cost-sharing for low-value services (where the moral hazard loss dominates).

The practical implementation of VBID requires identifying which services are high-value and which are low-value — a task that intersects with cost-effectiveness analysis (Chapter 6) and quality measurement (Chapter 7). The evidence on VBID is growing, with studies showing that reducing copayments for medications used to manage chronic conditions (statins, anti-hypertensives, diabetes medications) increases adherence and may reduce total costs by preventing expensive downstream complications (Choudhry et al., 2011).

---

**Key Concepts Box: Moral Hazard in Health Insurance**

| Concept | Definition | Policy Implication |
|---|---|---|
| Ex-ante moral hazard | Reduced health investment due to insurance | Small empirical effects; not a major policy concern |
| Ex-post moral hazard | Increased utilization due to lower out-of-pocket price | Substantial; central to insurance design |
| Pauly welfare triangle | Welfare loss from price-induced overconsumption | Justifies cost-sharing to control utilization |
| Nyman access value | Welfare gain from insurance enabling access to expensive care | Suggests traditional welfare loss is overstated |
| Optimal coinsurance | Balances risk protection against moral hazard cost | Neither 0% nor 100%; depends on service type |
| Value-based insurance design | Cost-sharing varies by clinical value of service | Lower cost-sharing for high-value, higher for low-value |

---

## Physician-Induced Demand

### Theoretical Framework

Physician-induced demand (PID) is the hypothesis that physicians, as agents for their patients, can and do shift the patient's demand curve for medical services to serve the physician's own financial interests. Because of the information asymmetry described in Chapter 1, patients may not be able to distinguish between care that is medically necessary and care that is recommended primarily because it is profitable for the physician.

The theoretical literature on PID is rooted in the target income hypothesis, which posits that physicians have a target level of income and will induce demand when their income falls below this target. In its simplest form, the target income model predicts that an increase in the supply of physicians in a market — which would reduce each physician's patient volume — will lead to an increase in the volume of services per patient as physicians induce demand to maintain their income. This prediction is the opposite of what standard competitive models predict (more supply should reduce price and quantity per provider) and is therefore a distinguishing test of the PID hypothesis.

McGuire (2000) provided the definitive formal treatment of physician agency models. He distinguished between models in which the physician maximizes profit subject to an ethical constraint (a minimum standard of care below which the physician will not go, regardless of financial incentive) and models in which the physician experiences a disutility from deviating from the patient's true best interest. In both formulations, the physician's treatment recommendations are influenced by a combination of the patient's medical needs, the physician's financial incentives, and the physician's ethical standards.

The key formal result is that under fee-for-service payment, the physician has an incentive to recommend services where marginal revenue exceeds marginal cost, even if the marginal benefit to the patient is low. The extent to which the physician acts on this incentive depends on the strength of the ethical constraint and the degree to which patients can monitor and sanction inappropriate recommendations.

### Empirical Evidence

Empirical testing of the PID hypothesis faces severe identification challenges. The core difficulty is that the supply of physicians in an area is endogenous — physicians may locate in areas with high demand, creating a positive correlation between physician supply and utilization that reflects demand-side factors rather than supply-induced demand.

**Area-level studies.** Early studies by Fuchs (1978) and others documented positive correlations between physician density and per-capita healthcare utilization, even after controlling for observable demand-side factors. However, these cross-sectional studies could not distinguish PID from unobserved demand heterogeneity (sicker populations attract more physicians) or availability effects (individuals in physician-rich areas face lower time costs of access and therefore consume more care voluntarily).

**Natural experiments.** More convincing evidence comes from studies exploiting plausibly exogenous variation in physician supply. Gruber and Owings (1996) examined the effect of declining fertility rates on the rate of cesarean sections, reasoning that obstetricians facing reduced delivery volume (due to fewer births) might substitute toward more procedure-intensive delivery modes to maintain income. They found evidence consistent with this prediction, though alternative explanations (changing clinical guidelines, defensive medicine) could not be entirely excluded.

**Payment reform studies.** Studies of physician behavioral responses to fee changes provide indirect evidence on PID. When Medicare reduced fees for certain procedures, some studies found that physicians partially offset the revenue loss by increasing the volume of services — a finding consistent with income targeting. However, the magnitude of the volume response is typically far smaller than would be needed to fully offset the fee reduction, suggesting that income targeting is at most a partial explanation for physician behavior.

**The current consensus.** The health economics literature has not reached a definitive verdict on PID. The weight of evidence suggests that physician financial incentives do influence treatment recommendations at the margin, but that the effect is moderated by professional norms, clinical guidelines, and patient agency. The framing has shifted from the binary question "does PID exist?" to the more nuanced question "how do different payment structures affect the alignment between physician recommendations and patient interests?" — a question central to the design of value-based payment models discussed in Chapter 5.

## Non-Monetary Barriers to Healthcare Access

### Time Costs and Healthcare Demand

The standard demand model focuses on monetary prices, but non-monetary costs — particularly time costs — are important determinants of healthcare utilization. Seeking healthcare requires travel time, waiting time, and time spent in the encounter itself. These time costs represent opportunity costs (foregone wages, household production, or leisure) that are functionally equivalent to monetary prices in their effect on demand.

Acton (1975) provided the foundational theoretical analysis of time costs in healthcare demand. He showed that when out-of-pocket monetary prices are zero or near zero (as in many public insurance programs), time costs become the binding constraint on utilization, and the shadow price of healthcare is determined primarily by the time cost rather than the monetary price.

The empirical implications are significant. Low-income individuals, who have lower hourly wages and thus lower opportunity costs of time, might be expected to have lower time costs per healthcare encounter. However, low-income workers are also less likely to have paid sick leave, flexible work schedules, or the ability to take time off without losing wages. Furthermore, low-income individuals are more likely to rely on public transportation, face longer travel times to providers, and experience longer waiting times at safety-net facilities. The net effect is that time costs may be more burdensome for low-income populations despite their lower hourly wage rates.

### Travel Distance and Geographic Access

Distance to healthcare providers is a critical determinant of utilization, particularly for rural populations. The relationship between distance and utilization has been documented across many service types, including primary care, specialty care, emergency services, and cancer treatment.

Empirical estimates of the distance-utilization gradient vary by service type and population. For primary care, Goodman and colleagues (2003) found that utilization declines significantly with distance, with the gradient steeper for preventive services than for acute care. For specialty services such as cardiac catheterization, the distance gradient is even steeper, contributing to geographic disparities in the use of high-technology procedures.

The policy relevance of distance as a barrier to access is particularly acute in rural areas, where provider shortages and long travel distances compound each other. The economics of rural healthcare access is explored in detail in Chapter 8.

### Wait Times and Rationing by Waiting

In healthcare systems where monetary prices are set below market-clearing levels — either through public insurance with low cost-sharing or through price regulation — excess demand must be rationed by some non-price mechanism. Waiting time serves as the primary non-price rationing mechanism in many healthcare settings, including the US Veterans Health Administration, Canadian provincial health systems, and the UK National Health Service.

From an economic perspective, rationing by waiting is inefficient because the welfare loss from waiting is determined by the patient's opportunity cost of time rather than by the value they place on the medical service. High-wage individuals face higher waiting costs and may opt out of the queued system entirely (by seeking private care or by foregoing care), while low-wage individuals bear the waiting cost. The resulting allocation does not maximize social welfare because it does not allocate services to those who value them most.

However, rationing by waiting has a distributional advantage over rationing by price: because the opportunity cost of time is less steeply correlated with income than ability to pay, waiting-based rationing tends to produce a less unequal distribution of healthcare access than price-based rationing. Whether the efficiency loss from waiting-based rationing exceeds the equity gain is an empirical question that depends on the specific context and the social welfare function.

## Behavioral Economics and Healthcare Demand

### Bounded Rationality in Healthcare Decisions

The standard economic model assumes that individuals make healthcare decisions rationally — they collect and process information efficiently, weigh costs and benefits accurately, and choose the option that maximizes their expected utility. Behavioral economics challenges this assumption by documenting systematic departures from rational decision-making that are particularly relevant in healthcare contexts.

**Information overload and complexity.** Healthcare decisions often involve complex information about risks, probabilities, treatment alternatives, and tradeoffs. Research in behavioral economics demonstrates that individuals make systematic errors when processing probabilistic information: they overweight small probabilities, underweight large probabilities, and are heavily influenced by the framing of risk information. In the context of health insurance choice, the complexity of plan comparison (deductibles, copayments, coinsurance, out-of-pocket maximums, networks, formularies) leads to suboptimal plan selection, with many individuals choosing dominated plans that are strictly worse than available alternatives (Bhargava, Loewenstein, and Sydnor, 2017).

**Present bias and time-inconsistent preferences.** Healthcare decisions frequently involve intertemporal tradeoffs — incurring costs today (exercise, medication adherence, preventive screening) for benefits in the future (reduced disease risk, improved health outcomes). Individuals with present bias (also called hyperbolic discounting) overweight immediate costs relative to future benefits, leading to underinvestment in prevention and poor adherence to treatment regimens. The magnitude of present bias in healthcare decisions has been estimated using both experimental and observational data, with discount rates for health-related decisions substantially exceeding market interest rates.

**Status quo bias and default effects.** Individuals tend to maintain their current state — whether it is a particular insurance plan, medication regimen, or health behavior — even when switching would improve their welfare. In health insurance markets, default effects are powerful: auto-enrollment in employer-sponsored plans significantly affects plan participation and plan selection. The policy implication is that the design of default options can substantially influence healthcare utilization patterns and health outcomes.

### Nudges and Choice Architecture in Healthcare

The insights of behavioral economics have inspired a growing literature on "nudges" — interventions that alter the choice environment to steer individuals toward welfare-improving decisions without restricting choice.

**Medication adherence.** Non-adherence to prescribed medications is a major source of health and economic loss, with estimated costs exceeding $100 billion annually in the United States. Behavioral interventions to improve adherence include simplifying regimens (reducing pill burden and dosing frequency), using commitment devices (deposit contracts where patients forfeit a financial stake if they fail to adhere), providing timely reminders (text messages, automated pill dispensers), and reducing cost-sharing for high-value medications (VBID).

Randomized trials of financial incentive programs for medication adherence have produced mixed results. Volpp and colleagues (2008) found that lottery-based incentives improved warfarin adherence among patients with stroke risk, but the effects attenuated after the incentive was removed. Choudhry and colleagues (2011) demonstrated that eliminating copayments for post-myocardial infarction medications increased adherence and reduced total medical spending, with the cost savings from prevented events offsetting the revenue lost from copayment elimination.

**Insurance plan choice.** The complexity of health insurance markets has led to calls for simplified plan presentation formats, standardized benefit designs, and decision support tools. Kling and colleagues (2012) demonstrated that providing Medicare Part D beneficiaries with personalized information about the cost of their current plan versus alternatives increased switching to lower-cost plans. Handel (2013) estimated that inertia in employer-sponsored insurance plan choice costs employees an average of $2,000 per year, suggesting that interventions to reduce switching costs could yield substantial welfare gains.

**Preventive care utilization.** Default-based nudges have proven effective for increasing preventive care utilization. Making colorectal cancer screening the default option (requiring patients to opt out rather than opt in) substantially increases screening rates. Similarly, pre-scheduling follow-up appointments at the time of the current visit, rather than asking patients to call to schedule, increases follow-through rates for chronic disease management visits.

---

**Table 2.1: Landmark Studies in Healthcare Demand**

| Study | Year | Method | Key Finding |
|---|---|---|---|
| RAND Health Insurance Experiment | 1974-1982 | Randomized experiment | Price elasticity of demand ≈ -0.2; cost-sharing reduces use of both appropriate and inappropriate care |
| Oregon Health Insurance Experiment | 2008- | Lottery-based RCT | Medicaid increases utilization, improves financial protection and mental health; null physical health effect at 2 years |
| Finkelstein et al. (NBER) | 2012 | IV using Oregon lottery | Medicaid increases ED use (contrary to policy expectations) |
| Gruber and Owings | 1996 | Natural experiment | Declining births associated with increased C-section rates (PID evidence) |
| Manning et al. | 1987 | RAND HIE analysis | Demand elasticity estimates by service type; outpatient more elastic than inpatient |
| Choudhry et al. | 2011 | RCT (MI-FREEE trial) | Eliminating copays for post-MI drugs improved adherence, reduced total spending |
| Card, Dobkin, Maestas | 2008 | Regression discontinuity | Medicare eligibility at 65 increases utilization and improves outcomes |
| Bhargava, Loewenstein, Sydnor | 2017 | Observational + experiments | Employees frequently choose dominated health insurance plans |
| Handel | 2013 | Structural estimation | Inertia in plan choice costs average employee ~$2,000/year |
| Acton | 1975 | Theoretical + empirical | Time costs dominate demand when monetary price is zero |

---

## Demand Estimation: Methodological Considerations

### The Endogeneity Challenge

Estimating the demand for healthcare from observational data is fraught with endogeneity problems. The most fundamental challenge is that insurance coverage, which determines the out-of-pocket price of care, is not randomly assigned in the population. Individuals who anticipate higher healthcare needs are more likely to select generous insurance coverage (adverse selection), creating a positive correlation between insurance generosity and utilization that reflects selection rather than a causal price effect.

Similarly, the supply of healthcare services in an area (physician density, hospital bed supply) may be correlated with unobserved demand factors, confounding estimates of the supply-utilization relationship. And individual health behaviors (smoking, exercise, diet) are correlated with socioeconomic characteristics that independently affect healthcare utilization, making it difficult to isolate the causal effect of any single demand determinant.

The experimental evidence from the RAND HIE and Oregon experiment is so valuable precisely because randomization eliminates these endogeneity concerns. In observational settings, the quasi-experimental methods covered in Chapters 10-12 — instrumental variables, difference-in-differences, regression discontinuity — provide the primary tools for addressing endogeneity in demand estimation.

### Functional Form Considerations

Healthcare expenditure data have several distinctive distributional properties that create challenges for demand estimation.

**Mass at zero.** A substantial fraction of individuals in any given period incur zero healthcare expenditures. This creates a mixed distribution — a discrete probability mass at zero combined with a continuous distribution for positive expenditures — that is not well accommodated by standard linear regression. The two-part model, discussed in Chapter 13, addresses this feature by separately modeling the probability of any utilization (extensive margin) and the level of expenditures conditional on positive utilization (intensive margin).

**Right skewness.** Among individuals with positive expenditures, the distribution is heavily right-skewed — a small number of individuals account for a disproportionate share of total spending. In the United States, the top 5% of spenders account for approximately 50% of total healthcare expenditures, while the bottom 50% account for only about 3%. This skewness creates challenges for OLS regression, which is sensitive to extreme values, and motivates the use of GLMs with log link functions and gamma or other skewed error distributions.

**Heterogeneity.** Healthcare demand is highly heterogeneous across individuals, reflecting differences in health status, preferences, information, income, and insurance coverage. Capturing this heterogeneity requires either flexible model specifications that allow demand parameters to vary across subgroups or random-coefficient models that treat demand parameters as draws from a distribution of individual-level values.

### A Worked Demand Estimation Example

Consider estimating the price elasticity of demand for outpatient physician visits using claims data from an employer that offers multiple insurance plans with different copayment levels.

The basic two-part model specification is:

Part 1 (any visit): Pr(Visit > 0 | X) = Φ(β₀ + β₁ × ln(Copay) + β₂ × Age + β₃ × Female + β₄ × Chronic + ε)

Part 2 (number of visits, conditional on at least one): E[Visit | Visit > 0, X] = exp(γ₀ + γ₁ × ln(Copay) + γ₂ × Age + γ₃ × Female + γ₄ × Chronic + u)

The price elasticity of the extensive margin is estimated from Part 1 (the effect of copayment on the probability of any visit), and the price elasticity of the intensive margin is estimated from Part 2 (the effect of copayment on the number of visits among those with at least one visit). The total demand elasticity is the sum of the extensive and intensive margin elasticities.

The endogeneity concern is that plan choice (and therefore copayment level) may be correlated with unobserved health status. Instrumental variables strategies might exploit employer-level variation in plan offerings (employers that offer only high-copayment plans versus those that offer low-copayment plans) or regulatory changes in minimum copayment levels as instruments that are correlated with copayment but plausibly uncorrelated with individual health status.

## Conclusion

The demand for healthcare is shaped by a complex interplay of prices, insurance, income, time costs, information, provider recommendations, and behavioral factors. The experimental evidence from the RAND Health Insurance Experiment and the Oregon Health Insurance Experiment provides the empirical foundation: healthcare demand is price-sensitive (elasticity approximately -0.2), insurance coverage substantially increases utilization and provides important financial protection, and the relationship between coverage and physical health outcomes is more nuanced than simple models predict.

The theoretical frameworks for understanding healthcare demand — from the Grossman model of health capital to the moral hazard analysis of Pauly and Nyman to the behavioral economics of bounded rationality and present bias — provide the intellectual structure for interpreting empirical findings and designing policy interventions. The key tension in healthcare demand policy is between the welfare gain from insurance protection (financial risk reduction, access to high-value care) and the welfare loss from moral hazard (price-induced overconsumption of low-value services).

The econometric challenges of demand estimation — endogeneity, selection bias, non-standard distributions — motivate the methodological tools developed in subsequent chapters: instrumental variables (Chapter 10), regression discontinuity (Chapter 12), and the specialized count data and expenditure models of Chapter 13. The Julia implementations of these methods in Chapters 19-24 will provide the computational infrastructure for putting these tools into practice.

## References

1. Acton, J. P. (1975). Nonmonetary factors in the demand for medical services: Some empirical evidence. *Journal of Political Economy*, 83(3), 595-614.

2. Bhargava, S., Loewenstein, G., & Sydnor, J. (2017). Choose to lose: Health plan choices from a menu with dominated options. *Quarterly Journal of Economics*, 132(3), 1319-1372.

3. Card, D., Dobkin, C., & Maestas, N. (2008). The impact of nearly universal insurance coverage on health care utilization: Evidence from Medicare. *American Economic Review*, 98(5), 2242-2258.

4. Choudhry, N. K., Avorn, J., Glynn, R. J., Antman, E. M., Schneeweiss, S., Toscano, M., ... & Shrank, W. H. (2011). Full coverage for preventive medications after myocardial infarction. *New England Journal of Medicine*, 365(22), 2088-2097.

5. Dave, D., & Kaestner, R. (2009). Health insurance and ex ante moral hazard: Evidence from Medicare. *International Journal of Health Care Finance and Economics*, 9(4), 367-390.

6. Einav, L., Finkelstein, A., & Cullen, M. R. (2010). Estimating welfare in insurance markets using variation in prices. *Quarterly Journal of Economics*, 125(3), 877-921.

7. Finkelstein, A., Taubman, S., Wright, B., Bernstein, M., Gruber, J., Newhouse, J. P., ... & Baicker, K. (2012). The Oregon Health Insurance Experiment: Evidence from the first year. *Quarterly Journal of Economics*, 127(3), 1057-1106.

8. Fuchs, V. R. (1978). The supply of surgeons and the demand for operations. *Journal of Human Resources*, 13(Supplement), 35-56.

9. Getzen, T. E. (2000). Health care is an individual necessity and a national luxury: Applying multilevel decision models to the analysis of health care expenditures. *Journal of Health Economics*, 19(2), 259-270.

10. Grossman, M. (1972). On the concept of health capital and the demand for health. *Journal of Political Economy*, 80(2), 223-255.

11. Gruber, J., & Owings, M. (1996). Physician financial incentives and cesarean section delivery. *RAND Journal of Economics*, 27(1), 99-123.

12. Handel, B. R. (2013). Adverse selection and inertia in health insurance markets: When nudging hurts. *American Economic Review*, 103(7), 2643-2682.

13. Kling, J. R., Mullainathan, S., Shafir, E., Vermeulen, L. C., & Wrobel, M. V. (2012). Comparison friction: Experimental evidence from Medicare drug plans. *Quarterly Journal of Economics*, 127(1), 199-235.

14. Lohr, K. N., Brook, R. H., Kamberg, C. J., Goldberg, G. A., Leibowitz, A., Keesey, J., ... & Newhouse, J. P. (1986). Use of medical care in the RAND Health Insurance Experiment: Diagnosis- and service-specific analyses in a randomized controlled trial. *Medical Care*, 24(9), S1-S87.

15. Manning, W. G., Newhouse, J. P., Duan, N., Keeler, E. B., & Leibowitz, A. (1987). Health insurance and the demand for medical care: Evidence from a randomized experiment. *American Economic Review*, 77(3), 251-277.

16. McGuire, T. G. (2000). Physician agency. In A. J. Culyer & J. P. Newhouse (Eds.), *Handbook of Health Economics* (Vol. 1A, pp. 461-536). Elsevier.

17. Nyman, J. A. (2003). *The Theory of Demand for Health Insurance*. Stanford University Press.

18. Pauly, M. V. (1968). The economics of moral hazard: Comment. *American Economic Review*, 58(3), 531-537.

19. Volpp, K. G., Loewenstein, G., Troxel, A. B., Doshi, J., Price, M., Laskin, M., & Kimmel, S. E. (2008). A test of financial incentives to improve warfarin adherence. *BMC Health Services Research*, 8(1), 272.

20. Zeckhauser, R. (1970). Medical insurance: A case study of the tradeoff between risk spreading and appropriate incentives. *Journal of Economic Theory*, 2(1), 10-26.
