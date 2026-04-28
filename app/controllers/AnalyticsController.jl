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
include(joinpath(@__DIR__, "..", "..", "src", "data_ingestion", "hcris_importer.jl"))

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

# ─────────────────────────────────────────────────────────────────────────────
# Distress Scoring (Altman Z″ + Beneish M)
# ─────────────────────────────────────────────────────────────────────────────

"""
    handle_distress_scoring(payload::Dict)::Dict

API handler for Altman Z″ and Beneish M-score distress analysis.
"""
function handle_distress_scoring(payload::Dict)::Dict
    try
        # Extract financials (current and prior year)
        fin_curr = (
            total_operating_revenue = Float64(get(payload, "revenue_current", 20_000_000.0)),
            total_operating_expenses = Float64(get(payload, "expenses_current", 19_000_000.0)),
            ebit = Float64(get(payload, "ebit_current", 1_000_000.0)),
            interest_expense = Float64(get(payload, "interest_current", 500_000.0)),
            ebt = Float64(get(payload, "ebt_current", 500_000.0)),
            net_income = Float64(get(payload, "ni_current", 500_000.0)),
            depreciation = Float64(get(payload, "depr_current", 500_000.0))
        )

        fin_prior = (
            total_operating_revenue = Float64(get(payload, "revenue_prior", 19_500_000.0)),
            total_operating_expenses = Float64(get(payload, "expenses_prior", 18_500_000.0)),
            ebit = Float64(get(payload, "ebit_prior", 1_000_000.0)),
            interest_expense = Float64(get(payload, "interest_prior", 500_000.0)),
            ebt = Float64(get(payload, "ebt_prior", 500_000.0)),
            net_income = Float64(get(payload, "ni_prior", 500_000.0)),
            depreciation = Float64(get(payload, "depr_prior", 500_000.0))
        )

        # Extract BS (simplified to key fields)
        bs_curr = BalanceSheetSnapshot(
            as_of_date = today(),
            cash_and_equivalents = Float64(get(payload, "cash_curr", 2_000_000.0)),
            accounts_receivable_net = Float64(get(payload, "ar_curr", 3_000_000.0)),
            inventory = Float64(get(payload, "inv_curr", 500_000.0)),
            short_term_investments = Float64(get(payload, "sti_curr", 1_000_000.0)),
            gross_ppe = Float64(get(payload, "ppe_gross_curr", 50_000_000.0)),
            accumulated_depreciation = Float64(get(payload, "depr_accum_curr", 10_000_000.0)),
            long_term_investments = Float64(get(payload, "lti_curr", 5_000_000.0)),
            accounts_payable = Float64(get(payload, "ap_curr", 2_000_000.0)),
            accrued_expenses = Float64(get(payload, "accrued_curr", 1_000_000.0)),
            current_portion_lt_debt = Float64(get(payload, "cpltd_curr", 500_000.0)),
            long_term_debt = Float64(get(payload, "ltd_curr", 20_000_000.0)),
            net_assets_unrestricted = Float64(get(payload, "na_curr", 25_000_000.0))
        )

        bs_prior = BalanceSheetSnapshot(
            as_of_date = today() - Year(1),
            cash_and_equivalents = Float64(get(payload, "cash_prior", 2_000_000.0)),
            accounts_receivable_net = Float64(get(payload, "ar_prior", 3_000_000.0)),
            inventory = Float64(get(payload, "inv_prior", 500_000.0)),
            short_term_investments = Float64(get(payload, "sti_prior", 1_000_000.0)),
            gross_ppe = Float64(get(payload, "ppe_gross_prior", 50_000_000.0)),
            accumulated_depreciation = Float64(get(payload, "depr_accum_prior", 9_500_000.0)),
            long_term_investments = Float64(get(payload, "lti_prior", 5_000_000.0)),
            accounts_payable = Float64(get(payload, "ap_prior", 2_000_000.0)),
            accrued_expenses = Float64(get(payload, "accrued_prior", 1_000_000.0)),
            current_portion_lt_debt = Float64(get(payload, "cpltd_prior", 500_000.0)),
            long_term_debt = Float64(get(payload, "ltd_prior", 20_500_000.0)),
            net_assets_unrestricted = Float64(get(payload, "na_prior", 24_500_000.0))
        )

        # Compute scores
        z_score = altman_z_double_prime(fin_curr, bs_curr)
        m_score = beneish_m_score(fin_curr, fin_prior, bs_curr, bs_prior)

        return Dict(
            "status" => "success",
            "altman" => Dict(
                "z_double_prime" => round(z_score.z_double_prime, digits=4),
                "band" => String(z_score.band),
                "x1" => round(z_score.x1_working_capital_ratio, digits=4),
                "x2" => round(z_score.x2_retained_earnings_ratio, digits=4),
                "x3" => round(z_score.x3_ebit_ratio, digits=4),
                "x4" => round(z_score.x4_equity_ratio, digits=4)
            ),
            "beneish" => Dict(
                "m_score" => round(m_score.m_score, digits=4),
                "flag_manipulation" => m_score.flag_manipulation,
                "dsri" => round(m_score.dsri, digits=4),
                "gmi" => round(m_score.gmi, digits=4),
                "aqi" => round(m_score.aqi, digits=4),
                "sgi" => round(m_score.sgi, digits=4),
                "depi" => round(m_score.depi, digits=4),
                "sgai" => round(m_score.sgai, digits=4),
                "lvgi" => round(m_score.lvgi, digits=4),
                "tata" => round(m_score.tata, digits=6)
            )
        )
    catch e
        return Dict(
            "status" => "error",
            "message" => sprint(showerror, e)
        )
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# HCRIS Auto-Import
# ─────────────────────────────────────────────────────────────────────────────

