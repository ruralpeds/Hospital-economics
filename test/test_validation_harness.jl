using Test
using Dates
using JSON3

include(joinpath(@__DIR__, "..", "src", "validation", "harness.jl"))
using .ValidationHarness

@testset "ValidationHarness module" begin

    @testset "Fixture construction" begin
        fx = Fixture(
            name = "test1",
            function_name = "finance.npv",
            inputs = Dict("rate" => 0.1, "cash_flows" => [-100, 60, 60]),
            expected_outputs = Dict("npv" => 4.13223),
            tolerance = 1e-3,
            category = "finance",
        )
        @test fx.name == "test1"
        @test fx.function_name == "finance.npv"
        @test fx.tolerance == 1e-3
        @test fx.category == "finance"
        @test fx.inputs["rate"] == 0.1
    end

    @testset "diff_outputs: numeric within tolerance" begin
        errs = diff_outputs(Dict("x" => 1.0), Dict("x" => 1.0000001), 1e-3)
        @test isempty(errs)
    end

    @testset "diff_outputs: numeric exceeds tolerance" begin
        errs = diff_outputs(Dict("x" => 1.0), Dict("x" => 2.0), 1e-6)
        @test length(errs) == 1
        @test occursin("\$.x", errs[1])
    end

    @testset "diff_outputs: hybrid abs/rel tolerance scales with magnitude" begin
        # |expected|=1e6, diff=10 -> normalized 1e-5 -> within 1e-4 tolerance
        errs = diff_outputs(Dict("npv" => 1.0e6), Dict("npv" => 1.0e6 + 10), 1e-4)
        @test isempty(errs)
    end

    @testset "diff_outputs: string mismatch" begin
        errs = diff_outputs(Dict("cat" => "Medium"), Dict("cat" => "Low"), 1e-9)
        @test length(errs) == 1
        @test occursin("Medium", errs[1])
    end

    @testset "diff_outputs: extra actual fields allowed" begin
        errs = diff_outputs(
            Dict("x" => 1.0),
            Dict("x" => 1.0, "extra" => "ignore"),
            1e-9,
        )
        @test isempty(errs)
    end

    @testset "diff_outputs: missing expected field flagged" begin
        errs = diff_outputs(Dict("x" => 1.0, "y" => 2.0), Dict("x" => 1.0), 1e-9)
        @test length(errs) == 1
        @test occursin("missing in actual", errs[1])
    end

    @testset "diff_outputs: arrays" begin
        # Prefix-check: extra actual elements are fine.
        errs = diff_outputs([1.0, 2.0], [1.0, 2.0, 3.0], 1e-9)
        @test isempty(errs)

        # Expected longer than actual -> error.
        errs2 = diff_outputs([1.0, 2.0, 3.0], [1.0, 2.0], 1e-9)
        @test length(errs2) == 1
        @test occursin("array length", errs2[1])
    end

    @testset "diff_outputs: nested objects" begin
        e = Dict("outer" => Dict("inner" => 5.0, "name" => "ok"))
        a = Dict("outer" => Dict("inner" => 5.0, "name" => "ok", "extra" => 1))
        @test isempty(diff_outputs(e, a, 1e-6))

        bad = Dict("outer" => Dict("inner" => 6.0, "name" => "ok"))
        errs = diff_outputs(e, bad, 1e-6)
        @test length(errs) == 1
        @test occursin("\$.outer.inner", errs[1])
    end

    @testset "register_function! and run_fixture" begin
        table = Dict{String,Function}()
        register_function!(table, "add_one", inputs -> Dict("y" => inputs["x"] + 1))
        @test haskey(table, "add_one")

        fx = Fixture(
            name = "add1",
            function_name = "add_one",
            inputs = Dict("x" => 41),
            expected_outputs = Dict("y" => 42),
            tolerance = 1e-9,
            category = "math",
        )
        result = run_fixture(fx, table)
        @test result.passed
        @test result.fixture_name == "add1"
        @test result.actual_outputs["y"] == 42
        @test isempty(result.errors)
        @test result.duration_ms >= 0
    end

    @testset "run_fixture: unknown function" begin
        fx = Fixture(name = "x", function_name = "nope")
        result = run_fixture(fx, Dict{String,Function}())
        @test !result.passed
        @test any(occursin("no dispatch", e) for e in result.errors)
    end

    @testset "run_fixture: dispatch error captured" begin
        table = Dict{String,Function}()
        register_function!(table, "boom", _ -> error("kaboom"))
        fx = Fixture(name = "b", function_name = "boom")
        result = run_fixture(fx, table)
        @test !result.passed
        @test any(occursin("dispatch error", e) for e in result.errors)
        @test any(occursin("kaboom", e) for e in result.errors)
    end

    @testset "run_fixture: scalar return wrapped as value" begin
        table = Dict{String,Function}()
        register_function!(table, "double", inputs -> inputs["x"] * 2)
        fx = Fixture(
            name = "d",
            function_name = "double",
            inputs = Dict("x" => 21),
            expected_outputs = Dict("value" => 42),
            tolerance = 1e-9,
        )
        result = run_fixture(fx, table)
        @test result.passed
    end

    @testset "run_harness aggregates results" begin
        table = Dict{String,Function}()
        register_function!(table, "ok", _ -> Dict("y" => 1.0))
        register_function!(table, "bad", _ -> Dict("y" => 2.0))

        fixtures = [
            Fixture(name = "passes", function_name = "ok",
                    expected_outputs = Dict("y" => 1.0), tolerance = 1e-9),
            Fixture(name = "fails", function_name = "bad",
                    expected_outputs = Dict("y" => 1.0), tolerance = 1e-9),
        ]
        report = run_harness("suite-A", fixtures, table)
        @test report.suite_name == "suite-A"
        @test report.pass_count == 1
        @test report.fail_count == 1
        @test length(report.results) == 2
        @test report.total_duration_ms >= 0
        @test report.completed_at >= report.started_at
    end

    @testset "load_fixtures from disk" begin
        mktempdir() do dir
            fx_data = Dict(
                "name" => "fixture1",
                "function_name" => "finance.npv",
                "inputs" => Dict("rate" => 0.1),
                "expected_outputs" => Dict("npv" => 4.13),
                "tolerance" => 1e-3,
                "category" => "finance",
            )
            open(joinpath(dir, "fx1.json"), "w") do io
                JSON3.write(io, fx_data)
            end
            # Nested directory
            subdir = joinpath(dir, "nested")
            mkdir(subdir)
            open(joinpath(subdir, "fx2.json"), "w") do io
                JSON3.write(io, merge(fx_data, Dict("name" => "fixture2")))
            end
            # Invalid file should be skipped (no function_name)
            open(joinpath(dir, "bad.json"), "w") do io
                JSON3.write(io, Dict("name" => "bad"))
            end
            # Non-JSON ignored
            write(joinpath(dir, "ignore.txt"), "hello")

            fixtures = load_fixtures(dir)
            names = Set(fx.name for fx in fixtures)
            @test "fixture1" in names
            @test "fixture2" in names
            @test length(fixtures) == 2
        end
    end

    @testset "load_fixtures: missing directory returns empty" begin
        @test isempty(load_fixtures(joinpath(tempdir(), "does-not-exist-xyz")))
    end

    @testset "export_harness_report JSON and CSV" begin
        table = Dict{String,Function}()
        register_function!(table, "ok", _ -> Dict("y" => 1.0))
        fx = Fixture(
            name = "p", function_name = "ok",
            expected_outputs = Dict("y" => 1.0), tolerance = 1e-9,
        )
        report = run_harness("export-suite", [fx], table)

        mktempdir() do dir
            json_path = joinpath(dir, "report.json")
            export_harness_report(report, json_path; format = :json)
            parsed = JSON3.read(read(json_path, String))
            @test parsed.suite_name == "export-suite"
            @test parsed.pass_count == 1

            csv_path = joinpath(dir, "report.csv")
            export_harness_report(report, csv_path; format = :csv)
            csv = read(csv_path, String)
            @test occursin("fixture_name", csv)
            @test occursin("p,true", csv)

            @test_throws ArgumentError export_harness_report(
                report, joinpath(dir, "x"); format = :yaml,
            )
        end
    end

    @testset "harness_summary_text" begin
        table = Dict{String,Function}()
        register_function!(table, "ok", _ -> Dict("y" => 1.0))
        register_function!(table, "no", _ -> Dict("y" => 9.0))
        fixtures = [
            Fixture(name = "p", function_name = "ok",
                    expected_outputs = Dict("y" => 1.0), tolerance = 1e-9),
            Fixture(name = "f", function_name = "no",
                    expected_outputs = Dict("y" => 1.0), tolerance = 1e-9),
        ]
        report = run_harness("text-suite", fixtures, table)
        text = harness_summary_text(report)
        @test occursin("text-suite", text)
        @test occursin("1/2 passed", text)
        @test occursin("Failures", text)
        @test occursin("- f", text)
    end

    @testset "KNOWN_FUNCTIONS singleton is a Dict{String,Function}" begin
        @test KNOWN_FUNCTIONS isa Dict{String,Function}
        before = length(KNOWN_FUNCTIONS)
        register_function!(KNOWN_FUNCTIONS, "harness_test_ping", _ -> Dict("ok" => true))
        @test haskey(KNOWN_FUNCTIONS, "harness_test_ping")
        @test length(KNOWN_FUNCTIONS) == before + 1
    end

end
