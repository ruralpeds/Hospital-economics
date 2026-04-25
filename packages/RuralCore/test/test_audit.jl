# ==============================================================================
# test_audit.jl — Coverage for RuralCore's audit-trail shim and the canonical
# AuditTrail submodule it delegates to.
#
# Exercises:
#   * Canonical 4-arg @audited_calculation path
#   * Legacy 1-arg @audited_calculation path (with deprecation emission)
#   * HMAC integrity round-trip
#   * Tamper detection
#   * Wrong-key rejection
#   * Actor context propagation
#   * HMAC-SHA256 RFC 4231 test vector 1 (crypto correctness signal)
# ==============================================================================

using Test
using Dates
using JSON3
using RuralCore
using RuralCore.AuditTrail

# Isolated test harness — every test runs against a tempdir sink + known key
# so we don't step on each other or on a developer's HARTZOG_AUDIT_LOG.
@testset "RuralCore audit trail" begin

    @testset "HMAC-SHA256 RFC 4231 vector 1 — crypto correctness" begin
        # This is the canonical signal that the HMAC is implemented correctly.
        # If this fails, EVERY signed record is cryptographically invalid.
        key  = fill(0x0b, 20)
        data = Vector{UInt8}("Hi There")
        mac  = AuditTrail.hmac_sha256(key, data)
        @test bytes2hex(mac) ==
              "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
    end

    mktempdir() do dir
        log_path = joinpath(dir, "audit.jsonl")
        key = rand(UInt8, 32)
        AuditTrail.configure!(
            sink     = AuditTrail.FileSink(log_path; rotate_daily=false),
            hmac_key = key,
            package  = "RuralCoreTest",
            version  = "0.0.1",
            git_commit = "test-sha",
        )

        @testset "Canonical 4-arg form — happy path" begin
            result = @audited_calculation "unit_test" HIGH "test.add4" begin
                2 + 3
            end
            @test result == 5

            files = filter(f -> startswith(basename(f), "audit.jsonl"),
                           readdir(dir; join=true))
            @test !isempty(files)
            for f in files
                res = AuditTrail.verify_log_file(f; hmac_key=key)
                @test res.valid == res.total
                @test isempty(res.bad_lines)
            end
        end

        @testset "Canonical 4-arg form — error path emits error record and rethrows" begin
            @test_throws ErrorException begin
                @audited_calculation "unit_test" HIGH "test.err4" begin
                    error("deliberate error")
                end
            end
            # Integrity must still hold for the error record
            files = filter(f -> startswith(basename(f), "audit.jsonl"),
                           readdir(dir; join=true))
            for f in files
                res = AuditTrail.verify_log_file(f; hmac_key=key)
                @test res.valid == res.total
            end
        end

        @testset "Legacy 1-arg form — still works, emits deprecation, produces record" begin
            # The @warn at macro expansion does not affect control flow; the
            # runtime behavior must still be correct.
            result = @audited_calculation validate_fips("01001")
            @test result === nothing || isa(result, Bool)  # depends on fn

            # Check last record has intended_use == "legacy" and process_risk == "MEDIUM"
            files = filter(f -> startswith(basename(f), "audit.jsonl"),
                           readdir(dir; join=true))
            @test !isempty(files)
            # Take the most-recently-modified log file
            latest = last(sort(files; by=mtime))
            lines = readlines(latest)
            @test !isempty(lines)
            last_rec = JSON3.read(lines[end], Dict{String, Any})
            @test last_rec["action"]["intended_use"] == "legacy"
            @test last_rec["action"]["process_risk"] == "MEDIUM"
            @test last_rec["action"]["operation"] == "validate_fips"
            @test last_rec["result"] in ("success", "error")
        end

        @testset "Legacy 1-arg — non-call expression gets <expr> operation" begin
            x = 42
            result = @audited_calculation x
            @test result == 42

            files = filter(f -> startswith(basename(f), "audit.jsonl"),
                           readdir(dir; join=true))
            latest = last(sort(files; by=mtime))
            last_rec = JSON3.read(readlines(latest)[end], Dict{String, Any})
            # Symbol expr → operation name is the symbol name, "x"
            @test last_rec["action"]["operation"] in ("x", "<expr>")
        end

        @testset "Tamper detection" begin
            # Emit a clean record, then mutate it in-place in the log file
            @audited_calculation "tamper_test" MEDIUM "test.tamper" begin
                99
            end
            files = filter(f -> startswith(basename(f), "audit.jsonl"),
                           readdir(dir; join=true))
            latest = last(sort(files; by=mtime))
            lines = readlines(latest)
            line = lines[end]
            # Parse, mutate a field, re-serialize with the old HMAC still attached
            d = JSON3.read(line, Dict{String, Any})
            d["action"]["intended_use"] = "TAMPERED"
            tampered = JSON3.write(d)
            @test !AuditTrail.verify_record(tampered; hmac_key=key)
        end

        @testset "Wrong key rejects all records" begin
            bad_key = rand(UInt8, 32)
            files = filter(f -> startswith(basename(f), "audit.jsonl"),
                           readdir(dir; join=true))
            for f in files
                res = AuditTrail.verify_log_file(f; hmac_key=bad_key)
                @test res.valid == 0
                @test length(res.bad_lines) == res.total
            end
        end

        @testset "Actor context propagates into records" begin
            ctx = AuditTrail.AuditContext(
                user_id="thartzog",
                session_id="sess_test_actor",
                role="clinician",
                auth_method="oauth2+totp",
            )
            AuditTrail.with_actor(ctx) do
                @audited_calculation "actor_test" HIGH "test.actor" begin
                    "ok"
                end
            end
            files = filter(f -> startswith(basename(f), "audit.jsonl"),
                           readdir(dir; join=true))
            latest = last(sort(files; by=mtime))
            last_rec = JSON3.read(readlines(latest)[end], Dict{String, Any})
            @test last_rec["actor"]["user_id"] == "thartzog"
            @test last_rec["actor"]["session_id"] == "sess_test_actor"
            @test last_rec["actor"]["role"] == "clinician"
            @test last_rec["actor"]["auth_method"] == "oauth2+totp"
        end

        @testset "Nested calls populate parent_audit_id" begin
            outer = @audited_calculation "outer_use" MEDIUM "test.outer" begin
                inner = @audited_calculation "inner_use" HIGH "test.inner" begin
                    41
                end
                inner + 1
            end
            @test outer == 42
            files = filter(f -> startswith(basename(f), "audit.jsonl"),
                           readdir(dir; join=true))
            latest = last(sort(files; by=mtime))
            all_records = [JSON3.read(l, Dict{String, Any}) for l in readlines(latest)]
            # At least one record should have parent_audit_id populated
            @test any(r -> r["parent_audit_id"] !== nothing, all_records)
        end
    end

    @testset "Legacy AuditEntry API still compiles and functions" begin
        # These are marked deprecated but must remain functional for backward-compat
        clear_audit_log()
        @test get_audit_log() == AuditEntry[]
        mktempdir() do d
            fp = joinpath(d, "legacy.jsonl")
            save_audit_log(fp)
            @test isfile(fp)
        end
    end
end
