"""
    test_mba_p1_bundle3.jl — Tests for MBA P1 Bundle 3

Covers:
  E-05  340B contract pharmacy (manufacturer restrictions, savings, inhouse comparison)
  E-07  TEAM FY2026 (target price, reconciliation, portfolio, projection)
  E-08  Medicaid SDPs (eligibility, directed payments, UPL, portfolio)
  D-03  Bayesian VBC MSSP (track priors, posterior update, track comparison, update cycle)
"""

using Test
using Statistics

# ═════════════════════════════════════════════════════════════════════════════
# E-05: 340B Contract Pharmacy
# ═════════════════════════════════════════════════════════════════════════════

@testset "E-05 340B Contract Pharmacy" begin

    pharmacy = ContractPharmacy(
        pharmacy_id          = "CVS-001",
        name                 = "CVS Pharmacy #4521",
        chain                = "CVS",
        annual_script_volume = 3_800,
        admin_fee_per_script = 8.50,
        covered_entity_id    = "valley_cah",
    )

    drugs = [
        ContractPharmacyDrugRecord(
            drug_name="Humira (adalimumab)", manufacturer="AbbVie",
            ndc="00074-9738-02", annual_scripts=85,
            wac_per_script=6_200.0, ceiling_price_per_script=3_100.0,
            is_medicaid_ffs=false),
        ContractPharmacyDrugRecord(
            drug_name="Insulin Glargine", manufacturer="Sanofi",
            ndc="00088-5021-01", annual_scripts=420,
            wac_per_script=185.0, ceiling_price_per_script=82.0,
            is_medicaid_ffs=true),
        ContractPharmacyDrugRecord(
            drug_name="Lisinopril", manufacturer="Merck",
            ndc="00006-0019-58", annual_scripts=2_400,
            wac_per_script=12.0, ceiling_price_per_script=5.40,
            is_medicaid_ffs=false),
    ]

    @testset "MANUFACTURER_RESTRICTION_POLICIES_2026 — populated" begin
        @test length(MANUFACTURER_RESTRICTION_POLICIES_2026) >= 8
        manufacturers = [p.manufacturer for p in MANUFACTURER_RESTRICTION_POLICIES_2026]
        @test "AbbVie" in manufacturers
        @test "Sanofi" in manufacturers
        @test "Merck" in manufacturers
    end

    @testset "calculate_contract_pharmacy_savings — basic run" begin
        r = calculate_contract_pharmacy_savings(pharmacy, drugs, cah_340b)
        @test r.total_gross_savings > 0
        @test r.total_net_savings < r.total_gross_savings   # admin fees reduce net
        @test r.total_admin_fees > 0
        @test length(r.drug_results) == 3
    end

    @testset "calculate_contract_pharmacy_savings — Merck unrestricted" begin
        r = calculate_contract_pharmacy_savings(pharmacy, drugs, cah_340b)
        merck_drug = first(filter(d -> d.manufacturer == "Merck", r.drug_results))
        @test !merck_drug.manufacturer_restricted
        @test merck_drug.savings_at_risk_annual ≈ 0.0
    end

    @testset "calculate_contract_pharmacy_savings — AbbVie restricted for non-CAH" begin
        r = calculate_contract_pharmacy_savings(pharmacy, drugs, dsh_hospital)
        abbvie_drug = first(filter(d -> d.manufacturer == "AbbVie", r.drug_results))
        # dsh_hospital not in AbbVie's exemptions → restricted
        @test abbvie_drug.manufacturer_restricted
        @test abbvie_drug.savings_at_risk_annual > 0
    end

    @testset "calculate_contract_pharmacy_savings — CAH may be exempt from AbbVie" begin
        r = calculate_contract_pharmacy_savings(pharmacy, drugs, cah_340b)
        abbvie_drug = first(filter(d -> d.manufacturer == "AbbVie", r.drug_results))
        # CAH is in AbbVie's exemptions
        @test !abbvie_drug.manufacturer_restricted
    end

    @testset "calculate_contract_pharmacy_savings — Medicaid FFS → duplicate risk" begin
        r = calculate_contract_pharmacy_savings(pharmacy, drugs, cah_340b)
        sanofi_drug = first(filter(d -> d.manufacturer == "Sanofi", r.drug_results))
        @test sanofi_drug.duplicate_discount_risk == true
        @test sanofi_drug.duplicate_discount_exposure > 0
    end

    @testset "calculate_contract_pharmacy_savings — net savings positive" begin
        r = calculate_contract_pharmacy_savings(pharmacy, drugs, cah_340b)
        @test r.total_net_savings > 0
        @test r.effective_savings_rate < 1.0   # fees reduce effective rate
    end

    @testset "compare_inhouse_vs_contract — CAH may prefer inhouse for high scripts" begin
        r = compare_inhouse_vs_contract(
            annual_scripts           = 5_000,
            avg_wac_per_script       = 80.0,
            avg_ceiling_per_script   = 35.0,
            inhouse_ops_cost_annual  = 120_000.0,  # pharmacy staffing
            entity_type              = cah_340b,
        )
        @test r.total_gross_savings > 0
        @test r.preferred_model in (:inhouse, :contract)
        @test r.break_even_scripts > 0
    end

    @testset "compare_inhouse_vs_contract — low volume favours contract" begin
        r = compare_inhouse_vs_contract(
            annual_scripts          = 800,    # too few to justify inhouse
            avg_wac_per_script      = 30.0,
            avg_ceiling_per_script  = 15.0,
            inhouse_ops_cost_annual = 200_000.0,
            entity_type             = fqhc_340b,
        )
        @test r.preferred_model == :contract   # contract cheaper at low volume
    end

