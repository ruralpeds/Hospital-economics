"""
    test_mba_domain_a.jl — Tests for MBA Domain A Corporate Finance Gaps

Covers:
  A-04  Nonprofit WACC (mmd_yield, hamada, nonprofit_wacc, mads_headroom,
        covenant_dashboard, synthetic_rating)
  A-05  Equivalent Annual Cost (equivalent_annual_cost)
  A-06  Real Options (bsm_real_option, binomial_real_option,
        value_service_line_option, estimate_real_asset_volatility)
  A-09  Treasury (thirteen_week_forecast, medicare_delay_stress,
        run_medicare_delay_scenarios, loc_headroom, liquidity_dashboard)
"""

using Test
using Dates

# ═════════════════════════════════════════════════════════════════════════════
# A-04 Nonprofit WACC and Covenants
# ═════════════════════════════════════════════════════════════════════════════

@testset "A-04 Nonprofit WACC" begin

    @testset "mmd_yield — known rating" begin
        y = mmd_yield(10; rating="A2/A")
        @test y > 0.03        # well above AAA base
        @test y < 0.10        # not absurdly high
        @test y ≈ MMD_AAA_CURVE[10] + HOSPITAL_SECTOR_SPREADS["A2/A"] atol=1e-6
    end

    @testset "mmd_yield — interpolation" begin
        y6  = mmd_yield(6)
        y5  = mmd_yield(5)
        y7  = mmd_yield(7)
        @test y5 < y6 < y7    # monotone interpolation
    end

    @testset "mmd_yield — boundary clamp" begin
        y_short = mmd_yield(1)
        y_long  = mmd_yield(30)
        @test y_short > 0
        @test y_long  > y_short
        # Beyond 30 years: clamps to 30-year value + spread
        y_40 = mmd_yield(40)
        @test y_40 ≈ y_long atol=1e-6
    end

    @testset "hamada_unlever / relever round-trip" begin
        β_L  = 0.70
        d_r  = 0.40
        β_u  = hamada_unlever(β_L, d_r)
        β_L2 = hamada_relever(β_u, d_r)
        @test β_L2 ≈ β_L atol=1e-10
        @test β_u < β_L          # unlevered beta < levered
        @test β_u > 0
    end

    @testset "hamada — debt_ratio = 0 → no leverage adjustment" begin
        β_u = hamada_unlever(0.50, 0.0)
        @test β_u ≈ 0.50 atol=1e-10
    end

    @testset "hamada — invalid debt_ratio" begin
        @test_throws ArgumentError hamada_unlever(0.5, 1.0)
        @test_throws ArgumentError hamada_unlever(0.5, -0.1)
    end

    @testset "nonprofit_wacc — basic run" begin
        inputs = NonprofitWACCInputs(
            long_term_debt            = 25_000_000.0,
            net_assets_unrestricted   = 30_000_000.0,
            annual_debt_service       = 2_100_000.0,
            bond_maturity_years       = 20,
            rating                    = "A2/A",
            unlevered_beta            = 0.45,
        )
        r = nonprofit_wacc(inputs)
        @test r.wacc > 0.03
        @test r.wacc < 0.12
        @test r.debt_ratio + r.equity_ratio ≈ 1.0 atol=1e-10
        @test r.cost_of_debt_pretax == r.cost_of_debt_aftertax  # nonprofit: no tax shield
        @test r.levered_beta > inputs.unlevered_beta             # leverage increases beta
        @test r.taxable_equivalent_cod > r.cost_of_debt_pretax  # taxable equiv > tax-exempt
    end

    @testset "nonprofit_wacc — zero debt" begin
        inputs = NonprofitWACCInputs(
            long_term_debt          = 0.0,
            net_assets_unrestricted = 10_000_000.0,
            annual_debt_service     = 0.0,
        )
        r = nonprofit_wacc(inputs)
        @test r.debt_ratio ≈ 0.0 atol=1e-10
        @test r.equity_ratio ≈ 1.0 atol=1e-10
        @test r.wacc ≈ r.cost_of_equity atol=1e-10
    end

    @testset "nonprofit_wacc — invalid (zero capital)" begin
        inputs = NonprofitWACCInputs(
            long_term_debt          = 0.0,
            net_assets_unrestricted = 0.0,
            annual_debt_service     = 0.0,
        )
        @test_throws ArgumentError nonprofit_wacc(inputs)
    end

    @testset "mads_headroom — compliant hospital" begin
        inp = DebtCovenantInputs(
            net_patient_revenue          = 8_000_000.0,
            total_operating_expenses     = 7_500_000.0,
            cash_and_investments         = 3_000_000.0,
            long_term_debt               = 10_000_000.0,
            net_assets_unrestricted      = 12_000_000.0,
            current_assets               = 2_000_000.0,
            current_liabilities          = 1_200_000.0,
            max_annual_debt_service      = 800_000.0,
            current_annual_debt_service  = 750_000.0,
        )
        r = mads_headroom(inp)
        @test r.mads_dscr > 0
        @test r.compliant == (r.mads_dscr >= 1.10)
        @test isfinite(r.mads_headroom_pct)
    end

    @testset "mads_headroom — breach scenario" begin
        inp = DebtCovenantInputs(
            net_patient_revenue         = 5_000_000.0,
            total_operating_expenses    = 5_200_000.0,  # operating loss
            cash_and_investments        = 1_200_000.0,
            long_term_debt              = 15_000_000.0,
            net_assets_unrestricted     = 8_000_000.0,
            current_assets              = 900_000.0,
            current_liabilities         = 1_100_000.0,
            max_annual_debt_service     = 1_200_000.0,
            current_annual_debt_service = 1_100_000.0,
        )
        r = mads_headroom(inp)
        @test r.compliant == false   # operating loss → DSCR < 1
        @test r.income_shortfall < 0
    end

    @testset "covenant_dashboard — all compliant" begin
        inp = DebtCovenantInputs(
            net_patient_revenue         = 12_000_000.0,
            total_operating_expenses    = 11_000_000.0,
            cash_and_investments        = 4_000_000.0,
            long_term_debt              = 8_000_000.0,
            net_assets_unrestricted     = 15_000_000.0,
            current_assets              = 3_000_000.0,
            current_liabilities         = 1_500_000.0,
            max_annual_debt_service     = 700_000.0,
            current_annual_debt_service = 650_000.0,
        )
        dash = covenant_dashboard(inp)
        @test dash.all_compliant
        @test isempty(dash.critical_violations)
        @test 0.0 <= dash.waiver_risk_score <= 100.0
    end

    @testset "covenant_dashboard — mixed compliance" begin
        inp = DebtCovenantInputs(
            net_patient_revenue         = 5_000_000.0,
            total_operating_expenses    = 5_300_000.0,   # operating loss
            cash_and_investments        = 800_000.0,      # low cash
            long_term_debt              = 20_000_000.0,   # high debt
            net_assets_unrestricted     = 6_000_000.0,
            current_assets              = 700_000.0,
            current_liabilities         = 1_400_000.0,
            max_annual_debt_service     = 1_800_000.0,
            current_annual_debt_service = 1_700_000.0,
        )
        dash = covenant_dashboard(inp)
        @test !dash.all_compliant
        @test !isempty(dash.critical_violations)
        @test dash.waiver_risk_score > 50.0
    end

    @testset "synthetic_rating — strong hospital" begin
        inp = SyntheticRatingInputs(
            operating_margin_pct       = 5.5,
            excess_margin_pct          = 6.0,
            days_cash_on_hand          = 180.0,
            cash_to_debt_pct           = 110.0,
            debt_to_cap_pct            = 35.0,
            mads_dscr                  = 3.0,
            annual_revenue_millions    = 120.0,
            system_affiliation         = true,
        )
        r = synthetic_rating(inp)
        @test r.category == :investment_grade
        @test r.rating_numeric < 3.0
        @test startswith(r.moody_equivalent, "A") || startswith(r.moody_equivalent, "Aa")
    end

    @testset "synthetic_rating — distressed hospital" begin
        inp = SyntheticRatingInputs(
            operating_margin_pct       = -3.0,
            excess_margin_pct          = -2.0,
            days_cash_on_hand          = 18.0,
            cash_to_debt_pct           = 8.0,
            debt_to_cap_pct            = 78.0,
            mads_dscr                  = 0.8,
            annual_revenue_millions    = 15.0,
        )
        r = synthetic_rating(inp)
        @test r.category != :investment_grade
        @test r.rating_numeric > 4.0
    end

    @testset "synthetic_rating — score_detail fields" begin
        inp = SyntheticRatingInputs(
            operating_margin_pct=3.0, excess_margin_pct=4.0,
            days_cash_on_hand=90.0, cash_to_debt_pct=60.0,
            debt_to_cap_pct=45.0, mads_dscr=2.0, annual_revenue_millions=50.0,
        )
        r = synthetic_rating(inp)
        @test 1.0 <= r.score_detail.composite <= 5.0
        @test 1.0 <= r.score_detail.profitability_score <= 5.0
        @test 1.0 <= r.score_detail.liquidity_score <= 5.0
    end

