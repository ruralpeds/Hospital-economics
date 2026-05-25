using Test
using Statistics
using Random
using LinearAlgebra

include(joinpath(@__DIR__, "..", "src", "finance", "distress_scoring.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "lbo_model.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "real_options.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "var_cvar.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "copula_monte_carlo.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "treasury_forecast.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "physician_compensation.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "revenue_variance.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "forecasting.jl"))

# ═══════════════════════════════════════════════════════════════
# Altman Z'' Distress Scoring
# ═══════════════════════════════════════════════════════════════

@testset "Altman Z'' Distress Scoring" begin
    @testset "safe zone — healthy hospital" begin
        input = DistressInput(
            working_capital=5_000_000.0,
            total_assets=20_000_000.0,
            retained_earnings=8_000_000.0,
            ebit=3_000_000.0,
            book_equity=12_000_000.0,
            total_liabilities=8_000_000.0,
            revenue=30_000_000.0,
        )
        result = calculate_altman_z(input)

        @test result.zone == :safe
        @test result.z_score > 2.6
        @test haskey(result.component_scores, "x1_working_capital_ta")
        @test haskey(result.component_scores, "x2_retained_earnings_ta")
        @test haskey(result.component_scores, "x3_ebit_ta")
        @test haskey(result.component_scores, "x4_equity_tl")
    end

    @testset "grey zone" begin
        input = DistressInput(
            working_capital=1_000_000.0,
            total_assets=20_000_000.0,
            retained_earnings=2_000_000.0,
            ebit=500_000.0,
            book_equity=4_000_000.0,
            total_liabilities=16_000_000.0,
            revenue=25_000_000.0,
        )
        result = calculate_altman_z(input)

        @test result.zone == :grey
        @test 1.1 <= result.z_score <= 2.6
    end

    @testset "distress zone" begin
        input = DistressInput(
            working_capital=-2_000_000.0,
            total_assets=10_000_000.0,
            retained_earnings=-1_000_000.0,
            ebit=-500_000.0,
            book_equity=1_000_000.0,
            total_liabilities=9_000_000.0,
            revenue=12_000_000.0,
        )
        result = calculate_altman_z(input)

        @test result.zone == :distress
        @test result.z_score < 1.1
    end

    @testset "Z'' formula verification" begin
        input = DistressInput(
            working_capital=1_000.0,
            total_assets=10_000.0,
            retained_earnings=2_000.0,
            ebit=1_500.0,
            book_equity=3_000.0,
            total_liabilities=7_000.0,
            revenue=20_000.0,
        )
        result = calculate_altman_z(input)

        x1 = 1_000.0 / 10_000.0
        x2 = 2_000.0 / 10_000.0
        x3 = 1_500.0 / 10_000.0
        x4 = 3_000.0 / 7_000.0
        expected_z = 6.56 * x1 + 3.26 * x2 + 6.72 * x3 + 1.05 * x4

        @test result.z_score ≈ expected_z
    end

    @testset "invalid inputs" begin
        @test_throws ErrorException calculate_altman_z(DistressInput(
            working_capital=0.0, total_assets=0.0, retained_earnings=0.0,
            ebit=0.0, book_equity=0.0, total_liabilities=1.0, revenue=0.0))
        @test_throws ErrorException calculate_altman_z(DistressInput(
            working_capital=0.0, total_assets=1.0, retained_earnings=0.0,
            ebit=0.0, book_equity=0.0, total_liabilities=0.0, revenue=0.0))
    end

    @testset "distress timeline — declining" begin
        z_scores = [3.0, 2.5, 2.0, 1.5]
        years = [2020.0, 2021.0, 2022.0, 2023.0]
        tl = estimate_distress_timeline(z_scores, years)

        @test tl.slope < 0.0
        @test tl.current_z == 1.5
        @test tl.years_to_distress < Inf
        @test tl.years_to_distress > 0.0
    end

    @testset "distress timeline — improving" begin
        z_scores = [1.5, 2.0, 2.5, 3.0]
        years = [2020.0, 2021.0, 2022.0, 2023.0]
        tl = estimate_distress_timeline(z_scores, years)

        @test tl.slope > 0.0
        @test tl.years_to_distress == Inf
    end

    @testset "distress timeline — already in distress" begin
        z_scores = [1.0, 0.8]
        years = [2022.0, 2023.0]
        tl = estimate_distress_timeline(z_scores, years)

        @test tl.current_z == 0.8
        @test tl.years_to_distress == 0.0
    end

    @testset "distress timeline — too few points" begin
        @test_throws ErrorException estimate_distress_timeline([1.0], [2023.0])
    end
