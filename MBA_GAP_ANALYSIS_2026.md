# MBA-Grade Analytics Gap Analysis — `ruralpeds/hospital-economics`

> Target capability: **executive- and MBA-level advanced analytics for Rural PPS hospitals, Critical Access Hospitals (CAH), and Rural Emergency Hospitals (REH)** — equivalent to what a CFO, strategy consultant, or healthcare-finance MBA would expect from a decision-support platform.

| | |
|--|--|
| **Date** | 2026-04-27 |
| **Branch this was authored on** | `claude/mba-gap-analysis-2026-04-27` |
| **Branches inspected** | `main` + 21 remote branches (see Appendix A) |
| **Supersedes** | All documents in `archive/gap-analysis-history/` |
| **Prior gap analyses archived** | 11 files (see archive `README.md`) |

---

## 0. Executive summary (one screen)

The repo is **architecturally far stronger than the older `STRATEGIC_IMPLEMENTATION_PLAN.md` (Apr 15 2026)** suggested ("35–40% complete"), but **claims of "v1.0 ready, 645+ tests" in the old `IMPLEMENTATION_STATUS.md` are aspirational**, not load-bearing. After a file-by-file walkthrough on `main`, the realistic posture is:

- **Foundation: ~75% there.** A real Genie/Stipple web app, 17 reactive views, 142 Julia source files across 24 module families, two internal packages (`FinanceEngine`, `RuralCore`), Aqua + JET quality gates wired in, JuMP/HiGHS optimization engine in place, Kalman filter for margin monitoring, QuantEcon LQ control for cost trajectories, ABM/DES/SD/MC simulation engines, an ML closure model with Chartis-style coefficients, REH conversion analyzer, payer margin decomposition (CHQPR methodology), 340B and DSH/UPL supplemental modules.
- **MBA analytics: ~45–55% there.** The platform leans heavily toward **clinical economics / policy simulation** (QALY, ICER, NMB, multi-level policy coupling, equity, real-world validation against KY Medicaid expansion / MD all-payer / COVID), and is **thinner on the classical CFO / corporate-finance / strategy-consulting toolkit** that an MBA evaluator expects: WACC by capital tier, real-options on service lines, M&A/affiliation valuation, Beneish M-score / Altman Z-score, working-capital optimization, full DuPont, balanced scorecard, DEA / SFA productivity, transfer pricing, full activity-based costing with driver allocation, treasury & liquidity stress-testing, three-statement projection model with calibration to Medicare cost reports.
- **Repo hygiene: poor.** 42 macOS Finder duplicate files (`* 2.jl`, `* 3.jl`, `* 4.jl`) live in `main`, including in production-relevant directories (`packages/FinanceEngine/src/financial_monitoring 4.jl`, `packages/RuralCore/src/audit 3.jl`). The hygiene workflow at `.github/workflows/hygiene.yml` was added but is not enforcing dedupe.
- **Branch sprawl: high.** 22 remote branches, only `main` is canonical. 14 `copilot/*` and 4 `claude/*` branches still live; several appear stale. A consolidation pass is overdue.
- **Test claims vs reality:** `IMPLEMENTATION_STATUS.md` claimed "645+ tests / 100% coverage." The `test/` directory has 64 unique test files (and 14 dupes). No Codecov badge is wired into the CI; coverage figures are self-asserted.

The remainder of this document is the actionable gap list. The work is partitioned into **six analytics domains** (§2), with each gap given a **priority (P0/P1/P2), MBA-evaluator weight, target module, and acceptance test sketch**, followed by an **execution plan** (§3) and **branch-consolidation plan** (§4).

---

## 1. What is actually on `main` (ground-truth inventory)

This section replaces the inflated capability claims in the archived `IMPLEMENTATION_STATUS.md`. Every item below was verified by direct file inspection.

### 1.1 Domain types & data layer

| Component | Status | Notes |
|---|---|---|
| `CriticalAccessHospital`, `RuralEmergencyHospital`, `PPSHospital` types | ✅ Real | `src/types/hospital.jl` (referenced by reimbursement.jl) |
| Annual financials struct + Medicare cost report struct | ✅ Real | Used in `ratios.jl`, `reimbursement.jl` |
| 7 SearchLight migrations (orgs, users, hospitals, fiscal years, scenarios, departments/staff, capital/risk) | ✅ Real | `app/db/migrations/001..007` |
| HCRIS (Medicare cost report) parser | ✅ Real | `test_hcris_parser.jl` exists; importer in `data_ingestion/` |
| FHIR / 837 / X12 ingestion | ❌ Stub | Listed in `REQUIREMENTS_DOCUMENT.md`; no implementation |
| HIPAA audit logger + de-identifier | ✅ Real | `data_ingestion/audit_logger.jl`, `deidentifiers.jl` |
| PostgreSQL schema with column-level AES-256-GCM | 🟡 Documented | Schema in `DATA_DICTIONARY.md`; not all encryption verified in code |

### 1.2 `packages/FinanceEngine` (CFO toolbox — the most MBA-relevant package)

17 modules / ~7,000 lines. Verified function inventory:

