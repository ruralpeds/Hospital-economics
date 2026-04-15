using Test

include(joinpath(@__DIR__, "..", "src", "finance", "margin_decomposition.jl"))

@testset "Margin Decomposition" begin
    @testset "struct construction" begin
        c = PayerMarginComponent(payer_name="Medicare", payer_type=:government,
                                  revenue=5_000_000.0, allocated_costs=4_500_000.0,
                                  margin_dollars=500_000.0, margin_pct=0.10,
                                  volume_share=0.50, margin_contribution=0.05)
        @test c.payer_name == "Medicare"
        @test c.payer_type == :government

        d = MarginDecomposition(components=[c], total_revenue=5_000_000.0,
                                total_costs=4_500_000.0, total_margin_pct=0.10)
        @test d.non_patient_revenue == 0.0
        @test length(d.components) == 1
    end

    @testset "decompose_margin with multiple payers" begin
        payer_data = [
            (payer_name="Medicare", payer_type=:government, revenue=4_000_000.0, volume_share=0.50),
            (payer_name="Medicaid", payer_type=:government, revenue=1_500_000.0, volume_share=0.25),
            (payer_name="Commercial", payer_type=:commercial, revenue=3_000_000.0, volume_share=0.25),
        ]
        total_expenses = 8_000_000.0
        result = decompose_margin(payer_data, total_expenses)

        @test length(result.components) == 3
        @test result.total_revenue == 4_000_000.0 + 1_500_000.0 + 3_000_000.0
        @test result.total_costs == 8_000_000.0

        # Medicare: allocated = 8M * 0.50 = 4M, margin = 0
        mc = result.components[1]
        @test mc.allocated_costs == 4_000_000.0
        @test mc.margin_dollars == 0.0

        # Medicaid: allocated = 8M * 0.25 = 2M, margin = -500K
        md = result.components[2]
        @test md.margin_dollars == -500_000.0

        # Commercial: allocated = 2M, margin = 1M
        cm = result.components[3]
        @test cm.margin_dollars == 1_000_000.0

        # Margin contributions should sum to (total_revenue - total_expenses) / total_expenses
        total_mc = sum(c.margin_contribution for c in result.components)
        expected = (result.total_revenue - total_expenses) / total_expenses
        @test isapprox(total_mc, expected, atol=1e-10)
    end

    @testset "decompose_margin with non-patient revenue" begin
        payer_data = [
            (payer_name="Medicare", payer_type=:government, revenue=3_000_000.0, volume_share=1.0),
        ]
        result = decompose_margin(payer_data, 4_000_000.0, non_patient_revenue=500_000.0)

        @test result.total_revenue == 3_500_000.0
        @test result.non_patient_revenue == 500_000.0
        @test result.non_patient_contribution == 500_000.0 / 4_000_000.0
    end

    @testset "dupont_analysis" begin
        dp = dupont_analysis(10_000_000.0, 9_000_000.0, 20_000_000.0, 8_000_000.0)

        @test dp.profit_margin == 1_000_000.0 / 10_000_000.0  # 0.10
        @test dp.asset_turnover == 10_000_000.0 / 20_000_000.0  # 0.50
        @test dp.equity_multiplier == 20_000_000.0 / 8_000_000.0  # 2.50
        @test isapprox(dp.roe, dp.profit_margin * dp.asset_turnover * dp.equity_multiplier)

        # Errors on invalid inputs
        @test_throws ErrorException dupont_analysis(0.0, 100.0, 200.0, 100.0)
        @test_throws ErrorException dupont_analysis(100.0, 50.0, 0.0, 100.0)
        @test_throws ErrorException dupont_analysis(100.0, 50.0, 200.0, 0.0)
    end

    @testset "margin_waterfall ordering" begin
        payer_data = [
            (payer_name="Commercial", payer_type=:commercial, revenue=3_000_000.0, volume_share=0.30),
            (payer_name="Medicare", payer_type=:government, revenue=2_000_000.0, volume_share=0.40),
            (payer_name="Medicaid", payer_type=:government, revenue=1_000_000.0, volume_share=0.30),
        ]
        decomp = decompose_margin(payer_data, 5_000_000.0, non_patient_revenue=200_000.0)
        wf = margin_waterfall(decomp)

        # Should have 3 payers + non-patient + total = 5 entries
        @test length(wf) == 5
        @test wf[end].label == "Total Margin"
        # First entries should be sorted by margin contribution descending
        @test wf[1].value >= wf[2].value
        # Non-patient revenue entry before total
        @test wf[end-1].label == "Non-Patient Revenue"
    end

    @testset "edge cases" begin
        @test_throws ErrorException decompose_margin(
            [(payer_name="A", payer_type=:x, revenue=100.0, volume_share=1.0)], 0.0)
        # Single payer
        result = decompose_margin(
            [(payer_name="Solo", payer_type=:commercial, revenue=1_000_000.0, volume_share=1.0)],
            900_000.0)
        @test length(result.components) == 1
        @test result.components[1].margin_dollars == 100_000.0
    end
end