"""
    handle_hcris_import(payload::Dict)::Dict

API handler for HCRIS auto-import by CCN.
"""
function handle_hcris_import(payload::Dict)::Dict
    try
        ccn = String(get(payload, "ccn", ""))
        fiscal_year = Int(get(payload, "fiscal_year", Dates.year(today())))

        isempty(ccn) && throw(ArgumentError("CCN is required"))

        # Import from HCRIS
        result = import_hcris(ccn, fiscal_year)

        return Dict(
            "status" => "success",
            "ccn" => ccn,
            "fiscal_year" => fiscal_year,
            "financials" => Dict(
                "total_operating_revenue" => result.financials.total_operating_revenue,
                "total_operating_expenses" => result.financials.total_operating_expenses,
                "operating_income" => result.financials.operating_income,
                "net_assets" => result.financials.net_assets,
                "current_ratio" => result.financials.current_ratio,
                "days_cash_on_hand" => result.financials.days_cash_on_hand,
                "inpatient_discharges" => result.financials.inpatient_discharges,
                "ed_visits" => result.financials.ed_visits
            ),
            "balance_sheet" => Dict(
                "total_assets" => (result.balance_sheet.cash_and_equivalents +
                                   result.balance_sheet.accounts_receivable_net +
                                   result.balance_sheet.gross_ppe - result.balance_sheet.accumulated_depreciation),
                "total_liabilities" => (result.balance_sheet.accounts_payable +
                                        result.balance_sheet.long_term_debt),
                "net_assets" => result.balance_sheet.net_assets_unrestricted
            ),
            "metadata" => result.metadata
        )
    catch e
        return Dict(
            "status" => "error",
            "message" => sprint(showerror, e)
        )
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# A-04: Nonprofit WACC Calculator
# ─────────────────────────────────────────────────────────────────────────────