| Module | Real functions present | Notable gaps for MBA-grade analytics |
|---|---|---|
| `financial.jl` | `npv`, `roi`, `operating_margin`, `cost_per_patient`, `break_even_units`, `payback_period`, `drg_revenue`, `weighted_payer_rate`, `net_collection_rate` | ❌ No IRR, no MIRR, no profitability index, no equivalent annual cost |
| `capital_structure.jl` | `wacc`, `bond_price`, `bond_yield_to_maturity`, `capital_budget_ranking`, `financial_health_scorecard`, `debt_service_coverage_ratio`, `days_cash_on_hand`, `current_ratio`, `debt_to_capitalization` | ❌ No levered/unlevered beta, no cost-of-equity via CAPM tailored to non-profits, no tax-exempt bond modeling specifics, no covenant headroom calculator, no synthetic credit-rating model |
| `cost_accounting.jl` | `cost_to_charge_ratio`, `step_down_allocation`, `activity_based_cost`, `marginal_cost`, `department_profitability`, `value_score`, `quality_score`, `efficiency_score`, `readmission_penalty` | 🟡 ABC exists but no driver library, no reciprocal-method cost allocation, no time-driven ABC, no transfer pricing |
| `financial_monitoring.jl` | `initialize_kalman`, `kalman_filter_step`, `margin_tracker`, `early_warning_signal` | 🟡 Kalman is 1-D; no multivariate state, no regime-switching |
| `optimization.jl` | `optimal_bed_expansion`, `optimal_staffing`, `rouwenhorst_grid` | ❌ No service-line portfolio optimization with Markowitz framing, no integer programming for service-line entry/exit |
| `strategic_planning.jl` | `cost_trajectory` (LQ control), `merger_integration_plan`, `restructuring_plan`, `revenue_enhancement_plan` | ❌ M&A modules are templates, not valuation engines (no DCF + synergy + integration cost stack) |
| `risk_contracting.jl` | `pmpm`, `shared_savings`, `shared_risk`, `risk_corridor` | 🟡 Has the basics; no HCC risk adjustment with Medicare Advantage v28, no full-risk capitation P&L, no MLR rebate calculator |
| `value_based_care.jl` | `value_score`, `qalys`, `quality_score`, `efficiency_score`, `readmission_penalty` | 🟡 Doesn't tie to MIPS / VBP / HRRP / HACRP scoring |
| `population_health.jl` | `preventive_care_roi`, `telehealth_cost_effectiveness`, `sdoh_impact_model`, `chronic_disease_management_savings` | 🟡 Useful, but no AWV / TCM / CCM revenue model for rural FQHCs / RHCs |
| `operational_efficiency.jl` | `length_of_stay_analysis`, `bed_turnover_rate`, `ed_throughput`, `surgical_utilization`, `capacity_planning`, `staffing_ratio` | 🟡 Throughput exists; no DEA, no SFA, no Theory-of-Constraints bottleneck routine |
| `supply_chain.jl` | `economic_order_quantity`, `safety_stock`, `inventory_turnover`, `pharmaceutical_cost_analysis`, `stockout_cost`, `vendor_scorecard` | ✅ Reasonably complete for an MBA inventory chapter |
| `econometrics.jl` | `simple_linear_regression`, `predict_linear`, `r_squared`, `mean_absolute_error`, `monte_carlo_mean`, `simulate_growth`, `arma_forecast`, `arma_stochastic_paths` | 🟡 No VAR, no Bayesian VAR, no panel methods (fixed/random effects) — important for cross-state policy work |
| `simulation.jl` | Generic MC harness | (See `src/simulation` for ABM/DES/SD) |
| `performance_optimization.jl` | `parallelize_sweep`, `benchmark_abm`, `setup_worker_pool`, caching | Engineering plumbing (good) |
| `scenario_persistence.jl` | `Scenario`, `save_scenario`, `load_scenario`, `list_scenarios` | SQLite-backed; no scenario diff/compare |
| `undo_redo.jl` | Command pattern for parameter changes | UX plumbing (good) |

### 1.3 `src/` modules outside FinanceEngine

| Family | Files | Real or stub? |
|---|---|---|
| `analysis/` | `community.jl`, `community_benefit.jl`, `comparison.jl`, `geographic_access.jl`, `network_economics.jl`, `payer_negotiation.jl`, `sdoh.jl` | All real; `payer_negotiation.jl` was just corrected by T-001 |
| `analytics/` | `AdvancedAnalytics.jl` (571 LOC, GLM-based), `CostAnalysis.jl` (560 LOC) | Real but limited: logistic readmission, z-score anomaly. No XGBoost / no survival analysis / no time-to-closure hazard models |
| `comparative_effectiveness/` | `ComparativeEffectiveness.jl`, `CostEffectivenessAnalysis.jl`, `QualYCalculator.jl`, `SensitivityAnalysis.jl`, `ThresholdAnalysis.jl` | Real, ICER/NMB/PSA — strong on the public-health side |
| `health_economics/` | `ICER.jl` (267), `QALY.jl` (217), `NMB.jl`, `Uncertainty.jl` | Real |
| `risk/` | `closure.jl` (377), `closure_ml.jl` (193, Chartis 10-var logistic), `conversion.jl` (404, REH), `disaster_resilience.jl` | Real and substantive |
| `simulation/` | `abm.jl`, `des.jl`, `deterministic.jl`, `montecarlo.jl`, `scenarios.jl`, `systemdynamics.jl` | Real, all four engine types |
| `optimization/` | `OutcomeOptimization.jl`, `ResourceAllocation.jl`, `ValueBasedOptimization.jl`, `capital_scoring.jl`, `portfolio.jl`, `staffing.jl`, **`dummy.jl` (empty)** | Mostly real; `dummy.jl` is a placeholder smell |
| `policy/` | `MultiLevelPolicyCoupling.jl` | Real |
| `patient_flow/` | `ClinicalPathway.jl`, `CohortSimulation.jl`, `FlowSimulation.jl`, `PatientAgent.jl`, **`dummy.jl`** | Real with one stub |
| `episode/` | 9 files including `EpisodeCostModels.jl`, `ServiceLineCostAllocation.jl`, `ServiceLineMetrics.jl` | Real, recently expanded |
| `network/` | `HospitalNetworkSimulation.jl` | Real |
| `payer_models/` | `BudgetImpactModel.jl`, `FinancialImpact.jl`, `QualityMetrics.jl`, `ValueBasedCare.jl`, **`dummy.jl`** | Real with stub |
| `clinical_integration/` | `ClinicalEconomicCoupling.jl`, `PhysiologicalModel.jl`, **`dummy.jl`** | Real with stub |
| `visualization/` | `CostEffectiveness.jl`, `Dashboards.jl`, `PolicyAnalysisReporting.jl`, **`dummy.jl`** | Mostly real |
| `validation/` | `PolicyValidation.jl` | Real |
| `release/` | `ReleasePreparation.jl` | Real |
| `data_ingestion/` | Pipeline + audit logger + de-identifiers + validators | Real |
| `utils/` | `constants.jl`, `formatting.jl`, `types.jl`, `validation.jl` | Real |