end

# ═══════════════════════════════════════════════════════════════
# LBO Model
# ═══════════════════════════════════════════════════════════════

@testset "LBO Model" begin
    @testset "basic projection" begin
        input = LBOInput(
            enterprise_value=100_000_000.0,
            equity_pct=0.30,
            debt_terms=[DebtTerm(rate=0.06, maturity=7, amortization_pct=0.05)],
            revenue=80_000_000.0,
            ebitda_margin=0.15,
            revenue_growth=0.03,
            exit_multiple=8.0,
            hold_years=5,
        )
        result = calculate_lbo(input)

        @test result.total_enterprise_value == 100_000_000.0
        @test result.equity_contribution ≈ 30_000_000.0
        @test result.total_debt ≈ 70_000_000.0
        @test length(result.annual_projections) == 5
        # Revenue should grow each year
        @test result.annual_projections[5].revenue > result.annual_projections[1].revenue
        # Debt should decrease over time due to amortization
        @test result.annual_projections[5].debt_balance < result.annual_projections[1].debt_balance
    end

    @testset "IRR calculation" begin
        input = LBOInput(
            enterprise_value=50_000_000.0,
            equity_pct=0.40,
            debt_terms=[DebtTerm(rate=0.05, maturity=5, amortization_pct=0.10)],
            revenue=40_000_000.0,
            ebitda_margin=0.20,
            revenue_growth=0.05,
            exit_multiple=7.0,
            hold_years=5,
        )
        result = calculate_lbo(input)

        @test result.equity_irr > 0.0
        @test isfinite(result.equity_irr)
        @test result.moic > 1.0
    end

    @testset "multiple debt tranches" begin
        input = LBOInput(
            enterprise_value=100_000_000.0,
            equity_pct=0.30,
            debt_terms=[
                DebtTerm(rate=0.05, maturity=7, amortization_pct=0.05),
                DebtTerm(rate=0.08, maturity=5, amortization_pct=0.0),
            ],
            revenue=80_000_000.0,
            ebitda_margin=0.15,
            revenue_growth=0.03,
            exit_multiple=8.0,
            hold_years=5,
        )
        result = calculate_lbo(input)

        @test length(result.debt_by_tranche) == 2
        # Senior tranche gets 60%
        @test result.debt_by_tranche[1] ≈ 70_000_000.0 * 0.6
        @test result.debt_by_tranche[2] ≈ 70_000_000.0 * 0.4
    end

    @testset "cash sweep reduces exit debt" begin
        base_input = LBOInput(
            enterprise_value=50_000_000.0,
            equity_pct=0.40,
            debt_terms=[DebtTerm(rate=0.05, maturity=5, amortization_pct=0.0)],
            revenue=40_000_000.0,
            ebitda_margin=0.20,
            revenue_growth=0.05,
            exit_multiple=7.0,
            hold_years=5,
            cash_sweep_pct=0.0,
        )
        sweep_input = LBOInput(
            enterprise_value=50_000_000.0,
            equity_pct=0.40,
            debt_terms=[DebtTerm(rate=0.05, maturity=5, amortization_pct=0.0)],
            revenue=40_000_000.0,
            ebitda_margin=0.20,
            revenue_growth=0.05,
            exit_multiple=7.0,
            hold_years=5,
            cash_sweep_pct=0.50,
        )
        r_base = calculate_lbo(base_input)
        r_sweep = calculate_lbo(sweep_input)

        @test r_sweep.exit_debt < r_base.exit_debt
        @test r_sweep.exit_equity > r_base.exit_equity
    end

    @testset "projection fields populated" begin
        input = LBOInput(
            enterprise_value=50_000_000.0,
            equity_pct=0.40,
            debt_terms=[DebtTerm(rate=0.05, maturity=5, amortization_pct=0.05)],
            revenue=40_000_000.0,
            ebitda_margin=0.20,
            revenue_growth=0.05,
            exit_multiple=7.0,
            hold_years=3,
        )
        result = calculate_lbo(input)
        p = result.annual_projections[1]

        @test p.year == 1
        @test p.revenue > 0.0
        @test p.ebitda > 0.0
        @test p.interest_expense > 0.0
        @test p.capex > 0.0
    end

    @testset "edge cases" begin
        @test_throws ErrorException calculate_lbo(LBOInput(
            enterprise_value=0.0, equity_pct=0.30,
            debt_terms=[DebtTerm(rate=0.05, maturity=5)],
            revenue=1.0, ebitda_margin=0.10, revenue_growth=0.0,
            exit_multiple=5.0, hold_years=3))
        @test_throws ErrorException calculate_lbo(LBOInput(
            enterprise_value=100.0, equity_pct=0.0,
            debt_terms=[DebtTerm(rate=0.05, maturity=5)],
            revenue=1.0, ebitda_margin=0.10, revenue_growth=0.0,
            exit_multiple=5.0, hold_years=3))
        @test_throws ErrorException calculate_lbo(LBOInput(
            enterprise_value=100.0, equity_pct=0.30,
            debt_terms=DebtTerm[],
            revenue=1.0, ebitda_margin=0.10, revenue_growth=0.0,
            exit_multiple=5.0, hold_years=3))
    end
