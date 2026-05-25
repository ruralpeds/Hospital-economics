using Test

include(joinpath(@__DIR__, "..", "src", "quality", "cms_programs.jl"))

# ═══════════════════════════════════════════════════════════════
# VBP — Value-Based Purchasing
# ═══════════════════════════════════════════════════════════════

@testset "VBP — Value-Based Purchasing" begin
    @testset "basic VBP calculation" begin
        clinical = [VBPMeasure(measure_id="AMI-7a", achievement_points=8.0,
                               improvement_points=6.0, benchmark=0.95,
                               floor=0.70, threshold=0.85)]
        safety = [VBPMeasure(measure_id="PSI-90", achievement_points=7.0,
                              improvement_points=5.0, benchmark=0.90,
                              floor=0.65, threshold=0.80)]
        person = [VBPMeasure(measure_id="HCAHPS-1", achievement_points=6.0,
                              improvement_points=7.0, benchmark=0.88,
                              floor=0.60, threshold=0.75)]
        efficiency = [VBPMeasure(measure_id="MSPB-1", achievement_points=5.0,
                                  improvement_points=4.0, benchmark=1.05,
                                  floor=0.90, threshold=0.93)]

        result = calculate_vbp(clinical, safety, person, efficiency, 10_000_000.0)

        @test result.total_performance_score > 0.0
        @test result.total_performance_score <= 100.0
        @test length(result.domain_scores) == 4
        @test result.domain_scores[1].domain_name == "Clinical"
        @test result.domain_scores[2].domain_name == "Safety"
        @test result.payment_multiplier > 0.0
    end

    @testset "VBP with empty domains" begin
        clinical = [VBPMeasure(measure_id="M1", achievement_points=10.0,
                               improvement_points=10.0, benchmark=1.0,
                               floor=0.0, threshold=0.5)]
        result = calculate_vbp(clinical, VBPMeasure[], VBPMeasure[], VBPMeasure[], 5_000_000.0)

        # Only clinical contributes; other domains are 0
        @test result.total_performance_score == 100.0 * 0.25
        @test result.payment_multiplier > 0.0
    end

    @testset "VBP perfect scores" begin
        perfect = [VBPMeasure(measure_id="P1", achievement_points=10.0,
                               improvement_points=10.0, benchmark=1.0,
                               floor=0.0, threshold=0.5)]
        result = calculate_vbp(perfect, perfect, perfect, perfect, 10_000_000.0)

        @test result.total_performance_score == 100.0
        # With default slope 0.005 and withhold 0.02:
        # multiplier = 1 - 0.02 + (100/100) * 0.005 = 0.985
        @test result.payment_multiplier ≈ 0.985
    end

    @testset "VBP custom exchange slope" begin
        m = [VBPMeasure(measure_id="M1", achievement_points=5.0,
                         improvement_points=5.0, benchmark=1.0,
                         floor=0.0, threshold=0.5)]
        r1 = calculate_vbp(m, m, m, m, 1_000_000.0; exchange_function_slope=0.01)
        r2 = calculate_vbp(m, m, m, m, 1_000_000.0; exchange_function_slope=0.005)
        # Higher slope => payment multiplier deviates more from 1.0
        @test r1.payment_multiplier != r2.payment_multiplier
    end
end

# ═══════════════════════════════════════════════════════════════
# HACRP — Hospital-Acquired Condition Reduction Program
# ═══════════════════════════════════════════════════════════════

@testset "HACRP — Hospital-Acquired Condition Reduction Program" begin
    @testset "no penalty — good hospital" begin
        measures = [
            HACRPMeasure(measure_id="CLABSI", observed=2.0, predicted=5.0, z_score=-1.0),
            HACRPMeasure(measure_id="CAUTI", observed=1.0, predicted=4.0, z_score=-0.5),
        ]
        result = calculate_hacrp(measures)

        @test result.total_score < 0.0
        @test !result.penalty_applies
        @test result.penalty_pct == 0.0
    end

    @testset "penalty applies — bottom quartile" begin
        measures = [
            HACRPMeasure(measure_id="CLABSI", observed=10.0, predicted=3.0, z_score=2.5),
            HACRPMeasure(measure_id="CAUTI", observed=8.0, predicted=2.0, z_score=2.0),
        ]
        result = calculate_hacrp(measures)

        @test result.total_score > 0.75
        @test result.penalty_applies
        @test result.penalty_pct == -0.01
    end

    @testset "winsorization clamps extreme z-scores" begin
        measures = [
            HACRPMeasure(measure_id="PSI90", observed=20.0, predicted=2.0, z_score=5.0),
        ]
        result = calculate_hacrp(measures)

        # z-score of 5.0 should be winsorized to 3.0
        @test result.total_score == 3.0
        @test result.penalty_applies
    end

    @testset "empty measures" begin
        result = calculate_hacrp(HACRPMeasure[])
        @test result.total_score == 0.0
        @test !result.penalty_applies
        @test result.penalty_pct == 0.0
    end

    @testset "boundary — exactly at cutoff" begin
        measures = [
            HACRPMeasure(measure_id="M1", observed=5.0, predicted=5.0, z_score=0.75),
        ]
        result = calculate_hacrp(measures)
        # Score == cutoff should NOT trigger penalty (strictly greater than)
        @test !result.penalty_applies
    end
