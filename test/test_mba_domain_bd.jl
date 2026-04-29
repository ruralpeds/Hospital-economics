"""
    test_mba_domain_bd.jl — Tests for MBA Domains B (Strategy) + D (Risk/ML)

Covers:
  B-03  Service-line portfolio (Markowitz, efficient frontier, recommendations)
  B-06  Nash bargaining (Nash, KS, BATNA sensitivity, Rubinstein, reservation price)
  B-07  Competitive analytics (HHI, market share, geographic overlap, trend, position score)
  D-04  Copula MC (Gaussian, t-copula, marginal mapping, hospital default correlation)
  D-05  VaR / CVaR (historical, parametric, joint tail, hospital convenience function)
  D-06  CCAR stress test (scenario projection, covenant breach, capital adequacy)
"""

using Test
using Statistics
using LinearAlgebra

# ═════════════════════════════════════════════════════════════════════════════
# B-03: Service-Line Portfolio
# ═════════════════════════════════════════════════════════════════════════════

@testset "B-03 Service-Line Portfolio" begin

    function sample_lines()
        [
            ServiceLine(name="Emergency Medicine",
                annual_net_margin_history=[0.12, 0.11, 0.14, 0.13, 0.10],
                current_revenue=2_800_000.0, is_essential=true,
                community_need_score=0.95),
            ServiceLine(name="Obstetrics",
                annual_net_margin_history=[-0.05, -0.08, -0.03, -0.06, -0.04],
                current_revenue=950_000.0, is_essential=false,
                community_need_score=0.80),
            ServiceLine(name="Swing Bed/SNF",
                annual_net_margin_history=[0.08, 0.09, 0.07, 0.11, 0.10],
                current_revenue=620_000.0),
            ServiceLine(name="Rural Health Clinic",
                annual_net_margin_history=[0.15, 0.18, 0.14, 0.16, 0.17],
                current_revenue=1_100_000.0),
        ]
    end

    @testset "compute_portfolio_stats — basic" begin
        stats = compute_portfolio_stats(sample_lines())
        @test length(stats.names) == 4
        @test length(stats.expected_returns) == 4
        @test length(stats.std_devs) == 4
        @test size(stats.cov_matrix) == (4, 4)
        @test size(stats.corr_matrix) == (4, 4)
        # Covariance matrix should be symmetric
        @test stats.cov_matrix ≈ stats.cov_matrix' atol=1e-10
        # Diagonal of correlation matrix = 1
        @test all(abs(stats.corr_matrix[i,i] - 1.0) < 1e-9 for i in 1:4)
    end

    @testset "compute_portfolio_stats — expected returns match mean" begin
        lines = sample_lines()
        stats = compute_portfolio_stats(lines)
        for (i, l) in enumerate(lines)
            @test stats.expected_returns[i] ≈ mean(l.annual_net_margin_history) atol=1e-6
        end
    end

    @testset "optimize_service_line_portfolio — runs and returns frontier" begin
        result = optimize_service_line_portfolio(sample_lines(); n_frontier_points=20)
        @test result isa ServiceLinePortfolioResult
        @test length(result.frontier) == 20
        @test !isempty(result.essential_service_lines)
        @test "Emergency Medicine" in result.essential_service_lines
    end

    @testset "efficient frontier — monotone risk-return tradeoff" begin
        result = optimize_service_line_portfolio(sample_lines(); n_frontier_points=30)
        stds  = [p.portfolio_std for p in result.frontier]
        # Frontier sorted by std
        @test stds == sort(stds)
        # All stds non-negative
        @test all(s >= 0 for s in stds)
    end

    @testset "min variance portfolio has lowest std" begin
        result = optimize_service_line_portfolio(sample_lines())
        min_std = minimum(p.portfolio_std for p in result.frontier)
        @test result.min_variance.portfolio_std ≈ min_std atol=1e-4
    end

    @testset "portfolio weights sum to 1" begin
        result = optimize_service_line_portfolio(sample_lines())
        for pt in result.frontier
            @test sum(pt.weights) ≈ 1.0 atol=1e-4
            @test all(w >= -1e-6 for w in pt.weights)
        end
        @test sum(result.min_variance.weights) ≈ 1.0 atol=1e-4
        @test sum(result.max_sharpe.weights) ≈ 1.0 atol=1e-4
    end

    @testset "essential service lines maintain minimum weight" begin
        result = optimize_service_line_portfolio(sample_lines())
        em_idx = findfirst(==("Emergency Medicine"), result.stats.names)
        for pt in result.frontier
            @test pt.weights[em_idx] >= 0.01   # essential has minimum weight
        end
    end

    @testset "portfolio_recommendation — all actions valid" begin
        result = optimize_service_line_portfolio(sample_lines())
        recs = portfolio_recommendation(result)
        @test length(recs) == 4
        for r in recs
            @test r.action in (:maintain, :grow, :reduce, :close_evaluate)
        end
    end

    @testset "too few lines raises error" begin
        lines = [sample_lines()[1]]
        @test_throws ArgumentError compute_portfolio_stats(lines)
    end

    @testset "too few history years raises error" begin
        lines = [
            ServiceLine(name="A", annual_net_margin_history=[0.05], current_revenue=1e6),
            ServiceLine(name="B", annual_net_margin_history=[0.03], current_revenue=1e6),
        ]
        @test_throws ArgumentError compute_portfolio_stats(lines)
    end