end  # A-04

# ═════════════════════════════════════════════════════════════════════════════
# A-05 Equivalent Annual Cost
# ═════════════════════════════════════════════════════════════════════════════

@testset "A-05 Equivalent Annual Cost" begin

    @testset "EAC — textbook example" begin
        # Machine costing \$10,000 NPV over 5 years at 10% WACC
        # EAC = 10000 × 0.10 / (1 − 1.10^-5) = 2,637.97
        eac = equivalent_annual_cost(10_000.0, 0.10, 5)
        @test eac ≈ 2_637.97 atol=1.0
    end

    @testset "EAC — zero WACC" begin
        eac = equivalent_annual_cost(12_000.0, 0.0, 4)
        @test eac ≈ 3_000.0 atol=1e-6
    end

    @testset "EAC — longer life → lower annual cost" begin
        eac_5  = equivalent_annual_cost(100_000.0, 0.07, 5)
        eac_10 = equivalent_annual_cost(100_000.0, 0.07, 10)
        @test eac_5 > eac_10
    end

    @testset "EAC — invalid inputs" begin
        @test_throws ArgumentError equivalent_annual_cost(10_000.0, 0.05, 0)
        @test_throws ArgumentError equivalent_annual_cost(-1.0, 0.05, 5)
    end

    @testset "EAC — compares projects with different lives" begin
        # CT scanner: \$1.2M NPV, 8-yr life vs MRI: \$3M NPV, 15-yr life at 5%
        eac_ct  = equivalent_annual_cost(1_200_000.0, 0.05, 8)
        eac_mri = equivalent_annual_cost(3_000_000.0, 0.05, 15)
        @test eac_ct > 0
        @test eac_mri > 0
        # Both are valid comparisons (exact ranking depends on parameters)
        @test isfinite(eac_ct) && isfinite(eac_mri)
    end

