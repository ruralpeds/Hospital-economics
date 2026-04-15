# Chapter 6: Cost-Effectiveness Analysis and Health Technology Assessment

## Introduction

Every healthcare system faces the fundamental problem of scarcity: the resources available for healthcare are finite, but the potential applications of medical technology are virtually unlimited. Cost-effectiveness analysis (CEA) and its related methods provide the analytical framework for making principled resource allocation decisions — determining which interventions offer sufficient value to justify their cost and which represent poor uses of limited healthcare resources. In an era when a single course of gene therapy can cost $3.5 million, when new cancer immunotherapies extend median survival by weeks at costs exceeding $150,000 per year, and when the United States spends over $4.8 trillion annually on healthcare, the ability to systematically evaluate the economic value of healthcare interventions is not merely an academic exercise but an urgent policy necessity.

Economic evaluation in healthcare has matured into a sophisticated discipline with well-established methods, professional standards, and institutional infrastructure. The Second Panel on Cost-Effectiveness in Health and Medicine (Sanders et al., 2016) updated methodological recommendations that have become the de facto standard for US-based CEA. The Institute for Clinical and Economic Review (ICER) has emerged as the most prominent independent body conducting cost-effectiveness assessments of new therapies in the United States. And the growing adoption of value-based pricing frameworks by payers and pharmacy benefit managers has created direct linkages between CEA results and coverage and reimbursement decisions.

This chapter provides a comprehensive treatment of economic evaluation methods for graduate health economics researchers. We cover the four types of economic evaluation, the measurement of costs and health outcomes, the incremental cost-effectiveness ratio, decision-analytic modeling, sensitivity analysis, willingness-to-pay thresholds, budget impact analysis, and a complete worked example that illustrates the entire CEA workflow from problem formulation through decision recommendation. The computational implementation of these methods in Julia is covered in Chapter 23.

## Types of Economic Evaluation

### Cost-Minimization Analysis

Cost-minimization analysis (CMA) is the simplest form of economic evaluation, applicable only when two or more interventions have been demonstrated to produce equivalent health outcomes. Under this assumption, the decision reduces to identifying the least costly alternative. CMA requires strong evidence of clinical equivalence — ideally from a well-powered non-inferiority trial — and is appropriate for comparisons such as generic vs. brand-name drugs with established bioequivalence, or alternative surgical approaches with demonstrated equivalent outcomes.

In practice, CMA is rarely appropriate because true clinical equivalence is difficult to establish and because even small differences in outcomes may be economically important when applied to large populations. The method has declined in use as the field has moved toward CEA and cost-utility analysis, which can accommodate small differences in both costs and outcomes.

### Cost-Effectiveness Analysis

Cost-effectiveness analysis (CEA) compares interventions in terms of their incremental cost per unit of health outcome achieved. The outcome measure is expressed in natural clinical units — life-years gained, cases detected, hospitalizations prevented, infections averted, millimeters of mercury blood pressure reduction. CEA is appropriate when comparing interventions within a single disease area where a single clinical outcome measure is dominant.

The primary limitation of CEA with natural units is that it does not permit comparisons across disease areas. An intervention that costs $50,000 per life-year gained for cancer cannot be directly compared with an intervention that costs $30,000 per case of depression averted, because the outcome units are incommensurable. This limitation motivates cost-utility analysis.

### Cost-Utility Analysis

Cost-utility analysis (CUA) is a specific form of CEA in which health outcomes are measured in quality-adjusted life years (QALYs), a composite metric that incorporates both length of life and health-related quality of life into a single index. Because QALYs are a generic outcome measure applicable across all disease areas, CUA enables comparison of value across the full spectrum of healthcare interventions — from screening programs to surgical procedures to pharmaceutical therapies to public health interventions.

CUA has become the dominant form of economic evaluation in health economics, and the terms "cost-effectiveness analysis" and "cost-utility analysis" are often used interchangeably in practice (with the understanding that QALYs are the outcome measure). The Second Panel on Cost-Effectiveness in Health and Medicine recommends CUA with QALYs as the reference case for all economic evaluations.

### Cost-Benefit Analysis

