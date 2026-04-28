# Function → Tab Index

Authoritative mapping of every public function in `FUNCTIONS_CATALOG.md` to the
tab that hosts its input form. Keep this in sync with `docs/WEB_UI_BUILD_PLAN.md`
and the `@out functions_catalog` list used by `/functions` (Function Explorer).

> Format: `function_name(args)` — **Tab** — *status* — notes
>
> Status: `done` = form present, `wip` = scaffolded, `todo` = not started.

## 1. Data Collection & Integration

### 1.1 Source Data
- `ingest_hospital_data(source, format)` — **Data Intake** — todo
- `ingest_claims_data(payer_id, date_range)` — **Data Intake** — todo
- `ingest_clinical_data(ehr_system, patient_ids)` — **Data Intake** — todo
- `ingest_financial_statements(facility_id, fiscal_period)` — **Data Intake** — todo
- `ingest_registry_data(registry_name, cohort_filters)` — **Data Intake** — todo
- `ingest_csv(path, config)` — **Data Intake** — wip — exists in `data_ingestion/ingestion_api.jl`
- `validate_data_source(source_path, schema)` — **Data Intake** — todo
- `detect_data_quality_issues(dataframe, rules)` — **Data Intake** — todo

### 1.2 Data Transformation
- `normalize_patient_identifiers(data)` — **Data Preparation** — todo
- `standardize_medical_codes(codes, target_schema)` — **Data Preparation** — todo
- `aggregate_encounters(patient_data, time_period)` — **Data Preparation** — todo
- `calculate_risk_adjusters(patient_cohort)` — **Data Preparation** — todo
- `impute_missing_values(data, strategy)` — **Data Preparation** — todo
- `create_time_series(longitudinal_data, interval)` — **Data Preparation** — todo

## 2. Financial Analysis

### 2.1 Cost Analysis
- `calculate_total_cost_of_care(patient_id, date_range)` — **Cost Analysis** — todo
- `break_down_costs_by_category(charges, categories)` — **Cost Analysis** — todo
- `calculate_cost_per_episode(episode_data)` — **Cost Analysis** — wip — `episode/CostModels.jl`
- `calculate_cost_per_quality_adjusted_year(cost, qaly_gained)` — **Cost Analysis** — done — `health_economics/ICER.jl`
- `identify_high_cost_patients(patient_cohort, percentile)` — **Cost Analysis** — wip — `analytics/CostAnalysis.jl`
- `project_cost_trends(historical_costs, time_periods)` — **Cost Analysis** — todo
- `inflate_cost(amount, from_year, to_year)` — **Cost Analysis** — wip
- `calculate_cohort_total_cost(cohort)` — **Cost Analysis** — wip
- `analyze_high_cost_patients(cohort)` — **Cost Analysis** — wip

### 2.2 Revenue & Reimbursement
- `calculate_total_revenue(claims, reimbursement_rates)` — **Revenue & Reimbursement** — todo
- `calculate_denied_claims_impact(denied_claims)` — **Revenue & Reimbursement** — todo
- `analyze_payor_mix(claims)` — **Revenue & Reimbursement** — wip — `/payer-margin`
- `calculate_provider_payment(claims, fee_schedule)` — **Revenue & Reimbursement** — todo
- `simulate_reimbursement_change(claims, new_policy)` — **Revenue & Reimbursement** — wip — `/cost-reimbursement`

### 2.3 Profitability & Operations
- `calculate_contribution_margin(revenue, variable_costs)` — **Profitability & Operations** — wip
- `calculate_departmental_profitability(dept_id, period)` — **Profitability & Operations** — wip
- `analyze_fixed_vs_variable_costs(cost_data)` — **Profitability & Operations** — wip — `/cost-structure`
- `calculate_break_even_volume(fixed_costs, contribution_margin)` — **Profitability & Operations** — wip — `/break-even`
- `calculate_operating_margin(operating_income, revenue)` — **Profitability & Operations** — wip — `finance/ratios.jl`

## 3. Quality & Clinical Outcomes

