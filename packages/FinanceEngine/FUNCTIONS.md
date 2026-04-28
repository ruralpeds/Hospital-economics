# FinanceEngine — Complete Function Catalog

**Version:** post-port (healthcare-finance-julia fully merged)
**Total exported symbols:** ~170 domain functions + infrastructure types

---

## Ch. 1 — Core Finance (`financial.jl`)

| Function | Signature | Description |
|---|---|---|
| `npv` | `(cash_flows, rate)` | Net present value; `cash_flows[1]` is t=0 |
| `roi` | `(gain, cost)` | Return on investment = (gain−cost)/cost |
| `operating_margin` | `(revenue, expenses)` | (revenue−expenses)/revenue |
| `cost_per_patient` | `(total_costs, patient_count)` | Average cost per encounter |
| `break_even_units` | `(fixed_costs, price, variable_cost)` | Fixed / contribution margin |
| `payback_period` | `(cash_flows)` | Periods to recover investment (linear interp) |
| `drg_revenue` | `(drg_weight, base_rate, wage_index; outlier, ime, dsh)` | CMS DRG inpatient payment |
| `weighted_payer_rate` | `(mix::PayerMix, rates::NamedTuple)` | Blended reimbursement across payer categories |
| `net_collection_rate` | `(payments, allowed_charges)` | Cash collected / contractually allowed |

---

## Ch. 2 — Econometrics (`econometrics.jl`)

| Function | Signature | Description |
|---|---|---|
| `simple_linear_regression` | `(x, y)` | OLS slope and intercept |
| `predict_linear` | `(result, x_new)` | Predictions from regression result |
| `r_squared` | `(y_actual, y_predicted)` | Coefficient of determination |
| `mean_absolute_error` | `(y_actual, y_predicted)` | MAE between actual and predicted |

---

## Ch. 3 — Simulation (`simulation.jl`)

| Function | Signature | Description |
|---|---|---|
| `monte_carlo_mean` | `(sample_fn, n_sims)` | Mean of Monte Carlo draws |
| `simulate_growth` | `(initial_value, growth_rate, volatility, periods)` | Stochastic growth path |
| `arma_forecast` | `(series, p, q, horizon)` | ARMA point forecast with bootstrap CI |
| `arma_stochastic_paths` | `(series, p, q, horizon; n_paths)` | Matrix of stochastic ARMA paths |

---

## Ch. 4 — Dynamic Optimization (`optimization.jl`)

| Function | Signature | Description |
|---|---|---|
| `rouwenhorst_grid` | `(n, ρ, σ)` | Discrete Markov approximation for AR(1) demand |
| `optimal_bed_expansion` | `(; initial_beds, min_beds, max_beds, demand_states, discount_rate)` | Value-function iteration for bed capacity |
| `optimal_staffing` | `(; initial_fte, min_fte, max_fte, demand_states, discount_rate)` | Value-function iteration for FTE levels |

---

## Ch. 5 — Financial Monitoring (`financial_monitoring.jl`)

| Function | Signature | Description |
|---|---|---|
| `initialize_kalman` | `(initial_state, initial_uncertainty, process_noise, obs_noise)` | Create `KalmanFilterState` |
| `kalman_filter_step` | `(kf, observation)` | Single Kalman update step |
| `margin_tracker` | `(observations)` | Full margin tracking with Hamilton decomposition |
| `early_warning_signal` | `(margin_history)` | Alert level: `"green"`, `"yellow"`, `"red"` |
| `hamilton_filter` | `(data, h)` | Trend/cycle decomposition |
| `liquidity_forecast` | `(margin_history; monthly_revenue, cash_balance)` | Forward liquidity projection |

---

## Ch. 6 — Strategic Planning (`strategic_planning.jl`)

| Function | Signature | Description |
|---|---|---|
| `cost_trajectory` | `(; current_cost, target_cost, horizon, adjustment_cost)` | Optimal cost reduction path |
| `merger_integration_plan` | `(; hospital_a_cost, hospital_b_cost, synergy_target, ...)` | Post-merger integration schedule |
| `restructuring_plan` | `(; current_margin, target_margin, annual_revenue, ...)` | Feasibility-scored restructuring path |
| `revenue_enhancement_plan` | `(; current_revenue, target_revenue, current_margin, ...)` | Revenue growth optimization |

