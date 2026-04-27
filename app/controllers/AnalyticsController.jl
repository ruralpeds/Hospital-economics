"""
AnalyticsController — API handlers for MBA-grade analytics endpoints.

Routes:
  POST /api/analytics/three-statement
  POST /api/analytics/dupont
  POST /api/analytics/distress-scoring
"""
module AnalyticsController

using JSON3, Dates
using ...RuralHospitalSim
using FinanceEngine

# ─────────────────────────────────────────────────────────────────────────────
# Three-Statement Projection
# ─────────────────────────────────────────────────────────────────────────────

"""
    handle_three_statement(payload::Dict)::Dict

API handler for three-statement projection.

Expected payload keys:
  - baseline_revenue: Float64
  - baseline_expenses: Float64
  - bs_cash: Float64
  - bs_ar: Float64
  - bs_inventory: Float64
  - bs_gross_ppe: Float64
  - bs_accumulated_depr: Float64
  - bs_ap: Float64
  - bs_accrued_exp: Float64
  - bs_cp_debt: Float64
  - bs_lt_debt: Float64
  - bs_net_assets: Float64
  - revenue_growth: Vector{Float64}
  - expense_growth: Vector{Float64}
  - capex_pct: Float64
  - interest_rate: Float64

Returns a Dict with three-statement projection results.
"""
function handle_three_statement(payload::Dict)::Dict
    try
        # Extract baseline financials
        baseline_revenue = Float64(get(payload, "baseline_revenue", 20_000_000.0))
        baseline_expenses = Float64(get(payload, "baseline_expenses", 19_000_000.0))

        # Extract starting balance sheet
        bs_cash = Float64(get(payload, "bs_cash", 2_000_000.0))
        bs_short_term_inv = Float64(get(payload, "bs_short_term_inv", 1_000_000.0))
        bs_ar = Float64(get(payload, "bs_ar", 3_000_000.0))
        bs_inventory = Float64(get(payload, "bs_inventory", 500_000.0))
        bs_gross_ppe = Float64(get(payload, "bs_gross_ppe", 50_000_000.0))
        bs_accumulated_depr = Float64(get(payload, "bs_accumulated_depr", 10_000_000.0))
        bs_lt_inv = Float64(get(payload, "bs_lt_inv", 5_000_000.0))
        bs_ap = Float64(get(payload, "bs_ap", 2_000_000.0))
        bs_accrued_exp = Float64(get(payload, "bs_accrued_exp", 1_000_000.0))
        bs_cp_debt = Float64(get(payload, "bs_cp_debt", 500_000.0))
        bs_lt_debt = Float64(get(payload, "bs_lt_debt", 20_000_000.0))
        bs_net_assets = Float64(get(payload, "bs_net_assets", 25_000_000.0))

        # Extract assumptions
        horizon = Int(get(payload, "horizon_years", 5))
        revenue_growth = vec(Float64.(get(payload, "revenue_growth", fill(0.02, horizon))))
        expense_growth = vec(Float64.(get(payload, "expense_growth", fill(0.03, horizon))))
        capex_pct = Float64(get(payload, "capex_pct", 0.04))
        interest_rate = Float64(get(payload, "interest_rate", 0.05))
        days_in_ar = Float64(get(payload, "days_in_ar", 50.0))
        days_in_inventory = Float64(get(payload, "days_in_inventory", 25.0))
        days_in_ap = Float64(get(payload, "days_in_ap", 35.0))
        debt_amort_years = Int(get(payload, "debt_amort_years", 20))

        # Build baseline NamedTuple
        baseline = (
            total_operating_revenue = baseline_revenue,
            total_operating_expenses = baseline_expenses
        )

        # Build starting balance sheet
        starting_bs = BalanceSheetSnapshot(
            as_of_date = today(),
            cash_and_equivalents = bs_cash,
            short_term_investments = bs_short_term_inv,
            accounts_receivable_net = bs_ar,
            inventory = bs_inventory,
            gross_ppe = bs_gross_ppe,
            accumulated_depreciation = bs_accumulated_depr,
            long_term_investments = bs_lt_inv,
            accounts_payable = bs_ap,
            accrued_expenses = bs_accrued_exp,
            current_portion_lt_debt = bs_cp_debt,
            long_term_debt = bs_lt_debt,
            net_assets_unrestricted = bs_net_assets
        )

        # Build projection assumptions
        assumptions = ProjectionAssumptions(
            horizon_years = horizon,
            revenue_growth = revenue_growth,
            expense_growth = expense_growth,
            depreciation_rate = 0.05,
            capex_pct_of_revenue = capex_pct,
            days_in_ar = days_in_ar,
            days_in_inventory = days_in_inventory,
            days_in_ap = days_in_ap,
            interest_rate_lt_debt = interest_rate,
            debt_amortization_years = debt_amort_years,
            tax_rate = 0.0
        )

        # Run projection
        projection = project_three_statement(baseline, starting_bs, assumptions)

        # Format response
        return Dict(
            "status" => "success",
            "horizon_years" => horizon,
            "income_statements" => [
                Dict(
                    "year" => is.year,
                    "revenue" => round(is.revenue, digits=2),
                    "operating_expenses" => round(is.operating_expenses, digits=2),
                    "depreciation" => round(is.depreciation, digits=2),
                    "ebitda" => round(is.ebitda, digits=2),
                    "interest_expense" => round(is.interest_expense, digits=2),
                    "ebt" => round(is.ebt, digits=2),
                    "net_income" => round(is.net_income, digits=2)
                )
                for is in projection.income_statements
            ],
            "balance_sheets" => [
                Dict(
                    "year" => i,
                    "cash" => round(bs.cash_and_equivalents, digits=2),
                    "ar" => round(bs.accounts_receivable_net, digits=2),
                    "inventory" => round(bs.inventory, digits=2),
                    "gross_ppe" => round(bs.gross_ppe, digits=2),
                    "accumulated_depr" => round(bs.accumulated_depreciation, digits=2),
                    "ap" => round(bs.accounts_payable, digits=2),
                    "cp_debt" => round(bs.current_portion_lt_debt, digits=2),
                    "lt_debt" => round(bs.long_term_debt, digits=2),
                    "net_assets" => round(bs.net_assets_unrestricted, digits=2),
                    "balances" => bs_balances(bs, tol=1.0)
                )
                for (i, bs) in enumerate(projection.balance_sheets)
            ],
            "cash_flows" => [
                Dict(
                    "year" => cf.year,
                    "operating_cf" => round(cf.operating_cash_flow, digits=2),
                    "investing_cf" => round(cf.investing_cash_flow, digits=2),
                    "financing_cf" => round(cf.financing_cash_flow, digits=2),
                    "net_change" => round(cf.net_change_in_cash, digits=2)
                )
                for cf in projection.cash_flow_statements
            ]
        )
    catch e
        return Dict(
            "status" => "error",
            "message" => sprint(showerror, e)
        )
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# DuPont Decomposition
# ─────────────────────────────────────────────────────────────────────────────

