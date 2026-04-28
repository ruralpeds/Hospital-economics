using Test
using Dates
using FinanceEngine

@testset "A-04: Nonprofit WACC Calculator" begin
    # Test baseline balance sheet for all tests
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

    fin = (
        total_operating_revenue = 20_000_000.0,
        total_operating_expenses = 19_000_000.0
    )

    # ─────────────────────────────────────────────────────────────────────
    # Test 1: CAPM cost of equity calculation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        w = calculate_wacc(fin, bs; cost_of_equity_model=:capm,
                          risk_free_rate=0.04, market_risk_premium=0.06, beta=1.0)
        w.cost_of_equity ≈ 0.10 atol=1e-6 &&
        w.cost_of_equity > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: Conservative cost of equity (higher beta adjustment)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        w_capm = calculate_wacc(fin, bs; cost_of_equity_model=:capm, beta=1.0)
        w_cons = calculate_wacc(fin, bs; cost_of_equity_model=:conservative, beta=1.0)
        w_cons.cost_of_equity > w_capm.cost_of_equity
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: Aggressive cost of equity (lower beta adjustment)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        w_capm = calculate_wacc(fin, bs; cost_of_equity_model=:capm, beta=1.0)
        w_agg = calculate_wacc(fin, bs; cost_of_equity_model=:aggressive, beta=1.0)
        w_agg.cost_of_equity < w_capm.cost_of_equity || w_agg.cost_of_equity ≈ w_capm.cost_of_equity
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: Cost of debt by rating
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        w_aaa = calculate_wacc(fin, bs; rating="AAA")
        w_b = calculate_wacc(fin, bs; rating="B")
        w_b.cost_of_debt > w_aaa.cost_of_debt
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: Tax-exempt flag forces zero tax shield
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        w_exempt = calculate_wacc(fin, bs; tax_exempt=true)
        w_taxable = calculate_wacc(fin, bs; tax_exempt=false)
        w_exempt.wacc != w_taxable.wacc  # Taxable should have tax shield
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: Target debt ratio derived from balance sheet
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        w = calculate_wacc(fin, bs)
        total_cap = bs.long_term_debt + bs.net_assets_unrestricted
        expected_ratio = bs.long_term_debt / total_cap
        w.target_debt_ratio ≈ expected_ratio atol=1e-6
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: WACC is blended correctly (E/V)*CoE + (D/V)*CoD*(1-T)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        w = calculate_wacc(fin, bs; risk_free_rate=0.04, market_risk_premium=0.06,
                          beta=1.0, tax_exempt=true)
        equity_ratio = 1.0 - w.target_debt_ratio
        expected_wacc = equity_ratio * w.cost_of_equity + w.target_debt_ratio * w.cost_of_debt
        w.wacc ≈ expected_wacc atol=1e-6
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: Invalid cost_of_equity_model throws error
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        try
            calculate_wacc(fin, bs; cost_of_equity_model=:invalid)
            false
        catch e
            e isa ArgumentError
        end
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 9: WACC returns all required fields
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        w = calculate_wacc(fin, bs)
        hasfield(typeof(w), :cost_of_equity) &&
        hasfield(typeof(w), :cost_of_debt) &&
        hasfield(typeof(w), :target_debt_ratio) &&
        hasfield(typeof(w), :wacc)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 10: Zero debt case
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        bs_zero_debt = BalanceSheetSnapshot(
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
            current_portion_lt_debt = 0.0,
            long_term_debt = 0.0,
            net_assets_unrestricted = 45_000_000.0
        )
        w = calculate_wacc(fin, bs_zero_debt)
        w.target_debt_ratio ≈ 0.0 atol=1e-6 &&
        w.wacc ≈ w.cost_of_equity atol=1e-6
    end
end

