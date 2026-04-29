"""
    test_mba_domain_e.jl — Tests for MBA Domain E Reimbursement Analytics

Covers:
  E-01  CAH outlier payments (fixed-loss threshold, TEFRA, bad debt, swing-bed, E-1 summary)
  E-03  Medicare Advantage v28 (HCC coefficients, RAF calculation, normalization,
        rural pass-through, capitation, penetration impact)
  E-06  MIPS / VBP / HRRP / HACRP (actual CMS scoring algorithms, payment adjustments)
"""

using Test
using Statistics

# ═════════════════════════════════════════════════════════════════════════════
# E-01: CAH Outlier Payments & TEFRA
# ═════════════════════════════════════════════════════════════════════════════

@testset "E-01 CAH Outlier & TEFRA" begin

    @testset "Constants defined" begin
        @test CAH_OUTLIER_FIXED_LOSS_THRESHOLD_FY2026 > 0
        @test CAH_OUTLIER_MARGINAL_RATE == 0.80
        @test CAH_BAD_DEBT_REIMBURSEMENT_RATE == 1.00
    end

    @testset "cah_outlier_payment — non-outlier case" begin
        c = CAHOutlierCase(drg_weight=1.2, actual_cost=25_000.0, los_days=4)
        p = cah_outlier_payment(c; cah_ccr=0.42, base_rate=6_800.0)
        @test !p.is_outlier
        @test p.outlier_payment ≈ 0.0
        @test p.base_cost_reimbursement ≈ 25_000.0 * 1.01 atol=1e-2
    end

    @testset "cah_outlier_payment — outlier case" begin
        # actual_cost = 90,000; drg_equiv = 6800 × 3.8 = 25,840; threshold = 38788 + 25840 = 64628
        c = CAHOutlierCase(drg_weight=3.8, actual_cost=90_000.0, los_days=15)
        p = cah_outlier_payment(c; cah_ccr=0.42, base_rate=6_800.0)
        @test p.is_outlier
        @test p.outlier_costs_above_threshold ≈ 90_000.0 - p.outlier_threshold_amount atol=1.0
        @test p.outlier_payment ≈ p.outlier_costs_above_threshold * 0.80 atol=1.0
    end

    @testset "cah_outlier_payment — sequestration reduces total" begin
        c = CAHOutlierCase(drg_weight=4.0, actual_cost=100_000.0, los_days=18)
        p_seq   = cah_outlier_payment(c; sequestration=true)
        p_noseq = cah_outlier_payment(c; sequestration=false)
        @test p_seq.total_after_sequestration < p_noseq.total_after_sequestration
        @test p_noseq.total_after_sequestration ≈ p_noseq.total_payment atol=1e-4
    end

    @testset "cah_outlier_analysis — outlier rate" begin
        cases = [
            CAHOutlierCase(drg_weight=1.0, actual_cost=20_000.0, los_days=3),  # not outlier
            CAHOutlierCase(drg_weight=5.0, actual_cost=150_000.0, los_days=22), # outlier
            CAHOutlierCase(drg_weight=2.5, actual_cost=40_000.0, los_days=7),  # maybe
        ]
        r = cah_outlier_analysis(cases)
        @test r.n_outliers >= 1
        @test 0.0 <= r.outlier_rate <= 1.0
        @test r.total_outlier_payment >= 0.0
        @test r.total_payment > r.total_base_reimbursement - 1.0  # outlier adds to total
    end

    @testset "tefra_payment — below target (incentive)" begin
        data = TEFRAHospitalData(
            hospital_type                = :psychiatric,
            base_year_cost_per_discharge = 12_000.0,
            base_year                    = 2020,
            current_year                 = 2026,
            actual_cost_per_discharge    = 13_000.0,
            discharges                   = 400,
            market_basket_updates        = fill(0.032, 6),
        )
        r = tefra_payment(data)
        # Target after 6 years at 3.2%/yr
        expected_target = 12_000.0 * (1.032^6)
        @test r.target_rate ≈ expected_target atol=10.0
        @test r.performance == :under_target   # actual < target
        @test r.incentive_payment > 0
        @test r.penalty_amount ≈ 0.0
    end

    @testset "tefra_payment — above penalty threshold" begin
        data = TEFRAHospitalData(
            hospital_type                = :childrens,
            base_year_cost_per_discharge = 10_000.0,
            base_year                    = 2020,
            current_year                 = 2026,
            actual_cost_per_discharge    = 18_000.0,  # >> 110% of target
            discharges                   = 200,
            market_basket_updates        = fill(0.030, 6),
        )
        r = tefra_payment(data)
        @test r.performance == :above_penalty
        @test r.penalty_amount > 0
        @test r.incentive_payment ≈ 0.0
        @test r.total_payment < r.actual_cost_per_discharge * data.discharges
    end

    @testset "tefra_payment — invalid hospital type" begin
        @test_throws ArgumentError tefra_payment(TEFRAHospitalData(
            hospital_type=:urban_pps, base_year_cost_per_discharge=10_000.0,
            base_year=2020, current_year=2026,
            actual_cost_per_discharge=11_000.0, discharges=100))
    end

    @testset "tefra_payment — current_year must be > base_year" begin
        @test_throws ArgumentError tefra_payment(TEFRAHospitalData(
            hospital_type=:psychiatric, base_year_cost_per_discharge=10_000.0,
            base_year=2026, current_year=2025,
            actual_cost_per_discharge=11_000.0, discharges=100))
    end

    @testset "cah_bad_debt_reimbursement — CAH vs PPS" begin
        r_cah = cah_bad_debt_reimbursement(500_000.0; hospital_type=:cah)
        r_pps = cah_bad_debt_reimbursement(500_000.0; hospital_type=:pps)
        @test r_cah.bad_debt_reimbursement ≈ 500_000.0 atol=1.0
        @test r_pps.bad_debt_reimbursement ≈ 325_000.0 atol=1.0
        @test r_cah.incremental_over_pps   ≈ 175_000.0 atol=1.0
    end

    @testset "cah_swing_bed_payment" begin
        r = cah_swing_bed_payment(300; snf_per_diem=284.62, wage_index=0.95)
        @test r.swing_bed_days == 300
        @test r.per_diem_adjusted < 284.62   # wage index < 1 reduces the rate
        @test r.net_payment < r.gross_payment   # sequestration reduces
    end

    @testset "cah_worksheet_e1 — comprehensive settlement" begin
        inputs = CAHWorksheetE1Inputs(
            medicare_inpatient_costs  = 4_500_000.0,
            medicare_outpatient_costs = 2_200_000.0,
            medicare_bad_debt         = 180_000.0,
            outlier_cases             = [
                CAHOutlierCase(drg_weight=4.0, actual_cost=90_000.0, los_days=14),
            ],
            swing_bed_days            = 250,
            wage_index                = 1.02,
        )
        r = cah_worksheet_e1(inputs)
        @test r.inpatient_cost_reimbursement > 0
        @test r.outpatient_cost_reimbursement > 0
        @test r.bad_debt_reimbursement ≈ 180_000.0 atol=1.0
        @test r.net_settlement < r.subtotal_before_sequestration
        @test r.sequestration_reduction > 0
        @test r.net_settlement > 0
    end