end  # A-05

# ═════════════════════════════════════════════════════════════════════════════
# A-06 Real Options
# ═════════════════════════════════════════════════════════════════════════════

@testset "A-06 Real Options" begin

    @testset "bsm_real_option — call (expand)" begin
        opt = RealOptionBSM(S=10_000_000.0, K=8_000_000.0, T=3.0,
                            r=0.04, σ=0.25, option_type=:call)
        r = bsm_real_option(opt)
        @test r.option_value > 0
        # Deep in-the-money call: option value ≥ intrinsic value
        @test r.option_value >= r.intrinsic_value
        @test r.time_value   >= 0
        @test 0.0 <= r.delta <= 1.0
    end

    @testset "bsm_real_option — put (abandon)" begin
        opt = RealOptionBSM(S=5_000_000.0, K=7_000_000.0, T=2.0,
                            r=0.04, σ=0.30, option_type=:put)
        r = bsm_real_option(opt)
        @test r.option_value > 0
        @test r.intrinsic_value > 0   # ITM put
        @test -1.0 <= r.delta <= 0.0
    end

    @testset "bsm_real_option — put-call parity" begin
        # C − P = S·e^{-δT} − K·e^{-rT}
        S, K, T, r, σ, δ = 8e6, 8e6, 2.0, 0.04, 0.25, 0.02
        call_r = bsm_real_option(RealOptionBSM(S=S,K=K,T=T,r=r,σ=σ,δ=δ,option_type=:call))
        put_r  = bsm_real_option(RealOptionBSM(S=S,K=K,T=T,r=r,σ=σ,δ=δ,option_type=:put))
        parity = call_r.option_value - put_r.option_value
        rhs    = S * exp(-δ*T) - K * exp(-r*T)
        @test parity ≈ rhs atol=1.0
    end

    @testset "bsm_real_option — invalid inputs" begin
        @test_throws ArgumentError bsm_real_option(RealOptionBSM(S=1e6,K=1e6,T=0.0,σ=0.25))
        @test_throws ArgumentError bsm_real_option(RealOptionBSM(S=1e6,K=1e6,T=1.0,σ=0.0))
        @test_throws ArgumentError bsm_real_option(RealOptionBSM(S=0.0,K=1e6,T=1.0,σ=0.25))
    end

    @testset "bsm_real_option — unknown option type" begin
        @test_throws ArgumentError bsm_real_option(
            RealOptionBSM(S=1e6,K=1e6,T=1.0,σ=0.25,option_type=:straddle))
    end

    @testset "binomial_real_option — European ≈ BSM" begin
        S, K, T, r, σ = 10e6, 8e6, 3.0, 0.04, 0.25
        bsm_v = bsm_real_option(RealOptionBSM(S=S,K=K,T=T,r=r,σ=σ,option_type=:call)).option_value
        bin_v = binomial_real_option(RealOptionBinomial(S=S,K=K,T=T,r=r,σ=σ,
                                     american=false,n_steps=500,option_type=:call)).option_value
        @test bin_v ≈ bsm_v rtol=0.01    # within 1% for 500 steps
    end

    @testset "binomial_real_option — American ≥ European" begin
        opt_a = RealOptionBinomial(S=8e6,K=9e6,T=3.0,r=0.04,σ=0.30,american=true, option_type=:call)
        opt_e = RealOptionBinomial(S=8e6,K=9e6,T=3.0,r=0.04,σ=0.30,american=false,option_type=:call)
        r_a = binomial_real_option(opt_a)
        r_e = binomial_real_option(opt_e)
        # American ≥ European
        @test r_a.option_value >= r_e.option_value - 1.0   # small tolerance for grid error
        @test r_a.early_exercise_premium >= -1.0
    end

    @testset "binomial_real_option — put early exercise premium ≥ 0 for ITM" begin
        # Deep-in-money put: American should be worth more
        opt = RealOptionBinomial(S=5e6,K=8e6,T=5.0,r=0.04,σ=0.25,american=true,option_type=:put,n_steps=200)
        r = binomial_real_option(opt)
        @test r.early_exercise_premium >= -1.0   # small tolerance
    end

    @testset "binomial_real_option — invalid n_steps" begin
        @test_throws ArgumentError binomial_real_option(
            RealOptionBinomial(S=1e6,K=1e6,T=1.0,σ=0.25,n_steps=1))
    end

    @testset "estimate_real_asset_volatility" begin
        cfs = [280_000.0, 315_000.0, 295_000.0, 340_000.0, 290_000.0, 325_000.0]
        σ = estimate_real_asset_volatility(cfs)
        @test 0.0 < σ < 1.0        # reasonable range
    end

    @testset "estimate_real_asset_volatility — too few observations" begin
        @test_throws ArgumentError estimate_real_asset_volatility([100.0, 110.0])
    end

    @testset "estimate_real_asset_volatility — non-positive cash flow" begin
        @test_throws ArgumentError estimate_real_asset_volatility([100.0, -50.0, 200.0])
    end

    @testset "value_service_line_option — expand OB" begin
        opt = ServiceLineOption(
            name                    = "Expand OB Service Line",
            option_type             = :expand,
            underlying_value        = 6_000_000.0,
            investment_or_salvage   = 4_000_000.0,
            decision_horizon_years  = 3.0,
            annual_cash_flow        = 350_000.0,
            asset_volatility        = 0.28,
        )
        r = value_service_line_option(opt)
        @test r.option_value > 0
        @test r.method == :binomial
        @test r.recommendation in (:exercise_now, :hold_option, :abandon_option)
        @test !isempty(r.recommendation_rationale)
    end

    @testset "value_service_line_option — abandon inpatient" begin
        opt = ServiceLineOption(
            name                    = "Abandon Inpatient Unit",
            option_type             = :abandon,
            underlying_value        = 3_000_000.0,   # low PV of losing service line
            investment_or_salvage   = 5_000_000.0,   # salvage from shutdown
            decision_horizon_years  = 2.0,
            asset_volatility        = 0.35,
        )
        r = value_service_line_option(opt)
        @test r.option_value > 0
        @test r.npv_static > 0    # ITM put: salvage > service-line value
    end

    @testset "value_service_line_option — CAH to REH conversion" begin
        opt = ServiceLineOption(
            name                    = "Convert CAH to REH",
            option_type             = :switch,
            underlying_value        = 8_500_000.0,
            investment_or_salvage   = 5_000_000.0,
            decision_horizon_years  = 1.5,
            annual_cash_flow        = 400_000.0,
            asset_volatility        = 0.20,
        )
        r = value_service_line_option(opt)
        @test r.option_value >= 0
        @test r.strategic_premium >= 0
    end

    @testset "hospital_real_options_portfolio — sorted by value" begin
        opts = [
            ServiceLineOption(name="A", option_type=:expand,
                underlying_value=10e6, investment_or_salvage=5e6,
                decision_horizon_years=3.0, asset_volatility=0.25),
            ServiceLineOption(name="B", option_type=:abandon,
                underlying_value=2e6, investment_or_salvage=3e6,
                decision_horizon_years=2.0, asset_volatility=0.30),
            ServiceLineOption(name="C", option_type=:defer,
                underlying_value=5e6, investment_or_salvage=6e6,
                decision_horizon_years=5.0, asset_volatility=0.35),
        ]
        results = hospital_real_options_portfolio(opts)
        @test length(results) == 3
        # Sorted descending by option_value
        @test results[1].option_value >= results[2].option_value >= results[3].option_value
    end

