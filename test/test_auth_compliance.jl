using Test
using Dates
using SHA

include(joinpath(@__DIR__, "..", "src", "auth", "rbac.jl"))
include(joinpath(@__DIR__, "..", "src", "auth", "electronic_signatures.jl"))
include(joinpath(@__DIR__, "..", "src", "data_ingestion", "types.jl"))
include(joinpath(@__DIR__, "..", "src", "data_ingestion", "audit_logger.jl"))
include(joinpath(@__DIR__, "..", "src", "data_ingestion", "deidentifiers.jl"))

# ═══════════════════════════════════════════════════════════════
# RBAC — Role-Based Access Control
# ═══════════════════════════════════════════════════════════════

@testset "RBAC — Role-Based Access Control" begin
    @testset "admin gets all permissions" begin
        policy = default_policy()
        admin = Principal("admin1", "tenant_a", [:admin])

        for resource in [:financial, :quality, :clinical, :audit, :simulation]
            for action in [:read, :write, :delete, :execute]
                decision = authorize(admin, resource, action, policy)
                @test decision.decision == :allow
            end
        end
    end

    @testset "analyst gets read-only on financial and quality" begin
        policy = default_policy()
        analyst = Principal("analyst1", "tenant_a", [:analyst])

        @test authorize(analyst, :financial, :read, policy).decision == :allow
        @test authorize(analyst, :quality, :read, policy).decision == :allow
        @test authorize(analyst, :simulation, :execute, policy).decision == :allow

        @test authorize(analyst, :financial, :write, policy).decision == :deny
        @test authorize(analyst, :quality, :write, policy).decision == :deny
        @test authorize(analyst, :clinical, :read, policy).decision == :deny
    end

    @testset "CFO role permissions" begin
        policy = default_policy()
        cfo = Principal("cfo1", "tenant_a", [:cfo])

        @test authorize(cfo, :financial, :read, policy).decision == :allow
        @test authorize(cfo, :financial, :write, policy).decision == :allow
        @test authorize(cfo, :quality, :read, policy).decision == :allow
        @test authorize(cfo, :quality, :write, policy).decision == :deny
        @test authorize(cfo, :clinical, :read, policy).decision == :deny
    end

    @testset "CQO role permissions" begin
        policy = default_policy()
        cqo = Principal("cqo1", "tenant_a", [:cqo])

        @test authorize(cqo, :quality, :read, policy).decision == :allow
        @test authorize(cqo, :quality, :write, policy).decision == :allow
        @test authorize(cqo, :financial, :read, policy).decision == :allow
        @test authorize(cqo, :financial, :write, policy).decision == :deny
    end

    @testset "auditor role permissions" begin
        policy = default_policy()
        auditor = Principal("aud1", "tenant_a", [:auditor])

        @test authorize(auditor, :financial, :read, policy).decision == :allow
        @test authorize(auditor, :quality, :read, policy).decision == :allow
        @test authorize(auditor, :clinical, :read, policy).decision == :allow
        @test authorize(auditor, :audit, :read, policy).decision == :allow
        @test authorize(auditor, :financial, :write, policy).decision == :deny
    end

    @testset "clinician role permissions" begin
        policy = default_policy()
        clinician = Principal("dr1", "tenant_a", [:clinician])

        @test authorize(clinician, :clinical, :read, policy).decision == :allow
        @test authorize(clinician, :clinical, :write, policy).decision == :allow
        @test authorize(clinician, :quality, :read, policy).decision == :allow
        @test authorize(clinician, :financial, :read, policy).decision == :deny
    end

    @testset "viewer — read-only everywhere permitted" begin
        policy = default_policy()
        viewer = Principal("view1", "tenant_a", [:viewer])

        @test authorize(viewer, :financial, :read, policy).decision == :allow
        @test authorize(viewer, :quality, :read, policy).decision == :allow
        @test authorize(viewer, :clinical, :read, policy).decision == :allow
        @test authorize(viewer, :financial, :write, policy).decision == :deny
        @test authorize(viewer, :quality, :write, policy).decision == :deny
    end

    @testset "deny reason includes principal info" begin
        policy = default_policy()
        viewer = Principal("view1", "tenant_a", [:viewer])

        decision = authorize(viewer, :financial, :write, policy)
        @test decision.decision == :deny
        @test contains(decision.reason, "view1")
        @test contains(decision.reason, "viewer")
    end

    @testset "tenant isolation — same tenant" begin
        analyst = Principal("analyst1", "hospital_a", [:analyst])
        @test check_tenant_isolation(analyst, "hospital_a") == true
    end

    @testset "tenant isolation — different tenant denied" begin
        analyst = Principal("analyst1", "hospital_a", [:analyst])
        @test check_tenant_isolation(analyst, "hospital_b") == false
    end

    @testset "admin bypasses tenant isolation" begin
        admin = Principal("admin1", "hospital_a", [:admin])
        @test check_tenant_isolation(admin, "hospital_b") == true
    end

    @testset "multi-role principal gets union of permissions" begin
        policy = default_policy()
        multi = Principal("multi1", "t1", [:analyst, :clinician])

        @test authorize(multi, :financial, :read, policy).decision == :allow   # analyst
        @test authorize(multi, :clinical, :write, policy).decision == :allow   # clinician
        @test authorize(multi, :simulation, :execute, policy).decision == :allow  # analyst
    end

    @testset "invalid role raises error" begin
        @test_throws ErrorException Principal("user1", "t1", [:nonexistent_role])
    end