end

# ═══════════════════════════════════════════════════════════════
# Real Options — BSM
# ═══════════════════════════════════════════════════════════════

@testset "Real Options — BSM" begin
    @testset "call/put parity" begin
        input = RealOptionInput(
            underlying_value=100.0,
            exercise_price=100.0,
            time_to_expiry=1.0,
            risk_free_rate=0.05,
            volatility=0.20,
            convenience_yield=0.0,
        )
        result = calculate_real_option(input)

        # Put-Call Parity: C - P = S*e^(-qT) - K*e^(-rT)
        lhs = result.call_value - result.put_value
        rhs = 100.0 * exp(0.0) - 100.0 * exp(-0.05)
        @test lhs ≈ rhs atol=0.01
    end

    @testset "known BSM values — ATM call" begin
        input = RealOptionInput(
            underlying_value=100.0,
            exercise_price=100.0,
            time_to_expiry=1.0,
            risk_free_rate=0.05,
            volatility=0.20,
        )
        result = calculate_real_option(input)

        @test result.call_value > 0.0
        @test result.put_value > 0.0
        # BSM ATM call ~10.45 for these parameters
        @test result.call_value ≈ 10.45 atol=0.20
    end

    @testset "deep in-the-money call" begin
        input = RealOptionInput(
            underlying_value=200.0,
            exercise_price=100.0,
            time_to_expiry=1.0,
            risk_free_rate=0.05,
            volatility=0.20,
        )
        result = calculate_real_option(input)

        intrinsic = 200.0 - 100.0 * exp(-0.05)
        @test result.call_value ≈ intrinsic atol=1.0
        @test result.delta ≈ 1.0 atol=0.05
    end

    @testset "deep out-of-the-money call" begin
        input = RealOptionInput(
            underlying_value=50.0,
            exercise_price=200.0,
            time_to_expiry=1.0,
            risk_free_rate=0.05,
            volatility=0.20,
        )
        result = calculate_real_option(input)

        @test result.call_value ≈ 0.0 atol=0.01
        @test result.delta ≈ 0.0 atol=0.01
    end

    @testset "Greeks sensibility" begin
        input = RealOptionInput(
            underlying_value=100.0,
            exercise_price=100.0,
            time_to_expiry=1.0,
            risk_free_rate=0.05,
            volatility=0.20,
        )
        result = calculate_real_option(input)

        @test 0.0 < result.delta < 1.0
        @test result.gamma > 0.0
        @test result.vega > 0.0
        @test result.theta < 0.0
    end

    @testset "convenience yield reduces call value" begin
        r_no_yield = calculate_real_option(RealOptionInput(
            underlying_value=100.0, exercise_price=100.0,
            time_to_expiry=1.0, risk_free_rate=0.05, volatility=0.20,
            convenience_yield=0.0))
        r_yield = calculate_real_option(RealOptionInput(
            underlying_value=100.0, exercise_price=100.0,
            time_to_expiry=1.0, risk_free_rate=0.05, volatility=0.20,
            convenience_yield=0.03))

        @test r_yield.call_value < r_no_yield.call_value
    end

    @testset "invalid inputs" begin
        @test_throws ErrorException calculate_real_option(RealOptionInput(
            underlying_value=0.0, exercise_price=100.0,
            time_to_expiry=1.0, risk_free_rate=0.05, volatility=0.20))
        @test_throws ErrorException calculate_real_option(RealOptionInput(
            underlying_value=100.0, exercise_price=100.0,
            time_to_expiry=0.0, risk_free_rate=0.05, volatility=0.20))
        @test_throws ErrorException calculate_real_option(RealOptionInput(
            underlying_value=100.0, exercise_price=100.0,
            time_to_expiry=1.0, risk_free_rate=0.05, volatility=0.0))
    end