---

## Ch. 7 — Value-Based Care (`value_based_care.jl`)

| Function | Signature | Description |
|---|---|---|
| `value_score` | `(quality, efficiency)` | Composite quality/efficiency score |
| `qalys` | `(life_years, utility_weight)` | Quality-adjusted life years |
| `quality_score` | `(measures, weights)` | Weighted composite quality measure |
| `efficiency_score` | `(cost_per_case, benchmark)` | Cost efficiency vs. benchmark |
| `readmission_penalty` | `(observed_rate, expected_rate, base_payment)` | CMS readmission penalty amount |

---

## Ch. 8 — Cost Accounting (`cost_accounting.jl`)

| Function | Signature | Description |
|---|---|---|
| `cost_to_charge_ratio` | `(total_costs, total_charges)` | CCR for Medicare cost reports |
| `estimate_cost_from_charges` | `(charges, ccr)` | Estimated cost using CCR |
| `step_down_allocation` | `(direct_costs, allocation_matrix)` | Overhead step-down to revenue centers |
| `activity_based_cost` | `(activities::Vector)` | ABC model by activity driver |
| `marginal_cost` | `(fixed_costs, variable_cost_per_unit, volume)` | Total cost at given volume |
| `department_profitability` | `(departments::Vector)` | Profit/loss by department |

---

## Ch. 9 — Risk Contracting (`risk_contracting.jl`)

| Function | Signature | Description |
|---|---|---|
| `pmpm` | `(total_cost, member_months)` | Per-member-per-month rate |
| `shared_savings` | `(actual_cost, benchmark_cost, savings_rate)` | ACO shared savings amount |
| `shared_risk` | `(actual_cost, benchmark_cost, risk_rate)` | ACO downside risk amount |
| `risk_corridor` | `(actual_cost, target_cost; floor, ceiling)` | Corridor-bounded risk settlement |
| `hcc_risk_score` | `(conditions::Vector{String}, weights)` | CMS-HCC score from diagnosis code list |
| `case_mix_index` | `(drg_weights)` | Inpatient case mix index |
| `capitation_rate` | `(pmpm_cost; admin_load, risk_margin)` | Capitation rate with loadings |
| `medical_loss_ratio` | `(medical_costs, premium_revenue)` | MLR = medical costs / premium |

---

## Ch. 10 — Capital Structure (`capital_structure.jl`)

| Function | Signature | Description |
|---|---|---|
| `wacc` | `(equity_pct, debt_pct, cost_of_equity, cost_of_debt, tax_rate)` | WACC; set `tax_rate=0` for nonprofits |
| `debt_service_coverage_ratio` | `(net_operating_income, debt_service)` | NOI / annual debt service |
| `days_cash_on_hand` | `(cash_and_investments, daily_operating_expense)` | Liquidity in operating days |
| `current_ratio` | `(current_assets, current_liabilities)` | Short-term liquidity ratio |
| `debt_to_capitalization` | `(long_term_debt, net_assets)` | Leverage ratio |
| `bond_price` | `(face_value, coupon_rate, yield_rate, periods)` | Fixed-rate bond pricing |
| `bond_yield_to_maturity` | `(face_value, price, coupon_rate, periods)` | YTM via Newton's method |
| `capital_budget_ranking` | `(projects; budget)` | Rank by profitability index within budget |
| `financial_health_scorecard` | `(metrics::Dict)` | Letter-graded scorecard (A–F) |
| `irr` | `(cash_flows; lo, hi, tol)` | Internal rate of return via bisection; `missing` if no root |
| `mirr` | `(cash_flows, finance_rate, reinvestment_rate)` | Modified IRR |
| `discounted_payback_period` | `(cash_flows, discount_rate)` | Payback in time-value-adjusted dollars |
| `interest_coverage_ratio` | `(ebit, interest_expense)` | Times interest earned |
| `profitability_index` | `(npv_value, initial_investment)` | PI = (NPV + inv) / inv |
| `modified_duration` | `(cash_flows, yield)` | Bond price sensitivity to yield |
| `lease_vs_buy` | `(asset_cost, lease_payments, salvage_value, discount_rate, useful_life; tax_rate=0)` | NPV comparison; nonprofit default |

