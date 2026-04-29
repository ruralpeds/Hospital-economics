"""
    treasury.jl — Hospital Treasury & Liquidity Stress Testing (MBA Gap A-09)

Provides the short-term liquidity analytics that CFOs and rating agencies
use to assess near-term financial risk:

1. **13-Week Cash Flow Forecast** — rolling weekly AR/collections/payroll/AP model.
2. **Medicare Payment Delay Stress** — impact of 30/60/90-day CMS payment delays
   (common in government shutdown, sequestration, or audit scenarios).
3. **Line-of-Credit Headroom** — available LOC capacity under various scenarios.
4. **Minimum Cash Buffer Analysis** — how many weeks until a cash crisis under stress.

All monetary values in USD. All periods in weeks unless noted.

References:
- HFMA Cash Management Best Practices (2024)
- CMS Medicare Timely Payment Rules (42 CFR § 424.44)
- Moody's Hospital Liquidity Stress Framework (2023)
"""

using Dates
using Statistics
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# 13-Week Cash Flow Forecast
# ─────────────────────────────────────────────────────────────────────────────

"""
    WeeklyOperatingProfile

Stable-state weekly cash flow parameters. All amounts in USD/week.

# Fields
- `weekly_net_collections::Float64`: Average net cash collections (Medicare + Medicaid + Commercial + Self-pay).
- `weekly_payroll::Float64`: Payroll disbursements (bi-weekly payroll → allocate to both weeks).
- `weekly_supplies_ap::Float64`: Supply chain and AP disbursements.
- `weekly_other_disbursements::Float64`: Utilities, maintenance, other recurring.
- `medicare_pct_of_collections::Float64`: Medicare share of total collections [0,1].
- `medicaid_pct_of_collections::Float64`: Medicaid share [0,1].
- `commercial_pct_of_collections::Float64`: Commercial + self-pay share [0,1].
- `medicare_payment_lag_weeks::Int`: Typical Medicare payment lag (default 2).
- `ar_days_outstanding::Float64`: Current DSO in days.
"""
@kwdef struct WeeklyOperatingProfile
    weekly_net_collections::Float64
    weekly_payroll::Float64
    weekly_supplies_ap::Float64
    weekly_other_disbursements::Float64   = 0.0
    medicare_pct_of_collections::Float64  = 0.45
    medicaid_pct_of_collections::Float64  = 0.25
    commercial_pct_of_collections::Float64 = 0.30
    medicare_payment_lag_weeks::Int        = 2
    ar_days_outstanding::Float64           = 45.0
end

"""
    WeeklyForecastRow

A single week's cash flow forecast.

# Fields
- `week::Int`: Week number (1-13).
- `opening_cash::Float64`
- `medicare_collections::Float64`
- `medicaid_collections::Float64`
- `commercial_collections::Float64`
- `total_collections::Float64`
- `payroll_disbursement::Float64`
- `supplies_ap_disbursement::Float64`
- `other_disbursements::Float64`
- `total_disbursements::Float64`
- `net_cash_flow::Float64`
- `closing_cash::Float64`
- `loc_draw::Float64`: LOC draw required to maintain minimum cash (0 if sufficient).
- `loc_balance::Float64`: Cumulative LOC balance after this week.
"""
struct WeeklyForecastRow
    week::Int
    opening_cash::Float64
    medicare_collections::Float64
    medicaid_collections::Float64
    commercial_collections::Float64
    total_collections::Float64
    payroll_disbursement::Float64
    supplies_ap_disbursement::Float64
    other_disbursements::Float64
    total_disbursements::Float64
    net_cash_flow::Float64
    closing_cash::Float64
    loc_draw::Float64
    loc_balance::Float64
end