"""
    handle_wacc(payload::Dict)::Dict

API handler for nonprofit WACC calculation.

Expected payload keys:
  - cost_of_equity_model: String ("capm", "conservative", "aggressive")
  - risk_free_rate: Float64
  - market_risk_premium: Float64
  - beta: Float64
  - rating: String (S&P rating, e.g., "B")
  - lt_debt: Float64
  - net_assets: Float64

Returns WACC calculation results.
"""
function handle_wacc(payload::Dict)::Dict
    try
        cost_of_equity_model = Symbol(lowercase(get(payload, "cost_of_equity_model", "capm")))
        risk_free_rate = Float64(get(payload, "risk_free_rate", 0.04))
        market_risk_premium = Float64(get(payload, "market_risk_premium", 0.06))
        beta = Float64(get(payload, "beta", 1.0))
        rating = String(get(payload, "rating", "B"))
        lt_debt = Float64(get(payload, "lt_debt", 20_000_000.0))
        net_assets = Float64(get(payload, "net_assets", 25_000_000.0))

        # Create balance sheet
        bs = BalanceSheetSnapshot(
            as_of_date = today(),
            cash_and_equivalents = 2_000_000.0,
            short_term_investments = 1_000_000.0,
            accounts_receivable_net = 3_000_000.0,
            inventory = 500_000.0,
            gross_ppe = 50_000_000.0,
            accumulated_depreciation = 10_000_000.0,
            long_term_investments = 5_000_000.0,
            accounts_payable = 2_000_000.0,
            accrued_expenses = 1_000_000.0,
            current_portion_lt_debt = 500_000.0,
            long_term_debt = lt_debt,
            net_assets_unrestricted = net_assets
        )

        # Create dummy financials
        financials = (
            total_operating_revenue = 20_000_000.0,
            total_operating_expenses = 19_000_000.0
        )

        # Calculate WACC
        wacc_result = calculate_wacc(
            financials, bs;
            cost_of_equity_model = cost_of_equity_model,
            tax_exempt = true,
            risk_free_rate = risk_free_rate,
            market_risk_premium = market_risk_premium,
            beta = beta,
            rating = rating
        )

        return Dict(
            "status" => "ok",
            "wacc" => wacc_result.wacc,
            "cost_of_equity" => wacc_result.cost_of_equity,
            "cost_of_debt" => wacc_result.cost_of_debt,
            "target_debt_ratio" => wacc_result.target_debt_ratio,
            "equity_ratio" => 1.0 - wacc_result.target_debt_ratio
        )
    catch e
        return Dict(
            "status" => "error",
            "message" => sprint(showerror, e)
        )
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# A-05: Capital Budgeting (CapEx Ranking)
# ─────────────────────────────────────────────────────────────────────────────

"""
    handle_capex_ranking(payload::Dict)::Dict

API handler for capital project ranking.

Expected payload keys:
  - projects: Vector of project dicts with:
    - name: String
    - initial_outlay: Float64
    - useful_life: Int
    - annual_cf: Vector{Float64}
    - salvage_value: Float64 (optional)
  - wacc: Float64 (discount rate)
  - budget_constraint: Float64 or null

Returns ranked projects with NPV, IRR, profitability index.
"""
function handle_capex_ranking(payload::Dict)::Dict
    try
        projects_data = get(payload, "projects", [])
        wacc = Float64(get(payload, "wacc", 0.08))
        budget_constraint = get(payload, "budget_constraint", nothing)

        if isempty(projects_data)
            return Dict(
                "status" => "error",
                "message" => "No projects provided"
            )
        end

        # Build CapexProject structs
        projects = [
            CapexProject(
                name = String(p["name"]),
                initial_outlay = Float64(p["initial_outlay"]),
                useful_life = Int(p["useful_life"]),
                annual_cf = Float64.(p["annual_cf"]),
                salvage_value = Float64(get(p, "salvage_value", 0.0))
            )
            for p in projects_data
        ]

        # Rank projects
        if isnothing(budget_constraint)
            ranking_df = rank_projects(projects, wacc)
        else
            ranking_df = rank_projects(projects, wacc; budget_constraint = Float64(budget_constraint))
        end

        # Convert to JSON-serializable format
        ranked_projects = [
            Dict(
                "name" => row.name,
                "initial_outlay" => row.initial_outlay,
                "npv" => row.npv,
                "irr" => row.irr,
                "payback_years" => row.payback_years,
                "profitability_index" => row.profitability_index,
                "pi_rank" => row.pi_rank,
                "selected" => row.selected,
                "cumulative_investment" => row.cumulative_investment
            )
            for row in eachrow(ranking_df)
        ]

        return Dict(
            "status" => "ok",
            "ranked_projects" => ranked_projects,
            "total_projects" => nrow(ranking_df),
            "total_investment" => sum(ranking_df.initial_outlay),
            "total_npv" => sum(ranking_df.npv)
        )
    catch e
        return Dict(
            "status" => "error",
            "message" => sprint(showerror, e)
        )
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# A-08: RHC & CAH Reimbursement Comparison
# ─────────────────────────────────────────────────────────────────────────────

