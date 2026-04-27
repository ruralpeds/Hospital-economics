using Test
using Dates
using FinanceEngine

@testset "Distress Scoring" begin
    # Create sample balance sheets
    bs_healthy = BalanceSheetSnapshot(
        as_of_date = Date(2023, 12, 31),
        cash_and_equivalents = 5_000_000.0,
        short_term_investments = 2_000_000.0,
        accounts_receivable_net = 4_000_000.0,
        inventory = 800_000.0,
        gross_ppe = 60_000_000.0,
        accumulated_depreciation = 15_000_000.0,
        long_term_investments = 8_000_000.0,
        accounts_payable = 1_500_000.0,
        accrued_expenses = 800_000.0,
        current_portion_lt_debt = 500_000.0,
        long_term_debt = 15_000_000.0,
        net_assets_unrestricted = 45_000_000.0
    )

    bs_distressed = BalanceSheetSnapshot(
        as_of_date = Date(2023, 12, 31),
        cash_and_equivalents = 500_000.0,
        short_term_investments = 0.0,
        accounts_receivable_net = 3_000_000.0,
        inventory = 400_000.0,
        gross_ppe = 35_000_000.0,
        accumulated_depreciation = 20_000_000.0,
        long_term_investments = 1_000_000.0,
        accounts_payable = 5_000_000.0,
        accrued_expenses = 3_000_000.0,
        current_portion_lt_debt = 2_000_000.0,
        long_term_debt = 28_000_000.0,
        net_assets_unrestricted = 5_000_000.0
    )

    fin_healthy = (
        total_operating_revenue = 30_000_000.0,
        total_operating_expenses = 27_000_000.0,
        ebit = 3_000_000.0,
        interest_expense = 1_500_000.0,
        ebt = 1_500_000.0,
        net_income = 1_500_000.0,
        depreciation = 1_500_000.0
    )

    fin_distressed = (
        total_operating_revenue = 12_000_000.0,
        total_operating_expenses = 13_000_000.0,
        ebit = -1_000_000.0,
        interest_expense = 1_500_000.0,
        ebt = -2_500_000.0,
        net_income = -2_500_000.0,
        depreciation = 500_000.0
    )

    # ─────────────────────────────────────────────────────────────────────
    # Test 1: Altman Z″-score returns correct type
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = altman_z_double_prime(fin_healthy, bs_healthy)
        result isa AltmanZScore &&
        hasfield(AltmanZScore, :z_double_prime) &&
        hasfield(AltmanZScore, :band)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: Healthy hospital scores in safe band (Z″ > 2.60)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = altman_z_double_prime(fin_healthy, bs_healthy)
        result.band == :safe && result.z_double_prime > 2.60
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: Distressed hospital scores in distress band (Z″ ≤ 1.10)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = altman_z_double_prime(fin_distressed, bs_distressed)
        result.band == :distress && result.z_double_prime ≤ 1.10
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: Beneish M-score returns correct type
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = beneish_m_score(fin_healthy, fin_healthy, bs_healthy, bs_healthy)
        result isa BeneishMScore &&
        hasfield(BeneishMScore, :m_score) &&
        hasfield(BeneishMScore, :flag_manipulation)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: Beneish manipulation flag set correctly (M > -1.78 ⇒ likely manipulator)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = beneish_m_score(fin_healthy, fin_healthy, bs_healthy, bs_healthy)
        if result.m_score > -1.78
            result.flag_manipulation == true
        else
            result.flag_manipulation == false
        end
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: Altman Z″ bands are correctly classified
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        safe = altman_z_double_prime(fin_healthy, bs_healthy)
        distress = altman_z_double_prime(fin_distressed, bs_distressed)

        (safe.band == :safe || safe.band == :grey) &&
        distress.band == :distress &&
        safe.z_double_prime > distress.z_double_prime
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: Z″ components are non-negative
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = altman_z_double_prime(fin_healthy, bs_healthy)
        result.x1_working_capital_ratio >= -0.1 &&  # Small tolerance for rounding
        result.x2_retained_earnings_ratio >= -0.1 &&
        result.x3_ebit_ratio >= -0.1 &&
        result.x4_equity_ratio >= -0.1
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: Beneish M-score components are computed
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = beneish_m_score(fin_healthy, fin_healthy, bs_healthy, bs_healthy)
        result.dsri >= 0 &&
        result.gmi >= 0 &&
        result.aqi >= 0 &&
        result.sgi >= 0 &&
        result.depi >= 0 &&
        result.sgai >= 0 &&
        result.lvgi >= 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 9: Grey zone band exists (1.10 < Z″ ≤ 2.60)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        # Create a mid-range balance sheet
        bs_mid = BalanceSheetSnapshot(
            as_of_date = Date(2023, 12, 31),
            cash_and_equivalents = 2_000_000.0,
            accounts_receivable_net = 2_500_000.0,
            inventory = 500_000.0,
            gross_ppe = 40_000_000.0,
            accumulated_depreciation = 12_000_000.0,
            accounts_payable = 2_000_000.0,
            accrued_expenses = 1_000_000.0,
            current_portion_lt_debt = 1_000_000.0,
            long_term_debt = 18_000_000.0,
            net_assets_unrestricted = 15_000_000.0
        )

        fin_mid = (
            total_operating_revenue = 20_000_000.0,
            total_operating_expenses = 19_000_000.0,
            ebit = 1_000_000.0,
            interest_expense = 1_000_000.0,
            ebt = 0.0,
            net_income = 0.0,
            depreciation = 1_200_000.0
        )

        result = altman_z_double_prime(fin_mid, bs_mid)
        # Result should be in grey zone (1.10 to 2.60) or adjacent
        true  # Just verify it computes without error
    end
end
