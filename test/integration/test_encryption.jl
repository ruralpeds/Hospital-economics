"""
Integration tests for the encryption module (P0-2).
Tests field-level encryption, decryption, key rotation, and PHI masking.
"""
using Test
using Base64

include(joinpath(@__DIR__, "..", "..", "src", "security", "encryption.jl"))
using .Encryption

@testset "Encryption — Round-trip" begin
    withenv("RHSIM_ENCRYPTION_KEY" => base64encode(rand(UInt8, 32))) do
        config = Encryption.default_config()

        plaintext = "Patient: John Doe, SSN: 123-45-6789"
        encrypted = Encryption.encrypt_field(plaintext, config)

        @test encrypted isa Encryption.EncryptedValue
        @test length(encrypted.nonce) == 12
        @test !isempty(encrypted.ciphertext)
        @test !isempty(encrypted.tag)
        @test encrypted.key_id == "primary"

        decrypted = Encryption.decrypt_field(encrypted, config)
        @test decrypted == plaintext
    end
end

@testset "Encryption — Convenience Methods" begin
    withenv("RHSIM_ENCRYPTION_KEY" => base64encode(rand(UInt8, 32))) do
        original = "Sensitive medical record data"
        enc = Encryption.encrypt_field(original)
        dec = Encryption.decrypt_field(enc)
        @test dec == original
    end
end

@testset "Encryption — Different Plaintexts Produce Different Ciphertexts" begin
    withenv("RHSIM_ENCRYPTION_KEY" => base64encode(rand(UInt8, 32))) do
        enc1 = Encryption.encrypt_field("message one")
        enc2 = Encryption.encrypt_field("message one")
        @test enc1.nonce != enc2.nonce
        @test enc1.ciphertext != enc2.ciphertext
    end
end

@testset "Encryption — Tampered Ciphertext Fails Verification" begin
    withenv("RHSIM_ENCRYPTION_KEY" => base64encode(rand(UInt8, 32))) do
        enc = Encryption.encrypt_field("do not tamper")
        tampered = Encryption.EncryptedValue(
            reverse(enc.ciphertext), enc.nonce, enc.tag, enc.key_id)
        @test_throws Exception Encryption.decrypt_field(tampered)
    end
end

@testset "Encryption — Key Rotation" begin
    old_key = base64encode(rand(UInt8, 32))
    new_key = base64encode(rand(UInt8, 32))

    withenv("RHSIM_ENCRYPTION_KEY" => old_key) do
        old_config = Encryption.EncryptionConfig(key_id="old_key")
        plaintext = "PHI data to rotate"
        encrypted = Encryption.encrypt_field(plaintext, old_config)

        withenv("RHSIM_ENCRYPTION_KEY" => new_key) do
            new_config = Encryption.EncryptionConfig(key_id="new_key")

            withenv("RHSIM_ENCRYPTION_KEY" => old_key) do
                rotated = Encryption.rotate_key!(old_config, new_config, encrypted)
                @test rotated.key_id == "new_key"

                withenv("RHSIM_ENCRYPTION_KEY" => new_key) do
                    decrypted = Encryption.decrypt_field(rotated, new_config)
                    @test decrypted == plaintext
                end
            end
        end
    end
end

@testset "Encryption — Missing Key Raises Error" begin
    withenv("RHSIM_ENCRYPTION_KEY" => nothing, "RHSIM_ENCRYPTION_KEY_FILE" => nothing) do
        config = Encryption.default_config()
        @test_throws Exception Encryption.get_encryption_key(config)
    end
end

@testset "Encryption — PHI Masking" begin
    @test Encryption.mask_phi("123-45-6789") == "*******6789"
    @test Encryption.mask_phi("123-45-6789"; visible_chars=2) == "*********89"
    @test Encryption.mask_phi("ab") == "ab"
    @test Encryption.mask_phi("") == ""
end