### 1.4 Web application (`app/` — Genie + Stipple)

17 reactive views: `dashboard`, `hospital_profile`, `cost_structure`, `payer_negotiation`, `cost_reimbursement`, `financial_sim`, `simulation_runner`, `break_even`, `debt_capacity`, `team_bundled`, `telehealth`, `community_impact`, `disaster_resilience`, `geographic_access`, `reh_wizard`, `strategic_planner`, `results`. Controllers: `DataController`, `RiskController`, `OptimizationController`, `SimulationController`. Configurations for `dev`, `test`, `prod`.

### 1.5 Testing & CI

- 64 unique test files in `test/` (plus 14 macOS dupes that should not be committed).
- 3 GitHub Actions workflows: `ci.yml`, `hygiene.yml`, `test.yml`.
- Aqua.jl + JET.jl wired in `packages/FinanceEngine` per the `julia-enterprise-repo` standard.
- Playwright E2E suite (`e2e/tests/`): 7 specs (api-health, dashboard, navigation, hospital-profile, financial-sim, reh-wizard, analysis-tools).
- **No Codecov / Coveralls integration visible.** The "100% coverage" claim is unverifiable.

---

## 2. The MBA gap list — six domains

For each gap I give: **what's missing, where it should live, the MBA-evaluator rationale, an acceptance test sketch, and a priority.**

> Priority key: **P0** = blocks claim of "MBA-grade for rural"; **P1** = strongly expected by an MBA evaluator; **P2** = differentiator / nice-to-have.

### Domain A — Corporate finance & valuation depth (**weight: highest**)

| ID | Gap | Target module | Acceptance test sketch | P |
|---|---|---|---|---|
| A-01 | **Three-statement projection engine** (income statement + balance sheet + cash-flow statement, calibrated to a CMS HCRIS Worksheet S/G/A/B) is implied but not present as one composable struct. Currently `AnnualFinancials` exists but balance-sheet projection logic is fragmented. | New `src/finance/three_statement.jl` (or `packages/FinanceEngine/src/three_statement.jl`) | Given a Worksheet S-3 stub, project 5 yrs IS/BS/CF, prove BS balances each year, prove CF ties to IS+BS. | **P0** |
| A-02 | **Full DuPont decomposition** (3-factor + 5-factor) for nonprofit hospital margin: Net Margin × Asset Turnover × Equity Multiplier; plus 5-factor with EBIT/Sales × Sales/Assets × Assets/Equity × Tax Burden × Interest Burden adapted for tax-exempt entities. | `src/finance/dupont.jl` | Given AnnualFinancials + balance-sheet, return both decompositions; matches a hand-computed Moody's-style example to within 0.5 pp. | **P0** |
| A-03 | **Altman Z″-score** (private-firm variant, suitable for nonprofit hospitals) and **Beneish M-score** for earnings-quality screening of competitor / acquisition-target hospitals. | `src/finance/distress_scoring.jl` | Z″ on a known-distressed CAH (e.g., a closed hospital from CHQPR list) flags below 1.10. | **P0** |
| A-04 | **Cost of capital tailored to nonprofit / district / governmental hospitals**: tax-exempt municipal bond curve, AAA/AA/A/BBB rural-hospital spreads, levered/unlevered beta from FFY peer set, MADS (Maximum Annual Debt Service) covenant calculator. | Extend `capital_structure.jl` with `nonprofit_wacc`, `mads_headroom`, `synthetic_rating` | Given debt schedule + 5-yr operating projection, returns covenant headroom and synthetic Moody's rating. | **P0** |
| A-05 | **IRR, MIRR, profitability index, equivalent annual cost** — basic capital-budgeting ratios that should sit next to `npv` in `financial.jl`. | `financial.jl` | Standard textbook examples match. | **P1** |
| A-06 | **Real-options valuation on service lines** (option to expand OB, option to abandon inpatient, option to convert CAH→REH). Black-Scholes-Merton on continuous flows; binomial lattice for discrete decisions; Longstaff-Schwartz LSM for early-exercise paths. | `src/finance/real_options.jl` | REH conversion option valued > NPV of stay-as-CAH on stress scenarios; matches a known textbook closed-form on a toy. | **P0** |
| A-07 | **M&A / affiliation valuation engine**: standalone DCF + synergy DCF + integration-cost waterfall + accretion/dilution on the parent system + tax & 501(r) implications. The current `merger_integration_plan` in FinanceEngine is a planning template, not a valuation. | `src/finance/ma_valuation.jl` | Given two AnnualFinancials, returns deal NPV, synergy NPV, IRR to acquirer, breakeven multiple. | **P1** |
| A-08 | **LBO / restructuring model** — for distressed-hospital takeouts and REIT-leaseback scenarios increasingly relevant in rural markets. | `src/finance/lbo_model.jl` | Sources & uses balances; 5-yr IRR within 0.1 pp of a Damodaran textbook example. | **P2** |
| A-09 | **Treasury & liquidity stress test** — 13-week cash-flow forecast, days-cash-on-hand under shock scenarios, line-of-credit headroom. | `src/finance/treasury.jl` | 13-week forecast given AR aging + AP aging + payroll cycle; stress to 30/60/90-day Medicare-payment delays. | **P0** |
| A-10 | **Working-capital optimization** — AR cycle, AP cycle, inventory cycle, cash conversion cycle, target-DSO model. The `supply_chain.jl` covers inventory but not AR/AP. | `src/finance/working_capital.jl` | CCC = DSO + DIO − DPO; closed-form sensitivity to denials and aging buckets. | **P1** |

