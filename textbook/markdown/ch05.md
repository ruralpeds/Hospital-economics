# Chapter 5: Healthcare Financing and Payment Systems

## Introduction

Healthcare financing — the mobilization and allocation of financial resources for health services — is the connective tissue of any health system. How money flows from individuals, employers, and governments to hospitals, physicians, pharmaceutical companies, and other providers determines what care is delivered, how efficiently it is produced, and who has access to it. The design of payment systems shapes provider behavior as powerfully as any clinical guideline or regulatory mandate, because providers respond to financial incentives in systematic and predictable ways that either align with or diverge from the social objectives of high-quality, efficient, equitable care.

The United States devotes more financial resources to healthcare than any other nation — approximately $4.8 trillion in 2023, or roughly 17.3% of GDP — yet achieves mediocre population health outcomes by international standards. Understanding why requires a detailed examination of how these resources are raised, how they flow through the system, and what incentives the payment architecture creates for the actors who control resource allocation. This chapter provides that examination.

We begin with the national health expenditure accounting framework that quantifies the sources and uses of healthcare funds. We then examine the major provider payment mechanisms in detail — fee-for-service, prospective payment, capitation, bundled payment, and value-based models — analyzing the economic incentives each creates and the empirical evidence on their effects. We proceed to risk adjustment as the technical infrastructure underlying modern payment systems, physician compensation models, the structural drivers of healthcare cost growth, cost containment strategies, and the emerging economics of price transparency. Throughout, the chapter is grounded in the specific mechanics of US payment systems — CMS program details, coding systems, conversion factors — because the institutional details matter enormously for understanding incentive effects and for conducting empirical research using claims data.

## National Health Expenditure Accounting

### The CMS National Health Expenditure Framework

The Centers for Medicare and Medicaid Services (CMS) Office of the Actuary produces the National Health Expenditure Accounts (NHEA), the official US estimates of healthcare spending. The NHEA provides a comprehensive accounting of healthcare spending by source of funds (who pays), type of service (what is purchased), and sponsor (who bears the ultimate economic burden).

In 2023, total national health expenditures were approximately $4.8 trillion, distributed across the following major categories: hospital care (31%), physician and clinical services (20%), prescription drugs (9%), other professional services (3%), nursing care facilities and continuing care retirement communities (5%), home health care (3%), government administration and net cost of health insurance (8%), government public health activities (3%), investment in research and structures (5%), and other health spending (13%).

The sources of financing reveal the hybrid public-private character of the US system. Federal government programs (primarily Medicare, Medicaid federal share, VA, TRICARE, and CHIP) accounted for approximately 34% of total spending. State and local government programs (primarily the state share of Medicaid, public employee benefits, and public hospitals) accounted for approximately 16%. Private health insurance accounted for approximately 30%. Out-of-pocket spending accounted for approximately 11%. Other private revenues (philanthropy, workplace health programs, privately funded construction) accounted for the remainder.

The government share of healthcare financing — approximately 50% — substantially exceeds what most Americans perceive, because much of the government's role operates through intermediaries (Medicare contractors, Medicaid managed care organizations, tax subsidies for employer-sponsored insurance) rather than through direct provision.

### International Comparison Using OECD Methodology

The OECD System of Health Accounts (SHA) provides a standardized framework for comparing health spending across countries. Using this methodology, the United States stands out in several dimensions.

**Total spending.** US per capita health spending ($12,555 in 2022) was approximately twice the OECD average ($4,986) and substantially higher than the next-highest spender (Switzerland, approximately $8,049). This spending premium persists after adjusting for differences in national income: the US spends approximately 17% of GDP on health, compared to 10-12% for most other high-income OECD countries.

**Prices vs. quantities.** Anderson and colleagues' (2003) influential analysis concluded that the primary driver of higher US spending is higher prices — "it's the prices, stupid." US provider payment rates, pharmaceutical prices, and administrative costs all substantially exceed those in peer countries. Utilization rates for most services are comparable to or lower than OECD averages, though the US has higher utilization of expensive diagnostic imaging and some surgical procedures.

**Administrative costs.** The US multi-payer system generates administrative costs that are approximately two to three times higher than those in single-payer systems, as documented in Chapter 4. Billing, coding, claims processing, prior authorization, network management, and insurance eligibility determination collectively account for an estimated $265 billion to $390 billion in annual administrative spending that could potentially be reduced under a simplified financing architecture.

### Trends and Projections