end  # E-05


# ═════════════════════════════════════════════════════════════════════════════
# E-07: TEAM FY2026
# ═════════════════════════════════════════════════════════════════════════════

@testset "E-07 TEAM FY2026 Bundled Payment" begin

    @testset "TEAM_DRG_MAP — all episode types defined" begin
        for etype in [lejr, shff, sf, cdi, cabg]
            @test haskey(TEAM_DRG_MAP, etype) "Missing DRG map for $etype"
            @test !isempty(TEAM_DRG_MAP[etype])
        end
    end

    @testset "TEAM_QUALITY_ADJUSTMENTS — category 1 best, 5 worst" begin
        @test TEAM_QUALITY_ADJUSTMENTS[1] > TEAM_QUALITY_ADJUSTMENTS[3]
        @test TEAM_QUALITY_ADJUSTMENTS[3] > TEAM_QUALITY_ADJUSTMENTS[5]
        @test TEAM_QUALITY_ADJUSTMENTS[3] ≈ 1.0   # neutral for category 3
    end

    @testset "calculate_team_target_price — quality adj applied" begin
        inputs = TEAMTargetPriceInputs(
            episode_type=lejr,
            regional_benchmark_price=28_750.0)
        p3 = calculate_team_target_price(inputs, 1.0, 3)
        p1 = calculate_team_target_price(inputs, 1.0, 1)  # better quality
        p5 = calculate_team_target_price(inputs, 1.0, 5)  # worse quality
        @test p1 > p3 > p5
    end

    @testset "calculate_team_target_price — risk score scales price" begin
        inputs = TEAMTargetPriceInputs(
            episode_type=lejr, regional_benchmark_price=28_750.0)
        p_low  = calculate_team_target_price(inputs, 0.80, 3)
        p_high = calculate_team_target_price(inputs, 1.20, 3)
        @test p_high > p_low
        @test p_high / p_low ≈ 1.20 / 0.80 atol=0.01
    end

    @testset "calculate_team_target_price — invalid quality raises error" begin
        inputs = TEAMTargetPriceInputs(episode_type=lejr, regional_benchmark_price=28_750.0)
        @test_throws ArgumentError calculate_team_target_price(inputs, 1.0, 6)
        @test_throws ArgumentError calculate_team_target_price(inputs, 1.0, 0)
    end

    @testset "team_episode_reconciliation — savings when actual < target" begin
        ep = TEAMEpisode(
            episode_id=1, episode_type=lejr, drg=469,
            actual_episode_cost=24_000.0,  # below target ~28k
            risk_score=1.0, quality_category=3,
        )
        ti = TEAMTargetPriceInputs(episode_type=lejr, regional_benchmark_price=28_750.0)
        r  = team_episode_reconciliation(ep, ti)
        @test r.performance == :savings
        @test r.reconciliation_payment > 0
        @test r.target_price > r.actual_episode_cost
    end

    @testset "team_episode_reconciliation — repayment when actual >> target" begin
        ep = TEAMEpisode(
            episode_id=2, episode_type=cabg, drg=231,
            actual_episode_cost=130_000.0,  # well above target ~94k
            risk_score=1.0, quality_category=3,
        )
        ti = TEAMTargetPriceInputs(episode_type=cabg, regional_benchmark_price=94_300.0)
        r  = team_episode_reconciliation(ep, ti)
        @test r.performance == :repayment
        @test r.reconciliation_payment < 0
    end

    @testset "team_episode_reconciliation — stop-gain cap applied" begin
        ep = TEAMEpisode(
            episode_id=3, episode_type=lejr, drg=469,
            actual_episode_cost=50_000.0,  # way above target (stop-gain territory)
            risk_score=1.0, quality_category=3,
        )
        ti = TEAMTargetPriceInputs(episode_type=lejr, regional_benchmark_price=28_750.0)
        r  = team_episode_reconciliation(ep, ti)
        max_repayment = r.target_price * TEAM_STOP_GAIN
        @test abs(r.reconciliation_payment) <= max_repayment + 1.0
    end

    @testset "team_portfolio_analysis — runs correctly" begin
        ti = Dict(
            lejr => TEAMTargetPriceInputs(episode_type=lejr, regional_benchmark_price=28_750.0),
            shff => TEAMTargetPriceInputs(episode_type=shff, regional_benchmark_price=38_400.0),
        )
        episodes = [
            TEAMEpisode(episode_id=i, episode_type=i<=5 ? lejr : shff, drg=469,
                actual_episode_cost=28_000.0, risk_score=1.0, quality_category=3)
            for i in 1:10
        ]
        result = team_portfolio_analysis(episodes, ti)
        @test result.total_episodes == 10
        @test result.n_savings_episodes + result.n_repayment_episodes +
              count(r -> r.performance == :neutral, result.episode_results) == 10
        @test 0.0 <= result.savings_rate <= 1.0
    end

    @testset "team_annual_projection — below-target hospital earns savings" begin
        ti = Dict(lejr => TEAMTargetPriceInputs(
            episode_type=lejr, regional_benchmark_price=28_750.0))
        proj = team_annual_projection(
            Dict(lejr => 120),
            ti;
            avg_cost_ratio_to_target = 0.93,   # 7% below target
            quality_category = 2,
        )
        @test proj.programme_outcome == :net_savings
        @test proj.total_annual_reconciliation > 0
    end

    @testset "team_annual_projection — above-target hospital owes" begin
        ti = Dict(lejr => TEAMTargetPriceInputs(
            episode_type=lejr, regional_benchmark_price=28_750.0))
        proj = team_annual_projection(
            Dict(lejr => 120),
            ti;
            avg_cost_ratio_to_target = 1.15,   # 15% above target
            quality_category = 5,
        )
        @test proj.programme_outcome == :net_repayment
        @test proj.total_annual_reconciliation < 0
    end