end  # E-01


# ═════════════════════════════════════════════════════════════════════════════
# E-03: Medicare Advantage v28
# ═════════════════════════════════════════════════════════════════════════════

@testset "E-03 Medicare Advantage v28" begin

    @testset "HCC_V28_CNA_COEFFICIENTS — key conditions present" begin
        for code in ["HCC008","HCC079","HCC111","HCC017","HCC134","HCC067","HCC076"]
            @test haskey(HCC_V28_CNA_COEFFICIENTS, code) "Missing: $code"
        end
    end

    @testset "HCC_V28_CNA_COEFFICIENTS — high-acuity > low-acuity" begin
        @test HCC_V28_CNA_COEFFICIENTS["HCC008"] > HCC_V28_CNA_COEFFICIENTS["HCC019"]  # metastatic > dm no cx
        @test HCC_V28_CNA_COEFFICIENTS["HCC076"] > HCC_V28_CNA_COEFFICIENTS["HCC085"]  # vent > HTN
        @test HCC_V28_CNA_COEFFICIENTS["HCC067"] > HCC_V28_CNA_COEFFICIENTS["HCC069"]  # quadriplegia > spinal cord d/o
    end

    @testset "ma_normalization_factor — known years" begin
        @test ma_normalization_factor(2024) ≈ 0.941
        @test ma_normalization_factor(2025) ≈ 0.923
        @test ma_normalization_factor(2026) > 0.85
    end

    @testset "ma_demographic_factor — female older > younger" begin
        f70 = ma_demographic_factor(72, :female)
        f80 = ma_demographic_factor(82, :female)
        f90 = ma_demographic_factor(92, :female)
        @test f70 < f80 < f90
    end

    @testset "ma_demographic_factor — male ≈ female at same age" begin
        m75 = ma_demographic_factor(75, :male)
        f75 = ma_demographic_factor(75, :female)
        @test abs(m75 - f75) < 0.05   # within 5 pp
    end

    @testset "calculate_ma_raf — healthy member (no HCCs)" begin
        m = MAMemberRAF(age=70, sex=:female, hcc_codes=String[])
        r = calculate_ma_raf(m; contract_year=2026)
        @test r.normalized_raf > 0
        @test r.hcc_factor_sum ≈ 0.0
        @test r.interaction_factor_sum ≈ 0.0
        @test r.risk_category == :low
    end

    @testset "calculate_ma_raf — high-acuity member" begin
        m = MAMemberRAF(age=78, sex=:male,
                        hcc_codes=["HCC008","HCC079","HCC111","HCC017"])  # cancer + CHF + COPD + DM
        r = calculate_ma_raf(m; contract_year=2026)
        @test r.normalized_raf > 2.0   # very high acuity
        @test r.risk_category in (:high, :very_high)
        @test !isempty(r.hccs_recognized)
    end

    @testset "calculate_ma_raf — CHF_COPD interaction triggered" begin
        m = MAMemberRAF(age=75, sex=:female,
                        hcc_codes=["HCC079","HCC111"])  # CHF + COPD
        r = calculate_ma_raf(m; contract_year=2026)
        @test "CHF_COPD" in r.interactions_triggered
        @test r.interaction_factor_sum > 0
    end

    @testset "calculate_ma_raf — unrecognized codes tracked" begin
        m = MAMemberRAF(age=70, sex=:male,
                        hcc_codes=["HCC999","HCC079"])   # HCC999 doesn't exist
        r = calculate_ma_raf(m; contract_year=2026)
        @test "HCC999" in r.hccs_unrecognized
        @test "HCC079" in r.hccs_recognized
    end

    @testset "calculate_ma_raf — normalization reduces raw RAF" begin
        m = MAMemberRAF(age=75, sex=:female, hcc_codes=["HCC079","HCC085"])
        r = calculate_ma_raf(m; contract_year=2026)
        @test r.normalized_raf < r.raw_raf
        @test r.normalized_raf ≈ r.raw_raf * ma_normalization_factor(2026) atol=1e-6
    end

    @testset "calculate_ma_raf — DIABETES_CHF interaction" begin
        m = MAMemberRAF(age=72, sex=:female,
                        hcc_codes=["HCC019","HCC079"])  # DM no cx + CHF
        r = calculate_ma_raf(m; contract_year=2026)
        @test "DIABETES_CHF" in r.interactions_triggered
    end

    @testset "ma_rural_passthrough_payment" begin
        r = ma_rural_passthrough_payment(15_000.0)
        @test r.minimum_ma_payment ≈ 15_000.0 * 0.85 atol=1e-2
        @test r.protection_amount  ≈ 15_000.0 * 0.15 atol=1e-2
        @test r.passthrough_rate == MA_RURAL_PASSTHROUGH_RATE
    end

    @testset "ma_county_capitation — quality bonus for 4-star plan" begin
        inp = MACountyCapitationInputs(
            county_base_rate_pmpm       = 1_100.0,
            plan_bid_pct_of_benchmark   = 1.0,
            star_rating                 = 4.2,
            mean_member_raf             = 1.05,
            n_members                   = 500,
        )
        r = ma_county_capitation(inp)
        @test r.quality_bonus_rate == 0.035
        @test r.adjusted_benchmark_pmpm ≈ 1_100.0 * 1.035 atol=0.01
        @test r.plan_payment_pmpm ≈ r.adjusted_benchmark_pmpm * 1.05 atol=0.01
        @test r.total_annual_plan_revenue > 0
    end

    @testset "ma_county_capitation — no bonus below 4 stars" begin
        inp = MACountyCapitationInputs(
            county_base_rate_pmpm = 1_100.0, star_rating = 3.5, n_members = 200)
        r = ma_county_capitation(inp)
        @test r.quality_bonus_rate == 0.0
    end

    @testset "ma_penetration_revenue_impact — rural hospital always ≥ 85% FFS" begin
        r = ma_penetration_revenue_impact(200, 12_000.0;
                ma_payment_rate_pct=0.82, passthrough_protected=true)
        @test r.effective_ma_rate_pct >= MA_RURAL_PASSTHROUGH_RATE
        @test r.effective_ma_rate_pct ≈ MA_RURAL_PASSTHROUGH_RATE  # 0.85 > 0.82
    end

    @testset "ma_penetration_revenue_impact — negative impact vs FFS" begin
        r = ma_penetration_revenue_impact(300, 10_000.0; ma_payment_rate_pct=0.88)
        @test r.revenue_differential < 0   # MA pays less than FFS
        @test r.ffs_revenue > r.ma_revenue
    end

