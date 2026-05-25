@testset "Auth — RBAC" begin
    policy = default_policy()
    admin = Principal("admin1", "t1", [:admin])
    analyst = Principal("analyst1", "t1", [:analyst])

    @test authorize(admin, :financial, :write, policy).decision == :allow
    @test authorize(admin, :quality, :write, policy).decision == :allow
    @test authorize(analyst, :financial, :read, policy).decision == :allow
    @test check_tenant_isolation(admin, "t1") == true
    @test check_tenant_isolation(admin, "t2") == false
end

@testset "Auth — Electronic Signatures" begin
    using SHA
    key = sha256(Vector{UInt8}("test-key"))
    payload = Vector{UInt8}("test document content")
    sig = sign_document("user1", "Test User", payload, :review, key)
    @test sig.signer_id == "user1"
    @test sig.reason == :review
    @test !isempty(sig.signature_hex)

    verification = verify_signature(sig, payload, key)
    @test verification.valid == true
end

@testset "Compliance — PHI Scrubber" begin
    text = "Patient SSN 123-45-6789, email: test@example.com, phone (555) 123-4567"
    scrubbed = scrub_phi(text)
    @test !contains(scrubbed, "123-45-6789")
    @test !contains(scrubbed, "test@example.com")
    @test contains(scrubbed, "[SSN-REDACTED]") || contains(scrubbed, "REDACTED")

    detections = detect_phi(text)
    @test length(detections) >= 2
end

@testset "Compliance — Hash Chain Audit" begin
    log = create_audit_log()
    append_entry!(log, "admin", "create", "hospital"; detail="Created hospital record")
    append_entry!(log, "analyst", "read", "financial"; detail="Viewed financials")

    @test length(log.entries) == 2
    result = verify_chain_integrity(log)
    @test result.valid == true
end

@testset "Compliance — Encrypted Audit" begin
    passphrase = "test-passphrase-for-audit"
    original = "Sensitive audit entry with PHI"
    payload = encrypt_detail(original, passphrase)
    @test payload isa EncryptedPayload
    decrypted = decrypt_detail(payload, passphrase)
    @test decrypted == original

    log = create_encrypted_audit_log()
    append_encrypted_entry!(log, "admin", "create", "hospital", "Created record", passphrase)
    @test length(log.entries) == 1
end
