using Test
using Dates
using JSON3

include(joinpath(@__DIR__, "..", "src", "validation", "fmea.jl"))
using .FMEA

@testset "FMEA module" begin

    @testset "FailureMode construction and RPN" begin
        fm = FailureMode(
            id = "FM-TEST-001",
            description = "Test failure",
            function_name = "test.fn",
            potential_cause = "cause",
            potential_effect = "effect",
            severity = 5,
            probability = 4,
            detectability = 3,
            mitigation = "mit",
            assigned_to = "qa",
        )
        @test fm.id == "FM-TEST-001"
        @test fm.rpn == 60
        @test fm.status == :open
        @test FMEA.compute_rpn(5, 4, 3) == 60
    end

    @testset "Score validation" begin
        @test_throws ArgumentError FailureMode(id = "X", severity = 0)
        @test_throws ArgumentError FailureMode(id = "X", probability = 11)
        @test_throws ArgumentError FailureMode(id = "X", detectability = -1)
    end

    @testset "risk_acceptability bands" begin
        @test risk_acceptability(0) == :acceptable
        @test risk_acceptability(49) == :acceptable
        @test risk_acceptability(50) == :review
        @test risk_acceptability(125) == :review
        @test risk_acceptability(126) == :unacceptable
        @test risk_acceptability(1000) == :unacceptable
    end

    @testset "add_failure_mode! recomputes RPN" begin
        report = FMEAReport()
        fm = FailureMode(
            id = "FM-A", severity = 6, probability = 5, detectability = 4,
        )
        # Mutate scores prior to insertion; add! should recompute RPN.
        fm.severity = 10
        add_failure_mode!(report, fm)
        @test length(report.failure_modes) == 1
        @test report.failure_modes[1].rpn == 10 * 5 * 4
    end

    @testset "prioritize_by_rpn and high_risk_modes" begin
        report = FMEAReport()
        add_failure_mode!(report, FailureMode(id = "low", severity = 1, probability = 1, detectability = 1))
        add_failure_mode!(report, FailureMode(id = "hi", severity = 10, probability = 9, detectability = 8))
        add_failure_mode!(report, FailureMode(id = "mid", severity = 5, probability = 5, detectability = 5))

        prio = prioritize_by_rpn(report)
        @test [fm.id for fm in prio] == ["hi", "mid", "low"]

        hi = high_risk_modes(report; threshold = 100)
        @test length(hi) == 2
        @test hi[1].id == "hi"
        @test hi[2].id == "mid"

        @test isempty(high_risk_modes(report; threshold = 1000))
    end

    @testset "update_mitigation! and close_failure_mode!" begin
        report = FMEAReport()
        add_failure_mode!(report, FailureMode(
            id = "FM-U", severity = 8, probability = 6, detectability = 9,
        ))
        original_rpn = report.failure_modes[1].rpn
        @test original_rpn == 8 * 6 * 9

        update_mitigation!(report, "FM-U", "added unit test", 3)
        @test report.failure_modes[1].mitigation == "added unit test"
        @test report.failure_modes[1].detectability == 3
        @test report.failure_modes[1].rpn == 8 * 6 * 3
        @test report.failure_modes[1].status == :mitigated

        close_failure_mode!(report, "FM-U")
        @test report.failure_modes[1].status == :closed

        @test_throws KeyError close_failure_mode!(report, "missing")
        @test_throws KeyError update_mitigation!(report, "missing", "x", 2)
        @test_throws ArgumentError update_mitigation!(report, "FM-U", "x", 11)
    end

    @testset "fmea_summary" begin
        report = FMEAReport()
        add_failure_mode!(report, FailureMode(id = "a", severity = 2, probability = 2, detectability = 2))  # RPN 8 acceptable
        add_failure_mode!(report, FailureMode(id = "b", severity = 5, probability = 5, detectability = 3))  # RPN 75 review
        add_failure_mode!(report, FailureMode(id = "c", severity = 9, probability = 8, detectability = 6))  # RPN 432 unacceptable
        close_failure_mode!(report, "a")

        summary = fmea_summary(report)
        @test summary.total == 3
        @test summary.by_status[:closed] == 1
        @test summary.by_status[:open] == 2
        @test summary.by_acceptability[:acceptable] == 1
        @test summary.by_acceptability[:review] == 1
        @test summary.by_acceptability[:unacceptable] == 1
        @test summary.mean_rpn ≈ (8 + 75 + 432) / 3
    end

    @testset "empty summary" begin
        report = FMEAReport()
        summary = fmea_summary(report)
        @test summary.total == 0
        @test summary.mean_rpn == 0.0
    end

    @testset "export_fmea_report CSV and JSON" begin
        report = FMEAReport()
        add_failure_mode!(report, FailureMode(
            id = "FM-EXP-001",
            description = "Quoted, comma-laden \"text\"",
            severity = 4, probability = 3, detectability = 2,
        ))

        mktempdir() do dir
            csv_path = joinpath(dir, "report.csv")
            export_fmea_report(report, csv_path; format = :csv)
            csv = read(csv_path, String)
            @test occursin("FM-EXP-001", csv)
            @test occursin("acceptability", csv)
            @test occursin("\"\"text\"\"", csv)  # escaped quotes

            json_path = joinpath(dir, "report.json")
            export_fmea_report(report, json_path; format = :json)
            parsed = JSON3.read(read(json_path, String))
            @test length(parsed.failure_modes) == 1
            @test parsed.failure_modes[1].id == "FM-EXP-001"

            @test_throws ArgumentError export_fmea_report(report, joinpath(dir, "x"); format = :xml)
        end
    end

    @testset "HOSPITAL_FINANCE_FMEA_TEMPLATE" begin
        tmpl = HOSPITAL_FINANCE_FMEA_TEMPLATE()
        @test length(tmpl) >= 10
        ids = [fm.id for fm in tmpl]
        @test "FM-NPV-001" in ids
        @test "FM-DRG-001" in ids
        @test "FM-AUDIT-001" in ids
        @test length(unique(ids)) == length(ids)
        @test all(1 <= fm.severity <= 10 for fm in tmpl)
        @test all(fm.rpn == fm.severity * fm.probability * fm.detectability for fm in tmpl)
    end

    @testset "FMEA_REGISTRY singleton" begin
        @test FMEA_REGISTRY isa FMEAReport
        before = length(FMEA_REGISTRY.failure_modes)
        add_failure_mode!(FMEA_REGISTRY, FailureMode(
            id = "FM-GLOBAL-TEST", severity = 1, probability = 1, detectability = 1,
        ))
        @test length(FMEA_REGISTRY.failure_modes) == before + 1
    end

end
