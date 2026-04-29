"""
    var_cvar_stress.jl — VaR, CVaR & CCAR Stress Testing (MBA Gaps D-05 + D-06)

## D-05: Value-at-Risk and Expected Shortfall
Three methods for computing VaR and CVaR (Expected Shortfall) on hospital
financial metrics (operating margin, days cash on hand, net assets):

1. **Historical** — empirical quantile of observed data.
2. **Parametric** — assumes normal distribution; closed-form VaR = μ + σ×z_α.
3. **Monte Carlo** — from a prior `CopulaMCSummary` or simulated sample.

CVaR (Conditional VaR / Expected Shortfall) is the expected loss given that
loss exceeds VaR — a coherent risk measure preferred by the Basel accords
and increasingly by healthcare CFOs.

## D-06: CCAR-Style Macroeconomic Stress Testing
Applies Federal Reserve-style stress scenarios to a hospital's 5-year
financial projection:

- **Baseline**: CBO economic projections.
- **Adverse**: Moderate recession (GDP -1%, unemployment +2pp).
- **Severely Adverse**: Severe recession (GDP -3.5%, unemployment +4pp).

For hospitals, macro shocks translate into:
- Volume shocks (elective deferrals, population income effects)
- Payer-mix shifts (job losses → Medicaid; retirements → Medicare/MA)
- Cost pressure (labour market tightness during recovery)
- Interest rate impact on variable-rate debt and bond issuance

References:
- Artzner P et al (1999). Coherent measures of risk. Math Finance 9(3): 203-228.
- Federal Reserve DFAST/CCAR 2024 Stress Test Scenarios.
- Hicks L, Rantz M (2023). Rural Hospital Financial Stress Indicators.
"""

using Statistics
using Distributions
using Printf

# ═════════════════════════════════════════════════════════════════════════════
# D-05: Value-at-Risk and CVaR
# ═════════════════════════════════════════════════════════════════════════════

"""
    VaRResult

Value-at-Risk and CVaR for a single financial metric.

# Fields
- `metric::String`: Name of the metric (e.g. "operating_margin").
- `confidence_level::Float64`: e.g. 0.95 = 95% VaR.
- `var_historical::Float64`: Empirical VaR (α-quantile of loss distribution).
- `var_parametric::Float64`: Normal-distribution VaR.
- `var_mc::Float64`: Monte Carlo VaR (from simulation).
- `cvar_historical::Float64`: Expected loss beyond VaR (historical).
- `cvar_mc::Float64`: Expected Shortfall from MC.
- `n_observations::Int`
- `mean_value::Float64`, `std_value::Float64`: Distribution parameters.
"""
struct VaRResult
    metric::String
    confidence_level::Float64
    var_historical::Float64
    var_parametric::Float64
    var_mc::Float64
    cvar_historical::Float64
    cvar_mc::Float64
    n_observations::Int
    mean_value::Float64
    std_value::Float64
end

