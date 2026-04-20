# ============================================================================
# Tests for ML-Enhanced Closure Prediction (src/risk/closure_ml.jl)
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "risk", "closure_ml.jl"))

@testset "Closure ML Prediction" begin

    @testset "struct construction" begin
        f = ClosureMLFeatures()
        @test f.case_mix_index == 1.0
        @test f.occupancy_rate == 0.30
        @test f.years_negative_operating_margin == 0
        @test f.state_has_medicaid_expansion == true
    end

    @testset "predict_closure_logistic — healthy hospital" begin
        healthy = ClosureMLFeatures(
            occupancy_rate=0.55, avg_age_of_plant=8.0,
            years_negative_operating_margin=0, case_mix_index=1.3,
            pct_change_net_patient_revenue=0.05, state_has_medicaid_expansion=true,
            is_government_controlled=true, traditional_medicare_pct_days=0.30,
            avg_length_of_stay=3.0,
        )
        result = predict_closure_logistic(healthy)
        @test result.logistic_probability < 0.20
        @test result.risk_tier in (:low, :moderate)
        @test length(result.protective_factors) > 0
        @test result.chartis_vulnerability_score < 30.0
    end

    @testset "predict_closure_logistic — distressed hospital" begin
        distressed = ClosureMLFeatures(
            occupancy_rate=0.15, avg_age_of_plant=22.0,
            years_negative_operating_margin=4, case_mix_index=0.8,
            pct_change_net_patient_revenue=-0.10, state_has_medicaid_expansion=false,
            is_government_controlled=false, traditional_medicare_pct_days=0.60,
            avg_length_of_stay=5.5,
        )
        result = predict_closure_logistic(distressed)
        @test result.logistic_probability > 0.50
        @test result.risk_tier in (:high, :critical)
        @test length(result.key_risk_factors) >= 3
        @test result.chartis_vulnerability_score > 50.0
    end

    @testset "chartis_vulnerability_score" begin
        low_risk = ClosureMLFeatures(occupancy_rate=0.60, avg_age_of_plant=5.0,
            years_negative_operating_margin=0, pct_change_net_patient_revenue=0.05,
            case_mix_index=1.4, state_has_medicaid_expansion=true,
            is_government_controlled=true)
        @test chartis_vulnerability_score(low_risk) < 20.0

        high_risk = ClosureMLFeatures(occupancy_rate=0.10, avg_age_of_plant=25.0,
            years_negative_operating_margin=5, pct_change_net_patient_revenue=-0.15,
            case_mix_index=0.7, state_has_medicaid_expansion=false,
            is_government_controlled=false)
        @test chartis_vulnerability_score(high_risk) > 60.0

        # Score always in 0-100
        @test 0.0 <= chartis_vulnerability_score(ClosureMLFeatures()) <= 100.0
    end

    @testset "closure_risk_trend" begin
        # Worsening trajectory
        years = [
            ClosureMLFeatures(occupancy_rate=0.40, years_negative_operating_margin=0),
            ClosureMLFeatures(occupancy_rate=0.30, years_negative_operating_margin=1),
            ClosureMLFeatures(occupancy_rate=0.20, years_negative_operating_margin=2),
            ClosureMLFeatures(occupancy_rate=0.15, years_negative_operating_margin=3),
        ]
        trend = closure_risk_trend(years)
        @test length(trend) == 4
        @test trend[1].year_index == 1
        @test trend[1].delta == 0.0  # first year has no delta
        # Each subsequent year should have higher probability
        for i in 2:4
            @test trend[i].probability >= trend[i-1].probability
        end

        # Improving trajectory
        improving = [
            ClosureMLFeatures(occupancy_rate=0.20, years_negative_operating_margin=3),
            ClosureMLFeatures(occupancy_rate=0.35, years_negative_operating_margin=2),
            ClosureMLFeatures(occupancy_rate=0.50, years_negative_operating_margin=1),
        ]
        trend2 = closure_risk_trend(improving)
        @test trend2[3].probability < trend2[1].probability
    end

    @testset "edge cases" begin
        # Single year trend
        single = closure_risk_trend([ClosureMLFeatures()])
        @test length(single) == 1
        @test single[1].delta == 0.0

        # Default features should produce valid result
        result = predict_closure_logistic(ClosureMLFeatures())
        @test 0.0 <= result.logistic_probability <= 1.0
        @test result.risk_tier in (:low, :moderate, :high, :critical)
    end
end
