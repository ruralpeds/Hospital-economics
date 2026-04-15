# Healthcare Economics Research — Quick Analysis Guide

## Starting a New Research Analysis

### Step 1: Define Your Research Question (30 minutes)

```
Template:
"In [Population], what is the [Economic outcome] of [Intervention] 
compared to [Comparator] from the [Perspective] perspective?"

Examples:
- "In preterm infants, what is the cost-effectiveness of HFOV vs. conventional 
  ventilation from the healthcare system perspective?"
- "In Medicare patients with heart failure, what is the ROI of a care coordination 
  program compared to standard care from the payer perspective?"
- "In rural communities, what is the financial impact of a telemedicine program 
  on hospital viability?"
```

### Step 2: Outline Your Analysis (1 hour)

```
[ ] Define population: Who is included? (N, demographics, inclusion/exclusion)
[ ] Specify intervention: What exactly are you studying?
[ ] Identify comparator: Standard care or alternative?
[ ] Choose outcomes: Cost? QALYs? Clinical outcomes? All?
[ ] Select perspective: Healthcare system? Payer? Societal? Provider?
[ ] Set time horizon: 1 year? 5 years? Lifetime?
[ ] Identify data source: EHR? Claims? Trial? Literature?
[ ] Plan analysis: Deterministic? Sensitivity? Monte Carlo?
```

### Step 3: Set Up Your Analysis (2-4 hours)

```julia
using HospitalFinanceToolbox
using Dates, CSV, DataFrames

# 1. Load or generate your data
patients = CSV.read("patient_data.csv", DataFrame)

# 2. Create episode records
episodes = [
    Episode(
        episode_id = row.id,
        patient_id = row.patient_id,
        primary_diagnosis = row.diagnosis,
        drg_code = row.drg,
        # ... other fields
    ) 
    for row in eachrow(patients)
]

# 3. Define your cost model
cost_model = DRGCostModel(
    drg_base_rates = your_rates,
    complication_multiplier = 0.25
)

# 4. Calculate costs
episode_costs = [calculate_episode_cost(ep, cost_model) for ep in episodes]

# 5. Track outcomes
outcomes = [
    EpisodeOutcomes(
        episode_id = ep.episode_id,
        survived = survived_status,
        qaly_gained = calculated_qaly,
        total_cost = cost
    )
    for (ep, cost, ...) in zip(episodes, episode_costs, ...)
]

# 6. Analyze cost-effectiveness
icer = calculate_icer(
    intervention_cost = mean([o.total_cost for o in intervention_outcomes]),
    intervention_effect = mean([o.qaly_gained for o in intervention_outcomes]),
    control_cost = mean([o.total_cost for o in control_outcomes]),
    control_effect = mean([o.qaly_gained for o in control_outcomes])
)

println(recommend_intervention(icer))
```

### Step 4: Run Your Analysis (Variable)

**Base Case (Deterministic):**
- Point estimates
- Mean costs and effects
- Single ICER value
- Runtime: Minutes to hours

**Sensitivity Analysis:**
- ±10-20% on key parameters
- Tornado diagram (parameter importance)
- Threshold analysis (critical values)
- Runtime: Hours

**Probabilistic (Monte Carlo):**
- Parameter distributions
- 1,000-10,000 iterations
- Cost-effectiveness plane
- Cost-effectiveness acceptability curve
- Runtime: Minutes to hours

### Step 5: Report Your Findings (2-4 hours)

**Essential Outputs:**
1. Cost-effectiveness result (ICER, dominance status)
2. Cost comparison (mean, median, range)
3. Outcome comparison (survival, QALYs, clinical metrics)
4. Sensitivity analysis (what if scenarios)
5. Decision rule (recommendation at willingness-to-pay threshold)

**Optional/Advanced:**
6. Cost-effectiveness plane plot
7. Cost-effectiveness acceptability curve
8. Subgroup analysis
9. Budget impact projection
10. Implementation considerations

---

## Research Analysis Checklists

### Pre-Analysis Checklist

- [ ] Research protocol approved by IRB/Ethics Board (if human subjects)
- [ ] Research question clearly defined and specific
- [ ] Study population defined (inclusion/exclusion criteria)
- [ ] Intervention and comparator clearly described
- [ ] Primary and secondary outcomes specified
- [ ] Perspective (healthcare system, payer, societal) chosen
- [ ] Time horizon selected
- [ ] Discount rate (if multi-year) determined
- [ ] Data sources identified and accessible
- [ ] Analysis software (Julia + HospitalFinanceToolbox) set up