end

# ═══════════════════════════════════════════════════════════════
# VaR / CVaR
# ═══════════════════════════════════════════════════════════════

@testset "VaR / CVaR" begin
    @testset "sorted returns — basic calculation" begin
        returns = [-0.05, -0.03, -0.01, 0.0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.06]
        result = calculate_var_cvar(VaRInput(returns=returns, confidence=0.95))

        @test result.n_observations == 10
        @test result.var_pct > 0.0
        @test result.cvar_pct >= result.var_pct
    end

    @testset "confidence levels" begin
        returns = [-0.10, -0.08, -0.05, -0.03, -0.01, 0.01, 0.02, 0.04, 0.05, 0.07,
                   0.08, 0.10, -0.02, 0.03, -0.04, 0.06, -0.06, 0.09, -0.07, 0.11]

        r90 = calculate_var_cvar(VaRInput(returns=returns, confidence=0.90))
        r95 = calculate_var_cvar(VaRInput(returns=returns, confidence=0.95))
        r99 = calculate_var_cvar(VaRInput(returns=returns, confidence=0.99))

        @test r95.var_pct >= r90.var_pct
        @test r99.var_pct >= r95.var_pct
    end

    @testset "holding period scaling — sqrt(T)" begin
        returns = [-0.05, -0.03, -0.01, 0.0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.06]

        r1 = calculate_var_cvar(VaRInput(returns=returns, confidence=0.95, holding_period=1))
        r5 = calculate_var_cvar(VaRInput(returns=returns, confidence=0.95, holding_period=5))

        @test r5.var_pct ≈ r1.var_pct * sqrt(5.0) atol=1e-10
    end

    @testset "CVaR always >= VaR" begin
        returns = collect(range(-0.10, 0.10, length=100))
        result = calculate_var_cvar(VaRInput(returns=returns, confidence=0.95))

        @test result.cvar_pct >= result.var_pct
    end

    @testset "all-positive returns" begin
        returns = [0.01, 0.02, 0.03, 0.04, 0.05]
        result = calculate_var_cvar(VaRInput(returns=returns, confidence=0.95))

        @test result.var_pct ≈ -returns[1] atol=1e-10
    end

    @testset "edge cases" begin
        @test_throws ErrorException calculate_var_cvar(VaRInput(returns=[0.01], confidence=0.95))
        @test_throws ErrorException calculate_var_cvar(VaRInput(returns=[0.01, 0.02], confidence=0.0))
        @test_throws ErrorException calculate_var_cvar(VaRInput(returns=[0.01, 0.02], confidence=1.0))
    end
end

# ═══════════════════════════════════════════════════════════════
# Copula Monte Carlo
# ═══════════════════════════════════════════════════════════════

