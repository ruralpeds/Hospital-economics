# Chapter 7: Healthcare Quality Measurement and Value

## Introduction

Healthcare quality — the degree to which health services for individuals and populations increase the likelihood of desired health outcomes and are consistent with current professional knowledge — is simultaneously the purpose of the healthcare system and one of its most persistent challenges. The Institute of Medicine's landmark 1999 report *To Err Is Human* estimated that between 44,000 and 98,000 Americans die annually from preventable medical errors, and its 2001 follow-up *Crossing the Quality Chasm* documented pervasive gaps between the care patients receive and the care that evidence supports. Two decades later, despite enormous investments in quality measurement, public reporting, and pay-for-performance, quality improvement remains uneven, quality disparities persist across race, income, and geography, and the fundamental challenge of defining and measuring quality in a system as complex as healthcare remains incompletely resolved.

From an economic perspective, quality measurement is not merely a clinical concern but a central element of market design. Information asymmetry about quality is one of the defining market failures in healthcare (Chapter 1). If patients cannot observe quality, competitive pressures do not reward high-quality providers or penalize low-quality ones. Quality measurement and public reporting represent interventions to reduce this information asymmetry. Pay-for-performance and value-based payment represent interventions to create financial incentives for quality improvement. And the value equation — outcomes achieved relative to costs incurred — provides the conceptual framework for aligning the economic and clinical objectives of the healthcare system.

This chapter provides a comprehensive treatment of healthcare quality economics for graduate researchers. We cover quality measurement frameworks, the infrastructure of US quality measurement programs, the economics of medical errors and patient safety, pay-for-performance theory and evidence, public reporting, value-based healthcare frameworks, quality disparities, and the economics of low-value care and overuse. Throughout, the chapter is grounded in the specific programs and metrics of the US healthcare system.

## Defining and Measuring Quality

### Donabedian's Structure-Process-Outcome Framework

Avedis Donabedian's (1966, 1988) tripartite framework for quality assessment — structure, process, and outcome — remains the foundational conceptual model for healthcare quality measurement.

**Structure** refers to the characteristics of the setting in which care is delivered: physical facilities, equipment, staffing levels and qualifications, organizational characteristics, and financial resources. Structural measures are attractive because they are relatively easy to measure and because they reflect the capacity to deliver quality care. Examples include nurse-to-patient ratios, board certification of physicians, availability of electronic health records, and accreditation status. The limitation of structural measures is that the link between structure and outcomes is often weak and indirect — a well-equipped hospital with credentialed physicians may still deliver poor care if processes are dysfunctional.

**Process** refers to what is actually done in giving and receiving care: the clinical activities performed by providers (diagnosis, treatment, counseling, referral) and the actions taken by patients (adherence, self-management). Process measures capture the content of care delivery and are directly actionable — a hospital can improve its door-to-balloon time for STEMI patients, increase its rate of appropriate antibiotic prophylaxis, or improve its screening mammography completion rate through targeted quality improvement interventions. Examples include administration of aspirin at arrival for acute myocardial infarction, HbA1c testing for diabetic patients, and timely administration of antibiotics for pneumonia.

Process measures are most informative when there is strong evidence linking the process to improved outcomes. When this evidence-outcome link is established (as for aspirin in MI, anticoagulation for atrial fibrillation, or beta-blocker therapy after MI), process measures serve as valid proxies for outcomes. When the evidence base is weak or the process-outcome relationship is complex, process measures may reward activity without improving health.

**Outcome** refers to the effects of care on health status: mortality, morbidity, functional status, patient experience, and patient-reported outcomes. Outcome measures are the most direct indicators of quality — they capture what ultimately matters to patients. However, outcomes are influenced by many factors beyond the quality of care, including patient severity, comorbidities, socioeconomic status, and random variation. Meaningful comparison of outcomes across providers requires risk adjustment — statistical models that account for differences in patient characteristics — to isolate the contribution of care quality from the contribution of patient factors.

### The IOM Quality Framework: STEEEP

The Institute of Medicine's 2001 report *Crossing the Quality Chasm* defined six aims for healthcare improvement, captured by the acronym STEEEP:

**Safe**: Avoiding harm to patients from the care that is intended to help them. Safety encompasses freedom from medical errors, healthcare-associated infections, adverse drug events, falls, and other preventable harms.

**Timely**: Reducing waits and sometimes harmful delays for both those who receive and those who give care. Timeliness includes both emergency care response times and wait times for scheduled appointments, referrals, and test results.

**Effective**: Providing services based on scientific knowledge to all who could benefit and refraining from providing services to those not likely to benefit. Effectiveness requires alignment between clinical practice and the evidence base.

**Efficient**: Avoiding waste, including waste of equipment, supplies, ideas, and energy. Efficiency encompasses both technical efficiency (maximizing output per unit of input) and allocative efficiency (directing resources to their highest-value uses).

**Equitable**: Providing care that does not vary in quality because of personal characteristics such as gender, ethnicity, geographic location, and socioeconomic status.

**Patient-centered**: Providing care that is respectful of and responsive to individual patient preferences, needs, and values, and ensuring that patient values guide all clinical decisions.

These six aims provide a comprehensive framework for quality measurement that extends beyond traditional clinical metrics to encompass the patient experience, equity, and efficiency dimensions that are central to health economics.

## Quality Measurement Infrastructure in the United States

### The National Quality Forum

The National Quality Forum (NQF) serves as the primary consensus-based organization for healthcare quality measurement in the United States. NQF's endorsement process evaluates proposed quality measures against four criteria: importance (the measure addresses a significant health issue), scientific acceptability (the measure is reliable, valid, and evidence-based), usability (the measure is useful for quality improvement and accountability), and feasibility (the measure can be implemented with available data at reasonable cost).

NQF endorsement has become a de facto prerequisite for adoption of quality measures in federal programs. CMS's quality reporting and payment programs (Hospital Inpatient Quality Reporting, Hospital Value-Based Purchasing, MIPS) preferentially use NQF-endorsed measures, and private payers and accreditation organizations increasingly align their quality metrics with NQF-endorsed measures.

### CMS Quality Programs

CMS operates an extensive portfolio of quality measurement, reporting, and payment programs that collectively represent the most ambitious government-sponsored quality infrastructure in the world.

**Hospital Inpatient Quality Reporting (IQR) Program.** Hospitals that fail to report required quality measures receive a 25% reduction in their annual payment update. The IQR program collects data on clinical process measures, outcome measures (mortality, readmissions, complications), patient experience (HCAHPS), and healthcare-associated infection rates.

