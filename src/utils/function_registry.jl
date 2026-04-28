"""
FunctionRegistry — central catalog of all simulator functions (E23).
"""
module FunctionRegistry

const REGISTRY = Dict{Symbol, NamedTuple{(:fn_name, :section, :tab_url, :description, :inputs), Tuple{String, String, String, String, Vector{NamedTuple}}}}()

function register!(name::Symbol; fn_name::String, section::String, tab_url::String, description::String="", inputs::Vector=NamedTuple[])
    REGISTRY[name] = (fn_name=fn_name, section=section, tab_url=tab_url, description=description, inputs=inputs)
end

function all_entries()
    [Dict("name"=>string(k), "fn_name"=>v.fn_name, "section"=>v.section, "tab_url"=>v.tab_url, "description"=>v.description) for (k,v) in REGISTRY]
end

function get_entry(name::Symbol)
    haskey(REGISTRY, name) ? REGISTRY[name] : nothing
end

# ─── Quality & Clinical ────────────────────────────────────────────────────
register!(:readmission_rate;  fn_name="handle_readmission",  section="Quality", tab_url="/quality", description="30/90-day readmission rate by cohort")
register!(:mortality_rate;    fn_name="handle_mortality",    section="Quality", tab_url="/quality", description="Inpatient and 30-day post-discharge mortality")
register!(:infection_rate;    fn_name="handle_infection",    section="Quality", tab_url="/quality", description="HAI rates: CLABSI, CAUTI, SSI, C. diff")
register!(:psi_composite;     fn_name="handle_psi",          section="Quality", tab_url="/quality", description="AHRQ Patient Safety Indicator composite")
register!(:qol_score;         fn_name="handle_qol",          section="Quality", tab_url="/quality", description="Quality-of-life score (EQ-5D, SF-36, PROMIS)")
register!(:outcome_disparities; fn_name="handle_disparities", section="Quality", tab_url="/quality", description="Outcome disparities by race, income, geography")

# ─── Statistics ────────────────────────────────────────────────────────────
register!(:descriptive_stats; fn_name="handle_descriptive",  section="Statistics", tab_url="/stats", description="Mean, median, SD, IQR, skewness, kurtosis")
register!(:t_test;            fn_name="handle_ttest",        section="Statistics", tab_url="/stats", description="Independent and paired t-test with effect size")
register!(:anova;             fn_name="handle_anova",        section="Statistics", tab_url="/stats", description="One-way and two-way ANOVA with post-hoc tests")
register!(:chi_square;        fn_name="handle_chisquare",    section="Statistics", tab_url="/stats", description="Chi-square test of independence and goodness-of-fit")
register!(:log_rank;          fn_name="handle_logrank",      section="Statistics", tab_url="/stats", description="Log-rank test for survival curve comparison")
register!(:confidence_interval; fn_name="handle_ci",         section="Statistics", tab_url="/stats", description="Bootstrap and analytical confidence intervals")
register!(:table1;            fn_name="handle_table1",       section="Statistics", tab_url="/stats", description="Baseline characteristics Table 1 generator")

# ─── Regression ────────────────────────────────────────────────────────────
register!(:ols_regression;    fn_name="handle_ols",          section="Regression", tab_url="/regression", description="Ordinary least squares with robust SEs")
register!(:logistic_regression; fn_name="handle_logistic",  section="Regression", tab_url="/regression", description="Binary and multinomial logistic regression")
register!(:poisson_regression;  fn_name="handle_poisson",   section="Regression", tab_url="/regression", description="Poisson regression for count outcomes")
register!(:cox_regression;    fn_name="handle_cox",          section="Regression", tab_url="/regression", description="Cox proportional hazards survival model")
register!(:regression_diagnostics; fn_name="handle_diagnostics", section="Regression", tab_url="/regression", description="Residual plots, VIF, heteroskedasticity tests")

# ─── Causal Inference ──────────────────────────────────────────────────────
register!(:propensity_matching; fn_name="handle_psm",        section="Causal", tab_url="/causal", description="Propensity score matching with balance diagnostics")
register!(:iv_analysis;       fn_name="handle_iv",           section="Causal", tab_url="/causal", description="Instrumental variables two-stage least squares")
register!(:diff_in_diff;      fn_name="handle_did",          section="Causal", tab_url="/causal", description="Difference-in-differences with parallel trends test")
register!(:regression_discontinuity; fn_name="handle_rdd",  section="Causal", tab_url="/causal", description="Regression discontinuity design")
register!(:hte_analysis;      fn_name="handle_hte",          section="Causal", tab_url="/causal", description="Heterogeneous treatment effect estimation")

# ─── Economic Evaluation ───────────────────────────────────────────────────
register!(:icer;              fn_name="handle_icer",          section="CEA", tab_url="/cea", description="Incremental cost-effectiveness ratio")
register!(:ceac;              fn_name="handle_ceac",          section="CEA", tab_url="/cea", description="Cost-effectiveness acceptability curve")
register!(:npv;               fn_name="handle_npv",           section="CBA", tab_url="/cba", description="Net present value of intervention")
register!(:roi;               fn_name="handle_roi",           section="CBA", tab_url="/cba", description="Return on investment calculation")
register!(:budget_impact;     fn_name="handle_budget_impact", section="CBA", tab_url="/cba", description="5-year budget impact model")

# ─── Advanced ──────────────────────────────────────────────────────────────
register!(:ml_train;          fn_name="handle_train",         section="ML", tab_url="/ml", description="Train risk prediction model (GLM/RF/GBM)")
register!(:ml_predict;        fn_name="handle_predict",       section="ML", tab_url="/ml", description="Generate predictions from saved model")
register!(:anomaly_detection; fn_name="handle_anomaly",       section="ML", tab_url="/ml", description="Unsupervised anomaly detection in claims")
register!(:scenario_best;     fn_name="handle_best_case",     section="Scenarios", tab_url="/scenario-lab", description="Best-case scenario projection")
register!(:scenario_worst;    fn_name="handle_worst_case",    section="Scenarios", tab_url="/scenario-lab", description="Worst-case scenario projection")
register!(:psa;               fn_name="handle_psa",           section="Scenarios", tab_url="/scenario-lab", description="Probabilistic sensitivity analysis (Monte Carlo)")
register!(:deidentify;        fn_name="handle_deidentify",    section="Audit", tab_url="/audit", description="HIPAA de-identification of patient data")

end  # module FunctionRegistry