### Data Analysis Checklist

- [ ] Data imported and validated
- [ ] Cohort characteristics summarized
- [ ] Missing data assessed and handled
- [ ] Cost data completeness verified
- [ ] Outcome data quality checked
- [ ] Outliers reviewed (appropriate vs. errors?)
- [ ] Statistical assumptions tested
- [ ] Baseline balance between groups assessed (if comparative)
- [ ] Confounding variables identified
- [ ] Analysis-ready dataset created

### Cost Analysis Checklist

- [ ] Cost categories identified (direct, indirect, intangible)
- [ ] Cost sources documented (claims, charges, micro-costing?)
- [ ] Allocation methods specified
- [ ] Inflation adjustments applied (if multi-year data)
- [ ] Currency/year standardized
- [ ] Cost model validated on subset of data
- [ ] Mean and median costs calculated
- [ ] Cost distributions examined
- [ ] Outliers reviewed and handled
- [ ] Sensitivity on cost assumptions tested

### Outcome Analysis Checklist

- [ ] Outcome definitions standardized across groups
- [ ] Outcome measurement timing specified
- [ ] Clinical outcomes calculated
- [ ] QALYs calculated from [source of utility weights]
- [ ] Quality/safety metrics assessed
- [ ] Missing outcome data handled
- [ ] Subgroup outcomes examined
- [ ] Time-to-event analysis (if applicable) performed
- [ ] Outcome validation completed

### Cost-Effectiveness Analysis Checklist

- [ ] Base case ICER calculated (point estimate)
- [ ] Dominance status determined
- [ ] Decision rule applied (cost-effective? yes/no)
- [ ] Uncertainty quantified (confidence intervals)
- [ ] One-way sensitivity analysis completed
- [ ] Tornado diagram created (parameter importance)
- [ ] Probabilistic sensitivity analysis run (if applicable)
- [ ] Cost-effectiveness plane plotted
- [ ] CEAC curve generated
- [ ] Key drivers identified

### Results Interpretation Checklist

- [ ] ICER compared to established thresholds ($50K, $100K, $150K/QALY)
- [ ] Clinical significance assessed (beyond statistics)
- [ ] Generalizability discussed (internal/external validity)
- [ ] Limitations acknowledged
- [ ] Assumptions listed and justified
- [ ] Subgroup findings interpreted
- [ ] Uncertainty in decision discussed
- [ ] Competing values addressed
- [ ] Implementation barriers identified
- [ ] Next steps for research/practice identified

### Publication Checklist

- [ ] Methods fully documented and reproducible
- [ ] Results reported with precision and uncertainty
- [ ] Tables/figures clear and self-contained
- [ ] Supplementary materials complete
- [ ] Data availability statement included
- [ ] Funding sources disclosed
- [ ] Conflicts of interest addressed
- [ ] Code and data shared (if appropriate)
- [ ] Open science practices applied
- [ ] Lay summary prepared

---

## Quick Reference: Common Research Scenarios

### Scenario 1: Cost-Effectiveness of Clinical Intervention
**Time:** 4-8 weeks  
**Data:** RCT or observational study with clinical + cost data  
**Output:** ICER, cost-effectiveness decision, publication

```julia
# Typical analysis structure
intervention_group_costs = [...]  # From cost analysis
intervention_group_qalys = [...]  # From quality weights
control_group_costs = [...]
control_group_qalys = [...]

icer = calculate_icer(
    intervention_cost = mean(intervention_group_costs),
    intervention_effect = mean(intervention_group_qalys),
    control_cost = mean(control_group_costs),
    control_effect = mean(control_group_qalys),
    ce_threshold = 100_000  # $100K/QALY threshold
)
```

### Scenario 2: Hospital Quality Improvement ROI
**Time:** 2-6 weeks  
**Data:** Before/after operational data + costs  
**Output:** ROI, break-even timeline, recommendation

```julia
# Pre-intervention analysis
baseline_outcomes = baseline_patients_analysis()
baseline_cost_per_patient = mean(baseline_outcomes.costs)

# Post-intervention analysis
intervention_outcomes = intervention_patients_analysis()
intervention_cost_per_patient = mean(intervention_outcomes.costs)

# Calculate impact
cost_improvement = baseline_cost_per_patient - intervention_cost_per_patient
outcome_improvement = intervention_outcomes.quality_score - baseline_outcomes.quality_score

# ROI calculation
total_implementation_cost = 50_000
months_to_breakeven = total_implementation_cost / (cost_improvement * cohort_size / 12)
```