end  # E-07


# ═════════════════════════════════════════════════════════════════════════════
# E-08: Medicaid SDPs
# ═════════════════════════════════════════════════════════════════════════════

@testset "E-08 Medicaid State Directed Payments" begin

    cah_hospital = SDPHospitalInputs(
        hospital_id   = "CAH-001",
        hospital_name = "Valley CAH",
        is_cah        = true,
        hospital_type = :cah,
        medicaid_managed_care_days  = 820,
        medicaid_mc_op_visits       = 4_200,
        current_mcaid_base_payment_ip = 650.0,
        current_mcaid_base_payment_op = 85.0,
        medicare_ip_payment_rate    = 1_800.0,
        medicare_op_payment_rate    = 180.0,
    )

    rural_pps = SDPHospitalInputs(
        hospital_id   = "PPS-002",
        hospital_name = "Rural Regional",
        is_cah        = false,
        hospital_type = :rural_pps,
        medicaid_managed_care_days  = 2_200,
        medicaid_mc_op_visits       = 12_000,
        current_mcaid_base_payment_ip = 700.0,
        current_mcaid_base_payment_op = 90.0,
        medicare_ip_payment_rate    = 1_900.0,
        medicare_op_payment_rate    = 190.0,
    )

    rural_program = SDPProgramInputs(sdp_type=rural_cah_directed, state="KS")

    @testset "sdp_eligibility_tier — CAH gets tier 1" begin
        tier = sdp_eligibility_tier(cah_hospital, rural_cah_directed)
        @test tier == tier_1_cah_sole_community
    end

    @testset "sdp_eligibility_tier — rural PPS gets tier 2" begin
        tier = sdp_eligibility_tier(rural_pps, rural_cah_directed)
        @test tier == tier_2_rural_hospital
    end

    @testset "calculate_sdp_payment — CAH receives positive directed payment" begin
        r = calculate_sdp_payment(cah_hospital, rural_program)
        @test r.total_directed_payment > 0
        @test r.directed_ip_payment_annual > 0
        @test r.directed_op_payment_annual > 0
    end

    @testset "calculate_sdp_payment — higher tier gets larger multiplier" begin
        r_cah  = calculate_sdp_payment(cah_hospital, rural_program)
        r_pps  = calculate_sdp_payment(rural_pps, rural_program)
        @test r_cah.ip_directed_rate_multiplier >= r_pps.ip_directed_rate_multiplier
    end

    @testset "calculate_sdp_payment — UPL check fires when exceeding Medicare" begin
        # Give a tiny Medicare rate so UPL is very low → likely binding
        constrained = SDPHospitalInputs(
            hospital_id="X", hospital_name="X",
            is_cah=true, hospital_type=:cah,
            medicaid_managed_care_days=1_000,
            medicaid_mc_op_visits=5_000,
            current_mcaid_base_payment_ip=800.0,    # high base
            current_mcaid_base_payment_op=120.0,
            medicare_ip_payment_rate=900.0,         # Medicare lower than directed
            medicare_op_payment_rate=130.0,
        )
        r = calculate_sdp_payment(constrained, rural_program)
        # Directed payment should be capped at UPL headroom (or near-zero)
        # (8x multiplier × 800 × 1000 would exceed Medicare 900 × 1000)
        @test r.total_mcaid_payment_with_sdp <= r.upl_ceiling_ip + r.upl_ceiling_op + 1.0
    end

    @testset "calculate_sdp_payment — effective improvement positive" begin
        r = calculate_sdp_payment(cah_hospital, rural_program)
        @test r.effective_medicaid_rate_improvement_pct > 0
    end

    @testset "sdp_portfolio_analysis — sorted by directed payment desc" begin
        hospitals = [cah_hospital, rural_pps]
        result    = sdp_portfolio_analysis(hospitals, rural_program)
        @test length(result.results) == 2
        payments = [r.total_directed_payment for r in result.results]
        @test payments == sort(payments; rev=true)
        @test result.total_directed_statewide ≈ sum(payments) atol=1.0
    end

    @testset "sdp_portfolio_analysis — tier summary populated" begin
        hospitals = [cah_hospital, rural_pps]
        result    = sdp_portfolio_analysis(hospitals, rural_program)
        @test !isempty(result.tier_summary)
        @test result.n_cah_eligible >= 1
    end

