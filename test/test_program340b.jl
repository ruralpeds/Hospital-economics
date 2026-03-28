# ============================================================================
# Tests for 340B Drug Pricing Program (src/finance/program340b.jl)
# ============================================================================

using Test
using Dates

# Include only the required source files
include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "program340b.jl"))

@testset "340B Drug Pricing Program" begin

    @testset "calculate_340b_impact basic" begin
        params = Program340BParams(total_drug_spend=1_000_000.0)
        result = calculate_340b_impact(params)

        # gross_savings = spend * discount_rate = 1_000_000 * 0.40 = 400_000
        @test result.gross_savings ≈ 400_000.0

        # admin_costs = gross_savings * admin_cost_pct = 400_000 * 0.05 = 20_000
        @test result.admin_costs ≈ 20_000.0

        # Contract pharmacy: volume = 1_000_000 * 0.30 = 300_000
        # spread = 300_000 * 0.40 = 120_000
        # num_rxs = 300_000 / 100 = 3_000; fees = 3_000 * 15 = 45_000
        # contract_pharmacy_revenue = 120_000 - 45_000 = 75_000
        @test result.contract_pharmacy_revenue ≈ 75_000.0

        # net_benefit = 400_000 + 75_000 - 20_000 = 455_000
        @test result.net_benefit ≈ 455_000.0
        @test result.margin_impact ≈ result.net_benefit

        # at_risk_amount = 0 (default at_risk_revenue_pct = 0)
        @test result.at_risk_amount ≈ 0.0
    end

    @testset "calculate_340b_impact custom params" begin
        params = Program340BParams(
            total_drug_spend=2_000_000.0,
            discount_rate=0.50,
            contract_pharmacy_pct=0.0,
            admin_cost_pct=0.10,
            at_risk_revenue_pct=0.25,
        )
        result = calculate_340b_impact(params)

        @test result.gross_savings ≈ 1_000_000.0
        @test result.contract_pharmacy_revenue ≈ 0.0  # no contract pharmacy
        @test result.admin_costs ≈ 100_000.0
        @test result.net_benefit ≈ 900_000.0
        @test result.at_risk_amount ≈ 225_000.0  # 25% of 900_000
    end

    @testset "gross_savings equals spend times discount" begin
        for spend in [500_000.0, 1_500_000.0, 3_000_000.0]
            for dr in [0.20, 0.40, 0.60]
                params = Program340BParams(total_drug_spend=spend, discount_rate=dr)
                result = calculate_340b_impact(params)
                @test result.gross_savings ≈ spend * dr
            end
        end
    end

    @testset "policy_risk_scenarios count and structure" begin
        params = Program340BParams(total_drug_spend=1_000_000.0)
        scenarios = policy_risk_scenarios(params)
        @test length(scenarios) == 3

        @test scenarios[1].scenario == :current
        @test scenarios[2].scenario == :moderate_reform
        @test scenarios[3].scenario == :significant_reform

        # Each scenario has a result and description
        for s in scenarios
            @test s.result isa Program340BResult
            @test !isempty(s.description)
        end
    end

    @testset "moderate reform has lower benefit than current" begin
        params = Program340BParams(total_drug_spend=1_000_000.0)
        scenarios = policy_risk_scenarios(params)
        current_benefit = scenarios[1].result.net_benefit
        moderate_benefit = scenarios[2].result.net_benefit
        significant_benefit = scenarios[3].result.net_benefit

        @test moderate_benefit < current_benefit
        @test significant_benefit < moderate_benefit
    end

    @testset "significant reform has lowest benefit" begin
        params = Program340BParams(total_drug_spend=2_000_000.0, discount_rate=0.35)
        scenarios = policy_risk_scenarios(params)
        benefits = [s.result.net_benefit for s in scenarios]
        # Benefits should be in descending order: current > moderate > significant
        @test issorted(benefits; rev=true)
    end

    @testset "Program340BResult show method" begin
        result = calculate_340b_impact(Program340BParams(total_drug_spend=500_000.0))
        io = IOBuffer()
        show(io, result)
        s = String(take!(io))
        @test contains(s, "Program340BResult")
        @test contains(s, "net_benefit")
    end
end
