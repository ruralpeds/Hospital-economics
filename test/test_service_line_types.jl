using Test
include("../src/episode/ServiceLineTypes.jl")
include("../src/episode/ServiceLineCostAllocation.jl")

@testset "ServiceLineTypes" begin
    @testset "ServiceLine construction" begin
        sl = ServiceLine(
            id="SL001",
            name="Orthopedic Surgery",
            department="Surgical",
            drg_codes=["469", "470"],
            volume=150,
            revenue=5_000_000.0,
            direct_cost=3_000_000.0,
            allocated_indirect_cost=800_000.0
        )

        @test sl.id == "SL001"
        @test sl.name == "Orthopedic Surgery"
        @test sl.volume == 150
        @test sl.revenue == 5_000_000.0
        @test sl.direct_cost == 3_000_000.0
    end

    @testset "ServiceLine validation" begin
        @test_throws AssertionError ServiceLine(
            id="", name="Test", department="Test",
            drg_codes=String[], volume=10, revenue=100_000.0, direct_cost=50_000.0
        )

        @test_throws AssertionError ServiceLine(
            id="SL001", name="Test", department="Test",
            drg_codes=String[], volume=-5, revenue=100_000.0, direct_cost=50_000.0
        )

        @test_throws AssertionError ServiceLine(
            id="SL001", name="Test", department="Test",
            drg_codes=String[], volume=10, revenue=-100_000.0, direct_cost=50_000.0
        )
    end

    @testset "calculate_service_line_metrics" begin
        sl = ServiceLine(
            id="SL001",
            name="Cardiology",
            department="Medical",
            drg_codes=["246", "247"],
            volume=200,
            revenue=8_000_000.0,
            direct_cost=5_000_000.0,
            allocated_indirect_cost=1_500_000.0
        )

        metrics = calculate_service_line_metrics(sl)

        @test metrics.service_line_id == "SL001"
        @test metrics.contribution_margin == 3_000_000.0  # revenue - direct_cost
        @test metrics.contribution_margin_pct ≈ 37.5  # (3M / 8M * 100)
        @test metrics.allocated_margin == 1_500_000.0  # contribution - indirect
        @test metrics.allocated_margin_pct ≈ 18.75
        @test metrics.revenue_per_case ≈ 40_000.0  # 8M / 200
        @test metrics.direct_cost_per_case ≈ 25_000.0  # 5M / 200
        @test metrics.profitability_status == :profitable
    end

    @testset "ServiceLineMetrics for loss-making service" begin
        sl = ServiceLine(
            id="SL002",
            name="Obstetrics",
            department="Medical",
            drg_codes=["373", "374"],
            volume=100,
            revenue=3_000_000.0,
            direct_cost=2_900_000.0,
            allocated_indirect_cost=500_000.0
        )

        metrics = calculate_service_line_metrics(sl)

        @test metrics.allocated_margin < 0  # Loss
        @test metrics.profitability_status == :loss
    end
end

@testset "ServiceLineCostAllocation" begin
    # Create sample service lines
    services = [
        ServiceLine(
            id="SL001", name="Orthopedics",
            department="Surgical", drg_codes=["469"],
            volume=150, revenue=5_000_000.0, direct_cost=3_000_000.0
        ),
        ServiceLine(
            id="SL002", name="Cardiology",
            department="Medical", drg_codes=["246"],
            volume=200, revenue=8_000_000.0, direct_cost=4_000_000.0
        ),
        ServiceLine(
            id="SL003", name="Oncology",
            department="Medical", drg_codes=["844"],
            volume=100, revenue=6_000_000.0, direct_cost=5_000_000.0
        ),
    ]

    total_indirect = 3_000_000.0

    @testset "Proportional allocation" begin
        allocated = allocate_indirect_costs_proportional(services, total_indirect)

        @test length(allocated) == 3
        total_allocated = sum(sl.allocated_indirect_cost for sl in allocated)
        @test isapprox(total_allocated, total_indirect, atol=1.0)

        # Orthopedics has 30% of direct costs, should get 30% of indirect
        ortho = allocated[1]
        expected_indirect = (3_000_000.0 / 12_000_000.0) * total_indirect
        @test isapprox(ortho.allocated_indirect_cost, expected_indirect, atol=1.0)
    end

    @testset "Activity-based allocation" begin
        allocated = allocate_indirect_costs_activity_based(services, total_indirect)

        @test length(allocated) == 3
        total_allocated = sum(sl.allocated_indirect_cost for sl in allocated)
        @test isapprox(total_allocated, total_indirect, atol=1.0)

        # Cardiology has 40% of volume (200/450), should get 40% of indirect
        cardio = allocated[2]
        expected_indirect = (200.0 / 450.0) * total_indirect
        @test isapprox(cardio.allocated_indirect_cost, expected_indirect, atol=1.0)
    end

    @testset "Step-down allocation" begin
        allocated = allocate_indirect_costs_step_down(services, total_indirect)

        @test length(allocated) == 3
        total_allocated = sum(sl.allocated_indirect_cost for sl in allocated)
        # Step-down allocates only 90% of indirect costs (10% goes to support services)
        expected_allocated = total_indirect * 0.9
        @test isapprox(total_allocated, expected_allocated, atol=1.0)
    end

    @testset "Full analysis" begin
        result = analyze_service_lines(services, total_indirect, allocation_method=:proportional)

        @test length(result.service_lines) == 3
        @test length(result.metrics) == 3
        @test result.total_revenue == 19_000_000.0
        @test result.total_direct_cost == 12_000_000.0
        @test isapprox(result.total_indirect_cost, total_indirect, atol=1.0)
        @test result.total_margin > 0  # Should be profitable overall
        @test !isempty(result.recommendations)
    end

    @testset "Analysis with loss service" begin
        services_with_loss = vcat(
            services,
            [ServiceLine(
                id="SL004", name="Low Margin Service",
                department="Medical", drg_codes=["500"],
                volume=50, revenue=1_000_000.0, direct_cost=1_500_000.0
            )]
        )

        result = analyze_service_lines(services_with_loss, total_indirect, allocation_method=:activity_based)

        @test !isempty(result.loss_services)
        @test "SL004" in result.loss_services
        @test any(contains("losing"), lowercase.(result.recommendations))
    end

    @testset "Recommendations generation" begin
        result = analyze_service_lines(services, total_indirect)

        @test !isempty(result.recommendations)
        @test all(typeof(r) == String for r in result.recommendations)
        @test all(!isempty(r) for r in result.recommendations)
    end
end

println("\n✓ All ServiceLine tests passed!")
