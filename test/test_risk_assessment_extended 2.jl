# ============================================================================
# Tests for risk assessment gaps: distress timeline, assumptions, closure ML
# ============================================================================

using Test
using Dates

# Include source
include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "department.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "staffing.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "payer.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "financial.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "capital.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "hospital.jl"))
include(joinpath(@__DIR__, "..", "src", "risk", "closure.jl"))
include(joinpath(@__DIR__, "..", "src", "risk", "conversion.jl"))
include(joinpath(@__DIR__, "..", "src", "risk", "closure_ml.jl"))

@testset "Risk Assessment Extended" begin

    # -----------------------------------------------------------------------
    @testset "estimate_distress_timeline - high risk" begin
        # High composite and financial risk => short timeline
        years = estimate_distress_timeline(0.85, 0.90)
        @test years < 5.0
        @test years > 0.0
    end

    # -----------------------------------------------------------------------
    @testset "estimate_distress_timeline - moderate risk" begin
        years = estimate_distress_timeline(0.50, 0.55)
        @test years > 2.0
        @test years < 20.0
    end

    # -----------------------------------------------------------------------
    @testset "estimate_distress_timeline - low risk" begin
        years = estimate_distress_timeline(0.15, 0.10)
        @test years > 10.0 || years == Inf
    end

    # -----------------------------------------------------------------------
    @testset "estimate_distress_timeline - very low risk returns Inf" begin
        years = estimate_distress_timeline(0.05, 0.05)
        @test years == Inf || years > 20.0
    end

    # -----------------------------------------------------------------------
    @testset "estimate_distress_timeline - monotonicity" begin
        # Higher risk should yield shorter timeline
        y1 = estimate_distress_timeline(0.30, 0.30)
        y2 = estimate_distress_timeline(0.60, 0.60)
        y3 = estimate_distress_timeline(0.90, 0.90)
        @test y1 >= y2
        @test y2 >= y3
    end

    # -----------------------------------------------------------------------
    @testset "default_cah_assumptions" begin
        assumptions = default_cah_assumptions()
        @test assumptions isa Dict{String,Float64}

        @test haskey(assumptions, "cost_reimbursement_rate")
        @test assumptions["cost_reimbursement_rate"] == 1.01
        @test haskey(assumptions, "occupancy_rate")
        @test 0.0 < assumptions["occupancy_rate"] < 1.0
        @test haskey(assumptions, "medicare_payer_pct")
        @test assumptions["medicare_payer_pct"] > 0.40  # CAHs are Medicare-heavy
        @test haskey(assumptions, "annual_cost_growth")
        @test assumptions["annual_cost_growth"] > 0.0
        @test haskey(assumptions, "outpatient_revenue_pct")
        @test assumptions["outpatient_revenue_pct"] > 0.50  # CAHs are outpatient-heavy

        # Payer mix should sum to ~1.0
        payer_sum = get(assumptions, "medicare_payer_pct", 0.0) +
                    get(assumptions, "medicaid_payer_pct", 0.0) +
                    get(assumptions, "commercial_payer_pct", 0.0) +
                    get(assumptions, "self_pay_pct", 0.0)
        @test isapprox(payer_sum, 0.95; atol=0.10)
    end

    # -----------------------------------------------------------------------
    @testset "default_reh_assumptions" begin
        assumptions = default_reh_assumptions()
        @test assumptions isa Dict{String,Float64}

        @test haskey(assumptions, "monthly_facility_payment")
        @test assumptions["monthly_facility_payment"] > 270_000.0
        @test haskey(assumptions, "opps_addon_pct")
        @test assumptions["opps_addon_pct"] == 0.05
        @test haskey(assumptions, "volume_retention_pct")
        @test 0.0 < assumptions["volume_retention_pct"] <= 1.0
        @test haskey(assumptions, "transition_cost_estimate")
        @test assumptions["transition_cost_estimate"] > 0.0
        @test haskey(assumptions, "outpatient_revenue_pct")
        @test assumptions["outpatient_revenue_pct"] == 1.0  # REH is all outpatient
    end

    # -----------------------------------------------------------------------
    @testset "default assumptions consistency" begin
        cah = default_cah_assumptions()
        reh = default_reh_assumptions()

        # REH should have lower cost growth (no inpatient overhead)
        @test reh["annual_cost_growth"] <= cah["annual_cost_growth"]
        # REH should have higher outpatient share
        @test reh["outpatient_revenue_pct"] >= cah["outpatient_revenue_pct"]
    end

    # -----------------------------------------------------------------------
    @testset "chartis_vulnerability_score - healthy hospital" begin
        features = ClosureMLFeatures(;
            case_mix_index=1.1,
            occupancy_rate=0.45,
            avg_age_of_plant=8.0,
            years_negative_operating_margin=0,
            state_has_medicaid_expansion=true,
            pct_change_net_patient_revenue=0.03,
        )
        score = chartis_vulnerability_score(features)
        @test 0.0 <= score <= 1.0
        @test score < 0.30  # healthy hospital should be low risk
    end

    # -----------------------------------------------------------------------
    @testset "chartis_vulnerability_score - distressed hospital" begin
        features = ClosureMLFeatures(;
            case_mix_index=0.75,
            occupancy_rate=0.15,
            avg_age_of_plant=22.0,
            years_negative_operating_margin=5,
            state_has_medicaid_expansion=false,
            pct_change_net_patient_revenue=-0.08,
            is_government_controlled=false,
        )
        score = chartis_vulnerability_score(features)
        @test 0.0 <= score <= 1.0
        @test score > 0.50  # distressed should be high risk
    end

    # -----------------------------------------------------------------------
    @testset "chartis_vulnerability_score - monotonicity on negative margins" begin
        score_0 = chartis_vulnerability_score(ClosureMLFeatures(;
            years_negative_operating_margin=0))
        score_3 = chartis_vulnerability_score(ClosureMLFeatures(;
            years_negative_operating_margin=3))
        score_5 = chartis_vulnerability_score(ClosureMLFeatures(;
            years_negative_operating_margin=5))
        @test score_0 <= score_3
        @test score_3 <= score_5
    end

    # -----------------------------------------------------------------------
    @testset "closure_risk_trend - improving trajectory" begin
        # Simulate 4 years of improving financials
        features = [
            ClosureMLFeatures(; years_negative_operating_margin=3, occupancy_rate=0.20,
                pct_change_net_patient_revenue=-0.05),
            ClosureMLFeatures(; years_negative_operating_margin=2, occupancy_rate=0.25,
                pct_change_net_patient_revenue=-0.02),
            ClosureMLFeatures(; years_negative_operating_margin=1, occupancy_rate=0.30,
                pct_change_net_patient_revenue=0.01),
            ClosureMLFeatures(; years_negative_operating_margin=0, occupancy_rate=0.35,
                pct_change_net_patient_revenue=0.03),
        ]
        trend = closure_risk_trend(features)
        @test length(trend) == 4

        # Risk probability should decrease over time
        @test trend[4].probability <= trend[1].probability
        # Delta should be negative (improving)
        @test trend[4].delta <= 0.0
    end

    # -----------------------------------------------------------------------
    @testset "closure_risk_trend - deteriorating trajectory" begin
        features = [
            ClosureMLFeatures(; years_negative_operating_margin=0, occupancy_rate=0.40),
            ClosureMLFeatures(; years_negative_operating_margin=1, occupancy_rate=0.35),
            ClosureMLFeatures(; years_negative_operating_margin=2, occupancy_rate=0.28),
            ClosureMLFeatures(; years_negative_operating_margin=3, occupancy_rate=0.20),
        ]
        trend = closure_risk_trend(features)
        @test length(trend) == 4

        # Risk should increase
        @test trend[4].probability >= trend[1].probability
        @test trend[4].delta >= 0.0
        # Should flag as accelerating
        @test trend[4].accelerating == true || trend[3].accelerating == true
    end

    # -----------------------------------------------------------------------
    @testset "closure_risk_trend - single year" begin
        features = [ClosureMLFeatures()]
        trend = closure_risk_trend(features)
        @test length(trend) == 1
        @test trend[1].delta == 0.0
    end
end