end

# ═══════════════════════════════════════════════════════════════
# HRRP — Hospital Readmissions Reduction Program
# ═══════════════════════════════════════════════════════════════

@testset "HRRP — Hospital Readmissions Reduction Program" begin
    @testset "compliant hospital — no penalty" begin
        conditions = [
            HRRPCondition(condition=:ami, predicted=90.0, expected=100.0),
            HRRPCondition(condition=:hf, predicted=80.0, expected=100.0),
        ]
        result = calculate_hrrp(conditions, 5_000_000.0)

        @test result.payment_adjustment == 1.0
        @test result.penalty_pct == 0.0
        @test all(cr.excess_readmission_ratio <= 1.0 for cr in result.condition_results)
    end

    @testset "excess readmissions — penalty applied" begin
        conditions = [
            HRRPCondition(condition=:ami, predicted=120.0, expected=100.0),
            HRRPCondition(condition=:hf, predicted=110.0, expected=100.0),
        ]
        result = calculate_hrrp(conditions, 5_000_000.0)

        @test result.payment_adjustment < 1.0
        @test result.penalty_pct < 0.0
        @test result.condition_results[1].excess_readmission_ratio ≈ 1.2
    end

    @testset "penalty capped at 3%" begin
        conditions = [
            HRRPCondition(condition=:ami, predicted=200.0, expected=100.0),
            HRRPCondition(condition=:hf, predicted=200.0, expected=100.0),
        ]
        result = calculate_hrrp(conditions, 5_000_000.0)

        @test result.payment_adjustment >= 0.97
        @test result.penalty_pct >= -3.0
    end

    @testset "dual-eligible adjustment" begin
        cond_no_adj = HRRPCondition(condition=:ami, predicted=110.0, expected=100.0,
                                     dual_eligible_adj=1.0)
        cond_adj = HRRPCondition(condition=:ami, predicted=110.0, expected=100.0,
                                  dual_eligible_adj=0.95)
        r1 = calculate_hrrp([cond_no_adj], 5_000_000.0)
        r2 = calculate_hrrp([cond_adj], 5_000_000.0)

        # Dual-eligible adjustment reduces ERR
        @test r2.condition_results[1].excess_readmission_ratio <
              r1.condition_results[1].excess_readmission_ratio
    end

    @testset "empty conditions" begin
        result = calculate_hrrp(HRRPCondition[], 5_000_000.0)
        @test result.payment_adjustment == 1.0
        @test isempty(result.condition_results)
    end
end

# ═══════════════════════════════════════════════════════════════
# Star Ratings
# ═══════════════════════════════════════════════════════════════

