"""
    test_hash_chain_audit.jl

Unit tests for the hash-chained audit log module
(`src/validation/hash_chain_audit.jl`).

Covers:
- Empty log: chain valid
- Append five entries: chain valid and hashes link correctly
- Tampering with entry 2's `details`: verification detects it and returns
  `first_tampered_index == 2`
- Persist + reload from JSONL: chain still verifies
- Concurrent append from many tasks (`@sync @async`): chain still verifies
"""

using Test
using Dates
using JSON3

include(joinpath(@__DIR__, "..", "src", "validation", "hash_chain_audit.jl"))

@testset "hash_chain_audit" begin

    @testset "Empty log: chain valid" begin
        log = HashChainedLog()
        result = verify_chain(log)
        @test result.valid
        @test result.first_tampered_index === nothing
        @test isempty(result.errors)

        summary = chain_summary(log)
        @test summary.entry_count == 0
        @test summary.valid
        @test summary.latest_hash == log.genesis_hash
    end

    @testset "Five entries form valid chain" begin
        log = HashChainedLog()
        for i in 1:5
            append_entry!(
                log,
                "PHI_ACCESS",
                "user_$i",
                "patient_$i",
                "VIEW";
                details = Dict{String, Any}("seq" => i, "note" => "entry $i"),
            )
        end

        @test length(log.entries) == 5
        @test log.entries[1].index == 0
        @test log.entries[5].index == 4
        @test log.entries[1].prev_hash == log.genesis_hash

        # Each entry's prev_hash matches the previous entry's entry_hash.
        for i in 2:5
            @test log.entries[i].prev_hash == log.entries[i - 1].entry_hash
        end

        # All entry_hashes recompute to the same stored values.
        for entry in log.entries
            @test compute_entry_hash(entry) == entry.entry_hash
        end

        result = verify_chain(log)
        @test result.valid
        @test result.first_tampered_index === nothing
        @test isempty(result.errors)
    end

    @testset "Tampering with entry 2's details is detected" begin
        log = HashChainedLog()
        for i in 1:5
            append_entry!(
                log,
                "PHI_ACCESS",
                "user_$i",
                "patient_$i",
                "VIEW";
                details = Dict{String, Any}("seq" => i),
            )
        end

        # Tamper with entry at index 2 (the third entry).
        original = log.entries[3]
        @test original.index == 2
        tampered_details = Dict{String, Any}("seq" => 999, "evil" => true)
        log.entries[3] = HashChainedEntry(
            original.index,
            original.timestamp,
            original.event_type,
            original.user_id,
            original.resource,
            original.action,
            tampered_details,
            original.prev_hash,
            original.entry_hash,  # stale hash that no longer matches contents
        )

        result = verify_chain(log)
        @test !result.valid
        @test result.first_tampered_index == 2
        @test !isempty(result.errors)
        @test any(occursin("entry_hash mismatch", e) for e in result.errors)
    end

    @testset "Persist and reload: chain still valid" begin
        mktempdir() do dir
            path = joinpath(dir, "audit.jsonl")
            log = HashChainedLog(path)

            for i in 1:5
                append_entry!(
                    log,
                    "INGESTION",
                    "loader",
                    "file_$i.csv",
                    "IMPORT";
                    details = Dict{String, Any}("rows" => i * 100),
                )
            end

            @test isfile(path)
            nlines = countlines(path)
            @test nlines == 5

            reloaded = load_hash_chained_log(path)
            @test length(reloaded.entries) == 5

            result = verify_chain(reloaded)
            @test result.valid
            @test result.first_tampered_index === nothing

            # Round-tripped hashes match the originals.
            for i in 1:5
                @test reloaded.entries[i].entry_hash == log.entries[i].entry_hash
                @test reloaded.entries[i].prev_hash == log.entries[i].prev_hash
            end

            # Report export works.
            report_path = joinpath(dir, "report.txt")
            export_audit_report(reloaded, report_path)
            @test isfile(report_path)
            report_text = read(report_path, String)
            @test occursin("HASH-CHAINED AUDIT TRAIL REPORT", report_text)
            @test occursin("Valid:", report_text)
        end
    end

    @testset "Concurrent append from multiple tasks: chain still valid" begin
        mktempdir() do dir
            path = joinpath(dir, "concurrent.jsonl")
            log = HashChainedLog(path)

            n_tasks = 20
            @sync for t in 1:n_tasks
                @async append_entry!(
                    log,
                    "CONCURRENT",
                    "task_$t",
                    "res_$t",
                    "WRITE";
                    details = Dict{String, Any}("task_id" => t),
                )
            end

            @test length(log.entries) == n_tasks

            # Indices are 0..n_tasks-1 in order (lock guarantees serialization).
            for (i, entry) in enumerate(log.entries)
                @test entry.index == i - 1
            end

            result = verify_chain(log)
            @test result.valid
            @test result.first_tampered_index === nothing
            @test isempty(result.errors)

            # Disk reflects the same number of lines.
            @test countlines(path) == n_tasks

            reloaded = load_hash_chained_log(path)
            @test length(reloaded.entries) == n_tasks
            @test verify_chain(reloaded).valid
        end
    end

end
