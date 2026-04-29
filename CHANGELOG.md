# Changelog

All notable changes to `ruralpeds/Hospital-economics` are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-04-28

**First production-ready release.** Closes all Priority-1 MBA analytics gaps
identified in the April 2026 gap analysis. `packages/FinanceEngine` now ships
60+ modules covering every major domain of hospital CFO practice.

### Summary
- **New FinanceEngine modules:** 34 (across 6 MBA domains A–F)
- **New test assertions added:** 600+
- **Stale branches deleted:** 40
- **FinanceEngine exports:** 300+

### Added — Domain A: Corporate Finance
A-04 nonprofit_wacc (MMD curve, Hamada, WACC, MADS, covenant dashboard, synthetic rating);
A-05/A-06 real_options (BSM, CRR binomial, ServiceLineOption portfolio);
A-07 ma_valuation (DCF + comparables + asset-based, synergy NPV, IRR break-even);
A-09 treasury (13-week forecast, Medicare delay stress, LOC headroom);
A-10 working_capital (CCC, target DSO, AR aging analysis, scenario engine)

### Added — Domain B: Strategy
B-01 balanced_scorecard (20-KPI CAH library, RAG scoring, strategy map, initiatives);
B-03 service_line_portfolio (Markowitz efficient frontier, essential service constraints);
B-06 payer_negotiation_game (Nash bargaining, Kalai-Smorodinsky, Rubinstein);
B-07 competitive_analytics (HHI, market share, geographic overlap, merger delta)

### Added — Domain C: Operations
C-01 dea (DEA-CCR + DEA-BCC via JuMP/HiGHS, two-phase LP, scale efficiency);
C-02 sfa (translog cost frontier OLS + JLMS efficiency estimator);
C-03 variance_analysis (price/volume/mix revenue bridge + expense variance);
C-05 tdabc (Kaplan-Anderson TDABC, resource pools, time equations, unused capacity);
C-06 reciprocal_cost_allocation (step-down + simultaneous reciprocal (I-S)x=c);
C-07 peer_benchmarking (Flex Monitoring 2022, AHA Rural 2023, MGMA 2023 embedded tables)

### Added — Domain D: Risk & ML
D-01 cox_ph_closure (8-covariate Cox PH, AHA/HCRIS baseline survival, risk tiers);
D-03 vbc_bayesian_mssp (7-track MSSP priors, conjugate update, 3-level uncertainty MC);
D-04 copula_mc (Gaussian + t-copula, HOSPITAL_DEFAULT_CORRELATION, tail dependence);
D-05/D-06 var_cvar_stress (VaR/CVaR, CCAR_SCENARIOS_2024, covenant breach detection)

### Added — Domain E: Reimbursement
E-01 cah_outlier_payments (FY2026 fixed-loss $38,788; TEFRA incentive/penalty; Worksheet E-1);
E-03 medicare_advantage (65 HCC v28 CNA coefficients; normalization factors; rural 85% passthrough);
E-04 rhc_air_cap (CAA 2021 phase-in CY2022-2028; independent vs provider-based caps);
E-05 b340_contract_pharmacy (10-manufacturer restriction table; duplicate discount; inhouse comparison);
E-06 mips_vbp_hrrp (MIPS CY2025; VBP/HRRP/HACRP FY2026 with actual CMS algorithms);
E-07 team_bundled_payment (TEAM FY2026 CMS-5531-F; 5 episode types; reconciliation);
E-08 medicaid_sdp (42 CFR § 438.6(c); 4 tiers; UPL ceiling; statewide portfolio)

### Added — Domain F: Reporting
F-01 board_packet (12-section Markdown + Typst board packet generator);
F-02 rating_agency_memo (Moody's-style credit memo; 8 sections; auto-narrative);
F-03 cfo_dashboard (Stipple 1-pager; 6 KPI cards + sparklines; exception flags; /cfo route);
F-04 sensitivity_tornado (universal one-way/two-way/break-even/scenario API; Plotly-ready);
F-05 scenario_diff (ScenarioSnapshot compare; waterfall builder; ScenarioSet versioning);
F-06 import_hcris (CMS HCRIS CLI --ccn --year; Worksheet parsing; JSON/text output)

### Added — T-021 through T-030
MCResultCache, ConvergenceCriteria, bulk_project_hospitals; RatioCache; 16 validation helpers;
10-type hospital registry; ExtendedVBCParams; ICER sensitivity; cohort builder; REH analytics;
Report/ReportSection export framework

### Changed
- **Julia compat:** All packages aligned to `julia = "1.11"` (LTS)
- **CMS rates** (src/utils/constants.jl): All FY2026 values applied; 5 TODOs cleared
  (REH $295,135/mo; IPPS $6,881; OPPS $96.86; CAH outlier threshold $38,788)
- **CI:** Coverage-enabled tests + Codecov LCOV upload + 60% floor
- **JS toolchain** moved from root to `e2e/`; duplicate `/api/bugreport` route removed
- **Version:** 0.3.0 → **1.0.0**

### Fixed
- HCC v28 fixture: placeholder coefficients replaced with real CMS CY2024 values
- `vbc_transition.jl` TODO documented; `FinanceEngine.jl` conflict resolution

### Infrastructure
- 40 stale branches deleted; repo reduced from 41 to 2 branches pre-release

---

## [0.3.0] — 2026-04-01

Initial framework: Genie + Stipple stack; 26-module FinanceEngine; 38+ interactive views;
simulation engines; education center.
