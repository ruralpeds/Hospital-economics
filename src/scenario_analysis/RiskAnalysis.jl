# ============================================================================
# RISK ANALYSIS (Module 7)
# ============================================================================
# Financial risk quantification for hospital contract portfolios.
# Provides Value-at-Risk (VaR), Conditional VaR, stress testing, and
# automatic contingency-plan generation for adverse scenarios.
# ============================================================================

using Statistics
using Distributions
using Random

# ============================================================================
# TYPES
# ============================================================================

"""
    RiskProfile

Quantified financial risk profile for a contract portfolio.

# Fields
- `portfolio_name::String`: descriptive label
- `expected_margin::Float64`: probability-weighted expected annual margin (USD)
- `margin_std_dev::Float64`: standard deviation of margin across scenarios
- `var_95::Float64`: Value-at-Risk at 95 % confidence (worst 5 % annual margin)
- `cvar_95::Float64`: Conditional VaR / Expected Shortfall at 95 % (mean of worst 5 %)
- `downside_probability::Float64`: probability that margin < 0
- `max_loss::Float64`: worst-case annual margin observed
- `best_case::Float64`: best-case annual margin observed
- `risk_rating::String`: qualitative rating ("Low", "Moderate", "High", "Critical")
- `scenario_margins::Dict{String,Float64}`: scenario id -> annual margin
"""
struct RiskProfile
    portfolio_name::String
    expected_margin::Float64
    margin_std_dev::Float64
    var_95::Float64
    cvar_95::Float64
    downside_probability::Float64
    max_loss::Float64
    best_case::Float64
    risk_rating::String
    scenario_margins::Dict{String,Float64}
end

function Base.show(io::IO, rp::RiskProfile)
    print(io, "RiskProfile(\"$(rp.portfolio_name)\", rating=$(rp.risk_rating), VaR95=\$$(round(rp.var_95, digits=0)))")
end

"""
    StressTestResult

Result of a single stress-test applied to a portfolio.

# Fields
- `stress_name::String`: label for the stress scenario
- `description::String`: narrative description
- `baseline_margin::Float64`: margin before stress
- `stressed_margin::Float64`: margin under stress
- `margin_impact::Float64`: change in margin (stressed - baseline)
- `margin_impact_pct::Float64`: percentage change relative to baseline
- `survives::Bool`: true if stressed margin remains > 0
- `severity::String`: "Mild", "Moderate", "Severe", or "Catastrophic"
"""
struct StressTestResult
    stress_name::String
    description::String
    baseline_margin::Float64
    stressed_margin::Float64
    margin_impact::Float64
    margin_impact_pct::Float64
    survives::Bool
    severity::String
end

function Base.show(io::IO, st::StressTestResult)
    pct = round(st.margin_impact_pct * 100; digits=1)
    print(io, "StressTestResult(\"$(st.stress_name)\", impact=$(pct)%, $(st.severity))")
end

"""
    ContingencyPlan

A recommended contingency action triggered by an identified risk.

# Fields
- `risk_trigger::String`: condition that activates this plan
- `trigger_threshold::Float64`: quantitative threshold (e.g., margin < -500_000)
- `recommended_actions::Vector{String}`: ordered list of actions
- `estimated_savings::Float64`: estimated annual savings from actions (USD)
- `implementation_timeline::String`: expected timeline (e.g., "30-60 days")
- `priority::String`: "Immediate", "Short-Term", "Medium-Term"
"""
struct ContingencyPlan
    risk_trigger::String
    trigger_threshold::Float64
    recommended_actions::Vector{String}
    estimated_savings::Float64
    implementation_timeline::String
    priority::String
end

function Base.show(io::IO, cp::ContingencyPlan)
    print(io, "ContingencyPlan(\"$(cp.risk_trigger)\", priority=$(cp.priority))")
end

# ============================================================================
# PORTFOLIO RISK ANALYSIS
# ============================================================================

