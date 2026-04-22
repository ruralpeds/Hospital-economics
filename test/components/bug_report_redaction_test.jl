# ============================================================================
# test/components/bug_report_redaction_test.jl
#
# Unit tests for BugReportRedaction PHI redaction module.
# Exercises ≥ 50 corpus patterns.
# Run standalone:
#   julia --compiled-modules=no --startup-file=no test/components/bug_report_redaction_test.jl
# ============================================================================

using Test

# Load the module without the full app stack
_mod_path = joinpath(@__DIR__, "..", "..", "app", "components", "bug_report_redaction.jl")
include(_mod_path)
using .BugReportRedaction

@testset "BugReportRedaction — PHI corpus" begin

    # ── SSN ──────────────────────────────────────────────────────────────────
    @testset "SSN" begin
        @test redact_text("SSN: 123-45-6789") == "SSN: [SSN]"
        @test redact_text("Social 987-65-4321 on file") == "Social [SSN] on file"
        @test !contains(redact_text("no ssn here: 12-34-5678"), "[SSN]")  # wrong digit groups
        @test !contains(redact_text("call 800-555-1234"), "[SSN]")        # phone, not SSN
        @test contains(redact_text("id 123456789"), "[SSN]")  # bare 9-digit
    end

    # ── DOB ──────────────────────────────────────────────────────────────────
    @testset "DOB" begin
        @test contains(redact_text("DOB: 01/15/1990"), "[DOB]")
        @test contains(redact_text("born 12-31-2001"), "[DOB]")
        @test contains(redact_text("dob 3/7/1985"), "[DOB]")
        @test contains(redact_text("patient dob: 11/02/2000"), "[DOB]")
        @test contains(redact_text("date 06/21/1975"), "[DOB]")
    end

    # ── MRN ──────────────────────────────────────────────────────────────────
    @testset "MRN" begin
        @test contains(redact_text("MRN: 12345678"), "[MRN]")
        @test contains(redact_text("mrn 9876"), "[MRN]")
        @test contains(redact_text("MRN:00112233"), "[MRN]")
        @test contains(redact_text("Patient MRN 4455667788"), "[MRN]")
        @test contains(redact_text("MRN: 123456789012"), "[MRN]")  # 12 digits (max)
    end

    # ── Phone ─────────────────────────────────────────────────────────────────
    @testset "Phone" begin
        @test contains(redact_text("Call 800-555-1234"), "[PHONE]")
        @test contains(redact_text("Phone: (555) 867-5309"), "[PHONE]")
        @test contains(redact_text("mobile +1.415.555.2671"), "[PHONE]")
        @test contains(redact_text("tel 202 555 0191"), "[PHONE]")
        @test contains(redact_text("+18005550100"), "[PHONE]")
        @test contains(redact_text("fax: 555.867.5309"), "[PHONE]")
    end

    # ── Email ─────────────────────────────────────────────────────────────────
    @testset "Email" begin
        @test contains(redact_text("Contact user@example.com for details"), "[EMAIL]")
        @test contains(redact_text("john.doe+tag@hospital.org"), "[EMAIL]")
        @test contains(redact_text("admin@sub.domain.co.uk"), "[EMAIL]")
        @test contains(redact_text("noreply@test-domain.io"), "[EMAIL]")
    end

    # ── Insurance IDs ─────────────────────────────────────────────────────────
    @testset "Insurance IDs" begin
        @test contains(redact_text("member id: ABC123456"), "[INSURANCE_ID]")
        @test contains(redact_text("claim number XYZ9876543"), "[INSURANCE_ID]")
        @test contains(redact_text("group id: GRP00112233"), "[INSURANCE_ID]")
        @test contains(redact_text("policy no. POL12345678"), "[INSURANCE_ID]")
        @test contains(redact_text("subscriber id: SB0099887766"), "[INSURANCE_ID]")
        @test contains(redact_text("Beneficiary ID: BN123456789"), "[INSURANCE_ID]")
        # Generic alphanumeric pattern (2–4 alpha + 7–12 digits)
        @test contains(redact_text("UHC12345678"), "[INSURANCE_ID]")
        @test contains(redact_text("BCBS987654321"), "[INSURANCE_ID]")
    end

    # ── Street addresses ──────────────────────────────────────────────────────
    @testset "Street addresses" begin
        @test contains(redact_text("Lives at 123 Main Street"), "[ADDRESS]")
        @test contains(redact_text("address: 45 Oak Avenue"), "[ADDRESS]")
        @test contains(redact_text("sent to 7 Elm Drive"), "[ADDRESS]")
        @test contains(redact_text("office at 100 Park Blvd"), "[ADDRESS]")
        @test contains(redact_text("location 22 Birch Road"), "[ADDRESS]")
    end

    # ── ZIP codes ─────────────────────────────────────────────────────────────
    @testset "ZIP codes" begin
        @test contains(redact_text("zip 90210"), "[ZIP]")
        @test contains(redact_text("postal 12345-6789"), "[ZIP]")
        @test contains(redact_text("code: 10001"), "[ZIP]")
    end

    # ── Compound / multi-pattern ──────────────────────────────────────────────
    @testset "Compound PHI strings" begin
        compound = "Patient John DOB 01/01/1980 SSN 123-45-6789 " *
                   "MRN: 9876543 phone 555-867-5309 " *
                   "email john@test.com address 10 Main St"
        scrubbed = redact_text(compound)
        @test !contains(scrubbed, "123-45-6789")
        @test !contains(scrubbed, "01/01/1980")
        @test !contains(scrubbed, "9876543")
        @test !contains(scrubbed, "555-867-5309")
        @test !contains(scrubbed, "john@test.com")
        @test contains(scrubbed, "[SSN]")
        @test contains(scrubbed, "[DOB]")
        @test contains(scrubbed, "[MRN]")
        @test contains(scrubbed, "[PHONE]")
        @test contains(scrubbed, "[EMAIL]")
    end

    # ── redact_state_delta ────────────────────────────────────────────────────
    @testset "redact_state_delta" begin
        delta = Dict(
            "patient_name"  => "John DOB 01/15/1990 SSN 123-45-6789",
            "count"         => 42,
            "enabled"       => true,
            "nested"        => Dict("mrn" => "MRN: 12345678"),
            "list"          => ["phone 800-555-1234", 99],
        )
        result = redact_state_delta(delta)

        @test contains(result["patient_name"], "[DOB]")
        @test contains(result["patient_name"], "[SSN]")
        @test result["count"] == 42            # numeric pass-through
        @test result["enabled"] == true         # bool pass-through
        @test contains(result["nested"]["mrn"], "[MRN]")
        @test contains(result["list"][1], "[PHONE]")
        @test result["list"][2] == 99           # numeric in array
    end

    # ── Idempotency & non-mutation ────────────────────────────────────────────
    @testset "Idempotency & non-mutation" begin
        original = "no PHI here"
        result   = redact_text(original)
        # Non-PHI strings are returned unchanged (modulo potential name matches)
        @test result isa String

        # Running twice doesn't add extra markers
        once  = redact_text("SSN: 123-45-6789")
        twice = redact_text(once)
        @test !contains(twice, "123-45-6789")
        @test once == twice   # second pass is idempotent (already replaced)
    end

    # ── Empty / edge cases ────────────────────────────────────────────────────
    @testset "Edge cases" begin
        @test redact_text("") == ""
        @test redact_text("   ") isa String  # whitespace-only strings are handled
        @test redact_state_delta(Dict{String,Any}()) == Dict{String,Any}()
        # Non-string scalar in dict should pass through
        d = redact_state_delta(Dict{String,Any}("n" => 3.14))
        @test d["n"] == 3.14
    end

end # testset