National health expenditure growth has generally exceeded GDP growth over the past five decades, with the health spending share of GDP rising from 5% in 1960 to 17.3% in 2023. However, the rate of excess cost growth (health spending growth minus GDP growth) has moderated since 2010, falling from approximately 2.5 percentage points annually in the 1980s and 1990s to approximately 1.0 to 1.5 percentage points in the 2010s.

CMS actuarial projections estimate that national health expenditures will reach approximately $7.2 trillion by 2031, representing approximately 19.6% of GDP. The primary drivers of projected spending growth are population aging (the baby boom generation entering Medicare), general price inflation, growth in Medicaid enrollment, and continued (though moderated) technological change.

Whether the slowdown in health spending growth since 2010 represents a structural shift (driven by delivery system reform, value-based payment, and changes in the healthcare workforce) or a cyclical phenomenon (related to the Great Recession and its lingering effects on utilization) remains an active research question. Cutler and Sahni (2013) argued that structural factors — including the adoption of generic drugs, slower diffusion of new technologies, and delivery system changes — contributed to the slowdown, while others emphasized the macroeconomic cycle and the ACA's temporary payment reductions.

## Fee-for-Service Payment in Detail

### The CPT/HCPCS Coding System

Fee-for-service payment in the United States is built on a coding infrastructure that classifies every billable service into a standardized code. Two code sets are used:

**Current Procedural Terminology (CPT)** codes, maintained by the American Medical Association, classify physician services, procedures, and other outpatient services. CPT codes are five-digit numeric codes organized into three categories: Category I (procedures and services), Category II (performance measurement), and Category III (emerging technology). The CPT code set is updated annually, with new codes added for novel procedures and existing codes revised or deleted.

**Healthcare Common Procedure Coding System (HCPCS)** Level II codes, maintained by CMS, classify services not covered by CPT, including durable medical equipment, prosthetics, orthotics, supplies, ambulance services, and drugs administered by providers. HCPCS Level II codes are alphanumeric (letter followed by four digits).

The coding system is the foundation of claims-based healthcare data. Every claim submitted to Medicare, Medicaid, or commercial insurers contains CPT/HCPCS procedure codes, ICD-10-CM diagnosis codes, place of service codes, and provider identifiers. Understanding the coding system is essential for health economics researchers because measurement of healthcare utilization, spending, and quality all depend on the accuracy and completeness of coded claims data. The transition from ICD-9-CM (approximately 14,000 diagnosis codes) to ICD-10-CM (approximately 68,000 codes) in October 2015 substantially increased diagnostic specificity but created discontinuities in time-series analyses that researchers must address.

### The Resource-Based Relative Value Scale (RBRVS)

Medicare's physician fee schedule is based on the Resource-Based Relative Value Scale, developed by William Hsiao and colleagues at Harvard and implemented by CMS in 1992. The RBRVS assigns each CPT code a total relative value unit (RVU) composed of three components:

**Physician work RVUs** reflect the time, technical skill, physical effort, mental effort, and judgment required to perform the service. Work RVUs account for approximately 50.9% of the total payment.

**Practice expense RVUs** reflect the direct and indirect costs of maintaining a medical practice — staff salaries, rent, equipment, supplies. Practice expense RVUs account for approximately 44.8% of total payment and are calculated separately for facility settings (where the hospital bears most practice expenses) and non-facility settings (where the physician practice bears them).

**Malpractice RVUs** reflect the cost of professional liability insurance and account for approximately 4.3% of total payment.

Each component is adjusted by a Geographic Practice Cost Index (GPCI) that reflects local cost variation, and the adjusted total is multiplied by a national conversion factor (CF) to yield the dollar payment:

Payment = [(Work RVU × Work GPCI) + (PE RVU × PE GPCI) + (MP RVU × MP GPCI)] × CF

The conversion factor was approximately $33.89 in 2024, and is updated annually through a process that has been the subject of persistent legislative intervention. The Sustainable Growth Rate (SGR) formula, which governed conversion factor updates from 1998 to 2015, repeatedly called for physician fee reductions that Congress overrode through temporary "doc fixes." The Medicare Access and CHIP Reauthorization Act (MACRA) of 2015 replaced the SGR with a new framework that provides modest annual updates and transitions physicians into the Merit-based Incentive Payment System (MIPS) or Advanced Alternative Payment Models (A-APMs).

### The RUC and Specialty Income Disparities

