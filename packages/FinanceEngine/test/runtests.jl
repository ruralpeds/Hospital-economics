using Test
using FinanceEngine

# Include enterprise pattern tests
include("error_tests.jl")
include("audit_tests.jl")

@testset "FinanceEngine" begin
    @testset "NPV" begin
        @test npv(0.1, [100.0, 200.0, 300.0]) ≈ 100/1.1 + 200/1.21 + 300/1.331 atol=0.01
        @test npv(0.0, [100.0]) ≈ 100.0
    end

    @testset "NPV — single cashflow" begin
        @test npv(0.05, [200.0]) ≈ 200.0 / 1.05 atol=1e-10
    end

    @testset "NPV — zero rate returns sum of cashflows" begin
        cfs = [100.0, 200.0, 300.0]
        @test npv(0.0, cfs) ≈ sum(cfs) atol=1e-10
    end

    @testset "NPV — negative cashflow (outflow)" begin
        # Investment followed by returns
        cfs = [-500.0, 200.0, 200.0, 200.0]
        result = npv(0.05, cfs)
        @test result ≈ -500/1.05 + 200/1.05^2 + 200/1.05^3 + 200/1.05^4 atol=0.01
    end

    @testset "ROI" begin
        @test roi(150.0, 100.0) ≈ 0.5
        @test_throws ArgumentError roi(100.0, 0.0)
    end

    @testset "ROI — loss scenario" begin
        # Gain < Cost → negative ROI
        @test roi(50.0, 100.0) ≈ -0.5
    end

    @testset "ROI — break-even" begin
        @test roi(100.0, 100.0) ≈ 0.0
    end

    @testset "Operating Margin" begin
        @test operating_margin(1000.0, 800.0) ≈ 0.2
        @test_throws ArgumentError operating_margin(0.0, 100.0)
    end

    @testset "Operating Margin — negative margin (loss)" begin
        @test operating_margin(1000.0, 1200.0) ≈ -0.2
    end

    @testset "Cost Per Patient" begin
        @test cost_per_patient(10000.0, 100.0) ≈ 100.0
        @test_throws ArgumentError cost_per_patient(100.0, 0.0)
    end

    @testset "Break Even" begin
        @test break_even_units(10000.0, 200.0, 100.0) ≈ 100.0
        @test_throws ArgumentError break_even_units(100.0, 50.0, 50.0)
    end

    @testset "Break Even — negative contribution margin throws" begin
        @test_throws ArgumentError break_even_units(1000.0, 50.0, 80.0)
    end

    @testset "Payback Period" begin
        @test payback_period(100.0, [50.0, 50.0, 50.0]) ≈ 2.0
        @test ismissing(payback_period(1000.0, [10.0, 10.0]))
    end

    @testset "Payback Period — exact period boundary" begin
        # 100 investment, 100/period cashflow → repaid in exactly 1 period
        @test payback_period(100.0, [100.0, 100.0]) ≈ 1.0
    end

    @testset "Payback Period — zero investment" begin
        # No investment → paid back immediately (fraction 0.0 in period 1)
        @test payback_period(0.0, [50.0, 50.0]) ≈ 0.0
    end

    @testset "Payback Period — partial period" begin
        # 75 investment, [50, 50] cashflows → paid back halfway through period 2
        @test payback_period(75.0, [50.0, 50.0]) ≈ 1.5
    end

    @testset "DRG Revenue" begin
        @test drg_revenue(5000.0, 1.5, 10) ≈ 75000.0
    end

    @testset "DRG Revenue — unit case" begin
        @test drg_revenue(1000.0, 1.0, 1) ≈ 1000.0
    end

    @testset "Weighted Payer Rate" begin
        @test weighted_payer_rate([100.0, 80.0], [0.6, 0.4]) ≈ 92.0
    end

    @testset "Weighted Payer Rate — mismatched lengths throws" begin
        @test_throws ArgumentError weighted_payer_rate([100.0, 80.0], [0.5])
    end

    @testset "Weighted Payer Rate — single payer" begin
        @test weighted_payer_rate([90.0], [1.0]) ≈ 90.0
    end

    @testset "Net Collection Rate" begin
        @test net_collection_rate(90.0, 100.0, 0.0) ≈ 0.9
    end

    @testset "Net Collection Rate — with contractual adjustments" begin
        # payments=80, charges=100, adjustments=20 → denominator=80 → rate=1.0
        @test net_collection_rate(80.0, 100.0, 20.0) ≈ 1.0
    end

    @testset "Net Collection Rate — zero denominator throws" begin
        @test_throws ArgumentError net_collection_rate(50.0, 100.0, 100.0)
    end

    @testset "Econometrics — perfect linear fit" begin
        x = [1.0, 2.0, 3.0, 4.0, 5.0]
        y = [2.0, 4.0, 6.0, 8.0, 10.0]
        m = simple_linear_regression(x, y)
        @test m.slope ≈ 2.0 atol=1e-10
        @test m.intercept ≈ 0.0 atol=1e-10

        preds = predict_linear(m, x)
        @test r_squared(y, preds) ≈ 1.0 atol=1e-10
        @test mean_absolute_error(y, preds) ≈ 0.0 atol=1e-10
    end

    @testset "Econometrics — negative slope" begin
        x = [1.0, 2.0, 3.0, 4.0, 5.0]
        y = [10.0, 8.0, 6.0, 4.0, 2.0]
        m = simple_linear_regression(x, y)
        @test m.slope ≈ -2.0 atol=1e-10
        @test m.intercept ≈ 12.0 atol=1e-10
    end

    @testset "Econometrics — identical x values throws" begin
        @test_throws ArgumentError simple_linear_regression(
            [1.0, 1.0, 1.0], [2.0, 3.0, 4.0])
    end

    @testset "Econometrics — length mismatch throws" begin
        @test_throws ArgumentError simple_linear_regression([1.0, 2.0], [1.0, 2.0, 3.0])
    end

    @testset "Econometrics — single observation throws" begin
        @test_throws ArgumentError simple_linear_regression([1.0], [2.0])
    end

    @testset "Econometrics — r_squared constant true values throws" begin
        @test_throws ArgumentError r_squared([5.0, 5.0, 5.0], [5.0, 5.0, 5.0])
    end

    @testset "Econometrics — mean_absolute_error perfect" begin
        @test mean_absolute_error([1.0, 2.0, 3.0], [1.0, 2.0, 3.0]) ≈ 0.0
    end

    @testset "Econometrics — mean_absolute_error length mismatch" begin
        @test_throws ArgumentError mean_absolute_error([1.0, 2.0], [1.0])
    end

    @testset "Simulation" begin
        result = monte_carlo_mean(() -> 1.0, 100)
        @test result ≈ 1.0

        growth = simulate_growth(100.0, 0.1, 3)
        @test length(growth) == 3
        @test growth[1] ≈ 110.0

        # ARMA Forecasting
        # Create synthetic AR(1) data: y_t = 0.7*y_{t-1} + noise
        historical = [100.0]
        for _ in 1:29
            push!(historical, 0.7 * historical[end] + randn() * 5)
        end

        forecast_result = arma_forecast(historical, 1, 0, 12; n_bootstrap=100)
        @test length(forecast_result.point_forecast) == 12
        @test length(forecast_result.ci_lower) == 12
        @test length(forecast_result.ci_upper) == 12
        @test all(forecast_result.ci_lower .<= forecast_result.point_forecast)
        @test all(forecast_result.point_forecast .<= forecast_result.ci_upper)

        # ARMA stochastic paths
        paths = arma_stochastic_paths(historical, 1, 0, 24; n_paths=100)
        @test size(paths) == (100, 24)
    end

    @testset "Simulation — growth compounding" begin
        g = simulate_growth(100.0, 0.1, 3)
        @test g[1] ≈ 110.0
        @test g[2] ≈ 121.0
        @test g[3] ≈ 133.1 atol=1e-10
    end

    @testset "Simulation — zero periods returns empty" begin
        @test isempty(simulate_growth(100.0, 0.1, 0))
    end

    @testset "Simulation — monte_carlo_mean n=0 throws" begin
        @test_throws ArgumentError monte_carlo_mean(() -> 1.0, 0)
    end

    @testset "Value-Based Care" begin
        @test value_score(80.0, 100.0) ≈ 0.8
        @test qalys(10.0, 0.8) ≈ 8.0
    end

    @testset "Optimization" begin
        # Test Rouwenhorst grid
        grid, Π = rouwenhorst_grid(5, 0.8, 0.1)
        @test length(grid) == 5
        @test size(Π) == (5, 5)
        @test all(sum(Π, dims=2) .≈ 1.0)  # Rows sum to 1

        # Test bed expansion
        result = optimal_bed_expansion(
            initial_beds=20,
            min_beds=10,
            max_beds=40,
            demand_states=10,
            discount_rate=0.05
        )
        @test size(result.policy) == (31, 10)  # 31 bed states × 10 demand states
        @test size(result.value) == (31, 10)
        @test length(result.demand_grid) == 10
        @test size(result.demand_trans) == (10, 10)

        # Test staffing optimization
        result_staff = optimal_staffing(
            initial_fte=50,
            min_fte=25,
            max_fte=75,
            demand_states=10,
            discount_rate=0.05
        )
        @test size(result_staff.policy) == (51, 10)  # 51 FTE states × 10 demand states
        @test size(result_staff.value) == (51, 10)
        @test length(result_staff.fte_states) == 51
    end

    @testset "Financial Monitoring" begin
        # Test Kalman filter initialization
        kf = initialize_kalman(0.20, 0.05^2, 0.01^2, 0.02^2)
        @test kf.x ≈ 0.20
        @test kf.A == 1.0
        @test kf.C == 1.0

        # Test Kalman filter step
        result = kalman_filter_step(kf, 0.19)
        @test result.state_estimate ≈ kf.x
        @test result.uncertainty > 0

        # Test margin tracker
        margins = [0.20, 0.19, 0.195, 0.18, 0.17, 0.16]
        tracking = margin_tracker(margins)
        @test length(tracking.state_estimates) == 6
        @test length(tracking.uncertainties) == 6
        @test length(tracking.innovations) == 6
        @test length(tracking.trends) == 6
        @test length(tracking.cycles) == 6

        # Test early warning signal
        warning = early_warning_signal(margins)
        @test haskey(warning, :alert_level)
        @test warning.alert_level in ["green", "yellow", "red"]
        @test warning.estimated_margin > 0
        @test length(warning.margin_ci) == 2

        # Test Hamilton filter
        revenues = [10.0 + 0.5*i + randn()*0.3 for i in 1:20]
        hf_result = hamilton_filter(revenues, 4)
        @test length(hf_result.trend) == 20
        @test length(hf_result.cycle) == 20

        # Test liquidity forecast
        forecast = liquidity_forecast(
            margins,
            monthly_revenue = 2_000_000,
            cash_balance = 500_000
        )
        @test length(forecast.projected_margins) == 6
        @test length(forecast.projected_cash) == 6
        @test haskey(forecast, :months_to_stress)
        @test haskey(forecast, :stress_risk)
    end

    # ── Capital Structure additions ────────────────────────────────────────

    @testset "IRR — basic project" begin
        # -100 now, +60 in period 1, +60 in period 2 → IRR ≈ 13.07%
        cfs = [-100.0, 60.0, 60.0]
        r = irr(cfs)
        @test !ismissing(r)
        @test r ≈ 0.1307 atol=1e-4
    end

    @testset "IRR — no real root returns missing" begin
        # All positive cash flows — no crossover
        @test ismissing(irr([10.0, 20.0, 30.0]))
    end

    @testset "IRR — single cashflow throws" begin
        @test_throws Exception irr([-100.0])
    end

    @testset "MIRR — standard case" begin
        cfs = [-100.0, 50.0, 60.0, 70.0]
        r = mirr(cfs, 0.08, 0.12)
        @test r > 0.0
        @test r ≈ (70.0*(1.12)^0 + 60.0*(1.12)^1 + 50.0*(1.12)^2)^(1/3) /
                  (100.0 / (1.08)^0)^(1/3) - 1 atol=0.01
    end

    @testset "MIRR — no negative flows throws" begin
        @test_throws Exception mirr([10.0, 20.0, 30.0], 0.08, 0.12)
    end

    @testset "Discounted Payback — recovers within horizon" begin
        # -100 at t=0, +60 discounted, +60 discounted
        cfs = [-100.0, 60.0, 60.0]
        dpp = discounted_payback_period(cfs, 0.10)
        @test isfinite(dpp)
        @test dpp > 1.0 && dpp < 3.0
    end

    @testset "Discounted Payback — never recovers returns Inf" begin
        @test discounted_payback_period([-1000.0, 1.0, 1.0], 0.10) == Inf
    end

    @testset "Interest Coverage Ratio" begin
        @test interest_coverage_ratio(4_000_000.0, 1_000_000.0) ≈ 4.0
        @test_throws Exception interest_coverage_ratio(1_000_000.0, 0.0)
    end

    @testset "Interest Coverage Ratio — below lender threshold" begin
        # ICR < 2.5 is typically a covenant concern
        @test interest_coverage_ratio(200_000.0, 100_000.0) ≈ 2.0
    end

    @testset "Profitability Index — value-creating project" begin
        @test profitability_index(50_000.0, 100_000.0) ≈ 1.5
    end

    @testset "Profitability Index — zero NPV project" begin
        @test profitability_index(0.0, 100_000.0) ≈ 1.0
    end

    @testset "Profitability Index — negative initial investment throws" begin
        @test_throws Exception profitability_index(50_000.0, 0.0)
    end

    @testset "Modified Duration — two-period bond" begin
        cfs = [50.0, 1050.0]  # coupon + principal
        d = modified_duration(cfs, 0.05)
        @test d > 0.0
        @test d < 2.0  # duration < maturity
    end

    @testset "Modified Duration — empty cashflows throws" begin
        @test_throws Exception modified_duration(Float64[], 0.05)
    end

    @testset "Lease vs Buy — lease preferred" begin
        # Low lease payments → lease wins
        r = lease_vs_buy(100_000.0, [8_000.0, 8_000.0, 8_000.0, 8_000.0, 8_000.0],
                         10_000.0, 0.08, 5)
        @test r.preferred == :lease
        @test r.lease_pv < r.buy_pv
    end

    @testset "Lease vs Buy — nonprofit tax_rate=0 default" begin
        r = lease_vs_buy(50_000.0, [12_000.0, 12_000.0, 12_000.0],
                         5_000.0, 0.06, 3)
        @test r.buy_pv > 0
        @test r.preferred in (:lease, :buy)
    end

    @testset "Lease vs Buy — invalid asset cost throws" begin
        @test_throws Exception lease_vs_buy(0.0, [1000.0], 0.0, 0.05, 5)
    end

    # ── Budgeting ──────────────────────────────────────────────────────────

    @testset "Operating Budget — basic" begin
        b = operating_budget(50_000.0, 200.0, 100.0, 500.0)
        @test b.revenue ≈ 50_000.0
        @test b.variable_costs ≈ 20_000.0
        @test b.fixed_costs ≈ 50_000.0
        @test b.total_costs ≈ 70_000.0
        @test b.operating_income ≈ -20_000.0
    end

    @testset "Operating Budget — other revenue" begin
        b = operating_budget(10_000.0, 50.0, 100.0, 200.0; other_revenue=5_000.0)
        @test b.revenue ≈ 25_000.0
    end

    @testset "Flex Budget — equals operating budget at actual volume" begin
        orig = operating_budget(10_000.0, 100.0, 200.0, 300.0)
        flex = flex_budget(10_000.0, 100.0, 180.0, 300.0)
        @test flex.revenue ≈ 54_000.0
        @test flex.variable_costs ≈ 18_000.0
        @test orig.fixed_costs == flex.fixed_costs
    end

    @testset "Volume Variance — favorable" begin
        @test volume_variance(50.0, 110.0, 100.0) ≈ 500.0
    end

    @testset "Volume Variance — unfavorable" begin
        @test volume_variance(50.0, 90.0, 100.0) ≈ -500.0
    end

    @testset "Price Variance" begin
        @test price_variance(210.0, 200.0, 100.0) ≈ 1_000.0
    end

    @testset "Efficiency Variance — overuse unfavorable" begin
        @test efficiency_variance(20.0, 550.0, 5.0, 100.0) ≈ 1_000.0
    end

    @testset "Mix Variance — equal mix has zero variance" begin
        mv = mix_variance([50.0, 50.0], [50.0, 50.0], [100.0, 80.0])
        @test mv.total_mix_variance ≈ 0.0 atol=1e-10
    end

    @testset "Mix Variance — length mismatch throws" begin
        @test_throws Exception mix_variance([1.0, 2.0], [1.0], [10.0, 10.0])
    end

    @testset "Rate Volume Variance — decomposition" begin
        rv = rate_volume_variance(210_000.0, 200_000.0, 110.0, 100.0, 2_000.0)
        @test rv.total_variance ≈ 10_000.0
        @test rv.volume_variance ≈ 20_000.0
        @test rv.rate_variance ≈ -10_000.0
    end

    @testset "Budget to Actual Variance — under budget" begin
        v = budget_to_actual_variance(100_000.0, 90_000.0)
        @test v.dollar_variance ≈ 10_000.0
        @test v.pct_variance ≈ 0.10
    end

    @testset "Budget to Actual Variance — zero budget throws" begin
        @test_throws Exception budget_to_actual_variance(0.0, 50_000.0)
    end

    @testset "Capital Budget Rank — highest NPV + strategic wins" begin
        projects = [
            (name="MRI",  npv=500_000.0, strategic_score=8.0),
            (name="EHR",  npv=200_000.0, strategic_score=9.0),
            (name="Boiler", npv=50_000.0, strategic_score=3.0),
        ]
        ranked = capital_budget_rank(projects)
        @test length(ranked) == 3
        @test ranked[1].name in ("MRI", "EHR")
        @test ranked[end].name == "Boiler"
    end

    @testset "Capital Budget Rank — empty throws" begin
        @test_throws Exception capital_budget_rank([])
    end

    @testset "Capital Budget Rank — weights not summing to 1 throws" begin
        projects = [(name="X", npv=100.0, strategic_score=5.0)]
        @test_throws Exception capital_budget_rank(projects; npv_weight=0.5, strategic_weight=0.4)
    end

    @testset "Zero Based Budget Score — valid" begin
        s = zero_based_budget_score(8.0, 7.0, 6.0)
        @test s ≈ 0.4*8.0 + 0.3*7.0 + 0.3*6.0 atol=1e-10
    end

    @testset "Zero Based Budget Score — out of range throws" begin
        @test_throws Exception zero_based_budget_score(11.0, 5.0, 5.0)
    end

    @testset "Rolling Forecast Update — on pace" begin
        r = rolling_forecast_update(500_000.0, 6, 12, 1_000_000.0)
        @test r.projected_annual ≈ 1_000_000.0
        @test r.variance_to_budget ≈ 0.0 atol=1e-10
        @test r.pct_variance ≈ 0.0 atol=1e-10
    end

    @testset "Rolling Forecast Update — over budget" begin
        r = rolling_forecast_update(600_000.0, 6, 12, 1_000_000.0)
        @test r.projected_annual ≈ 1_200_000.0
        @test r.variance_to_budget ≈ -200_000.0
        @test r.pct_variance ≈ -0.20 atol=1e-10
    end

    @testset "Rolling Forecast Update — elapsed ≥ total throws" begin
        @test_throws Exception rolling_forecast_update(100.0, 12, 12, 1000.0)
    end

    @testset "Strategic Planning" begin
        # Test cost trajectory
        result = cost_trajectory(
            current_cost = 50_000_000,
            target_cost = 45_000_000,
            horizon = 3,
            adjustment_cost = 0.5
        )
        @test length(result.optimal_costs) == 3
        @test length(result.required_reductions) == 3
        @test result.optimal_costs[1] > 45_000_000  # Should approach target gradually
        @test result.optimal_costs[end] <= 45_000_000 + 100_000  # Should hit target

        # Test merger integration plan
        result_merger = merger_integration_plan(
            hospital_a_cost = 30_000_000,
            hospital_b_cost = 20_000_000,
            synergy_target = 8_000_000,
            integration_horizon = 2,
            disruption_penalty = 0.3
        )
        @test result_merger.combined_cost == 50_000_000
        @test result_merger.target_cost == 42_000_000
        @test length(result_merger.optimal_path) == 2
        @test haskey(result_merger, :recommendation)

        # Test restructuring plan
        result_restr = restructuring_plan(
            current_margin = 0.05,
            target_margin = 0.10,
            annual_revenue = 100_000_000,
            time_horizon = 3,
            max_annual_cost_cut = 0.05
        )
        @test length(result_restr.optimal_path) == 3
        @test length(result_restr.required_improvements) == 3
        @test result_restr.feasibility_score >= 0
        @test result_restr.feasibility_score <= 1.0

        # Test revenue enhancement plan
        result_rev = revenue_enhancement_plan(
            current_revenue = 100_000_000,
            target_revenue = 120_000_000,
            current_margin = 0.05,
            time_horizon = 3,
            growth_initiative_weight = 0.15
        )
        @test length(result_rev.optimal_path) == 3
        @test length(result_rev.annual_growth) == 3
        @test sum(result_rev.annual_growth) > 0
    end

    # ── Accounting ─────────────────────────────────────────────────────────

    @testset "Income Statement" begin
        s = income_statement(10_000_000.0, 2_000_000.0, 100_000.0,
                             50_000.0, 7_000_000.0; other_income=200_000.0)
        @test s.net_patient_revenue ≈ 7_850_000.0
        @test s.total_operating_revenue ≈ 8_050_000.0
        @test s.operating_income ≈ 1_050_000.0
        @test s.total_margin ≈ 1_050_000.0 / 8_050_000.0 atol=1e-10
    end

    @testset "Income Statement — zero gross_revenue throws" begin
        @test_throws ArgumentError income_statement(0.0, 0.0, 0.0, 0.0, 0.0)
    end

    @testset "EBITDA" begin
        @test ebitda(500_000.0, 300_000.0, 50_000.0) ≈ 850_000.0
        @test ebitda(500_000.0, 300_000.0) ≈ 800_000.0  # default amortization=0
    end

    @testset "EBITDA Margin" begin
        @test ebitda_margin(800_000.0, 10_000_000.0) ≈ 0.08
        @test_throws ArgumentError ebitda_margin(100.0, 0.0)
    end

    @testset "Total Margin (accounting)" begin
        @test total_margin(200_000.0, 10_000_000.0) ≈ 0.02
        @test_throws ArgumentError total_margin(100.0, 0.0)
    end

    @testset "Operating Margin HFMA" begin
        @test operating_margin_hfma(300_000.0, 10_000_000.0) ≈ 0.03
    end

    @testset "Operating Leverage" begin
        @test operating_leverage(1_000_000.0, 500_000.0) ≈ 2.0
        @test_throws ArgumentError operating_leverage(500_000.0, 0.0)
    end

    @testset "Quick Ratio" begin
        @test quick_ratio(1_000_000.0, 2_000_000.0) ≈ 0.5
        @test_throws ArgumentError quick_ratio(100.0, 0.0)
    end

    @testset "Debt to Equity" begin
        @test debt_to_equity(4_000_000.0, 6_000_000.0) ≈ 4/6 atol=1e-10
        @test_throws ArgumentError debt_to_equity(1.0, 0.0)
    end

    @testset "Equity Multiplier" begin
        @test equity_multiplier(10_000_000.0, 6_000_000.0) ≈ 10/6 atol=1e-10
    end

    @testset "Cash Flow Indirect" begin
        cf = cash_flow_indirect(500_000.0, 200_000.0, 50_000.0,
                                100_000.0, 80_000.0, 20_000.0, 300_000.0)
        @test cf.operating ≈ 500_000 + 200_000 + 50_000 - 100_000 + 80_000 - 20_000
        @test cf.investing ≈ -300_000.0
        @test cf.net_change ≈ cf.operating + cf.investing
    end

    @testset "Straight Line Depreciation" begin
        @test straight_line_depreciation(100_000.0, 10_000.0, 10) ≈ 9_000.0
        @test_throws ArgumentError straight_line_depreciation(100.0, 200.0, 5)
    end

    @testset "MACRS Depreciation — 5-year" begin
        schedule = macrs_depreciation_schedule(100_000.0, 5)
        @test length(schedule) == 6
        @test sum(schedule) ≈ 100_000.0 atol=1.0
        @test schedule[1] ≈ 20_000.0
    end

    @testset "MACRS Depreciation — unsupported class throws" begin
        @test_throws ArgumentError macrs_depreciation_schedule(100_000.0, 3)
    end

    @testset "Net Assets Change" begin
        @test net_assets_change(5_000_000.0, 300_000.0, 100_000.0) ≈ 5_400_000.0
    end

    @testset "Fund Accounting Summary" begin
        s = fund_accounting_summary(3_000_000.0, 1_000_000.0, 500_000.0)
        @test s.total_net_assets ≈ 4_500_000.0
        @test s.unrestricted_fraction ≈ 3/4.5 atol=1e-10
    end

    @testset "Charitable Community Benefit Rate" begin
        @test charitable_community_benefit_rate(500_000.0, 10_000_000.0) ≈ 0.05
        @test_throws ArgumentError charitable_community_benefit_rate(100.0, 0.0)
    end

    # ── Actuarial ──────────────────────────────────────────────────────────

    @testset "Loss Development Factors — 3×3 triangle" begin
        tri = Float64[100 150 180;
                      120 170   0;
                      130   0   0]
        ldfs = loss_development_factors(tri)
        @test length(ldfs) == 2
        @test ldfs[1] ≈ (150 + 170) / (100 + 120) atol=1e-10
    end

    @testset "Claims Triangle Development" begin
        tri = Float64[100 150 180;
                      120 170   0;
                      130   0   0]
        dev = claims_triangle_development(tri)
        @test dev[2, 3] ≈ 170 * (180/150) atol=0.01
        @test dev[3, 2] ≈ 130 * ((150+170)/(100+120)) atol=0.01
    end

    @testset "IBNR Reserve" begin
        tri = Float64[100 150 180;
                      120 170   0;
                      130   0   0]
        reserves = ibnr_reserve(tri)
        @test length(reserves) == 3
        @test reserves[1] ≈ 0.0 atol=0.01  # fully developed
        @test reserves[2] > 0
        @test reserves[3] > 0
    end

    @testset "HCC Risk Score (actuarial numeric)" begin
        @test hcc_risk_score(0.8, [0.3, 0.2]) ≈ 1.3
        @test hcc_risk_score(0.8, [0.3, 0.2]; normalization_factor=1.1) ≈ 1.3/1.1 atol=1e-10
        @test_throws ArgumentError hcc_risk_score(0.8, [0.3]; normalization_factor=0.0)
    end

    @testset "HCC Prospective Score" begin
        @test hcc_prospective_score(1.2, 1.05) ≈ 1.26
    end

    @testset "PMPM by Category" begin
        cats = pmpm_by_category([12_000.0, 8_000.0], ["IP", "OP"], 100.0)
        @test length(cats) == 2
        @test cats[1].pmpm ≈ 120.0
    end

    @testset "Admin Expense Ratio" begin
        @test admin_expense_ratio(150_000.0, 1_000_000.0) ≈ 0.15
    end

    @testset "Premium Rate Development" begin
        p = premium_rate_development(300.0, 0.15, 0.05)
        @test p ≈ 300.0 / 0.80 atol=1e-10
        @test_throws ArgumentError premium_rate_development(300.0, 0.6, 0.5)
    end

    @testset "Utilization Rate" begin
        @test utilization_rate(80.0, 1200.0) ≈ 80/1200*1000 atol=1e-10
    end

    @testset "Admissions per Thousand" begin
        @test admissions_per_thousand(100.0, 1000.0) ≈ 1200.0
    end

    @testset "Claim Frequency and Severity" begin
        @test claim_frequency(500.0, 1000.0) ≈ 0.5
        @test claim_severity(250_000.0, 500.0) ≈ 500.0
        @test pure_premium(0.5, 500.0) ≈ 250.0
    end

    @testset "Credibility Weight" begin
        @test credibility_weight(1082.0) ≈ 1.0
        @test credibility_weight(270.5) ≈ 0.5 atol=1e-4
        @test credibility_weight(0.0) ≈ 0.0
    end

    @testset "Blended Rate" begin
        @test blended_rate(100.0, 80.0, 0.75) ≈ 95.0
        @test_throws ArgumentError blended_rate(100.0, 80.0, 1.5)
    end

    # ── Reimbursement ──────────────────────────────────────────────────────

    @testset "DRG Payment" begin
        @test drg_payment(6000.0, 1.5, 10) ≈ 90_000.0
        @test drg_payment(6000.0, 1.5, 10; outlier_threshold=500.0, outlier_rate=0.8) ≈ 94_000.0
    end

    @testset "MS-DRG Payment" begin
        p = ms_drg_payment(6000.0, 1.5, 5, :none; wage_index=0.95)
        @test p > 0
        @test_throws ArgumentError ms_drg_payment(6000.0, 1.5, 5, :invalid)
    end

    @testset "APR-DRG Payment — severity adjustors" begin
        base = apr_drg_payment(5000.0, 1.0, 2, 1)  # severity 2 = weight 1.0
        high = apr_drg_payment(5000.0, 1.0, 4, 1)  # severity 4 = weight 2.2
        @test high > base
        @test high ≈ 5000.0 * 2.2
        @test_throws ArgumentError apr_drg_payment(5000.0, 1.0, 5, 1)
    end

    @testset "OPPS APC Payment" begin
        @test opps_apc_payment(80.0, 2.5, 100) ≈ 20_000.0
    end

    @testset "RVU to Payment" begin
        @test rvu_to_payment(2.0, 1.5, 0.5, 36.0) ≈ (2.0+1.5+0.5)*36.0
    end

    @testset "RBRVS Payment — multiple units" begin
        single = rvu_to_payment(2.0, 1.0, 0.5, 36.0)
        @test rbrvs_payment(2.0, 1.0, 0.5, 36.0, 3) ≈ single * 3
    end

    @testset "Capitation PMPM" begin
        @test capitation_pmpm(1_200_000.0, 1000.0) ≈ 1200.0
    end

    @testset "PMPM Trend" begin
        @test pmpm_trend(100.0, 0.05, 12) ≈ 100.0 * (1.05)^12 atol=1e-10
    end

    @testset "Revenue Cycle KPIs" begin
        @test days_in_ar(2_000_000.0, 50_000.0) ≈ 40.0
        @test denial_rate(150, 5000) ≈ 0.03
        @test clean_claim_rate(4900, 5000) ≈ 0.98
        @test gross_collection_rate(800_000.0, 1_000_000.0) ≈ 0.80
        @test cash_collection_efficiency(1_020_000.0, 1_000_000.0) ≈ 1.02
        @test bad_debt_rate(50_000.0, 1_000_000.0) ≈ 0.05
        @test charity_care_rate(30_000.0, 600_000.0) ≈ 0.05
        @test uncompensated_care_rate(50_000.0, 30_000.0, 1_000_000.0) ≈ 0.08
    end

    @testset "Revenue Cycle Scorecard — exceeds" begin
        s = revenue_cycle_scorecard(days_ar=38.0, denial_rt=0.02,
                                    clean_claim_rt=0.99, cash_efficiency=1.03)
        @test s.days_ar == :exceeds
        @test s.denial_rate == :exceeds
        @test s.clean_claim_rate == :exceeds
        @test s.cash_efficiency == :exceeds
    end

    @testset "Revenue Cycle Scorecard — below" begin
        s = revenue_cycle_scorecard(days_ar=60.0, denial_rt=0.08,
                                    clean_claim_rt=0.90, cash_efficiency=0.95)
        @test s.days_ar == :below
        @test s.denial_rate == :below
    end

    # ── Forecasting ────────────────────────────────────────────────────────

    @testset "Simple Exponential Smoothing" begin
        result = simple_exponential_smoothing([100.0, 110.0, 120.0], 0.3)
        @test length(result.smoothed) == 3
        @test length(result.forecast) == 1
        @test result.smoothed[1] ≈ 100.0
        @test_throws ArgumentError simple_exponential_smoothing([100.0], 0.0)
    end

    @testset "Holt Double Exponential" begin
        result = holt_double_exponential([100.0, 105.0, 110.0, 115.0], 0.4, 0.3; horizon=2)
        @test length(result.forecast) == 2
        @test result.forecast[1] > result.level[end]  # trending up
    end

    @testset "Holt-Winters Additive" begin
        # 2 seasons of quarterly data
        data = [100.0, 90.0, 110.0, 105.0, 102.0, 92.0, 112.0, 107.0]
        result = holt_winters_additive(data, 0.3, 0.1, 0.2, 4; horizon=4)
        @test length(result.forecast) == 4
        @test length(result.seasonal) == 8
    end

    @testset "Weighted Moving Average" begin
        wma = weighted_moving_average([100.0, 110.0, 120.0], [1.0, 2.0, 3.0])
        expected = (100*1/6 + 110*2/6 + 120*3/6)
        @test wma[1] ≈ expected atol=1e-10
    end

    @testset "Seasonal Indices — round-trip" begin
        data    = [100.0, 80.0, 120.0, 100.0, 100.0, 80.0, 120.0, 100.0]
        indices = seasonal_indices(data, 4)
        @test length(indices) == 4
        deseas  = deseasonalize(data, indices)
        reseas  = reseasonalize(deseas, indices)
        @test reseas ≈ data atol=1e-10
    end

    @testset "Budget Variance Functions" begin
        @test budget_variance(105_000.0, 100_000.0) ≈ 5_000.0
        @test budget_variance_pct(105_000.0, 100_000.0) ≈ 0.05
        @test flexible_budget_variance(105_000.0, 102_000.0) ≈ 3_000.0
        @test_throws ArgumentError budget_variance_pct(100.0, 0.0)
    end

    @testset "Forecast Accuracy Metrics" begin
        actual   = [100.0, 110.0, 120.0, 130.0]
        forecast = [102.0, 108.0, 122.0, 128.0]
        @test forecast_rmse(actual, forecast) > 0
        @test forecast_mape(actual, forecast) > 0
        fb = forecast_bias(actual, forecast)
        @test abs(fb) < 5.0
        @test_throws ArgumentError forecast_mape([0.0, 100.0], [1.0, 100.0])
    end

    # ── Cost-Effectiveness Analysis ────────────────────────────────────────

    @testset "Markov Cohort — 2-state model" begin
        T = [0.9 0.1; 0.0 1.0]  # absorbing death state
        init = [1.0, 0.0]
        traces = markov_cohort(T, init, 10)
        @test size(traces) == (11, 2)
        @test traces[1, :] ≈ [1.0, 0.0]
        @test sum(traces[end, :]) ≈ 1.0 atol=1e-10
    end

    @testset "Markov Cohort — row sum ≠ 1 throws" begin
        T = [0.9 0.2; 0.0 1.0]
        @test_throws ArgumentError markov_cohort(T, [1.0, 0.0], 5)
    end

    @testset "Markov Cycle Traces — QALY sum" begin
        T      = [0.9 0.1; 0.0 1.0]
        traces = markov_cohort(T, [1.0, 0.0], 5)
        qalys  = markov_cycle_traces(traces, [0.8, 0.0])
        @test length(qalys) == 5
        @test all(q >= 0 for q in qalys)
    end

    @testset "ICER" begin
        @test icer(50_000.0, 1.0) ≈ 50_000.0
        @test_throws ArgumentError icer(50_000.0, 0.0)
    end

    @testset "CEA Dominance" begin
        @test cea_dominant(100.0, 10.0, 200.0, 8.0) == :a_dominates
        @test cea_dominant(200.0, 8.0, 100.0, 10.0) == :b_dominates
        @test cea_dominant(100.0, 8.0, 90.0, 10.0) == :neither
    end

    @testset "Net Monetary Benefit" begin
        @test net_monetary_benefit(2.0, 80_000.0, 50_000.0) ≈ 20_000.0
        @test_throws ArgumentError net_monetary_benefit(1.0, 100.0, -1.0)
    end

    @testset "DALY" begin
        @test daly(5.0, 10.0, 0.3) ≈ 8.0
        @test_throws ArgumentError daly(5.0, 10.0, 1.5)
    end

    @testset "QALY Adjusted Life Years" begin
        @test qaly_adjusted_life_years(10.0, 0.8) ≈ 8.0
    end

    @testset "Budget Impact Analysis" begin
        b = budget_impact_analysis(10_000.0, 0.1, 5000.0, 3000.0, 0.0; horizon_years=3)
        @test length(b.annual_impacts) == 3
        @test b.cumulative_impact ≈ sum(b.annual_impacts)
        @test b.annual_impacts[1] > 0  # new therapy costs more
    end

    @testset "Decision Tree EV" begin
        @test decision_tree_ev([100.0, 50.0, 0.0], [0.5, 0.3, 0.2]) ≈ 65.0
        @test_throws ArgumentError decision_tree_ev([1.0, 2.0], [0.6, 0.6])
    end

    @testset "PSA — fraction cost effective" begin
        result = probabilistic_sensitivity_analysis(
            () -> randn() * 1000 + 5000,
            () -> randn() * 0.1 + 0.5,
            500; wtp_threshold=50_000.0)
        @test 0 <= result.fraction_cost_effective <= 1
        @test !isempty(result.nmbs)
    end

    # ── Accounting ─────────────────────────────────────────────────────────

    @testset "Income Statement" begin
        s = income_statement(10_000_000.0, 2_000_000.0, 100_000.0,
                             50_000.0, 7_000_000.0; other_income=200_000.0)
        @test s.net_patient_revenue ≈ 7_850_000.0
        @test s.total_operating_revenue ≈ 8_050_000.0
        @test s.operating_income ≈ 1_050_000.0
        @test s.total_margin ≈ 1_050_000.0 / 8_050_000.0 atol=1e-10
    end

    @testset "Income Statement — zero gross_revenue throws" begin
        @test_throws ArgumentError income_statement(0.0, 0.0, 0.0, 0.0, 0.0)
    end

    @testset "EBITDA" begin
        @test ebitda(500_000.0, 300_000.0, 50_000.0) ≈ 850_000.0
        @test ebitda(500_000.0, 300_000.0) ≈ 800_000.0  # default amortization=0
    end

    @testset "EBITDA Margin" begin
        @test ebitda_margin(800_000.0, 10_000_000.0) ≈ 0.08
        @test_throws ArgumentError ebitda_margin(100.0, 0.0)
    end

    @testset "Total Margin (accounting)" begin
        @test total_margin(200_000.0, 10_000_000.0) ≈ 0.02
        @test_throws ArgumentError total_margin(100.0, 0.0)
    end

    @testset "Operating Margin HFMA" begin
        @test operating_margin_hfma(300_000.0, 10_000_000.0) ≈ 0.03
    end

    @testset "Operating Leverage" begin
        @test operating_leverage(1_000_000.0, 500_000.0) ≈ 2.0
        @test_throws ArgumentError operating_leverage(500_000.0, 0.0)
    end

    @testset "Quick Ratio" begin
        @test quick_ratio(1_000_000.0, 2_000_000.0) ≈ 0.5
        @test_throws ArgumentError quick_ratio(100.0, 0.0)
    end

    @testset "Debt to Equity" begin
        @test debt_to_equity(4_000_000.0, 6_000_000.0) ≈ 4/6 atol=1e-10
        @test_throws ArgumentError debt_to_equity(1.0, 0.0)
    end

    @testset "Equity Multiplier" begin
        @test equity_multiplier(10_000_000.0, 6_000_000.0) ≈ 10/6 atol=1e-10
    end

    @testset "Cash Flow Indirect" begin
        cf = cash_flow_indirect(500_000.0, 200_000.0, 50_000.0,
                                100_000.0, 80_000.0, 20_000.0, 300_000.0)
        @test cf.operating ≈ 500_000 + 200_000 + 50_000 - 100_000 + 80_000 - 20_000
        @test cf.investing ≈ -300_000.0
        @test cf.net_change ≈ cf.operating + cf.investing
    end

    @testset "Straight Line Depreciation" begin
        @test straight_line_depreciation(100_000.0, 10_000.0, 10) ≈ 9_000.0
        @test_throws ArgumentError straight_line_depreciation(100.0, 200.0, 5)
    end

    @testset "MACRS Depreciation — 5-year" begin
        schedule = macrs_depreciation_schedule(100_000.0, 5)
        @test length(schedule) == 6
        @test sum(schedule) ≈ 100_000.0 atol=1.0
        @test schedule[1] ≈ 20_000.0
    end

    @testset "MACRS Depreciation — unsupported class throws" begin
        @test_throws ArgumentError macrs_depreciation_schedule(100_000.0, 3)
    end

    @testset "Net Assets Change" begin
        @test net_assets_change(5_000_000.0, 300_000.0, 100_000.0) ≈ 5_400_000.0
    end

    @testset "Fund Accounting Summary" begin
        s = fund_accounting_summary(3_000_000.0, 1_000_000.0, 500_000.0)
        @test s.total_net_assets ≈ 4_500_000.0
        @test s.unrestricted_fraction ≈ 3/4.5 atol=1e-10
    end

    @testset "Charitable Community Benefit Rate" begin
        @test charitable_community_benefit_rate(500_000.0, 10_000_000.0) ≈ 0.05
        @test_throws ArgumentError charitable_community_benefit_rate(100.0, 0.0)
    end

    # ── Actuarial ──────────────────────────────────────────────────────────

    @testset "Loss Development Factors — 3×3 triangle" begin
        tri = Float64[100 150 180;
                      120 170   0;
                      130   0   0]
        ldfs = loss_development_factors(tri)
        @test length(ldfs) == 2
        @test ldfs[1] ≈ (150 + 170) / (100 + 120) atol=1e-10
    end

    @testset "Claims Triangle Development" begin
        tri = Float64[100 150 180;
                      120 170   0;
                      130   0   0]
        dev = claims_triangle_development(tri)
        @test dev[2, 3] ≈ 170 * (180/150) atol=0.01
        @test dev[3, 2] ≈ 130 * ((150+170)/(100+120)) atol=0.01
    end

    @testset "IBNR Reserve" begin
        tri = Float64[100 150 180;
                      120 170   0;
                      130   0   0]
        reserves = ibnr_reserve(tri)
        @test length(reserves) == 3
        @test reserves[1] ≈ 0.0 atol=0.01  # fully developed
        @test reserves[2] > 0
        @test reserves[3] > 0
    end

    @testset "HCC Risk Score (actuarial numeric)" begin
        @test hcc_risk_score(0.8, [0.3, 0.2]) ≈ 1.3
        @test hcc_risk_score(0.8, [0.3, 0.2]; normalization_factor=1.1) ≈ 1.3/1.1 atol=1e-10
        @test_throws ArgumentError hcc_risk_score(0.8, [0.3]; normalization_factor=0.0)
    end

    @testset "HCC Prospective Score" begin
        @test hcc_prospective_score(1.2, 1.05) ≈ 1.26
    end

    @testset "PMPM by Category" begin
        cats = pmpm_by_category([12_000.0, 8_000.0], ["IP", "OP"], 100.0)
        @test length(cats) == 2
        @test cats[1].pmpm ≈ 120.0
    end

    @testset "Admin Expense Ratio" begin
        @test admin_expense_ratio(150_000.0, 1_000_000.0) ≈ 0.15
    end

    @testset "Premium Rate Development" begin
        p = premium_rate_development(300.0, 0.15, 0.05)
        @test p ≈ 300.0 / 0.80 atol=1e-10
        @test_throws ArgumentError premium_rate_development(300.0, 0.6, 0.5)
    end

    @testset "Utilization Rate" begin
        @test utilization_rate(80.0, 1200.0) ≈ 80/1200*1000 atol=1e-10
    end

    @testset "Admissions per Thousand" begin
        @test admissions_per_thousand(100.0, 1000.0) ≈ 1200.0
    end

    @testset "Claim Frequency and Severity" begin
        @test claim_frequency(500.0, 1000.0) ≈ 0.5
        @test claim_severity(250_000.0, 500.0) ≈ 500.0
        @test pure_premium(0.5, 500.0) ≈ 250.0
    end

    @testset "Credibility Weight" begin
        @test credibility_weight(1082.0) ≈ 1.0
        @test credibility_weight(270.5) ≈ 0.5 atol=1e-4
        @test credibility_weight(0.0) ≈ 0.0
    end

    @testset "Blended Rate" begin
        @test blended_rate(100.0, 80.0, 0.75) ≈ 95.0
        @test_throws ArgumentError blended_rate(100.0, 80.0, 1.5)
    end

    # ── Reimbursement ──────────────────────────────────────────────────────

    @testset "DRG Payment" begin
        @test drg_payment(6000.0, 1.5, 10) ≈ 90_000.0
        @test drg_payment(6000.0, 1.5, 10; outlier_threshold=500.0, outlier_rate=0.8) ≈ 94_000.0
    end

    @testset "MS-DRG Payment" begin
        p = ms_drg_payment(6000.0, 1.5, 5, :none; wage_index=0.95)
        @test p > 0
        @test_throws ArgumentError ms_drg_payment(6000.0, 1.5, 5, :invalid)
    end

    @testset "APR-DRG Payment — severity adjustors" begin
        base = apr_drg_payment(5000.0, 1.0, 2, 1)  # severity 2 = weight 1.0
        high = apr_drg_payment(5000.0, 1.0, 4, 1)  # severity 4 = weight 2.2
        @test high > base
        @test high ≈ 5000.0 * 2.2
        @test_throws ArgumentError apr_drg_payment(5000.0, 1.0, 5, 1)
    end

    @testset "OPPS APC Payment" begin
        @test opps_apc_payment(80.0, 2.5, 100) ≈ 20_000.0
    end

    @testset "RVU to Payment" begin
        @test rvu_to_payment(2.0, 1.5, 0.5, 36.0) ≈ (2.0+1.5+0.5)*36.0
    end

    @testset "RBRVS Payment — multiple units" begin
        single = rvu_to_payment(2.0, 1.0, 0.5, 36.0)
        @test rbrvs_payment(2.0, 1.0, 0.5, 36.0, 3) ≈ single * 3
    end

    @testset "Capitation PMPM" begin
        @test capitation_pmpm(1_200_000.0, 1000.0) ≈ 1200.0
    end

    @testset "PMPM Trend" begin
        @test pmpm_trend(100.0, 0.05, 12) ≈ 100.0 * (1.05)^12 atol=1e-10
    end

    @testset "Revenue Cycle KPIs" begin
        @test days_in_ar(2_000_000.0, 50_000.0) ≈ 40.0
        @test denial_rate(150, 5000) ≈ 0.03
        @test clean_claim_rate(4900, 5000) ≈ 0.98
        @test gross_collection_rate(800_000.0, 1_000_000.0) ≈ 0.80
        @test cash_collection_efficiency(1_020_000.0, 1_000_000.0) ≈ 1.02
        @test bad_debt_rate(50_000.0, 1_000_000.0) ≈ 0.05
        @test charity_care_rate(30_000.0, 600_000.0) ≈ 0.05
        @test uncompensated_care_rate(50_000.0, 30_000.0, 1_000_000.0) ≈ 0.08
    end

    @testset "Revenue Cycle Scorecard — exceeds" begin
        s = revenue_cycle_scorecard(days_ar=38.0, denial_rt=0.02,
                                    clean_claim_rt=0.99, cash_efficiency=1.03)
        @test s.days_ar == :exceeds
        @test s.denial_rate == :exceeds
        @test s.clean_claim_rate == :exceeds
        @test s.cash_efficiency == :exceeds
    end

    @testset "Revenue Cycle Scorecard — below" begin
        s = revenue_cycle_scorecard(days_ar=60.0, denial_rt=0.08,
                                    clean_claim_rt=0.90, cash_efficiency=0.95)
        @test s.days_ar == :below
        @test s.denial_rate == :below
    end

    # ── Forecasting ────────────────────────────────────────────────────────

    @testset "Simple Exponential Smoothing" begin
        result = simple_exponential_smoothing([100.0, 110.0, 120.0], 0.3)
        @test length(result.smoothed) == 3
        @test length(result.forecast) == 1
        @test result.smoothed[1] ≈ 100.0
        @test_throws ArgumentError simple_exponential_smoothing([100.0], 0.0)
    end

    @testset "Holt Double Exponential" begin
        result = holt_double_exponential([100.0, 105.0, 110.0, 115.0], 0.4, 0.3; horizon=2)
        @test length(result.forecast) == 2
        @test result.forecast[1] > result.level[end]  # trending up
    end

    @testset "Holt-Winters Additive" begin
        # 2 seasons of quarterly data
        data = [100.0, 90.0, 110.0, 105.0, 102.0, 92.0, 112.0, 107.0]
        result = holt_winters_additive(data, 0.3, 0.1, 0.2, 4; horizon=4)
        @test length(result.forecast) == 4
        @test length(result.seasonal) == 8
    end

    @testset "Weighted Moving Average" begin
        wma = weighted_moving_average([100.0, 110.0, 120.0], [1.0, 2.0, 3.0])
        expected = (100*1/6 + 110*2/6 + 120*3/6)
        @test wma[1] ≈ expected atol=1e-10
    end

    @testset "Seasonal Indices — round-trip" begin
        data    = [100.0, 80.0, 120.0, 100.0, 100.0, 80.0, 120.0, 100.0]
        indices = seasonal_indices(data, 4)
        @test length(indices) == 4
        deseas  = deseasonalize(data, indices)
        reseas  = reseasonalize(deseas, indices)
        @test reseas ≈ data atol=1e-10
    end

    @testset "Budget Variance Functions" begin
        @test budget_variance(105_000.0, 100_000.0) ≈ 5_000.0
        @test budget_variance_pct(105_000.0, 100_000.0) ≈ 0.05
        @test flexible_budget_variance(105_000.0, 102_000.0) ≈ 3_000.0
        @test_throws ArgumentError budget_variance_pct(100.0, 0.0)
    end

    @testset "Forecast Accuracy Metrics" begin
        actual   = [100.0, 110.0, 120.0, 130.0]
        forecast = [102.0, 108.0, 122.0, 128.0]
        @test forecast_rmse(actual, forecast) > 0
        @test forecast_mape(actual, forecast) > 0
        fb = forecast_bias(actual, forecast)
        @test abs(fb) < 5.0
        @test_throws ArgumentError forecast_mape([0.0, 100.0], [1.0, 100.0])
    end

    # ── Cost-Effectiveness Analysis ────────────────────────────────────────

    @testset "Markov Cohort — 2-state model" begin
        T = [0.9 0.1; 0.0 1.0]  # absorbing death state
        init = [1.0, 0.0]
        traces = markov_cohort(T, init, 10)
        @test size(traces) == (11, 2)
        @test traces[1, :] ≈ [1.0, 0.0]
        @test sum(traces[end, :]) ≈ 1.0 atol=1e-10
    end

    @testset "Markov Cohort — row sum ≠ 1 throws" begin
        T = [0.9 0.2; 0.0 1.0]
        @test_throws ArgumentError markov_cohort(T, [1.0, 0.0], 5)
    end

    @testset "Markov Cycle Traces — QALY sum" begin
        T      = [0.9 0.1; 0.0 1.0]
        traces = markov_cohort(T, [1.0, 0.0], 5)
        qalys  = markov_cycle_traces(traces, [0.8, 0.0])
        @test length(qalys) == 5
        @test all(q >= 0 for q in qalys)
    end

    @testset "ICER" begin
        @test icer(50_000.0, 1.0) ≈ 50_000.0
        @test_throws ArgumentError icer(50_000.0, 0.0)
    end

    @testset "CEA Dominance" begin
        @test cea_dominant(100.0, 10.0, 200.0, 8.0) == :a_dominates
        @test cea_dominant(200.0, 8.0, 100.0, 10.0) == :b_dominates
        @test cea_dominant(100.0, 8.0, 90.0, 10.0) == :neither
    end

    @testset "Net Monetary Benefit" begin
        @test net_monetary_benefit(2.0, 80_000.0, 50_000.0) ≈ 20_000.0
        @test_throws ArgumentError net_monetary_benefit(1.0, 100.0, -1.0)
    end

    @testset "DALY" begin
        @test daly(5.0, 10.0, 0.3) ≈ 8.0
        @test_throws ArgumentError daly(5.0, 10.0, 1.5)
    end

    @testset "QALY Adjusted Life Years" begin
        @test qaly_adjusted_life_years(10.0, 0.8) ≈ 8.0
    end

    @testset "Budget Impact Analysis" begin
        b = budget_impact_analysis(10_000.0, 0.1, 5000.0, 3000.0, 0.0; horizon_years=3)
        @test length(b.annual_impacts) == 3
        @test b.cumulative_impact ≈ sum(b.annual_impacts)
        @test b.annual_impacts[1] > 0  # new therapy costs more
    end

    @testset "Decision Tree EV" begin
        @test decision_tree_ev([100.0, 50.0, 0.0], [0.5, 0.3, 0.2]) ≈ 65.0
        @test_throws ArgumentError decision_tree_ev([1.0, 2.0], [0.6, 0.6])
    end

    @testset "PSA — fraction cost effective" begin
        result = probabilistic_sensitivity_analysis(
            () -> randn() * 1000 + 5000,
            () -> randn() * 0.1 + 0.5,
            500; wtp_threshold=50_000.0)
        @test 0 <= result.fraction_cost_effective <= 1
        @test !isempty(result.nmbs)
    end

end  # @testset "FinanceEngine"

include("test_three_statement.jl")
include("test_dupont.jl")
include("test_distress_scoring.jl")


include("aqua_tests.jl")
include("jet_tests.jl")