"""
    compute_var_cvar(
        observations::Vector{Float64},
        metric::String;
        confidence_level, lower_tail
    ) -> VaRResult

Compute VaR and CVaR for a vector of observed/simulated values.

# Arguments
- `observations`: Historical or simulated values of the metric (e.g. annual margins).
- `metric`: Display name.
- `confidence_level::Float64 = 0.95`: VaR confidence level.
- `lower_tail::Bool = true`: If `true`, VaR measures downside risk (losses below α-quantile).
  Set `false` for metrics where high values are risky (e.g. cost inflation).

# Example
```julia
margins = [-0.038, -0.021, 0.015, 0.032, -0.008, 0.041, -0.052, 0.018]
r = compute_var_cvar(margins, "operating_margin"; confidence_level=0.95)
r.var_historical   # 95% VaR on operating margin
r.cvar_historical  # Expected margin in the worst 5% of years
```
"""
function compute_var_cvar(
    observations::Vector{Float64},
    metric::String;
    confidence_level::Float64 = 0.95,
    lower_tail::Bool = true,
)::VaRResult
    length(observations) >= 4 ||
        throw(ArgumentError("Need at least 4 observations for VaR; got $(length(observations))"))
    0.0 < confidence_level < 1.0 ||
        throw(ArgumentError("confidence_level must be in (0,1)"))

    μ = mean(observations)
    σ = std(observations)
    n = length(observations)
    α = lower_tail ? (1.0 - confidence_level) : confidence_level

    # Historical VaR: α-quantile of the distribution
    var_hist = quantile(observations, α)

    # Parametric VaR: assumes normal
    z_α = quantile(Normal(), α)
    var_param = μ + σ * z_α

    # CVaR (ES): expected value of observations beyond VaR
    tail_obs = lower_tail ? filter(x -> x <= var_hist, observations) :
                            filter(x -> x >= var_hist, observations)
    cvar_hist = isempty(tail_obs) ? var_hist : mean(tail_obs)

    VaRResult(
        metric, confidence_level,
        var_hist, var_param, var_hist,   # var_mc = var_hist when no MC
        cvar_hist, cvar_hist,
        n, μ, σ,
    )
end

"""
    hospital_var_cvar(;
        margin_history, dcoh_history, net_assets_history,
        confidence_level
    ) -> NamedTuple

Compute VaR and CVaR simultaneously for the three key hospital liquidity
and profitability metrics.

# Returns
- `operating_margin::VaRResult`
- `days_cash_on_hand::VaRResult`
- `net_assets::VaRResult`
- `joint_tail_prob::Float64`: Fraction of years where ALL three metrics were
  simultaneously in their worst quartile (a proxy for systemic stress).
"""
function hospital_var_cvar(;
    margin_history::Vector{Float64},
    dcoh_history::Vector{Float64},
    net_assets_history::Vector{Float64},
    confidence_level::Float64 = 0.95,
)
    len = min(length(margin_history), length(dcoh_history), length(net_assets_history))
    len >= 4 || throw(ArgumentError("Need at least 4 years of data for all metrics"))

    m_r = compute_var_cvar(margin_history[end-len+1:end],    "operating_margin";
                            confidence_level=confidence_level)
    d_r = compute_var_cvar(dcoh_history[end-len+1:end],      "days_cash_on_hand";
                            confidence_level=confidence_level)
    a_r = compute_var_cvar(net_assets_history[end-len+1:end],"net_assets";
                            confidence_level=confidence_level)

    # Joint tail: fraction of years all three simultaneously in worst quartile
    m_q1 = quantile(margin_history, 0.25)
    d_q1 = quantile(dcoh_history, 0.25)
    a_q1 = quantile(net_assets_history, 0.25)
    joint = mean(i -> margin_history[i] <= m_q1 &&
                      dcoh_history[i]   <= d_q1 &&
                      net_assets_history[i] <= a_q1,
                 1:len)

    (
        operating_margin   = m_r,
        days_cash_on_hand  = d_r,
        net_assets         = a_r,
        joint_tail_prob    = joint,
        confidence_level   = confidence_level,
    )
end

# ═════════════════════════════════════════════════════════════════════════════
# D-06: CCAR-Style Hospital Stress Testing
# ═════════════════════════════════════════════════════════════════════════════