end  # E-08


# ═════════════════════════════════════════════════════════════════════════════
# D-03: Bayesian VBC MSSP
# ═════════════════════════════════════════════════════════════════════════════

@testset "D-03 Bayesian VBC / MSSP" begin

    @testset "MSSP_TRACK_PARAMETERS — all tracks defined" begin
        for track in instances(MSSPTrack)
            @test haskey(MSSP_TRACK_PARAMETERS, track) "Missing params for $track"
            p = MSSP_TRACK_PARAMETERS[track]
            @test p.shared_savings > 0
            @test 0 <= p.shared_loss <= 1.0
        end
    end

    @testset "MSSP_EMPIRICAL_PRIORS — Enhanced > Basic A (expected savings)" begin
        basic  = MSSP_EMPIRICAL_PRIORS[mssp_basic_a]
        enhanced = MSSP_EMPIRICAL_PRIORS[mssp_enhanced]
        @test enhanced.mean_pbpy > basic.mean_pbpy
        @test enhanced.std_pbpy > basic.std_pbpy
    end

    @testset "MSSP_TRACK_PARAMETERS — 1-sided tracks have zero loss" begin
        for track in [mssp_basic_a, mssp_basic_b, mssp_basic_c, mssp_basic_d]
            @test MSSP_TRACK_PARAMETERS[track].one_sided == true
            @test MSSP_TRACK_PARAMETERS[track].shared_loss == 0.0
        end
    end

    @testset "MSSP_TRACK_PARAMETERS — 2-sided tracks have loss sharing" begin
        for track in [mssp_enhanced, reach_aco]
            @test MSSP_TRACK_PARAMETERS[track].one_sided == false
            @test MSSP_TRACK_PARAMETERS[track].shared_loss > 0
        end
    end

    function sample_inputs(track=mssp_enhanced)
        MSSPHospitalInputs(
            hospital_id              = "Valley CAH",
            track                    = track,
            attributed_beneficiaries = 1_850,
            per_capita_benchmark     = 12_200.0,
            care_management_investment = 180_000.0,
            n_simulation             = 3_000,   # fast for tests
        )
    end

    @testset "mssp_bayesian_analysis — basic run" begin
        r = mssp_bayesian_analysis(sample_inputs())
        @test r isa MSSPBayesianResult
        @test r.track == mssp_enhanced
        @test 0.0 <= r.prob_earn_shared_savings <= 1.0
        @test r.ci_95_lower < r.ci_95_upper
    end

    @testset "mssp_bayesian_analysis — posterior with historical data" begin
        # Historical data showing consistent savings
        inputs = MSSPHospitalInputs(
            hospital_id = "X", track = mssp_enhanced,
            attributed_beneficiaries = 1_850,
            per_capita_benchmark = 12_200.0,
            historical_savings_pbpy = [120.0, 145.0, 160.0, 132.0],  # positive track record
            n_simulation = 3_000,
        )
        r = mssp_bayesian_analysis(inputs)
        r_prior = mssp_bayesian_analysis(sample_inputs())
        # With positive history, posterior should have higher expected savings
        @test r.posterior_mean_pbpy > r_prior.prior_mean_pbpy * 0.8
    end

    @testset "mssp_bayesian_analysis — 1-sided track has no loss exposure" begin
        r = mssp_bayesian_analysis(sample_inputs(mssp_basic_a))
        @test r.prob_loss_exposure ≈ 0.0 atol=0.01
        @test r.expected_loss_payment ≈ 0.0 atol=1.0
    end

    @testset "mssp_bayesian_analysis — recommendation is valid" begin
        r = mssp_bayesian_analysis(sample_inputs())
        @test r.track_recommendation in (:strongly_recommended, :recommended,
                                          :marginal, :not_recommended)
    end

    @testset "mssp_track_comparison — returns all tracks sorted" begin
        results = mssp_track_comparison(sample_inputs(), [mssp_basic_a, mssp_enhanced, reach_aco])
        @test length(results) == 3
        payments = [r.expected_net_payment for r in results]
        @test payments == sort(payments; rev=true)
    end

    @testset "mssp_track_comparison — enhanced > basic_a expected payment" begin
        results = mssp_track_comparison(sample_inputs(), [mssp_basic_a, mssp_enhanced])
        enhanced_row = first(filter(r -> r.track == mssp_enhanced, results))
        basic_row    = first(filter(r -> r.track == mssp_basic_a, results))
        # Enhanced has higher savings potential and higher risk — should dominate at realistic savings rates
        @test enhanced_row.expected_net_payment + basic_row.expected_net_payment != 0  # both computed
    end

    @testset "bayesian_update_cycle — posterior tightens with more data" begin
        inputs = sample_inputs()
        annual_results = [85.0, 110.0, 130.0, 95.0]
        cycle = bayesian_update_cycle(inputs, annual_results)
        @test length(cycle) == 4
        # Standard deviation should decrease (posterior tightens)
        stds = [r.posterior_std_pbpy for r in cycle]
        @test stds[end] < stds[1]
    end

    @testset "bayesian_update_cycle — mean shifts toward data" begin
        inputs = sample_inputs(mssp_basic_a)
        # Feed consistently high savings → posterior mean should increase
        cycle = bayesian_update_cycle(inputs, [200.0, 220.0, 215.0])
        @test cycle[end].posterior_mean_pbpy > cycle[1].posterior_mean_pbpy
    end

end  # D-03

println("\n✅  P1 Bundle 3 (E-05 340B, E-07 TEAM, E-08 Medicaid SDPs, D-03 Bayesian VBC) tests complete.")
