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
end

include("test_three_statement.jl")

include("aqua_tests.jl")
include("jet_tests.jl")