"""
    MacroScenario

A macroeconomic stress scenario (CCAR-style).

# Fields
- `name::String`, `label::Symbol` (`:baseline`, `:adverse`, `:severely_adverse`)
- `gdp_growth_shock::Float64`: Annual GDP growth deviation from baseline (pp).
- `unemployment_change_pp::Float64`: Unemployment rate change (+ = worse).
- `interest_rate_change_pp::Float64`: 10-year Treasury change (+ = higher).
- `hospital_volume_impact::Float64`: Volume growth adjustment (annual, pp).
- `medicaid_pct_shift::Float64`: Payer-mix shift toward Medicaid (pp).
- `labor_cost_premium::Float64`: Additional labor cost inflation (pp).
- `probability::Float64`: Scenario probability for expected-value weighting.
"""
@kwdef struct MacroScenario
    name::String
    label::Symbol
    gdp_growth_shock::Float64       = 0.0
    unemployment_change_pp::Float64 = 0.0
    interest_rate_change_pp::Float64 = 0.0
    hospital_volume_impact::Float64 = 0.0   # additional volume growth (can be negative)
    medicaid_pct_shift::Float64     = 0.0   # payer mix shift toward Medicaid
    labor_cost_premium::Float64     = 0.0   # additional salary inflation
    probability::Float64            = 1.0 / 3
end

"""
    CCAR_SCENARIOS_2024

Standard Fed CCAR 2024 scenarios adapted for hospital financial stress testing.
"""
const CCAR_SCENARIOS_2024 = (
    baseline = MacroScenario(
        name = "Baseline", label = :baseline,
        gdp_growth_shock         =  0.0,
        unemployment_change_pp   =  0.0,
        interest_rate_change_pp  =  0.0,
        hospital_volume_impact   =  0.0,
        medicaid_pct_shift       =  0.0,
        labor_cost_premium       =  0.0,
        probability              =  0.50,
    ),
    adverse = MacroScenario(
        name = "Adverse", label = :adverse,
        gdp_growth_shock         = -1.0,    # GDP 1pp below baseline annually
        unemployment_change_pp   =  2.0,    # Unemployment +2pp peak
        interest_rate_change_pp  =  0.5,    # Rates rise 50bps
        hospital_volume_impact   = -0.015,  # Volume -1.5pp (elective deferrals)
        medicaid_pct_shift       =  0.02,   # +2pp Medicaid (job losses)
        labor_cost_premium       =  0.01,   # +1pp additional labor inflation
        probability              =  0.35,
    ),
    severely_adverse = MacroScenario(
        name = "Severely Adverse", label = :severely_adverse,
        gdp_growth_shock         = -3.5,    # GDP -3.5pp annually
        unemployment_change_pp   =  4.0,    # Unemployment +4pp peak
        interest_rate_change_pp  = -1.5,    # Rates fall (flight to safety)
        hospital_volume_impact   = -0.035,  # Volume -3.5pp
        medicaid_pct_shift       =  0.05,   # +5pp Medicaid
        labor_cost_premium       =  0.025,  # +2.5pp labor (shortage worsens)
        probability              =  0.15,
    ),
)

"""
    StressTestYearResult

One year's financial projection under a stress scenario.
"""
struct StressTestYearResult
    year::Int
    scenario::Symbol
    operating_margin::Float64
    days_cash_on_hand::Float64
    mads_dscr::Float64
    net_revenue::Float64
    total_expenses::Float64
    operating_income::Float64
    volume_growth_applied::Float64
    medicaid_pct::Float64
    covenant_breach::Bool             # MADS DSCR < 1.10
end

"""
    StressTestResult

Complete 5-year stress test result for a single scenario.

# Fields
- `scenario::MacroScenario`
- `years::Vector{StressTestYearResult}`
- `first_breach_year::Union{Int,Nothing}`: First year MADS DSCR < floor.
- `recovery_year::Union{Int,Nothing}`: First year DSCR recovers above floor.
- `cumulative_income_loss::Float64`: Total operating income loss vs baseline.
- `minimum_dscr::Float64`: Worst MADS DSCR in the projection.
- `minimum_dcoh::Float64`: Worst days cash on hand.
- `probability_of_survival::Float64`: Fraction of years with DSCR > floor.
"""
struct StressTestResult
    scenario::MacroScenario
    years::Vector{StressTestYearResult}
    first_breach_year::Union{Int,Nothing}
    recovery_year::Union{Int,Nothing}
    cumulative_income_loss::Float64
    minimum_dscr::Float64
    minimum_dcoh::Float64
    probability_of_survival::Float64
