# Chapter 4: Health Insurance Economics and Market Design

## Introduction

Health insurance is the institutional mechanism through which most Americans finance their healthcare consumption, and the economics of insurance markets — adverse selection, moral hazard, risk pooling, optimal contract design, and market regulation — constitute one of the richest and most policy-relevant subfields of health economics. The design of health insurance systems shapes who receives care, how much care they receive, what they pay for it, and how the financial risk of illness is distributed across the population. Understanding insurance economics is therefore prerequisite to understanding virtually every other topic in this textbook.

The United States health insurance system is distinctive among high-income nations in its complexity, fragmentation, and reliance on multiple overlapping coverage mechanisms. Employer-sponsored insurance covers approximately 155 million Americans; Medicare covers 65 million elderly and disabled beneficiaries; Medicaid covers 85 million low-income individuals; the individual market (including the ACA exchanges) covers approximately 20 million; and approximately 26 million remain uninsured. Each of these coverage mechanisms embodies different economic tradeoffs and creates different incentive structures for consumers, providers, and insurers.

This chapter provides a comprehensive treatment of health insurance economics for graduate researchers. We begin with the foundational theory of insurance demand under uncertainty, then examine adverse selection and moral hazard as the central market failures in insurance, survey the major US insurance coverage mechanisms, analyze the Affordable Care Act as a case study in insurance market design, discuss managed care economics, value-based insurance design, and conclude with an international comparison of insurance system architectures. Throughout, we emphasize the interaction between economic theory and empirical evidence, drawing on the experimental findings from Chapters 1 and 2 and previewing the econometric methods developed in Chapters 9-17.

## The Economic Theory of Insurance

### Expected Utility Theory and Risk Aversion

The economic rationale for insurance is grounded in expected utility theory. An individual faces a random health expenditure *L* that occurs with probability *p*. Without insurance, the individual's expected utility is:

EU(no insurance) = p × U(W - L) + (1 - p) × U(W)

where *W* is initial wealth and *U(·)* is a von Neumann-Morgenstern utility function. If the individual is risk-averse — meaning U(·) is concave, so that the marginal utility of wealth is diminishing — then expected utility can be increased by purchasing actuarially fair insurance at premium *π = pL*:

EU(fair insurance) = U(W - pL) > p × U(W - L) + (1 - p) × U(W)

The inequality follows directly from Jensen's inequality applied to the concave utility function. The individual prefers the certain outcome (wealth *W - pL*) to the risky gamble with the same expected value, and is therefore willing to pay a premium above the actuarially fair price to eliminate the risk. The maximum premium the individual would pay — the certainty equivalent minus the expected loss — is the risk premium, which measures the welfare value of insurance.

The risk premium depends on three factors: the degree of risk aversion (the curvature of the utility function), the magnitude of the potential loss, and the probability of loss. For healthcare, losses can be catastrophic — a cancer diagnosis, a premature birth, a serious trauma — with costs potentially exceeding lifetime savings. The risk premium for catastrophic health insurance is therefore large, providing a strong economic justification for insurance coverage.

### The Demand for Insurance

The demand for insurance depends on the trade-off between risk reduction (the welfare benefit of smoother consumption across health states) and the premium cost (which includes the actuarially fair price plus an administrative loading factor). The loading factor — the difference between the premium and the expected claim cost — reflects the insurer's administrative expenses, profit margin, and reserves, and typically ranges from 5% to 15% for group insurance and 15% to 30% for individual insurance.

Formal models of insurance demand predict that risk-averse individuals will purchase full insurance when insurance is actuarially fair (zero loading) and will purchase less than full insurance (accepting some cost-sharing) when loading is positive. The optimal level of cost-sharing increases with the loading factor and decreases with the degree of risk aversion and the variance of healthcare expenditures.