"""
    analyze_portfolio_risk(
        portfolio::OptimizedContractPortfolio,
        scenarios::Vector{HealthcareScenario};
        n_simulations::Int = 5000,
        base_cost_per_case::Float64 = 12000.0,
        base_quality_score::Float64 = 0.80
    )::RiskProfile

Quantify the financial risk of an optimised contract portfolio by projecting
margins under each scenario and computing VaR / CVaR statistics.

If more than three scenarios are supplied, a Monte-Carlo simulation is run by
sampling scenarios according to their probabilities and adding noise to
produce a margin distribution.

# Arguments
- `portfolio`: the optimised portfolio to assess
- `scenarios`: set of healthcare scenarios
- `n_simulations`: Monte-Carlo iterations for tail-risk estimation
- `base_cost_per_case`: starting average cost per case
- `base_quality_score`: starting quality metric

# Returns
A `RiskProfile` summarising expected margin, VaR, CVaR, downside probability,
and a qualitative risk rating.
"""
function analyze_portfolio_risk(
    portfolio::OptimizedContractPortfolio,
    scenarios::Vector{HealthcareScenario};
    n_simulations::Int = 5000,
    base_cost_per_case::Float64 = 12000.0,
    base_quality_score::Float64 = 0.80
)::RiskProfile

    isempty(scenarios) && error("scenarios must not be empty")

    # ── Project each selected contract under each scenario ──────────────
    scenario_margins = Dict{String,Float64}()

    for scenario in scenarios
        total_margin = 0.0
        for (contract, vol) in zip(portfolio.selected_contracts, portfolio.volume_allocation)
            proj = project_contract_under_scenario(
                contract, scenario;
                base_volume = vol,
                base_cost_per_case = base_cost_per_case,
                base_quality_score = base_quality_score,
            )
            # Use average annual margin
            avg_margin = length(proj.annual_margin) > 0 ? mean(proj.annual_margin) : 0.0
            total_margin += avg_margin
        end
        scenario_margins[scenario.id] = total_margin
    end

    margins = collect(values(scenario_margins))
    probs = [s.probability for s in scenarios]
    prob_sum = sum(probs)
    w = prob_sum > 0.0 ? probs ./ prob_sum : fill(1.0 / length(scenarios), length(scenarios))

    expected = sum(margins[i] * w[i] for i in eachindex(margins))
    sigma = length(margins) > 1 ? std(margins) : 0.0

    # ── Monte-Carlo for tail statistics ─────────────────────────────────
    rng = MersenneTwister(42)
    mc_margins = Float64[]
    scenario_indices = 1:length(scenarios)

    for _ in 1:n_simulations
        # Sample a scenario index according to probabilities
        u = rand(rng)
        cumul = 0.0
        chosen = 1
        for (idx, pw) in enumerate(w)
            cumul += pw
            if u <= cumul
                chosen = idx
                break
            end
        end
        base_m = margins[chosen]
        # Add Gaussian noise proportional to sigma
        noise = sigma > 0.0 ? randn(rng) * sigma * 0.3 : 0.0
        push!(mc_margins, base_m + noise)
    end

    sort!(mc_margins)
    var_95_idx = max(1, Int(floor(0.05 * n_simulations)))
    var_95 = mc_margins[var_95_idx]
    cvar_95 = mean(mc_margins[1:var_95_idx])

    downside_prob = count(m -> m < 0.0, mc_margins) / n_simulations
    max_loss = minimum(mc_margins)
    best_case = maximum(mc_margins)

    # ── Risk rating ─────────────────────────────────────────────────────
    risk_rating = if downside_prob < 0.05 && var_95 > 0
        "Low"
    elseif downside_prob < 0.15
        "Moderate"
    elseif downside_prob < 0.35
        "High"
    else
        "Critical"
    end

    portfolio_name = join([_contract_name(c) for c in portfolio.selected_contracts], " + ")

    return RiskProfile(
        portfolio_name,
        expected,
        sigma,
        var_95,
        cvar_95,
        downside_prob,
        max_loss,
        best_case,
        risk_rating,
        scenario_margins,
    )
end

# ============================================================================
# STRESS TESTING
# ============================================================================

