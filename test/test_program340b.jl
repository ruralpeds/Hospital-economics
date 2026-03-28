# ============================================================================
# Tests for 340B Drug Pricing Program (src/finance/program340b.jl)
# ============================================================================

using Test
using Dates

# Include only the required source files
include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "program340b.jl"))

@testset "340B Drug Pricing Program" begin

    @testset "calculate_340b_impact - basic with defaults" begin
        params = Program340BParams(total_drug_spend=1_000_000.0)
        result = calculate_340b_impact(params)

        # gross_savings = spend * discount_rate = 1M * 0.40 = 400k
        @test result.gross_savings ≈ 400_000.0
        # admin_costs = gross_savings * 0.05 = 20k
        @test result.admin_costs ≈ 20_000.0
        # net benefit is positive
        @test result.net_benefit > 0.0
        # margin_impact equals net_benefit
        @test result.margin_impact ≈ result.net_benefit
        # default at_risk_revenue_pct = 0 => at_risk_amount = 0
        @test result.at_risk_amount ≈ 0.0
    end

    @testset "calculate_340b_impact - gross savings formula" begin
        for (spend, dr) in [(500_000.0, 0.20), (2_000_000.0, 0.35), (1_000_000.0, 0.50)]
            params = Program340BParams(total_drug_spend=spend, discount_rate=dr)
            result = calculate_340b_impact(params)
            @test result.gross_savings ≈ spend * dr
        end
    end

    @testset "calculate_340b_impact - contract pharmacy revenue" begin
        params = Program340BParams(
            total_drug_spend=1_000_000.0,
            discount_rate=0.40,
            contract_pharmacy_pct=0.30,
            contract_pharmacy_fee=15.0,
        )
        result = calculate_340b_impact(params)
        # volume = 1M * 0.30 = 300k; spread = 300k * 0.40 = 120k
        # num_rxs = 300k / 100 = 3000; fees = 3000 * 15 = 45k
        # revenue = 120k - 45k = 75k
        @test result.contract_pharmacy_revenue ≈ 75_000.0
    end

    @testset "calculate_340b_impact - net benefit calculation" begin
        params = Program340BParams(total_drug_spend=1_000_000.0)
        result = calculate_340b_impact(params)
        # net = gross_savings + max(contract_pharmacy_revenue, 0) - admin
        expected = result.gross_savings + max(result.contract_pharmacy_revenue, 0.0) - result.admin_costs
        @test result.net_benefit ≈ expected
    end

    @testset "calculate_340b_impact - at risk amount" begin
        params = Program340BParams(
            total_drug_spend=1_000_000.0,
            at_risk_revenue_pct=0.50,
        )
        result = calculate_340b_impact(params)
        @test result.at_risk_amount ≈ result.net_benefit * 0.50
        @test result.at_risk_amount > 0.0
    end

    @testset "calculate_340b_impact - zero spend" begin
        params = Program340BParams(total_drug_spend=0.0)
        result = calculate_340b_impact(params)
        @test result.gross_savings ≈ 0.0
        @test result.net_benefit ≈ 0.0
        @test result.admin_costs ≈ 0.0
    end

    @testset "calculate_340b_impact - no contract pharmacy" begin
        params = Program340BParams(
            total_drug_spend=2_000_000.0,
            discount_rate=0.50,
            contract_pharmacy_pct=0.0,
            admin_cost_pct=0.10,
        )
        result = calculate_340b_impact(params)
        @test result.gross_savings ≈ 1_000_000.0
        @test result.contract_pharmacy_revenue ≈ 0.0
        @test result.admin_costs ≈ 100_000.0
        @test result.net_benefit ≈ 900_000.0
    end

    @testset "policy_risk_scenarios - generates 3 scenarios" begin
        params = Program340BParams(total_drug_spend=1_000_000.0)
        scenarios = policy_risk_scenarios(params)
        @test length(scenarios) == 3
        @test scenarios[1].scenario == :current
        @test scenarios[2].scenario == :moderate_reform
        @test scenarios[3].scenario == :significant_reform
    end

    @testset "policy_risk_scenarios - current matches direct calc" begin
        params = Program340BParams(total_drug_spend=1_000_000.0)
        scenarios = policy_risk_scenarios(params)
        direct = calculate_340b_impact(params)
        @test scenarios[1].result.net_benefit ≈ direct.net_benefit
        @test scenarios[1].result.gross_savings ≈ direct.gross_savings
    end

    @testset "policy_risk_scenarios - reform reduces benefit" begin
        params = Program340BParams(total_drug_spend=1_000_000.0)
        scenarios = policy_risk_scenarios(params)
        current_benefit = scenarios[1].result.net_benefit
        moderate_benefit = scenarios[2].result.net_benefit
        significant_benefit = scenarios[3].result.net_benefit

        @test moderate_benefit < current_benefit
        @test significant_benefit < moderate_benefit
    end

    @testset "policy_risk_scenarios - descriptions are non-empty" begin
        params = Program340BParams(total_drug_spend=500_000.0)
        scenarios = policy_risk_scenarios(params)
        for s in scenarios
            @test s.result isa Program340BResult
            @test length(s.description) > 0
        end
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
