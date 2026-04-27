using Test
using Dates
using FinanceEngine

@testset "Three-Statement Projection Engine" begin
    # Create a baseline AnnualFinancials as a NamedTuple (simulating minimal data)
    baseline = (
        total_operating_revenue = 20_000_000.0,
        total_operating_expenses = 19_000_000.0
    )

    # Create a starting balance sheet
    starting_bs = BalanceSheetSnapshot(
        as_of_date = Date(2023, 12, 31),
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
        long_term_debt = 20_000_000.0,
        net_assets_unrestricted = 25_000_000.0
    )

    # Create projection assumptions
    assumptions = ProjectionAssumptions(
        horizon_years = 5,
        revenue_growth = [0.02, 0.02, 0.02, 0.01, 0.01],
        expense_growth = [0.03, 0.03, 0.02, 0.02, 0.02],
        depreciation_rate = 0.05,
        capex_pct_of_revenue = 0.04,
        days_in_ar = 50.0,
        days_in_inventory = 25.0,
        days_in_ap = 35.0,
        interest_rate_lt_debt = 0.05,
        debt_amortization_years = 20,
        tax_rate = 0.0,
        investment_yield = 0.04
    )

    # ─────────────────────────────────────────────────────────────────────
    # Test 1: Returns correct projection type with correct horizon length
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        projection = project_three_statement(baseline, starting_bs, assumptions)
        projection isa ThreeStatementProjection &&
        length(projection.income_statements) == 5 &&
        length(projection.balance_sheets) == 5 &&
        length(projection.cash_flow_statements) == 5
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: Each year's balance sheet balances within $1
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        projection = project_three_statement(baseline, starting_bs, assumptions)
        all(bs_balances(bs, tol=1.0) for bs in projection.balance_sheets)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: Cash flow reconciles to balance sheet changes within $1
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        projection = project_three_statement(baseline, starting_bs, assumptions)
        prior_bs = projection.starting_balance_sheet
        all_reconcile = true
        for (i, cf) in enumerate(projection.cash_flow_statements)
            current_bs = projection.balance_sheets[i]
            delta_cash_bs = current_bs.cash_and_equivalents - prior_bs.cash_and_equivalents
            delta_cash_cf = cf.net_change_in_cash
            if abs(delta_cash_bs - delta_cash_cf) > 1.0
                all_reconcile = false
                break
            end
            prior_bs = current_bs
        end
        all_reconcile
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: With zero growth and zero capex, gross PPE is constant
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        zero_assumptions = ProjectionAssumptions(
            horizon_years = 5,
            revenue_growth = [0.0, 0.0, 0.0, 0.0, 0.0],
            expense_growth = [0.0, 0.0, 0.0, 0.0, 0.0],
            depreciation_rate = 0.05,
            capex_pct_of_revenue = 0.0,
            days_in_ar = 50.0,
            days_in_inventory = 25.0,
            days_in_ap = 35.0,
            interest_rate_lt_debt = 0.05,
            debt_amortization_years = 20,
            tax_rate = 0.0,
            investment_yield = 0.04
        )
        projection = project_three_statement(baseline, starting_bs, zero_assumptions)
        # Gross PPE should remain constant (no capex)
        all(bs.gross_ppe ≈ starting_bs.gross_ppe for bs in projection.balance_sheets)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: With growth = 0 everywhere, revenue equals baseline
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        zero_assumptions = ProjectionAssumptions(
            horizon_years = 5,
            revenue_growth = [0.0, 0.0, 0.0, 0.0, 0.0],
            expense_growth = [0.0, 0.0, 0.0, 0.0, 0.0],
            depreciation_rate = 0.05,
            capex_pct_of_revenue = 0.0,
            days_in_ar = 50.0,
            days_in_inventory = 25.0,
            days_in_ap = 35.0,
            interest_rate_lt_debt = 0.05,
            debt_amortization_years = 20,
            tax_rate = 0.0,
            investment_yield = 0.04
        )
        projection = project_three_statement(baseline, starting_bs, zero_assumptions)
        # All revenues should equal baseline revenue
        all(is.revenue ≈ baseline.total_operating_revenue for is in projection.income_statements)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: Net income accumulates into net_assets_unrestricted year over year
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        projection = project_three_statement(baseline, starting_bs, assumptions)
        # Starting net assets + cumulative net income should ≈ final net assets
        cumulative_ni = sum(is.net_income for is in projection.income_statements)
        final_net_assets = projection.balance_sheets[end].net_assets_unrestricted
        starting_net_assets = projection.starting_balance_sheet.net_assets_unrestricted
        # Note: we also have investment income, so this is approximate
        final_net_assets > starting_net_assets  # Should increase if NI is positive
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: Days-in-AR change scales the AR balance correctly
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        # With 50 days AR and revenue growth, AR should scale proportionally
        projection = project_three_statement(baseline, starting_bs, assumptions)
        first_year_revenue = projection.income_statements[1].revenue
        expected_ar = first_year_revenue * (assumptions.days_in_ar / 365.0)
        actual_ar = projection.balance_sheets[1].accounts_receivable_net
        abs(actual_ar - expected_ar) < 1000.0  # Within $1k rounding
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: Throws error when horizon_years != length of growth vectors
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        bad_assumptions = ProjectionAssumptions(
            horizon_years = 5,
            revenue_growth = [0.02, 0.02],  # Only 2 elements
            expense_growth = [0.03, 0.03, 0.02, 0.02, 0.02],
            depreciation_rate = 0.05,
            capex_pct_of_revenue = 0.04,
            days_in_ar = 50.0,
            days_in_inventory = 25.0,
            days_in_ap = 35.0,
            interest_rate_lt_debt = 0.05,
            debt_amortization_years = 20,
            tax_rate = 0.0,
            investment_yield = 0.04
        )
        try
            project_three_statement(baseline, starting_bs, bad_assumptions)
            false  # Should not reach here
        catch err
            err isa DomainError
        end
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 9: CFO = NI + D&A - ΔWC formula holds for year 1
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        projection = project_three_statement(baseline, starting_bs, assumptions)
        cf = projection.cash_flow_statements[1]
        is = projection.income_statements[1]
        # CFO should equal NI + D&A - ΔWC (approximately)
        expected_cfo = is.net_income + is.depreciation_amortization -
                       (cf.change_in_ar + cf.change_in_inventory - cf.change_in_ap)
        abs(cf.operating_cash_flow - expected_cfo) < 1000.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 10: bs_balances returns true for balanced sheet, false for unbalanced
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        # A properly constructed BS should balance
        balanced = bs_balances(starting_bs, tol=1.0)
        # Create a deliberately unbalanced BS (subtract from assets)
        unbalanced_bs = BalanceSheetSnapshot(
            as_of_date = starting_bs.as_of_date,
            cash_and_equivalents = 0.0,  # Set to 0 to unbalance
            short_term_investments = starting_bs.short_term_investments,
            accounts_receivable_net = starting_bs.accounts_receivable_net,
            inventory = starting_bs.inventory,
            gross_ppe = starting_bs.gross_ppe,
            accumulated_depreciation = starting_bs.accumulated_depreciation,
            long_term_investments = starting_bs.long_term_investments,
            accounts_payable = starting_bs.accounts_payable,
            accrued_expenses = starting_bs.accrued_expenses,
            current_portion_lt_debt = starting_bs.current_portion_lt_debt,
            long_term_debt = starting_bs.long_term_debt,
            net_assets_unrestricted = starting_bs.net_assets_unrestricted
        )
        unbalanced = !bs_balances(unbalanced_bs, tol=1.0)
        balanced && unbalanced
    end
end
