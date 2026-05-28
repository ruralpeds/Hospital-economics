# ============================================================================
# Tests for HIPAA PHI scrubber (src/security/phi_scrubber.jl)
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "security", "phi_scrubber.jl"))
using .PhiScrubber

@testset "PHI Scrubber" begin

    @testset "SSN detection and redaction" begin
        text = "Patient SSN is 123-45-6789, alt 987-65-4321"
        r = scrub_phi(text)
        @test r.phi_found
        @test !occursin("123-45-6789", r.scrubbed)
        @test !occursin("987-65-4321", r.scrubbed)
        @test occursin("[REDACTED-SSN]", r.scrubbed)
        @test length(r.redactions) >= 2
    end

    @testset "Email detection" begin
        text = "Contact john.doe@example.com or jane@hospital.org"
        r = scrub_phi(text)
        @test r.phi_found
        @test !occursin("john.doe@example.com", r.scrubbed)
        @test !occursin("jane@hospital.org", r.scrubbed)
        @test occursin("[REDACTED-EMAIL]", r.scrubbed)
    end

    @testset "Phone detection" begin
        for phone in ["555-123-4567", "555.123.4567", "555 123 4567"]
            r = scrub_phi("Call $phone")
            @test r.phi_found
            @test !occursin(phone, r.scrubbed)
            @test occursin("[REDACTED-PHONE]", r.scrubbed)
        end
    end

    @testset "MRN detection (both labeled and alphanumeric)" begin
        r1 = scrub_phi("Pull chart MRN: 12345678")
        @test r1.phi_found
        @test occursin("[REDACTED-MRN]", r1.scrubbed)

        r2 = scrub_phi("Internal code AB1234567")
        @test r2.phi_found
        @test occursin("[REDACTED-MRN]", r2.scrubbed)
    end

    @testset "Date detection (DOB)" begin
        for d in ["01/15/1980", "1-2-99", "12/31/2024"]
            r = scrub_phi("DOB $d")
            @test r.phi_found
            @test !occursin(d, r.scrubbed)
        end
    end

    @testset "ZIP code -- 5-digit but not 3-digit" begin
        r5 = scrub_phi("ZIP 67530")
        @test r5.phi_found
        @test occursin("[REDACTED-ZIP]", r5.scrubbed)
        # 3-digit prefix is permitted by Safe Harbor
        r3 = scrub_phi("Prefix 675 only")
        @test !r3.phi_found
    end

    @testset "URLs and IPs" begin
        @test scrub_phi("see https://hospital.example.com/x?y=1").phi_found
        @test scrub_phi("from 192.168.1.50 today").phi_found
        @test scrub_phi("from 2001:db8::1 today").phi_found
    end

    @testset "MBI -- Medicare Beneficiary Identifier" begin
        r = scrub_phi("MBI 1A2B3C4DE56")  # canonical 11-char MBI shape
        @test r.phi_found
        @test occursin("[REDACTED-MBI]", r.scrubbed)
    end

    @testset "phi_safe and detect_phi" begin
        @test phi_safe("This text has no identifiers at all.")
        @test !phi_safe("SSN 111-22-3333")

        found = detect_phi("Email a@b.co and SSN 111-22-3333")
        @test length(found) >= 2
        @test any(f -> f.pattern == "SSN", found)
        @test any(f -> f.pattern == "Email", found)
        @test all(f -> haskey(f, :start) && haskey(f, :length), found)
    end

    @testset "scrub_dict recursive" begin
        d = Dict(
            "note" => "SSN 111-22-3333",
            "nested" => Dict("phone" => "555-123-4567"),
            "list" => ["clean", "email me at x@y.com"],
            "n" => 42,
        )
        out = scrub_dict(d)
        @test !occursin("111-22-3333", out["note"])
        @test !occursin("555-123-4567", out["nested"]["phone"])
        @test !occursin("x@y.com", out["list"][2])
        @test out["n"] == 42
    end

    @testset "scrub_log_message returns plain string" begin
        s = scrub_log_message("user SSN=123-45-6789 logged in")
        @test s isa String
        @test !occursin("123-45-6789", s)
    end

    @testset "add_custom_pattern!" begin
        custom = copy(HIPAA_PHI_PATTERNS)
        add_custom_pattern!(
            custom,
            "BadgeID",
            r"\bBADGE-\d{4}\b",
            "[REDACTED-BADGE]",
            :direct_identifier,
        )
        @test custom[end].name == "BadgeID"
        r = scrub_phi("user BADGE-1234 entered"; patterns=custom)
        @test r.phi_found
        @test occursin("[REDACTED-BADGE]", r.scrubbed)
        # Default pattern list unchanged
        @test length(HIPAA_PHI_PATTERNS) < length(custom)
    end

    @testset "ScrubResult invariants" begin
        text = "no phi here"
        r = scrub_phi(text)
        @test r.original == text
        @test r.scrubbed == text
        @test !r.phi_found
        @test isempty(r.redactions)
    end
end