### Domain B — Strategic & decision analytics (**weight: high**)

| ID | Gap | Target module | Acceptance test sketch | P |
|---|---|---|---|---|
| B-01 | **Balanced Scorecard / Strategy Map engine** — auto-compose 4-perspective (Financial / Customer / Internal / Learning) scorecard from existing metrics with cause-and-effect linkages. | `src/strategy/balanced_scorecard.jl` | Given a metrics dict, render scorecard table + mermaid strategy map. | **P1** |
| B-02 | **Porter Five Forces & SWOT structured outputs** for rural markets (low new-entrant threat but high payer power; thin substitutes but high regulatory pressure). Codify this as a JSON-driven framework so an analyst can produce a defensible competitive analysis. | `src/strategy/competitive.jl` | Inputs: HRR/HSA, payer mix, peer hospitals; outputs: 5-forces scoring with citations to AHA / RUPRI. | **P2** |
| B-03 | **Service-line portfolio optimization (Markowitz-style)** — frontier of expected margin vs margin variance across service lines, with capacity & community-need constraints. | `src/optimization/service_line_portfolio.jl` | Given service-line history (revenue, cost, volume), produce efficient frontier; integer-constrained variant for "open / close" decisions. | **P0** |
| B-04 | **Real-options decision tree on REH conversion** (already partly in `risk/conversion.jl`, but missing the decision-analytic frame: nodes for "wait 1 yr," "convert now," "close ED," with information-value of HCRIS update). | Extend `risk/conversion.jl` | Decision tree returns expected value-of-information for waiting; matches the Mathematica Decision Analysis textbook problem. | **P1** |
| B-05 | **Strategic scenario planning à la Wack/Schwartz** — three-scenario divergent futures (e.g., 340B repeal / Medicaid expansion in remaining states / Medicare physician-fee-schedule cuts); pre-computed scoring across all hospital decisions. | `src/strategy/scenario_planning.jl` | A scenario-by-decision payoff matrix is rendered. | **P2** |
| B-06 | **Game-theoretic payer-negotiation module** — current `payer_negotiation.jl` computes a rate; missing: Nash bargaining, BATNA modeling, reservation-price calibration, multi-round simulation. | Extend `analysis/payer_negotiation.jl` | Nash bargaining given outside options; matches Damodaran/Brandenburger example. | **P1** |
| B-07 | **HRR/HSA-level competitive analytics**: market share, HHI, geographic-access overlap (currently `geographic_access.jl` exists; HHI does not). | Extend `analysis/network_economics.jl` | HHI computed for each HRR; trend over 5 yrs given Dartmouth Atlas + CMS POS. | **P1** |

### Domain C — Operational & productivity analytics (**weight: high**)

| ID | Gap | Target module | Acceptance test sketch | P |
|---|---|---|---|---|
| C-01 | **Data Envelopment Analysis (DEA)** — DEA-CCR and DEA-BCC for efficiency frontier across peer rural hospitals. | `src/analytics/dea.jl` | Given peer DMUs (inputs: FTEs, beds, capital; outputs: discharges, ED visits, quality), return relative efficiency scores; replicate the Färe textbook example. | **P0** |
| C-02 | **Stochastic Frontier Analysis (SFA)** for cost efficiency with translog cost function. | `src/analytics/sfa.jl` | Half-normal inefficiency model; matches a published rural-hospital SFA paper to within reported coefficients. | **P1** |
| C-03 | **Variance analysis (price/volume/mix) for revenue cycle** — bridge from prior-period to current-period revenue with rate, volume, and case-mix-index components. | `src/finance/variance_analysis.jl` | Walk decomposition sums to total ΔRevenue exactly. | **P0** |
| C-04 | **Theory-of-Constraints bottleneck identification** for ED throughput, OR utilization, swing-bed flow. | `src/analytics/toc_bottleneck.jl` | Identifies the constraint resource and computes throughput dollars/hour. | **P2** |
| C-05 | **Time-Driven Activity-Based Costing (TDABC)** — current `activity_based_cost` uses traditional ABC. TDABC is the modern Kaplan/Anderson method. | Extend `cost_accounting.jl` | Capacity-cost rate per minute × time-equation = service cost; matches HBR example. | **P1** |
| C-06 | **Reciprocal-method cost allocation** (currently only step-down). MBA-grade cost-accounting expects all three: direct, step-down, reciprocal. | Extend `cost_accounting.jl` | Reciprocal allocation matrix solved via linear system; ties to step-down within rounding for non-cyclic dependency graphs. | **P1** |
| C-07 | **Productivity benchmarking against MGMA / AHA / Flex Monitoring** percentiles (FTE per AOB, OR turnover, RN HPPD, etc.) — `ratios.jl` does Flex 10 ratios but no peer benchmarking. | `src/analytics/peer_benchmarking.jl` | Given a CAH and a peer set (e.g., all CAHs <25 beds in the same region), return percentile bands per ratio. | **P0** |