@testset "Star Ratings" begin
    @testset "basic star rating" begin
        measures = [
            StarRatingsMeasure(measure_id="M1", score=0.8, weight=0.22, group="Mortality"),
            StarRatingsMeasure(measure_id="M2", score=0.7, weight=0.22, group="Safety"),
            StarRatingsMeasure(measure_id="M3", score=0.6, weight=0.22, group="Readmission"),
            StarRatingsMeasure(measure_id="M4", score=0.75, weight=0.22, group="Patient Experience"),
            StarRatingsMeasure(measure_id="M5", score=0.65, weight=0.12, group="Timely Care"),
        ]
        result = calculate_star_ratings(measures)

        @test 1 <= result.overall_stars <= 5
        @test result.weighted_score > 0.0
        @test length(result.group_scores) == 5
    end

    @testset "perfect scores yield 5 stars" begin
        measures = [
            StarRatingsMeasure(measure_id="M1", score=1.0, weight=1.0, group="G1"),
            StarRatingsMeasure(measure_id="M2", score=1.0, weight=1.0, group="G2"),
        ]
        result = calculate_star_ratings(measures)

        @test result.overall_stars == 5
        @test result.weighted_score ≈ 1.0
    end

    @testset "poor scores yield low stars" begin
        measures = [
            StarRatingsMeasure(measure_id="M1", score=0.05, weight=1.0, group="G1"),
            StarRatingsMeasure(measure_id="M2", score=0.05, weight=1.0, group="G2"),
        ]
        result = calculate_star_ratings(measures)

        @test result.overall_stars <= 2
        @test result.weighted_score < 0.2
    end

    @testset "empty measures" begin
        result = calculate_star_ratings(StarRatingsMeasure[])
        @test result.overall_stars == 1
        @test result.weighted_score == 0.0
    end

    @testset "sensitivity analysis" begin
        measures = [
            StarRatingsMeasure(measure_id="M1", score=0.5, weight=1.0, group="G1"),
            StarRatingsMeasure(measure_id="M2", score=0.5, weight=1.0, group="G2"),
        ]
        deltas = star_ratings_sensitivity(measures, 5)

        @test haskey(deltas, "G1")
        @test haskey(deltas, "G2")
        @test deltas["G1"] > 0.0  # need to improve
    end

    @testset "sensitivity — invalid target" begin
        measures = [StarRatingsMeasure(measure_id="M1", score=0.5, weight=1.0, group="G1")]
        @test_throws ErrorException star_ratings_sensitivity(measures, 6)
    end
end

# ═══════════════════════════════════════════════════════════════
# MIPS — Merit-Based Incentive Payment System
# ═══════════════════════════════════════════════════════════════

@testset "MIPS — Merit-Based Incentive Payment System" begin
    @testset "above threshold — positive adjustment" begin
        result = calculate_mips(90.0, 85.0, 80.0, 100.0)

        @test result.final_score > 75.0
        @test result.payment_adjustment_pct > 0.0
        @test length(result.categories) == 4
        @test result.categories[1].category_name == "Quality"
        @test result.categories[1].weight == 0.30
    end

    @testset "below threshold — negative adjustment" begin
        result = calculate_mips(30.0, 40.0, 50.0, 20.0)

        @test result.final_score < 75.0
        @test result.payment_adjustment_pct < 0.0
    end

    @testset "at threshold — zero adjustment" begin
        # Find scores that give exactly 75.0 weighted:
        # 75 * 0.30 + 75 * 0.30 + 75 * 0.25 + 75 * 0.15 = 75
        result = calculate_mips(75.0, 75.0, 75.0, 75.0)

        @test result.final_score ≈ 75.0
        @test result.payment_adjustment_pct ≈ 0.0 atol=0.001
    end

    @testset "exceptional performance — max adjustment" begin
        result = calculate_mips(100.0, 100.0, 100.0, 100.0)

        @test result.final_score == 100.0
        @test result.payment_adjustment_pct == 9.0
    end

    @testset "correct weights" begin
        # Quality 30%, Cost 30%, PI 25%, IA 15%
        result = calculate_mips(100.0, 0.0, 0.0, 0.0)
        @test result.final_score ≈ 30.0

        result2 = calculate_mips(0.0, 100.0, 0.0, 0.0)
        @test result2.final_score ≈ 30.0

        result3 = calculate_mips(0.0, 0.0, 100.0, 0.0)
        @test result3.final_score ≈ 25.0

        result4 = calculate_mips(0.0, 0.0, 0.0, 100.0)
        @test result4.final_score ≈ 15.0
    end
end

# ═══════════════════════════════════════════════════════════════
# HAI — Healthcare-Associated Infections
# ═══════════════════════════════════════════════════════════════

@testset "HAI — Healthcare-Associated Infections" begin
    @testset "basic SIR calculation" begin
        records = [
            HAIRecord(infection_type=:CLABSI, observed_events=3, predicted_events=5.0,
                      device_days_or_patient_days=1200.0),
            HAIRecord(infection_type=:CAUTI, observed_events=2, predicted_events=4.0,
                      device_days_or_patient_days=1500.0),
        ]
        result = calculate_hai(records)

        @test length(result.type_results) == 2
        @test result.overall_composite ≈ 5.0 / 9.0 atol=0.01
        @test result.compliance_flag  # SIR < 1.0
    end

    @testset "SIR above 1.0 — non-compliant" begin
        records = [
            HAIRecord(infection_type=:MRSA, observed_events=10, predicted_events=3.0,
                      device_days_or_patient_days=500.0),
        ]
        result = calculate_hai(records)

        @test result.type_results[1].sir ≈ 10.0 / 3.0 atol=0.01
        @test !result.compliance_flag
    end

    @testset "multiple records same infection type" begin
        records = [
            HAIRecord(infection_type=:CDI, observed_events=2, predicted_events=3.0,
                      device_days_or_patient_days=1000.0),
            HAIRecord(infection_type=:CDI, observed_events=3, predicted_events=4.0,
                      device_days_or_patient_days=1200.0),
        ]
        result = calculate_hai(records)

        @test length(result.type_results) == 1
        @test result.type_results[1].observed == 5
        @test result.type_results[1].predicted ≈ 7.0
        @test result.type_results[1].sir ≈ 5.0 / 7.0 atol=0.01
    end

    @testset "empty records" begin
        result = calculate_hai(HAIRecord[])
        @test isempty(result.type_results)
        @test result.overall_composite == 0.0
        @test result.compliance_flag
    end

    @testset "zero predicted events" begin
        records = [
            HAIRecord(infection_type=:SSI, observed_events=0, predicted_events=0.0,
                      device_days_or_patient_days=100.0),
        ]
        result = calculate_hai(records)
        @test result.type_results[1].sir == 0.0
    end