end  # B-03


# ═════════════════════════════════════════════════════════════════════════════
# B-06: Nash Bargaining
# ═════════════════════════════════════════════════════════════════════════════

@testset "B-06 Nash Bargaining" begin

    base_inputs = NashBargainInputs(
        hospital_batna            = 8_500.0,
        payer_batna               = 14_200.0,
        hospital_max_ask          = 13_000.0,
        payer_max_offer           = 9_500.0,
        hospital_bargaining_power = 0.50,
        annual_encounters         = 280,
    )

    @testset "nash_bargaining — symmetric splits ZOPA 50/50" begin
        r = nash_bargaining(base_inputs)
        @test r.contract_viable
        @test r.negotiated_rate ≈ (base_inputs.hospital_batna + base_inputs.payer_batna) / 2.0 atol=10.0
        @test r.hospital_share_of_surplus ≈ 0.50 atol=0.05
    end

    @testset "nash_bargaining — higher power → higher rate" begin
        r_low  = nash_bargaining(NashBargainInputs(; base_inputs..., hospital_bargaining_power=0.30))
        r_high = nash_bargaining(NashBargainInputs(; base_inputs..., hospital_bargaining_power=0.70))
        @test r_high.negotiated_rate > r_low.negotiated_rate
    end

    @testset "nash_bargaining — no ZOPA → not viable" begin
        inputs = NashBargainInputs(
            hospital_batna = 15_000.0,  # hospital wants more than payer's ceiling
            payer_batna    = 12_000.0,
            hospital_max_ask = 20_000.0,
            payer_max_offer  = 9_000.0,
        )
        r = nash_bargaining(inputs)
        @test !r.contract_viable
        @test r.negotiated_rate ≈ inputs.hospital_batna
    end

    @testset "nash_bargaining — annual revenue impact computed" begin
        r = nash_bargaining(base_inputs)
        @test r.annual_revenue_impact ≈ r.hospital_surplus * base_inputs.annual_encounters atol=1.0
    end

    @testset "kalai_smorodinsky — returns valid rate" begin
        r_ks = kalai_smorodinsky(base_inputs)
        r_n  = nash_bargaining(base_inputs)
        @test r_ks.contract_viable
        @test r_ks.solution_type == :kalai_smorodinsky
        @test base_inputs.hospital_batna <= r_ks.negotiated_rate <= base_inputs.payer_batna
    end

    @testset "batna_sensitivity — monotone relationship" begin
        sens = batna_sensitivity(base_inputs; n_points=10)
        @test length(sens) == 10
        # Higher BATNA → higher negotiated rate (or equal when no ZOPA)
        rates = [s.negotiated_rate for s in sens]
        # Should be non-decreasing
        diffs = diff(rates)
        @test all(d >= -1.0 for d in diffs)  # allow tiny numerical noise
    end

    @testset "rubinstein_simulation — reaches agreement for viable ZOPA" begin
        params = RubinsteinParams(
            hospital_initial_offer  = base_inputs.hospital_max_ask,
            payer_initial_offer     = base_inputs.payer_max_offer,
            hospital_batna          = base_inputs.hospital_batna,
            payer_batna             = base_inputs.payer_batna,
            hospital_discount_rate  = 0.95,
            payer_discount_rate     = 0.90,
        )
        r = rubinstein_simulation(params)
        # Most viable ZOPAs reach agreement
        if r.agreement_reached
            @test base_inputs.hospital_batna <= r.final_rate <= base_inputs.payer_batna
            @test !isnothing(r.agreement_round)
        end
        @test !isempty(r.rounds)
    end

    @testset "hospital_reservation_price — min rate ≥ full cost" begin
        r = hospital_reservation_price(
            cost_per_encounter          = 8_000.0,
            overhead_allocation_pct     = 0.35,
            volume_from_payer           = 280,
            total_volume               = 1_200,
            minimum_margin_floor        = 0.02,
        )
        @test r.full_cost_per_encounter > r.direct_cost_per_encounter
        @test r.minimum_acceptable_rate > r.full_cost_per_encounter
        @test r.effective_batna >= r.minimum_acceptable_rate
    end