"""
    handle_dupont(payload::Dict)::Dict

API handler for DuPont decomposition.

Expected payload keys:
  - baseline_revenue: Float64
  - ebit: Float64
  - interest_expense: Float64
  - ebt: Float64
  - net_income: Float64
  - bs_cash, bs_ar, bs_inventory, bs_gross_ppe, bs_accumulated_depr, etc.
  - tax_exempt: Bool

Returns a Dict with 3-factor and 5-factor DuPont results.
"""
function handle_dupont(payload::Dict)::Dict
    try
        # Extract financials
        baseline_revenue = Float64(get(payload, "baseline_revenue", 20_000_000.0))
        ebit = Float64(get(payload, "ebit", 1_000_000.0))
        interest_expense = Float64(get(payload, "interest_expense", 500_000.0))
        ebt = Float64(get(payload, "ebt", ebit - interest_expense))
        net_income = Float64(get(payload, "net_income", ebt))
        tax_exempt = Bool(get(payload, "tax_exempt", true))

        # Extract balance sheet
        bs_cash = Float64(get(payload, "bs_cash", 2_000_000.0))
        bs_short_term_inv = Float64(get(payload, "bs_short_term_inv", 1_000_000.0))
        bs_ar = Float64(get(payload, "bs_ar", 3_000_000.0))
        bs_inventory = Float64(get(payload, "bs_inventory", 500_000.0))
        bs_gross_ppe = Float64(get(payload, "bs_gross_ppe", 50_000_000.0))
        bs_accumulated_depr = Float64(get(payload, "bs_accumulated_depr", 10_000_000.0))
        bs_lt_inv = Float64(get(payload, "bs_lt_inv", 5_000_000.0))
        bs_ap = Float64(get(payload, "bs_ap", 2_000_000.0))
        bs_accrued_exp = Float64(get(payload, "bs_accrued_exp", 1_000_000.0))
        bs_cp_debt = Float64(get(payload, "bs_cp_debt", 500_000.0))
        bs_lt_debt = Float64(get(payload, "bs_lt_debt", 20_000_000.0))
        bs_net_assets = Float64(get(payload, "bs_net_assets", 25_000_000.0))

        # Build financials NamedTuple
        financials = (
            total_operating_revenue = baseline_revenue,
            ebit = ebit,
            interest_expense = interest_expense,
            ebt = ebt,
            net_income = net_income
        )

        # Build balance sheet
        bs = BalanceSheetSnapshot(
            as_of_date = today(),
            cash_and_equivalents = bs_cash,
            short_term_investments = bs_short_term_inv,
            accounts_receivable_net = bs_ar,
            inventory = bs_inventory,
            gross_ppe = bs_gross_ppe,
            accumulated_depreciation = bs_accumulated_depr,
            long_term_investments = bs_lt_inv,
            accounts_payable = bs_ap,
            accrued_expenses = bs_accrued_exp,
            current_portion_lt_debt = bs_cp_debt,
            long_term_debt = bs_lt_debt,
            net_assets_unrestricted = bs_net_assets
        )

        # Compute DuPont decompositions
        dp3 = dupont_3factor(financials, bs)
        dp5 = dupont_5factor(financials, bs, tax_exempt=tax_exempt)

        # Format response
        return Dict(
            "status" => "success",
            "three_factor" => Dict(
                "net_profit_margin" => round(dp3.net_profit_margin, digits=6),
                "asset_turnover" => round(dp3.asset_turnover, digits=4),
                "equity_multiplier" => round(dp3.equity_multiplier, digits=4),
                "return_on_net_assets" => round(dp3.return_on_net_assets, digits=6)
            ),
            "five_factor" => Dict(
                "operating_margin" => round(dp5.operating_margin, digits=6),
                "asset_turnover" => round(dp5.asset_turnover, digits=4),
                "equity_multiplier" => round(dp5.equity_multiplier, digits=4),
                "interest_burden" => round(dp5.interest_burden, digits=6),
                "tax_burden" => round(dp5.tax_burden, digits=6),
                "return_on_net_assets" => round(dp5.return_on_net_assets, digits=6)
            ),
            "metadata" => Dict(
                "tax_exempt" => tax_exempt,
                "revenue" => round(baseline_revenue, digits=2),
                "net_income" => round(net_income, digits=2)
            )
        )
    catch e
        return Dict(
            "status" => "error",
            "message" => sprint(showerror, e)
        )
    end
end

end  # module AnalyticsController