In practice, insurance demand is also affected by factors not captured in the simple expected utility model: tax subsidies (the employer-sponsored insurance tax exclusion effectively reduces the price of insurance by the individual's marginal tax rate), behavioral biases (probability neglect, present bias, status quo effects), and institutional constraints (employer-determined plan offerings, eligibility rules for public programs). Behavioral factors in insurance demand were discussed in Chapter 2, and the tax subsidy is addressed below in the context of employer-sponsored insurance.

### Optimal Insurance Contracts Under Symmetric Information

Under symmetric information (both the insurer and the insured observe the same risk factors), the optimal insurance contract for a risk-averse individual facing actuarially fair pricing is full insurance — zero cost-sharing. This result follows directly from the Arrow (1963) theorem on optimal insurance, which demonstrates that complete risk transfer maximizes the risk-averse individual's expected utility when the insurer is risk-neutral and there is no moral hazard.

When loading is positive but there is still no moral hazard, the optimal contract features a deductible with full insurance above the deductible (Arrow, 1963). The deductible eliminates small claims that are costly to administer relative to their risk-reduction value, while providing full protection against large losses that generate the greatest welfare gain from risk transfer.

These results change fundamentally when moral hazard is introduced. Because insurance affects the insured individual's behavior — inducing greater healthcare consumption by reducing the out-of-pocket price — the optimal contract must balance risk protection against incentive effects, as discussed in Chapter 2.

## Adverse Selection in Health Insurance Markets

### Theoretical Models

Adverse selection — the tendency for individuals with higher expected healthcare costs to be more likely to purchase insurance or to select more generous coverage — is the most fundamental market failure in health insurance. The classic theoretical treatments are Akerlof (1970) and Rothschild and Stiglitz (1976).

**The Akerlof "lemons" problem.** In Akerlof's model, asymmetric information about product quality can cause market breakdown. Applied to insurance, if insurers cannot distinguish high-risk from low-risk individuals, they must charge a pooling premium that reflects the average risk of the insured population. At this premium, some low-risk individuals find the price too high relative to their expected benefit and drop coverage. Their departure raises the average risk (and therefore the average cost) of the remaining pool, leading to premium increases that cause additional low-risk individuals to exit. In the extreme case, this "death spiral" can cause the market to collapse entirely, with only the highest-risk individuals remaining in the pool at prohibitively expensive premiums.

**The Rothschild-Stiglitz (1976) separating equilibrium.** Rothschild and Stiglitz demonstrated that competitive insurance markets with adverse selection may reach a separating equilibrium in which insurers offer a menu of contracts designed to induce self-selection: a generous plan with high premiums and low cost-sharing (attractive to high-risk individuals) and a less generous plan with lower premiums and higher cost-sharing (attractive to low-risk individuals). The key result is that in equilibrium, low-risk individuals receive less than full insurance — they bear more cost-sharing than they would under symmetric information — because insurers must distort the low-risk contract to prevent high-risk individuals from selecting it. This distortion represents a welfare loss from adverse selection: low-risk individuals are made worse off by the information asymmetry.

An important theoretical subtlety is that the Rothschild-Stiglitz separating equilibrium may not exist when the proportion of high-risk individuals is small. If there are few high-risk individuals, the cross-subsidy required to offer a pooling contract is small, and a pooling equilibrium would be preferred by both types. However, Rothschild and Stiglitz show that a pooling equilibrium is always broken by a cream-skimming deviation: an insurer can profitably offer a less generous contract that attracts only low-risk individuals. The resulting non-existence of equilibrium is a theoretical difficulty that has motivated subsequent work on alternative equilibrium concepts (Wilson, 1977; Riley, 1979; Miyazaki, 1977).

### The Cutler-Zeckhauser (1998) Framework

Cutler and Zeckhauser (1998) provided an influential empirical framework for analyzing adverse selection in employer-sponsored insurance markets. They demonstrated that when employers offer a menu of plans, the availability of a more generous option attracts disproportionately high-risk employees, driving up the premium for the generous plan relative to the less generous alternative. This premium differential further discourages low-risk enrollment in the generous plan, creating a dynamic of adverse selection that can, over time, lead to the elimination of the generous option — a phenomenon they termed "the death spiral."

Their framework distinguishes between "active" adverse selection (individuals choose plans based on anticipated healthcare needs) and "passive" adverse selection (sicker individuals remain in more generous plans due to inertia while healthier individuals switch to less expensive options). Both forms lead to the same outcome — risk sorting across plans — but they have different implications for policy interventions.

### The Einav-Finkelstein-Cullen (2010) Sufficient Statistics Approach

The most important recent theoretical advance in adverse selection analysis is the sufficient statistics approach developed by Einav, Finkelstein, and Cullen (2010). Their key insight is that welfare analysis of insurance markets requires only two curves: the demand curve for insurance (willingness to pay as a function of coverage generosity) and the cost curve (average cost of insured individuals as a function of coverage generosity).

If the cost curve lies below the demand curve at all coverage levels, there is no adverse selection — the market can sustain efficient coverage levels. If the cost curve lies above the demand curve for some coverage levels, adverse selection exists, and the magnitude of the welfare loss can be calculated as the area between the demand and cost curves in the region where coverage is inefficiently low.

This framework has been enormously influential because it reduces the complex structural problem of modeling insurance markets to two estimable empirical relationships. Applications include Einav, Finkelstein, and Levin (2010) on Medicare Part D, Handel (2013) on employer-sponsored insurance, and numerous studies of ACA marketplace dynamics.

### Empirical Evidence on Adverse Selection

The empirical evidence for adverse selection in US health insurance markets is extensive and generally supportive, though the magnitude varies across settings.

**The positive correlation test.** The simplest test for adverse selection is whether individuals who choose more generous insurance coverage have higher ex-post healthcare expenditures, conditional on observable risk factors. This "positive correlation test" (Chiappori and Salanié, 2000) has been applied in many insurance markets, with generally positive results — individuals who select lower deductibles and lower coinsurance rates tend to have higher claims.

However, the positive correlation test cannot distinguish adverse selection (selection on private information about risk) from moral hazard (coverage causes higher utilization). The Einav-Finkelstein-Cullen framework addresses this limitation by using exogenous variation in insurance prices (e.g., from employer contribution policies) to separately identify the demand and cost curves.

**Advantageous selection.** An important complication is that in some markets, the opposite of adverse selection — "advantageous selection" — has been documented. Finkelstein and McGarry (2006) found that individuals who purchase long-term care insurance are simultaneously more likely to enter a nursing home (adverse selection on risk) and more risk-averse, more cautious, and more engaged in preventive health behaviors (advantageous selection on preferences). When the preference dimension dominates, individuals who purchase more insurance may actually have lower costs, reversing the standard adverse selection prediction.

## US Health Insurance Market Structure

### Employer-Sponsored Insurance and the Tax Subsidy

Employer-sponsored insurance (ESI) is the dominant source of private health insurance in the United States, covering approximately 155 million individuals. The prevalence of ESI is largely attributable to the federal tax exclusion for employer contributions to health insurance premiums, which originated as an IRS ruling during World War II wage controls and was codified in the Internal Revenue Code.

The tax exclusion is the single largest tax expenditure in the federal budget, valued at approximately $300 billion annually. It operates as a subsidy to insurance purchase that is most valuable for higher-income workers in higher marginal tax brackets. An employee in the 32% federal income tax bracket, facing 7.65% FICA taxes and 5% state income taxes, effectively pays only $0.55 of each dollar of employer-provided health insurance premiums, compared to $1.00 for the same dollar received as wages.

The economic effects of the tax exclusion have been extensively analyzed.

**Coverage effects.** The tax exclusion substantially increases employer provision of health insurance and the generosity of coverage offered. Gruber and Lettau (2004) estimated that the tax subsidy increases the probability of employer-sponsored coverage by approximately 25 to 35 percentage points.

**Efficiency effects.** Because the subsidy increases with the marginal tax rate and has no ceiling (for most of the exclusion's history), it encourages overconsumption of health insurance — plans that are more generous than individuals would choose if they faced the full cost. This overconsumption of insurance leads, through moral hazard, to overconsumption of healthcare services. Feldstein and Friedman (1977) estimated that the welfare loss from the tax exclusion-induced overconsumption of insurance and healthcare was substantial.

**Distributional effects.** The tax exclusion is regressive: higher-income workers receive a larger subsidy per dollar of insurance premium (because of their higher marginal tax rate) and are more likely to receive employer-sponsored coverage in the first place. Attempts to cap or eliminate the exclusion — including the ACA's Cadillac Tax (repeatedly delayed and eventually repealed) — have been politically unsuccessful despite strong economic arguments for reform.

### Medicare

Medicare is the federal health insurance program for Americans aged 65 and older, individuals with disabilities who have received Social Security Disability Insurance for 24 months, and individuals with end-stage renal disease. The program covers approximately 65 million beneficiaries and accounts for approximately 21% of national health expenditures.

Medicare consists of four parts, each with a distinct financing and benefit structure:

**Part A (Hospital Insurance)** covers inpatient hospital care, skilled nursing facility care, home health services, and hospice care. Part A is financed primarily through the 2.9% payroll tax (split equally between employer and employee), and most beneficiaries pay no premium because they or their spouse paid Medicare taxes for at least 40 quarters.

**Part B (Supplementary Medical Insurance)** covers physician services, outpatient hospital care, durable medical equipment, and some preventive services. Part B is financed through beneficiary premiums (covering approximately 25% of costs) and general federal revenue (covering approximately 75%). The standard Part B premium was $174.70 per month in 2024, with income-related surcharges (IRMAA) for higher-income beneficiaries.

**Part C (Medicare Advantage)** allows beneficiaries to receive their Part A and Part B benefits through private managed care plans, which receive capitated payments from CMS based on the beneficiary's risk score. Medicare Advantage enrollment has grown rapidly, from approximately 13% of beneficiaries in 2005 to over 50% by 2024. The economic analysis of Medicare Advantage centers on whether private plans can deliver care more efficiently than traditional fee-for-service Medicare, or whether the capitation payments include excessive "overpayments" that represent transfers from taxpayers to private insurers and their enrollees.

**Part D (Prescription Drug Coverage)** was created by the Medicare Modernization Act of 2003 and provides subsidized prescription drug coverage through private stand-alone drug plans or Medicare Advantage plans. Part D features a distinctive coverage structure with an initial deductible, a coverage phase, a coverage gap (the "donut hole," substantially closed by the ACA and subsequent legislation), and catastrophic coverage.

Medicare's payment systems — hospital IPPS, physician RBRVS, Medicare Advantage risk adjustment — were discussed in Chapters 3 and 5. From an insurance economics perspective, the key features of Medicare are its universal eligibility at age 65 (eliminating adverse selection for the elderly), its defined benefit structure (providing standardized coverage regardless of health status), and its cost-sharing structure (which includes substantial gaps that motivate the purchase of supplemental Medigap coverage by approximately 24% of traditional Medicare beneficiaries).

### Medicaid

Medicaid is the joint federal-state health insurance program for low-income Americans, covering approximately 85 million individuals. Unlike Medicare, which is a federal entitlement with nationally uniform benefits, Medicaid is a cooperative federal-state program in which states have substantial discretion over eligibility levels, benefit design, provider payment rates, and delivery system organization, within broad federal guidelines.

The economic structure of Medicaid is shaped by the federal matching rate (Federal Medical Assistance Percentage, or FMAP), which ranges from 50% (for wealthier states) to approximately 77% (for poorer states), with a uniform 90% match for the ACA Medicaid expansion population. The matching formula creates a fiscal incentive for states to expand Medicaid coverage, because each additional dollar of state Medicaid spending generates between $1.00 and $3.30 in federal matching funds.

Medicaid provider payment rates are set by states and are generally well below Medicare and commercial insurance rates. The gap between Medicaid and commercial payment rates — approximately 30% to 50% lower for physician services — creates access challenges for Medicaid beneficiaries, as some providers limit or refuse Medicaid patients. The economic trade-off is clear: lower Medicaid payment rates reduce program costs but may reduce access and quality for beneficiaries.

The ACA Medicaid expansion — which extended eligibility to all adults with incomes up to 138% of the federal poverty level — represents the largest expansion of public insurance coverage since the original Medicaid program. By 2024, 40 states and the District of Columbia had adopted the expansion, extending coverage to approximately 20 million previously uninsured adults. The economic effects of Medicaid expansion have been extensively studied using difference-in-differences methods (Chapter 11), exploiting the variation in expansion timing across states. Key findings include significant increases in insurance coverage, improvements in self-reported health and financial security, reductions in uncompensated care costs for hospitals, and improvements in hospital financial margins — particularly for safety-net hospitals and those in rural areas.

## The Affordable Care Act as Insurance Market Design

### The Three-Legged Stool

The Affordable Care Act (2010) represents the most comprehensive reform of health insurance regulation in US history. Its individual market reforms are built on a "three-legged stool" design that addresses adverse selection through three interlocking mechanisms:

**Leg 1: Guaranteed issue and community rating.** The ACA prohibits insurers from denying coverage or charging higher premiums based on health status (guaranteed issue with modified community rating). Premiums may vary only by age (3:1 ratio cap), tobacco use (1.5:1 cap), geographic area, and family size. This regulation eliminates the most direct form of risk selection by insurers but, standing alone, would exacerbate adverse selection by allowing healthy individuals to purchase insurance only when they become sick.

**Leg 2: Individual mandate.** To prevent adverse selection under community rating, the ACA imposed an individual mandate requiring most Americans to maintain minimum essential coverage or pay a tax penalty. The mandate was designed to bring healthy individuals into the risk pool, reducing the average risk and therefore the average premium. The Tax Cuts and Jobs Act of 2017 reduced the mandate penalty to zero beginning in 2019, effectively eliminating the mandate at the federal level (though some states have enacted their own mandates).

**Leg 3: Premium subsidies.** The ACA provides advance premium tax credits (APTCs) to individuals with incomes between 100% and 400% of the federal poverty level (extended to incomes above 400% FPL by the American Rescue Plan Act and subsequent legislation). The subsidies are structured so that the individual pays a specified percentage of income for the second-lowest-cost silver plan in their area, with the federal government paying the difference between this contribution and the premium. This structure means that subsidies increase as premiums increase, providing a built-in stabilizer against premium spirals.

### Risk Adjustment, Reinsurance, and Risk Corridors

The ACA included three "3Rs" programs designed to mitigate adverse selection among insurers in the individual and small group markets:

**Risk adjustment** is a permanent program that transfers funds from insurers with lower-risk enrollees to insurers with higher-risk enrollees, based on a concurrent risk adjustment model (HHS-HCC). The goal is to reduce the incentive for insurers to engage in risk selection (cream-skimming) by compensating insurers that attract sicker enrollees.

**Reinsurance** was a transitional program (2014-2016) that reimbursed insurers for a portion of high-cost claims, reducing the financial risk associated with enrolling high-cost individuals during the initial years of market reform.

**Risk corridors** was a transitional program (2014-2016) that limited insurer gains and losses by sharing risk between insurers and the federal government. The program was intended to encourage insurer participation during the initial years of market uncertainty, but became politically controversial when it required federal outlays to cover insurer losses.

### Essential Health Benefits and Actuarial Value Tiers

The ACA defined ten categories of essential health benefits (EHBs) that all individual and small group plans must cover, including ambulatory care, emergency services, hospitalization, maternity and newborn care, mental health and substance use disorder services, prescription drugs, rehabilitative services, laboratory services, preventive and wellness services, and pediatric services including dental and vision.

Plans are classified into four actuarial value (AV) tiers: bronze (60% AV), silver (70% AV), gold (80% AV), and platinum (90% AV). The actuarial value represents the expected share of total allowed costs paid by the plan for a standard population — a bronze plan is expected to cover 60% of costs, leaving 40% to the enrollee through deductibles, copayments, and coinsurance.

The AV tier structure creates a standardized framework for plan comparison while allowing flexibility in cost-sharing design. From an economic perspective, the structure facilitates consumer comparison shopping but also creates adverse selection dynamics within tiers (sicker individuals tend to select gold and platinum plans, while healthier individuals select bronze plans).

### Empirical Evidence on ACA Effects

The ACA has generated an enormous empirical literature, exploiting the staggered implementation of its provisions and the state-level variation in Medicaid expansion for causal identification.

**Coverage effects.** The uninsured rate declined from approximately 16% in 2010 to approximately 8% in 2024, representing approximately 20 million newly insured individuals through the combination of Medicaid expansion and marketplace subsidized coverage.

**Marketplace dynamics.** Individual market premiums initially increased substantially in some areas as insurers adjusted to the new regulatory environment, but stabilized after 2018 in most markets. Insurer participation declined between 2016 and 2018 (with some counties having only one participating insurer) but has since recovered, with most markets having multiple competing plans by 2024.

**Health effects.** The evidence on health effects of ACA coverage expansion is growing. Studies using difference-in-differences designs comparing expansion and non-expansion states have found reductions in mortality (Miller, Johnson, and Wherry, 2021), improvements in self-reported health, and increases in the diagnosis and treatment of chronic conditions. The mortality effects are concentrated among populations with higher baseline uninsurance rates and for conditions amenable to medical treatment.

---

**Key Concepts Box: ACA Insurance Market Design**

| Design Element | Economic Purpose | Implementation |
|---|---|---|
| Guaranteed issue / community rating | Eliminate risk-based pricing | Premiums vary only by age, tobacco, geography |
| Individual mandate | Prevent adverse selection under community rating | Tax penalty (reduced to $0 in 2019) |
| Premium subsidies (APTCs) | Make coverage affordable; stabilize markets | Percentage-of-income contribution for benchmark plan |
| Risk adjustment | Reduce cream-skimming incentives | HHS-HCC concurrent model; transfers among insurers |
| Essential health benefits | Prevent benefit-based risk selection | Ten mandated benefit categories |
| Actuarial value tiers | Standardize plan generosity for comparison | Bronze (60%), Silver (70%), Gold (80%), Platinum (90%) |
| Medicaid expansion | Extend coverage to low-income adults | Eligibility to 138% FPL with 90% federal match |

---

## Managed Care Economics

### The Managed Care Model

Managed care organizations — health maintenance organizations (HMOs), preferred provider organizations (PPOs), and point-of-service (POS) plans — emerged as a market response to the cost inflation associated with traditional fee-for-service insurance. The defining features of managed care are selective contracting (maintaining a network of preferred providers), utilization management (requiring prior authorization for expensive services), capitation or discounted fee arrangements with providers, and coordinated care management.

The economic logic of managed care is threefold. First, by concentrating patient volume in a selected network of providers, managed care plans can negotiate lower prices (volume discounts and favorable fee schedules). Second, by employing utilization management (prior authorization, concurrent review, case management), managed care plans can reduce utilization of services deemed unnecessary or marginally beneficial. Third, by aligning provider incentives through capitation or risk-sharing arrangements, managed care plans can encourage cost-conscious practice patterns.

### Evidence on Managed Care Effects

The empirical evidence on managed care's effects on costs and quality is nuanced.

**Cost effects.** Managed care plans generally achieve lower per-beneficiary costs than traditional fee-for-service insurance, primarily through lower prices (negotiated discounts) and reduced utilization of expensive services (hospitalizations, specialist referrals). Cutler, McClellan, and Newhouse (2000) estimated that HMO enrollment reduced healthcare spending by approximately 25% to 40% relative to indemnity insurance, with the savings attributable roughly equally to price effects and utilization effects.

**Quality effects.** The evidence on managed care quality is more mixed. Some studies found that managed care plans achieved comparable or slightly better quality on process measures (preventive care delivery, chronic disease management) while concerns persisted about access to specialty care, complex treatments, and patient satisfaction. The managed care backlash of the late 1990s — driven by publicized cases of denied care and restrictions on provider choice — led to regulatory reforms (external review mandates, point-of-service options, "any willing provider" laws) that constrained the most aggressive utilization management practices.

**Selection effects.** A major challenge in evaluating managed care is that enrollment is voluntary, creating potential selection bias. If managed care plans attract healthier individuals (favorable selection), cost comparisons will overstate the true savings from managed care. The empirical evidence suggests that managed care plans do attract somewhat healthier enrollees, though the magnitude of selection bias varies across studies and settings. In Medicare Advantage, the evidence has shifted over time: early studies found substantial favorable selection, while more recent studies using improved risk adjustment suggest that selection has diminished but not been fully eliminated.

### HMOs, PPOs, and the Evolution of Managed Care

The managed care landscape has evolved substantially since the HMO Act of 1973.

**HMOs** represent the most restrictive form of managed care, requiring enrollees to receive care from network providers (with limited exceptions for emergencies), designating a primary care physician as "gatekeeper" for specialist referrals, and employing capitation or salary-based provider compensation. Staff-model HMOs (such as Kaiser Permanente) employ physicians directly and operate their own facilities; group-model and network-model HMOs contract with physician groups.

**PPOs** represent a less restrictive model that allows enrollees to receive care from both in-network and out-of-network providers, with higher cost-sharing for out-of-network use. PPOs generally do not require a gatekeeper and use fee-for-service provider compensation with negotiated discount rates. PPOs have become the dominant plan type in the employer-sponsored market, reflecting consumer demand for provider choice.

**High-deductible health plans (HDHPs)** with health savings accounts (HSAs) represent a more recent evolution that shifts financial responsibility to consumers through high deductibles (minimum $1,600 for individual coverage in 2024). HDHPs are paired with tax-advantaged HSAs that allow pre-tax contributions for qualified medical expenses. The economic theory is that high deductibles increase consumer price sensitivity for services below the deductible, reducing moral hazard. The empirical evidence confirms that HDHPs reduce healthcare utilization, but — consistent with the RAND HIE findings — the reductions include both low-value and high-value services (Brot-Goldberg et al., 2017).

## Value-Based Insurance Design

### Theory and Rationale

Value-based insurance design (VBID) is an insurance design philosophy that aligns cost-sharing with the clinical value of services rather than applying uniform cost-sharing rates across all services. The theoretical foundation is straightforward: if the goal of cost-sharing is to reduce utilization of low-value services while preserving access to high-value services, then cost-sharing should be inversely related to clinical value.

The formal framework follows from the optimal insurance literature. Let *v(m)* denote the health value of service *m* and *c(m)* its cost. Standard cost-sharing (uniform coinsurance rate *r*) reduces utilization of both high-value services (where *v(m) > c(m)*) and low-value services (where *v(m) < c(m)*) proportionally. Value-based cost-sharing sets *r(m)* as a decreasing function of the value-cost ratio *v(m)/c(m)*, concentrating utilization reductions on low-value services while maintaining or increasing access to high-value services.

### Evidence on VBID

The most compelling evidence for VBID comes from studies of medication cost-sharing for chronic conditions.

**The MI-FREEE Trial.** Choudhry and colleagues (2011) conducted a large randomized trial in which post-myocardial infarction patients were assigned to either full insurance coverage for secondary prevention medications (statins, ACE inhibitors, beta-blockers, antiplatelet agents) or standard cost-sharing. The full-coverage group had significantly higher medication adherence and lower rates of major vascular events. Total medical spending was similar between groups, suggesting that the cost of eliminating copayments was offset by reduced spending on hospitalizations and procedures.

**The Pitney Bowes experience.** One of the earliest VBID implementations occurred at Pitney Bowes, which reduced copayments for diabetes and asthma medications while maintaining standard copayments for other drugs. The company reported improved medication adherence, reduced emergency department visits, and flat or declining total healthcare costs for the targeted chronic disease populations.

**Medicare VBID demonstration.** CMS launched a Medicare Advantage VBID demonstration in 2017, allowing participating plans to reduce cost-sharing for high-value services and offer supplemental benefits targeted to beneficiaries with specific chronic conditions. Early results suggest modest improvements in medication adherence and preventive care utilization among targeted populations.

### Tiered Formularies and Reference Pricing

Tiered formularies and reference pricing represent related approaches that use cost-sharing variation to steer utilization toward cost-effective options.

**Tiered formularies** classify drugs into tiers based on cost and clinical considerations, with progressively higher cost-sharing at higher tiers. A typical four-tier structure includes generic drugs (lowest copayment), preferred brand-name drugs, non-preferred brand-name drugs, and specialty drugs (highest copayment or coinsurance). The economic logic is that within a therapeutic class, therapeutic substitutes with similar clinical value should be priced to consumers based on their relative cost, encouraging use of lower-cost alternatives.

**Reference pricing** sets a maximum amount that the insurer will pay for a service, with the patient responsible for any charges above the reference price. CalPERS implemented reference pricing for hip and knee replacement surgeries, setting a reference price at approximately the 60th percentile of hospital charges. Patients choosing a higher-priced hospital paid the difference. Robinson and Brown (2013) found that reference pricing reduced spending per joint replacement by approximately 20%, driven by patients shifting to lower-cost facilities and by hospitals reducing prices to remain at or below the reference price.

## International Comparison of Insurance System Architectures

### Typology of Health Insurance Systems

The world's health insurance systems can be classified into four broad archetypes, each embodying different economic trade-offs:

**The Beveridge model** (UK, Spain, Italy, Sweden) features government-owned and -operated healthcare delivery, financed through general taxation. Providers are government employees, and there are no insurance claims or premiums. The economic advantages include low administrative costs, strong cost control through budgetary limits, and universal coverage. The economic disadvantages include potential under-provision of services, waiting lists, and limited consumer choice.

**The Bismarck model** (Germany, France, Japan, Switzerland) features mandatory health insurance through multiple non-profit "sickness funds" or social insurance plans, financed through employer-employee payroll contributions. Providers may be public or private. The system achieves universal coverage through mandate and provides more consumer choice than the Beveridge model, but with higher administrative costs due to multiple payers.

**The national health insurance model** (Canada, Taiwan, South Korea) combines elements of Beveridge and Bismarck: a single public insurer financed through taxation provides universal coverage, but healthcare delivery is primarily private. The single-payer structure achieves low administrative costs and strong purchasing power, but may face challenges in controlling utilization and managing waiting times.

**The out-of-pocket model** (much of the developing world) features minimal insurance coverage, with individuals paying for healthcare at the point of service. This model is associated with catastrophic financial risk, access barriers for low-income populations, and poor health outcomes.

### Economic Evaluation of Single-Payer Systems

The economic argument for single-payer health insurance centers on three potential advantages: administrative cost savings, monopsony purchasing power, and elimination of adverse selection.

**Administrative costs.** The US healthcare system's administrative costs — estimated at approximately 34% of total healthcare expenditures by Woolhandler, Campbell, and Himmelstein (2003) — are substantially higher than those in single-payer systems (approximately 12% to 17% in Canada). The multi-payer US system generates administrative complexity through insurance eligibility determination, claims processing, prior authorization, network management, and billing for multiple payers with different rules. A single-payer system would eliminate much of this complexity, generating estimated savings of $350 billion to $600 billion annually, though estimates vary widely depending on assumptions about provider payment rates and utilization effects.

**Monopsony power.** A single payer would possess substantial bargaining power vis-à-vis providers and pharmaceutical companies, potentially achieving lower prices for healthcare services and drugs. The empirical evidence from existing single-payer systems supports this prediction: drug prices in Canada, the UK, and Australia are substantially lower than US prices for the same medications, reflecting the purchasing power of single government buyers.

**Adverse selection elimination.** A universal single-payer system eliminates adverse selection by definition — everyone is covered under the same plan, so there is no opportunity for risk selection. This eliminates the welfare loss from adverse selection (the Rothschild-Stiglitz distortion), the administrative costs of risk adjustment and risk selection mitigation, and the coverage gaps that arise from market-based insurance allocation.

Against these potential advantages, single-payer opponents cite concerns about government control over healthcare decisions, potential waiting times and rationing, reduced innovation incentives (if lower prices reduce pharmaceutical R&D returns), and the political difficulty of transitioning from the existing multi-payer system.

---

**Table 4.1: US Health Insurance Coverage Mechanisms**

| Coverage Type | Enrollment (millions, 2024 est.) | Financing Mechanism | Key Economic Feature |
|---|---|---|---|
| Employer-sponsored insurance | 155 | Employer/employee premiums (tax-excluded) | Tax subsidy valued at ~$300B annually |
| Medicare | 65 | Payroll tax (Part A), premiums + general revenue (Part B) | Universal at 65; eliminates age-based adverse selection |
| Medicaid | 85 | Federal-state matching funds (50-77% FMAP) | Means-tested; 90% federal match for expansion |
| ACA marketplace | 20 | Subsidized premiums (APTCs) | Three-legged stool design; risk adjustment |
| Uninsured | 26 | Out-of-pocket / uncompensated care | Implicit tax on providers; EMTALA mandate |
| VA/TRICARE/IHS | 15 | Federal appropriations | Direct government provision |

---

## Conclusion

Health insurance economics lies at the intersection of risk theory, information economics, market design, and public policy. The two canonical market failures — adverse selection and moral hazard — create a fundamental tension in insurance design: providing generous coverage maximizes risk protection but exacerbates moral hazard, while cost-sharing controls moral hazard but exposes individuals to financial risk and may create barriers to high-value care.

The US health insurance system's distinctive fragmentation — with employer-sponsored insurance, Medicare, Medicaid, individual markets, and the uninsured coexisting under different rules and incentive structures — creates a rich laboratory for economic research but also generates inefficiencies, coverage gaps, and administrative complexity that are largely absent in more unified systems. The ACA's three-legged stool design represents an elegant attempt to address adverse selection in the individual market through the combination of community rating, mandate, and subsidies, though the weakening of the individual mandate has tested the durability of this architecture.

The methods for empirically evaluating insurance market interventions — difference-in-differences for state-level Medicaid expansion, regression discontinuity for age-based Medicare eligibility, structural demand estimation for plan choice — are developed in subsequent chapters. The sufficient statistics approach of Einav, Finkelstein, and Cullen provides the theoretical framework for welfare analysis that can be implemented using the econometric and computational tools of Chapters 9-26.

## References

1. Akerlof, G. A. (1970). The market for "lemons": Quality uncertainty and the market mechanism. *Quarterly Journal of Economics*, 84(3), 488-500.

2. Arrow, K. J. (1963). Uncertainty and the welfare economics of medical care. *American Economic Review*, 53(5), 941-973.

3. Brot-Goldberg, Z. C., Chandra, A., Handel, B. R., & Kolstad, J. T. (2017). What does a deductible do? The impact of cost-sharing on health care prices, quantities, and spending dynamics. *Quarterly Journal of Economics*, 132(3), 1261-1318.

4. Chiappori, P. A., & Salanié, B. (2000). Testing for asymmetric information in insurance markets. *Journal of Political Economy*, 108(1), 56-78.

5. Choudhry, N. K., Avorn, J., Glynn, R. J., et al. (2011). Full coverage for preventive medications after myocardial infarction. *New England Journal of Medicine*, 365(22), 2088-2097.

6. Cutler, D. M., McClellan, M., & Newhouse, J. P. (2000). How does managed care do it? *RAND Journal of Economics*, 31(3), 526-548.

7. Cutler, D. M., & Zeckhauser, R. J. (1998). Adverse selection in health insurance. In A. M. Garber (Ed.), *Frontiers in Health Policy Research* (Vol. 1, pp. 1-31). MIT Press.

8. Einav, L., Finkelstein, A., & Cullen, M. R. (2010). Estimating welfare in insurance markets using variation in prices. *Quarterly Journal of Economics*, 125(3), 877-921.

9. Einav, L., Finkelstein, A., & Levin, J. (2010). Beyond testing: Empirical models of insurance markets. *Annual Review of Economics*, 2(1), 311-336.

10. Feldstein, M., & Friedman, B. (1977). Tax subsidies, the rational demand for insurance and the health care crisis. *Journal of Public Economics*, 7(2), 155-178.

11. Finkelstein, A., & McGarry, K. (2006). Multiple dimensions of private information: Evidence from the long-term care insurance market. *American Economic Review*, 96(4), 938-958.

12. Gruber, J., & Lettau, M. (2004). How elastic is the firm's demand for health insurance? *Journal of Public Economics*, 88(7-8), 1273-1293.

13. Handel, B. R. (2013). Adverse selection and inertia in health insurance markets: When nudging hurts. *American Economic Review*, 103(7), 2643-2682.

14. Miller, S., Johnson, N., & Wherry, L. R. (2021). Medicaid and mortality: New evidence from linked survey and administrative data. *Quarterly Journal of Economics*, 136(3), 1783-1829.

15. Miyazaki, H. (1977). The rat race and internal labor markets. *Bell Journal of Economics*, 8(2), 394-418.

16. Riley, J. G. (1979). Informational equilibrium. *Econometrica*, 47(2), 331-359.

17. Robinson, J. C., & Brown, T. T. (2013). Increases in consumer cost sharing redirect patient volumes and reduce hospital prices for orthopedic surgery. *Health Affairs*, 32(8), 1392-1397.

18. Rothschild, M., & Stiglitz, J. (1976). Equilibrium in competitive insurance markets: An essay on the economics of imperfect information. *Quarterly Journal of Economics*, 90(4), 629-649.

19. Wilson, C. (1977). A model of insurance markets with incomplete information. *Journal of Economic Theory*, 16(2), 167-207.

20. Woolhandler, S., Campbell, T., & Himmelstein, D. U. (2003). Costs of health care administration in the United States and Canada. *New England Journal of Medicine*, 349(8), 768-775.