end

# ═══════════════════════════════════════════════════════════════
# Combined Payment Impact
# ═══════════════════════════════════════════════════════════════

@testset "Combined Payment Impact" begin
    @testset "all programs — typical scenario" begin
        # Create component results
        vbp = VBPResult(
            domain_scores=VBPDomainScore[],
            total_performance_score=50.0,
            payment_multiplier=0.9825,
            net_adjustment_pct=-1.75,
        )
        hacrp = HACRPResult(
            total_score=0.5, percentile=58.3,
            penalty_applies=false, penalty_pct=0.0,
        )
        hrrp = HRRPResult(
            condition_results=HRRPConditionResult[],
            payment_adjustment=0.985,
            penalty_pct=-1.5,
        )

        result = calculate_combined_payment_impact(vbp, hacrp, hrrp, 10_000_000.0)

        @test result.vbp_adjustment ≈ -0.0175
        @test result.hacrp_penalty == 0.0
        @test result.hrrp_penalty ≈ -0.015
        @test result.net_impact_pct < 0.0
        @test result.net_impact_dollars < 0.0
    end

    @testset "no penalties — neutral impact" begin
        vbp = VBPResult(
            domain_scores=VBPDomainScore[],
            total_performance_score=50.0,
            payment_multiplier=1.0,
            net_adjustment_pct=0.0,
        )
        hacrp = HACRPResult(
            total_score=0.0, percentile=50.0,
            penalty_applies=false, penalty_pct=0.0,
        )
        hrrp = HRRPResult(
            condition_results=HRRPConditionResult[],
            payment_adjustment=1.0,
            penalty_pct=0.0,
        )

        result = calculate_combined_payment_impact(vbp, hacrp, hrrp, 10_000_000.0)

        @test result.net_impact_pct ≈ 0.0 atol=1e-10
        @test result.net_impact_dollars ≈ 0.0 atol=1e-6
    end

    @testset "all penalties stacked" begin
        vbp = VBPResult(
            domain_scores=VBPDomainScore[],
            total_performance_score=20.0,
            payment_multiplier=0.979,
            net_adjustment_pct=-2.1,
        )
        hacrp = HACRPResult(
            total_score=2.0, percentile=92.0,
            penalty_applies=true, penalty_pct=-0.01,
        )
        hrrp = HRRPResult(
            condition_results=HRRPConditionResult[],
            payment_adjustment=0.97,
            penalty_pct=-3.0,
        )

        result = calculate_combined_payment_impact(vbp, hacrp, hrrp, 10_000_000.0)

        # All three penalties should compound
        @test result.net_impact_pct < -2.0
        @test result.net_impact_dollars < -200_000.0
    end

    @testset "multiplicative — not additive" begin
        vbp = VBPResult(domain_scores=VBPDomainScore[],
                         total_performance_score=0.0, payment_multiplier=0.98,
                         net_adjustment_pct=-2.0)
        hacrp = HACRPResult(total_score=2.0, percentile=90.0,
                             penalty_applies=true, penalty_pct=-0.01)
        hrrp = HRRPResult(condition_results=HRRPConditionResult[],
                           payment_adjustment=0.97, penalty_pct=-3.0)

        result = calculate_combined_payment_impact(vbp, hacrp, hrrp, 10_000_000.0)

        # Multiplicative: (1-0.02) * (1-0.01) * (1-0.03) = 0.98 * 0.99 * 0.97
        expected_mult = 0.98 * 0.99 * 0.97
        expected_pct = (expected_mult - 1.0) * 100.0
        @test result.net_impact_pct ≈ expected_pct atol=0.01
    end
end