### 3.1 Quality Metrics
- `calculate_readmission_rate` — **Quality & Outcomes** — todo
- `calculate_mortality_rate` — **Quality & Outcomes** — todo
- `calculate_infection_rates` — **Quality & Outcomes** — todo
- `calculate_complication_rates` — **Quality & Outcomes** — todo
- `calculate_patient_safety_indicator` — **Quality & Outcomes** — todo
- `calculate_quality_metric` — **Quality & Outcomes** — wip — `payer_models/QualityMetrics.jl`

### 3.2 Outcomes Analysis
- `track_functional_status` — **Quality & Outcomes** — todo
- `track_symptom_resolution` — **Quality & Outcomes** — todo
- `calculate_quality_of_life_score` — **Quality & Outcomes** — todo
- `identify_outcome_disparities` — **Quality & Outcomes** — todo
- `compare_outcomes_by_treatment` — **Quality & Outcomes** — wip — `comparative_effectiveness/`

## 4. Statistical & Econometric Analysis

### 4.1 Descriptive
- `calculate_population_demographics` — **Stats** — todo
- `calculate_comorbidity_burden` — **Stats** — todo
- `calculate_summary_statistics` — **Stats** — todo
- `compare_groups_descriptively` — **Stats** — todo

### 4.2 Inferential
- `perform_t_test` — **Stats** — todo
- `perform_anova` — **Stats** — todo
- `perform_chi_square_test` — **Stats** — todo
- `perform_log_rank_test` — **Stats** — todo
- `calculate_confidence_intervals` — **Stats** — todo

### 4.3 Regression
- `perform_linear_regression` — **Regression Lab** — todo
- `perform_logistic_regression` — **Regression Lab** — todo
- `perform_poisson_regression` — **Regression Lab** — todo
- `perform_negative_binomial_regression` — **Regression Lab** — todo
- `perform_cox_proportional_hazards` — **Regression Lab** — todo
- `calculate_regression_diagnostics` — **Regression Lab** — todo

### 4.4 Causal
- `perform_propensity_score_matching` — **Causal Inference Lab** — todo
- `perform_instrumental_variable_analysis` — **Causal Inference Lab** — todo
- `perform_difference_in_differences` — **Causal Inference Lab** — todo
- `perform_regression_discontinuity` — **Causal Inference Lab** — todo
- `estimate_heterogeneous_treatment_effects` — **Causal Inference Lab** — todo

## 5. Economic Evaluation

### 5.1 CEA
- `calculate_cost_effectiveness_ratio` — **CEA** — wip
- `calculate_icer` — **CEA** — done — `health_economics/ICER.jl`
- `perform_sensitivity_analysis` — **CEA** — wip — `comparative_effectiveness/SensitivityAnalysis.jl`
- `perform_monte_carlo_simulation` — **CEA** — wip
- `calculate_incremental_net_benefit` — **CEA** — todo
- `generate_cost_effectiveness_plane` — **CEA** — wip — `comparative_effectiveness/`
- `build_ceac` — **CEA** — done — `health_economics/ICER.jl`
- `calculate_ceac_at_wtp` — **CEA** — done
- `recommend_intervention` — **CEA** — done

### 5.2 CBA
- `calculate_net_present_value` — **CBA + BIA** — todo
- `calculate_return_on_investment` — **CBA + BIA** — todo
- `calculate_benefit_cost_ratio` — **CBA + BIA** — todo
- `perform_break_even_analysis` — **CBA + BIA** — wip — `finance/breakeven.jl`

### 5.3 Budget Impact
- `estimate_population_impact` — **CBA + BIA** — todo
- `calculate_budget_impact` — **CBA + BIA** — wip — `payer_models/BudgetImpactModel.jl`
- `project_budget_over_time` — **CBA + BIA** — todo

## 6. Comparative Effectiveness

- `compare_treatment_outcomes` — **Comparative Effectiveness** — wip
- `analyze_treatment_patterns` — **Comparative Effectiveness** — todo
- `identify_practice_variation` — **Comparative Effectiveness** — todo
- `benchmark_against_peers` — **Comparative Effectiveness** — wip — `/benchmark`
- `calculate_standardized_mortality_ratio` — **Comparative Effectiveness** — todo
- `calculate_outcome_by_subgroup` — **Comparative Effectiveness** — todo
- `test_treatment_interaction` — **Comparative Effectiveness** — todo
- `identify_predictors_of_response` — **Comparative Effectiveness** — todo
- `compare_strategies` — **Comparative Effectiveness** — done — `comparative_effectiveness/ComparativeEffectiveness.jl`

