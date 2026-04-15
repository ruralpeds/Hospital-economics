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
        @test straight_line_depreciation(100_000.0, 10_000.0, 10) ≈ 9_000.0
        @test straight_line_depreciation(50_000.0, 0.0, 5) ≈ 10_000.0
        @test_throws ErrorException straight_line_depreciation(100_000.0, 0.0, 0)
    end

    @testset "declining_balance_depreciation" begin
        @test declining_balance_depreciation(100_000.0, 5) ≈ 40_000.0
        @test declining_balance_depreciation(60_000.0, 5) ≈ 24_000.0
        @test declining_balance_depreciation(100_000.0, 5; factor=1.5) ≈ 30_000.0
        @test_throws ErrorException declining_balance_depreciation(100_000.0, 0)
    end

    @testset "depreciation_schedule - straight line full life" begin
        asset = CapitalAsset(
            asset_id="EQ001", description="CT Scanner",
            category=:equipment, acquisition_date=Date(2020, 1, 1),
            acquisition_cost=500_000.0, useful_life_years=10,
            salvage_value=50_000.0, depreciation_method=:straight_line,
        )
        sched = depreciation_schedule(asset, 10)
        @test length(sched) == 10
        # Annual expense = (500k - 50k) / 10 = 45k
        @test sched[1].expense ≈ 45_000.0
        @test sched[1].accumulated ≈ 45_000.0
        @test sched[1].book_value ≈ 455_000.0
        @test sched[10].book_value ≈ 50_000.0
        @test sched[10].accumulated ≈ 450_000.0
    end

    @testset "depreciation_schedule - declining balance" begin
        asset = CapitalAsset(
            asset_id="EQ002", description="MRI Machine",
            category=:equipment, acquisition_date=Date(2021, 6, 1),
            acquisition_cost=200_000.0, useful_life_years=5,
            salvage_value=20_000.0, depreciation_method=:declining_balance,
        )
        sched = depreciation_schedule(asset, 5)
        @test length(sched) == 5
        # First year DDB: 200k * (2/5) = 80k
        @test sched[1].expense ≈ 80_000.0
        # Book value never goes below salvage
        @test sched[end].book_value >= 20_000.0 - 0.01
        # Accumulated depreciation is non-decreasing
        for i in 2:5
            @test sched[i].accumulated >= sched[i-1].accumulated - 0.01
        end
    end

    @testset "depreciation_schedule - beyond useful life has zero expense" begin
        asset = CapitalAsset(
            asset_id="EQ003", description="Small device",
            category=:equipment, acquisition_date=Date(2022, 1, 1),
            acquisition_cost=10_000.0, useful_life_years=3,
            salvage_value=1_000.0, depreciation_method=:straight_line,
        )
        sched = depreciation_schedule(asset, 5)
        @test length(sched) == 5
        @test sched[3].book_value ≈ 1_000.0
        @test sched[4].expense ≈ 0.0
        @test sched[5].expense ≈ 0.0
    end

    @testset "depreciation_schedule - with prior accumulated depreciation" begin
        asset = CapitalAsset(
            asset_id="EQ004", description="X-Ray Unit",
            category=:equipment, acquisition_date=Date(2018, 1, 1),
            acquisition_cost=100_000.0, useful_life_years=10,
            salvage_value=0.0, depreciation_method=:straight_line,
            accumulated_depreciation=50_000.0,
        )
        sched = depreciation_schedule(asset, 5)
        # Annual SL = 10k, starting book = 50k
        @test sched[1].expense ≈ 10_000.0
        @test sched[5].book_value ≈ 0.0
        @test sched[5].accumulated ≈ 100_000.0
    end

    @testset "total_annual_depreciation - active assets only" begin
        assets = [
            CapitalAsset(asset_id="A1", description="Building",
                category=:building, acquisition_date=Date(2015,1,1),
                acquisition_cost=2_000_000.0, useful_life_years=40,
                salvage_value=200_000.0, is_active=true),
            CapitalAsset(asset_id="A2", description="Van",
                category=:vehicle, acquisition_date=Date(2018,1,1),
                acquisition_cost=40_000.0, useful_life_years=5,
                salvage_value=5_000.0, is_active=true),
            CapitalAsset(asset_id="A3", description="Retired Scanner",
                category=:equipment, acquisition_date=Date(2010,1,1),
                acquisition_cost=300_000.0, useful_life_years=10,
                salvage_value=0.0, is_active=false),
        ]
        total = total_annual_depreciation(assets)
        # Building: (2M - 200k)/40 = 45k; Van: (40k - 5k)/5 = 7k; Retired: excluded
        @test total ≈ 45_000.0 + 7_000.0
    end

    @testset "total_annual_depreciation - empty list" begin
        @test total_annual_depreciation(CapitalAsset[]) ≈ 0.0
    end

    @testset "replacement_needs" begin
        old_asset = CapitalAsset(asset_id="OLD-1", description="Old Boiler",
            category=:equipment, acquisition_date=Date(2005,1,1),
            acquisition_cost=100_000.0, useful_life_years=10,
            salvage_value=0.0, accumulated_depreciation=90_000.0, is_active=true)
        new_asset = CapitalAsset(asset_id="NEW-1", description="New Monitor",
            category=:equipment, acquisition_date=Date(2023,1,1),
            acquisition_cost=50_000.0, useful_life_years=10,
            salvage_value=5_000.0, accumulated_depreciation=4_500.0, is_active=true)
        inactive_old = CapitalAsset(asset_id="OLD-2", description="Decommissioned",
            category=:equipment, acquisition_date=Date(2000,1,1),
            acquisition_cost=80_000.0, useful_life_years=10,
            salvage_value=0.0, accumulated_depreciation=80_000.0, is_active=false)

        needs = replacement_needs([old_asset, new_asset, inactive_old], 8)
        # Old: age=90k/10k=9>=8; New: age=1<8; Inactive: excluded
        @test length(needs) == 1
        @test needs[1].asset_id == "OLD-1"
        # None needed with high threshold
        @test length(replacement_needs([new_asset], 15)) == 0
    end
end