@testset "Copula Monte Carlo" begin
    @testset "correlation preservation" begin
        corr_matrix = [1.0 0.8; 0.8 1.0]
        input = CopulaInput(
            n_simulations=10_000,
            marginal_params=[(100.0, 15.0), (50.0, 10.0)],
            correlation_matrix=corr_matrix,
            random_seed=42,
        )
        result = generate_copula_samples(input)

        @test size(result.samples) == (10_000, 2)
        @test result.empirical_correlation[1, 2] ≈ 0.8 atol=0.05
    end

    @testset "marginal distribution means and stds" begin
        corr_matrix = [1.0 0.0; 0.0 1.0]
        input = CopulaInput(
            n_simulations=10_000,
            marginal_params=[(100.0, 15.0), (50.0, 10.0)],
            correlation_matrix=corr_matrix,
            random_seed=42,
        )
        result = generate_copula_samples(input)

        @test length(result.summary_stats) == 2
        @test result.summary_stats[1].mean ≈ 100.0 atol=1.0
        @test result.summary_stats[2].mean ≈ 50.0 atol=1.0
        @test result.summary_stats[1].std ≈ 15.0 atol=1.0
        @test result.summary_stats[2].std ≈ 10.0 atol=1.0
    end

    @testset "reproducibility with same seed" begin
        input = CopulaInput(
            n_simulations=100,
            marginal_params=[(0.0, 1.0)],
            correlation_matrix=reshape([1.0], 1, 1),
            random_seed=123,
        )
        r1 = generate_copula_samples(input)
        r2 = generate_copula_samples(input)

        @test r1.samples == r2.samples
    end

    @testset "three variables" begin
        corr = [1.0 0.5 0.3;
                0.5 1.0 0.4;
                0.3 0.4 1.0]
        input = CopulaInput(
            n_simulations=5_000,
            marginal_params=[(10.0, 2.0), (20.0, 3.0), (30.0, 5.0)],
            correlation_matrix=corr,
            random_seed=42,
        )
        result = generate_copula_samples(input)

        @test size(result.samples) == (5_000, 3)
        @test size(result.empirical_correlation) == (3, 3)
        # Diagonal should be 1.0
        @test result.empirical_correlation[1, 1] ≈ 1.0 atol=0.01
        @test result.empirical_correlation[2, 2] ≈ 1.0 atol=0.01
        @test result.empirical_correlation[3, 3] ≈ 1.0 atol=0.01
    end

    @testset "non-positive-definite matrix" begin
        bad_corr = [1.0 2.0; 2.0 1.0]
        @test_throws ErrorException generate_copula_samples(CopulaInput(
            n_simulations=100,
            marginal_params=[(0.0, 1.0), (0.0, 1.0)],
            correlation_matrix=bad_corr))
    end

    @testset "dimension mismatch" begin
        @test_throws ErrorException generate_copula_samples(CopulaInput(
            n_simulations=100,
            marginal_params=[(0.0, 1.0)],
            correlation_matrix=[1.0 0.0; 0.0 1.0]))
    end
end

# ═══════════════════════════════════════════════════════════════
# Treasury 13-Week Forecast
# ═══════════════════════════════════════════════════════════════