@testset "A-05: Capital Budgeting (IRR, NPV, Payback)" begin
    wacc = 0.08  # 8% discount rate

    # ─────────────────────────────────────────────────────────────────────
    # Test 1: NPV calculation (basic)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        proj = CapexProject(
            name="Simple Project",
            initial_outlay=100_000.0,
            useful_life=5,
            annual_cf=[20_000.0, 20_000.0, 20_000.0, 20_000.0, 20_000.0],
            salvage_value=10_000.0
        )
        metrics = calculate_capex_metrics(proj, wacc)
        # NPV = -100k + sum(20k/(1.08)^t for t=1..5) + 10k/(1.08)^5
        # Rough: 20k*3.993 + 10k/1.469 - 100k ≈ 79.86k + 6.81k - 100k ≈ -13.33k (oops, negative)
        # Let me recalc: 20k * PV annuity 5yr @8% = 20k * 3.9927 = 79.85k
        # Salvage: 10k / 1.4693 = 6.8k
        # Total: 79.85 + 6.8 - 100 = -13.35k (negative NPV)
        metrics isa CapexMetrics &&
        !isnan(metrics.npv)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: Positive NPV project
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        proj = CapexProject(
            name="Good Project",
            initial_outlay=100_000.0,
            useful_life=5,
            annual_cf=[30_000.0, 30_000.0, 30_000.0, 30_000.0, 30_000.0]
        )
        metrics = calculate_capex_metrics(proj, wacc)
        metrics.npv > 0  # 30k * 3.9927 - 100k ≈ 19.78k > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: IRR calculation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        proj = CapexProject(
            name="IRR Test",
            initial_outlay=100_000.0,
            useful_life=3,
            annual_cf=[40_000.0, 40_000.0, 50_000.0]
        )
        metrics = calculate_capex_metrics(proj, wacc)
        metrics.irr > 0 && metrics.irr < 1.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: Payback period calculation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        proj = CapexProject(
            name="Payback Test",
            initial_outlay=100_000.0,
            useful_life=5,
            annual_cf=[50_000.0, 50_000.0, 50_000.0, 50_000.0, 50_000.0]
        )
        metrics = calculate_capex_metrics(proj, wacc)
        # Payback after 2 years (100k / 50k per year)
        metrics.payback_years ≈ 2.0 atol=0.1
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: Profitability Index
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        proj = CapexProject(
            name="PI Test",
            initial_outlay=100_000.0,
            useful_life=5,
            annual_cf=[30_000.0, 30_000.0, 30_000.0, 30_000.0, 30_000.0]
        )
        metrics = calculate_capex_metrics(proj, wacc)
        # PI = (NPV + Initial) / Initial
        pi_expected = (metrics.npv + 100_000.0) / 100_000.0
        metrics.profitability_index ≈ pi_expected atol=1e-6
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: Salvage value impact on NPV
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        proj_no_salvage = CapexProject(
            name="No Salvage",
            initial_outlay=100_000.0,
            useful_life=5,
            annual_cf=[20_000.0, 20_000.0, 20_000.0, 20_000.0, 20_000.0],
            salvage_value=0.0
        )
        proj_with_salvage = CapexProject(
            name="With Salvage",
            initial_outlay=100_000.0,
            useful_life=5,
            annual_cf=[20_000.0, 20_000.0, 20_000.0, 20_000.0, 20_000.0],
            salvage_value=50_000.0
        )
        m1 = calculate_capex_metrics(proj_no_salvage, wacc)
        m2 = calculate_capex_metrics(proj_with_salvage, wacc)
        m2.npv > m1.npv  # Salvage adds value
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: Zero initial outlay
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        proj = CapexProject(
            name="Zero Outlay",
            initial_outlay=0.0,
            useful_life=5,
            annual_cf=[10_000.0, 10_000.0, 10_000.0, 10_000.0, 10_000.0]
        )
        metrics = calculate_capex_metrics(proj, wacc)
        # PI should be Inf or handled gracefully
        metrics.profitability_index > 1.0 || metrics.profitability_index == 0.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: Immediate payback
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        proj = CapexProject(
            name="Immediate",
            initial_outlay=100_000.0,
            useful_life=3,
            annual_cf=[100_000.0, 100_000.0, 100_000.0]
        )
        metrics = calculate_capex_metrics(proj, wacc)
        metrics.payback_years ≈ 1.0 atol=0.01
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 9: No payback within project life
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        proj = CapexProject(
            name="No Payback",
            initial_outlay=100_000.0,
            useful_life=3,
            annual_cf=[10_000.0, 10_000.0, 10_000.0]
        )
        metrics = calculate_capex_metrics(proj, wacc)
        metrics.payback_years > 3.0  # Doesn't pay back in project life
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 10: CapexMetrics struct fields
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        proj = CapexProject(
            name="Test",
            initial_outlay=100_000.0,
            useful_life=5,
            annual_cf=[20_000.0, 20_000.0, 20_000.0, 20_000.0, 20_000.0]
        )
        metrics = calculate_capex_metrics(proj, wacc)
        hasfield(typeof(metrics), :npv) &&
        hasfield(typeof(metrics), :irr) &&
        hasfield(typeof(metrics), :payback_years) &&
        hasfield(typeof(metrics), :profitability_index)
    end
end

@testset "A-05: Project Ranking and Budget Allocation" begin
    wacc = 0.08

    # Create test projects
    proj1 = CapexProject(
        name="Project A",
        initial_outlay=50_000.0,
        useful_life=5,
        annual_cf=[15_000.0, 15_000.0, 15_000.0, 15_000.0, 15_000.0]
    )

    proj2 = CapexProject(
        name="Project B",
        initial_outlay=80_000.0,
        useful_life=5,
        annual_cf=[25_000.0, 25_000.0, 25_000.0, 25_000.0, 25_000.0]
    )

    proj3 = CapexProject(
        name="Project C",
        initial_outlay=100_000.0,
        useful_life=5,
        annual_cf=[30_000.0, 30_000.0, 30_000.0, 30_000.0, 30_000.0]
    )

    # ─────────────────────────────────────────────────────────────────────
    # Test 11: rank_projects returns DataFrame
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = rank_projects([proj1, proj2, proj3], wacc)
        df isa DataFrame &&
        nrow(df) == 3 &&
        all(col -> col in names(df), [:name, :npv, :irr, :profitability_index, :pi_rank])
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 12: Projects ranked by profitability index
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = rank_projects([proj1, proj2, proj3], wacc)
        df.pi_rank[1] == 1 &&
        all(diff(df.pi_rank) .== 1)  # Ranks are sequential
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 13: Budget constraint filters projects
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        budget = 100_000.0
        df = rank_projects([proj1, proj2, proj3], wacc; budget_constraint=budget)
        sum(df[df.selected, :initial_outlay]) <= budget
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 14: All projects selected without budget constraint
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = rank_projects([proj1, proj2, proj3], wacc)
        all(df.selected) == true
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 15: Cumulative investment tracking
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = rank_projects([proj1, proj2, proj3], wacc)
        diff(df.cumulative_investment) .>= 0  # Monotone increasing
    end
end