### Scenario 3: Policy/Payer Analysis
**Time:** 6-12 weeks  
**Data:** Claims data, policy scenarios, simulation  
**Output:** Policy impact, budget impact, recommendations

```julia
# Scenario modeling
status_quo_cost = model_status_quo_scenario()
policy_change_cost = model_policy_scenario()
alternative_cost = model_alternative_scenario()

# Compare scenarios
budget_impact = policy_change_cost - status_quo_cost
cost_effectiveness = policy_change_cost / expected_benefits

# Sensitivity across scenarios
for assumption in key_assumptions
    adjusted_cost = adjust_for_assumption(policy_change_cost, assumption)
    # Repeat analysis with adjusted values
end
```

### Scenario 4: Real-World Data Analysis
**Time:** 8-16 weeks  
**Data:** EHR or claims data from 1,000-50,000+ patients  
**Output:** Effectiveness/costs in real practice, variation analysis

```julia
# Load real-world data
rwd_episodes = load_clinical_data("ehr_export.csv")

# Cohort definition
filtered_cohort = filter_to_inclusion_criteria(rwd_episodes)

# Cost and outcome analysis
costs = [calculate_episode_cost(ep, model) for ep in filtered_cohort]
outcomes = extract_clinical_outcomes(filtered_cohort)

# Real-world comparisons
intervention_cohort = filter(ep -> ep.intervention_received, filtered_cohort)
control_cohort = filter(ep -> !ep.intervention_received, filtered_cohort)

# Comparative analysis
rwd_icer = calculate_icer(
    intervention_cost = mean([cost for (ep,cost) in zip(intervention_cohort, costs) if ...]),
    intervention_effect = mean(intervention_outcomes),
    # ...
)

# Variation analysis
by_hospital = groupby(filtered_cohort, :hospital_id)
by_payer = groupby(filtered_cohort, :payer)
by_demographics = groupby(filtered_cohort, :age_group)
# Analyze within each group
```

---

## Key Research Parameters to Document

### Always Include in Your Analysis

```
# Population characteristics
- N (total sample size)
- N_intervention / N_control (group sizes)
- Age: Mean ± SD or range
- Sex: % female
- Race/ethnicity: %s by group
- Comorbidities: ICD-10 codes, Charlson score, etc.
- Severity: How measured?
- Insurance: Medicare/Medicaid/Commercial/Uninsured %s

# Cost data
- Cost year: 2024 dollars, adjusted for inflation?
- Cost source: Billing charges? Actual costs? Imputed?
- Included cost categories: Hospital? ED? Outpatient? Medications? All?
- Cost perspective: Payer? Healthcare system? Societal?
- Time period: Pre-intervention? During? Post?
- Follow-up duration: 30 days? 90 days? 1 year? Longer?

# Outcome data
- Primary outcome: How measured? From where?
- Outcome timing: At discharge? 30 days? 1 year?
- Clinical outcomes: Mortality? Morbidity? Specific events?
- QALYs: From what utility source? EQ-5D? VAS? Other?
- Quality/safety: How assessed?
- Missing data: How handled?

# Analysis details
- Time horizon: 1 year? 5 years? Lifetime?
- Discount rate: 0%? 3%? 3.5%?
- Perspective: Healthcare system? Payer? Societal?
- Sensitivity: Deterministic? Probabilistic? Both?
- Threshold: $50K? $100K? $150K per QALY?
- Software: Julia version? HospitalFinanceToolbox version?
```

---

## Research Resources

### Healthcare Economics References
- Briggs A, Claxton K, Sculpher M. Decision Modelling for Health Economic Evaluation. Oxford University Press, 2012.
- Sanders GD, et al. Recommendations for conduct, methodological practices, and reporting of cost-effectiveness analyses. JAMA. 2016;315(10):1009-1020.
- ISPOR Best Practices: https://www.ispor.org/research-guidance

### Julia Resources
- Julia documentation: https://docs.julialang.org
- HospitalFinanceToolbox documentation: (in this repository)

### Data & Methods
- CMS documentation: https://www.cms.gov
- EQ-5D utility weights: https://www.euroqol.org
- Healthcare cost benchmarks: Solucient, Optum, Truven

### Publication & Collaboration
- ISPOR conferences: https://www.ispor.org
- AcademyHealth: https://academyhealth.org
- Peer-reviewed journals: Health Economics, Medical Decision Making, etc.