The Relative Value Scale Update Committee (RUC), a committee of the American Medical Association composed primarily of specialty society representatives, makes recommendations to CMS on the relative values assigned to CPT codes. CMS accepts approximately 90% of RUC recommendations, giving the committee enormous influence over physician payment.

The RUC process has been criticized for systematically overvaluing procedure-intensive services relative to evaluation and management (E&M) services, contributing to the income gap between procedural specialists and primary care physicians. The median income for orthopedic surgeons (approximately $557,000 in 2023) exceeds that for family medicine physicians (approximately $255,000) by a factor of more than two. Critics argue that the RUC's specialty-dominated composition creates a structural bias toward maintaining high procedure values, as specialty societies have a financial interest in preserving or increasing the RVUs assigned to their procedures.

CMS has undertaken periodic revaluations of overvalued services through the "misvalued code initiative," and the 2021 increase in E&M visit values (the largest revaluation in RBRVS history) represented an attempt to partially close the primary care-specialty payment gap. However, the budget-neutrality constraint of the physician fee schedule means that any increase in RVUs for one set of services requires a proportional reduction in the conversion factor, effectively redistributing payment among specialties rather than increasing total physician payment.

## Medicare Inpatient Prospective Payment System

### DRG System Design and Mechanics

The Medicare Inpatient Prospective Payment System (IPPS), implemented in 1983, pays hospitals a predetermined amount per discharge based on the patient's diagnosis-related group (DRG). The system was designed to replace retrospective cost-based reimbursement, which provided no incentive for efficiency, with a prospective fixed payment that rewards hospitals for reducing unnecessary resource use.

The current system uses Medicare Severity Diagnosis-Related Groups (MS-DRGs), which classify each inpatient discharge into one of approximately 767 groups based on the principal diagnosis, surgical procedures performed, comorbidities (pre-existing conditions), and complications (conditions arising during the hospitalization). The MS-DRG system introduced three severity levels for most base DRGs: without complications or comorbidities (CC), with CC, and with major CC (MCC), providing more refined payment differentiation based on case complexity.

The payment for each case is calculated as:

Operating Payment = [Labor Share × Wage Index + Non-Labor Share] × Base Rate × DRG Weight × (1 + DSH % + IME %)

Capital Payment = Federal Capital Rate × DRG Weight × Geographic Adjustment × (DSH and IME adjustments)

The base rate (standardized amount) is updated annually by the market basket index (a healthcare-specific price index) minus a productivity adjustment. The DRG weight reflects the expected costliness of the case type relative to the average Medicare case. Policy add-on payments include the disproportionate share hospital (DSH) adjustment for hospitals serving a high proportion of low-income patients, and the indirect medical education (IME) adjustment for teaching hospitals.

### Case Mix Index and Hospital Revenue

The case mix index (CMI) is the average DRG weight across all of a hospital's discharges, serving as a summary measure of case complexity and expected resource intensity. A hospital with a CMI of 1.50 treats cases that are, on average, 50% more resource-intensive than the national average Medicare case.

CMI is a critical metric for hospital financial management and for health services research. Rising CMI may reflect genuine increases in case complexity (sicker patients, more complex procedures), improvements in documentation and coding accuracy, or strategic upcoding (classifying patients into higher-paying DRGs). Distinguishing these mechanisms is empirically challenging and has been the subject of extensive research.

Dafny (2005) provided one of the most rigorous analyses of hospital coding behavior under prospective payment. She found that when CMS introduced a new DRG classification that created opportunities for higher-paying codes, hospitals rapidly shifted coding patterns to capture the higher payments — even for patients whose clinical presentations had not changed. This response was stronger in for-profit hospitals and in hospitals under greater financial pressure, consistent with strategic rather than clinical motivation.

### Outlier Payments

The IPPS includes an outlier payment mechanism for cases with exceptionally high costs. When a case's cost (estimated from charges multiplied by the hospital's cost-to-charge ratio) exceeds the DRG payment plus a fixed-loss threshold (approximately $33,000 in 2024), Medicare pays 80% of the excess cost. Outlier payments are designed to protect hospitals from catastrophic financial losses on individual cases and to reduce the incentive to avoid or under-treat high-cost patients.

Outlier payments account for approximately 5% of total IPPS payments. The policy has been refined over time in response to evidence of outlier payment manipulation — most notably the Tenet Healthcare scandal in the early 2000s, in which hospitals inflated charges (the basis for outlier eligibility determination) to maximize outlier payments without increasing actual resource use.

## Capitation and Risk Adjustment

### Risk Adjustment Methodology

