# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Data Ingestion (E4, delegated to IngestionController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/ingest/hospital", method=POST) do
    try
        payload = jsonpayload()
        result = IngestionController.handle_hospital(payload)
        json(result)
    catch e
        _safe_error("Hospital data ingestion", e)
    end
end

route("/api/ingest/claims", method=POST) do
    try
        payload = jsonpayload()
        result = IngestionController.handle_claims(payload)
        json(result)
    catch e
        _safe_error("Claims data ingestion", e)
    end
end

route("/api/ingest/clinical", method=POST) do
    try
        payload = jsonpayload()
        result = IngestionController.handle_clinical(payload)
        json(result)
    catch e
        _safe_error("Clinical data ingestion", e)
    end
end

route("/api/ingest/financial", method=POST) do
    try
        payload = jsonpayload()
        result = IngestionController.handle_financial(payload)
        json(result)
    catch e
        _safe_error("Financial data ingestion", e)
    end
end

route("/api/ingest/registry", method=POST) do
    try
        payload = jsonpayload()
        result = IngestionController.handle_registry(payload)
        json(result)
    catch e
        _safe_error("Registry data ingestion", e)
    end
end

route("/api/ingest/validate", method=POST) do
    try
        payload = jsonpayload()
        result = IngestionController.handle_validate(payload)
        json(result)
    catch e
        _safe_error("Data validation", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Data Preparation (E5, delegated to PreparationController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/prepare/normalize", method=POST) do
    try
        payload = jsonpayload()
        result = PreparationController.handle_normalize(payload)
        json(result)
    catch e
        _safe_error("ID normalization", e)
    end
end

route("/api/prepare/standardize", method=POST) do
    try
        payload = jsonpayload()
        result = PreparationController.handle_standardize(payload)
        json(result)
    catch e
        _safe_error("Code standardization", e)
    end
end

route("/api/prepare/aggregate", method=POST) do
    try
        payload = jsonpayload()
        result = PreparationController.handle_aggregate(payload)
        json(result)
    catch e
        _safe_error("Episode aggregation", e)
    end
end

route("/api/prepare/risk-adjust", method=POST) do
    try
        payload = jsonpayload()
        result = PreparationController.handle_risk_adjust(payload)
        json(result)
    catch e
        _safe_error("Risk adjustment", e)
    end
end

route("/api/prepare/impute", method=POST) do
    try
        payload = jsonpayload()
        result = PreparationController.handle_impute(payload)
        json(result)
    catch e
        _safe_error("Imputation", e)
    end
end

route("/api/prepare/time-series", method=POST) do
    try
        payload = jsonpayload()
        result = PreparationController.handle_time_series(payload)
        json(result)
    catch e
        _safe_error("Time-series formatting", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Cohort Builder (E6, delegated to CohortsController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/cohorts/preview", method=POST) do
    try
        payload = jsonpayload()
        result = CohortsController.handle_preview(payload)
        json(result)
    catch e
        _safe_error("Cohort preview", e)
    end
end

route("/api/cohorts/save", method=POST) do
    try
        payload = jsonpayload()
        result = CohortsController.handle_save(payload)
        json(result)
    catch e
        _safe_error("Cohort save", e)
    end
end

route("/api/cohorts", method=GET) do
    try
        result = CohortsController.handle_list()
        json(result)
    catch e
        _safe_error("Cohort list", e)
    end
end

route("/api/cohorts/:id", method=GET) do
    try
        result = CohortsController.handle_get(params(:id))
        json(result)
    catch e
        _safe_error("Cohort get", e)
    end
end

route("/api/cohorts/:id", method=DELETE) do
    try
        result = CohortsController.handle_delete(params(:id))
        json(result)
    catch e
        _safe_error("Cohort delete", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Cost Analysis (E7, delegated to CostAnalysisController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/cost-analysis/total", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_total(payload)
        json(result)
    catch e
        _safe_error("Cost total", e)
    end
end

route("/api/cost-analysis/breakdown", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_breakdown(payload)
        json(result)
    catch e
        _safe_error("Cost breakdown", e)
    end
end

route("/api/cost-analysis/per-episode", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_per_episode(payload)
        json(result)
    catch e
        _safe_error("Per-episode cost", e)
    end
end

route("/api/cost-analysis/cpq", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_cpq(payload)
        json(result)
    catch e
        _safe_error("Cost per QALY", e)
    end
end

route("/api/cost-analysis/high-cost", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_high_cost(payload)
        json(result)
    catch e
        _safe_error("High-cost patient identification", e)
    end
end

route("/api/cost-analysis/project", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_project(payload)
        json(result)
    catch e
        _safe_error("Cost projection", e)
    end
end

route("/api/cost-analysis/inflate", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_inflate(payload)
        json(result)
    catch e
        _safe_error("Cost inflation adjustment", e)
    end
end

route("/api/cost-analysis/cohort-summary", method=POST) do
    try
        payload = jsonpayload()
        result = CostAnalysisController.handle_cohort_summary(payload)
        json(result)
    catch e
        _safe_error("Cohort cost summary", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Revenue & Reimbursement (E8, delegated to RevenueController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/revenue/total", method=POST) do
    try
        payload = jsonpayload()
        result = RevenueController.handle_total(payload)
        json(result)
    catch e
        _safe_error("Revenue total", e)
    end
end

route("/api/revenue/denied", method=POST) do
    try
        payload = jsonpayload()
        result = RevenueController.handle_denied(payload)
        json(result)
    catch e
        _safe_error("Denied claims analysis", e)
    end
end

route("/api/revenue/payor-mix", method=POST) do
    try
        payload = jsonpayload()
        result = RevenueController.handle_payor_mix(payload)
        json(result)
    catch e
        _safe_error("Payer mix analysis", e)
    end
end

route("/api/revenue/provider-payment", method=POST) do
    try
        payload = jsonpayload()
        result = RevenueController.handle_provider_payment(payload)
        json(result)
    catch e
        _safe_error("Provider payment analysis", e)
    end
end

route("/api/revenue/simulate", method=POST) do
    try
        payload = jsonpayload()
        result = RevenueController.handle_simulate(payload)
        json(result)
    catch e
        _safe_error("Revenue simulation", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Profitability & Operations (E9, delegated to ProfitabilityController)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/profitability/contrib-margin", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_contrib_margin(payload)
        json(result)
    catch e
        _safe_error("Contribution margin", e)
    end
end

route("/api/profitability/by-dept", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_by_dept(payload)
        json(result)
    catch e
        _safe_error("Departmental profitability", e)
    end
end

route("/api/profitability/fixed-variable", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_fixed_variable(payload)
        json(result)
    catch e
        _safe_error("Fixed-variable decomposition", e)
    end
end

route("/api/profitability/break-even", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_break_even(payload)
        json(result)
    catch e
        _safe_error("Break-even analysis", e)
    end
end

route("/api/profitability/operating-margin", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_operating_margin(payload)
        json(result)
    catch e
        _safe_error("Operating margin", e)
    end
end

route("/api/profitability/margin-decomp", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_margin_decomp(payload)
        json(result)
    catch e
        _safe_error("Margin decomposition", e)
    end
end

route("/api/profitability/ratios", method=POST) do
    try
        payload = jsonpayload()
        result = ProfitabilityController.handle_ratios(payload)
        json(result)
    catch e
        _safe_error("Profitability ratios", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Quality & Clinical Outcomes (E10)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/quality/readmission", method=POST) do
    try
        payload = jsonpayload()
        result = QualityController.handle_readmission(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Quality readmission", e)
    end
end

route("/api/quality/mortality", method=POST) do
    try
        payload = jsonpayload()
        result = QualityController.handle_mortality(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Quality mortality", e)
    end
end

route("/api/quality/infection", method=POST) do
    try
        payload = jsonpayload()
        result = QualityController.handle_infection(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Quality infection", e)
    end
end

route("/api/quality/psi", method=POST) do
    try
        payload = jsonpayload()
        result = QualityController.handle_psi(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Quality PSI", e)
    end
end

route("/api/quality/qol", method=POST) do
    try
        payload = jsonpayload()
        result = QualityController.handle_qol(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Quality QoL", e)
    end
end

route("/api/quality/disparities", method=POST) do
    try
        payload = jsonpayload()
        result = QualityController.handle_disparities(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Quality disparities", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Statistics (E11)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/stats/descriptive", method=POST) do
    try; result = StatsController.handle_descriptive(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats descriptive", e); end
end

route("/api/stats/ttest", method=POST) do
    try; result = StatsController.handle_ttest(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats t-test", e); end
end

route("/api/stats/anova", method=POST) do
    try; result = StatsController.handle_anova(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats ANOVA", e); end
end

route("/api/stats/chisquare", method=POST) do
    try; result = StatsController.handle_chisquare(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats chi-square", e); end
end

route("/api/stats/logrank", method=POST) do
    try; result = StatsController.handle_logrank(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats log-rank", e); end
end

route("/api/stats/ci", method=POST) do
    try; result = StatsController.handle_ci(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats CI", e); end
end

route("/api/stats/table1", method=POST) do
    try; result = StatsController.handle_table1(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Stats Table1", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Regression (E12)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/regression/ols", method=POST) do
    try; result = RegressionController.handle_ols(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Regression OLS", e); end
end

route("/api/regression/logistic", method=POST) do
    try; result = RegressionController.handle_logistic(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Regression logistic", e); end
end

route("/api/regression/poisson", method=POST) do
    try; result = RegressionController.handle_poisson(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Regression Poisson", e); end
end

route("/api/regression/negbin", method=POST) do
    try; result = RegressionController.handle_negbin(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Regression NegBin", e); end
end

route("/api/regression/cox", method=POST) do
    try; result = RegressionController.handle_cox(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Regression Cox", e); end
end

route("/api/regression/diagnostics", method=POST) do
    try; result = RegressionController.handle_diagnostics(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Regression diagnostics", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Causal Inference (E13)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/causal/psm", method=POST) do
    try; result = CausalController.handle_psm(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Causal PSM", e); end
end

route("/api/causal/iv", method=POST) do
    try; result = CausalController.handle_iv(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Causal IV", e); end
end

route("/api/causal/did", method=POST) do
    try; result = CausalController.handle_did(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Causal DiD", e); end
end

route("/api/causal/rdd", method=POST) do
    try; result = CausalController.handle_rdd(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Causal RDD", e); end
end

route("/api/causal/hte", method=POST) do
    try; result = CausalController.handle_hte(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Causal HTE", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — CEA (E14)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/cea/icer", method=POST) do
    try; result = CEAController.handle_icer(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CEA ICER", e); end
end

route("/api/cea/ceac", method=POST) do
    try; result = CEAController.handle_ceac(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CEA CEAC", e); end
end

route("/api/cea/sensitivity", method=POST) do
    try; result = CEAController.handle_sensitivity(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CEA sensitivity", e); end
end

route("/api/cea/monte-carlo", method=POST) do
    try; result = CEAController.handle_monte_carlo(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CEA Monte Carlo", e); end
end

route("/api/cea/analyze", method=POST) do
    try; result = CEAController.handle_analyze(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CEA analyze", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — CBA (E15)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/cba/npv", method=POST) do
    try; result = CBAController.handle_npv(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CBA NPV", e); end
end

route("/api/cba/roi", method=POST) do
    try; result = CBAController.handle_roi(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CBA ROI", e); end
end

route("/api/cba/bcr", method=POST) do
    try; result = CBAController.handle_bcr(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CBA BCR", e); end
end

route("/api/cba/break-even", method=POST) do
    try; result = CBAController.handle_break_even(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CBA break-even", e); end
end

route("/api/cba/budget-impact", method=POST) do
    try; result = CBAController.handle_budget_impact(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("CBA budget impact", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Comparative Effectiveness (E16)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/comparative/outcomes", method=POST) do
    try; result = ComparativeController.handle_outcomes(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative outcomes", e); end
end

route("/api/comparative/patterns", method=POST) do
    try; result = ComparativeController.handle_patterns(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative patterns", e); end
end

route("/api/comparative/variation", method=POST) do
    try; result = ComparativeController.handle_variation(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative variation", e); end
end

route("/api/comparative/benchmark", method=POST) do
    try; result = ComparativeController.handle_benchmark(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative benchmark", e); end
end

route("/api/comparative/smr", method=POST) do
    try; result = ComparativeController.handle_smr(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative SMR", e); end
end

route("/api/comparative/subgroup", method=POST) do
    try; result = ComparativeController.handle_subgroup(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative subgroup", e); end
end

route("/api/comparative/interaction", method=POST) do
    try; result = ComparativeController.handle_interaction(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Comparative interaction", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Visualization (E17)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/visualize/render", method=POST) do
    try; result = VisualizeController.handle_render(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Visualize render", e); end
end

route("/api/visualize/export", method=POST) do
    try; result = VisualizeController.handle_export(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Visualize export", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Reports (E18)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/reports/generate", method=POST) do
    try; result = ReportsController.handle_generate(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Reports generate", e); end
end

route("/api/reports/export-pdf", method=POST) do
    try; result = ReportsController.handle_export_pdf(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Reports export PDF", e); end
end

route("/api/reports/export-xlsx", method=POST) do
    try; result = ReportsController.handle_export_xlsx(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Reports export XLSX", e); end
end

route("/api/reports/preview", method=POST) do
    try; result = ReportsController.handle_preview(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Reports preview", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Database (E19)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/database/query-patients", method=POST) do
    try; result = DatabaseController.handle_query_patients(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database query patients", e); end
end

route("/api/database/query-claims", method=POST) do
    try; result = DatabaseController.handle_query_claims(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database query claims", e); end
end

route("/api/database/query-encounters", method=POST) do
    try; result = DatabaseController.handle_query_encounters(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database query encounters", e); end
end

route("/api/database/query-financial", method=POST) do
    try; result = DatabaseController.handle_query_financial(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database query financial", e); end
end

route("/api/database/save-result", method=POST) do
    try; result = DatabaseController.handle_save_result(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database save result", e); end
end

route("/api/database/save-version", method=POST) do
    try; result = DatabaseController.handle_save_version(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database save version", e); end
end

route("/api/database/retrieve-archived", method=POST) do
    try; result = DatabaseController.handle_retrieve_archived(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Database retrieve archived", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — ML (E20)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/ml/train", method=POST) do
    try; result = MLController.handle_train(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("ML train", e); end
end

route("/api/ml/predict", method=POST) do
    try; result = MLController.handle_predict(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("ML predict", e); end
end

route("/api/ml/predict-batch", method=POST) do
    try; result = MLController.handle_predict_batch(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("ML predict batch", e); end
end

route("/api/ml/anomaly", method=POST) do
    try; result = MLController.handle_anomaly(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("ML anomaly", e); end
end

route("/api/ml/stratify", method=POST) do
    try; result = MLController.handle_stratify(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("ML stratify", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Systems (E21)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/systems/referral-network", method=POST) do
    try; result = SystemsController.handle_referral_network(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Systems referral network", e); end
end

route("/api/systems/care-gaps", method=POST) do
    try; result = SystemsController.handle_care_gaps(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Systems care gaps", e); end
end

route("/api/systems/team-composition", method=POST) do
    try; result = SystemsController.handle_team_composition(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Systems team composition", e); end
end

route("/api/systems/simulate-pathway", method=POST) do
    try; result = SystemsController.handle_simulate_pathway(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Systems simulate pathway", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Scenario Lab (E22)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/scenario/best-case", method=POST) do
    try; result = ScenarioLabController.handle_best_case(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Scenario best-case", e); end
end

route("/api/scenario/base-case", method=POST) do
    try; result = ScenarioLabController.handle_base_case(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Scenario base-case", e); end
end

route("/api/scenario/worst-case", method=POST) do
    try; result = ScenarioLabController.handle_worst_case(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Scenario worst-case", e); end
end

route("/api/scenario/one-way", method=POST) do
    try; result = ScenarioLabController.handle_one_way(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Scenario one-way", e); end
end

route("/api/scenario/two-way", method=POST) do
    try; result = ScenarioLabController.handle_two_way(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Scenario two-way", e); end
end

route("/api/scenario/psa", method=POST) do
    try; result = ScenarioLabController.handle_psa(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Scenario PSA", e); end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Function Explorer (E23)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/fn/:name", method=POST) do
    try
        payload = jsonpayload()
        result = FunctionController.handle_invoke(payload === nothing ? Dict() : payload)
        json(result)
    catch e
        _safe_error("Function invoke", e)
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# API Routes — Audit (E24)
# ═══════════════════════════════════════════════════════════════════════════

route("/api/audit/set-config", method=POST) do
    try; result = AuditController.handle_set_config(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Audit set config", e); end
end

route("/api/audit/log", method=POST) do
    try; result = AuditController.handle_log(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Audit log", e); end
end

route("/api/audit/generate-log", method=POST) do
    try; result = AuditController.handle_generate_log(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Audit generate log", e); end
end

route("/api/audit/deidentify", method=POST) do
    try; result = AuditController.handle_deidentify(jsonpayload() === nothing ? Dict() : jsonpayload()); json(result); catch e; _safe_error("Audit deidentify", e); end
end