Cost-benefit analysis (CBA) measures both costs and outcomes in monetary terms, allowing a direct comparison of the total benefits and total costs of an intervention. If benefits exceed costs, the intervention passes the Kaldor-Hicks compensation test (discussed in Chapter 1) and is considered economically efficient.

The principal challenge of CBA in healthcare is the need to assign monetary values to health outcomes — a life-year, a QALY, a statistical life. The value of a statistical life (VSL), estimated from labor market studies of wage-risk tradeoffs and from stated preference studies, ranges from approximately $7 million to $12 million in the United States. The monetary value of a QALY can be derived from the VSL, yielding estimates of approximately $100,000 to $300,000 per QALY.

CBA has the theoretical advantage of providing a definitive yes/no answer (do benefits exceed costs?) without requiring an external willingness-to-pay threshold. However, the necessity of monetizing health outcomes is ethically controversial and methodologically uncertain, and CBA has been less widely adopted in healthcare than in other policy domains (transportation, environmental regulation) where monetization of outcomes is more established.

## Measuring Costs

### Perspective and Cost Categories

The perspective of an economic evaluation determines which costs are included. The Second Panel recommends that all CEAs include a reference case analysis from the healthcare sector perspective and, when relevant, a supplemental analysis from the societal perspective.

**Healthcare sector perspective.** This perspective includes all direct medical costs borne by the healthcare system, regardless of who pays: hospitalizations, physician visits, medications, laboratory tests, imaging studies, rehabilitation services, long-term care, and other healthcare services consumed as a result of the intervention and its downstream consequences. This perspective is most relevant for payers making coverage and formulary decisions.

**Societal perspective.** This perspective includes all costs regardless of who bears them: healthcare costs, patient time costs (travel, waiting, treatment time), caregiver time costs, productivity losses due to morbidity and mortality (the "friction cost" or "human capital" approach), and non-healthcare sector costs (criminal justice, education, social services). The societal perspective is most relevant for broad policy evaluation but is more difficult to implement comprehensively and introduces greater uncertainty.

### Micro-Costing vs. Gross-Costing

**Micro-costing** (bottom-up costing) identifies and values each individual resource consumed in delivering an intervention. The analyst catalogs every input — minutes of operating room time, units of each medication, nursing hours, supplies, equipment depreciation — and multiplies each by its unit cost. Micro-costing provides the most accurate cost estimates but is labor-intensive and may not be feasible for complex interventions delivered across multiple settings.

**Gross-costing** (top-down costing) assigns costs based on aggregate cost data, such as average cost per hospital day, average cost per DRG, or average cost per outpatient visit. Gross-costing uses readily available administrative data (claims, cost reports) but may obscure important variation in resource use across patients and settings.

In practice, most CEAs use a combination: micro-costing for the intervention itself (where resource use is well-characterized) and gross-costing for downstream healthcare utilization (where claims data provide adequate cost estimates).

### Time Horizon and Discounting

The time horizon of a CEA should be long enough to capture all relevant costs and outcomes of the intervention. For acute interventions (surgery, short-course antibiotics), a short time horizon may be adequate. For chronic disease interventions (statins for cardiovascular prevention, screening programs), a lifetime time horizon is typically necessary because the costs and benefits accrue over decades.

When costs and outcomes occur over different time periods, they must be discounted to present value to reflect the time value of money and time preference. The Second Panel recommends a discount rate of 3% per year for both costs and health outcomes, with sensitivity analyses at 0% and 7%. The use of the same discount rate for costs and outcomes is debated — some economists argue that health outcomes should be discounted at a lower rate than costs, reflecting a societal preference for health that differs from financial time preference — but equal discounting remains the standard recommendation.

### Handling Inflation and Currency

Costs should be reported in a consistent currency year (e.g., 2024 US dollars). When costs are drawn from different years, they should be inflated or deflated to the reference year using an appropriate price index. For healthcare costs, the Consumer Price Index for Medical Care (CPI-M) or the Personal Health Care (PHC) deflator from the NHEA is appropriate. For general costs, the GDP deflator or the all-items CPI is used.