### Domain D — Risk & ML analytics (**weight: medium-high**)

| ID | Gap | Target module | Acceptance test sketch | P |
|---|---|---|---|---|
| D-01 | **Closure hazard model (Cox proportional hazards / parametric AFT)** in addition to the existing logistic Chartis model in `closure_ml.jl`. Time-to-closure is the natural target. | Extend `risk/closure_ml.jl` | Cox PH on Sheps Center closure dataset; concordance > 0.75. | **P1** |
| D-02 | **Gradient-boosted closure model (XGBoost/LightGBM via `MLJ.jl`)** as a higher-accuracy alternative to logistic. | `risk/closure_ml.jl` | AUC improvement over logistic on held-out test ≥ 0.05. | **P2** |
| D-03 | **Bayesian VBC contract simulator** — current `risk_contracting.jl` has shared_savings/risk; missing posterior-predictive distributions over savings under prior uncertainty. | Extend `value_based_care.jl` | Returns posterior over savings using Turing.jl; calibration plot in 95% CI. | **P1** |
| D-04 | **Monte Carlo with copula-correlated inputs** — current MC uses independent draws. Real CFOs need correlated revenue/expense shocks (e.g., utilization down ⇒ revenue down ⇒ supply costs partly down). | Extend `simulation/montecarlo.jl` | Gaussian or t-copula on arbitrary marginals; correlation recovered to within 0.02. | **P0** |
| D-05 | **Value-at-Risk (VaR) and Expected Shortfall (CVaR)** on operating margin, days-cash-on-hand, and net assets. | `src/risk/var_cvar.jl` | 95% VaR and CVaR computed via historical, parametric, and MC methods; consistent within 5%. | **P1** |
| D-06 | **Scenario stress-testing à la Federal Reserve CCAR** — adverse and severely-adverse macro scenarios applied to hospital projections. | `src/risk/stress_test.jl` | Fed-style severe scenario applied to a 5-yr projection; reports breach years and recovery time. | **P1** |
| D-07 | **Natural disaster / climate stress test** — `disaster_resilience.jl` exists. Extend to NOAA SVI + climate-projection inputs. | Extend `risk/disaster_resilience.jl` | County-FIPS lookup of hurricane/wildfire/flood probability; integrates into closure-risk score. | **P2** |

### Domain E — Reimbursement & policy analytics depth (**weight: high — distinguishes rural focus**)

| ID | Gap | Target module | Acceptance test sketch | P |
|---|---|---|---|---|
| E-01 | **CAH 101% cost-based reimbursement** is implemented (`reimbursement.jl`), but **outlier payments**, **DSH for CAHs (limited)**, **TEFRA target rate variants** are not fully parameterized. The Tier-1 audit (`HAIKU_BUILD_PLAN_PHASE2`, archived) flagged outlier payment % as missing — confirmed. | Extend `finance/reimbursement.jl` and `utils/constants.jl` | Replicate a CAH cost report Worksheet E-1 line-by-line within 0.5%. | **P0** |
| E-02 | **REH facility payment + outpatient add-on (5%)** — partly implemented. Missing: monthly facility payment trending, partial-year proration, REH-quality-program adjustments. | Extend `risk/conversion.jl`, `reimbursement.jl` | Given REH params, compute year-by-year payment matching CMS REH technical specs PDF examples. | **P0** |
| E-03 | **Medicare Advantage (MA) payment under v28 risk model and MA rural-hospital pass-through** — entirely missing. MA is now ~50% of Medicare beneficiaries; absence is a major MBA gap. | `src/finance/medicare_advantage.jl` | HCC v28 model coefficients with normalization factor 1.045; matches CMS rate book example. | **P0** |
| E-04 | **Rural Health Clinic (RHC) AIR cap, Method II billing, productivity standards** — `rhc_optimization.jl` exists but does not model the AIR cap mechanism end-to-end nor the new RHC payment limit phase-in. | Extend `finance/rhc_optimization.jl` | Compute AIR vs cap; phase-in trajectory matches CAA 2021 schedule. | **P1** |
| E-05 | **340B program economics** — `program340b.jl` exists. Missing: contract-pharmacy dispensing model, manufacturer restrictions tracking, modifier JG/TB tracking, savings-share with referral providers. | Extend `finance/program340b.jl` | Given a Medicaid duplicate-discount scenario, returns net 340B savings with reasonable assumptions. | **P1** |
| E-06 | **MIPS / VBP / HRRP / HACRP scoring** — implemented metrics exist (`QualityMetrics.jl`) but the actual CMS scoring algorithms with current threshold tables are not implemented. | `src/policy/mips_vbp_hrrp.jl` | Given a hospital's measure scores, compute the % payment adjustment exactly per CMS spec. | **P0** |
| E-07 | **TEAM (Transforming Episode Accountability Model) bundled-payment program** — `team_bundled.jl` exists. Verify it's current with the FY2026 TEAM final rule (mandatory model starting Jan 2026). | Audit + extend `finance/team_bundled.jl` | Reproduce a TEAM target-price calculation per the CMS TEAM specifications manual. | **P0** |
| E-08 | **State Medicaid supplemental payment programs** — `medicaid_supplemental.jl` exists for UPL/DSH. Missing: state-directed payments (SDPs), graduate medical education (GME) payments, HRSA-funded RHC enhanced payments. | Extend `finance/medicaid_supplemental.jl` | State-directed-payment estimator for at least 3 states with public methodologies (TX, CA, OH). | **P1** |
| E-09 | **No-Surprises-Act independent dispute resolution (IDR) economics** — entirely missing. Increasingly relevant for rural ED out-of-network billing. | `src/policy/nsa_idr.jl` | Computes Qualified Payment Amount (QPA) and IDR-batch-eligible claims per CMS NSA rule. | **P2** |

