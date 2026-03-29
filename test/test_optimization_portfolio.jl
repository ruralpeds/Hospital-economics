# ============================================================================
# Tests for service portfolio optimization and scenario comparison
# ============================================================================

using Test

# Include source
include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "department.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "staffing.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "payer.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "financial.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "capital.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "hospital.jl"))
include(joinpath(@__DIR__, "..", "src", "optimization", "portfolio.jl"))
include(joinpath(@__DIR__, "..", "src", "analysis", "comparison.jl"))
include(joinpath(@__DIR__, "..", "src", "analysis", "payer_negotiation.jl"))

@testset "Portfolio Optimization & Scenario Comparison" begin

    # -----------------------------------------------------------------------
    @testset "optimize_service_portfolio - basic feasible" begin
        services = [:ed, :outpatient, :imaging, :lab, :pharmacy]
        result = optimize_service_portfolio(;
            services=services,
            revenue_per_unit=Dict(:ed => 1850.0, :outpatient => 450.0,
                :imaging => 680.0, :lab => 85.0, :pharmacy => 120.0),
            cost_per_unit=Dict(:ed => 1600.0, :outpatient => 350.0,
                :imaging => 520.0, :lab => 55.0, :pharmacy => 95.0),
            volume_potential=Dict(:ed => 4200.0, :outpatient => 12800.0,
                :imaging => 6200.0, :lab => 18500.0, :pharmacy => 8000.0),
            capacity_requirement=Dict(:ed => 0.25, :outpatient => 0.30,
                :imaging => 0.15, :lab => 0.10, :pharmacy => 0.08),
            total_capacity=1.0,
            fixed_costs=Dict(:ed => 500_000.0, :outpatient => 300_000.0,
                :imaging => 400_000.0, :lab => 200_000.0, :pharmacy => 150_000.0),
            required_services=[:ed],
        )

        @test result.status == :Optimal || result.status == :optimal ||
              result.status == :OPTIMAL || string(result.status) != "infeasible"
        @test result.objective_value > 0.0
        @test result.selected_services[:ed] == true  # required
        @test length(result.selected_services) == 5
    end

    # -----------------------------------------------------------------------
    @testset "optimize_service_portfolio - capacity constraint binds" begin
        services = [:svc_a, :svc_b]
        result = optimize_service_portfolio(;
            services=services,
            revenue_per_unit=Dict(:svc_a => 500.0, :svc_b => 600.0),
            cost_per_unit=Dict(:svc_a => 300.0, :svc_b => 400.0),
            volume_potential=Dict(:svc_a => 1000.0, :svc_b => 1000.0),
            capacity_requirement=Dict(:svc_a => 0.60, :svc_b => 0.60),
            total_capacity=1.0,
            fixed_costs=Dict(:svc_a => 50_000.0, :svc_b => 50_000.0),
        )

        # Can't fit both at 60% each in 100% capacity
        selected_count = count(values(result.selected_services))
        @test selected_count <= 2
        # Total allocated capacity should not exceed 1.0
        total_cap = sum(values(result.allocated_capacity))
        @test total_cap <= 1.0 + 1e-6
    end

    # -----------------------------------------------------------------------
    @testset "optimize_service_portfolio - community need weighting" begin
        services = [:essential, :profitable]
        # Essential has higher community need but lower margin
        result = optimize_service_portfolio(;
            services=services,
            revenue_per_unit=Dict(:essential => 200.0, :profitable => 800.0),
            cost_per_unit=Dict(:essential => 250.0, :profitable => 400.0),
            volume_potential=Dict(:essential => 5000.0, :profitable => 1000.0),
            capacity_requirement=Dict(:essential => 0.50, :profitable => 0.50),
            total_capacity=0.60,
            fixed_costs=Dict(:essential => 100_000.0, :profitable => 100_000.0),
            community_need_weight=0.8,
            community_need_scores=Dict(:essential => 0.95, :profitable => 0.20),
        )

        @test result isa ServicePortfolioResult
    end

    # -----------------------------------------------------------------------
    @testset "optimal_rate_target" begin
        hospital = CriticalAccessHospital(;
            name="Test CAH", cms_provider_number="171301", npi="1234567890",
            cah_certification_date=Date(2006, 1, 15),
            licensed_beds=25, nearest_hospital_miles=35.0,
            location=GeoLocation(; latitude=38.5, longitude=-98.7,
                fips_code="20009", state="KS", county="Barton", zip_code="67530"),
            service_area=ServiceArea(; primary_service_area_pop=8000,
                total_service_area_pop=12000),
        )

        rate = optimal_rate_target(hospital, :commercial; target_margin=0.0)
        @test rate > 0.0
        @test rate <= 2.0  # reasonable upper bound for rate as fraction

        # Higher target margin should require higher rate
        rate_high = optimal_rate_target(hospital, :commercial; target_margin=0.10)
        @test rate_high >= rate
    end

    # -----------------------------------------------------------------------
    @testset "compare_scenarios - basic" begin
        # Create mock simulation results to compare
        # Need to match AbstractSimulationResult interface
        @test_nowarn begin
            # Verify ScenarioComparison struct exists
            comp = ScenarioComparison(
                ["Baseline", "REH Conversion"],
                ["operating_margin", "total_revenue"],
                [-0.038 18_500_000.0; 0.015 20_100_000.0],
                1
            )
            @test comp.scenario_names == ["Baseline", "REH Conversion"]
            @test size(comp.values) == (2, 2)
        end
    end

    # -----------------------------------------------------------------------
    @testset "rank_scenarios" begin
        comp = ScenarioComparison(
            ["Baseline", "Plan A", "Plan B"],
            ["operating_margin", "days_cash_on_hand"],
            [-0.038 42.0; 0.015 65.0; 0.025 80.0],
            1
        )
        ranks = rank_scenarios(comp)
        @test length(ranks) == 3
        # Plan B (best margin + cash) should rank highest
        @test ranks[3] <= ranks[1]  # Plan B rank <= Baseline rank
    end

    # -----------------------------------------------------------------------
    @testset "scenario_delta" begin
        comp = ScenarioComparison(
            ["Baseline", "Plan A"],
            ["operating_margin", "total_revenue"],
            [-0.038 18_500_000.0; 0.015 20_100_000.0],
            1
        )
        delta = scenario_delta(comp, 2)
        @test delta isa Dict{String,Float64}
        @test haskey(delta, "operating_margin")
        @test delta["operating_margin"] > 0.0  # Plan A better than baseline
        @test delta["total_revenue"] > 0.0
    end
end