When costs from different countries must be compared or converted, purchasing power parities (PPPs) for health are preferred over market exchange rates, because PPPs account for differences in the relative prices of healthcare inputs across countries.

## Measuring Health Outcomes

### Quality-Adjusted Life Years

The quality-adjusted life year (QALY) combines survival duration and health-related quality of life (HRQoL) into a single metric. One QALY represents one year of life lived in perfect health. A year lived in a health state with utility weight 0.7 generates 0.7 QALYs; death is assigned a utility weight of 0; and health states considered worse than death receive negative utility weights.

Total QALYs for an individual over a time period are calculated as:

QALYs = Σₜ uₜ × Δtₜ

where uₜ is the utility weight for the health state at time t and Δtₜ is the duration of time spent in that health state. When discounting is applied:

Discounted QALYs = Σₜ uₜ × Δtₜ / (1 + r)ᵗ

where r is the annual discount rate.

### Utility Elicitation Methods

Utility weights are elicited using preference-based methods that ask individuals to value health states on a 0-1 scale (where 0 = death and 1 = perfect health). Three direct elicitation methods are widely used:

**Standard gamble (SG).** The respondent chooses between certain life in the health state being valued and a gamble between perfect health (with probability p) and death (with probability 1-p). The probability p at which the respondent is indifferent between the certain and uncertain options is the utility weight. The SG is grounded directly in von Neumann-Morgenstern expected utility theory and is considered the gold standard for preference elicitation, but it is cognitively demanding and may be influenced by risk attitudes.

**Time trade-off (TTO).** The respondent indicates how many years of life in the health state being valued they would trade for fewer years in perfect health. If the respondent is indifferent between 10 years in the health state and 7 years in perfect health, the utility weight is 0.7. TTO is simpler than SG and avoids the risk attitude confound, but it may be influenced by time preference.

**Visual analogue scale (VAS).** The respondent rates the health state on a thermometer-like scale from 0 (worst imaginable health) to 100 (best imaginable health). VAS is the simplest method but is not preference-based (it measures perception of severity rather than the trade-offs individuals would make) and typically produces higher values than SG or TTO.

### Multi-Attribute Utility Instruments

In practice, most CEAs obtain utility weights from standardized multi-attribute utility instruments (MAUIs) rather than direct elicitation. These instruments describe health states using a multi-dimensional classification system and apply a pre-estimated scoring algorithm (derived from community preference surveys) to convert the classification into a utility weight.

**EQ-5D** is the most widely used MAUI globally. The EQ-5D-5L version classifies health along five dimensions — mobility, self-care, usual activities, pain/discomfort, and anxiety/depression — each with five severity levels, generating 3,125 unique health states. US-specific value sets derived from TTO and discrete choice experiments are available, with utility weights ranging from approximately -0.11 (worst health state) to 1.0 (full health).

**SF-6D** is derived from the SF-36 health survey and classifies health along six dimensions — physical functioning, role limitation, social functioning, pain, mental health, and vitality — each with four to six levels. The SF-6D is useful when SF-36 data have already been collected in clinical trials.

**Health Utilities Index (HUI)** is available in two versions (HUI2 and HUI3) that classify health using seven to eight attributes. HUI3 includes vision, hearing, speech, ambulation, dexterity, emotion, cognition, and pain, providing more detailed functional assessment than EQ-5D.

The choice of MAUI can affect CEA results because the instruments differ in their dimensional coverage, severity ranges, and scoring algorithms. The Second Panel recommends reporting the instrument used and conducting sensitivity analyses with alternative instruments when feasible.

### Disability-Adjusted Life Years

The disability-adjusted life year (DALY) is an alternative summary health measure used primarily in global health contexts, particularly by the World Health Organization and the Global Burden of Disease (GBD) study. DALYs measure health loss rather than health gain:

DALYs = YLL + YLD

where YLL (years of life lost) measures premature mortality relative to a reference life expectancy, and YLD (years lived with disability) measures the burden of living with a health condition, weighted by a disability weight between 0 (perfect health) and 1 (death).