### Domain F — Reporting, decisioning, and presentation layer (**weight: medium**)

| ID | Gap | Target module | Acceptance test sketch | P |
|---|---|---|---|---|
| F-01 | **Board-ready packet generator** — auto-render a 12-page board PDF (cover, exec summary, scorecard, scenarios, risks, capital plan, payer-mix walk, productivity, quality, community impact, financials, appendix). | `src/visualization/board_packet.jl` + `pdf` skill | Given a fiscal year, produces a deterministic 12-page PDF that an actual hospital board would accept. | **P0** |
| F-02 | **Rating-agency-style memo** (Moody's / Fitch format) — narrative + ratios + peer comparison + outlook. | `src/visualization/rating_memo.jl` | Renders a docx that mirrors the Moody's "Issuer Comment" structure. | **P1** |
| F-03 | **CFO 1-pager (weekly/monthly)** — single-screen KPI dashboard with sparklines, RAG status, and exception flags. | Extend `app/views/dashboard/` | Loads in <500 ms on the existing Stipple dashboard; passes Playwright spec. | **P0** |
| F-04 | **Sensitivity-tornado on every model** — exists for sensitivity analysis but not exposed uniformly across modules. | `src/visualization/tornado.jl` | A single API call `tornado(model, params)` returns sorted bars. | **P1** |
| F-05 | **Scenario diff/compare** — current scenario_persistence stores scenarios but has no diff. | Extend `scenario_persistence.jl` | Two scenarios → side-by-side delta table. | **P1** |
| F-06 | **CMS HCRIS auto-importer** — `test_hcris_parser` exists but no end-to-end CLI for "give me a CCN, get a fully populated AnnualFinancials." | `scripts/import_hcris.jl` | `julia scripts/import_hcris.jl --ccn 011300 --year 2024` populates the full data model. | **P0** |
| F-07 | **Federal Register / proposed-rule monitor** — pull IPPS, OPPS, PFS, REH, 340B proposed rules as soon as published; auto-recompute impact. | `scripts/fed_register_monitor.jl` | Given a date range, returns relevant rules with delta on hospital margin. | **P2** |

---

## 3. Six-domain execution plan (sequenced)

This plan deliberately does **not** repeat the structure of the archived `STRATEGIC_IMPLEMENTATION_PLAN.md`. It is organized by **MBA-evaluator readiness milestones**, not by month.

### Milestone M1 — "CFO can use it tomorrow" (4–6 weeks of focused work)

Closes the most embarrassing gaps for an MBA evaluator. Items: A-01, A-02, A-03, A-04, A-09, B-03, C-01, C-03, C-07, D-04, E-01, E-02, E-06, E-07, F-01, F-03, F-06, plus repo-hygiene cleanup (§4).

Rationale: the M1 set is the minimum bar at which a rural-hospital CFO and a strategy MBA can independently produce a board-ready financial position, three-statement projection, distress score, peer-benchmark, throughput variance, payment-program impact, and a deterministic board packet — all from an HCRIS CCN.

### Milestone M2 — "Strategy consultant can use it" (next 6–8 weeks)

Items: A-05, A-06, A-07, A-10, B-01, B-04, B-06, B-07, C-02, C-05, C-06, D-01, D-03, D-05, D-06, E-03, E-04, E-05, E-08, F-02, F-04, F-05.

Rationale: real-options, M&A modeling, balanced scorecard, Cox closure, Bayesian VBC, MA risk-adjustment, full payer-program coverage, board memos. After M2, the platform can support service-line strategy decisions, payer negotiations, and CAH→REH go/no-go with documented evidence.

### Milestone M3 — "Differentiator features" (later)

Items: A-08 (LBO), B-02, B-05, C-04 (TOC), D-02 (XGBoost), D-07 (climate), E-09 (NSA-IDR), F-07 (Fed Reg monitor).

These are the items that move the platform from "credible MBA toolkit" to "research-publication-grade" — appropriate for collaboration with academic centers (RUPRI, Sheps Center, Flex Monitoring Team).

### Cross-cutting workstreams running through all milestones

1. **Repo hygiene** — delete the 42 macOS Finder duplicate files, enforce in `.github/workflows/hygiene.yml` via a check that `find . -regex '.* [0-9]\..*'` returns empty. **(2 hr task; P0.)**
2. **Coverage measurement** — wire Codecov into `ci.yml`, fail PRs that drop coverage > 1 pp. Replace the self-asserted "100% coverage" claim. **(1 day; P0.)**
3. **Documenter.jl docs site** — convert the existing scattered Markdown into a Documenter.jl site at `gh-pages`. **(2 days; P1.)**
4. **Branch consolidation** — see §4. **(0.5 day; P0.)**
5. **CMS data ingestion** — HCRIS, POS, MA-PD, SDP, Hospital Compare, MEDPAR — bundled in `data/` with idempotent download scripts. **(1 wk; P0.)**
6. **Reproducible research bundle** — `make benchmarks` should produce the figures/tables for a future RUPRI-style working paper. **(P1.)**

### Suggested package decomposition after the gaps close

The `RuralHospitalSim` umbrella package is straining. Once M2 is done, split into:

| Package | Purpose |
|---|---|
| `RuralCore.jl` (exists) | Auth, audit, types, validation |
| `FinanceEngine.jl` (exists, expand) | All A-* and C-* corporate-finance math |
| `RuralReimbursement.jl` (new) | All E-* CMS / Medicaid reimbursement math |
| `RuralAnalytics.jl` (new) | DEA, SFA, ML closure, Bayesian VBC, copula MC |
| `RuralStrategy.jl` (new) | Balanced scorecard, real options, M&A, scenario planning |
| `RuralReports.jl` (new) | Board packet, rating memo, tornado, scenario diff |
| `RuralHospitalSim.jl` (umbrella) | Web app, controllers, integration |

This makes each package independently testable, separately versionable, and individually citable.

---

## 4. Branch-consolidation plan

### Current state (22 remote branches)

| Branch | Last action seen | Recommendation |
|---|---|---|
| `main` | Active | **Keep — canonical.** |
| `claude/audit-fix-planning-DVvmd` | Audit fix planning predecessor of merged Tier-0 work | **Delete** (work merged via T-001..T-007). |
| `claude/gap-analysis-nY74X` | Pre-FinanceEngine import gap analysis | **Delete** (superseded by this document). |
| `claude/hospital-finance-ui-plan-Wk2lK` | UI plan | **Inspect, then merge or delete.** |
| `claude/update-repo-docs-duXdu` | Doc update | **Inspect, then merge or delete.** |
| `claude/mba-gap-analysis-2026-04-27` | This branch | **Open PR.** |
| `copilot/add-multi-level-policy-simulation` | Pre-merge Phase 3.1 | **Delete** (merged). |
| `copilot/add-reusable-formgrid-and-components` | Pre-merge E3 | **Delete** (merged). |
| `copilot/add-service-line-analytics` | Pre-merge | **Delete if merged; otherwise rebase.** |
| `copilot/add-state-level-policy-simulation-module` | Pre-merge Phase 3.x | **Delete** (merged). |
| `copilot/add-value-based-optimization-module` | Pre-merge | **Delete** (merged). |
| `copilot/create-hospital-network-simulation` | Pre-merge | **Delete** (merged). |
| `copilot/create-publication-ready-visualization` | Pre-merge | **Delete** (merged). |
| `copilot/create-reusable-upload-component` | Pre-merge E2 | **Delete** (merged). |
| `copilot/create-shared-ui-framework` | Pre-merge E1 | **Delete** (merged). |
| `copilot/e27-reusable-bug-report-component` | Pre-merge E27 | **Delete** (merged). |
| `copilot/implement-cost-models` | Pre-merge | **Delete** (merged). |
| `copilot/phase-1-2-patient-flow-integration` | Pre-merge | **Delete** (merged). |
| `copilot/phase-2-validation-integration-testing` | Pre-merge | **Delete** (merged). |
| `copilot/prepare-v1-0-release-docs-testing` | Pre-merge | **Delete** (merged). |
| `copilot/validate-phase-1-implementation` | Pre-merge | **Delete** (merged). |
| `copilot/validate-real-world-policy-cases` | Pre-merge | **Delete** (merged). |
| `feature/add-financeengine` | Pre-merge (PR #65) | **Delete** (merged). |

Concretely, after this PR lands, run:

```bash
git push origin --delete \
  claude/audit-fix-planning-DVvmd \
  claude/gap-analysis-nY74X \
  copilot/add-multi-level-policy-simulation \
  copilot/add-reusable-formgrid-and-components \
  copilot/add-state-level-policy-simulation-module \
  copilot/add-value-based-optimization-module \
  copilot/create-hospital-network-simulation \
  copilot/create-publication-ready-visualization \
  copilot/create-reusable-upload-component \
  copilot/create-shared-ui-framework \
  copilot/e27-reusable-bug-report-component \
  copilot/implement-cost-models \
  copilot/phase-1-2-patient-flow-integration \
  copilot/phase-2-validation-integration-testing \
  copilot/prepare-v1-0-release-docs-testing \
  copilot/validate-phase-1-implementation \
  copilot/validate-real-world-policy-cases \
  feature/add-financeengine
```

Then inspect and decide on the four `claude/*` and one `copilot/*` (`add-service-line-analytics`) ambiguous branches with `git diff origin/main`.

---

## 5. Acceptance criteria for "MBA-grade for rural"

The platform is **MBA-grade for rural / CAH / REH analytics** when, *for any rural hospital identified by CCN*, an analyst with no prior knowledge of the codebase can produce in one session:

1. A populated **AnnualFinancials** struct from HCRIS for the most recent reporting year. **(F-06)**
2. A **5-year three-statement projection** that ties IS↔BS↔CF. **(A-01)**
3. **DuPont (3- and 5-factor)** decomposition. **(A-02)**
4. **Altman Z″** and **Beneish M-score**. **(A-03)**
5. **WACC, MADS headroom, synthetic credit rating**. **(A-04)**
6. A **service-line portfolio frontier** with constraints. **(B-03)**
7. **DEA efficiency score** vs a peer set. **(C-01)**
8. **Closure hazard** + ML probability. **(D-01, existing closure_ml)**
9. **Reimbursement walk** for CAH (or PPS), with sequestration, bad debt, outliers, and DSH. **(E-01)**
10. A **CAH→REH conversion** NPV with real-options value-of-waiting. **(A-06, E-02)**
11. **MA risk-adjusted P&L** under HCC v28. **(E-03)**
12. **MIPS / VBP / HRRP / HACRP** payment adjustment. **(E-06)**
13. A **board packet PDF** that an actual hospital board would accept. **(F-01)**
14. A **reproducible scenario** that another analyst can re-run with one command and get identical numbers. **(F-05, plus existing `scenario_persistence`)**

When all 14 work end-to-end, the platform clears the bar.

---

## 6. What to remove or refactor (negative space)

- Delete `src/optimization/dummy.jl`, `src/clinical_integration/dummy.jl`, `src/payer_models/dummy.jl`, `src/visualization/dummy.jl`, `src/patient_flow/dummy.jl` — they are zero-byte or near-zero-byte placeholders that pollute module loading.
- Delete all 42 ` 2.*`, ` 3.*`, ` 4.*` macOS Finder duplicates.
- Resolve the `Project.toml` Julia compat split — the umbrella declares `julia = "1.11"`, `FinanceEngine` declares `julia = "1.12"`. Pick one (recommend 1.11 LTS-track).
- The `tsconfig.json` + `package.json` + `playwright.config.ts` at the repo root suggest a JS toolchain that's only used for E2E. Move it under `e2e/` so the root package.json doesn't confuse repo scanners and SBOM tools.
- `BUILD_LOG.md`, `BUILD_AUTOMATION_GUIDE.md`, `CLAUDE_CODE_CLI_GUIDE.md` are operational notes that belong in `docs/operations/`, not at the repo root.

---

## Appendix A — Branch enumeration (as of 2026-04-27)

```
* main
  remotes/origin/HEAD -> origin/main
  remotes/origin/claude/audit-fix-planning-DVvmd
  remotes/origin/claude/gap-analysis-nY74X
  remotes/origin/claude/hospital-finance-ui-plan-Wk2lK
  remotes/origin/claude/update-repo-docs-duXdu
  remotes/origin/copilot/add-multi-level-policy-simulation
  remotes/origin/copilot/add-reusable-formgrid-and-components
  remotes/origin/copilot/add-service-line-analytics
  remotes/origin/copilot/add-state-level-policy-simulation-module
  remotes/origin/copilot/add-value-based-optimization-module
  remotes/origin/copilot/create-hospital-network-simulation
  remotes/origin/copilot/create-publication-ready-visualization
  remotes/origin/copilot/create-reusable-upload-component
  remotes/origin/copilot/create-shared-ui-framework
  remotes/origin/copilot/e27-reusable-bug-report-component
  remotes/origin/copilot/implement-cost-models
  remotes/origin/copilot/phase-1-2-patient-flow-integration
  remotes/origin/copilot/phase-2-validation-integration-testing
  remotes/origin/copilot/prepare-v1-0-release-docs-testing
  remotes/origin/copilot/validate-phase-1-implementation
  remotes/origin/copilot/validate-real-world-policy-cases
  remotes/origin/feature/add-financeengine
```

## Appendix B — Files archived in this PR

```
archive/gap-analysis-history/
├── 2024-04_ROADMAP_v0.1.md
├── 2026-04-15_STRATEGIC_IMPLEMENTATION_PLAN.md
├── 2026-04_HAIKU_BUILD_PLAN_phase1_tier0.md
├── 2026-04_HAIKU_BUILD_PLAN_phase2_tier1.md
├── 2026-04_HAIKU_BUILD_TRACKING_phase1.md
├── 2026-04_HAIKU_BUILD_TRACKING_phase2.md
├── 2026-04_IMPLEMENTATION_STATUS.md
├── BUILD_COMPLETE.md
├── MODULE_1_BUILD_SUMMARY.md
├── MODULE_4_5_COMPLETION_SUMMARY.md
├── MODULE_6_COMPARATIVE_EFFECTIVENESS.md
└── README.md  (provenance & rationale)
```

## Appendix C — Source citations / standards baselines for new modules

USA-only sources, per project policy:

- **HCRIS** Worksheet S, S-3, G, A, B, C, E-1: CMS public files (cost-report).
- **AHA Annual Survey** for peer-set construction.
- **Flex Monitoring Team** for the 10-ratio CAH benchmark methodology.
- **Sheps Center for Health Services Research (UNC)** for closure datasets.
- **CHQPR** (Center for Healthcare Quality and Payment Reform) — payer-margin decomposition methodology and rural-payment-policy reference.
- **MedPAC** annual reports for payment-policy detail.
- **CMS** REH technical specifications, IPPS / OPPS / PFS final rules, MA HCC v28 model, MIPS / HVBP / HRRP / HACRP scoring methods.
- **HRSA / FORHP** for RHC and 340B program economics.
- **AAP / AHA / NRP / ACOG** clinical-economic costing baselines (per project's USA-only sourcing policy).
- **Damodaran (NYU Stern)** corporate-finance reference data (industry betas, ERP) — for cost-of-capital module.
- **Moody's / Fitch / S&P** healthcare rating methodology white papers — for synthetic-rating module.

---

*End of MBA Gap Analysis 2026-04-27.*
