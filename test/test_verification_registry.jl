using Test
using Dates
using JSON3

include(joinpath(@__DIR__, "..", "src", "validation", "verification_registry.jl"))
using .VerificationRegistryModule

@testset "VerificationRegistry" begin

    @testset "enum values" begin
        @test Int(not_verified) == 0
        @test Int(verified) == 1
        @test Int(stale) == 2
        @test Int(failed) == 3
    end

    @testset "register_verification! creates a verified entry" begin
        reg = VerificationRegistry()
        entry = register_verification!(reg, "finance.dscr", "Finance",
            "Excel reference model v3.1", "models/dscr_reference.xlsx";
            tolerance = 1e-4, notes = "matched all 12 fiscal year rows")
        @test entry.function_name == "finance.dscr"
        @test entry.module_name == "Finance"
        @test entry.status == verified
        @test entry.verified_by == "Excel reference model v3.1"
        @test entry.reference_source == "models/dscr_reference.xlsx"
        @test entry.tolerance == 1e-4
        @test entry.notes == "matched all 12 fiscal year rows"
        @test entry.verified_at <= now(UTC)
        @test length(reg.entries) == 1
    end

    @testset "register_verification! overwrites prior entry" begin
        reg = VerificationRegistry()
        register_verification!(reg, "f", "M", "v1", "src1")
        register_verification!(reg, "f", "M", "v2", "src2"; tolerance = 1e-3)
        @test length(reg.entries) == 1
        @test reg.entries["f"].verified_by == "v2"
        @test reg.entries["f"].tolerance == 1e-3
    end

    @testset "mark_stale! transitions verified -> stale" begin
        reg = VerificationRegistry()
        register_verification!(reg, "a.b", "A", "ref", "src"; notes = "ok")
        mark_stale!(reg, "a.b"; reason = "refactor on 2026-05-28")
        @test reg.entries["a.b"].status == stale
        @test occursin("stale", reg.entries["a.b"].notes)
        @test occursin("refactor", reg.entries["a.b"].notes)
    end

    @testset "mark_stale! is a no-op for unknown functions" begin
        reg = VerificationRegistry()
        mark_stale!(reg, "missing"; reason = "")
        @test isempty(reg.entries)
    end

    @testset "mark_failed! transitions to failed and records reason" begin
        reg = VerificationRegistry()
        register_verification!(reg, "x", "X", "ref", "src")
        mark_failed!(reg, "x", "diff exceeded 2.3e-3 vs 1e-6 tolerance")
        @test reg.entries["x"].status == failed
        @test occursin("failed", reg.entries["x"].notes)
        @test occursin("2.3e-3", reg.entries["x"].notes)
    end

    @testset "query_verifications filters" begin
        reg = VerificationRegistry()
        register_verification!(reg, "fin.npv", "Finance", "Excel", "npv.xlsx")
        register_verification!(reg, "fin.irr", "Finance", "Excel", "irr.xlsx")
        register_verification!(reg, "q.spc", "Quality", "R qcc", "qcc.R")
        mark_failed!(reg, "fin.irr", "off by 0.01")

        @test length(query_verifications(reg)) == 3
        @test length(query_verifications(reg; status = verified)) == 2
        @test length(query_verifications(reg; status = failed)) == 1
        @test length(query_verifications(reg; module_name = "Finance")) == 2
        @test length(query_verifications(reg; status = verified, module_name = "Quality")) == 1
        @test isempty(query_verifications(reg; module_name = "Nope"))
    end

    @testset "verification_coverage" begin
        reg = VerificationRegistry()
        register_verification!(reg, "a", "M", "ref", "src")
        register_verification!(reg, "b", "M", "ref", "src")
        register_verification!(reg, "c", "M", "ref", "src")
        mark_stale!(reg, "b")
        mark_failed!(reg, "c", "diff")

        cov = verification_coverage(reg, ["a", "b", "c", "d"])
        @test cov.total == 4
        @test cov.verified == 1
        @test cov.stale == 1
        @test cov.failed == 1
        @test cov.not_verified == 1
        @test cov.coverage_pct == 25.0

        @test verification_coverage(reg, String[]).coverage_pct == 0.0
    end

    @testset "critical_unverified" begin
        reg = VerificationRegistry()
        register_verification!(reg, "ok", "M", "ref", "src")
        register_verification!(reg, "bad", "M", "ref", "src")
        mark_failed!(reg, "bad", "diff")

        gaps = critical_unverified(reg, ["ok", "bad", "missing"])
        @test "ok" ∉ gaps
        @test "bad" ∈ gaps
        @test "missing" ∈ gaps
        @test length(gaps) == 2
    end

    @testset "export_verification_report writes sorted JSON" begin
        reg = VerificationRegistry()
        register_verification!(reg, "z.func", "Z", "ref", "src")
        register_verification!(reg, "a.func", "A", "ref", "src")
        mktempdir() do dir
            path = joinpath(dir, "subdir", "report.json")
            export_verification_report(reg, path)
            @test isfile(path)
            payload = JSON3.read(read(path, String))
            @test payload["total_entries"] == 2
            @test haskey(payload["records"], "a.func")
            @test haskey(payload["records"], "z.func")
            @test payload["records"]["a.func"]["status"] == "verified"
            @test haskey(payload, "generated_at")
        end
    end

    @testset "global VERIFICATION_REGISTRY is shared" begin
        n_before = length(VERIFICATION_REGISTRY.entries)
        register_verification!(VERIFICATION_REGISTRY, "global.test.fn",
            "GlobalTest", "ref", "src")
        @test length(VERIFICATION_REGISTRY.entries) == n_before + 1
        @test VERIFICATION_REGISTRY.entries["global.test.fn"].status == verified
        # clean up to keep the singleton tidy for any subsequent test file
        delete!(VERIFICATION_REGISTRY.entries, "global.test.fn")
    end

    @testset "thread-safety: concurrent registration" begin
        reg = VerificationRegistry()
        Threads.@threads for i in 1:100
            register_verification!(reg, "fn_$i", "M", "ref", "src")
        end
        @test length(reg.entries) == 100
    end
end