---

## Ch. 10b — Budgeting (`budgeting.jl`)

| Function | Signature | Description |
|---|---|---|
| `operating_budget` | `(fixed_costs, variable_cost_per_unit, expected_volume, price_per_unit; other_revenue)` | Full departmental budget |
| `flex_budget` | `(fixed_costs, variable_cost_per_unit, actual_volume, price_per_unit)` | Budget restated at actual volume |
| `volume_variance` | `(budgeted_cm_per_unit, actual_volume, budgeted_volume)` | Variance from volume difference |
| `price_variance` | `(actual_price, budgeted_price, actual_volume)` | Variance from pricing difference |
| `efficiency_variance` | `(budgeted_cost_per_unit, actual_units, standard_units_per_output, actual_output)` | Resource use vs. standard |
| `mix_variance` | `(actual_volumes, budgeted_volumes, budgeted_margins)` | Payer/service-line mix shift impact |
| `rate_volume_variance` | `(actual_revenue, budgeted_revenue, actual_volume, budgeted_volume, budgeted_price)` | Rate + volume decomposition |
| `budget_to_actual_variance` | `(budget, actual)` | Dollar and % variance |
| `capital_budget_rank` | `(projects; npv_weight=0.7, strategic_weight=0.3)` | Weighted NPV + strategic score ranking |
| `zero_based_budget_score` | `(necessity, cost_effectiveness, strategic_alignment; weights)` | ZBB line-item score 0–10 |
| `rolling_forecast_update` | `(actuals_ytd, periods_elapsed, periods_total, original_budget)` | Run-rate annual projection |

---

## Ch. 11 — Operational Efficiency (`operational_efficiency.jl`)

| Function | Signature | Description |
|---|---|---|
| `length_of_stay_analysis` | `(los_data)` | LOS statistics (mean, median, outliers) |
| `bed_turnover_rate` | `(discharges, beds, days)` | Discharges per bed per period |
| `ed_throughput` | `(arrivals, departures, timestamps)` | ED flow metrics |
| `surgical_utilization` | `(cases, rooms, days; hours_per_day)` | OR utilization rate |
| `capacity_planning` | `(current_demand, growth_rate; horizon, target_utilization)` | Beds/FTE needed over horizon |
| `staffing_ratio` | `(patient_days, fte_count; target_ratio)` | Patient days per FTE |

---

## Ch. 12a — Accounting (`accounting.jl`)

| Function | Signature | Description |
|---|---|---|
| `income_statement` | `(gross_revenue, contractual_adjustments, bad_debt, charity_care, operating_expenses; other_income)` | Full HFMA income statement |
| `ebitda` | `(operating_income, depreciation, amortization=0)` | Earnings before interest/taxes/D&A |
| `ebitda_margin` | `(ebitda_val, total_operating_revenue)` | EBITDA as % of revenue |
| `total_margin` | `(excess_revenue, total_revenue)` | Including non-operating items |
| `operating_margin_hfma` | `(operating_income, total_operating_revenue)` | HFMA definition (excludes non-operating) |
| `operating_leverage` | `(contribution_margin, operating_income)` | DOL = CM / operating income |
| `quick_ratio` | `(cash_and_equivalents, current_liabilities)` | Acid-test liquidity |
| `debt_to_equity` | `(total_liabilities, net_assets)` | Leverage (net assets = equity for nonprofits) |
| `equity_multiplier` | `(total_assets, net_assets)` | DuPont multiplier |
| `balance_sheet_ratios` | `(current_assets, current_liabilities, cash, total_assets, total_liabilities, net_assets, long_term_debt)` | Full ratio suite in one call |
| `cash_flow_indirect` | `(net_income, depreciation, amortization, Δar, Δap, Δinventory, capex)` | Indirect-method cash flow statement |
| `straight_line_depreciation` | `(cost, salvage_value, useful_life_years)` | Annual SL depreciation |
| `macrs_depreciation_schedule` | `(cost, property_class)` | IRS MACRS schedule (5/7/10/15/27.5/39 yr) |
| `net_assets_change` | `(beginning_net_assets, excess_revenue; gifts, releases, other)` | Ending net assets (ASC 958) |
| `fund_accounting_summary` | `(unrestricted, temporarily_restricted, permanently_restricted)` | Three-class net asset summary |
| `charitable_community_benefit_rate` | `(community_benefit_expense, total_operating_expense)` | IRS Form 990 Schedule H metric |