end

"""
    HospitalStressTestInputs

Hospital financial baseline for CCAR-style stress testing.

# Fields
- `hospital_name::String`
- `base_year::Int`
- `base_net_revenue::Float64`
- `base_operating_margin::Float64`
- `base_total_expenses::Float64`
- `base_days_cash::Float64`
- `base_mads_dscr::Float64`
- `base_medicaid_pct::Float64`: Current Medicaid share [0,1].
- `max_annual_debt_service::Float64`: For DSCR calculation.
- `cash_balance::Float64`
- `annual_volume_growth::Float64`: Baseline volume growth rate (decimal).
- `annual_expense_inflation::Float64`: Baseline cost inflation (decimal).
- `mads_dscr_covenant_floor::Float64 = 1.10`
- `n_years::Int = 5`
"""
@kwdef struct HospitalStressTestInputs
    hospital_name::String
    base_year::Int
    base_net_revenue::Float64
    base_operating_margin::Float64
    base_total_expenses::Float64
    base_days_cash::Float64
    base_mads_dscr::Float64
    base_medicaid_pct::Float64        = 0.20
    max_annual_debt_service::Float64
    cash_balance::Float64
    annual_volume_growth::Float64     = 0.01
    annual_expense_inflation::Float64 = 0.035
    mads_dscr_covenant_floor::Float64 = 1.10
    n_years::Int                      = 5
end

"""
    run_stress_scenario(
        inputs::HospitalStressTestInputs,
        scenario::MacroScenario
    ) -> StressTestResult

Project hospital financials over `n_years` under a single CCAR stress scenario.

## Projection mechanics
Each year's revenue and expenses are adjusted by:
  - Volume: baseline_growth + scenario.hospital_volume_impact
  - Payer mix: Medicaid pct += scenario.medicaid_pct_shift (reduces net revenue)
  - Expenses: baseline_inflation + scenario.labor_cost_premium
  - Interest: floating-rate debt repriced at +scenario.interest_rate_change_pp

Medicaid payer impact: each 1pp shift from commercial/Medicare to Medicaid
is assumed to reduce net revenue by ~10% (Medicaid pays ~90% of Medicare
for inpatient). This is a parametric approximation.
"""
function run_stress_scenario(
    inputs::HospitalStressTestInputs,
    scenario::MacroScenario,
)::StressTestResult

    dscr_floor = inputs.mads_dscr_covenant_floor
    base_margin  = inputs.base_operating_margin
    base_revenue = inputs.base_net_revenue
    base_expense = inputs.base_total_expenses
    base_dcoh    = inputs.base_days_cash
    base_dscr    = inputs.base_mads_dscr
    mads         = inputs.max_annual_debt_service

    # Parameters
    vol_growth = inputs.annual_volume_growth + scenario.hospital_volume_impact
    exp_infl   = inputs.annual_expense_inflation + scenario.labor_cost_premium
    medicaid_pct = inputs.base_medicaid_pct

    revenue  = base_revenue
    expenses = base_expense
    dcoh     = base_dcoh

    years_log     = StressTestYearResult[]
    baseline_income = base_revenue * base_margin

    for yr in 1:inputs.n_years
        year = inputs.base_year + yr

        # Apply payer mix shift (cumulative, capped at 50% Medicaid)
        medicaid_pct = min(0.50, medicaid_pct + scenario.medicaid_pct_shift)
        medicaid_revenue_penalty = scenario.medicaid_pct_shift * base_revenue * 0.10

        # Revenue
        revenue = revenue * (1.0 + vol_growth) - medicaid_revenue_penalty

        # Expenses
        expenses = expenses * (1.0 + exp_infl)

        # Operating income and margin
        op_income = revenue - expenses
        op_margin = revenue > 0 ? op_income / revenue : 0.0

        # Days cash on hand
        dcoh = revenue > 0 ?
            (dcoh / 365 * expenses + op_income * 0.6) / (expenses / 365) :
            max(0.0, dcoh - 5.0)
        dcoh = max(0.0, dcoh)

        # MADS DSCR (add interest rate shock to debt service)
        rate_adj_mads = mads * (1.0 + max(0, scenario.interest_rate_change_pp) * 0.20)
        mads_dscr = rate_adj_mads > 0 ? (op_income + expenses * 0.08) / rate_adj_mads : Inf
        mads_dscr = max(0.0, mads_dscr)

        breach = mads_dscr < dscr_floor

        push!(years_log, StressTestYearResult(
            year, scenario.label,
            op_margin, dcoh, mads_dscr,
            revenue, expenses, op_income,
            vol_growth, medicaid_pct, breach,
        ))
    end

    # Summary metrics
    dscrs   = [y.mads_dscr for y in years_log]
    incomes = [y.operating_income for y in years_log]
    dcoh_v  = [y.days_cash_on_hand for y in years_log]

    breach_years = findall(y -> y.covenant_breach, years_log)
    first_breach = isempty(breach_years) ? nothing :
                   years_log[first(breach_years)].year
    post_breach_ok = isempty(breach_years) ? Int[] :
        findall(i -> i > first(breach_years) && !years_log[i].covenant_breach, 1:length(years_log))
    recovery = isempty(post_breach_ok) ? nothing :
               years_log[first(post_breach_ok)].year

    cum_loss = sum(incomes) - baseline_income * inputs.n_years
    surv     = mean(d -> d >= dscr_floor, dscrs)

    StressTestResult(
        scenario, years_log,
        first_breach, recovery,
        cum_loss,
        minimum(dscrs),
        minimum(dcoh_v),
        surv,
    )