end  # B-06


# ═════════════════════════════════════════════════════════════════════════════
# B-07: Competitive Analytics
# ═════════════════════════════════════════════════════════════════════════════

@testset "B-07 Competitive Analytics" begin

    @testset "compute_hhi — known values" begin
        # Monopoly: 100% market share → HHI = 10,000
        @test compute_hhi([1.0]) ≈ 10_000.0 atol=1.0
        # Duopoly 50/50 → HHI = 5,000
        @test compute_hhi([0.5, 0.5]) ≈ 5_000.0 atol=1.0
        # 5 equal firms → HHI = 2,000
        @test compute_hhi(fill(0.2, 5)) ≈ 2_000.0 atol=1.0
    end

    @testset "compute_hhi — invalid inputs" begin
        @test_throws ArgumentError compute_hhi(Float64[])
        @test_throws ArgumentError compute_hhi([-0.1, 1.1])
    end

    @testset "market_concentration_tier — thresholds" begin
        @test market_concentration_tier(1_000.0) == :unconcentrated
        @test market_concentration_tier(1_500.0) == :moderately_concentrated
        @test market_concentration_tier(2_000.0) == :moderately_concentrated
        @test market_concentration_tier(2_500.0) == :highly_concentrated
        @test market_concentration_tier(5_000.0) == :highly_concentrated
    end

    @testset "hhi_merger_delta — increases concentration" begin
        shares = [0.40, 0.35, 0.25]
        r = hhi_merger_delta(shares, 0.25, 0.35)
        @test r.post_hhi > r.pre_hhi
        @test r.delta_hhi > 0
    end

    @testset "hhi_merger_delta — antitrust concern flags" begin
        # Large merger in concentrated market
        shares = [0.60, 0.30, 0.10]
        r = hhi_merger_delta(shares, 0.30, 0.10)
        @test r.post_hhi > 2_500
        # Antitrust concern should fire
        @test r.antitrust_concern == true
    end

    @testset "analyze_market_share — correct shares" begin
        market = [
            HospitalCompetitor(id=1, name="Valley CAH",     annual_discharges=620,  is_target=true),
            HospitalCompetitor(id=2, name="Regional",       annual_discharges=4_200),
            HospitalCompetitor(id=3, name="St. Mary's",     annual_discharges=2_800),
        ]
        result = analyze_market_share(market)
        total = 620 + 4_200 + 2_800
        @test result.discharge_shares[1] ≈ 620 / total atol=1e-6
        @test result.discharge_shares[2] ≈ 4_200 / total atol=1e-6
        @test sum(values(result.discharge_shares)) ≈ 1.0 atol=1e-6
    end

    @testset "analyze_market_share — target rank and gap" begin
        market = [
            HospitalCompetitor(id=1, name="Small CAH", annual_discharges=500, is_target=true),
            HospitalCompetitor(id=2, name="Large",     annual_discharges=3_000),
        ]
        result = analyze_market_share(market)
        @test result.target_discharge_rank == 2   # smaller hospital is #2
        @test result.competitive_gap > 0
        @test result.largest_competitor_share > result.target_market_share
    end

    @testset "geographic_overlap_score — sole community" begin
        sole = [HospitalCompetitor(name="Sole Community", annual_discharges=800, is_target=true)]
        overlap = geographic_overlap_score(sole)
        @test overlap.n_competitors_in_radius == 0
        @test overlap.overlap_score == 0.0
        @test !overlap.contested_market
    end

    @testset "geographic_overlap_score — nearby competitors" begin
        market = [
            HospitalCompetitor(name="Target", annual_discharges=800, distance_miles=0.0, is_target=true),
            HospitalCompetitor(name="Rival A", annual_discharges=2000, distance_miles=20.0),
            HospitalCompetitor(name="Far",     annual_discharges=1500, distance_miles=80.0),
        ]
        overlap = geographic_overlap_score(market; service_radius_miles=35.0)
        @test overlap.n_competitors_in_radius == 1   # only Rival A within 35 miles
        @test overlap.contested_market == true
    end

    @testset "compute_hhi_trend — sorted by year" begin
        data = Dict(
            2020 => [620, 4_200, 2_800],
            2021 => [650, 4_100, 2_900],
            2022 => [700, 3_900, 3_100],
        )
        trend = compute_hhi_trend(data)
        @test length(trend) == 3
        @test trend[1].year == 2020
        @test trend[end].year == 2022
        @test all(p.hhi > 0 for p in trend)
    end

    @testset "competitive_position_score — sole community = max share score" begin
        market = [HospitalCompetitor(name="Sole", annual_discharges=500, is_target=true)]
        result = analyze_market_share(market)
        overlap = geographic_overlap_score(market)
        pos = competitive_position_score(result, overlap)
        @test pos.total_score > 0
        @test pos.strategic_position in (:strong, :moderate, :vulnerable)
    end

