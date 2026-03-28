# ============================================================================
# Tests for depreciation calculations (src/finance/depreciation.jl)
# ============================================================================

using Test
using Dates
using UUIDs

# Include source files directly for testing (in dependency order)
include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "department.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "staffing.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "payer.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "financial.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "capital.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "depreciation.jl"))

@testset "Depreciation" begin

    @testset "straight_line_depreciation" begin
        # (100_000 - 10_000) / 10 = 9_000
        @test straight_line_depreciation(100_000.0, 10_000.0, 10) ≈ 9_000.0
        @test straight_line_depreciation(50_000.0, 0.0, 5) ≈ 10_000.0
        @test_throws ErrorException straight_line_depreciation(100_000.0, 0.0, 0)
    end

    @testset "declining_balance_depreciation" begin
        # DDB: book_value * (2.0 / useful_life)
        @test declining_balance_depreciation(100_000.0, 10) ≈ 20_000.0
        @test declining_balance_depreciation(80_000.0, 10) ≈ 16_000.0
        # Custom factor (1.5x declining)
        @test declining_balance_depreciation(100_000.0, 10; factor=1.5) ≈ 15_000.0
        @test_throws ErrorException declining_balance_depreciation(100_000.0, 0)
    end

    @testset "depreciation_schedule straight_line" begin
        asset = CapitalAsset(
            asset_id="EQ001",
            description="CT Scanner",
            category=:equipment,
            acquisition_date=Date(2020, 1, 1),
            acquisition_cost=500_000.0,
            useful_life_years=10,
            salvage_value=50_000.0,
            depreciation_method=:straight_line,
        )
        sched = depreciation_schedule(asset, 10)
        @test length(sched) == 10
        # Each year should depreciate (500k - 50k) / 10 = 45_000
        @test sched[1].expense ≈ 45_000.0
        @test sched[1].accumulated ≈ 45_000.0
        @test sched[1].book_value ≈ 455_000.0
        # Final year: fully depreciated to salvage
        @test sched[10].book_value ≈ 50_000.0
        @test sched[10].accumulated ≈ 450_000.0
    end

    @testset "depreciation_schedule declining_balance" begin
        asset = CapitalAsset(
            asset_id="EQ002",
            description="MRI Machine",
            category=:equipment,
            acquisition_date=Date(2021, 6, 1),
            acquisition_cost=200_000.0,
            useful_life_years=5,
            salvage_value=20_000.0,
            depreciation_method=:declining_balance,
        )
        sched = depreciation_schedule(asset, 5)
        @test length(sched) == 5
        # First year DDB: 200_000 * (2/5) = 80_000
        @test sched[1].expense ≈ 80_000.0
        # Book value should never go below salvage
        @test sched[end].book_value >= 20_000.0 - 0.01
    end

    @testset "depreciation_schedule with accumulated depreciation" begin
        asset = CapitalAsset(
            asset_id="EQ003",
            description="X-Ray Unit",
            category=:equipment,
            acquisition_date=Date(2018, 1, 1),
            acquisition_cost=100_000.0,
            useful_life_years=10,
            salvage_value=0.0,
            depreciation_method=:straight_line,
            accumulated_depreciation=50_000.0,
        )
        sched = depreciation_schedule(asset, 5)
        # Annual SL = 10_000; starting book = 50_000
        @test sched[1].expense ≈ 10_000.0
        @test sched[5].book_value ≈ 0.0
        @test sched[5].accumulated ≈ 100_000.0
    end

    @testset "total_annual_depreciation" begin
        assets = [
            CapitalAsset(asset_id="A1", description="Bldg", category=:building,
                acquisition_date=Date(2015,1,1), acquisition_cost=1_000_000.0,
                useful_life_years=40, salvage_value=0.0, is_active=true),
            CapitalAsset(asset_id="A2", description="Van", category=:vehicle,
                acquisition_date=Date(2020,1,1), acquisition_cost=50_000.0,
                useful_life_years=5, salvage_value=5_000.0, is_active=true),
            CapitalAsset(asset_id="A3", description="Old", category=:equipment,
                acquisition_date=Date(2010,1,1), acquisition_cost=80_000.0,
                useful_life_years=10, salvage_value=0.0, is_active=false),
        ]
        total = total_annual_depreciation(assets)
        # A1: 1_000_000/40 = 25_000; A2: 45_000/5 = 9_000; A3: inactive
        @test total ≈ 25_000.0 + 9_000.0
    end

    @testset "replacement_needs" begin
        assets = [
            CapitalAsset(asset_id="R1", description="Old Roof", category=:building,
                acquisition_date=Date(2000,1,1), acquisition_cost=200_000.0,
                useful_life_years=20, salvage_value=0.0, is_active=true,
                accumulated_depreciation=200_000.0),
            CapitalAsset(asset_id="R2", description="New Scanner", category=:equipment,
                acquisition_date=Date(2022,1,1), acquisition_cost=300_000.0,
                useful_life_years=10, salvage_value=30_000.0, is_active=true,
                accumulated_depreciation=27_000.0),
        ]
        # R1: age = 200_000 / (200_000/20) = 20 years; R2: age = 27_000/27_000 = 1 year
        needs = replacement_needs(assets, 15)
        @test length(needs) == 1
        @test needs[1].asset_id == "R1"

        # All under threshold
        needs_high = replacement_needs(assets, 25)
        @test length(needs_high) == 0
    end
end