**Hospital Value-Based Purchasing (VBP) Program.** As discussed in Chapter 3, VBP withholds 2% of hospital DRG payments and redistributes funds based on performance across four domains: clinical outcomes (25%), safety (25%), person and community engagement (25%), and efficiency (25%). Performance is assessed through both achievement (performance relative to national benchmarks) and improvement (performance relative to the hospital's own baseline), with the higher of the two scores used. Approximately half of hospitals receive net positive adjustments and half receive net negative adjustments in any given year.

**Hospital Readmissions Reduction Program (HRRP).** The HRRP penalizes hospitals with excess 30-day readmission rates for targeted conditions (acute myocardial infarction, heart failure, pneumonia, COPD, hip/knee replacement, coronary artery bypass graft). Excess readmissions are defined relative to the national average after risk adjustment. Maximum penalties are capped at 3% of base operating DRG payments. The program has been credited with reducing readmission rates nationally but has also been criticized for disproportionately penalizing safety-net hospitals that serve disadvantaged populations with higher baseline readmission risk.

**Hospital-Acquired Condition Reduction Program (HACRP).** The HACRP imposes a 1% payment reduction on the quartile of hospitals with the highest rates of hospital-acquired conditions, including central line-associated bloodstream infections (CLABSI), catheter-associated urinary tract infections (CAUTI), surgical site infections, MRSA bacteremia, C. difficile infections, and patient safety indicators (PSIs) from claims data.

**Star Ratings.** CMS publishes overall hospital quality star ratings (1-5 stars) on the Hospital Compare website, calculated from a weighted composite of approximately 47 quality measures grouped into seven categories. The star rating system has been controversial due to methodological concerns (the grouping methodology, the treatment of missing data, the sensitivity of ratings to small changes in methodology) and because of its potential to mislead consumers who may interpret the single summary rating as a comprehensive assessment of hospital quality.

### AHRQ Quality Indicators

The Agency for Healthcare Research and Quality (AHRQ) maintains a set of quality indicators derived from administrative claims data that are widely used for quality screening, benchmarking, and research:

**Patient Safety Indicators (PSIs)** identify potentially preventable complications and adverse events during hospitalization, such as pressure ulcers, postoperative respiratory failure, accidental puncture or laceration, and death among surgical inpatients with treatable complications. PSIs are calculated from ICD-10-CM/PCS coded discharge data and serve as flags for potential quality problems rather than definitive measures of error.

**Inpatient Quality Indicators (IQIs)** measure inpatient mortality for specific conditions and procedures (acute MI mortality, heart failure mortality, pneumonia mortality, hip fracture mortality) and volume of procedures associated with volume-outcome relationships (coronary artery bypass graft, abdominal aortic aneurysm repair, pancreatic resection).

**Prevention Quality Indicators (PQIs)** measure ambulatory care-sensitive hospitalizations — hospitalizations for conditions such as diabetes, hypertension, asthma, and COPD that should be preventable with good outpatient care. Elevated PQI rates suggest deficiencies in access to or quality of primary care.

**Pediatric Quality Indicators (PDIs)** adapt the PSI and PQI concepts to the pediatric population, addressing conditions and complications specific to children.

### Risk Adjustment for Quality Comparison

Comparing quality across providers requires risk adjustment to account for differences in patient populations. Without risk adjustment, hospitals that treat sicker, older, or more socioeconomically disadvantaged patients will appear to have worse outcomes, even if the quality of care they provide is equivalent to or better than that of hospitals serving healthier populations.

The standard approach to risk adjustment for quality measurement uses hierarchical generalized linear models (HGLMs, also called multilevel models) that estimate hospital-specific effects after controlling for patient-level risk factors. CMS's readmission and mortality models, for example, use hierarchical logistic regression with patient-level covariates (age, sex, comorbidities derived from claims data) and hospital-level random effects. The hospital-specific predicted outcome is then compared to the expected outcome (based on the national average for patients with similar risk profiles) to yield a risk-standardized ratio.

The risk adjustment methodology has been criticized on several grounds. First, the models rely on administrative claims data, which may incompletely capture disease severity — sicker patients may have more diagnoses coded, creating a positive correlation between coding intensity and apparent risk that could mask true quality differences. Second, the models do not adjust for socioeconomic status (SES), which is independently associated with outcomes but may also reflect quality differences in the care delivered to disadvantaged populations. CMS added dual-eligibility stratification to the HRRP in response to evidence that safety-net hospitals were disproportionately penalized, but the broader question of SES adjustment in quality measurement remains unresolved.

## The Economics of Medical Errors and Patient Safety

### Economic Burden of Adverse Events

Medical errors and adverse events impose substantial economic costs on the healthcare system, patients, and society. The economic burden operates through several channels: direct costs of treating complications and injuries caused by errors, extended hospital stays, additional procedures and medications, legal and malpractice costs, and indirect costs of disability, lost productivity, and premature mortality.

Estimating the total economic burden of medical errors is methodologically challenging because many errors are not reported or documented, the causal attribution of complications to errors (vs. underlying disease progression) is often uncertain, and the counterfactual (what would have happened without the error) is inherently unobservable. Published estimates vary widely depending on definitions, data sources, and methodology.

Shreve and colleagues (2010) estimated the annual cost of measurable medical errors in the United States at approximately $17.1 billion, based on analysis of claims data for five categories of errors: medication errors, surgical errors, diagnostic errors, therapeutic errors, and preventive errors. Andel and colleagues (2012) estimated broader costs of $19.5 billion annually. These estimates almost certainly understate the true economic burden because they capture only errors that are documented in claims data and do not include the full range of patient safety events.

### Never Events and Non-Payment Policies

CMS's hospital-acquired conditions (HAC) policy, implemented in 2008, eliminated Medicare payment for certain "never events" — serious adverse events that should never occur in a healthcare setting, such as surgery on the wrong body part, foreign objects retained after surgery, air embolism, and blood incompatibility. The policy was expanded to include additional hospital-acquired conditions such as CLABSI, CAUTI, surgical site infections after specific procedures, and falls and trauma.

The economic logic of non-payment for preventable events is straightforward: if hospitals bear the financial cost of their own errors, they have a direct financial incentive to invest in prevention. However, the empirical evidence on whether non-payment policies actually reduce the incidence of targeted events is mixed. Lee and colleagues (2012) found modest reductions in some targeted conditions following the CMS HAC policy, but the effects were small and difficult to attribute causally to the payment change (as opposed to concurrent quality improvement initiatives and secular trends).

### Economics of Patient Safety Interventions

Patient safety interventions — checklists, computerized physician order entry (CPOE), bar-coded medication administration, surgical safety protocols, rapid response teams — require upfront investment in technology, training, and workflow redesign. The economic evaluation of these interventions follows the CEA framework developed in Chapter 6, comparing the cost of the intervention with the cost savings from prevented adverse events and the health outcomes gained.

Several patient safety interventions have been demonstrated to be cost-saving (the intervention reduces total costs by preventing expensive complications). Central line insertion checklists, which dramatically reduce CLABSI rates, are among the most cost-effective patient safety interventions, with estimated savings of $10,000 to $40,000 per prevented infection. CPOE systems require larger upfront investments ($5 million to $20 million for a large hospital) but can reduce medication errors by 50% to 80% and generate long-term cost savings through error prevention and efficiency gains.

## Pay-for-Performance Economics

### Theoretical Models of Optimal P4P Design

The theoretical literature on pay-for-performance in healthcare draws on the principal-agent framework from contract theory. The payer (principal) seeks to incentivize the provider (agent) to deliver high-quality care, but quality is imperfectly observable and the provider's effort is not directly contractible. The optimal P4P contract must balance several competing objectives.

**Incentive power vs. risk.** Stronger financial incentives for measured quality increase the provider's motivation to improve quality but also expose the provider to financial risk from factors beyond their control (random variation in outcomes, measurement error, case mix). Risk-averse providers will demand compensation for bearing this risk (a risk premium), increasing the cost of the P4P program. The optimal incentive power depends on the provider's degree of risk aversion, the noise in the quality signal, and the provider's ability to influence quality through effort.

**The multitasking problem.** Holmstrom and Milgrom (1991) demonstrated that when agents perform multiple tasks, incentivizing performance on measured tasks will divert effort from unmeasured tasks. In healthcare, where providers perform hundreds of distinct activities and quality has multiple dimensions (clinical effectiveness, safety, patient experience, equity, efficiency), incentivizing a small number of measured quality indicators may lead providers to neglect unmeasured dimensions. This concern has been borne out empirically: studies of P4P programs have documented improvements in incentivized measures accompanied by no change or deterioration in non-incentivized measures.

**Threshold vs. continuous incentives.** P4P programs differ in whether they reward performance above a fixed threshold (absolute P4P), improvement from a baseline (relative P4P), or tournament-style rankings (competitive P4P). Each design has different incentive properties. Threshold-based incentives create strong motivation for providers near the threshold but weak motivation for those far above or below it. Improvement-based incentives reward all providers for gains but create a perverse incentive: providers who perform well at baseline have less room for improvement and may be penalized relative to providers who started with poor performance.

Mullen, Frank, and Rosenthal (2010) developed a formal model of optimal P4P design in healthcare that incorporates risk aversion, multitasking, and gaming. Their key finding is that optimal P4P contracts are complex, involving multiple measures with carefully calibrated weights, and that the optimal incentive power is substantially weaker than what would be optimal in a single-task setting without gaming concerns.

### Empirical Evidence on P4P

**The Premier Hospital Quality Incentive Demonstration (HQID).** One of the earliest and most rigorously evaluated P4P programs, the Premier HQID (2003-2009) offered bonus payments to hospitals in the top performance deciles on process quality measures and penalties to those in the bottom deciles. Ryan (2009) and Werner and Dudley (2012) found modest improvements in incentivized measures (1-4 percentage points) but no significant effects on patient outcomes (mortality, readmissions). Quality improvements were larger for measures with more room for improvement and for hospitals with greater financial exposure to the incentives.

**The UK Quality and Outcomes Framework (QOF).** The QOF, implemented in 2004, is the largest P4P program in the world, linking approximately 25% of general practitioner income to performance on approximately 130 quality indicators. Studies by Doran and colleagues (2006) and Campbell and colleagues (2009) found that the QOF was associated with improvements in measured quality indicators, but that much of the improvement reflected pre-existing trends that would have occurred without the incentive. There was also evidence of ceiling effects (little further improvement once performance approached maximum achievable levels), gaming (exception reporting to exclude difficult patients from quality denominators), and neglect of non-incentivized aspects of care.

**The Hospital VBP Program.** Evaluations of CMS's Hospital VBP Program have found limited effects on the targeted quality measures. Figueroa and colleagues (2016) found no significant improvement in 30-day mortality or patient experience attributable to VBP, suggesting that the 2% financial stake was insufficient to motivate meaningful behavioral change at the hospital level.

### Gaming and Unintended Consequences

P4P programs are vulnerable to gaming — strategic behavior that improves measured performance without improving actual quality. Common gaming strategies include:

**Upcoding and documentation improvement.** Providers may invest in more thorough documentation of patient severity to improve risk-adjusted performance without changing clinical practice. While better documentation can be beneficial (improving communication and care coordination), its effect on quality measurement is to make the provider's patients appear sicker, thereby lowering the risk-adjusted expected outcome and making actual outcomes appear relatively better.

**Patient selection.** Providers may avoid treating high-risk patients who are likely to have poor outcomes, or may selectively refer difficult cases to other providers. Evidence from cardiac surgery report cards in New York and Pennsylvania suggests that the publication of surgeon-specific mortality rates led some surgeons to avoid operating on the sickest patients, with consequent access problems for high-risk patients.

**Teaching to the test.** Providers may concentrate improvement efforts narrowly on measured indicators while neglecting unmeasured aspects of quality. If P4P rewards door-to-balloon time for STEMI patients, hospitals may invest heavily in STEMI protocols while underinvesting in the quality of care for unstroke patients, sepsis patients, or other conditions not subject to P4P incentives.

---

**Key Concepts Box: Pay-for-Performance Design Elements**

| Design Element | Options | Trade-off |
|---|---|---|
| Performance basis | Absolute level vs. improvement vs. ranking | Level rewards high performers; improvement rewards progress; ranking creates zero-sum competition |
| Financial stake | Small (1-2%) vs. large (10-25% of revenue) | Larger stakes create stronger incentives but greater risk and gaming pressure |
| Measure selection | Process vs. outcome vs. composite | Process is actionable; outcome is meaningful; composite risks obscuring signal |
| Risk adjustment | Claims-based vs. clinical data-based | Clinical is more accurate but costlier to collect |
| Attribution | Individual provider vs. facility vs. system | Individual creates strongest incentive but noisiest signal |
| Penalty vs. reward | Bonus payments vs. withholds vs. both | Losses loom larger than gains (prospect theory) but penalties are politically difficult |

---

## Public Reporting and Information Economics

### Theoretical Effects

Public reporting of healthcare quality information addresses the information asymmetry between providers and patients that is a central market failure in healthcare (Chapter 1). The theoretical mechanisms through which public reporting can improve quality include:

**Selection pathway.** Informed patients select higher-quality providers, shifting market share toward better performers. This competitive pressure creates financial incentives for providers to improve quality, even in the absence of explicit P4P programs. The selection pathway requires that patients access and use quality information, that they can distinguish quality signals from noise, and that they can act on their preferences (switching costs, network restrictions, and geographic constraints may limit patient choice).

**Reputation pathway.** Providers value their professional reputation and may improve quality in response to publicly reported information even in the absence of competitive market share effects. The reputation mechanism operates through physician and hospital pride, recruitment and retention of staff, and relationships with referring physicians.

**Quality improvement pathway.** Public reporting generates data that providers can use for internal quality improvement, benchmarking against peers, and identifying areas for targeted improvement efforts.

### Empirical Evidence

The empirical evidence on whether patients use publicly reported quality information to guide provider choice is disappointing. Multiple studies have found that only a small proportion of patients (typically 5% to 15%) report using quality report cards when choosing hospitals or physicians, and that the patients who do use the information tend to be younger, better educated, and healthier — the population segment least in need of quality guidance.

However, the evidence on provider behavioral responses to public reporting is more positive. Hibbard, Stockard, and Tusler (2003) found that hospitals subject to public reporting demonstrated greater quality improvement than hospitals whose performance data were reported only privately. The mechanism appears to be primarily reputational — hospitals improve quality to avoid the embarrassment of poor public performance — rather than competitive market share effects.

The most extensively studied public reporting program is the New York State cardiac surgery reporting system, which has published risk-adjusted mortality rates for cardiac surgeons and hospitals since 1989. The program has been associated with significant reductions in cardiac surgery mortality, but also with concerns about risk-averse surgeon behavior (avoiding high-risk patients) and migration of high-risk cases to neighboring states. Dranove and colleagues (2003) found evidence that cardiac surgery report cards led to worse matching between patient severity and surgeon quality — an unintended consequence with negative welfare implications.

## Value-Based Healthcare Frameworks

### Porter's Value Equation

Michael Porter's value framework defines healthcare value as the ratio of outcomes achieved to costs incurred:

Value = Health Outcomes / Cost

Porter argues that value, measured for specific medical conditions over the full cycle of care, should be the organizing principle of healthcare delivery and payment. This framework rejects the traditional volume-driven model (which maximizes revenue by maximizing activity) in favor of an outcome-driven model that rewards providers for achieving the best possible outcomes at the lowest possible cost.

The practical implementation of Porter's value framework requires measurement of both components: outcomes (including both clinical outcomes and patient-reported outcomes) and costs (measured using time-driven activity-based costing rather than charges or aggregate cost data). Porter and colleagues have developed condition-specific outcome measure sets through the International Consortium for Health Outcomes Measurement (ICHOM), covering over 40 medical conditions.

### The Triple Aim and Quadruple Aim

The Institute for Healthcare Improvement's (IHI) Triple Aim framework, articulated by Berwick, Nolan, and Whittington (2008), identifies three simultaneous objectives for health system performance: improving the patient experience of care, improving the health of populations, and reducing the per capita cost of healthcare. The Triple Aim has been widely adopted as a strategic framework by health systems, payers, and policymakers.

The Quadruple Aim (Bodenheimer and Sinsky, 2014) extends the Triple Aim by adding a fourth objective: improving the work life of healthcare providers. This addition reflects growing concern about clinician burnout, moral distress, and workforce turnover, which threaten the sustainability of quality improvement efforts and the healthcare workforce itself. From an economic perspective, clinician burnout represents a negative externality of quality measurement and administrative burden — the costs of measurement and reporting are borne by clinicians in the form of reduced time for patient care, increased documentation burden, and diminished professional satisfaction.

## Quality Disparities

### Economic Determinants

Healthcare quality varies systematically across racial, ethnic, socioeconomic, and geographic lines, and these disparities impose both health and economic costs on disadvantaged populations and on society.

**Racial and ethnic disparities.** The AHRQ National Healthcare Quality and Disparities Report documents persistent disparities in healthcare quality by race and ethnicity. Black and Hispanic patients receive lower-quality care than White patients on a majority of quality indicators, including rates of preventive screening, chronic disease management, surgical outcomes, and patient experience. The sources of these disparities include differential access to high-quality providers, implicit bias in clinical decision-making, structural racism in healthcare delivery systems, and socioeconomic factors correlated with race that independently affect care quality.

**Geographic disparities.** Quality varies substantially across geographic areas, with rural areas generally performing worse than urban areas on many quality indicators. Rural hospitals have higher risk-adjusted mortality for common conditions, lower process quality scores, and more limited access to specialist services. These geographic disparities reflect workforce shortages, lower patient volumes (which are associated with worse outcomes for volume-sensitive procedures), greater distance to tertiary care, and the financial constraints facing rural and critical access hospitals (Chapter 8).

**Socioeconomic disparities.** Lower-income patients and patients with Medicaid coverage receive lower-quality care on many measures, in part because of the concentration of disadvantaged patients in lower-quality providers and in part because of the direct effects of socioeconomic disadvantage on health behaviors, treatment adherence, and care navigation.

## The Cost of Poor Quality

### Waste Taxonomy

Berwick and Hackbarth (2012) estimated that waste in the US healthcare system accounts for approximately 34% of total healthcare spending — roughly $935 billion annually (in 2011 dollars). They identified six categories of waste:

**Failures of care delivery** ($102-154 billion): poor execution of care processes, inadequate prevention, avoidable complications.

**Failures of care coordination** ($25-45 billion): fragmented care across providers and settings, unnecessary hospitalizations, avoidable ED visits.

**Overtreatment** ($158-226 billion): provision of services beyond evidence-established levels, preference-sensitive care delivered without shared decision-making.

**Administrative complexity** ($107-389 billion): excessive paperwork, duplicative reporting, complex billing.

**Pricing failures** ($84-178 billion): prices that exceed competitive levels due to market power, opacity, or regulatory capture.

**Fraud and abuse** ($82-272 billion): fraudulent billing, kickbacks, inappropriate self-referral.

### Low-Value Care and the Choosing Wisely Campaign

Low-value care — services that provide little or no clinical benefit relative to their cost or potential harm — represents a specific and measurable component of healthcare waste. The Choosing Wisely campaign, launched by the ABIM Foundation in 2012, has engaged over 80 medical specialty societies in identifying more than 600 specific tests, treatments, and procedures that are commonly overused.

Measuring low-value care from claims data requires translating clinical recommendations into operational algorithms based on diagnosis codes, procedure codes, and patient characteristics. Schwartz and colleagues (2014) developed claims-based measures for 26 low-value services and estimated that approximately 25% to 30% of the measured services were delivered to patients for whom they were unlikely to provide benefit.

The economic approach to reducing low-value care involves both demand-side strategies (patient education, shared decision-making, cost-sharing for low-value services) and supply-side strategies (clinical decision support, physician feedback, guideline implementation, prior authorization). The evidence on the effectiveness of these strategies is mixed, with the most promising results from multi-component interventions that combine professional education, data feedback, and system-level workflow changes.

---

**Table 7.1: CMS Hospital Quality and Payment Programs**

| Program | Year Launched | Financial Mechanism | Maximum Financial Impact | Key Measures |
|---|---|---|---|---|
| Hospital IQR | 2004 | Payment update reduction for non-reporting | 25% of annual update | Process, outcome, patient experience |
| Hospital VBP | 2012 | Redistribution of withheld DRG payments | 2% of base DRG | Clinical outcomes, safety, HCAHPS, efficiency |
| HRRP | 2012 | Penalty for excess readmissions | 3% of base operating DRG | 30-day readmission for 6 conditions |
| HACRP | 2014 | Penalty for worst-quartile HAC rates | 1% of total DRG | CLABSI, CAUTI, SSI, MRSA, C. diff, PSIs |
| Star Ratings | 2016 | Informational (no direct financial impact) | Reputational | Composite of ~47 measures across 7 groups |

---

## Conclusion

Healthcare quality measurement operates at the intersection of clinical science, information economics, and incentive design. The fundamental economic challenge is straightforward: quality is a credence good that patients cannot easily evaluate, creating information asymmetry that undermines competitive market incentives for quality improvement. Quality measurement, public reporting, and pay-for-performance represent interventions to address this market failure, but each confronts practical limitations — measurement imprecision, gaming, multitasking distortions, and the modest financial stakes of current P4P programs.

The empirical evidence suggests that quality measurement and reporting have contributed to modest improvements in measured quality, but that the improvements are smaller than proponents anticipated, unevenly distributed across measures and settings, and accompanied by unintended consequences including gaming, patient selection, and neglect of unmeasured quality dimensions. The most promising directions for quality improvement involve moving beyond individual quality metrics toward comprehensive value measurement (outcomes relative to costs), addressing quality disparities through equity-focused measurement and payment, and reducing low-value care through evidence-based identification and targeted intervention.

The econometric methods for evaluating quality improvement interventions — difference-in-differences for policy implementation (Chapter 11), regression discontinuity for threshold-based programs (Chapter 12), and hierarchical models for provider profiling — are developed in subsequent chapters. The Julia implementation of risk-adjustment models and quality metric calculation is covered in Chapters 21 and 22.

## References

1. Berwick, D. M., & Hackbarth, A. D. (2012). Eliminating waste in US health care. *JAMA*, 307(14), 1513-1516.

2. Berwick, D. M., Nolan, T. W., & Whittington, J. (2008). The triple aim: Care, health, and cost. *Health Affairs*, 27(3), 759-769.

3. Bodenheimer, T., & Sinsky, C. (2014). From triple to quadruple aim: Care of the patient requires care of the provider. *Annals of Family Medicine*, 12(6), 573-576.

4. Campbell, S. M., Reeves, D., Kontopantelis, E., Sibbald, B., & Roland, M. (2009). Effects of pay for performance on the quality of primary care in England. *New England Journal of Medicine*, 361(4), 368-378.

5. Donabedian, A. (1988). The quality of care: How can it be assessed? *JAMA*, 260(12), 1743-1748.

6. Doran, T., Fullwood, C., Gravelle, H., Reeves, D., Kontopantelis, E., Hiroeh, U., & Roland, M. (2006). Pay-for-performance programs in family practices in the United Kingdom. *New England Journal of Medicine*, 355(4), 375-384.

7. Dranove, D., Kessler, D., McClellan, M., & Satterthwaite, M. (2003). Is more information better? The effects of "report cards" on health care providers. *Journal of Political Economy*, 111(3), 555-588.

8. Figueroa, J. F., Tsugawa, Y., Zheng, J., Orav, E. J., & Jha, A. K. (2016). Association between the Value-Based Purchasing pay for performance program and patient mortality in US hospitals. *BMJ*, 353, i2214.

9. Hibbard, J. H., Stockard, J., & Tusler, M. (2003). Does publicizing hospital performance stimulate quality improvement efforts? *Health Affairs*, 22(2), 84-94.

10. Holmstrom, B., & Milgrom, P. (1991). Multitask principal-agent analyses: Incentive contracts, asset ownership, and job design. *Journal of Law, Economics, and Organization*, 7(Special Issue), 24-52.

11. Institute of Medicine. (1999). *To Err Is Human: Building a Safer Health System*. National Academies Press.

12. Institute of Medicine. (2001). *Crossing the Quality Chasm: A New Health System for the 21st Century*. National Academies Press.

13. Mullen, K. J., Frank, R. G., & Rosenthal, M. B. (2010). Can you get what you pay for? Pay-for-performance and the quality of healthcare providers. *RAND Journal of Economics*, 41(1), 64-91.

14. Porter, M. E. (2010). What is value in health care? *New England Journal of Medicine*, 363(26), 2477-2481.

15. Ryan, A. M. (2009). Effects of the Premier Hospital Quality Incentive Demonstration on Medicare patient mortality and cost. *Health Services Research*, 44(3), 821-842.

16. Schwartz, A. L., Landon, B. E., Elshaug, A. G., Chernew, M. E., & McWilliams, J. M. (2014). Measuring low-value care in Medicare. *JAMA Internal Medicine*, 174(7), 1067-1076.

17. Shreve, J., Van Den Bos, J., Gray, T., Halford, M., Rustagi, K., & Ziemkiewicz, E. (2010). *The Economic Measurement of Medical Errors*. Society of Actuaries.