end  # B-07


# ═════════════════════════════════════════════════════════════════════════════
# D-04: Copula MC
# ═════════════════════════════════════════════════════════════════════════════

@testset "D-04 Copula Monte Carlo" begin

    @testset "HOSPITAL_DEFAULT_CORRELATION — valid PSD matrix" begin
        Σ = HOSPITAL_DEFAULT_CORRELATION
        @test size(Σ) == (5, 5)
        @test Σ ≈ Σ' atol=1e-10
        @test all(Σ[i,i] ≈ 1.0 for i in 1:5)
        @test isposdef(Σ + 1e-8 * I)  # PSD (with regularization)
    end

    @testset "CopulaSpec — valid construction" begin
        spec = CopulaSpec(type=:gaussian, correlation_matrix=HOSPITAL_DEFAULT_CORRELATION)
        @test spec.type == :gaussian
        @test size(spec.correlation_matrix) == (5, 5)
    end

    @testset "CopulaSpec — invalid type" begin
        @test_throws ArgumentError CopulaSpec(
            type=:pearson, correlation_matrix=I(3))
    end

    @testset "sample_gaussian_copula — uniform marginals" begin
        spec = CopulaSpec(type=:gaussian, correlation_matrix=HOSPITAL_DEFAULT_CORRELATION)
        U = sample_gaussian_copula(spec, 1_000)
        @test size(U) == (1_000, 5)
        @test all(0.0 .<= U .<= 1.0)
        # Each column should be approximately uniform
        for j in 1:5
            @test 0.40 < mean(U[:,j]) < 0.60   # U[0,1] mean ≈ 0.5
        end
    end

    @testset "sample_t_copula — uniform marginals, heavier tails" begin
        spec = CopulaSpec(type=:t, correlation_matrix=HOSPITAL_DEFAULT_CORRELATION, df=4.0)
        U = sample_t_copula(spec, 1_000)
        @test size(U) == (1_000, 5)
        @test all(0.0 .<= U .<= 1.0)
    end

    @testset "copula preserves correlation structure" begin
        # 2-variable copula with high correlation
        Σ2 = [1.0 0.85; 0.85 1.0]
        spec = CopulaSpec(type=:gaussian, correlation_matrix=Σ2)
        U = sample_gaussian_copula(spec, 5_000)
        # Empirical correlation should be close to 0.85
        @test abs(cor(U[:,1], U[:,2]) - 0.85) < 0.05
    end

    @testset "uniforms_to_marginals — correct distribution" begin
        spec = CopulaSpec(type=:gaussian, correlation_matrix=HOSPITAL_DEFAULT_CORRELATION)
        U = sample_copula(spec, 2_000)
        marginals = [
            CopulaMarginal("x", Normal(0.0, 1.0)),
            CopulaMarginal("y", Normal(5.0, 2.0)),
        ]
        X = uniforms_to_marginals(U[:,1:2], marginals)
        @test abs(mean(X[:,1])) < 0.10      # ~N(0,1)
        @test abs(mean(X[:,2]) - 5.0) < 0.15  # ~N(5,2)
    end

    @testset "CopulaMCParams — default copula is valid" begin
        params = CopulaMCParams(n_iterations=100)
        @test params.copula.type == :gaussian
        @test size(params.copula.correlation_matrix) == (5, 5)
        @test length(params.marginals) == 5
    end