DALYs and QALYs are conceptually related but differ in several important respects. QALYs measure health gained (higher is better); DALYs measure health lost (lower is better). QALY utility weights are preference-based (derived from individual trade-off exercises); DALY disability weights are assigned by expert panels using a different methodology. For domestic US CEA, QALYs are the standard outcome measure; DALYs are more commonly used in global health economic evaluations.

---

**Key Concepts Box: Measuring Health Outcomes in Economic Evaluation**

| Measure | What It Captures | Valuation Method | Primary Use |
|---|---|---|---|
| Life-years gained | Survival duration only | None (objective measure) | Disease-specific CEA |
| QALYs | Survival × quality of life | Preference-based (SG, TTO, EQ-5D) | Reference case CEA/CUA |
| DALYs | Years lost to mortality + disability | Expert panel disability weights | Global health CEA, GBD |
| Willingness to pay | Monetary value of health gain | Contingent valuation, revealed preference | Cost-benefit analysis |

---

## The Incremental Cost-Effectiveness Ratio

### Calculation and Interpretation

The incremental cost-effectiveness ratio (ICER) is the primary summary measure in CEA. For a new intervention compared to a comparator (typically current standard of care), the ICER is:

ICER = (C_new - C_comparator) / (E_new - E_comparator) = ΔC / ΔE

where C represents total discounted costs and E represents total discounted health outcomes (typically QALYs). The ICER represents the additional cost per additional unit of health outcome achieved by adopting the new intervention.

Interpretation of the ICER requires an external benchmark — a willingness-to-pay (WTP) threshold λ representing the maximum amount the decision-maker is willing to pay per unit of health outcome. If the ICER is below the WTP threshold (ICER < λ), the intervention is considered cost-effective. If the ICER exceeds the threshold (ICER > λ), the intervention is not cost-effective.

### The Cost-Effectiveness Plane

The cost-effectiveness plane is a graphical representation of the joint distribution of incremental costs (vertical axis) and incremental effects (horizontal axis). The four quadrants correspond to four decision scenarios:

**Northeast quadrant (ΔC > 0, ΔE > 0).** The new intervention is more effective and more costly. The decision depends on whether the ICER is below the WTP threshold. This is the most common scenario for new medical technologies.

**Southeast quadrant (ΔC < 0, ΔE > 0).** The new intervention is more effective and less costly — it dominates the comparator. The decision is straightforward: adopt the new intervention. This scenario is less common but occurs for some preventive interventions and efficiency-improving innovations.

**Northwest quadrant (ΔC > 0, ΔE < 0).** The new intervention is less effective and more costly — it is dominated by the comparator. The decision is straightforward: reject the new intervention.

**Southwest quadrant (ΔC < 0, ΔE < 0).** The new intervention is less costly but also less effective. The decision depends on whether the cost savings justify the health loss, evaluated against the WTP threshold.

### Dominance and Extended Dominance

When comparing more than two alternatives, simple dominance and extended dominance help narrow the set of efficient options.

**Simple dominance** occurs when one alternative is both more effective and less costly than another. The dominated alternative should be eliminated from consideration regardless of the WTP threshold.

**Extended dominance** occurs when an alternative is dominated by a linear combination of two other alternatives — the dominated alternative falls below the efficiency frontier connecting the remaining options. Extended dominance is identified by calculating ICERs sequentially from least effective to most effective and eliminating any alternative whose ICER is higher than that of a more effective alternative.

The remaining alternatives after eliminating dominated and extendedly dominated options define the efficiency frontier — the set of alternatives that represent the best value at some WTP threshold.

## Willingness-to-Pay Thresholds

### The $50,000-$150,000 Per QALY Range

The most commonly cited WTP thresholds in US-based CEA range from $50,000 to $150,000 per QALY. The $50,000 threshold has been widely used since the 1990s, though its empirical basis is weak — it has been attributed to the approximate cost per QALY of renal dialysis at the time Medicare coverage was extended to dialysis patients in 1972, though this origin story is largely apocryphal.

The Second Panel on Cost-Effectiveness recommended against a single fixed threshold, instead suggesting that decision-makers consider a range of thresholds and examine how the decision changes across the range. Neumann, Cohen, and Weinstein (2014) argued that WTP thresholds of $100,000 to $150,000 per QALY are more consistent with the values revealed by existing healthcare spending patterns and by estimates of the value of a statistical life.