"""
    stress_test_portfolio(
        portfolio::OptimizedContractPortfolio,
        base_scenario::HealthcareScenario;
        base_cost_per_case::Float64 = 12000.0,
        base_quality_score::Float64 = 0.80
    )::Vector{StressTestResult}

Apply a battery of pre-defined stress tests to the portfolio and report the
impact on margin.

Built-in stresses:
1. **Volume shock** -- 15 % drop in patient volume
2. **Cost surge** -- cost inflation doubles
3. **Reimbursement cut** -- reimbursement growth cut to zero
4. **Quality degradation** -- quality score drops 10 points
5. **Combined adverse** -- simultaneous volume drop, cost surge, and reimbursement cut
"""
function stress_test_portfolio(
    portfolio::OptimizedContractPortfolio,
    base_scenario::HealthcareScenario;
    base_cost_per_case::Float64 = 12000.0,
    base_quality_score::Float64 = 0.80
)::Vector{StressTestResult}

    # ── Baseline margin ─────────────────────────────────────────────────
    baseline_margin = _portfolio_margin(portfolio, base_scenario, base_cost_per_case, base_quality_score)

    # ── Define stresses ─────────────────────────────────────────────────
    stresses = [
        (
            "Volume Shock",
            "15% sudden drop in patient volume",
            HealthcareScenario(
                id="stress_volume", name="Volume Shock", description="",
                probability=1.0,
                volume_growth_rate = base_scenario.volume_growth_rate - 0.15,
                cost_inflation_rate = base_scenario.cost_inflation_rate,
                reimbursement_change_rate = base_scenario.reimbursement_change_rate,
                quality_score_adjustment = base_scenario.quality_score_adjustment,
                payer_mix_shift = base_scenario.payer_mix_shift,
                policy_impact = base_scenario.policy_impact,
                projection_years = base_scenario.projection_years,
                discount_rate = base_scenario.discount_rate,
            )
        ),
        (
            "Cost Surge",
            "Cost inflation doubles from baseline",
            HealthcareScenario(
                id="stress_cost", name="Cost Surge", description="",
                probability=1.0,
                volume_growth_rate = base_scenario.volume_growth_rate,
                cost_inflation_rate = base_scenario.cost_inflation_rate * 2.0,
                reimbursement_change_rate = base_scenario.reimbursement_change_rate,
                quality_score_adjustment = base_scenario.quality_score_adjustment,
                payer_mix_shift = base_scenario.payer_mix_shift,
                policy_impact = base_scenario.policy_impact,
                projection_years = base_scenario.projection_years,
                discount_rate = base_scenario.discount_rate,
            )
        ),
        (
            "Reimbursement Cut",
            "Reimbursement growth drops to zero",
            HealthcareScenario(
                id="stress_reimb", name="Reimbursement Cut", description="",
                probability=1.0,
                volume_growth_rate = base_scenario.volume_growth_rate,
                cost_inflation_rate = base_scenario.cost_inflation_rate,
                reimbursement_change_rate = 0.0,
                quality_score_adjustment = base_scenario.quality_score_adjustment,
                payer_mix_shift = base_scenario.payer_mix_shift,
                policy_impact = base_scenario.policy_impact,
                projection_years = base_scenario.projection_years,
                discount_rate = base_scenario.discount_rate,
            )
        ),
        (
            "Quality Degradation",
            "Quality score drops by 0.10 (10 points)",
            HealthcareScenario(
                id="stress_quality", name="Quality Degradation", description="",
                probability=1.0,
                volume_growth_rate = base_scenario.volume_growth_rate,
                cost_inflation_rate = base_scenario.cost_inflation_rate,
                reimbursement_change_rate = base_scenario.reimbursement_change_rate,
                quality_score_adjustment = base_scenario.quality_score_adjustment - 0.10,
                payer_mix_shift = base_scenario.payer_mix_shift,
                policy_impact = base_scenario.policy_impact,
                projection_years = base_scenario.projection_years,
                discount_rate = base_scenario.discount_rate,
            )
        ),
        (
            "Combined Adverse",
            "Simultaneous volume drop (-10%), cost surge (+50% inflation), and reimbursement freeze",
            HealthcareScenario(
                id="stress_combined", name="Combined Adverse", description="",
                probability=1.0,
                volume_growth_rate = base_scenario.volume_growth_rate - 0.10,
                cost_inflation_rate = base_scenario.cost_inflation_rate * 1.5,
                reimbursement_change_rate = 0.0,
                quality_score_adjustment = base_scenario.quality_score_adjustment - 0.05,
                payer_mix_shift = base_scenario.payer_mix_shift,
                policy_impact = base_scenario.policy_impact - 100_000.0,
                projection_years = base_scenario.projection_years,
                discount_rate = base_scenario.discount_rate,
            )
        ),
    ]

    results = StressTestResult[]

    for (sname, sdesc, stressed_scenario) in stresses
        stressed_margin = _portfolio_margin(portfolio, stressed_scenario, base_cost_per_case, base_quality_score)
        impact = stressed_margin - baseline_margin
        impact_pct = baseline_margin != 0.0 ? impact / abs(baseline_margin) : 0.0
        survives = stressed_margin > 0.0

        severity = if abs(impact_pct) < 0.10
            "Mild"
        elseif abs(impact_pct) < 0.25
            "Moderate"
        elseif abs(impact_pct) < 0.50
            "Severe"
        else
            "Catastrophic"
        end

        push!(results, StressTestResult(
            sname, sdesc,
            baseline_margin, stressed_margin,
            impact, impact_pct,
            survives, severity,
        ))
    end

    return results