@testset "Treasury 13-Week Forecast" begin
    function _make_profiles(n=13; receipts=500_000.0, disbursements=450_000.0)
        [WeeklyProfile(week=i, operating_receipts=receipts,
                       operating_disbursements=disbursements)
         for i in 1:n]
    end

    @testset "weekly balances — stable positive cash flow" begin
        profiles = _make_profiles()
        input = TreasuryInput(
            starting_cash=1_000_000.0,
            weekly_profiles=profiles,
        )
        result = forecast_treasury(input)

        @test length(result.weekly_balances) == 13
        @test result.weekly_balances[1].beginning_cash == 1_000_000.0
        @test result.weekly_balances[1].net_cash_flow ≈ 50_000.0
        @test result.weekly_balances[13].ending_cash > 1_000_000.0
        @test result.loc_draws == 0.0
    end

    @testset "LOC draws when cash is below threshold" begin
        profiles = [WeeklyProfile(week=i, operating_receipts=100_000.0,
                                  operating_disbursements=200_000.0)
                    for i in 1:5]
        input = TreasuryInput(
            starting_cash=200_000.0,
            weekly_profiles=profiles,
            loc_capacity=500_000.0,
            loc_rate=0.05,
            min_cash_threshold=100_000.0,
        )
        result = forecast_treasury(input)

        @test result.loc_draws > 0.0
        @test result.loc_balance >= 0.0
    end

    @testset "LOC interest accrues" begin
        profiles = [WeeklyProfile(week=i, operating_receipts=100_000.0,
                                  operating_disbursements=200_000.0)
                    for i in 1:3]
        input = TreasuryInput(
            starting_cash=100_000.0,
            weekly_profiles=profiles,
            loc_capacity=1_000_000.0,
            loc_rate=0.052,
            min_cash_threshold=50_000.0,
        )
        result = forecast_treasury(input)

        @test result.interest_cost > 0.0
    end

    @testset "nadir tracking" begin
        profiles = [
            WeeklyProfile(week=1, operating_receipts=500_000.0, operating_disbursements=450_000.0),
            WeeklyProfile(week=2, operating_receipts=500_000.0, operating_disbursements=450_000.0),
            WeeklyProfile(week=3, operating_receipts=100_000.0, operating_disbursements=800_000.0),
            WeeklyProfile(week=4, operating_receipts=500_000.0, operating_disbursements=450_000.0),
            WeeklyProfile(week=5, operating_receipts=500_000.0, operating_disbursements=450_000.0),
        ]
        input = TreasuryInput(starting_cash=1_000_000.0, weekly_profiles=profiles)
        result = forecast_treasury(input)

        @test result.nadir_week == 3
        @test result.nadir_amount < 1_000_000.0
    end

    @testset "Medicare delay stress test" begin
        profiles = _make_profiles(5; receipts=500_000.0, disbursements=450_000.0)
        r_base = forecast_treasury(TreasuryInput(
            starting_cash=500_000.0, weekly_profiles=profiles,
            medicare_delay_weeks=0))
        r_stress = forecast_treasury(TreasuryInput(
            starting_cash=500_000.0, weekly_profiles=profiles,
            medicare_delay_weeks=2, medicare_pct_of_receipts=0.45))

        @test r_stress.nadir_amount <= r_base.nadir_amount
        @test r_stress.medicare_stress_impact != 0.0
    end

    @testset "empty profiles" begin
        @test_throws ErrorException forecast_treasury(
            TreasuryInput(starting_cash=1_000.0, weekly_profiles=WeeklyProfile[]))
    end
end

# ═══════════════════════════════════════════════════════════════
# Physician Compensation
# ═══════════════════════════════════════════════════════════════

