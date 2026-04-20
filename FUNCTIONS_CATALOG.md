# Healthcare Economics Research Functions Catalog

## 1. Data Collection & Integration

### Source Data Functions
- `ingest_hospital_data(source, format)` - Load hospital administrative data
- `ingest_claims_data(payer_id, date_range)` - Load insurance claims data
- `ingest_clinical_data(ehr_system, patient_ids)` - Load clinical/EHR data
- `ingest_financial_statements(facility_id, fiscal_period)` - Load financial records
- `ingest_registry_data(registry_name, cohort_filters)` - Load disease/outcome registries
- `validate_data_source(source_path, schema)` - Validate data structure and completeness
- `detect_data_quality_issues(dataframe, rules)` - Identify outliers, missing values, inconsistencies

### Data Transformation
- `normalize_patient_identifiers(data)` - Standardize patient IDs across sources
- `standardize_medical_codes(codes, target_schema)` - Convert ICD, CPT, HCPCS codes
- `aggregate_encounters(patient_data, time_period)` - Group episodes of care
- `calculate_risk_adjusters(patient_cohort)` - Compute HCC, CMS-HCC, or similar risk scores
- `impute_missing_values(data, strategy)` - Handle missing data with appropriate methods
- `create_time_series(longitudinal_data, interval)` - Restructure data for time-series analysis

---

## 2. Financial Analysis Functions

### Cost Analysis
- `calculate_total_cost_of_care(patient_id, date_range)` - Sum all costs for a patient
- `break_down_costs_by_category(charges, categories)` - Segment costs (inpatient, outpatient, pharmacy)
- `calculate_cost_per_episode(episode_data)` - Cost of a single episode of care
- `calculate_cost_per_quality_adjusted_year(cost, qaly_gained)` - Cost-effectiveness metric
- `identify_high_cost_patients(patient_cohort, percentile)` - Flag top cost drivers
- `project_cost_trends(historical_costs, time_periods)` - Forecast future costs

### Revenue & Reimbursement
- `calculate_total_revenue(claims, reimbursement_rates)` - Sum received or allowed amounts
- `calculate_denied_claims_impact(denied_claims)` - Quantify revenue loss from denials
- `analyze_payor_mix(claims)` - Distribution of payer types (Medicare, Medicaid, commercial)
- `calculate_provider_payment(claims, fee_schedule)` - Provider reimbursement amounts
- `simulate_reimbursement_change(claims, new_policy)` - Impact of policy changes on revenue

### Profitability & Operations
- `calculate_contribution_margin(revenue, variable_costs)` - Profit after variable costs
- `calculate_departmental_profitability(dept_id, period)` - Profit by department
- `analyze_fixed_vs_variable_costs(cost_data)` - Cost structure breakdown
- `calculate_break_even_volume(fixed_costs, contribution_margin)` - Volume needed for profitability
- `calculate_operating_margin(operating_income, revenue)` - Operational efficiency metric

---

## 3. Quality & Clinical Outcomes

### Quality Metrics
- `calculate_readmission_rate(cohort, days=30)` - % returning within N days
- `calculate_mortality_rate(cohort, time_period)` - In-hospital or short-term mortality
- `calculate_infection_rates(facility, infection_type)` - Hospital-acquired infection rates
- `calculate_complication_rates(procedure, complication_type)` - Post-operative complication rates
- `calculate_patient_safety_indicator(psi_measure, population)` - AHRQ PSI calculation
- `calculate_quality_metric(measure_id, denominator, numerator)` - Generic quality measure framework

### Outcomes Analysis
- `track_functional_status(patient_id, assessment_timeline)` - Mobility, ADL improvements
- `track_symptom_resolution(patient_id, symptom, timeline)` - Symptom improvement over time
- `calculate_quality_of_life_score(patient_data, scale)` - EQ-5D, SF-36, disease-specific scales
- `identify_outcome_disparities(outcomes, demographic_groups)` - Equity analysis by race, income, etc.
- `compare_outcomes_by_treatment(cohorts)` - Comparative effectiveness between interventions

---

## 4. Statistical & Econometric Analysis

### Descriptive Statistics
- `calculate_population_demographics(cohort)` - Age, sex, race/ethnicity distribution
- `calculate_comorbidity_burden(patient_cohort)` - Charlson, Elixhauser scores
- `calculate_summary_statistics(data, group_by)` - Mean, median, SD, quartiles
- `compare_groups_descriptively(group1, group2)` - Baseline characteristics table

