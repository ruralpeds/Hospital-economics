# ============================================================================
# Tests for discrete event simulation (ED throughput model)
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "simulation", "des.jl"))

@testset "DES Simulation" begin

    @testset "default DESParams produces reasonable result" begin
        params = DESParams()
        result = run_des(params)
        @test result isa DESResult
        @test result.total_patients > 0
        @test 0.0 < result.bed_utilization < 1.0
        @test result.avg_wait_time >= 0.0
        @test result.avg_length_of_stay > 0.0
        @test length(result.hourly_arrivals) == 24
        @test length(result.hourly_occupancy) == 24
        @test result.lwbs_rate >= 0.0 && result.lwbs_rate <= 1.0
    end

    @testset "total patients matches arrival rate * hours" begin
        params = DESParams(simulation_hours=720, mean_arrival_rate=2.5)
        result = run_des(params)
        @test result.total_patients == round(Int, 2.5 * 720)
    end

    @testset "high arrival rate produces high utilization" begin
        params_high = DESParams(mean_arrival_rate=7.0, ed_beds=4)
        result_high = run_des(params_high)
        # With 7 arrivals/hr and only 4 beds, system should be heavily loaded
        @test result_high.bed_utilization >= 0.8
    end

    @testset "low bed count increases wait time" begin
        params_few = DESParams(mean_arrival_rate=3.0, ed_beds=3)
        params_many = DESParams(mean_arrival_rate=3.0, ed_beds=12)
        result_few = run_des(params_few)
        result_many = run_des(params_many)
        @test result_few.avg_wait_time >= result_many.avg_wait_time
    end

    @testset "hourly patterns have correct length" begin
        result = run_des(DESParams())
        @test length(result.hourly_arrivals) == 24
        @test length(result.hourly_occupancy) == 24
        # All occupancy values should be non-negative
        @test all(x -> x >= 0.0, result.hourly_occupancy)
        # All arrivals should be positive
        @test all(x -> x > 0.0, result.hourly_arrivals)
    end

    @testset "max wait >= avg wait" begin
        result = run_des(DESParams())
        @test result.max_wait_time >= result.avg_wait_time
    end

    @testset "very low arrival rate gives low utilization" begin
        params = DESParams(mean_arrival_rate=0.5, ed_beds=8)
        result = run_des(params)
        @test result.bed_utilization < 0.3
        @test result.avg_wait_time < 0.1
    end
end
