# ============================================================================
# Tests for benchmark comparison analysis
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "data", "benchmarks.jl"))

@testset "Benchmarks" begin

    @testset "default_cah_benchmarks returns BenchmarkData" begin
        bm = default_cah_benchmarks()
        @test bm isa BenchmarkData
        @test bm.operating_margin ≈ -0.005
        @test bm.days_cash_on_hand ≈ 95.0
        @test bm.current_ratio ≈ 2.45
        @test bm.peer_operating_margin ≈ -0.008
    end

    @testset "compare_to_benchmarks with known metrics" begin
        metrics = Dict(
            "operating_margin" => 0.03,
            "days_cash_on_hand" => 120.0,
        )
        comps = compare_to_benchmarks(metrics)
        @test length(comps) == 2
        @test all(c -> c isa BenchmarkComparison, comps)
        # Find operating_margin comparison
        om = filter(c -> c.metric == "operating_margin", comps)[1]
        @test om.hospital_value ≈ 0.03
        @test om.national_median ≈ -0.005
        @test om.variance_from_national ≈ 0.035
    end

    @testset "compare_to_benchmarks ignores unknown metrics" begin
        metrics = Dict("nonexistent_metric" => 42.0)
        comps = compare_to_benchmarks(metrics)
        @test length(comps) == 0
    end

    @testset "percentile_rank returns 0-100" begin
        # Value at median should be near 50
        p = percentile_rank(-0.005, -0.005, "operating_margin")
        @test 45.0 <= p <= 55.0

        # Value well above median
        p_high = percentile_rank(0.10, -0.005, "operating_margin")
        @test p_high > 80.0
        @test p_high <= 100.0

        # Value well below median
        p_low = percentile_rank(-0.15, -0.005, "operating_margin")
        @test p_low < 20.0
        @test p_low >= 0.0
    end

    @testset "percentile_rank clamped" begin
        # Extreme values should still be in range
        p = percentile_rank(100.0, 0.0, "operating_margin")
        @test 0.0 <= p <= 100.0
        p2 = percentile_rank(-100.0, 0.0, "operating_margin")
        @test 0.0 <= p2 <= 100.0
    end

    @testset "rating logic - above median higher-is-better" begin
        metrics = Dict("operating_margin" => 0.10)
        comps = compare_to_benchmarks(metrics)
        om = comps[1]
        # 0.10 is well above -0.005 median => should be Above Average
        @test om.rating == "Above Average"
    end

    @testset "rating logic - below median higher-is-better" begin
        metrics = Dict("operating_margin" => -0.10)
        comps = compare_to_benchmarks(metrics)
        om = comps[1]
        # -0.10 is well below -0.005 => Below Average or Critical
        @test om.rating in ["Below Average", "Critical"]
    end

    @testset "rating logic - lower-is-better metric" begin
        # debt_to_capitalization: lower is better, median = 0.32
        metrics = Dict("debt_to_capitalization" => 0.15)
        comps = compare_to_benchmarks(metrics)
        dtc = comps[1]
        # 0.15 is well below 0.32 median, and lower is better => Above Average
        @test dtc.rating == "Above Average"
    end

    @testset "variance from peer" begin
        metrics = Dict("operating_margin" => 0.03)
        bm = default_cah_benchmarks()
        comps = compare_to_benchmarks(metrics, bm)
        om = filter(c -> c.metric == "operating_margin", comps)[1]
        @test om.variance_from_peer ≈ 0.03 - bm.peer_operating_margin
    end
end