---

## Ch. 12b — Population Health (`population_health.jl`)

| Function | Signature | Description |
|---|---|---|
| `preventive_care_roi` | `(intervention_cost, avoided_cost, population)` | ROI on prevention programs |
| `telehealth_cost_effectiveness` | `(telehealth_cost, in_person_cost, utilization_rate)` | Cost savings from telehealth |
| `sdoh_impact_model` | `(sdoh_scores::Dict, cost_weights)` | Social determinants financial impact |
| `chronic_disease_management_savings` | `(prevalence, population, per_member_cost, reduction_rate)` | CDM program savings |

---

## Ch. 13a — Actuarial (`actuarial.jl`)

| Function | Signature | Description |
|---|---|---|
| `loss_development_factors` | `(triangle::Matrix{Float64})` | Chain-ladder age-to-age LDFs |
| `claims_triangle_development` | `(triangle::Matrix{Float64})` | Complete paid claims triangle |
| `ibnr_reserve` | `(triangle::Matrix{Float64})` | IBNR per accident year |
| `hcc_risk_score` | `(demographic_factor, hcc_factors; normalization_factor)` | CMS-HCC RAF from numeric components |
| `hcc_prospective_score` | `(prior_year_raf, trend_factor)` | Project RAF forward |
| `pmpm_by_category` | `(expenditures, labels, member_months)` | PMPM breakdown by service category |
| `admin_expense_ratio` | `(admin_expenses, premium_revenue)` | Admin as % of premium |
| `premium_rate_development` | `(claims_pmpm, admin_loading, profit_margin, risk_margin)` | Premium from claims base |
| `community_rating_premium` | `(market_claims_pmpm, admin_loading, profit_margin)` | Single area-wide premium |
| `utilization_rate` | `(events, member_months; per=1000)` | Events per N member months |
| `admissions_per_thousand` | `(inpatient_admissions, member_months)` | APT (annualised) |
| `ed_visits_per_thousand` | `(ed_visits, member_months)` | EDVPT (annualised) |
| `claim_frequency` | `(claim_count, exposure_units)` | Claims per exposure unit |
| `claim_severity` | `(total_paid, claim_count)` | Average paid per claim |
| `pure_premium` | `(frequency, severity)` | Expected cost per exposure |
| `credibility_weight` | `(observed_members, full_credibility_threshold=1082)` | Limited fluctuation Z ∈ [0,1] |
| `blended_rate` | `(group_rate, market_rate, credibility_z)` | Z-weighted blended rate |

---

## Ch. 13b — Reimbursement (`reimbursement.jl`)

