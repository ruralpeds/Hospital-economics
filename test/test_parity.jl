"""
Tests for the parity testing framework (`src/validation/parity.jl`).
"""

using Test
using Dates
using JSON3

# Load the parity module directly from source so this test file is
# self-contained and does not depend on the top-level package include path.
include(joinpath(@__DIR__, "..", "src", "validation", "parity.jl"))
using .Parity

@testset "Parity framework" begin

    @testset "Tolerance defaults" begin
        t = Tolerance()
        @test t.absolute == 1e-9
        @test t.relative == 1e-6
        @test t.nan_equal == true
    end

    @testset "Scalar: equal within absolute tolerance" begin
        c = compare_scalar("equal", 1.0, 1.0 + 1e-12)
        @test c.passed
        @test c.delta !== nothing
        @test c.delta <= 1e-9
        @test occursin("OK", c.message)
    end

    @testset "Scalar: exact equality" begin
        c = compare("exact", 42.0, 42.0)
        @test c.passed
        @test c.delta == 0.0
        @test c.relative_delta == 0.0
    end

    @testset "Scalar: within relative tolerance but outside absolute" begin
        # |Δ| = 1e-4, absolute fails (1e-9), but |Δ|/|expected| = 1e-10 << 1e-6.
        expected = 1.0e6
        actual   = 1.0e6 + 1.0e-4
        c = compare_scalar("rel_ok", expected, actual)
        @test c.passed
        @test c.relative_delta < 1e-6
    end

    @testset "Scalar: exceeding both tolerances fails" begin
        c = compare_scalar("fail", 1.0, 2.0)
        @test !c.passed
        @test isapprox(c.delta, 1.0; atol=1e-12)
        @test isapprox(c.relative_delta, 1.0; atol=1e-12)
        @test occursin("FAIL", c.message)
    end

    @testset "Scalar: custom tolerance allows looser match" begin
        loose = Tolerance(0.1, 0.0, true)
        c = compare_scalar("loose", 1234567.89, 1234567.88; tolerance=loose)
        @test c.passed
    end

    @testset "NaN equality" begin
        # Default: nan_equal = true.
        c_eq = compare_scalar("nan_eq", NaN, NaN)
        @test c_eq.passed
        @test occursin("NaN == NaN", c_eq.message)

        # nan_equal = false.
        strict = Tolerance(1e-9, 1e-6, false)
        c_ne = compare_scalar("nan_neq", NaN, NaN; tolerance=strict)
        @test !c_ne.passed
        @test occursin("NaN != NaN", c_ne.message)

        # NaN vs concrete number always fails.
        c_mixed = compare_scalar("nan_mixed", NaN, 1.0)
        @test !c_mixed.passed
    end

    @testset "Inf handling" begin
        c_eq = compare_scalar("inf_eq", Inf, Inf)
        @test c_eq.passed
        c_ne = compare_scalar("inf_ne", Inf, -Inf)
        @test !c_ne.passed
    end

    @testset "Vector: element-wise pass" begin
        e = [1.0, 2.0, 3.0]
        a = [1.0, 2.0, 3.0 + 1e-12]
        c = compare_vector("vec_ok", e, a)
        @test c.passed
        @test c.delta !== nothing
        @test c.delta <= 1e-9
    end

    @testset "Vector: element-wise failure" begin
        e = [1.0, 2.0, 3.0]
        a = [1.0, 2.0, 3.5]
        c = compare_vector("vec_fail", e, a)
        @test !c.passed
        @test occursin("FAIL", c.message)
    end

    @testset "Vector: length mismatch" begin
        c = compare_vector("vec_len", [1.0, 2.0], [1.0, 2.0, 3.0])
        @test !c.passed
        @test occursin("Length mismatch", c.message)
    end

    @testset "Vector: empty vectors" begin
        c = compare_vector("vec_empty", Float64[], Float64[])
        @test c.passed
    end

    @testset "Vector: dispatch through compare()" begin
        c = compare("dispatch", [1.0, 2.0], [1.0, 2.0])
        @test c.passed
    end

    @testset "Dict: recursive pass" begin
        e = Dict("a" => 1.0, "b" => Dict("c" => 2.0, "d" => [1.0, 2.0]))
        a = Dict("a" => 1.0, "b" => Dict("c" => 2.0 + 1e-12, "d" => [1.0, 2.0]))
        c = compare_dict("nested", e, a)
        @test c.passed
    end

    @testset "Dict: missing keys fails" begin
        e = Dict("a" => 1.0, "b" => 2.0)
        a = Dict("a" => 1.0)
        c = compare_dict("missing_key", e, a)
        @test !c.passed
        @test occursin("Key mismatch", c.message)
    end

    @testset "Dict: extra keys fails" begin
        e = Dict("a" => 1.0)
        a = Dict("a" => 1.0, "b" => 2.0)
        c = compare_dict("extra_key", e, a)
        @test !c.passed
        @test occursin("Key mismatch", c.message)
    end

    @testset "Dict: value mismatch fails" begin
        e = Dict("a" => 1.0, "b" => 2.0)
        a = Dict("a" => 1.0, "b" => 5.0)
        c = compare_dict("val_mismatch", e, a)
        @test !c.passed
    end

    @testset "Non-numeric fallback equality" begin
        c_eq = compare("str_eq", "hello", "hello")
        @test c_eq.passed
        c_ne = compare("str_ne", "hello", "world")
        @test !c_ne.passed
    end

    @testset "ParityReport summary counts" begin
        cmps = ParityComparison[
            compare("p1", 1.0, 1.0),
            compare("p2", 2.0, 2.0),
            compare("f1", 1.0, 5.0),
        ]
        report = run_parity_suite("mixed_suite", cmps)
        @test report.passed_count == 2
        @test report.failed_count == 1
        @test length(report.comparisons) == 3
        @test occursin("2/3 passed", report.summary)
        @test report.suite_name == "mixed_suite"
        @test report.timestamp isa DateTime
    end

    @testset "parity_summary_text formatting" begin
        cmps = ParityComparison[
            compare("alpha", 1.0, 1.0),
            compare("beta",  1.0, 2.0),
        ]
        report = run_parity_suite("text_suite", cmps)
        text = parity_summary_text(report)
        @test occursin("Parity Test Report", text)
        @test occursin("text_suite", text)
        @test occursin("[PASS] alpha", text)
        @test occursin("[FAIL] beta", text)
    end

    @testset "export_parity_report JSON round-trip" begin
        cmps = ParityComparison[
            compare("x", 1.0, 1.0),
            compare("y", 1.0, 2.0),
        ]
        report = run_parity_suite("io_suite", cmps)
        path = tempname() * ".json"
        try
            export_parity_report(report, path; format=:json)
            @test isfile(path)
            data = JSON3.read(read(path, String))
            @test String(data.suite_name) == "io_suite"
            @test data.passed_count == 1
            @test data.failed_count == 1
            @test length(data.comparisons) == 2
        finally
            isfile(path) && rm(path)
        end
    end

    @testset "export_parity_report CSV" begin
        cmps = ParityComparison[compare("x", 1.0, 1.0)]
        report = run_parity_suite("csv_suite", cmps)
        path = tempname() * ".csv"
        try
            export_parity_report(report, path; format=:csv)
            @test isfile(path)
            content = read(path, String)
            @test occursin("name,passed", content)
            @test occursin("\"x\"", content)
        finally
            isfile(path) && rm(path)
        end
    end

    @testset "load_reference_fixtures" begin
        fixture = Dict(
            "npv"    => 1234.56,
            "values" => [1.0, 2.0, 3.0],
            "nested" => Dict("a" => 1, "b" => 2),
        )
        path = tempname() * ".json"
        try
            open(path, "w") do io
                JSON3.write(io, fixture)
            end
            loaded = load_reference_fixtures(path)
            @test loaded isa Dict
            @test loaded["npv"] == 1234.56
            @test loaded["values"] == [1.0, 2.0, 3.0]
            @test loaded["nested"] isa Dict
            @test loaded["nested"]["a"] == 1
        finally
            isfile(path) && rm(path)
        end
    end

    @testset "load_reference_fixtures missing file errors" begin
        @test_throws ArgumentError load_reference_fixtures("/no/such/file.json")
    end

    @testset "@parity_test macro accumulates results" begin
        __parity_results__ = ParityComparison[]
        @parity_test "m_pass" 1.0 1.0
        @parity_test "m_fail" 1.0 2.0
        @parity_test "m_tol"  1.0 1.5 Tolerance(1.0, 0.0, true)
        @test length(__parity_results__) == 3
        @test __parity_results__[1].passed
        @test !__parity_results__[2].passed
        @test __parity_results__[3].passed  # within custom abs tol of 1.0
    end

    @testset "@parity_test macro returns comparison when no accumulator" begin
        c = @parity_test "standalone" 1.0 1.0
        @test c isa ParityComparison
        @test c.passed
    end
end