### Empirical Approaches to Threshold Estimation

Several approaches have been used to estimate empirically appropriate WTP thresholds:

**The supply-side threshold (opportunity cost approach).** This approach estimates the health that is displaced when resources are diverted to fund a new intervention. If the marginal cost of producing a QALY through the existing healthcare system is $30,000, then funding a new intervention with an ICER above $30,000 per QALY will displace more health than it produces — a net health loss. Claxton and colleagues (2015) estimated the supply-side threshold for the English NHS at approximately £13,000 per QALY, substantially below the NICE threshold of £20,000-£30,000. Equivalent US estimates are not well-established but would likely be higher given higher US healthcare spending per capita.

**The demand-side threshold (value of health approach).** This approach uses estimates of individuals' willingness to pay for health gains, derived from stated preference surveys or from the value of a statistical life. These estimates generally yield higher thresholds — $100,000 to $300,000 per QALY — reflecting the full consumption value of health rather than the marginal opportunity cost of healthcare spending.

**The NICE threshold.** The UK National Institute for Health and Care Excellence uses a WTP threshold of £20,000-£30,000 per QALY (approximately $25,000-$38,000) for standard health technologies, with a higher threshold of up to £50,000 per QALY for end-of-life treatments and treatments for very rare conditions. NICE's threshold is considerably lower than commonly used US thresholds, reflecting both the UK's lower per-capita healthcare spending and its explicit commitment to opportunity cost-based resource allocation.

## Decision-Analytic Modeling

### Decision Trees

Decision trees are the simplest form of decision-analytic model, representing a sequential decision problem as a branching structure in which each node represents either a decision (square node), a chance event (circle node), or an outcome (triangle/terminal node). Probabilities are assigned to each branch emanating from chance nodes, and costs and outcomes are assigned to terminal nodes.

The expected value of each strategy is calculated by "rolling back" the tree — multiplying outcomes by probabilities at each chance node and summing across branches. The strategy with the highest expected net benefit (or lowest ICER relative to the WTP threshold) is preferred.

Decision trees are appropriate for acute clinical decisions with a limited number of events and a short time horizon — for example, the choice between immediate surgery and watchful waiting for a suspected appendicitis, or the comparison of two diagnostic testing strategies. They are less suitable for chronic disease modeling because they cannot easily represent recurring events, disease progression over time, or feedback loops.

### Markov Models

Markov cohort models are the workhorse of chronic disease CEA. A Markov model represents disease progression as a series of discrete health states (e.g., healthy, mild disease, severe disease, dead), with transitions between states occurring at fixed time intervals (cycle lengths, typically one month or one year). The model tracks a hypothetical cohort as it transitions among health states over the analysis time horizon.

The key elements of a Markov model are:

**Health states.** These must be mutually exclusive and collectively exhaustive — every individual in the cohort must be in exactly one state at each time point. States should be clinically meaningful and should differ in either costs or utilities (otherwise they should be combined).

**Transition probabilities.** A transition probability matrix P specifies the probability of moving from each state to each other state during one cycle. If there are n health states, P is an n × n matrix where entry pᵢⱼ is the probability of transitioning from state i to state j, and each row sums to 1.

**State rewards.** Each health state is assigned a cost per cycle and a utility weight. As the cohort moves through the model, costs and QALYs accumulate based on the proportion of the cohort in each state and the rewards associated with each state.