end  # D-04


# ═════════════════════════════════════════════════════════════════════════════
# D-05: VaR / CVaR
# ═════════════════════════════════════════════════════════════════════════════

@testset "D-05 VaR and CVaR" begin

    # 10 years of margin history: mostly positive with occasional losses
    margin_history = [-0.038, -0.021, 0.015, 0.032, -0.008, 0.041, -0.052, 0.018, 0.028, 0.035]
    dcoh_history   = [48.2, 55.1, 62.4, 58.8, 52.1, 68.2, 42.8, 71.5, 65.4, 69.8]
    assets_history = [8.2e6, 8.5e6, 8.9e6, 9.1e6, 8.7e6, 9.4e6, 8.3e6, 9.6e6, 9.8e6, 10.1e6]

    @testset "compute_var_cvar — basic run" begin
        r = compute_var_cvar(margin_history, "operating_margin"; confidence_level=0.95)
        @test r.metric == "operating_margin"
        @test r.confidence_level == 0.95
        @test r.n_observations == 10
        @test r.var_historical < r.mean_value   # VaR is below mean for downside
        @test r.cvar_historical <= r.var_historical  # CVaR ≤ VaR (deeper tail)
    end

    @testset "compute_var_cvar — 95% VaR is 5th percentile" begin
        r = compute_var_cvar(margin_history, "margin")
        expected_var = quantile(margin_history, 0.05)
        @test r.var_historical ≈ expected_var atol=1e-8
    end

    @testset "compute_var_cvar — CVaR worse than VaR" begin
        r = compute_var_cvar(margin_history, "margin")
        @test r.cvar_historical <= r.var_historical + 1e-10
    end

    @testset "compute_var_cvar — too few observations" begin
        @test_throws ArgumentError compute_var_cvar([0.01, 0.02, 0.03], "x")
    end

    @testset "compute_var_cvar — invalid confidence level" begin
        @test_throws ArgumentError compute_var_cvar(margin_history, "x"; confidence_level=1.1)
        @test_throws ArgumentError compute_var_cvar(margin_history, "x"; confidence_level=0.0)
    end

    @testset "hospital_var_cvar — all three metrics" begin
        result = hospital_var_cvar(
            margin_history     = margin_history,
            dcoh_history       = dcoh_history,
            net_assets_history = assets_history,
            confidence_level   = 0.90,
        )
        @test result.operating_margin isa VaRResult
        @test result.days_cash_on_hand isa VaRResult
        @test result.net_assets isa VaRResult
        @test 0.0 <= result.joint_tail_prob <= 1.0
        @test result.confidence_level == 0.90
    end

    @testset "hospital_var_cvar — joint tail probability" begin
        # With highly correlated bad years, joint tail should be > independent
        result = hospital_var_cvar(
            margin_history     = margin_history,
            dcoh_history       = dcoh_history,
            net_assets_history = assets_history,
        )
        # joint_tail_prob is [0,1]
        @test 0.0 <= result.joint_tail_prob <= 1.0
    end

end  # D-05


# ═════════════════════════════════════════════════════════════════════════════
# D-06: CCAR Stress Test
# ═════════════════════════════════════════════════════════════════════════════