"""
    ThirteenWeekForecast

Complete 13-week rolling cash flow forecast.

# Fields
- `weeks::Vector{WeeklyForecastRow}`
- `opening_cash_balance::Float64`
- `closing_cash_balance::Float64`
- `minimum_cash_week::Int`: Week with lowest closing cash.
- `minimum_cash_balance::Float64`
- `total_loc_drawn::Float64`: Total LOC draws over 13 weeks.
- `loc_availability_maintained::Bool`: `true` if LOC never exceeded capacity.
- `weeks_to_cash_crisis::Union{Int, Nothing}`: First week closing cash < `min_cash_threshold`; `nothing` if never.
"""
struct ThirteenWeekForecast
    weeks::Vector{WeeklyForecastRow}
    opening_cash_balance::Float64
    closing_cash_balance::Float64
    minimum_cash_week::Int
    minimum_cash_balance::Float64
    total_loc_drawn::Float64
    loc_availability_maintained::Bool
    weeks_to_cash_crisis::Union{Int, Nothing}
end

"""
    thirteen_week_forecast(
        profile, opening_cash;
        loc_capacity, min_cash_threshold,
        payroll_weeks, shock
    ) -> ThirteenWeekForecast

Build a 13-week rolling cash flow forecast.

# Arguments
- `profile::WeeklyOperatingProfile`: Stable-state weekly operating parameters.
- `opening_cash::Float64`: Cash + investments balance at week 0.
- `loc_capacity::Float64 = 0.0`: Maximum line-of-credit available.
- `min_cash_threshold::Float64 = 0.0`: Minimum operating cash (trigger for LOC draw).
- `payroll_weeks::Vector{Int} = [1,3,5,7,9,11,13]`: Weeks with payroll disbursement (bi-weekly).
- `shock::Union{Nothing, Function} = nothing`: Optional weekly cash-flow shock function
  `(week::Int, row::WeeklyForecastRow) -> Float64` — extra positive or negative cash flow.
"""
function thirteen_week_forecast(
    profile::WeeklyOperatingProfile,
    opening_cash::Float64;
    loc_capacity::Float64 = 0.0,
    min_cash_threshold::Float64 = 0.0,
    payroll_weeks::Vector{Int} = collect(1:2:13),
    shock = nothing,
)::ThirteenWeekForecast

    rows       = WeeklyForecastRow[]
    cash       = opening_cash
    loc_bal    = 0.0
    crisis_week = nothing

    for wk in 1:13
        open_cash = cash

        # Collections by payer
        mc = profile.weekly_net_collections * profile.medicare_pct_of_collections
        md = profile.weekly_net_collections * profile.medicaid_pct_of_collections
        cm = profile.weekly_net_collections * profile.commercial_pct_of_collections
        total_coll = mc + md + cm

        # Disbursements
        payroll_disb = wk in payroll_weeks ? profile.weekly_payroll : 0.0
        ap_disb      = profile.weekly_supplies_ap
        other_disb   = profile.weekly_other_disbursements
        total_disb   = payroll_disb + ap_disb + other_disb

        # Shock injection
        shock_cf = isnothing(shock) ? 0.0 : Float64(shock(wk,
            WeeklyForecastRow(wk, open_cash, mc, md, cm, total_coll,
                              payroll_disb, ap_disb, other_disb, total_disb,
                              total_coll-total_disb, open_cash+total_coll-total_disb, 0.0, loc_bal)))

        net_cf   = total_coll - total_disb + shock_cf
        close_before_loc = open_cash + net_cf

        # LOC draw to maintain minimum
        loc_draw = 0.0
        if close_before_loc < min_cash_threshold && loc_capacity > 0
            needed   = min_cash_threshold - close_before_loc
            available = loc_capacity - loc_bal
            loc_draw  = min(needed, available)
        end
        loc_bal += loc_draw
        close_cash = close_before_loc + loc_draw

        if close_cash < min_cash_threshold && isnothing(crisis_week)
            crisis_week = wk
        end

        push!(rows, WeeklyForecastRow(
            wk, open_cash, mc, md, cm, total_coll,
            payroll_disb, ap_disb, other_disb, total_disb,
            net_cf, close_cash, loc_draw, loc_bal,
        ))
        cash = close_cash
    end

    min_idx  = argmin([r.closing_cash for r in rows])
    loc_ok   = loc_bal <= loc_capacity + 1e-6

    ThirteenWeekForecast(
        rows,
        opening_cash,
        cash,
        min_idx,
        rows[min_idx].closing_cash,
        loc_bal,
        loc_ok,
        crisis_week,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Medicare Payment Delay Stress Test
# ─────────────────────────────────────────────────────────────────────────────

"""
    MedicareDelayScenario

A Medicare payment delay stress scenario.

# Fields
- `delay_weeks::Int`: Number of weeks Medicare payments are delayed (typical: 4, 8, or 13).
- `label::String`: Scenario label.
- `probability::Float64`: Subjective scenario probability [0,1] (for expected-value weighting).
"""
@kwdef struct MedicareDelayScenario
    delay_weeks::Int
    label::String = ""
    probability::Float64 = 1.0 / 3
end

"""
    MedicareDelayStressResult

Result of a Medicare payment delay stress scenario.

# Fields
- `scenario::MedicareDelayScenario`
- `baseline_forecast::ThirteenWeekForecast`: Unshocked 13-week forecast.
- `stressed_forecast::ThirteenWeekForecast`: Forecast with Medicare payment delay.
- `medicare_revenue_deferred::Float64`: Total Medicare collections withheld.
- `incremental_loc_required::Float64`: Additional LOC drawn vs baseline.
- `min_cash_stressed::Float64`
- `weeks_to_crisis::Union{Int,Nothing}`
- `survivable::Bool`: `true` if LOC + cash covers the gap.
"""
struct MedicareDelayStressResult
    scenario::MedicareDelayScenario
    baseline_forecast::ThirteenWeekForecast
    stressed_forecast::ThirteenWeekForecast
    medicare_revenue_deferred::Float64
    incremental_loc_required::Float64
    min_cash_stressed::Float64
    weeks_to_crisis::Union{Int, Nothing}
    survivable::Bool
end

"""
    medicare_delay_stress(
        profile, opening_cash, scenario;
        loc_capacity, min_cash_threshold, payroll_weeks
    ) -> MedicareDelayStressResult

Stress-test a hospital's 13-week cash position under a Medicare payment delay.

Simulates the delay by zeroing out Medicare collections for `scenario.delay_weeks`
weeks, then receiving a catch-up lump sum in the subsequent week (if within the
13-week window). This models CMS payment suspension during a government shutdown,
sequestration pause, or MAC audit hold.

# Example
```julia
profile = WeeklyOperatingProfile(
    weekly_net_collections = 800_000,
    weekly_payroll         = 350_000,
    weekly_supplies_ap     = 180_000,
)
scenario = MedicareDelayScenario(delay_weeks=8, label="90-day CMS hold")
result = medicare_delay_stress(profile, 3_500_000, scenario; loc_capacity=5_000_000)
result.survivable   # can the hospital make it through?
```
"""
function medicare_delay_stress(
    profile::WeeklyOperatingProfile,
    opening_cash::Float64,
    scenario::MedicareDelayScenario;
    loc_capacity::Float64 = 0.0,
    min_cash_threshold::Float64 = 0.0,
    payroll_weeks::Vector{Int} = collect(1:2:13),
)::MedicareDelayStressResult

    weekly_mc = profile.weekly_net_collections * profile.medicare_pct_of_collections
    deferred  = Float64(min(scenario.delay_weeks, 13)) * weekly_mc

    # Build shock: zero Medicare for delay_weeks, then catch-up
    function mc_shock(wk::Int, _)::Float64
        if wk <= scenario.delay_weeks
            return -weekly_mc          # remove Medicare collections this week
        elseif wk == scenario.delay_weeks + 1
            return deferred            # catch-up lump sum
        else
            return 0.0
        end
    end

    baseline = thirteen_week_forecast(profile, opening_cash;
        loc_capacity = loc_capacity, min_cash_threshold = min_cash_threshold,
        payroll_weeks = payroll_weeks)

    stressed = thirteen_week_forecast(profile, opening_cash;
        loc_capacity = loc_capacity, min_cash_threshold = min_cash_threshold,
        payroll_weeks = payroll_weeks, shock = mc_shock)

    incr_loc = stressed.total_loc_drawn - baseline.total_loc_drawn
    survivable = stressed.loc_availability_maintained && isnothing(stressed.weeks_to_cash_crisis)

    MedicareDelayStressResult(
        scenario, baseline, stressed,
        deferred, incr_loc, stressed.minimum_cash_balance,
        stressed.weeks_to_cash_crisis, survivable,
    )
end

"""
    run_medicare_delay_scenarios(
        profile, opening_cash;
        delay_weeks_list, loc_capacity, min_cash_threshold
    ) -> Vector{MedicareDelayStressResult}

Run multiple Medicare delay scenarios and return results sorted by severity
(longest delay first). Convenience wrapper for `medicare_delay_stress`.

Default scenarios: 4-week (government shutdown), 8-week (sequestration), 13-week (MAC audit hold).
"""
function run_medicare_delay_scenarios(
    profile::WeeklyOperatingProfile,
    opening_cash::Float64;
    delay_weeks_list::Vector{Int} = [4, 8, 13],
    loc_capacity::Float64 = 0.0,
    min_cash_threshold::Float64 = 0.0,
    payroll_weeks::Vector{Int} = collect(1:2:13),
)::Vector{MedicareDelayStressResult}

    labels = Dict(4 => "4-week (shutdown)", 8 => "8-week (sequestration)", 13 => "13-week (MAC hold)")
    probs  = Dict(4 => 0.40, 8 => 0.35, 13 => 0.25)

    results = MedicareDelayStressResult[]
    for dw in sort(delay_weeks_list; rev=true)
        sc = MedicareDelayScenario(
            delay_weeks = dw,
            label       = get(labels, dw, "$(dw)-week delay"),
            probability = get(probs, dw, 1.0 / length(delay_weeks_list)),
        )
        push!(results, medicare_delay_stress(profile, opening_cash, sc;
            loc_capacity = loc_capacity,
            min_cash_threshold = min_cash_threshold,
            payroll_weeks = payroll_weeks,
        ))
    end
    results
end

# ─────────────────────────────────────────────────────────────────────────────
# Line-of-Credit Headroom Analysis
# ─────────────────────────────────────────────────────────────────────────────

"""
    LOCHeadroomInputs

Inputs for line-of-credit headroom analysis.

# Fields
- `loc_commitment::Float64`: Total committed LOC facility size.
- `loc_outstanding::Float64`: Amount currently drawn.
- `loc_maturity_date::Date`: Facility expiration.
- `loc_interest_rate::Float64`: Current interest rate on drawn balance (decimal).
- `covenant_loc_floor::Union{Nothing,Float64}`: Minimum undrawn balance required
  by covenant (e.g. some indentures require LOC ≥ X months of MADS).
- `annual_facility_fee::Float64`: Unused commitment fee (annual, on undrawn balance).
"""
@kwdef struct LOCHeadroomInputs
    loc_commitment::Float64
    loc_outstanding::Float64              = 0.0
    loc_maturity_date::Date               = today() + Year(1)
    loc_interest_rate::Float64            = 0.065
    covenant_loc_floor::Union{Nothing,Float64} = nothing
    annual_facility_fee::Float64          = 0.005
end

"""
    LOCHeadroomResult

Line-of-credit headroom analysis result.

# Fields
- `gross_availability::Float64`: `loc_commitment − loc_outstanding`.
- `net_availability::Float64`: After deducting covenant floor.
- `days_to_maturity::Int`
- `annualized_cost_of_drawn_balance::Float64`
- `annualized_unused_fee::Float64`
- `months_of_operating_expenses_covered::Float64`: Net availability / (monthly opex).
- `renewal_risk::Symbol`: `:low` (>180 days), `:medium` (90–180), `:high` (<90).
"""
struct LOCHeadroomResult
    gross_availability::Float64
    net_availability::Float64
    days_to_maturity::Int
    annualized_cost_of_drawn_balance::Float64
    annualized_unused_fee::Float64
    months_of_operating_expenses_covered::Float64
    renewal_risk::Symbol
end

"""
    loc_headroom(inputs::LOCHeadroomInputs; monthly_operating_expenses=0.0) -> LOCHeadroomResult

Compute line-of-credit availability and renewal risk.
"""
function loc_headroom(
    inputs::LOCHeadroomInputs;
    monthly_operating_expenses::Float64 = 0.0,
)::LOCHeadroomResult

    gross = inputs.loc_commitment - inputs.loc_outstanding
    floor = isnothing(inputs.covenant_loc_floor) ? 0.0 : inputs.covenant_loc_floor
    net   = max(gross - floor, 0.0)
    days  = Dates.value(inputs.loc_maturity_date - today())
    renewal_risk = days > 180 ? :low : days > 90 ? :medium : :high

    cost_drawn = inputs.loc_outstanding * inputs.loc_interest_rate
    unused_fee = gross * inputs.annual_facility_fee

    months_covered = monthly_operating_expenses > 0 ?
        net / monthly_operating_expenses : NaN

    LOCHeadroomResult(gross, net, days, cost_drawn, unused_fee, months_covered, renewal_risk)
end

# ─────────────────────────────────────────────────────────────────────────────
# Integrated liquidity dashboard
# ─────────────────────────────────────────────────────────────────────────────

"""
    LiquidityDashboard

Combined short-term liquidity summary.

# Fields
- `baseline_13wk::ThirteenWeekForecast`
- `stress_scenarios::Vector{MedicareDelayStressResult}`
- `loc::LOCHeadroomResult`
- `days_cash_on_hand_opening::Float64`
- `worst_case_weeks_to_crisis::Union{Int,Nothing}`: Across all stress scenarios.
- `expected_survivability::Float64`: Probability-weighted survivability across scenarios [0,1].
- `liquidity_rating::Symbol`: `:adequate`, `:watch`, or `:critical`.
"""
struct LiquidityDashboard
    baseline_13wk::ThirteenWeekForecast
    stress_scenarios::Vector{MedicareDelayStressResult}
    loc::LOCHeadroomResult
    days_cash_on_hand_opening::Float64
    worst_case_weeks_to_crisis::Union{Int, Nothing}
    expected_survivability::Float64
    liquidity_rating::Symbol
end

"""
    liquidity_dashboard(
        profile, opening_cash, loc_inputs;
        monthly_opex, min_cash_threshold, payroll_weeks
    ) -> LiquidityDashboard

Build a complete hospital liquidity dashboard combining the 13-week baseline,
standard Medicare delay stress scenarios, and LOC headroom.
"""
function liquidity_dashboard(
    profile::WeeklyOperatingProfile,
    opening_cash::Float64,
    loc_inputs::LOCHeadroomInputs;
    monthly_opex::Float64 = 0.0,
    min_cash_threshold::Float64 = 0.0,
    payroll_weeks::Vector{Int} = collect(1:2:13),
)::LiquidityDashboard

    baseline = thirteen_week_forecast(profile, opening_cash;
        loc_capacity = loc_inputs.loc_commitment,
        min_cash_threshold = min_cash_threshold,
        payroll_weeks = payroll_weeks)

    stress_results = run_medicare_delay_scenarios(profile, opening_cash;
        loc_capacity = loc_inputs.loc_commitment,
        min_cash_threshold = min_cash_threshold,
        payroll_weeks = payroll_weeks)

    loc_result = loc_headroom(loc_inputs; monthly_operating_expenses = monthly_opex)

    # DCOH at open
    annual_opex = monthly_opex * 12
    dcoh = annual_opex > 0 ? opening_cash / (annual_opex / 365) : NaN

    # Worst-case crisis week
    crisis_weeks = [r.weeks_to_crisis for r in stress_results if !isnothing(r.weeks_to_crisis)]
    worst_crisis = isempty(crisis_weeks) ? nothing : minimum(crisis_weeks)

    # Expected survivability
    total_prob = sum(r.scenario.probability for r in stress_results)
    surv = total_prob > 0 ?
        sum(r.scenario.probability * (r.survivable ? 1.0 : 0.0) for r in stress_results) / total_prob :
        1.0

    # Rating
    rating = if surv >= 0.85 && dcoh >= 55
        :adequate
    elseif surv >= 0.60 || dcoh >= 30
        :watch
    else
        :critical
    end

    LiquidityDashboard(baseline, stress_results, loc_result, dcoh,
                       worst_crisis, surv, rating)
end
