using Test
using Dates
using FinanceEngine

@testset "DuPont Decomposition" begin
    # Create sample balance sheet
    bs = BalanceSheetSnapshot(
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

    # Create sample financials
    financials = (
        total_operating_revenue = 20_000_000.0,
        operating_expenses = 19_000_000.0,
        ebit = 1_000_000.0,
        interest_expense = 500_000.0,
        ebt = 500_000.0,
        net_income = 500_000.0  # Tax-exempt, so NI = EBT
    )

    # ─────────────────────────────────────────────────────────────────────
    # Test 1: DuPont 3-factor returns correct type
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = dupont_3factor(financials, bs)
        result isa DuPont3Factor &&
        hasfield(DuPont3Factor, :net_profit_margin) &&
        hasfield(DuPont3Factor, :asset_turnover) &&
        hasfield(DuPont3Factor, :equity_multiplier) &&
        hasfield(DuPont3Factor, :return_on_net_assets)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: DuPont 5-factor returns correct type
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = dupont_5factor(financials, bs, tax_exempt=true)
        result isa DuPont5Factor &&
        hasfield(DuPont5Factor, :operating_margin) &&
        hasfield(DuPont5Factor, :interest_burden) &&
        hasfield(DuPont5Factor, :tax_burden)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: 3-factor product equals direct ROA calculation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = dupont_3factor(financials, bs)
        # Direct calculation of ROA: NI / Net Assets
        direct_rona = 500_000.0 / 25_000_000.0  # = 0.02
        # DuPont product should match within numerical precision
        product = result.net_profit_margin * result.asset_turnover * result.equity_multiplier
        abs(product - result.return_on_net_assets) < 1e-9 &&
        abs(result.return_on_net_assets - direct_rona) < 0.001
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: Tax-exempt means tax_burden = 1.0 for 5-factor
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result_exempt = dupont_5factor(financials, bs, tax_exempt=true)
        result_exempt.tax_burden ≈ 1.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: 5-factor product equals direct ROA (tax-exempt)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = dupont_5factor(financials, bs, tax_exempt=true)
        direct_rona = 500_000.0 / 25_000_000.0
        product = result.operating_margin * result.asset_turnover *
                  result.equity_multiplier * result.interest_burden * result.tax_burden
        abs(product - result.return_on_net_assets) < 1e-9 &&
        abs(result.return_on_net_assets - direct_rona) < 0.001
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: Known textbook example (simplified Moody's methodology)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        # Use easily calculable numbers for verification
        textbook_bs = BalanceSheetSnapshot(
            as_of_date = Date(2023, 12, 31),
            cash_and_equivalents = 100_000.0,
            accounts_receivable_net = 300_000.0,
            inventory = 100_000.0,
            gross_ppe = 1_000_000.0,
            accumulated_depreciation = 200_000.0,
            accounts_payable = 200_000.0,
            accrued_expenses = 100_000.0,
            current_portion_lt_debt = 100_000.0,
            long_term_debt = 400_000.0,
            net_assets_unrestricted = 1_000_000.0
        )

        textbook_fin = (
            total_operating_revenue = 2_000_000.0,
            ebit = 200_000.0,
            ebt = 100_000.0,
            net_income = 100_000.0
        )

        # Total assets = 100 + 300 + 100 + 800 = 1300
        # NPM = 100/2000 = 0.05
        # ATO = 2000/1300 ≈ 1.538
        # EM = 1300/1000 = 1.3
        # ROA = 0.05 × 1.538 × 1.3 ≈ 0.1
        result = dupont_3factor(textbook_fin, textbook_bs)
        expected_rona = 100_000.0 / 1_000_000.0  # 0.10
        abs(result.return_on_net_assets - expected_rona) < 0.001
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: Interest burden calculation (EBT / EBIT)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = dupont_5factor(financials, bs, tax_exempt=true)
        # Interest burden = EBT / EBIT = 500k / 1M = 0.5
        expected_ib = 500_000.0 / 1_000_000.0
        abs(result.interest_burden - expected_ib) < 0.001
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: Handles zero/negative EBIT gracefully (sets interest_burden to 1.0)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        zero_ebit = (
            total_operating_revenue = 2_000_000.0,
            ebit = 0.0,
            ebt = -100_000.0,
            net_income = -100_000.0
        )
        result = dupont_5factor(zero_ebit, bs, tax_exempt=true)
        result.interest_burden ≈ 1.0  # Should be set to 1.0, not NaN
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 9: Asset turnover (Revenue / Total Assets)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = dupont_3factor(financials, bs)
        # Total Assets ≈ 2 + 1 + 3 + 0.5 + 40 + 5 = 51.5M
        # ATO = 20M / 51.5M ≈ 0.388
        expected_ato = 20_000_000.0 / (2_000_000 + 1_000_000 + 3_000_000 +
                                       500_000 + 40_000_000 + 5_000_000)
        abs(result.asset_turnover - expected_ato) < 0.001
    end
end