"""
    handle_rhc_cah_comparison(payload::Dict) -> Dict

API handler for RHC vs CAH reimbursement analysis.
"""
function handle_rhc_cah_comparison(payload::Dict)::Dict
    try
        rhc_visits = get(payload, "rhc_visits", Dict())
        ar_volumes = get(payload, "ar_volumes", Dict())
        non_ar_volumes = get(payload, "non_ar_volumes", Dict())
        mileage = Float64(get(payload, "mileage_miles", 0.0))
        conversion_cost = Float64(get(payload, "conversion_cost", 50_000.0))

        rhc_fixture = joinpath(@__DIR__, "..", "..", "test", "fixtures", "reimbursement", "rhc_rvu_2024.json")
        cah_fixture = joinpath(@__DIR__, "..", "..", "test", "fixtures", "reimbursement", "cah_ar_2024.json")

        rhc_sch = load_rhc_schedule(rhc_fixture)
        cah_sch = load_cah_schedule(cah_fixture)

        comp = compare_reimbursement(rhc_visits, ar_volumes, non_ar_volumes, rhc_sch, cah_sch;
                                    mileage_miles=mileage, conversion_cost_estimate=conversion_cost)

        return Dict(
            "status" => "ok",
            "rhc_revenue" => comp.rhc_annual_revenue,
            "cah_revenue" => comp.cah_annual_revenue,
            "revenue_difference" => comp.revenue_difference,
            "revenue_difference_pct" => comp.revenue_difference_pct,
            "roi_pct" => comp.conversion_roi_pct,
            "break_even_months" => comp.break_even_months,
            "recommendation" => comp.recommendation
        )
    catch e
        return Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# A-07: VBC Bayesian Scenario Modeling
# ─────────────────────────────────────────────────────────────────────────────

"""
    handle_vbc_bayesian(payload::Dict) -> Dict

API handler for VBC Bayesian posterior sampling.

Expected payload:
  - scenario: Dict with name, scenario_type, shared_savings_rate, risk_bearing
  - historical_savings: Vector of annual savings values

Returns posterior statistics and visualization data.
"""
function handle_vbc_bayesian(payload::Dict)::Dict
    try
        scenario_data = get(payload, "scenario", Dict())
        historical_savings = Float64.(get(payload, "historical_savings", [100_000.0]))

        # Build VBC scenario
        scenario = VBCScenario(
            name = String(get(scenario_data, "name", "Unknown")),
            scenario_type = Symbol(lowercase(get(scenario_data, "scenario_type", "aco"))),
            shared_savings_rate = Float64(get(scenario_data, "shared_savings_rate", 0.50)),
            risk_bearing = Float64(get(scenario_data, "risk_bearing", 0.30))
        )

        # Sample posterior
        post = sample_vbc_posterior(scenario, historical_savings; n_iterations=1000, seed=42)

        return Dict(
            "status" => "ok",
            "scenario_name" => post.scenario_name,
            "scenario_type" => string(post.scenario_type),
            "posterior_mean_savings" => post.posterior_mean_savings,
            "posterior_std" => post.posterior_std,
            "ci_lower" => post.credible_interval_lower,
            "ci_upper" => post.credible_interval_upper,
            "prob_positive" => post.prob_positive_savings,
            "prior_mean" => post.prior_mean,
            "prior_std" => post.prior_std,
            "n_iterations" => post.n_iterations,
            "convergence_rhat" => post.convergence_rhat
        )
    catch e
        return Dict(
            "status" => "error",
            "message" => sprint(showerror, e)
        )
    end
end

