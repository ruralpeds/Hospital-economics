# ============================================================================
# Tests for Geographic Access Modeling (src/analysis/geographic_access.jl)
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "analysis", "geographic_access.jl"))

@testset "Geographic Access" begin

    @testset "struct construction" begin
        f = FacilityLocation(name="Rural Hospital", latitude=38.0, longitude=-97.0)
        @test f.service_type == :full_service
        @test f.capacity == 1.0

        pc = PopulationCenter(name="Town A", latitude=38.1, longitude=-97.1, population=5000)
        @test pc.pct_over_65 == 0.15

        ar = AccessResult(facility_name="H1", catchment_population=10000,
            drive_time_minutes=15.0, access_score=0.5, market_share_estimate=0.3,
            volume_estimate=300.0)
        @test ar.facility_name == "H1"
    end

    @testset "haversine_distance" begin
        # Same point = zero distance
        @test haversine_distance(40.0, -90.0, 40.0, -90.0) == 0.0
        # NYC to LA ~ 3944 km (allow 5% tolerance)
        d = haversine_distance(40.7128, -74.0060, 33.9425, -118.4081)
        @test 3900.0 < d < 4000.0
        # Short known distance: ~111 km per degree latitude at equator
        d2 = haversine_distance(0.0, 0.0, 1.0, 0.0)
        @test 110.0 < d2 < 112.0
    end

    @testset "estimate_drive_time" begin
        # 80 km at 80 km/h with 1.3x winding = 78 minutes
        t = estimate_drive_time(80.0)
        @test t ≈ (80.0 * 1.3 / 80.0) * 60.0
        # Zero distance = zero time
        @test estimate_drive_time(0.0) == 0.0
    end

    @testset "calculate_catchment" begin
        facility = FacilityLocation(name="Hospital A", latitude=38.0, longitude=-97.0)
        pops = [
            PopulationCenter(name="Near Town", latitude=38.05, longitude=-97.05, population=3000),
            PopulationCenter(name="Far Town", latitude=40.0, longitude=-95.0, population=8000),
        ]
        result = calculate_catchment(facility, pops)
        # Near Town should be in catchment; Far Town likely out of 30-min range
        @test result.catchment_population >= 3000
        @test result.facility_name == "Hospital A"
        @test result.access_score >= 0.0
        @test result.volume_estimate >= 0.0
    end

    @testset "closure_access_impact" begin
        facilities = [
            FacilityLocation(name="H1", latitude=38.0, longitude=-97.0),
            FacilityLocation(name="H2", latitude=38.3, longitude=-97.3),
        ]
        pops = [
            PopulationCenter(name="Town", latitude=38.05, longitude=-97.05, population=5000),
        ]
        impact = closure_access_impact(facilities, pops, 1)
        @test impact.closed_facility == "H1"
        @test impact.next_nearest_facility == "H2"
        @test impact.avg_new_drive_minutes > 0.0
        @test impact.population_losing_access >= 0
    end

    @testset "edge cases" begin
        facility = FacilityLocation(name="H", latitude=0.0, longitude=0.0)
        # Empty population list should error (validation requires non-empty)
        @test_throws ErrorException calculate_catchment(facility, PopulationCenter[])

        # closure_access_impact: out of range index errors
        @test_throws ErrorException closure_access_impact(
            [FacilityLocation(name="H1", latitude=0.0, longitude=0.0)],
            PopulationCenter[], 2)

        # Cannot close only facility
        @test_throws ErrorException closure_access_impact(
            [FacilityLocation(name="H1", latitude=0.0, longitude=0.0)],
            [PopulationCenter(name="T", latitude=0.0, longitude=0.0, population=100)], 1)
    end
end
