# Monthly cash flow projection for Rural Hospital Economics Simulator
#
# Projects monthly cash inflows and outflows from annual financial data,
# incorporating seasonality, to identify cash shortfalls and line-of-credit
# requirements for rural hospitals.

"""
    MonthlyCashFlow

A single month's projected cash flow statement.

# Fields
- `month::Int`: month number (1-12 or beyond for multi-year projections)
- `beginning_cash::Float64`: cash balance at start of month
- `operating_receipts::Float64`: cash collected from operations
- `operating_disbursements::Float64`: cash paid for operating expenses
- `capital_expenditures::Float64`: cash spent on capital assets
- `debt_service::Float64`: principal and interest payments
- `net_cash_flow::Float64`: net change in cash for the month
- `ending_cash::Float64`: cash balance at end of month
- `days_cash_on_hand::Float64`: ending cash expressed in days of operating expenses
"""
@kwdef struct MonthlyCashFlow
    month::Int
    beginning_cash::Float64
    operating_receipts::Float64
    operating_disbursements::Float64
    capital_expenditures::Float64
    debt_service::Float64
    net_cash_flow::Float64
    ending_cash::Float64
    days_cash_on_hand::Float64
end

function Base.show(io::IO, cf::MonthlyCashFlow)
    print(io, "MonthlyCashFlow(month=$(cf.month), ending_cash=$(round(Int, cf.ending_cash)), days_cash=$(round(cf.days_cash_on_hand, digits=1)))")
end

"""
    project_monthly_cash_flow(base_financials::AnnualFinancials;
                              months::Int=12,
                              seasonality_factors::Vector{Float64}=ones(12),
                              capex_monthly::Float64=0.0,
                              beginning_cash::Union{Float64, Nothing}=nothing) -> Vector{MonthlyCashFlow}

Project monthly cash flows from annual financial data. Revenue and expenses
are distributed across months using the provided seasonality factors (which
are normalized internally so they sum to the number of months in a cycle).

# Arguments
- `base_financials`: annual financial data to annualize from
- `months`: number of months to project (default 12)
- `seasonality_factors`: 12-element vector of relative volume factors per month;
  `ones(12)` means uniform distribution. Factors cycle for projections beyond 12 months.
- `capex_monthly`: fixed monthly capital expenditure amount (default 0)
- `beginning_cash`: starting cash balance; defaults to `cash_and_equivalents` from financials
"""
function project_monthly_cash_flow(base_financials::AnnualFinancials;
                                    months::Int=12,
                                    seasonality_factors::Vector{Float64}=ones(12),
                                    capex_monthly::Float64=0.0,
                                    beginning_cash::Union{Float64, Nothing}=nothing)::Vector{MonthlyCashFlow}
    length(seasonality_factors) == 12 || error("seasonality_factors must have 12 elements")
    months > 0 || error("months must be positive; got $months")

    # Normalize seasonality factors so they sum to 12
    factor_sum = sum(seasonality_factors)
    norm_factors = seasonality_factors .* (12.0 / factor_sum)

    # Annual totals to distribute
    annual_revenue = base_financials.total_operating_revenue + base_financials.non_operating_revenue
    annual_cash_expenses = base_financials.total_operating_expenses -
                           base_financials.depreciation - base_financials.amortization
    annual_debt_service = base_financials.interest_expense +
                          (base_financials.long_term_debt > 0.0 ?
                           base_financials.long_term_debt / 20.0 : 0.0)  # Estimate principal from 20-yr amort

    # Daily operating expense for days-cash calculation
    daily_cash_expense = annual_cash_expenses / 365.0

    cash = isnothing(beginning_cash) ? base_financials.cash_and_equivalents : beginning_cash
    projections = MonthlyCashFlow[]

    for m in 1:months
        month_idx = mod1(m, 12)
        factor = norm_factors[month_idx] / 12.0  # fraction of annual total for this month

        receipts = annual_revenue * factor
        disbursements = annual_cash_expenses * factor
        debt_svc = annual_debt_service / 12.0
        capex = capex_monthly

        net = receipts - disbursements - capex - debt_svc
        ending = cash + net
        dcoh = daily_cash_expense > 0.0 ? ending / daily_cash_expense : Inf

        push!(projections, MonthlyCashFlow(
            month = m,
            beginning_cash = cash,
            operating_receipts = receipts,
            operating_disbursements = disbursements,
            capital_expenditures = capex,
            debt_service = debt_svc,
            net_cash_flow = net,
            ending_cash = ending,
            days_cash_on_hand = dcoh,
        ))

        cash = ending
    end

    return projections
end

"""
    find_cash_nadir(projections::Vector{MonthlyCashFlow}) -> NamedTuple

Find the month with the lowest ending cash balance in the projection.
Returns a NamedTuple with `month`, `amount`, and `days_cash`.
"""
function find_cash_nadir(projections::Vector{MonthlyCashFlow})
    isempty(projections) && error("No projections provided")

    min_idx = argmin([p.ending_cash for p in projections])
    nadir = projections[min_idx]

    return (month=nadir.month, amount=nadir.ending_cash, days_cash=nadir.days_cash_on_hand)
end

"""
    line_of_credit_needed(projections::Vector{MonthlyCashFlow};
                          min_days_cash::Float64=30.0) -> Float64

Calculate the line of credit needed to maintain a minimum days-cash-on-hand
threshold throughout the projection period. Returns 0.0 if the hospital
never falls below the threshold.

# Arguments
- `projections`: monthly cash flow projections
- `min_days_cash`: minimum acceptable days cash on hand (default 30)
"""
function line_of_credit_needed(projections::Vector{MonthlyCashFlow};
                                min_days_cash::Float64=30.0)::Float64
    isempty(projections) && return 0.0

    # Estimate daily expense from the first month's data
    first = projections[1]
    # Approximate daily expense: monthly disbursements * 12 / 365
    annual_disbursements = first.operating_disbursements * 12.0
    daily_expense = annual_disbursements / 365.0
    daily_expense <= 0.0 && return 0.0

    min_cash_required = min_days_cash * daily_expense
    max_shortfall = 0.0

    for p in projections
        shortfall = min_cash_required - p.ending_cash
        if shortfall > max_shortfall
            max_shortfall = shortfall
        end
    end

    return max_shortfall
end