| Function | Signature | Description |
|---|---|---|
| `drg_payment` | `(base_rate, drg_weight, cases; outlier_threshold, outlier_rate)` | Basic inpatient DRG payment |
| `ms_drg_payment` | `(base_rate, drg_weight, cases, cc_mcc_flag; wage_index, dsh, ime)` | Full MS-DRG IPPS with CMS adjustments |
| `apr_drg_payment` | `(base_rate, drg_weight, severity_level, cases)` | APR-DRG by severity tier 1–4 |
| `opps_apc_payment` | `(conversion_factor, apc_relative_weight, visits; copay, pass_through)` | OPPS outpatient APC |
| `rvu_to_payment` | `(work_rvu, pe_rvu, mp_rvu, conversion_factor; gpci_work, gpci_pe, gpci_mp)` | Medicare physician fee schedule |
| `rbrvs_payment` | `(work_rvu, pe_rvu, mp_rvu, conversion_factor, units; gpci)` | RBRVS for multiple service units |
| `capitation_pmpm` | `(total_expenditure, member_months)` | PMPM capitation rate |
| `pmpm_trend` | `(base_pmpm, trend_rate, months)` | PMPM projection with compounding |
| `payer_contract_net` | `(charges, allowed_rate, payer_share, patient_copay)` | Net revenue under contract |
| `days_in_ar` | `(ending_ar_balance, average_daily_revenue)` | AR days; benchmark ≤ 40 |
| `denial_rate` | `(denied_claims, total_claims_submitted)` | Claim denial %; benchmark ≤ 3% |
| `clean_claim_rate` | `(claims_paid_first_submission, total_claims_submitted)` | First-pass payment rate; benchmark ≥ 98% |
| `gross_collection_rate` | `(payments_received, gross_charges)` | Payments / gross charges |
| `cash_collection_efficiency` | `(actual_cash_collected, net_revenue)` | Cash vs. net revenue |
| `bad_debt_rate` | `(bad_debt_expense, gross_revenue)` | Bad debt / gross revenue |
| `charity_care_rate` | `(charity_care_cost, total_operating_expense)` | Charity care % of operating expense |
| `uncompensated_care_rate` | `(bad_debt_expense, charity_care_cost, gross_revenue)` | Combined uncompensated care |
| `revenue_cycle_scorecard` | `(; days_ar, denial_rt, clean_claim_rt, cash_efficiency)` | `:exceeds` / `:meets` / `:below` per KPI |

---

## Ch. 14 — Forecasting (`forecasting.jl`)

| Function | Signature | Description |
|---|---|---|
| `simple_exponential_smoothing` | `(values, α; horizon)` | SES: smoothed series + flat forecast |
| `holt_double_exponential` | `(values, α, β; horizon)` | Trend-adjusted Holt smoothing |
| `holt_winters_additive` | `(values, α, β, γ, season_length; horizon)` | Level + trend + seasonal |
| `weighted_moving_average` | `(values, weights; horizon)` | Normalised weighted MA forecast |
| `seasonal_indices` | `(values, season_length)` | Multiplicative seasonal indices |
| `deseasonalize` | `(values, indices)` | Remove seasonality (÷ indices) |
| `reseasonalize` | `(values, indices)` | Restore seasonality (× indices) |
| `budget_variance` | `(actual, budget)` | actual − budget |
| `budget_variance_pct` | `(actual, budget)` | (actual − budget) / budget |
| `flexible_budget_variance` | `(actual, flexible_budget)` | actual − volume-adjusted budget |
| `forecast_rmse` | `(actual, forecast)` | Root mean squared error |
| `forecast_mape` | `(actual, forecast)` | Mean absolute percentage error |
| `forecast_bias` | `(actual, forecast)` | Systematic over/under-forecast |

---

## Ch. 15 — Cost-Effectiveness Analysis (`cost_effectiveness.jl`)

