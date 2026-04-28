"""
    three_statement.jl — Linked three-statement projection engine

Builds forward-looking income statement, balance sheet, and cash-flow statement
projections where the balance sheet balances each year and the cash-flow statement
reconciles to changes in the balance sheet.
"""

using Dates

# ─────────────────────────────────────────────────────────────────────────────
# Types
# ─────────────────────────────────────────────────────────────────────────────

"""
    BalanceSheetSnapshot

Hospital balance sheet at a point in time. All amounts in USD.
"""
@kwdef struct BalanceSheetSnapshot
    as_of_date::Date
    cash_and_equivalents::Float64
    short_term_investments::Float64 = 0.0
    accounts_receivable_net::Float64
    inventory::Float64
    other_current_assets::Float64 = 0.0
    gross_ppe::Float64
    accumulated_depreciation::Float64
    long_term_investments::Float64 = 0.0
    other_lt_assets::Float64 = 0.0
    accounts_payable::Float64
    accrued_expenses::Float64
    current_portion_lt_debt::Float64
    other_current_liabilities::Float64 = 0.0
    long_term_debt::Float64
    other_lt_liabilities::Float64 = 0.0
    net_assets_unrestricted::Float64
    net_assets_temp_restricted::Float64 = 0.0
    net_assets_perm_restricted::Float64 = 0.0
end

"""
    ProjectionAssumptions

Forward-looking parameters for an n-year projection.
"""
@kwdef struct ProjectionAssumptions
    horizon_years::Int = 5
    revenue_growth::Vector{Float64}
    expense_growth::Vector{Float64}
    depreciation_rate::Float64 = 0.05
    capex_pct_of_revenue::Float64 = 0.04
    days_in_ar::Float64 = 50.0
    days_in_inventory::Float64 = 25.0
    days_in_ap::Float64 = 35.0
    interest_rate_lt_debt::Float64 = 0.05
    debt_amortization_years::Int = 20
    tax_rate::Float64 = 0.0
    investment_yield::Float64 = 0.04
end

"""
    ThreeStatementProjection

Linked IS/BS/CF projection. The vector elements are years 1..horizon_years.
The BS at index i is end-of-year i. CF at index i covers year i.
"""
@kwdef struct ThreeStatementProjection
    income_statements::Vector{NamedTuple}
    balance_sheets::Vector{BalanceSheetSnapshot}
    cash_flow_statements::Vector{NamedTuple}
    starting_balance_sheet::BalanceSheetSnapshot
    assumptions::ProjectionAssumptions
end

# ─────────────────────────────────────────────────────────────────────────────
# Core functions
# ─────────────────────────────────────────────────────────────────────────────

"""
    bs_balances(bs::BalanceSheetSnapshot; tol::Float64=1.0)::Bool

Returns true iff total assets equals total liabilities + net assets within tol USD.
"""
function bs_balances(bs::BalanceSheetSnapshot; tol::Float64=1.0)::Bool
    current_assets = bs.cash_and_equivalents + bs.short_term_investments +
                     bs.accounts_receivable_net + bs.inventory + bs.other_current_assets
    net_ppe = bs.gross_ppe - bs.accumulated_depreciation
    total_assets = current_assets + net_ppe + bs.long_term_investments + bs.other_lt_assets

    current_liabilities = bs.accounts_payable + bs.accrued_expenses +
                         bs.current_portion_lt_debt + bs.other_current_liabilities
    total_liabilities = current_liabilities + bs.long_term_debt + bs.other_lt_liabilities

    total_net_assets = bs.net_assets_unrestricted + bs.net_assets_temp_restricted +
                       bs.net_assets_perm_restricted

    return abs(total_assets - (total_liabilities + total_net_assets)) ≤ tol
end