@testset "Physician Compensation" begin
    @testset "wRVU rates and productivity" begin
        profiles = [
            PhysicianProfile(name="Dr. A", specialty="Cardiology",
                             wrvu_actual=6000.0, wrvu_benchmark=5500.0,
                             base_salary=400_000.0, quality_bonus_pct=0.10),
            PhysicianProfile(name="Dr. B", specialty="Cardiology",
                             wrvu_actual=5000.0, wrvu_benchmark=5500.0,
                             base_salary=350_000.0, quality_bonus_pct=0.05),
        ]
        results = calculate_physician_compensation(profiles)

        @test length(results) == 2
        @test results[1].total_comp ≈ 440_000.0
        @test results[1].comp_per_wrvu ≈ 440_000.0 / 6000.0
        @test results[1].productivity_pct > 100.0
        @test results[2].productivity_pct < 100.0
    end

    @testset "outlier detection — high comp/wRVU flagged" begin
        profiles = [
            PhysicianProfile(name="N1", specialty="FM",
                             wrvu_actual=4000.0, wrvu_benchmark=4000.0, base_salary=250_000.0),
            PhysicianProfile(name="N2", specialty="FM",
                             wrvu_actual=4200.0, wrvu_benchmark=4000.0, base_salary=260_000.0),
            PhysicianProfile(name="N3", specialty="FM",
                             wrvu_actual=3800.0, wrvu_benchmark=4000.0, base_salary=240_000.0),
            PhysicianProfile(name="N4", specialty="FM",
                             wrvu_actual=4100.0, wrvu_benchmark=4000.0, base_salary=255_000.0),
            PhysicianProfile(name="Outlier", specialty="FM",
                             wrvu_actual=1000.0, wrvu_benchmark=4000.0, base_salary=500_000.0),
        ]
        results = calculate_physician_compensation(profiles)

        outlier_result = filter(r -> r.name == "Outlier", results)
        @test length(outlier_result) == 1
        @test outlier_result[1].outlier_flag == true

        normals = filter(r -> r.name != "Outlier", results)
        @test all(r -> !r.outlier_flag, normals)
    end

    @testset "cohort analysis by specialty" begin
        profiles = [
            PhysicianProfile(name="Dr. X", specialty="Ortho",
                             wrvu_actual=5000.0, wrvu_benchmark=5000.0, base_salary=500_000.0),
            PhysicianProfile(name="Dr. Y", specialty="Ortho",
                             wrvu_actual=5500.0, wrvu_benchmark=5000.0, base_salary=520_000.0),
            PhysicianProfile(name="Dr. Z", specialty="FM",
                             wrvu_actual=4000.0, wrvu_benchmark=4000.0, base_salary=250_000.0),
        ]
        summaries = physician_cohort_analysis(profiles)

        @test length(summaries) == 2
        ortho = filter(s -> s.specialty == "Ortho", summaries)
        @test length(ortho) == 1
        @test ortho[1].n_physicians == 2
        @test ortho[1].total_wrvu == 10_500.0
        @test ortho[1].total_compensation ≈ 500_000.0 + 520_000.0
    end

    @testset "empty profiles" begin
        @test_throws ErrorException calculate_physician_compensation(PhysicianProfile[])
        @test_throws ErrorException physician_cohort_analysis(PhysicianProfile[])
    end
end

# ═══════════════════════════════════════════════════════════════
# Revenue Variance Bridge
# ═══════════════════════════════════════════════════════════════

@testset "Revenue Variance Bridge" begin
    @testset "price/volume/mix decomposition" begin
        services = [
            ServiceLineRevenue(name="Cardiology",
                               prior_volume=1000.0, current_volume=1100.0,
                               prior_price=500.0, current_price=520.0),
            ServiceLineRevenue(name="Orthopedics",
                               prior_volume=800.0, current_volume=750.0,
                               prior_price=600.0, current_price=610.0),
        ]
        result = calculate_revenue_variance(services)

        # Total = price + volume + mix
        @test result.total_variance ≈ result.price_variance + result.volume_variance + result.mix_variance atol=0.01
        # Cardiology had both price and volume increase
        @test result.service_details[1].price_var > 0.0
        @test result.service_details[1].volume_var > 0.0
        # Orthopedics had volume decrease
        @test result.service_details[2].volume_var < 0.0
    end

    @testset "pure price change — no volume effect" begin
        services = [
            ServiceLineRevenue(name="Lab",
                               prior_volume=1000.0, current_volume=1000.0,
                               prior_price=100.0, current_price=110.0),
        ]
        result = calculate_revenue_variance(services)

        @test result.volume_variance ≈ 0.0 atol=1e-10
        @test result.price_variance ≈ 10_000.0
        @test result.total_variance ≈ 10_000.0
    end

    @testset "pure volume change — no price effect" begin
        services = [
            ServiceLineRevenue(name="Lab",
                               prior_volume=1000.0, current_volume=1200.0,
                               prior_price=100.0, current_price=100.0),
        ]
        result = calculate_revenue_variance(services)

        @test result.price_variance ≈ 0.0 atol=1e-10
        @test result.volume_variance ≈ 20_000.0
    end

    @testset "percentage calculations relative to prior" begin
        services = [
            ServiceLineRevenue(name="S1",
                               prior_volume=100.0, current_volume=120.0,
                               prior_price=10.0, current_price=12.0),
        ]
        result = calculate_revenue_variance(services)

        prior_revenue = 100.0 * 10.0
        @test result.price_pct ≈ (result.price_variance / prior_revenue) * 100.0
        @test result.volume_pct ≈ (result.volume_variance / prior_revenue) * 100.0
    end

    @testset "no change — zero variance" begin
        services = [
            ServiceLineRevenue(name="Stable",
                               prior_volume=500.0, current_volume=500.0,
                               prior_price=200.0, current_price=200.0),
        ]
        result = calculate_revenue_variance(services)

        @test result.total_variance ≈ 0.0 atol=1e-10
        @test result.price_variance ≈ 0.0 atol=1e-10
        @test result.volume_variance ≈ 0.0 atol=1e-10
        @test result.mix_variance ≈ 0.0 atol=1e-10
    end

    @testset "empty services" begin
        @test_throws ErrorException calculate_revenue_variance(ServiceLineRevenue[])
    end
