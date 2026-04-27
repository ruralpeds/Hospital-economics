using Test

include(joinpath(@__DIR__, "..", "src", "finance", "vbc_transition.jl"))

@testset "Value-Based Care Transition" begin
    @testset "struct construction" begin
        p = VBCParams(total_cost_of_care=900_000.0, benchmark=1_000_000.0,
                      patient_panel_size=500)
        @test p.model_type == :mssp_basic
        @test p.risk_track == :one_sided
        @test p.shared_savings_rate == 0.50
        @test p.shared_loss_rate == 0.30
        @test p.min_savings_rate == 0.02
        @test p.care_management_investment == 0.0
    end

    @testset "calculate_vbc_outcome — one-sided savings above MSR" begin
        p = VBCParams(total_cost_of_care=950_000.0, benchmark=1_000_000.0,
                      patient_panel_size=500, quality_score=1.0, risk_track=:one_sided)
        r = calculate_vbc_outcome(p)

        @test r.gross_savings == 50_000.0
        @test r.savings_rate == 0.05
        @test r.meets_minimum_savings  # 5% > 2% MSR
        # shared_savings = 50_000 * 0.50 * 1.0 = 25_000
        @test r.shared_savings_payment == 25_000.0
        @test r.shared_loss_payment == 0.0
        @test r.net_vbc_income == 25_000.0
        @test r.per_beneficiary_savings == 100.0
    end

    @testset "calculate_vbc_outcome — savings below MSR" begin
        # 1% savings < 2% MSR => no shared savings
        p = VBCParams(total_cost_of_care=990_000.0, benchmark=1_000_000.0,
                      patient_panel_size=1000, quality_score=0.8)
        r = calculate_vbc_outcome(p)

        @test r.gross_savings == 10_000.0
        @test r.savings_rate == 0.01
        @test !r.meets_minimum_savings
        @test r.shared_savings_payment == 0.0
    end

    @testset "calculate_vbc_outcome — two-sided losses" begin
        p = VBCParams(total_cost_of_care=1_100_000.0, benchmark=1_000_000.0,
                      patient_panel_size=500, risk_track=:two_sided,
                      model_type=:mssp_enhanced, shared_loss_rate=0.40)
        r = calculate_vbc_outcome(p)

        @test r.gross_savings == -100_000.0
        @test !r.meets_minimum_savings
        @test r.shared_savings_payment == 0.0
        @test r.shared_loss_payment > 0.0
        # Calculation: raw_loss = |(-100_000)| * 0.40 = 40_000
        # MSSP Enhanced loss_cap = 1_000_000 * 0.10 = 100_000
        # shared_loss_payment = min(40_000, 100_000) = 40_000
        @test r.shared_loss_payment == 40_000.0
        @test r.net_vbc_income < 0.0
    end

    @testset "calculate_vbc_outcome — one-sided losses (no shared loss)" begin
        p = VBCParams(total_cost_of_care=1_100_000.0, benchmark=1_000_000.0,
                      patient_panel_size=500, risk_track=:one_sided)
        r = calculate_vbc_outcome(p)

        @test r.gross_savings == -100_000.0
        @test r.shared_loss_payment == 0.0
        @test r.net_vbc_income == 0.0
    end

    @testset "vbc_transition_timeline" begin
        p = VBCParams(total_cost_of_care=950_000.0, benchmark=1_000_000.0,
                      patient_panel_size=500, care_management_investment=20_000.0)
        tl = vbc_transition_timeline(p, years=5)

        @test length(tl) == 5
        @test tl[1].year == 1
        @test tl[5].year == 5
        # Care management ramp: year 1 = 60%, year 3 = 100%
        @test tl[1].care_management_cost == 20_000.0 * 0.60
        @test tl[3].care_management_cost == 20_000.0 * 1.0
    end

    @testset "edge cases" begin
        @test_throws ErrorException calculate_vbc_outcome(
            VBCParams(total_cost_of_care=100.0, benchmark=0.0, patient_panel_size=10))
        @test_throws ErrorException calculate_vbc_outcome(
            VBCParams(total_cost_of_care=100.0, benchmark=100.0, patient_panel_size=0))
        @test_throws ErrorException calculate_vbc_outcome(
            VBCParams(total_cost_of_care=100.0, benchmark=100.0, patient_panel_size=10,
                      risk_track=:invalid))
        @test_throws ErrorException vbc_transition_timeline(
            VBCParams(total_cost_of_care=100.0, benchmark=100.0, patient_panel_size=10),
            years=0)
        # Care management cost offsets savings
        p = VBCParams(total_cost_of_care=950_000.0, benchmark=1_000_000.0,
                      patient_panel_size=500, quality_score=1.0,
                      care_management_investment=30_000.0)
        r = calculate_vbc_outcome(p)
        @test r.net_financial_impact == r.net_vbc_income - 30_000.0
    end
end