## 7. Data Visualization & Reporting

### 7.1 Charts
- `create_cost_trend_chart` — **Visualization Workbench** — todo
- `create_cost_breakdown_chart` — **Visualization Workbench** — todo
- `create_quality_metric_dashboard` — **Visualization Workbench** — todo
- `create_cost_effectiveness_plane` — **Visualization Workbench** — wip
- `create_tornado_diagram` — **Visualization Workbench** — todo
- `create_survival_curve` — **Visualization Workbench** — todo
- `create_forest_plot` — **Visualization Workbench** — todo
- `create_heatmap` — **Visualization Workbench** — todo
- `create_geographic_map` — **Visualization Workbench** — todo

### 7.2 Reports
- `generate_financial_report` — **Reports & Export** — todo
- `generate_quality_report` — **Reports & Export** — todo
- `generate_analysis_report` — **Reports & Export** — todo
- `export_to_pdf` — **Reports & Export** — todo
- `export_to_excel` — **Reports & Export** — todo
- `create_executive_summary` — **Reports & Export** — todo

## 8. Database & Data Management

- `query_patient_records` — **Database** — todo
- `query_claims` — **Database** — todo
- `query_encounters` — **Database** — todo
- `query_financial_data` — **Database** — todo
- `create_cohort_from_criteria` — **Cohort Builder** — wip — `patient_cohort/cohort_builder.jl`
- `save_analysis_result` — **Database** — todo
- `save_dataset_version` — **Database** — todo
- `retrieve_archived_data` — **Database** — todo
- `backup_database` — **Database** — todo

## 9. Utilities & Audit
- `load_configuration` — **Audit & Governance** — todo
- `set_discount_rate` / `set_cost_year` / `set_analysis_parameters` — **Audit & Governance** — todo
- `log_analysis_step` — **Audit & Governance** — wip — `data_ingestion/audit_logger.jl`
- `validate_analysis_inputs` — **Audit & Governance** — todo
- `generate_audit_log` — **Audit & Governance** — wip
- `adjust_for_inflation` — **Audit & Governance** — todo
- `calculate_present_value` — **Audit & Governance** — todo
- `deidentify_data` — **Audit & Governance** — wip — `data_ingestion/deidentifiers.jl`
- `merge_datasets` — **Audit & Governance** — todo

## 10. Advanced Analytics

### 10.1 ML
- `predict_patient_risk` — **Advanced Analytics / ML** — wip
- `predict_readmission_probability` — **Advanced Analytics / ML** — wip
- `predict_high_cost_status` — **Advanced Analytics / ML** — wip
- `predict_treatment_response` — **Advanced Analytics / ML** — todo
- `train_prediction_model` — **Advanced Analytics / ML** — todo
- `evaluate_model_performance` — **Advanced Analytics / ML** — todo
- `build_readmission_model` — **Advanced Analytics / ML** — wip — `analytics/AdvancedAnalytics.jl`
- `detect_cost_anomalies` — **Advanced Analytics / ML** — wip
- `stratify_patient_risk` — **Advanced Analytics / ML** — wip

### 10.2 Network & Systems
- `analyze_referral_network` — **Network & Systems** — todo
- `identify_care_coordination_gaps` — **Network & Systems** — todo
- `analyze_care_team_composition` — **Network & Systems** — todo
- `simulate_care_pathway` — **Network & Systems** — wip — `patient_flow/ClinicalPathway.jl`

### 10.3 Scenario
- `run_best_case_scenario` / `run_base_case_scenario` / `run_worst_case_scenario` — **Scenario Lab** — wip — `/scenarios`
- `sensitivity_to_parameter` — **Scenario Lab** — wip — `/sensitivity`
- `two_way_sensitivity_analysis` — **Scenario Lab** — todo
- `conduct_one_way_sensitivity` / `tornado_analysis` — **Scenario Lab** — done
- `conduct_two_way_sensitivity` — **Scenario Lab** — wip
- `conduct_probabilistic_sensitivity` — **Scenario Lab** — wip