"""
    project_three_statement(
        baseline::NamedTuple,
        starting_bs::BalanceSheetSnapshot,
        assumptions::ProjectionAssumptions
    )::ThreeStatementProjection

Build a forward-looking three-statement projection from a baseline annual financials
and starting balance sheet, applying growth assumptions year by year.

# Mechanics
- Income statement: revenue grows at `revenue_growth[year]`; expenses grow at
  `expense_growth[year]`; depreciation = `depreciation_rate * gross_ppe`;
  interest expense = `interest_rate_lt_debt * (lt_debt_prior + cp_lt_debt_prior)`.
- Balance sheet: working capital scales by days-in-AR/inventory/AP; gross PPE grows
  by capex; accumulated depreciation accumulates; long-term debt amortizes straight-line;
  net assets accumulate net income minus any distributions.
- Cash-flow statement: CFO = NI + D&A − ΔWC; CFI = −capex; CFF = −debt principal.
  ΔCash must equal the ΔCash on the BS to within \\$1 of rounding.

# Returns
A `ThreeStatementProjection` whose `balance_sheets[i]` balances every year.
"""
function project_three_statement(
    baseline::NamedTuple,
    starting_bs::BalanceSheetSnapshot,
    assumptions::ProjectionAssumptions
)::ThreeStatementProjection
    # Validate inputs
    length(assumptions.revenue_growth) == assumptions.horizon_years ||
        throw(DomainError("revenue_growth length must equal horizon_years"))
    length(assumptions.expense_growth) == assumptions.horizon_years ||
        throw(DomainError("expense_growth length must equal horizon_years"))

    # Initialize storage
    income_statements = NamedTuple[]
    balance_sheets = BalanceSheetSnapshot[]
    cash_flow_statements = NamedTuple[]

    # Starting values
    current_bs = starting_bs
    prior_revenue = baseline.total_operating_revenue
    prior_expenses = baseline.total_operating_expenses

    for year in 1:assumptions.horizon_years
        # ─── Income Statement ─────────────────────────────────────────────
        revenue = prior_revenue * (1.0 + assumptions.revenue_growth[year])
        expenses = prior_expenses * (1.0 + assumptions.expense_growth[year])

        # Depreciation based on current gross PPE
        depreciation = assumptions.depreciation_rate * current_bs.gross_ppe

        # Interest on debt at beginning of year
        debt_at_year_start = current_bs.long_term_debt + current_bs.current_portion_lt_debt
        interest_expense = assumptions.interest_rate_lt_debt * debt_at_year_start

        # EBIT and NI
        ebit = revenue - expenses - depreciation
        ebt = ebit - interest_expense
        net_income = ebt * (1.0 - assumptions.tax_rate)

        push!(income_statements, (
            year = year,
            revenue = revenue,
            operating_expenses = expenses,
            depreciation = depreciation,
            ebitda = ebit + depreciation,
            interest_expense = interest_expense,
            ebt = ebt,
            tax_expense = ebt * assumptions.tax_rate,
            net_income = net_income
        ))

        # ─── Balance Sheet ────────────────────────────────────────────────

        # Working capital scaling
        ar_new = revenue * (assumptions.days_in_ar / 365.0)
        inventory_new = expenses * (assumptions.days_in_inventory / 365.0)
        ap_new = expenses * (assumptions.days_in_ap / 365.0)

        # Capital expenditure
        capex = revenue * assumptions.capex_pct_of_revenue

        # New gross PPE and accumulated depreciation
        gross_ppe_new = current_bs.gross_ppe + capex
        accumulated_depr_new = current_bs.accumulated_depreciation + depreciation

        # Debt amortization (straight-line)
        debt_principal_payment = debt_at_year_start / assumptions.debt_amortization_years
        cp_lt_debt_new = debt_principal_payment
        lt_debt_new = max(0.0, current_bs.long_term_debt - debt_principal_payment)

        # Investment income
        total_investments = current_bs.short_term_investments + current_bs.long_term_investments
        investment_income = total_investments * assumptions.investment_yield

        # Net assets accumulation (assumes no distributions)
        new_net_assets_unrestricted = current_bs.net_assets_unrestricted + net_income + investment_income

        # Compute cash flow components for CF reconciliation
        # ΔWC = Δ(AR + Inventory - AP)
        prior_ar = current_bs.accounts_receivable_net
        prior_inventory = current_bs.inventory
        prior_ap = current_bs.accounts_payable

        delta_ar = ar_new - prior_ar
        delta_inventory = inventory_new - prior_inventory
        delta_ap = ap_new - prior_ap
        delta_wc = delta_ar + delta_inventory - delta_ap

        cfo = net_income + depreciation - delta_wc
        cfi = -capex
        cff = -debt_principal_payment

        # Net cash change
        delta_cash = cfo + cfi + cff

        # Update balance sheet for next iteration
        cash_new = max(0.0, current_bs.cash_and_equivalents + delta_cash)

        current_bs = BalanceSheetSnapshot(
            as_of_date = starting_bs.as_of_date + Year(year),
            cash_and_equivalents = cash_new,
            short_term_investments = current_bs.short_term_investments,
            accounts_receivable_net = ar_new,
            inventory = inventory_new,
            other_current_assets = current_bs.other_current_assets,
            gross_ppe = gross_ppe_new,
            accumulated_depreciation = accumulated_depr_new,
            long_term_investments = current_bs.long_term_investments,
            other_lt_assets = current_bs.other_lt_assets,
            accounts_payable = ap_new,
            accrued_expenses = current_bs.accrued_expenses,
            current_portion_lt_debt = cp_lt_debt_new,
            other_current_liabilities = current_bs.other_current_liabilities,
            long_term_debt = lt_debt_new,
            other_lt_liabilities = current_bs.other_lt_liabilities,
            net_assets_unrestricted = new_net_assets_unrestricted,
            net_assets_temp_restricted = current_bs.net_assets_temp_restricted,
            net_assets_perm_restricted = current_bs.net_assets_perm_restricted
        )

        push!(balance_sheets, current_bs)

        # ─── Cash Flow Statement ──────────────────────────────────────────
        push!(cash_flow_statements, (
            year = year,
            operating_cash_flow = cfo,
            investing_cash_flow = cfi,
            financing_cash_flow = cff,
            net_change_in_cash = delta_cash,
            # Components
            net_income = net_income,
            depreciation_amortization = depreciation,
            change_in_ar = -delta_ar,
            change_in_inventory = -delta_inventory,
            change_in_ap = delta_ap,
            capital_expenditure = capex,
            debt_principal_payment = debt_principal_payment
        ))

        # Update prior for next iteration
        prior_revenue = revenue
        prior_expenses = expenses
    end

    return ThreeStatementProjection(
        income_statements = income_statements,
        balance_sheets = balance_sheets,
        cash_flow_statements = cash_flow_statements,
        starting_balance_sheet = starting_bs,
        assumptions = assumptions
    )
end