Risk adjustment is the statistical process of adjusting payments to reflect the expected healthcare costs of individual patients or populations, accounting for differences in health status, demographics, and other cost-predictive factors. Risk adjustment is essential for any payment model that shifts financial risk to providers (capitation, shared savings, bundled payment) because without accurate risk adjustment, providers face strong incentives to avoid high-cost patients (cream-skimming) or to stint on care for enrolled populations (underservice).

The CMS Hierarchical Condition Categories (CMS-HCC) model is the primary risk adjustment system used in US healthcare. The model predicts individual-level healthcare expenditures based on demographic factors (age, sex, Medicaid dual-eligibility status, disability status) and diagnosis-based condition categories derived from ICD-10-CM codes on claims data.

The HCC model groups the approximately 68,000 ICD-10-CM codes into approximately 86 condition categories, arranged in a hierarchical structure so that only the most severe manifestation of a disease within each hierarchy is counted. For example, the diabetes hierarchy includes diabetes without complications, diabetes with chronic complications, and diabetes with acute complications — only the highest-severity diagnosis is included in the risk score.

The individual risk score is computed as:

Risk Score = Σ (Demographic Coefficients) + Σ (HCC Coefficients for conditions present)

A risk score of 1.00 represents the average Medicare beneficiary. A beneficiary with multiple chronic conditions might have a risk score of 2.50, indicating expected costs 2.5 times the average. Capitation payments (Medicare Advantage) are then calculated as:

Monthly Capitation = County Benchmark × Risk Score × Coding Intensity Adjustment

### Gaming and Upcoding Concerns

Risk adjustment creates an incentive for providers and insurers to maximize the documented severity of their patient populations — a practice variously described as "coding intensity," "risk score gaming," or "upcoding." In Medicare Advantage, plans have a financial incentive to ensure that all clinically relevant diagnoses are captured on claims, because higher risk scores generate higher capitation payments.

The magnitude of MA coding intensity is substantial. CMS has estimated that MA risk scores are inflated by approximately 3% to 8% relative to traditional Medicare, representing approximately $12 billion to $25 billion in excess payments annually. CMS applies a coding intensity adjustment (currently approximately 5.9%) to MA payments to partially offset this inflation, but the adjustment is applied uniformly rather than varying by plan, and may not fully capture the extent of differential coding.

Geruso and Layton (2020) provided a rigorous analysis of risk adjustment and selection in the ACA marketplaces, finding that the HHS-HCC risk adjustment model used in the exchanges captures only approximately 55% of the predictable variation in individual healthcare expenditures. The residual predictable variation creates opportunities for profitable selection — insurers can design plans that attract enrollees who are profitable even after risk adjustment, undermining the goal of eliminating selection-based competition.

## Value-Based Payment Models

### The Medicare Shared Savings Program

The Medicare Shared Savings Program (MSSP), established by the ACA in 2010, is the largest value-based payment program in the United States. Under MSSP, accountable care organizations (ACOs) — groups of providers and suppliers that voluntarily coordinate care for a defined population of Medicare fee-for-service beneficiaries — are held accountable for the total cost and quality of care for their attributed beneficiaries.

The MSSP operates through benchmark spending targets and shared savings/losses. Each ACO's benchmark is calculated based on its historical spending, trended forward and blended with regional spending averages. If the ACO's actual spending falls below the benchmark by more than a minimum savings rate (typically 2% to 3.9%, depending on ACO size), the ACO shares in the savings at a rate of 50% to 75%. Under two-sided risk tracks, ACOs also share in losses if spending exceeds the benchmark.

Quality performance is assessed through a set of approximately 10 quality measures spanning patient experience, care coordination, preventive health, and at-risk populations. ACOs must meet a minimum quality threshold to be eligible for shared savings payments.

As of 2024, over 450 ACOs participated in MSSP, covering approximately 11 million Medicare beneficiaries. The evidence on MSSP performance shows modest net savings (approximately 1% to 2% of total spending for established ACOs), with savings growing over time as ACOs gain experience with population health management. McWilliams and colleagues (2016, 2018) found that physician-led ACOs generated larger savings than hospital-led ACOs, potentially because hospitals face conflicting incentives — reducing hospitalizations and post-acute care utilization (which generates shared savings) also reduces the hospital's fee-for-service revenue.

### The Quality Payment Program and MIPS

The Medicare Access and CHIP Reauthorization Act (MACRA) of 2015 created the Quality Payment Program (QPP), which channels virtually all Medicare physician payment through one of two tracks:

**The Merit-based Incentive Payment System (MIPS)** adjusts physician fee schedule payments based on composite performance scores across four categories: quality (30% weight), cost (30%), promoting interoperability (25%, formerly meaningful use), and improvement activities (15%). Physicians scoring above the performance threshold receive positive payment adjustments; those below receive negative adjustments. The adjustments are budget-neutral — positive adjustments are funded by negative adjustments on lower performers.

**Advanced Alternative Payment Models (A-APMs)** provide a 5% incentive payment (through 2024, transitioning to higher fee schedule updates thereafter) for physicians who receive a sufficient share of their revenue through qualifying APMs such as MSSP Track 2, Next Generation ACOs, or BPCI Advanced. A-APM participants are exempt from MIPS reporting.

The economic design of MIPS embodies the same multitasking challenges identified in the P4P literature (Chapter 3): incentivizing measured dimensions of performance may divert effort from unmeasured dimensions, and the composite scoring methodology may obscure rather than clarify the relationship between individual actions and financial rewards. Early evaluations suggest that MIPS has had limited impact on physician behavior, in part because the financial stakes remain modest relative to total physician revenue and in part because the complex scoring methodology makes it difficult for physicians to identify specific actions that would improve their scores.

### Global Budgets

Global budgets represent the strongest form of prospective payment, setting a fixed total budget for a provider or health system for all services delivered to a defined population over a defined period. Under a global budget, the provider receives a predetermined amount regardless of the volume of services delivered, creating maximum incentive for efficiency but also maximum risk of underservice.

The most prominent US global budget program is the Maryland All-Payer Model, implemented in 2014 and extended as the Total Cost of Care (TCOC) Model in 2019. Under the Maryland model, each hospital receives a global budget for all inpatient and outpatient hospital services, updated annually based on population, inflation, and quality performance. The global budget is set on an all-payer basis — Medicare, Medicaid, and commercial insurers all pay proportionally under the same budget framework.