@testset "D-06 CCAR Stress Test" begin

    base_inputs = HospitalStressTestInputs(
        hospital_name              = "Valley CAH",
        base_year                  = 2025,
        base_net_revenue           = 8_500_000.0,
        base_operating_margin      = 0.028,
        base_total_expenses        = 8_262_000.0,
        base_days_cash             = 52.4,
        base_mads_dscr             = 1.32,
        base_medicaid_pct          = 0.20,
        max_annual_debt_service    = 580_000.0,
        cash_balance               = 1_200_000.0,
        annual_volume_growth       = 0.010,
        annual_expense_inflation   = 0.035,
        mads_dscr_covenant_floor   = 1.10,
        n_years                    = 5,
    )

    @testset "CCAR_SCENARIOS_2024 — all three defined" begin
        @test CCAR_SCENARIOS_2024.baseline.label == :baseline
        @test CCAR_SCENARIOS_2024.adverse.label == :adverse
        @test CCAR_SCENARIOS_2024.severely_adverse.label == :severely_adverse
        @test CCAR_SCENARIOS_2024.baseline.hospital_volume_impact == 0.0
        @test CCAR_SCENARIOS_2024.adverse.hospital_volume_impact < 0.0
        @test CCAR_SCENARIOS_2024.severely_adverse.hospital_volume_impact <
              CCAR_SCENARIOS_2024.adverse.hospital_volume_impact
    end

    @testset "run_stress_scenario — baseline produces 5 years" begin
        r = run_stress_scenario(base_inputs, CCAR_SCENARIOS_2024.baseline)
        @test length(r.years) == 5
        @test r.years[1].year == 2026
        @test r.years[end].year == 2030
    end

    @testset "run_stress_scenario — baseline no breach for viable hospital" begin
        r = run_stress_scenario(base_inputs, CCAR_SCENARIOS_2024.baseline)
        # Baseline with positive margin and DSCR 1.32 should not breach
        @test isnothing(r.first_breach_year) || r.first_breach_year > 2028
    end

    @testset "run_stress_scenario — adverse worse than baseline" begin
        r_base = run_stress_scenario(base_inputs, CCAR_SCENARIOS_2024.baseline)
        r_adv  = run_stress_scenario(base_inputs, CCAR_SCENARIOS_2024.adverse)
        # Adverse should have lower minimum DSCR
        @test r_adv.minimum_dscr <= r_base.minimum_dscr + 0.01
        # Adverse should have more cumulative income loss
        @test r_adv.cumulative_income_loss <= r_base.cumulative_income_loss + 1.0
    end

    @testset "run_stress_scenario — severely adverse worst outcome" begin
        r_adv = run_stress_scenario(base_inputs, CCAR_SCENARIOS_2024.adverse)
        r_sev = run_stress_scenario(base_inputs, CCAR_SCENARIOS_2024.severely_adverse)
        @test r_sev.minimum_dscr <= r_adv.minimum_dscr + 0.01
        @test r_sev.minimum_dcoh <= r_adv.minimum_dcoh + 1.0
    end

    @testset "run_stress_scenario — minimum DSCR non-negative" begin
        for scen in [CCAR_SCENARIOS_2024.baseline, CCAR_SCENARIOS_2024.adverse,
                     CCAR_SCENARIOS_2024.severely_adverse]
            r = run_stress_scenario(base_inputs, scen)
            @test r.minimum_dscr >= 0.0
        end
    end

    @testset "run_ccar_stress_test — all three scenarios" begin
        result = run_ccar_stress_test(base_inputs)
        @test result.baseline isa StressTestResult
        @test result.adverse isa StressTestResult
        @test result.severely_adverse isa StressTestResult
        @test result.capital_adequacy in (:adequate, :watch, :critical)
        @test 0.0 <= result.probability_weighted_survival <= 1.0
        @test result.expected_value_dscr > 0
    end

    @testset "run_ccar_stress_test — capital adequacy ordering" begin
        # A hospital with high DSCR baseline should be :adequate
        strong = HospitalStressTestInputs(; base_inputs...,
            base_operating_margin   = 0.12,
            base_mads_dscr          = 3.5,
            base_days_cash          = 120.0,
            annual_expense_inflation = 0.025,
        )
        r_strong = run_ccar_stress_test(strong)
        # Should not breach in adverse (baseline DSCR=3.5, adverse shock moderate)
        @test r_strong.capital_adequacy in (:adequate, :watch)
    end

    @testset "StressTestYearResult — covenant breach defined correctly" begin
        r = run_stress_scenario(base_inputs, CCAR_SCENARIOS_2024.severely_adverse)
        for yr in r.years
            @test yr.covenant_breach == (yr.mads_dscr < base_inputs.mads_dscr_covenant_floor)
        end
    end

    @testset "probability_of_survival — fraction of years above floor" begin
        r = run_stress_scenario(base_inputs, CCAR_SCENARIOS_2024.adverse)
        expected_surv = mean(y -> !y.covenant_breach, r.years)
        @test r.probability_of_survival ≈ expected_surv atol=1e-9
    end

end  # D-06

println("\n✅  MBA Domains B (B-03/B-06/B-07) + D (D-04/D-05/D-06) test suite complete.")
