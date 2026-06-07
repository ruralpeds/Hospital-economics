# ============================================================================
# Tests for electronic signature service (src/security/esignature.jl)
# ============================================================================

using Test
using Dates
using JSON3

include(joinpath(@__DIR__, "..", "src", "security", "esignature.jl"))
using .ESignature

@testset "Electronic Signatures" begin

    @testset "Service creation and signer registration" begin
        svc = create_signature_service()
        @test svc.algorithm == "HMAC-SHA256"
        @test isempty(svc.records)

        pub = register_signer!(svc, "user-001", "CFO")
        @test pub isa Vector{UInt8}
        @test haskey(svc.private_keys, "user-001")
        @test haskey(svc.public_keys, "user-001")
        @test svc.roles["user-001"] == "CFO"
    end

    @testset "Sign and verify happy path" begin
        svc = create_signature_service()
        register_signer!(svc, "user-001", "CFO")
        rec = sign_record(svc, "user-001", "Q4 financial close", "CFO")
        @test rec.signer_id == "user-001"
        @test rec.signer_role == "CFO"
        @test rec.content == "Q4 financial close"
        @test !isempty(rec.signature)
        @test rec.algorithm == "HMAC-SHA256"
        @test verify_signature(svc, rec)
    end

    @testset "Verify fails on content tampering" begin
        svc = create_signature_service()
        register_signer!(svc, "u1", "CFO")
        rec = sign_record(svc, "u1", "approved", "CFO")
        tampered = SignedRecord(
            rec.record_id, "denied", rec.signer_id, rec.signer_role,
            rec.signed_at, rec.signature, rec.algorithm, rec.certificate_id,
        )
        @test !verify_signature(svc, tampered)
    end

    @testset "Verify fails for unknown signer" begin
        svc1 = create_signature_service()
        register_signer!(svc1, "u1", "CFO")
        rec = sign_record(svc1, "u1", "doc", "CFO")
        svc2 = create_signature_service()
        @test !verify_signature(svc2, rec)
    end

    @testset "Custom record_id" begin
        svc = create_signature_service()
        register_signer!(svc, "u1", "CFO")
        rec = sign_record(svc, "u1", "doc", "CFO"; record_id="REC-2026-001")
        @test rec.record_id == "REC-2026-001"
        @test verify_signature(svc, rec)
    end

    @testset "Revoke signer" begin
        svc = create_signature_service()
        register_signer!(svc, "u1", "CFO")
        sign_record(svc, "u1", "before-revoke", "CFO")
        revoke_signer!(svc, "u1", "left organization")
        @test haskey(svc.revoked, "u1")
        @test_throws ErrorException sign_record(svc, "u1", "after-revoke", "CFO")
    end

    @testset "signed_records_for_signer" begin
        svc = create_signature_service()
        register_signer!(svc, "u1", "CFO")
        register_signer!(svc, "u2", "Compliance Officer")
        sign_record(svc, "u1", "doc-a", "CFO")
        sign_record(svc, "u1", "doc-b", "CFO")
        sign_record(svc, "u2", "doc-c", "Compliance Officer")
        @test length(signed_records_for_signer(svc, "u1")) == 2
        @test length(signed_records_for_signer(svc, "u2")) == 1
        @test isempty(signed_records_for_signer(svc, "u3"))
    end

    @testset "export_audit_trail JSON" begin
        svc = create_signature_service()
        register_signer!(svc, "u1", "CFO")
        sign_record(svc, "u1", "doc-1", "CFO")
        path = tempname() * ".json"
        export_audit_trail(svc.records, path)
        @test isfile(path)
        data = JSON3.read(read(path, String))
        @test length(data) == 1
        @test data[1].signer_id == "u1"
        @test data[1].signer_role == "CFO"
    end

    @testset "ApprovalChain basic workflow" begin
        svc = create_signature_service()
        register_signer!(svc, "cfo-1", "CFO")
        register_signer!(svc, "comp-1", "Compliance Officer")

        rid = "POLICY-2026-001"
        chain = create_approval_chain(rid, ["CFO", "Compliance Officer"])
        @test chain.status == :pending
        @test Set(pending_signers(chain)) == Set(["CFO", "Compliance Officer"])

        sig1 = sign_record(svc, "cfo-1", "policy text", "CFO"; record_id=rid)
        add_signature!(chain, sig1)
        @test !is_approved(chain)
        @test pending_signers(chain) == ["Compliance Officer"]

        sig2 = sign_record(svc, "comp-1", "policy text", "Compliance Officer"; record_id=rid)
        add_signature!(chain, sig2)
        @test is_approved(chain)
        @test chain.status == :approved
        @test isempty(pending_signers(chain))
    end

    @testset "ApprovalChain expiry" begin
        chain = create_approval_chain("R1", ["CFO"]; expires_in_hours=72)
        @test chain.expires_at > now(UTC)
        # Force expiry
        chain.expires_at = now(UTC) - Hour(1)
        @test !is_approved(chain)
        @test chain.status == :expired
    end

    @testset "ApprovalChain rejects mismatched record_id" begin
        svc = create_signature_service()
        register_signer!(svc, "u1", "CFO")
        chain = create_approval_chain("R1", ["CFO"])
        bad = sign_record(svc, "u1", "doc", "CFO"; record_id="R2")
        @test_throws ErrorException add_signature!(chain, bad)
    end
end