end

# ═══════════════════════════════════════════════════════════════
# Forecasting — SES, Holt, WMA, Accuracy
# ═══════════════════════════════════════════════════════════════

@testset "Forecasting" begin
    @testset "SES — flat forecast" begin
        values = [100.0, 102.0, 101.0, 103.0, 100.0]
        forecast = simple_exponential_smoothing(values, 0.3, 4)

        @test length(forecast) == 4
        # SES produces a flat forecast
        @test all(f == forecast[1] for f in forecast)
        @test 99.0 < forecast[1] < 104.0
    end

    @testset "SES — high alpha tracks recent data" begin
        values = [100.0, 200.0]
        f_high = simple_exponential_smoothing(values, 0.9, 1)
        f_low = simple_exponential_smoothing(values, 0.1, 1)

        @test abs(f_high[1] - 200.0) < abs(f_low[1] - 200.0)
    end

    @testset "SES — invalid alpha" begin
        @test_throws ErrorException simple_exponential_smoothing([1.0], 0.0, 1)
        @test_throws ErrorException simple_exponential_smoothing([1.0], 1.0, 1)
    end

    @testset "Holt — trending data projects forward" begin
        values = [100.0, 110.0, 120.0, 130.0, 140.0]
        forecast = holt_double_exponential(values, 0.5, 0.3, 3)

        @test length(forecast) == 3
        @test forecast[1] > values[end]
        @test forecast[2] > forecast[1]
        @test forecast[3] > forecast[2]
    end

    @testset "Holt — too few observations" begin
        @test_throws ErrorException holt_double_exponential([100.0], 0.5, 0.3, 1)
    end

    @testset "WMA — equal weights = simple average" begin
        values = [10.0, 20.0, 30.0, 40.0, 50.0]
        result = weighted_moving_average(values, [1.0, 1.0, 1.0])
        @test result ≈ (30.0 + 40.0 + 50.0) / 3.0
    end

    @testset "WMA — recency-weighted" begin
        values = [10.0, 20.0, 30.0, 40.0, 50.0]
        result = weighted_moving_average(values, [1.0, 2.0, 3.0])
        expected = (1.0 * 30.0 + 2.0 * 40.0 + 3.0 * 50.0) / 6.0
        @test result ≈ expected
    end

    @testset "WMA — insufficient data" begin
        @test_throws ErrorException weighted_moving_average([1.0, 2.0], [1.0, 1.0, 1.0])
    end

    @testset "WMA — empty weights" begin
        @test_throws ErrorException weighted_moving_average([1.0], Float64[])
    end

    @testset "accuracy metrics — balanced errors" begin
        actual = [100.0, 200.0, 300.0, 400.0]
        predicted = [110.0, 190.0, 310.0, 390.0]
        acc = forecast_accuracy(actual, predicted)

        @test acc.rmse > 0.0
        @test acc.mape > 0.0
        @test acc.mape < 100.0
        # Bias: mean(10,-10,10,-10) = 0
        @test acc.bias ≈ 0.0 atol=1e-10
    end

    @testset "accuracy — perfect forecast" begin
        actual = [100.0, 200.0, 300.0]
        acc = forecast_accuracy(actual, actual)

        @test acc.rmse ≈ 0.0
        @test acc.mape ≈ 0.0
        @test acc.bias ≈ 0.0
    end

    @testset "accuracy — length mismatch" begin
        @test_throws ErrorException forecast_accuracy([1.0, 2.0], [1.0])
    end

    @testset "accuracy — empty" begin
        @test_throws ErrorException forecast_accuracy(Float64[], Float64[])
    end
end