### Inferential Statistics
- `perform_t_test(group1, group2)` - Compare means between two groups
- `perform_anova(groups)` - Compare means across multiple groups
- `perform_chi_square_test(contingency_table)` - Test categorical associations
- `perform_log_rank_test(survival_data, groups)` - Compare survival curves
- `calculate_confidence_intervals(data, confidence_level)` - Uncertainty quantification

### Regression Analysis
- `perform_linear_regression(X, y)` - Standard OLS regression
- `perform_logistic_regression(X, y_binary)` - Binary outcome modeling
- `perform_poisson_regression(X, y_count)` - Count data modeling
- `perform_negative_binomial_regression(X, y_count_overdispersed)` - For overdispersed counts
- `perform_cox_proportional_hazards(X, survival_time, event)` - Survival analysis
- `calculate_regression_diagnostics(model)` - Check assumptions, VIF, residuals

### Causal Inference
- `perform_propensity_score_matching(treatment, covariates)` - Observational study balance
- `perform_instrumental_variable_analysis(X, instrument, y)` - Address endogeneity
- `perform_difference_in_differences(before_after_groups)` - Policy impact evaluation
- `perform_regression_discontinuity(running_variable, cutoff, outcome)` - Sharp cutoff designs
- `estimate_heterogeneous_treatment_effects(treatment, covariates, outcome)` - Treatment effect variation

---

## 5. Economic Evaluation Functions

### Cost-Effectiveness Analysis
- `calculate_cost_effectiveness_ratio(cost, effect)` - ICER calculation
- `perform_sensitivity_analysis(base_case, parameter_ranges)` - Uncertainty analysis
- `perform_monte_carlo_simulation(parameters_distributions, n_iterations)` - Probabilistic sensitivity
- `calculate_incremental_net_benefit(cost, effect, willingness_to_pay)` - Net benefit framework
- `generate_cost_effectiveness_plane(icers)` - CE plane visualization

### Cost-Benefit Analysis
- `calculate_net_present_value(costs, benefits, discount_rate)` - NPV over time
- `calculate_return_on_investment(benefits, costs)` - ROI metric
- `calculate_benefit_cost_ratio(benefits, costs)` - Ratio of benefits to costs
- `perform_break_even_analysis(costs, benefits)` - When do benefits exceed costs?

### Budget Impact Analysis
- `estimate_population_impact(efficacy, target_population)` - Scale to population
- `calculate_budget_impact(cost_per_patient, adoption_rate, population)` - Financial impact
- `project_budget_over_time(annual_costs, population_growth, inflation)` - Multi-year budget

---

## 6. Comparative Effectiveness & Evidence

### Evidence Synthesis
- `compare_treatment_outcomes(treatments, outcome_metric)` - Head-to-head effectiveness
- `analyze_treatment_patterns(facility, time_period)` - What treatments are used when?
- `identify_practice_variation(providers, measure)` - Geographic/provider variation
- `benchmark_against_peers(facility_metric, peer_group)` - Relative performance
- `calculate_standardized_mortality_ratio(observed_deaths, expected_deaths)` - Risk-adjusted mortality

### Subgroup Analysis
- `calculate_outcome_by_subgroup(cohort, subgroup_variable, outcome)` - Stratified analysis
- `test_treatment_interaction(treatment, modifier_variable, outcome)` - Does effect vary?
- `identify_predictors_of_response(treatment, covariates, outcome)` - Who benefits most?

---

## 7. Data Visualization & Reporting

### Charts & Plots
- `create_cost_trend_chart(time_series_data)` - Line chart of costs over time
- `create_cost_breakdown_chart(cost_categories)` - Pie or stacked bar chart
- `create_quality_metric_dashboard(metrics_dict)` - Multi-metric dashboard
- `create_cost_effectiveness_plane(icers)` - Scatter plot of cost vs. effect
- `create_tornado_diagram(sensitivity_results)` - Sensitivity analysis visualization
- `create_survival_curve(survival_data, groups)` - Kaplan-Meier plots
- `create_forest_plot(effect_estimates, confidence_intervals)` - Meta-analysis style plot
- `create_heatmap(data_matrix, row_labels, col_labels)` - Correlation or provider comparisons
- `create_geographic_map(facility_locations, metric_values)` - Spatial visualization