"""
    handle_vbc_compare_scenarios(payload::Dict) -> Dict

API handler for comparing multiple VBC scenarios.

Expected payload:
  - scenarios: Vector of scenario dicts

Returns ranked scenarios with posteriors.
"""
function handle_vbc_compare_scenarios(payload::Dict)::Dict
    try
        scenarios_data = get(payload, "scenarios", [])
        if isempty(scenarios_data)
            return Dict(
                "status" => "error",
                "message" => "No scenarios provided"
            )
        end

        # Build VBC scenarios
        scenarios = [
            VBCScenario(
                name = String(get(s, "name", "Unknown")),
                scenario_type = Symbol(lowercase(get(s, "scenario_type", "aco"))),
                shared_savings_rate = Float64(get(s, "shared_savings_rate", 0.50)),
                risk_bearing = Float64(get(s, "risk_bearing", 0.30))
            )
            for s in scenarios_data
        ]

        # Build historical data dict (default if not provided)
        historical_dict = Dict(
            scenario.name => [
                Float64(get(s, "historical_savings", [100_000.0, 110_000.0]))[1]
            ]
            for (s, scenario) in zip(scenarios_data, scenarios)
        )

        # Compare scenarios
        ranking_df = compare_scenarios(scenarios, historical_dict)

        # Convert to JSON-serializable format
        ranked_scenarios = [
            Dict(
                "rank" => row.rank,
                "scenario_name" => row.scenario_name,
                "scenario_type" => row.scenario_type,
                "posterior_mean_savings" => row.posterior_mean_savings,
                "posterior_std" => row.posterior_std,
                "ci_lower" => row.ci_lower,
                "ci_upper" => row.ci_upper,
                "prob_positive" => row.prob_positive,
                "ranking_score" => row.ranking_score,
                "shared_savings_rate" => row.shared_savings_rate,
                "risk_bearing" => row.risk_bearing
            )
            for row in eachrow(ranking_df)
        ]

        return Dict(
            "status" => "ok",
            "ranked_scenarios" => ranked_scenarios,
            "scenario_count" => length(scenarios)
        )
    catch e
        return Dict(
            "status" => "error",
            "message" => sprint(showerror, e)
        )
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 340B Drug Program Savings (A-09)
# ─────────────────────────────────────────────────────────────────────────────

"""
    handle_340b_savings(payload::Dict)::Dict

API handler for 340B drug program savings estimation.

Expected payload keys:
  - drugs: Vector{Dict} with keys [ndc, description, avg_wholesale_price, ceiling_price, hospital_acquisition_cost, estimated_monthly_usage]
  - managed_care_cap: Float64 (default 0.15)
  - optimize: Bool (if true, also compute drug mix optimization)
  - budget: Float64 (for optimization, default 500000.0)

Returns a Dict with savings metrics and optional optimization results.
"""
function handle_340b_savings(payload::Dict)::Dict
    try
        drugs_data = get(payload, "drugs", [])
        managed_care_cap = Float64(get(payload, "managed_care_cap", 0.15))
        should_optimize = get(payload, "optimize", false)
        budget = Float64(get(payload, "budget", 500_000.0))

        if isempty(drugs_data)
            return Dict("error" => "No drugs provided")
        end

        # Build Drug340B structs
        drugs = [
            Drug340B(
                String(get(d, "ndc", "")),
                String(get(d, "description", "")),
                Float64(get(d, "avg_wholesale_price", 0.0)),
                Float64(get(d, "ceiling_price", 0.0)),
                Float64(get(d, "hospital_acquisition_cost", 0.0)),
                Float64(get(d, "estimated_monthly_usage", 0.0))
            )
            for d in drugs_data
        ]

        # Estimate savings
        metrics = estimate_340b_savings(drugs, managed_care_cap=managed_care_cap)

        result = Dict(
            "status" => "ok",
            "total_annual_usage" => metrics.total_annual_usage_units,
            "avg_discount_pct" => metrics.avg_discount_pct,
            "estimated_annual_savings" => metrics.estimated_annual_savings,
            "ceiling_vs_mac_ratio" => metrics.ceiling_vs_mac_ratio,
            "managed_care_applicability" => metrics.managed_care_discount_applicability
        )

        # Optimize drug mix if requested
        if should_optimize && budget > 0
            opt_result = optimize_drug_mix(drugs, budget, managed_care_cap=managed_care_cap)
            result["optimization"] = Dict(
                "optimized_drug_count" => length(opt_result.optimized_drugs),
                "total_annual_savings" => opt_result.total_annual_savings,
                "budget_remaining" => opt_result.budget_remaining,
                "annual_units_used" => opt_result.annual_units_used,
                "average_discount_pct" => opt_result.average_discount_pct,
                "optimized_ndcs" => opt_result.optimized_drugs
            )
        end

        return result
    catch e
        return Dict(
            "status" => "error",
            "message" => sprint(showerror, e)
        )
    end
end

end  # module AnalyticsController