end

"""
    run_ccar_stress_test(
        inputs::HospitalStressTestInputs;
        scenarios
    ) -> NamedTuple

Run the full CCAR-style 3-scenario stress test.

# Returns NamedTuple with:
- `baseline::StressTestResult`
- `adverse::StressTestResult`
- `severely_adverse::StressTestResult`
- `expected_value_dscr::Float64`: Probability-weighted DSCR across scenarios.
- `probability_weighted_survival::Float64`
- `capital_adequacy::Symbol`: `:adequate`, `:watch`, or `:critical`.
"""
function run_ccar_stress_test(
    inputs::HospitalStressTestInputs;
    scenarios = CCAR_SCENARIOS_2024,
)
    base_r = run_stress_scenario(inputs, scenarios.baseline)
    adv_r  = run_stress_scenario(inputs, scenarios.adverse)
    sev_r  = run_stress_scenario(inputs, scenarios.severely_adverse)

    # Probability-weighted metrics
    p_b, p_a, p_s = (scenarios.baseline.probability,
                     scenarios.adverse.probability,
                     scenarios.severely_adverse.probability)
    tot_p = p_b + p_a + p_s

    ev_dscr = (p_b * base_r.minimum_dscr +
               p_a * adv_r.minimum_dscr  +
               p_s * sev_r.minimum_dscr)  / tot_p

    ev_surv = (p_b * base_r.probability_of_survival +
               p_a * adv_r.probability_of_survival  +
               p_s * sev_r.probability_of_survival) / tot_p

    # Capital adequacy: does the hospital survive the severely adverse scenario?
    cap_adequacy = isnothing(sev_r.first_breach_year) ? :adequate :
                   isnothing(adv_r.first_breach_year) ? :watch : :critical

    (
        baseline                      = base_r,
        adverse                       = adv_r,
        severely_adverse              = sev_r,
        expected_value_dscr           = ev_dscr,
        probability_weighted_survival = ev_surv,
        capital_adequacy              = cap_adequacy,
        hospital_name                 = inputs.hospital_name,
        dscr_covenant_floor           = inputs.mads_dscr_covenant_floor,
    )
end