**Cycle correction.** Because transitions occur continuously but are modeled at discrete intervals, a cycle correction (half-cycle correction or Simpson's rule) adjusts for the timing of events within each cycle. The half-cycle correction assumes that, on average, transitions occur at the midpoint of the cycle.

The output of a Markov model is the expected total discounted cost and expected total discounted QALYs for each strategy, from which ICERs are calculated.

### Microsimulation

Microsimulation (individual-level simulation) models track individual patients rather than cohorts, allowing for individual-level heterogeneity, memory of prior events, and more complex disease progression pathways than Markov cohort models can accommodate.

In a microsimulation, each simulated individual is assigned baseline characteristics (age, sex, risk factors), and the model simulates their disease trajectory event by event, drawing from probability distributions at each decision point. Because individual outcomes are stochastic, the simulation must be run for a large number of individuals (typically 10,000 to 1,000,000) to achieve stable estimates of expected costs and outcomes.

Microsimulation offers several advantages over Markov cohort models: it can incorporate patient heterogeneity (different transition probabilities for different patient types), it can model memory (transition probabilities that depend on the history of prior events, not just the current state), and it can accommodate complex interventions that affect individuals differently based on their characteristics or history. The disadvantage is computational intensity — microsimulation requires substantially more computation time than cohort models, particularly when combined with probabilistic sensitivity analysis.

### Discrete Event Simulation

Discrete event simulation (DES) models time as a continuous variable rather than discrete cycles, with events occurring at irregular time points determined by sampling from time-to-event distributions. DES is particularly useful for modeling queuing and resource constraints (e.g., operating room capacity, ICU bed availability) and for situations where the timing of events matters (e.g., sequential treatments with variable waiting times).

DES has seen increasing use in health economics, particularly for modeling healthcare delivery processes (emergency department flow, surgical scheduling) and for capturing the interaction between disease progression and healthcare system capacity constraints.

## Sensitivity Analysis

### One-Way Sensitivity Analysis

One-way sensitivity analysis (OWSA) varies a single parameter across its plausible range while holding all other parameters at their base-case values, producing a range of ICERs that illustrates the sensitivity of the result to uncertainty in that parameter. The results are typically displayed as a tornado diagram, with parameters arranged by their influence on the ICER, from most influential (widest bar) to least influential (narrowest bar).

OWSA identifies the parameters that are most critical to the decision and that should receive the greatest attention in data collection and validation. However, it has the limitation of varying only one parameter at a time, ignoring correlations among parameters and the simultaneous effect of uncertainty in multiple parameters.

### Probabilistic Sensitivity Analysis

Probabilistic sensitivity analysis (PSA) is the current standard for characterizing decision uncertainty in CEA. PSA assigns a probability distribution to each uncertain parameter, then draws simultaneously from all distributions using Monte Carlo simulation to generate a joint distribution of incremental costs and incremental effects.

The distributional assumptions for PSA follow conventions that reflect the mathematical properties of different parameter types:

**Probabilities** are assigned beta distributions (bounded between 0 and 1).

**Relative risks and hazard ratios** are assigned log-normal distributions (bounded above 0, right-skewed).

**Costs** are assigned gamma distributions (bounded above 0, right-skewed) or log-normal distributions.

**Utility weights** are assigned beta distributions (bounded between 0 and 1).

The PSA output is a scatter plot of simulated (ΔC, ΔE) pairs on the cost-effectiveness plane, from which the cost-effectiveness acceptability curve (CEAC) is derived. The CEAC plots the probability that the intervention is cost-effective as a function of the WTP threshold, providing a complete characterization of decision uncertainty.

### Value of Information Analysis

Value of information (VOI) analysis quantifies the expected value of reducing decision uncertainty through additional research. The expected value of perfect information (EVPI) is the maximum amount a decision-maker should be willing to pay for a study that would eliminate all parameter uncertainty — it equals the expected cost of making a wrong decision under current information.

EVPI is calculated from the PSA output:

EVPI = E_θ[max_d NB(d, θ)] - max_d E_θ[NB(d, θ)]

where NB(d, θ) is the net benefit of decision d given parameter values θ. The first term is the expected net benefit under perfect information (choosing the best decision for each parameter draw), and the second term is the expected net benefit under current information (choosing the decision that is best on average).

The expected value of partial perfect information (EVPPI) extends this analysis to individual parameters or groups of parameters, identifying which parameters would be most valuable to resolve through additional research. The expected value of sample information (EVSI) further refines the analysis by estimating the value of a specific feasible study design (with specified sample size, follow-up duration, and endpoints) rather than the idealized case of perfect information.

VOI analysis is increasingly used to inform research prioritization and clinical trial design, providing a formal framework for deciding whether the cost of additional research is justified by the expected value of the information it would produce.

## Budget Impact Analysis

### Purpose and Relationship to CEA

Budget impact analysis (BIA) addresses a different question than CEA. While CEA asks "is this intervention good value for money?" (an efficiency question), BIA asks "can we afford it?" (a financial feasibility question). An intervention can be highly cost-effective (low ICER) yet have a large budget impact if it is applicable to a large population, and conversely, an intervention with a high ICER may have a small budget impact if it applies to a rare condition.

BIA estimates the financial consequences of adopting a new intervention from the perspective of a specific payer over a defined time horizon (typically one to five years). The analysis compares total healthcare spending under the current treatment mix (the "current scenario") with spending under the new treatment mix following adoption (the "new scenario"), accounting for the eligible population, expected uptake rate, displacement of existing treatments, and any downstream cost offsets.

### BIA Methodology

The International Society for Pharmacoeconomics and Outcomes Research (ISPOR) has published guidelines for BIA that recommend:

1. Define the eligible population based on epidemiological data (prevalence, incidence, diagnosis rates).
2. Estimate the market uptake trajectory for the new intervention over the analysis horizon.
3. Calculate the per-patient cost difference between the new intervention and displaced treatments.
4. Multiply per-patient cost differences by the number of patients expected to receive the new intervention in each year.
5. Include cost offsets from reduced utilization of other healthcare services (hospitalizations averted, complications prevented).
6. Present results as the incremental budget impact in each year and cumulatively over the analysis horizon.

BIA results are highly sensitive to assumptions about market uptake speed, eligible population size, and cost offsets, and should be presented with uncertainty ranges.

## A Complete CEA Example

### Problem Formulation

Consider a hypothetical CEA comparing a new pharmacogenomic-guided statin therapy selection strategy (PGx-guided) with standard empiric statin prescribing for secondary prevention of cardiovascular events in patients with established coronary artery disease.

The PGx-guided strategy involves genetic testing (cost: $250 per test) to identify patients with genetic variants associated with statin intolerance or differential response, enabling personalized statin selection that improves adherence and reduces adverse events. The standard strategy prescribes high-intensity statins without genetic testing, with dose adjustment based on clinical response and tolerability.

### Model Structure

A Markov cohort model with annual cycles and a lifetime time horizon (age 65 at entry, maximum age 100) is constructed with five health states: stable coronary artery disease, post-myocardial infarction (first year), post-stroke (first year), chronic post-event, and dead. Transition probabilities are derived from published cardiovascular outcome trials and observational cohort studies. The PGx-guided strategy reduces the annual probability of statin discontinuation (from 15% to 5%) and improves adherence-adjusted cardiovascular risk reduction.

### ICER Calculation

After running the Markov model with base-case parameter values:

PGx-guided strategy: Total cost = $87,500; Total QALYs = 8.45
Standard strategy: Total cost = $82,200; Total QALYs = 8.21

ICER = ($87,500 - $82,200) / (8.45 - 8.21) = $5,300 / 0.24 = $22,083 per QALY

At a WTP threshold of $100,000 per QALY, the PGx-guided strategy is cost-effective.

### Sensitivity Analysis Results

One-way sensitivity analysis identifies statin discontinuation rate in the standard arm, the cost of genetic testing, and the cardiovascular event rate as the most influential parameters. PSA with 10,000 Monte Carlo draws shows that the PGx-guided strategy is cost-effective in 87% of simulations at a $50,000/QALY threshold and 94% at $100,000/QALY. EVPI analysis suggests that additional research to better characterize the statin discontinuation rate would have the highest expected value of information.

---

**Table 6.1: Recommended Distributional Assumptions for PSA**

| Parameter Type | Recommended Distribution | Rationale | Parameterization |
|---|---|---|---|
| Probabilities | Beta | Bounded [0,1]; conjugate for binomial | α = events, β = non-events |
| Relative risks | Log-normal | Bounded (0,∞); multiplicative scale | μ = ln(RR), σ from 95% CI |
| Costs | Gamma | Bounded [0,∞); right-skewed | α = (mean/SE)², β = SE²/mean |
| Utility weights | Beta | Bounded [0,1]; left-skewed typical | α, β from mean and variance |
| Hazard ratios | Log-normal | Bounded (0,∞); multiplicative | μ = ln(HR), σ from 95% CI |

---

## Conclusion

Cost-effectiveness analysis provides the systematic framework for evaluating whether healthcare interventions represent good value for the resources they consume. The methodology has matured substantially since the First Panel on Cost-Effectiveness in Health and Medicine (1996), with well-established standards for cost measurement, QALY calculation, decision-analytic modeling, and uncertainty quantification. The Second Panel's (2016) updated recommendations — including the dual-perspective reference case, the impact inventory for cost identification, and the emphasis on PSA and VOI analysis — represent the current methodological standard.

The practical influence of CEA on healthcare decision-making in the United States is growing but remains more limited than in countries with formal health technology assessment bodies (NICE in the UK, CADTH in Canada, PBAC in Australia). The lack of a centralized US body with authority to make coverage decisions based on cost-effectiveness evidence reflects both political resistance to "rationing" and the fragmented multi-payer structure of the US system. However, the emergence of ICER as an influential independent evaluator, the increasing use of CEA evidence by pharmacy benefit managers and health plans, and the growing interest in value-based pricing frameworks suggest that CEA will play an expanding role in US healthcare resource allocation.

The computational implementation of CEA methods — decision trees, Markov models, microsimulation, PSA, and VOI analysis — in Julia is covered in Chapter 23, which provides production-ready code for every model type discussed in this chapter.

## References

1. Briggs, A. H., Claxton, K., & Sculpher, M. J. (2006). *Decision Modelling for Health Economic Evaluation*. Oxford University Press.

2. Claxton, K., Martin, S., Soares, M., Rice, N., Spackman, E., Hinde, S., ... & Sculpher, M. (2015). Methods for the estimation of the National Institute for Health and Care Excellence cost-effectiveness threshold. *Health Technology Assessment*, 19(14), 1-503.

3. Drummond, M. F., Sculpher, M. J., Claxton, K., Stoddart, G. L., & Torrance, G. W. (2015). *Methods for the Economic Evaluation of Health Care Programmes* (4th ed.). Oxford University Press.

4. Gold, M. R., Siegel, J. E., Russell, L. B., & Weinstein, M. C. (Eds.). (1996). *Cost-Effectiveness in Health and Medicine*. Oxford University Press.

5. Herdman, M., Gudex, C., Lloyd, A., Janssen, M., Kind, P., Parkin, D., ... & Badia, X. (2011). Development and preliminary testing of the new five-level version of EQ-5D (EQ-5D-5L). *Quality of Life Research*, 20(10), 1727-1736.

6. Neumann, P. J., Cohen, J. T., & Weinstein, M. C. (2014). Updating cost-effectiveness — the curious resilience of the $50,000-per-QALY threshold. *New England Journal of Medicine*, 371(9), 796-797.

7. Neumann, P. J., Sanders, G. D., Russell, L. B., Siegel, J. E., & Ganiats, T. G. (Eds.). (2017). *Cost-Effectiveness in Health and Medicine* (2nd ed.). Oxford University Press.

8. Petrou, S., & Gray, A. (2011). Economic evaluation alongside randomised controlled trials: Design, conduct, analysis, and reporting. *BMJ*, 342, d1548.

9. Sanders, G. D., Neumann, P. J., Basu, A., Brock, D. W., Feeny, D., Krahn, M., ... & Ganiats, T. G. (2016). Recommendations for conduct, methodological practices, and reporting of cost-effectiveness analyses: Second panel on cost-effectiveness in health and medicine. *JAMA*, 316(10), 1093-1103.

10. Sculpher, M. J., Claxton, K., Drummond, M., & McCabe, C. (2006). Whither trial-based economic evaluation for health care decision making? *Health Economics*, 15(7), 677-687.

11. Stinnett, A. A., & Mullahy, J. (1998). Net health benefits: A new framework for the analysis of uncertainty in cost-effectiveness analysis. *Medical Decision Making*, 18(2 Suppl), S68-S80.

12. Weinstein, M. C., Torrance, G., & McGuire, A. (2009). QALYs: The basics. *Value in Health*, 12(Suppl 1), S5-S9.