end

# ═══════════════════════════════════════════════════════════════
# Electronic Signatures — 21 CFR Part 11
# ═══════════════════════════════════════════════════════════════

@testset "Electronic Signatures" begin
    @testset "sign/verify round-trip" begin
        key = Vector{UInt8}("my-secret-signing-key-12345")
        payload = Vector{UInt8}("This is a document to sign.")

        sig = sign_document("user1", "Jane Doe", payload, :approval, key)

        @test sig.signer_id == "user1"
        @test sig.signer_name == "Jane Doe"
        @test sig.reason == :approval
        @test !isempty(sig.payload_hash)
        @test !isempty(sig.signature_hex)
        @test !isempty(sig.certificate_id)

        verification = verify_signature(sig, payload, key)
        @test verification.valid == true
        @test verification.signer_id == "user1"
        @test verification.reason == :approval
        @test contains(verification.message, "valid")
    end

    @testset "verification fails with wrong key" begin
        key = Vector{UInt8}("correct-key-1234567890")
        wrong_key = Vector{UInt8}("wrong-key-9876543210ab")
        payload = Vector{UInt8}("test document")

        sig = sign_document("user1", "Test User", payload, :review, key)
        verification = verify_signature(sig, payload, wrong_key)

        @test verification.valid == false
    end

    @testset "verification fails with modified payload" begin
        key = Vector{UInt8}("secret-key-for-testing")
        original = Vector{UInt8}("original document content")
        modified = Vector{UInt8}("modified document content")

        sig = sign_document("user1", "Test User", original, :authorship, key)
        verification = verify_signature(sig, modified, key)

        @test verification.valid == false
        @test contains(verification.message, "mismatch")
    end

    @testset "all valid signing reasons" begin
        key = Vector{UInt8}("test-key-for-all-reasons")
        payload = Vector{UInt8}("doc")

        for reason in [:review, :approval, :authorship, :attestation]
            sig = sign_document("u1", "Name", payload, reason, key)
            @test sig.reason == reason
            v = verify_signature(sig, payload, key)
            @test v.valid == true
        end
    end

    @testset "invalid signing reason" begin
        @test_throws ErrorException ElectronicSignature(
            "u1", "Name", now(), :invalid_reason, "hash", "sig", "cert")
    end

    @testset "approval chain — pending to complete" begin
        chain = create_approval_chain("DOC-001", [:review, :approval])

        @test chain.document_id == "DOC-001"
        @test chain.status == :pending
        @test isempty(chain.collected_signatures)

        key = Vector{UInt8}("chain-test-key-12345678")
        payload = Vector{UInt8}("document payload")

        sig1 = sign_document("reviewer1", "Reviewer One", payload, :review, key)
        add_signature!(chain, sig1)
        @test chain.status == :pending

        sig2 = sign_document("approver1", "Approver One", payload, :approval, key)
        add_signature!(chain, sig2)
        @test chain.status == :complete
        @test length(chain.collected_signatures) == 2
    end

    @testset "approval chain — partial completion stays pending" begin
        chain = create_approval_chain("DOC-002", [:review, :approval, :attestation])

        key = Vector{UInt8}("partial-chain-key-test")
        payload = Vector{UInt8}("doc content here")

        add_signature!(chain, sign_document("u1", "U1", payload, :review, key))
        @test chain.status == :pending

        add_signature!(chain, sign_document("u2", "U2", payload, :approval, key))
        @test chain.status == :pending
    end

    @testset "approval chain — invalid reason" begin
        @test_throws ErrorException create_approval_chain("DOC-003", [:bogus_reason])
    end

    @testset "deterministic signature for same inputs" begin
        key = Vector{UInt8}("deterministic-test-key!!")
        payload = Vector{UInt8}("same content")

        sig1 = sign_document("u1", "A", payload, :review, key)
        sig2 = sign_document("u1", "A", payload, :review, key)

        @test sig1.payload_hash == sig2.payload_hash
        @test sig1.signature_hex == sig2.signature_hex
    end
end

# ═══════════════════════════════════════════════════════════════
# PHI De-identification — HIPAA Safe Harbor
# ═══════════════════════════════════════════════════════════════

