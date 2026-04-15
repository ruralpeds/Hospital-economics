# ============================================================================
# Tests for sensitivity analysis
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "finance", "sensitivity.jl"))

@testset "Sensitivity Analysis" begin

    # Simple linear model: f(p) = p["a"] * 2 + p["b"]
    model_fn(p) = p["a"] * 2.0 + p["b"]
    base_params = Dict("a" => 10.0, "b" => 5.0)

    @testset "run_sensitivity_analysis basics" begin
        results = run_sensitivity_analysis(model_fn, base_params)
        @test length(results) == 2
        @test results[1] isa SensitivityResult
        # Base outcome = 10*2 + 5 = 25
        @test results[1].base_outcome ≈ 25.0
        @test results[2].base_outcome ≈ 25.0
    end

    @testset "results sorted by descending swing" begin
        results = run_sensitivity_analysis(model_fn, base_params; perturbation=0.10)
        @test results[1].swing >= results[2].swing
        # "a" has coefficient 2 and base 10, so swing = 2*(11-9) = 4.0
        # "b" has coefficient 1 and base 5, so swing = (5.5-4.5) = 1.0
        a_result = filter(r -> r.parameter_name == "a", results)[1]
        b_result = filter(r -> r.parameter_name == "b", results)[1]
        @test a_result.swing ≈ 4.0
        @test b_result.swing ≈ 1.0
        # "a" should be first (larger swing)
        @test results[1].parameter_name == "a"
    end

    @testset "perturbation values are correct" begin
        results = run_sensitivity_analysis(model_fn, base_params; perturbation=0.20)
        a_result = filter(r -> r.parameter_name == "a", results)[1]
        @test a_result.low_value ≈ 8.0   # 10 * 0.8
        @test a_result.high_value ≈ 12.0  # 10 * 1.2
        @test a_result.low_outcome ≈ 8.0 * 2.0 + 5.0
        @test a_result.high_outcome ≈ 12.0 * 2.0 + 5.0
    end

    @testset "custom perturbation" begin
        results = run_sensitivity_analysis(model_fn, base_params; perturbation=0.50)
        a_result = filter(r -> r.parameter_name == "a", results)[1]
        @test a_result.low_value ≈ 5.0
        @test a_result.high_value ≈ 15.0
    end

    @testset "build_tornado_data" begin
        results = run_sensitivity_analysis(model_fn, base_params)
        bars = build_tornado_data(results)
        @test length(bars) == 2
        @test bars[1] isa TornadoBar
        @test bars[1].base_outcome ≈ 25.0
        # Deltas are relative to base outcome
        @test bars[1].low_delta ≈ bars[1].base_outcome - 25.0 atol=5.0
    end

    @testset "build_tornado_data top_n" begin
        results = run_sensitivity_analysis(model_fn, base_params)
        bars = build_tornado_data(results; top_n=1)
        @test length(bars) == 1
        @test bars[1].parameter == "a"
    end

    @testset "single parameter" begin
        single = Dict("x" => 100.0)
        results = run_sensitivity_analysis(p -> p["x"] * 3.0, single)
        @test length(results) == 1
        @test results[1].swing ≈ 60.0  # 330 - 270
    end
end