| Function | Signature | Description |
|---|---|---|
| `markov_cohort` | `(transition_matrix, initial_cohort, n_cycles; discount_rate)` | Discrete-time state-transition traces |
| `markov_cycle_traces` | `(traces, utility_weights; discount_rate)` | Discounted QALYs per cycle (half-cycle correction) |
| `icer` | `(delta_cost, delta_effectiveness)` | ΔCost / ΔEffectiveness |
| `cea_dominant` | `(cost_a, effect_a, cost_b, effect_b)` | `:a_dominates`, `:b_dominates`, or `:neither` |
| `net_monetary_benefit` | `(effectiveness, cost, wtp_threshold)` | NMB = effect × WTP − cost |
| `willingness_to_pay_threshold` | `(delta_cost, delta_effectiveness)` | Max WTP for cost-effectiveness |
| `daly` | `(years_life_lost, years_lived_with_disability, disability_weight)` | YLL + YLD × weight |
| `life_years_gained` | `(intervention_survival, comparator_survival)` | Undiscounted LYG |
| `qaly_adjusted_life_years` | `(life_years, utility_weight)` | LY × utility |
| `budget_impact_analysis` | `(eligible_population, uptake_rate, new_therapy_cost, current_therapy_cost, current_market_share; horizon_years)` | Annual + cumulative budget impact |
| `decision_tree_ev` | `(outcomes, probabilities)` | Expected value = dot(outcomes, probs) |
| `probabilistic_sensitivity_analysis` | `(cost_sampler, effect_sampler, n_simulations; wtp_threshold)` | Monte Carlo ICER/NMB distribution |
| `tornado_diagram_inputs` | `(base_icer, parameter_ranges, icer_function)` | One-way sensitivity, sorted by swing |

---

## Ch. 16 — Supply Chain (`supply_chain.jl`)

| Function | Signature | Description |
|---|---|---|
| `economic_order_quantity` | `(annual_demand, order_cost, holding_cost)` | EOQ optimal order quantity |
| `safety_stock` | `(avg_daily_demand, demand_std, lead_time; service_level)` | Buffer stock for stockout protection |
| `inventory_turnover` | `(cogs, avg_inventory)` | COGS / average inventory |
| `pharmaceutical_cost_analysis` | `(drugs::Vector)` | Cost/volume/margin by drug |
| `stockout_cost` | `(lost_revenue_per_day, days_out; margin_rate)` | Financial impact of stockout |
| `vendor_scorecard` | `(vendors; weights)` | Weighted vendor performance score |

---

## Infrastructure

### Scenario Persistence (`scenario_persistence.jl`)
`save_scenario`, `load_scenario`, `list_scenarios`, `delete_scenario`, `toggle_favorite`, `export_scenario_to_json`, `import_scenario_from_json`
Types: `Scenario`, `ScenarioStorage`

### Undo/Redo (`undo_redo.jl`)
`execute!`, `undo!`, `redo!`, `can_undo`, `can_redo`, `next_undo_description`, `next_redo_description`, `clear_history!`, `get_history`, `get_state`, `execute_and_record!`
Types: `Command`, `ParameterChangeCommand`, `CommandHistory`

### Performance (`performance_optimization.jl`)
`parallelize_sweep`, `benchmark_abm`, `setup_worker_pool`, `get_cached`, `set_cached`, `clear_cache`, `vectorized_demand_forecast`, `batch_compute_stockout_risk`
Types: `ProfileResult`, `CacheLayer`

---

## Function Count by Module

| Module | File | Functions |
|---|---|---|
| Core Finance | `financial.jl` | 9 |
| Econometrics | `econometrics.jl` | 4 |
| Simulation | `simulation.jl` | 4 |
| Dynamic Optimization | `optimization.jl` | 3 |
| Financial Monitoring | `financial_monitoring.jl` | 6 |
| Strategic Planning | `strategic_planning.jl` | 4 |
| Value-Based Care | `value_based_care.jl` | 5 |
| Cost Accounting | `cost_accounting.jl` | 6 |
| Risk Contracting | `risk_contracting.jl` | 8 |
| Capital Structure | `capital_structure.jl` | 16 |
| Operational Efficiency | `operational_efficiency.jl` | 6 |
| Budgeting | `budgeting.jl` | 11 |
| Accounting | `accounting.jl` | 16 |
| Population Health | `population_health.jl` | 4 |
| Actuarial | `actuarial.jl` | 17 |
| Reimbursement | `reimbursement.jl` | 18 |
| Forecasting | `forecasting.jl` | 13 |
| Cost-Effectiveness | `cost_effectiveness.jl` | 13 |
| Supply Chain | `supply_chain.jl` | 6 |
| **Domain Total** | | **169** |
| Infrastructure | 3 files | ~30 |
| **Grand Total** | | **~199** |