end

# ── Internal helper: compute portfolio margin under a scenario ────────────

function _portfolio_margin(
    portfolio::OptimizedContractPortfolio,
    scenario::HealthcareScenario,
    base_cost_per_case::Float64,
    base_quality_score::Float64
)::Float64
    total_margin = 0.0
    for (contract, vol) in zip(portfolio.selected_contracts, portfolio.volume_allocation)
        proj = project_contract_under_scenario(
            contract, scenario;
            base_volume = vol,
            base_cost_per_case = base_cost_per_case,
            base_quality_score = base_quality_score,
        )
        total_margin += length(proj.annual_margin) > 0 ? mean(proj.annual_margin) : 0.0
    end
    return total_margin
end

# ============================================================================
# CONTINGENCY PLAN GENERATION
# ============================================================================

"""
    generate_contingency_plans(
        risk_profile::RiskProfile,
        stress_results::Vector{StressTestResult}
    )::Vector{ContingencyPlan}

Automatically generate contingency plans based on the identified risk profile
and stress-test outcomes.  Plans are prioritised from most to least urgent.

Contingency plans address:
- Revenue shortfalls (volume or reimbursement driven)
- Cost overruns (inflation or supply-chain driven)
- Quality failures (penalty exposure)
- Liquidity crises (combined adverse scenarios)

# Arguments
- `risk_profile`: output of `analyze_portfolio_risk`
- `stress_results`: output of `stress_test_portfolio`

# Returns
A prioritised vector of `ContingencyPlan` structs.
"""
function generate_contingency_plans(
    risk_profile::RiskProfile,
    stress_results::Vector{StressTestResult}
)::Vector{ContingencyPlan}

    plans = ContingencyPlan[]

    # ── 1. Overall downside risk ────────────────────────────────────────
    if risk_profile.downside_probability > 0.10
        push!(plans, ContingencyPlan(
            "Operating margin falls below zero",
            0.0,
            [
                "Activate cost-reduction task force targeting 5-8% operating expense reduction",
                "Defer non-essential capital expenditures for 6 months",
                "Renegotiate supply contracts with top-5 vendors",
                "Evaluate temporary staffing reductions via attrition holds",
            ],
            risk_profile.expected_margin * 0.05,
            "30-60 days",
            "Immediate",
        ))
    end

    # ── 2. Volume-related stress ────────────────────────────────────────
    vol_stress = findfirst(r -> r.stress_name == "Volume Shock", stress_results)
    if vol_stress !== nothing
        st = stress_results[vol_stress]
        if !st.survives || st.severity in ("Severe", "Catastrophic")
            push!(plans, ContingencyPlan(
                "Patient volume drops >15% from baseline",
                st.stressed_margin,
                [
                    "Launch targeted community outreach and physician referral campaigns",
                    "Expand telehealth and outpatient service lines to capture ambulatory volume",
                    "Partner with neighbouring health systems for patient transfer agreements",
                    "Adjust staffing models to flex capacity (PRN pool expansion)",
                ],
                abs(st.margin_impact) * 0.30,
                "60-90 days",
                "Short-Term",
            ))
        end
    end

    # ── 3. Cost surge ───────────────────────────────────────────────────
    cost_stress = findfirst(r -> r.stress_name == "Cost Surge", stress_results)
    if cost_stress !== nothing
        st = stress_results[cost_stress]
        if st.severity in ("Moderate", "Severe", "Catastrophic")
            push!(plans, ContingencyPlan(
                "Cost inflation exceeds reimbursement growth by >3 percentage points",
                st.stressed_margin,
                [
                    "Activate GPO renegotiation for pharmaceutical and supply contracts",
                    "Implement energy and facilities cost-reduction programme",
                    "Accelerate revenue-cycle improvements to reduce A/R days",
                    "Review and consolidate vendor contracts across service lines",
                ],
                abs(st.margin_impact) * 0.25,
                "30-90 days",
                "Short-Term",
            ))
        end
    end

    # ── 4. Quality / penalty exposure ───────────────────────────────────
    qual_stress = findfirst(r -> r.stress_name == "Quality Degradation", stress_results)
    if qual_stress !== nothing
        st = stress_results[qual_stress]
        if abs(st.margin_impact_pct) > 0.05
            push!(plans, ContingencyPlan(
                "Quality scores decline triggering payer penalties",
                st.stressed_margin,
                [
                    "Intensify clinical quality improvement initiatives (sepsis bundle, fall prevention)",
                    "Deploy real-time quality dashboards for nursing and physician leaders",
                    "Engage patient experience consultants for HCAHPS improvement",
                    "Increase care-coordination staffing to reduce preventable readmissions",
                ],
                abs(st.margin_impact) * 0.40,
                "60-120 days",
                "Medium-Term",
            ))
        end
    end

    # ── 5. Combined / catastrophic ──────────────────────────────────────
    comb_stress = findfirst(r -> r.stress_name == "Combined Adverse", stress_results)
    if comb_stress !== nothing
        st = stress_results[comb_stress]
        if st.severity in ("Severe", "Catastrophic")
            push!(plans, ContingencyPlan(
                "Multiple adverse conditions materialise simultaneously",
                st.stressed_margin,
                [
                    "Convene emergency financial oversight committee with board participation",
                    "Engage financial advisor for liquidity and debt restructuring assessment",
                    "Explore strategic partnership, affiliation, or merger options",
                    "Apply for emergency government relief programmes if available",
                    "Implement across-the-board 10% discretionary spending freeze",
                ],
                abs(st.margin_impact) * 0.20,
                "Immediate - 30 days",
                "Immediate",
            ))
        end
    end

    # ── 6. Diversification weakness ─────────────────────────────────────
    if risk_profile.margin_std_dev > 0 && (risk_profile.margin_std_dev / abs(risk_profile.expected_margin)) > 0.30
        push!(plans, ContingencyPlan(
            "Portfolio concentration risk exceeds 30% coefficient of variation",
            risk_profile.expected_margin,
            [
                "Diversify payer mix by pursuing additional commercial contracts",
                "Add value-based or shared-savings arrangements to reduce FFS dependence",
                "Explore capitation or bundled-payment pilots for high-volume service lines",
            ],
            risk_profile.margin_std_dev * 0.15,
            "90-180 days",
            "Medium-Term",
        ))
    end

    # Sort by priority: Immediate first, then Short-Term, then Medium-Term
    priority_order = Dict("Immediate" => 1, "Short-Term" => 2, "Medium-Term" => 3)
    sort!(plans; by = p -> get(priority_order, p.priority, 4))

    return plans
end
