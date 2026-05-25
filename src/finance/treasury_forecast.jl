# 13-Week Cash Flow Forecast — Treasury Management
#
# Projects weekly cash positions for a 13-week horizon, incorporating
# operating receipts, disbursements, capital items, debt service, and
# line-of-credit (LOC) draws. Includes Medicare delay stress testing.

"""
    WeeklyProfile

Cash flow profile for a single week.
"""
@kwdef struct WeeklyProfile
    week::Int
    operating_receipts::Float64
    operating_disbursements::Float64
    capital_items::Float64 = 0.0
    debt_service::Float64 = 0.0
end

"""
    TreasuryInput

Input parameters for 13-week cash forecast.

Fields:
- `starting_cash` — beginning cash balance
- `weekly_profiles` — vector of 13 WeeklyProfile entries
- `loc_capacity` — total line-of-credit capacity
- `loc_rate` — annualized LOC interest rate
- `min_cash_threshold` — minimum cash balance before LOC draw
- `medicare_delay_weeks` — weeks to shift Medicare receipts for stress test (default 0)
- `medicare_pct_of_receipts` — fraction of operating receipts from Medicare (default 0.45)
"""
@kwdef struct TreasuryInput
    starting_cash::Float64
    weekly_profiles::Vector{WeeklyProfile}
    loc_capacity::Float64 = 0.0
    loc_rate::Float64 = 0.0
    min_cash_threshold::Float64 = 0.0
    medicare_delay_weeks::Int = 0
    medicare_pct_of_receipts::Float64 = 0.45
end

"""
    WeeklyBalance

Computed cash position for a single week.
"""
@kwdef struct WeeklyBalance
    week::Int
    beginning_cash::Float64
    net_cash_flow::Float64
    loc_draw::Float64
    loc_repayment::Float64
    ending_cash::Float64
end

"""
    TreasuryResult

Result of the 13-week cash forecast.

Fields:
- `weekly_balances` — per-week cash positions
- `loc_draws` — total LOC draws over the period
- `loc_balance` — ending LOC balance outstanding
- `interest_cost` — total LOC interest expense
- `nadir_week` — week with lowest ending cash
- `nadir_amount` — lowest ending cash amount
- `medicare_stress_impact` — change in nadir from Medicare delay stress (0 if no stress test)
"""
@kwdef struct TreasuryResult
    weekly_balances::Vector{WeeklyBalance}
    loc_draws::Float64
    loc_balance::Float64
    interest_cost::Float64
    nadir_week::Int
    nadir_amount::Float64
    medicare_stress_impact::Float64
end

function Base.show(io::IO, r::TreasuryResult)
    print(io, "TreasuryResult($(length(r.weekly_balances)) weeks, nadir=\$$(round(Int, r.nadir_amount)) @ wk$(r.nadir_week))")
end

"""
    forecast_treasury(input::TreasuryInput) -> TreasuryResult

Generate a 13-week cash forecast with optional LOC draws and Medicare delay stress.

Algorithm:
1. For each week, compute net cash flow = receipts - disbursements - capital - debt service
2. If ending cash < min_cash_threshold, draw on LOC (up to capacity)
3. If ending cash > min_cash_threshold + loc outstanding, repay LOC
4. Track nadir (lowest ending cash)
5. If medicare_delay_weeks > 0, shift Medicare portion of receipts and recompute
"""
function forecast_treasury(input::TreasuryInput)::TreasuryResult
    !isempty(input.weekly_profiles) || error("weekly_profiles must not be empty")
    input.starting_cash >= 0.0 || error("starting_cash must be non-negative")
    input.loc_capacity >= 0.0 || error("loc_capacity must be non-negative")

    # Apply Medicare delay stress if requested
    profiles = if input.medicare_delay_weeks > 0
        _apply_medicare_delay(input.weekly_profiles, input.medicare_delay_weeks,
                              input.medicare_pct_of_receipts)
    else
        input.weekly_profiles
    end

    weekly_balances = WeeklyBalance[]
    cash = input.starting_cash
    loc_outstanding = 0.0
    total_draws = 0.0
    total_interest = 0.0
    weekly_rate = input.loc_rate / 52.0

    nadir_week = 1
    nadir_amount = cash

    for profile in profiles
        beginning_cash = cash

        net_cf = profile.operating_receipts -
                 profile.operating_disbursements -
                 profile.capital_items -
                 profile.debt_service

        # LOC interest on outstanding balance
        interest = loc_outstanding * weekly_rate
        total_interest += interest
        net_cf -= interest

        ending_cash = beginning_cash + net_cf
        draw = 0.0
        repayment = 0.0

        # Draw on LOC if below threshold
        if ending_cash < input.min_cash_threshold
            shortfall = input.min_cash_threshold - ending_cash
            available = input.loc_capacity - loc_outstanding
            draw = min(shortfall, available)
            loc_outstanding += draw
            total_draws += draw
            ending_cash += draw
        end

        # Repay LOC if excess cash available
        if ending_cash > input.min_cash_threshold && loc_outstanding > 0.0
            excess = ending_cash - input.min_cash_threshold
            repayment = min(excess, loc_outstanding)
            loc_outstanding -= repayment
            ending_cash -= repayment
        end

        cash = ending_cash

        # Track nadir
        if ending_cash < nadir_amount
            nadir_amount = ending_cash
            nadir_week = profile.week
        end

        push!(weekly_balances, WeeklyBalance(
            week = profile.week,
            beginning_cash = beginning_cash,
            net_cash_flow = net_cf,
            loc_draw = draw,
            loc_repayment = repayment,
            ending_cash = ending_cash,
        ))
    end

    # Medicare stress impact: compare nadir with and without delay
    stress_impact = 0.0
    if input.medicare_delay_weeks > 0
        baseline_input = TreasuryInput(
            starting_cash = input.starting_cash,
            weekly_profiles = input.weekly_profiles,
            loc_capacity = input.loc_capacity,
            loc_rate = input.loc_rate,
            min_cash_threshold = input.min_cash_threshold,
            medicare_delay_weeks = 0,
            medicare_pct_of_receipts = input.medicare_pct_of_receipts,
        )
        baseline = forecast_treasury(baseline_input)
        stress_impact = nadir_amount - baseline.nadir_amount
    end

    return TreasuryResult(
        weekly_balances = weekly_balances,
        loc_draws = total_draws,
        loc_balance = loc_outstanding,
        interest_cost = total_interest,
        nadir_week = nadir_week,
        nadir_amount = nadir_amount,
        medicare_stress_impact = stress_impact,
    )
end

"""Shift Medicare receipts by `delay_weeks` to simulate payment delays."""
function _apply_medicare_delay(profiles::Vector{WeeklyProfile}, delay_weeks::Int,
                               medicare_pct::Float64)::Vector{WeeklyProfile}
    n = length(profiles)
    result = WeeklyProfile[]

    for (i, p) in enumerate(profiles)
        medicare_receipts = p.operating_receipts * medicare_pct
        non_medicare = p.operating_receipts - medicare_receipts

        # Medicare receipts from `delay_weeks` earlier (if available)
        source_idx = i - delay_weeks
        delayed_medicare = if source_idx >= 1
            profiles[source_idx].operating_receipts * medicare_pct
        else
            0.0  # Medicare receipts not yet received
        end

        adjusted_receipts = non_medicare + delayed_medicare

        push!(result, WeeklyProfile(
            week = p.week,
            operating_receipts = adjusted_receipts,
            operating_disbursements = p.operating_disbursements,
            capital_items = p.capital_items,
            debt_service = p.debt_service,
        ))
    end
    return result
end