The Maryland model has produced significant results: hospital revenue growth has been held below 3.6% annually (the state's per capita income growth rate), avoidable hospitalizations have declined, and hospital operating margins have stabilized. The model effectively eliminates the volume incentive of fee-for-service — hospitals receive the same revenue regardless of whether admissions rise or fall — fundamentally changing the economic calculus of hospital decision-making.

The economic analysis of global budgets highlights several key design considerations. First, the budget-setting formula must adequately account for population growth, aging, disease burden changes, and input cost inflation to avoid systematic underfunding. Second, quality monitoring must be robust to prevent the budget constraint from leading to underservice — monitoring should include measures of access (wait times, patient volume), clinical quality (mortality, readmissions, complications), and patient experience. Third, the transition from volume-based to budget-based payment requires substantial organizational adaptation, including new competencies in population health management, care coordination, and financial risk management.

---

**Key Concepts Box: Payment System Design Principles**

| Design Principle | Description | Payment Models That Embody It |
|---|---|---|
| Volume incentive alignment | Payment should not reward unnecessary volume | Capitation, global budgets, bundled payments |
| Risk adjustment adequacy | Payments must reflect patient complexity | HCC risk adjustment, DRG severity levels |
| Quality safeguards | Financial incentives must be paired with quality measurement | P4P, MSSP quality gates, VBP Program |
| Financial risk calibration | Risk transfer to providers must match their capacity | One-sided vs. two-sided risk tracks |
| Budget neutrality | New payment models should not increase total spending | MIPS, VBP redistribution |
| Administrative feasibility | Payment complexity must not exceed system capacity | Simplified DRG grouping, standardized quality measures |

---

## Healthcare Cost Drivers

### Baumol's Cost Disease

William Baumol's theory of unbalanced growth — often called "Baumol's cost disease" — provides a structural explanation for persistent healthcare cost growth. Baumol (1967) observed that sectors with low productivity growth (the "stagnant" sector, exemplified by personal services including healthcare) will experience rising relative costs over time, because wages in the stagnant sector must keep pace with wages in the "progressive" sector (manufacturing, technology) to attract workers, even though productivity in the stagnant sector is not growing commensurately.

Applied to healthcare, Baumol's model suggests that healthcare costs will inevitably grow faster than general prices because healthcare production remains labor-intensive and resistant to the labor-saving technological innovation that drives productivity growth in other sectors. A surgical procedure, a primary care visit, and a nursing shift all require roughly the same amount of human time as they did decades ago, even though wages for healthcare workers have risen with the general economy.

The empirical relevance of Baumol's cost disease for healthcare is debated. Nordhaus (2008) found that Baumol's model explains a substantial share of cross-sector cost variation in the US economy. However, healthcare does experience technological change — albeit technology that tends to expand capabilities (new procedures, new drugs, new diagnostics) rather than reduce labor requirements per unit of output. This pattern of cost-increasing technological change is discussed below.

### Technology Diffusion as Cost Driver

Technological change is widely regarded as the single most important driver of long-run healthcare cost growth, accounting for an estimated 40% to 65% of expenditure increases over the past half-century (Newhouse, 1992; CBO, 2008). However, the mechanism through which technology drives costs in healthcare differs fundamentally from the mechanism in most other industries.

In manufacturing and information technology, new technology typically reduces the cost per unit of output — robots replace assembly workers, software automates clerical tasks, cloud computing reduces infrastructure costs. In healthcare, new technology typically expands the set of treatable conditions and the intensity of treatment for existing conditions, increasing total expenditure even when the cost per treatment episode declines. A new cancer immunotherapy may be highly cost-effective (extending life by years at a per-QALY cost below conventional thresholds), yet its adoption increases total cancer spending because it is applied to patients who previously had no effective treatment option.

This pattern — cost-increasing rather than cost-reducing technological change — is partly a consequence of the insurance and payment architecture. When patients are insulated from costs by insurance, and providers are paid more for delivering more services (fee-for-service), there is little market pressure for cost-reducing innovation. The incentive structure rewards technologies that expand the scope of medicine, even when the marginal clinical benefit is small relative to the marginal cost.

### Administrative Costs

Administrative costs in the US healthcare system represent a significant and potentially reducible source of spending. Himmelstein, Campbell, and Woolhandler (2020) estimated that administrative costs account for approximately 34.2% of total US healthcare expenditures — approximately $1.06 trillion in 2023 — compared to 17% in Canada.

The sources of administrative cost are numerous: insurance company overhead (underwriting, marketing, claims processing, network management, utilization review), provider billing and collections (coding, claims submission, prior authorization, appeals, collections), government program administration, and regulatory compliance. Each payer maintains its own benefit design, formulary, prior authorization requirements, and claims processing rules, forcing providers to maintain complex billing operations that can identify and comply with the requirements of multiple payers.

The potential savings from administrative simplification are substantial but politically difficult to achieve, because administrative activities create employment for a large workforce and because simplification often requires standardization that reduces the ability of payers and providers to differentiate their offerings. The ACA included provisions for administrative simplification (standardized electronic transactions, operating rules for claims processing), but the multi-payer system's fundamental complexity remains.

### Prices vs. Utilization Decomposition

Decomposing healthcare spending growth into price and utilization (quantity) components is essential for identifying appropriate policy responses. If spending growth is driven primarily by prices, then price regulation, reference pricing, or competitive bidding may be effective containment strategies. If spending growth is driven by utilization increases, then demand-side interventions (cost-sharing, utilization management) or supply-side interventions (practice guidelines, technology assessment) may be more appropriate.

The empirical evidence suggests that both prices and utilization contribute to US spending growth, but that prices play a larger role in explaining the US spending premium relative to other countries (Anderson et al., 2003). Within the United States, spending variation across geographic areas is driven more by utilization differences (particularly post-acute care utilization and the intensity of services during hospitalizations) than by price differences, after controlling for regional cost of living.

Cooper and colleagues (2019) documented substantial variation in commercial insurance prices across US hospital markets, finding that prices for the same procedure could vary by a factor of three or more across hospitals in the same metropolitan area. This price variation is strongly correlated with hospital market concentration, reinforcing the findings on merger-induced price increases discussed in Chapter 3.

## Cost Containment Strategies

### Supply-Side Approaches

**Certificate of need (CON).** Certificate of need programs, adopted by 35 states at the peak of the CON movement in the 1970s and retained by approximately 35 states (with varying scope) as of 2024, require healthcare providers to obtain state approval before constructing new facilities, expanding existing facilities, or acquiring major equipment. The economic rationale is that excess capacity creates supply-induced demand: building more hospital beds leads to more hospitalizations.

The empirical evidence on CON effectiveness is mixed to negative. Most studies find that CON programs do not reduce healthcare spending and may actually increase costs by reducing competition and protecting incumbent providers from entry. Conover and Sloan (1998) found little evidence that CON achieved its stated objectives of controlling costs or improving quality. The American Health Planning Association and some health policy scholars continue to defend CON as a tool for ensuring equitable distribution of healthcare resources, particularly in rural areas.

**Rate setting.** All-payer rate setting — in which a state regulates the prices that all payers (Medicare, Medicaid, commercial insurers) pay hospitals — was adopted by several states in the 1970s and 1980s. Maryland is the only state that has maintained continuous all-payer rate setting, which evolved into the global budget program described above. The evidence from the Maryland experience suggests that rate setting can effectively control hospital cost growth, but its success depends on political sustainability and the sophistication of the rate-setting methodology.

### Demand-Side Approaches

**Consumer-directed health plans.** High-deductible health plans with health savings accounts represent the primary demand-side cost containment strategy in the current US market. The economic theory is straightforward: by increasing the out-of-pocket price of care below the deductible, HDHPs increase consumer price sensitivity and reduce moral hazard.

The evidence confirms that HDHPs reduce healthcare utilization and spending, at least in the short run. Brot-Goldberg and colleagues (2017) studied a large employer that shifted all employees from free care to a high-deductible plan and found a 12% reduction in total spending in the first year, driven primarily by quantity reductions rather than price shopping. However, consistent with the RAND HIE, spending reductions were concentrated among lower-income employees, reductions included both low-value and high-value services, and there was limited evidence that consumers engaged in meaningful price shopping.

**Utilization management.** Prior authorization, concurrent review, and retrospective review represent utilization management strategies employed by insurers to reduce unnecessary care. The economic rationale is that utilization management applies clinical criteria to individual treatment decisions, theoretically allowing reductions in low-value care while preserving high-value care. In practice, utilization management has been criticized for imposing substantial administrative burden on providers, delaying necessary care, and generating patient dissatisfaction — leading to regulatory responses including state prior authorization reform laws and CMS's 2024 Interoperability and Prior Authorization final rule requiring electronic prior authorization.

## The Economics of Healthcare Price Transparency

### The Price Transparency Movement

Healthcare price transparency — the idea that consumers should have access to meaningful price information before receiving care — has gained significant policy momentum since 2019. CMS's Hospital Price Transparency Rule (effective January 2021) requires hospitals to publish machine-readable files containing negotiated rates with all payers and to provide a consumer-friendly tool displaying prices for 300 shoppable services. The Transparency in Coverage Rule (effective July 2022) requires commercial insurers to publish machine-readable files of negotiated rates for all covered services.

The economic case for price transparency rests on the assumption that information asymmetry about prices prevents competitive market forces from operating. If consumers can compare prices across providers before receiving care, they may choose lower-priced options, creating competitive pressure for providers to reduce prices. Reference pricing (discussed in Chapter 4) operationalizes this theory by giving consumers both price information and a financial incentive to choose lower-priced providers.

### Empirical Evidence and Limitations

The empirical evidence on the effects of price transparency is modest and mixed. Studies of early price transparency initiatives found limited consumer engagement — few patients actively used available price comparison tools, and price shopping was concentrated in "shoppable" services (imaging, laboratory tests, elective procedures) that constitute a minority of total healthcare spending. Emergency care, inpatient hospitalizations, and complex chronic disease management — the categories that drive the majority of spending — are generally not shoppable because patients cannot or do not make provider selections based on price.

The more promising channel for price transparency effects may be through employers, insurers, and policymakers rather than individual consumers. Machine-readable price data enables research on price variation, supports reference pricing and narrow network design, and creates public accountability for pricing practices. The growing availability of all-payer claims databases (APCDs) at the state level provides a complementary data infrastructure for price research and policy analysis.

---

**Table 5.1: Medicare Payment Systems by Service Type**

| Service Type | Payment System | Unit of Payment | Key Adjustment Factors |
|---|---|---|---|
| Inpatient hospital | IPPS | MS-DRG per discharge | Wage index, DSH, IME, outlier |
| Outpatient hospital | OPPS | APC per service | Wage index, outlier, pass-through |
| Physician services | PFS (RBRVS) | RVU per service | GPCI, MIPS adjustment |
| Skilled nursing facility | SNF PPS | PDPM per day (case-mix adjusted) | Variable per diem by component |
| Home health | HH PPS | PDGM per 30-day period | Case-mix, LUPA threshold |
| Hospice | Hospice per diem | Per diem by level of care | Routine home care, continuous, respite, inpatient |
| Medicare Advantage | Capitation | PMPM (risk-adjusted) | County benchmark, HCC risk score, quality bonus |
| Part D drugs | Negotiated/formulary | Per prescription | Plan benefit design, coverage gap |

---

## Conclusion

Healthcare financing and payment systems are the economic architecture of the health system — they determine the incentives that shape provider behavior, the distribution of financial risk among patients, providers, and payers, and the total resources devoted to healthcare. The US system's complexity — with multiple payer types, multiple payment models operating simultaneously, and continuous policy experimentation — creates both challenges and opportunities for health economics research.

The central tension in payment system design is between simplicity and precision. Simple payment models (fee-for-service, per diem rates) are easy to administer but create crude incentives that may not align with clinical or social objectives. Sophisticated models (risk-adjusted capitation, episode-based payment with quality adjustment) better align incentives but require complex measurement and adjustment infrastructure (coding systems, risk adjustment models, quality metrics) that is costly to maintain and vulnerable to gaming.

The trend in US healthcare payment is clearly toward value-based models that hold providers accountable for total cost and quality — ACOs, bundled payments, global budgets, and population-based payment. Whether these models will achieve their promise of bending the cost curve while maintaining or improving quality depends on the resolution of several technical and political challenges: the accuracy of risk adjustment, the adequacy of quality measurement, the calibration of financial risk, and the political sustainability of payment reform in the face of provider resistance.

The econometric methods developed in Chapters 9-17 — particularly difference-in-differences for evaluating payment reform rollouts, instrumental variables for addressing the endogeneity of payment and utilization, and structural models for simulating counterfactual payment designs — provide the tools for evaluating these payment experiments. The Julia implementations in Chapters 19-26 enable the computation.

## References

1. Anderson, G. F., Hussey, P. S., Frogner, B. K., & Waters, H. R. (2005). Health spending in the United States and the rest of the industrialized world. *Health Affairs*, 24(4), 903-914.

2. Baumol, W. J. (1967). Macroeconomics of unbalanced growth: The anatomy of urban crisis. *American Economic Review*, 57(3), 415-426.

3. Brot-Goldberg, Z. C., Chandra, A., Handel, B. R., & Kolstad, J. T. (2017). What does a deductible do? The impact of cost-sharing on health care prices, quantities, and spending dynamics. *Quarterly Journal of Economics*, 132(3), 1261-1318.

4. Congressional Budget Office. (2008). *Technological Change and the Growth of Health Care Spending*. CBO.

5. Conover, C. J., & Sloan, F. A. (1998). Does removing certificate-of-need regulations lead to a surge in health care spending? *Journal of Health Politics, Policy and Law*, 23(3), 455-481.

6. Cooper, Z., Craig, S. V., Gaynor, M., & Van Reenen, J. (2019). The price ain't right? Hospital prices and health spending on the privately insured. *Quarterly Journal of Economics*, 134(1), 51-107.

7. Cutler, D. M., & Sahni, N. R. (2013). If slow rate of health care spending growth persists, projections may be off by $770 billion. *Health Affairs*, 32(5), 841-850.

8. Dafny, L. S. (2005). How do hospitals respond to price changes? *American Economic Review*, 95(5), 1525-1547.

9. Geruso, M., & Layton, T. J. (2020). Upcoding: Evidence from Medicare on squishy risk adjustment. *Journal of Political Economy*, 128(3), 984-1026.

10. Himmelstein, D. U., Campbell, T., & Woolhandler, S. (2020). Health care administrative costs in the United States and Canada, 2017. *Annals of Internal Medicine*, 172(2), 134-142.

11. Hsiao, W. C., Braun, P., Yntema, D., & Becker, E. R. (1988). Estimating physicians' work for a resource-based relative-value scale. *New England Journal of Medicine*, 319(13), 835-841.

12. McWilliams, J. M., Hatfield, L. A., Chernew, M. E., Landon, B. E., & Schwartz, A. L. (2016). Early performance of accountable care organizations in Medicare. *New England Journal of Medicine*, 374(24), 2357-2366.

13. Newhouse, J. P. (1992). Medical care costs: How much welfare loss? *Journal of Economic Perspectives*, 6(3), 3-21.

14. Nordhaus, W. D. (2008). Baumol's diseases: A macroeconomic perspective. *The B.E. Journal of Macroeconomics*, 8(1), Article 9.

15. Robinson, J. C., & Brown, T. T. (2013). Increases in consumer cost sharing redirect patient volumes and reduce hospital prices for orthopedic surgery. *Health Affairs*, 32(8), 1392-1397.