@testset "PHI De-identification" begin
    @testset "pseudonym generation — deterministic" begin
        salt = "HospitalSalt2024"
        p1 = generate_pseudonym("MRN12345", salt)
        p2 = generate_pseudonym("MRN12345", salt)

        @test p1 == p2
        @test length(p1) == 16
        @test all(c -> c in "0123456789abcdef", p1)
    end

    @testset "different patients get different pseudonyms" begin
        salt = "TestSalt"
        p1 = generate_pseudonym("Patient001", salt)
        p2 = generate_pseudonym("Patient002", salt)
        @test p1 != p2
    end

    @testset "different salts produce different pseudonyms" begin
        p1 = generate_pseudonym("MRN001", "SaltA")
        p2 = generate_pseudonym("MRN001", "SaltB")
        @test p1 != p2
    end

    @testset "encounter ID generation" begin
        eid = generate_encounter_id("abc123def456gh78", Date(2024, 3, 15))

        @test contains(eid, "abc123def456gh78")
        @test contains(eid, "20240315")
        @test contains(eid, "_001")
    end

    @testset "ZIP code truncation in deidentified encounter" begin
        raw = Dict{String, Any}(
            "patient_id" => "PAT999",
            "admission_date" => "2024-01-15",
            "discharge_date" => "2024-01-18",
            "zip_code" => "90210",
            "age_at_admission" => 65,
            "dob" => "1959-06-01",
        )
        enc = deidentify_encounter(raw, "test-salt")

        @test length(enc.zip_code_prefix) == 3
        @test enc.zip_code_prefix == "902"
    end

    @testset "age capping at 90 for >89" begin
        raw = Dict{String, Any}(
            "patient_id" => "PAT_OLD",
            "admission_date" => "2024-01-01",
            "discharge_date" => "2024-01-05",
            "age_at_admission" => 95,
            "dob" => "1929-01-01",
        )
        enc = deidentify_encounter(raw, "salt")
        @test enc.age_at_admission == 90
    end

    @testset "validate_deidentification — clean record passes" begin
        raw = Dict{String, Any}(
            "patient_id" => "PAT001",
            "admission_date" => "2024-06-01",
            "discharge_date" => "2024-06-03",
            "age_at_admission" => 55,
            "dob" => "1969-01-01",
            "zip_code" => "12345",
        )
        enc = deidentify_encounter(raw, "salt123")
        is_safe, issues = validate_deidentification(enc)

        @test is_safe == true
        @test isempty(issues)
    end
end

# ═══════════════════════════════════════════════════════════════
# Audit Logging — HIPAA Compliant
# ═══════════════════════════════════════════════════════════════

@testset "Audit Logging" begin
    @testset "log ingestion event" begin
        entry = log_ingestion_event("admin@hospital.org", "INGESTION_START",
                                    "patients_2024.csv"; record_count=5000)

        @test entry.user_id == "admin@hospital.org"
        @test entry.event_type == "INGESTION_START"
        @test entry.resource_id == "patients_2024.csv"
        @test entry.record_count == 5000
        @test entry.status == "SUCCESS"
        @test !isempty(entry.entry_id)
    end

    @testset "log data access" begin
        entry = log_data_access("analyst@hospital.org", "cohort_001", "VIEW")

        @test entry.user_id == "analyst@hospital.org"
        @test entry.action == "VIEW"
        @test entry.event_type == "PHI_ACCESS"
    end

    @testset "log validation error" begin
        entry = log_validation_error("sys", "rec_001", "age", "Age exceeds 150")

        @test entry.status == "FAILED"
        @test entry.event_type == "VALIDATION_ERROR"
        @test haskey(entry.details, "field")
        @test entry.details["field"] == "age"
    end

    @testset "audit log store — append and query" begin
        store = AuditLogStore()
        e1 = log_ingestion_event("u1", "INGESTION_START", "file1.csv")
        e2 = log_data_access("u2", "cohort_1", "EXPORT")
        e3 = log_ingestion_event("u1", "INGESTION_COMPLETE", "file1.csv")

        @test append_log(store, e1) == true
        @test append_log(store, e2) == true
        @test append_log(store, e3) == true
        @test length(store.entries) == 3

        u1_entries = get_audit_entries(store; user_id="u1")
        @test length(u1_entries) == 2

        access_entries = get_audit_entries(store; event_type="PHI_ACCESS")
        @test length(access_entries) == 1
    end

    @testset "audit log store — lock prevents appending" begin
        store = AuditLogStore()
        e1 = log_ingestion_event("u1", "TEST", "file.csv")
        append_log(store, e1)

        lock_audit_log(store)
        e2 = log_ingestion_event("u2", "TEST2", "file2.csv")
        @test append_log(store, e2) == false
        @test length(store.entries) == 1
    end

    @testset "audit log summary" begin
        store = AuditLogStore()
        append_log(store, log_ingestion_event("u1", "INGESTION_START", "f.csv"))
        append_log(store, log_ingestion_event("u1", "INGESTION_COMPLETE", "f.csv"))
        append_log(store, log_data_access("u2", "cohort", "VIEW"))

        summary = audit_log_summary(store)
        @test summary["total_entries"] == 3
        @test haskey(summary, "event_types")
        @test haskey(summary, "users")
    end

    @testset "audit log summary — empty store" begin
        store = AuditLogStore()
        summary = audit_log_summary(store)
        @test summary["total_entries"] == 0
    end
end
