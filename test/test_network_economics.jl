# ============================================================================
# Tests for Network Economics (src/analysis/network_economics.jl)
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "analysis", "network_economics.jl"))

@testset "Network Economics" begin

    # Reusable fixtures
    members = [
        NetworkMember(name="Hospital A", annual_revenue=20_000_000.0,
            annual_expenses=19_000_000.0, fte_count=150, service_lines=["ED", "Surgery"]),
        NetworkMember(name="Hospital B", annual_revenue=15_000_000.0,
            annual_expenses=14_500_000.0, fte_count=100, service_lines=["ED"]),
    ]
    services = [
        SharedService(service_name="IT", current_cost_per_member=500_000.0,
            network_cost_per_member=350_000.0, implementation_cost=200_000.0),
        SharedService(service_name="Lab", current_cost_per_member=300_000.0,
            network_cost_per_member=200_000.0, implementation_cost=100_000.0),
    ]

    @testset "struct construction" begin
        @test members[1].name == "Hospital A"
        @test services[1].current_cost_per_member == 500_000.0
        @test services[1].ramp_up_years == 1
    end

    @testset "evaluate_network" begin
        result = evaluate_network(members, services)
        # 2 members x (500k+300k) current = 1.6M total current
        @test result.total_current_cost ≈ 1_600_000.0
        # 2 members x (350k+200k) network = 1.1M
        @test result.total_network_cost ≈ 1_100_000.0
        @test result.annual_savings ≈ 500_000.0
        # Implementation: 2 members x (200k+100k) = 600k
        @test result.implementation_cost ≈ 600_000.0
        # Breakeven = 600k / 500k = 1.2 years
        @test result.breakeven_years ≈ 1.2
        @test length(result.per_member_savings) == 2
        @test result.per_member_savings[1].name == "Hospital A"
    end

    @testset "network_aco_formation" begin
        aco = network_aco_formation(members; benchmark_per_beneficiary=12_000.0,
            total_beneficiaries=5000)
        @test aco.total_benchmark == 60_000_000.0
        @test aco.cost_per_beneficiary > 0.0
        @test haskey(aco, :qualifies_for_savings)
        @test haskey(aco, :shared_savings_payment)
        @test aco.per_member_payment >= 0.0
    end

    @testset "joint_purchasing_savings" begin
        jps = joint_purchasing_savings(members)
        # Supply spend = 30% of (19M + 14.5M) = 10.05M
        @test jps.combined_supply_spend ≈ 10_050_000.0
        @test jps.base_discount == 0.05
        @test jps.volume_bonus > 0.0
        @test jps.effective_discount > jps.base_discount
        @test jps.total_annual_savings > 0.0
        @test length(jps.per_member_detail) == 2
        # Savings should sum to total
        member_sum = sum(d.annual_savings for d in jps.per_member_detail)
        @test member_sum ≈ jps.total_annual_savings atol=0.01
    end

    @testset "edge cases" begin
        @test_throws ErrorException evaluate_network(NetworkMember[], services)
        @test_throws ErrorException evaluate_network(members, SharedService[])

        # Single member network
        single = [members[1]]
        r = evaluate_network(single, [services[1]])
        @test r.annual_savings ≈ 150_000.0
        @test length(r.per_member_savings) == 1
    end
end