end  # A-06

# ═════════════════════════════════════════════════════════════════════════════
# A-09 Treasury & Liquidity
# ═════════════════════════════════════════════════════════════════════════════

@testset "A-09 Treasury & Liquidity" begin

    base_profile = WeeklyOperatingProfile(
        weekly_net_collections     = 900_000.0,
        weekly_payroll             = 380_000.0,
        weekly_supplies_ap         = 190_000.0,
        weekly_other_disbursements = 30_000.0,
        medicare_pct_of_collections = 0.45,
        medicaid_pct_of_collections  = 0.25,
        commercial_pct_of_collections = 0.30,
    )

    @testset "thirteen_week_forecast — basic structure" begin
        f = thirteen_week_forecast(base_profile, 4_000_000.0)
        @test length(f.weeks) == 13
        @test f.opening_cash_balance ≈ 4_000_000.0
        @test 1 <= f.minimum_cash_week <= 13
        @test f.total_loc_drawn == 0.0   # no LOC configured
    end

    @testset "thirteen_week_forecast — cash balance continuity" begin
        f = thirteen_week_forecast(base_profile, 2_000_000.0)
        for i in 2:13
            @test f.weeks[i].opening_cash ≈ f.weeks[i-1].closing_cash atol=1e-2
        end
    end

    @testset "thirteen_week_forecast — payer split sums to total" begin
        f = thirteen_week_forecast(base_profile, 1_000_000.0)
        for row in f.weeks
            @test row.medicare_collections + row.medicaid_collections +
                  row.commercial_collections ≈ row.total_collections atol=1e-2
        end
    end

    @testset "thirteen_week_forecast — LOC draw on low cash" begin
        # Opening cash too low; LOC should be drawn
        f = thirteen_week_forecast(base_profile, 100_000.0;
            loc_capacity=5_000_000.0, min_cash_threshold=500_000.0)
        @test f.total_loc_drawn > 0
    end

    @testset "thirteen_week_forecast — crisis detection" begin
        f = thirteen_week_forecast(base_profile, 50_000.0;
            min_cash_threshold=200_000.0)  # no LOC
        @test !isnothing(f.weeks_to_cash_crisis)
        @test 1 <= f.weeks_to_cash_crisis <= 13
    end

    @testset "thirteen_week_forecast — shock function" begin
        # Apply a positive shock in week 5 (e.g. supplemental payment)
        shock_fn = (wk, _) -> wk == 5 ? 500_000.0 : 0.0
        f_base   = thirteen_week_forecast(base_profile, 2_000_000.0)
        f_shock  = thirteen_week_forecast(base_profile, 2_000_000.0; shock=shock_fn)
        @test f_shock.closing_cash_balance > f_base.closing_cash_balance
    end

    @testset "medicare_delay_stress — 4-week delay" begin
        sc = MedicareDelayScenario(delay_weeks=4, label="4-week shutdown")
        r = medicare_delay_stress(base_profile, 5_000_000.0, sc;
            loc_capacity=8_000_000.0, min_cash_threshold=500_000.0)
        @test r.medicare_revenue_deferred > 0
        @test r.medicare_revenue_deferred ≈
            base_profile.weekly_net_collections * 0.45 * 4 atol=1.0
        @test r.survivable isa Bool
    end

    @testset "medicare_delay_stress — incremental LOC ≥ 0" begin
        sc = MedicareDelayScenario(delay_weeks=8)
        r  = medicare_delay_stress(base_profile, 3_000_000.0, sc;
            loc_capacity=10_000_000.0)
        @test r.incremental_loc_required >= 0.0
    end

    @testset "medicare_delay_stress — stressed > baseline LOC draw" begin
        sc = MedicareDelayScenario(delay_weeks=13)
        r  = medicare_delay_stress(base_profile, 2_000_000.0, sc;
            loc_capacity=10_000_000.0, min_cash_threshold=300_000.0)
        @test r.stressed_forecast.total_loc_drawn >= r.baseline_forecast.total_loc_drawn
    end

    @testset "run_medicare_delay_scenarios — default 3 scenarios" begin
        results = run_medicare_delay_scenarios(base_profile, 4_000_000.0;
            loc_capacity=8_000_000.0)
        @test length(results) == 3
        # Sorted by delay descending (most severe first)
        delays = [r.scenario.delay_weeks for r in results]
        @test delays == sort(delays; rev=true)
    end

    @testset "loc_headroom — basic" begin
        inputs = LOCHeadroomInputs(
            loc_commitment    = 5_000_000.0,
            loc_outstanding   = 1_200_000.0,
            loc_maturity_date = today() + Month(14),
        )
        r = loc_headroom(inputs; monthly_operating_expenses=900_000.0)
        @test r.gross_availability ≈ 3_800_000.0 atol=1.0
        @test r.net_availability   == r.gross_availability   # no covenant floor set
        @test r.days_to_maturity   > 0
        @test r.renewal_risk == :low
        @test r.months_of_operating_expenses_covered > 0
    end

    @testset "loc_headroom — covenant floor" begin
        inputs = LOCHeadroomInputs(
            loc_commitment         = 5_000_000.0,
            loc_outstanding        = 1_000_000.0,
            loc_maturity_date      = today() + Month(6),
            covenant_loc_floor     = 500_000.0,
        )
        r = loc_headroom(inputs)
        @test r.gross_availability ≈ 4_000_000.0 atol=1.0
        @test r.net_availability   ≈ 3_500_000.0 atol=1.0
    end

    @testset "loc_headroom — renewal risk tiers" begin
        far  = loc_headroom(LOCHeadroomInputs(loc_commitment=1e6,
                    loc_maturity_date=today()+Day(200)))
        mid  = loc_headroom(LOCHeadroomInputs(loc_commitment=1e6,
                    loc_maturity_date=today()+Day(120)))
        near = loc_headroom(LOCHeadroomInputs(loc_commitment=1e6,
                    loc_maturity_date=today()+Day(60)))
        @test far.renewal_risk  == :low
        @test mid.renewal_risk  == :medium
        @test near.renewal_risk == :high
    end

    @testset "liquidity_dashboard — runs and returns rating" begin
        profile = base_profile
        loc_in  = LOCHeadroomInputs(
            loc_commitment    = 8_000_000.0,
            loc_maturity_date = today() + Month(18),
        )
        dash = liquidity_dashboard(profile, 5_000_000.0, loc_in;
            monthly_opex=2_500_000.0, min_cash_threshold=500_000.0)
        @test dash.liquidity_rating in (:adequate, :watch, :critical)
        @test 0.0 <= dash.expected_survivability <= 1.0
        @test dash.days_cash_on_hand_opening > 0
        @test length(dash.stress_scenarios) == 3
    end

end  # A-09

println("\n✅  MBA Domain A (A-04, A-05, A-06, A-09) test suite complete.")