### Reports & Export
- `generate_financial_report(period, facilities)` - Standardized financial report
- `generate_quality_report(period, measures)` - Quality metrics summary
- `generate_analysis_report(analysis_results, template)` - Custom analysis report
- `export_to_pdf(content, output_path)` - PDF generation
- `export_to_excel(dataframes_dict, output_path)` - Multi-sheet Excel export
- `create_executive_summary(full_results)` - High-level insights

---

## 8. Database & Data Management

### Query & Retrieval
- `query_patient_records(filters)` - Get patient data by criteria
- `query_claims(date_range, payer, facility)` - Get claims by filters
- `query_encounters(facility_id, date_range, encounter_type)` - Get encounter records
- `query_financial_data(facility_id, period, account_code)` - Get financial records
- `create_cohort_from_criteria(inclusion_criteria, exclusion_criteria)` - Build research cohort

### Data Storage & Versioning
- `save_analysis_result(analysis_id, result_data, metadata)` - Persist results
- `save_dataset_version(dataset_name, version, data)` - Version control for datasets
- `retrieve_archived_data(dataset_name, version_date)` - Historical data access
- `backup_database(target_location)` - Data backup

---

## 9. Utilities & Infrastructure

### Configuration & Parameters
- `load_configuration(config_file)` - Load system settings
- `set_discount_rate(rate)` - Economic analysis parameter
- `set_cost_year(year)` - Inflation adjustment year
- `set_analysis_parameters(parameters_dict)` - Batch parameter setting

### Logging & Error Handling
- `log_analysis_step(step_name, parameters, result)` - Audit trail
- `handle_missing_data_error(error, data_context)` - Graceful error management
- `validate_analysis_inputs(data, expected_schema)` - Input validation
- `generate_audit_log(analysis_id)` - Reproducibility documentation

### Helper Functions
- `adjust_for_inflation(amount, from_year, to_year)` - Inflation adjustment
- `calculate_present_value(future_amount, years, discount_rate)` - Time value of money
- `apply_probability(outcome, probability)` - Weighted scenarios
- `merge_datasets(data1, data2, join_key)` - Data consolidation
- `deidentify_data(dataset, pii_columns)` - Privacy protection

---

## 10. Advanced Analytics

### Machine Learning & Prediction
- `predict_patient_risk(patient_features, model)` - Risk stratification
- `predict_readmission_probability(patient_data)` - Readmission risk model
- `predict_high_cost_status(patient_data)` - Who will be high-cost?
- `predict_treatment_response(patient_data, treatment)` - Personalized medicine
- `train_prediction_model(training_data, outcome_variable)` - Build ML model
- `evaluate_model_performance(model, test_data)` - AUC, sensitivity, specificity

### Network & System Analysis
- `analyze_referral_network(provider_referrals)` - Referral patterns
- `identify_care_coordination_gaps(patient_pathway)` - Care fragmentation
- `analyze_care_team_composition(encounters)` - Utilization patterns
- `simulate_care_pathway(starting_condition, rules)` - Scenario modeling

### Scenario & Sensitivity Analysis
- `run_best_case_scenario(base_parameters)` - Optimistic assumptions
- `run_worst_case_scenario(base_parameters)` - Pessimistic assumptions
- `run_base_case_scenario(base_parameters)` - Most likely scenario
- `sensitivity_to_parameter(base_case, parameter_name, range)` - One-way sensitivity
- `two_way_sensitivity_analysis(param1_range, param2_range)` - Two-parameter uncertainty

---

## Implementation Priorities

### Phase 1 (MVP)
- Data ingestion & validation (Section 1.1-1.2)
- Basic financial analysis (Section 2.1-2.2)
- Quality metrics (Section 3.1)
- Descriptive statistics (Section 4.1)
- Basic reporting (Section 7.1-7.2)

### Phase 2
- Regression analysis (Section 4.3)
- Economic evaluation (Section 5)
- Advanced visualizations (Section 7.1)
- Database management (Section 8)

### Phase 3
- Causal inference methods (Section 4.4)
- Machine learning (Section 10.1)
- Complex scenario analysis (Section 10.3)
- Real-time dashboards

---

## Usage Notes

- Functions should follow naming convention: `verb_noun` (e.g., `calculate_cost`, `perform_regression`)
- All functions should accept optional parameters for time periods, facility filters, cohort definitions
- Results should include confidence intervals and sensitivity ranges where applicable
- All analyses should be reproducible with audit trails
- Output formats should support both programmatic access and human-readable reports