end  # E-03


# ═════════════════════════════════════════════════════════════════════════════
# E-06: MIPS / VBP / HRRP / HACRP
# ═════════════════════════════════════════════════════════════════════════════

@testset "E-06 Quality Payment Programs" begin

    # ── MIPS ──────────────────────────────────────────────────────────────

    @testset "MIPS — negative adjustment below threshold" begin
        scores = MIPSScores(quality_score=40.0, pi_score=50.0,
                            ia_score=30.0, cost_score=45.0)
        r = calculate_mips(scores)
        @test r.composite_score < 75.0
        @test r.payment_adjustment_pct < 0
        @test r.performance_tier == :negative
    end

    @testset "MIPS — neutral at exactly 75" begin
        # Construct scores that yield exactly 75 composite
        # 0.30×75 + 0.25×75 + 0.15×75 + 0.30×75 = 75
        scores = MIPSScores(quality_score=75.0, pi_score=75.0,
                            ia_score=75.0, cost_score=75.0)
        r = calculate_mips(scores)
        @test r.composite_score ≈ 75.0 atol=1e-6
        @test r.payment_adjustment_pct ≈ 0.0 atol=1e-6
        @test r.performance_tier == :neutral
    end

    @testset "MIPS — positive above threshold" begin
        scores = MIPSScores(quality_score=85.0, pi_score=80.0,
                            ia_score=90.0, cost_score=82.0)
        r = calculate_mips(scores)
        @test r.composite_score > 75.0
        @test r.payment_adjustment_pct > 0
        @test r.performance_tier in (:positive, :exceptional)
    end

    @testset "MIPS — exceptional performance bonus" begin
        scores = MIPSScores(quality_score=95.0, pi_score=92.0,
                            ia_score=100.0, cost_score=93.0)
        r = calculate_mips(scores)
        @test r.composite_score > 89.0
        @test r.exceptional_bonus_pct > 0
        @test r.performance_tier == :exceptional
        @test r.total_adjustment_pct == r.payment_adjustment_pct + r.exceptional_bonus_pct
    end

    @testset "MIPS — max negative adjustment ≥ -9%" begin
        scores = MIPSScores(quality_score=0.0, pi_score=0.0,
                            ia_score=0.0, cost_score=0.0)
        r = calculate_mips(scores)
        @test r.payment_adjustment_pct >= -0.09
    end

    @testset "MIPS — PI-exempt reweights to quality" begin
        scores_normal = MIPSScores(quality_score=80.0, pi_score=60.0,
                                   ia_score=70.0, cost_score=75.0)
        scores_exempt = MIPSScores(quality_score=80.0, pi_score=60.0,
                                   ia_score=70.0, cost_score=75.0, pi_exempt=true)
        r_n = calculate_mips(scores_normal)
        r_e = calculate_mips(scores_exempt)
        # PI-exempt hospital gets PI weight added to quality
        # If quality > PI score, this should increase composite
        @test r_e.composite_score != r_n.composite_score
    end

    # ── Hospital VBP ──────────────────────────────────────────────────────

    @testset "VBP — neutral TPS ≈ 50" begin
        scores = VBPDomainScores(clinical_outcomes=50.0, person_engagement=50.0,
                                  safety=50.0, efficiency=50.0)
        r = calculate_vbp(scores)
        @test r.tps ≈ 50.0 atol=1e-6
        @test abs(r.payment_adjustment_pct) < 0.001
    end

    @testset "VBP — above 50 TPS → positive adjustment" begin
        scores = VBPDomainScores(clinical_outcomes=70.0, person_engagement=75.0,
                                  safety=65.0, efficiency=72.0)
        r = calculate_vbp(scores)
        @test r.tps > 50.0
        @test r.payment_adjustment_pct > 0
        @test r.performance_tier in (:above_median, :top_performer)
    end

    @testset "VBP — below 50 TPS → negative adjustment" begin
        scores = VBPDomainScores(clinical_outcomes=30.0, person_engagement=35.0,
                                  safety=28.0, efficiency=40.0)
        r = calculate_vbp(scores)
        @test r.tps < 50.0
        @test r.payment_adjustment_pct < 0
        @test r.performance_tier == :below_median
    end

    @testset "VBP — adjustment bounded to ±2%" begin
        max_scores = VBPDomainScores(clinical_outcomes=100.0, person_engagement=100.0,
                                      safety=100.0, efficiency=100.0)
        min_scores = VBPDomainScores(clinical_outcomes=0.0,   person_engagement=0.0,
                                      safety=0.0,   efficiency=0.0)
        r_max = calculate_vbp(max_scores)
        r_min = calculate_vbp(min_scores)
        @test r_max.payment_adjustment_pct <= 0.02 + 1e-6
        @test r_min.payment_adjustment_pct >= -0.02 - 1e-6
    end

    @testset "VBP — domain weights sum to 1" begin
        w = VBP_DOMAIN_WEIGHTS_FY2026
        @test w.clinical_outcomes + w.person_engagement + w.safety + w.efficiency ≈ 1.0 atol=1e-10
    end

    # ── HRRP ──────────────────────────────────────────────────────────────

    @testset "HRRP — no excess readmissions → no penalty" begin
        measures = [
            HRRPMeasure(condition=:ami, observed_readmissions=8,
                        predicted_readmissions=8.0, expected_readmissions=9.0, discharges=90),
            HRRPMeasure(condition=:hf,  observed_readmissions=15,
                        predicted_readmissions=14.0, expected_readmissions=16.0, discharges=160),
        ]
        r = calculate_hrrp(measures)
        @test r.payment_reduction_pct >= -0.001   # ≈ 0
        @test r.performance_tier == :no_penalty
    end

    @testset "HRRP — excess readmissions → penalty" begin
        measures = [
            HRRPMeasure(condition=:hf,   observed_readmissions=32,
                        predicted_readmissions=32.0, expected_readmissions=25.0, discharges=200),
            HRRPMeasure(condition=:pna,  observed_readmissions=18,
                        predicted_readmissions=18.0, expected_readmissions=14.0, discharges=120),
            HRRPMeasure(condition=:copd, observed_readmissions=12,
                        predicted_readmissions=12.0, expected_readmissions=9.0,  discharges=85),
        ]
        r = calculate_hrrp(measures)
        @test r.payment_reduction_pct < 0
        @test r.n_conditions_excess >= 1
    end

    @testset "HRRP — penalty capped at -3%" begin
        measures = [
            HRRPMeasure(condition=:hf, observed_readmissions=1000,
                        predicted_readmissions=1000.0, expected_readmissions=100.0, discharges=500),
        ]
        r = calculate_hrrp(measures)
        @test r.payment_reduction_pct >= -0.03 - 1e-6
        @test r.performance_tier == :max_penalty
    end

    @testset "HRRP — ERR computed correctly" begin
        measures = [
            HRRPMeasure(condition=:ami, observed_readmissions=10,
                        predicted_readmissions=12.0, expected_readmissions=10.0, discharges=100),
        ]
        r = calculate_hrrp(measures)
        @test r.excess_readmission_ratios[:ami] ≈ 12.0 / 10.0 atol=1e-6
    end

    @testset "HRRP — zero expected raises error" begin
        m = HRRPMeasure(condition=:ami, observed_readmissions=5,
                        predicted_readmissions=5.0, expected_readmissions=0.0, discharges=50)
        @test_throws ArgumentError calculate_hrrp([m])
    end

    # ── HACRP ──────────────────────────────────────────────────────────────

    @testset "HACRP — average hospital (SIR ≈ 1) no penalty" begin
        inp = HACRPInputs(psi90_score=1.0, clabsi_sir=1.0, cauti_sir=1.0,
                          ssi_colon_sir=1.0, ssi_hyst_sir=1.0, mrsa_sir=1.0, cdi_sir=1.0)
        r = calculate_hacrp(inp; national_mean_hac_score=1.0)
        @test r.hac_score ≈ 1.0 atol=0.01
        @test r.payment_reduction_pct == 0.0
        @test r.performance_tier == :no_penalty
    end

    @testset "HACRP — high-HAI hospital → penalty" begin
        inp = HACRPInputs(psi90_score=1.5, clabsi_sir=2.0, cauti_sir=1.8,
                          ssi_colon_sir=1.6, ssi_hyst_sir=1.4, mrsa_sir=2.1, cdi_sir=1.7)
        r = calculate_hacrp(inp; national_mean_hac_score=1.0)
        @test r.hac_score > 1.25     # > 1.25 × mean → proxy bottom quartile
        @test r.payment_reduction_pct == -0.01
        @test r.performance_tier == :penalty
    end

    @testset "HACRP — winsorization applied" begin
        inp = HACRPInputs(psi90_score=5.0,   # > 2.0 ceiling
                          clabsi_sir=10.0,    # > 2.5 ceiling
                          cauti_sir=0.0,      # < 0.05 floor
                          ssi_colon_sir=1.0, ssi_hyst_sir=1.0, mrsa_sir=1.0, cdi_sir=1.0)
        r = calculate_hacrp(inp; is_bottom_quartile=false)
        @test r.domain1_score <= 2.0    # winsorized
        @test r.domain2_score <= 2.5
        @test r.domain2_score >= 0.05
    end

    @testset "HACRP — explicit bottom quartile flag" begin
        inp = HACRPInputs()  # average inputs
        r_penalty  = calculate_hacrp(inp; is_bottom_quartile=true)
        r_no_pen   = calculate_hacrp(inp; is_bottom_quartile=false)
        @test r_penalty.payment_reduction_pct  == -0.01
        @test r_no_pen.payment_reduction_pct   == 0.0
    end

    @testset "HACRP — domain weights sum to 1" begin
        w = HACRP_DOMAIN_WEIGHTS_FY2026
        @test w.domain1_psi90 + w.domain2_nhsn ≈ 1.0 atol=1e-10
    end

    # ── Combined Impact ────────────────────────────────────────────────────

    @testset "hospital_quality_payment_impact — combined adjustment" begin
        vbp_scores = VBPDomainScores(clinical_outcomes=60.0, person_engagement=68.0,
                                      safety=55.0, efficiency=64.0)
        hrrp_m = [
            HRRPMeasure(condition=:hf,  observed_readmissions=22,
                        predicted_readmissions=22.0, expected_readmissions=20.0, discharges=180),
            HRRPMeasure(condition=:ami, observed_readmissions=8,
                        predicted_readmissions=8.0, expected_readmissions=8.5, discharges=80),
        ]
        hacrp_in = HACRPInputs(psi90_score=1.1, clabsi_sir=1.2, cauti_sir=1.1,
                                ssi_colon_sir=0.9, ssi_hyst_sir=1.0, mrsa_sir=1.1, cdi_sir=0.8)

        impact = hospital_quality_payment_impact(
            vbp_scores, hrrp_m, hacrp_in;
            annual_ipps_revenue = 10_000_000.0,
        )
        @test impact.total_adjustment_pct == (impact.vbp_result.payment_adjustment_pct +
                                               impact.hrrp_result.payment_reduction_pct +
                                               impact.hacrp_result.payment_reduction_pct)
        @test impact.net_dollar_impact ≈ 10_000_000.0 * impact.total_adjustment_pct atol=1.0
        @test impact.net_dollar_impact isa Float64
    end

end  # E-06

println("\n✅  MBA Domain E (E-01 CAH Outliers, E-03 MA v28, E-06 MIPS/VBP/HRRP/HACRP) tests complete.")
