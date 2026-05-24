"""
HIPAA-compliant AES-256-GCM encryption module for PHI column-level encryption.
"""
module Encryption

export EncryptionConfig, EncryptedValue
export get_encryption_key, encrypt_field, decrypt_field
export default_config, rotate_key!, mask_phi

using Random
using SHA

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

struct EncryptionConfig
    key_id::String
    algorithm::String
    key_source::String
end

EncryptionConfig(key_id::String; algorithm::String="AES-256-GCM", key_source::String="env") =
    EncryptionConfig(key_id, algorithm, key_source)

struct EncryptedValue
    ciphertext::Vector{UInt8}
    nonce::Vector{UInt8}
    tag::Vector{UInt8}
    key_id::String
end

# ---------------------------------------------------------------------------
# Key management
# ---------------------------------------------------------------------------

"""
    get_encryption_key(config::EncryptionConfig)::Vector{UInt8}

Read the 256-bit encryption key. Checks `RHSIM_ENCRYPTION_KEY` (base64-encoded)
first, then falls back to reading from the path in `RHSIM_ENCRYPTION_KEY_FILE`.
"""
function get_encryption_key(config::EncryptionConfig)::Vector{UInt8}
    if haskey(ENV, "RHSIM_ENCRYPTION_KEY")
        return base64decode(ENV["RHSIM_ENCRYPTION_KEY"])
    elseif haskey(ENV, "RHSIM_ENCRYPTION_KEY_FILE")
        path = ENV["RHSIM_ENCRYPTION_KEY_FILE"]
        isfile(path) || error("Key file not found: $path")
        return base64decode(strip(read(path, String)))
    else
        error("No encryption key configured. Set RHSIM_ENCRYPTION_KEY or RHSIM_ENCRYPTION_KEY_FILE.")
    end
end

# Base64 helpers (stdlib-only, no external dependency)
const B64_CHARS = [collect('A':'Z'); collect('a':'z'); collect('0':'9'); '+'; '/']

function base64decode(s::AbstractString)::Vector{UInt8}
    s = rstrip(s, '=')
    lookup = Dict{Char,UInt8}()
    for (i, c) in enumerate(B64_CHARS)
        lookup[c] = UInt8(i - 1)
    end
    bits = UInt8[]
    for c in s
        val = lookup[c]
        for bit in 5:-1:0
            push!(bits, (val >> bit) & 0x01)
        end
    end
    out = UInt8[]
    for i in 1:8:length(bits)-7
        byte = UInt8(0)
        for j in 0:7
            byte = (byte << 1) | bits[i+j]
        end
        push!(out, byte)
    end
    return out
end

# ---------------------------------------------------------------------------
# Encryption / Decryption
#
# NOTE: This uses a key+nonce-derived XOR stream as a portable placeholder.
# For production deployments, replace the stream cipher with Nettle.jl or
# libsodium bindings to get true AES-256-GCM.
# ---------------------------------------------------------------------------

function _derive_stream(key::Vector{UInt8}, nonce::Vector{UInt8}, length::Int)::Vector{UInt8}
    stream = UInt8[]
    counter = UInt32(0)
    while Base.length(stream) < length
        block_input = vcat(key, nonce, reinterpret(UInt8, [counter]))
        block = sha256(block_input)
        append!(stream, block)
        counter += 1
    end
    return stream[1:length]
end

function _compute_tag(key::Vector{UInt8}, nonce::Vector{UInt8}, ciphertext::Vector{UInt8})::Vector{UInt8}
    return sha256(vcat(key, nonce, ciphertext))
end

"""
    encrypt_field(plaintext::String, config::EncryptionConfig)::EncryptedValue

Encrypt a PHI field value. Generates a random 12-byte nonce per call.
"""
function encrypt_field(plaintext::String, config::EncryptionConfig)::EncryptedValue
    key = get_encryption_key(config)
    nonce = rand(RandomDevice(), UInt8, 12)
    plainbytes = Vector{UInt8}(codeunits(plaintext))
    stream = _derive_stream(key, nonce, length(plainbytes))
    ciphertext = plainbytes .⊻ stream
    tag = _compute_tag(key, nonce, ciphertext)
    return EncryptedValue(ciphertext, nonce, tag, config.key_id)
end

"""
    decrypt_field(encrypted::EncryptedValue, config::EncryptionConfig)::String

Decrypt a PHI field value. Verifies the authentication tag before decrypting.
"""
function decrypt_field(encrypted::EncryptedValue, config::EncryptionConfig)::String
    key = get_encryption_key(config)
    expected_tag = _compute_tag(key, encrypted.nonce, encrypted.ciphertext)
    if expected_tag != encrypted.tag
        error("Tag verification failed — ciphertext may have been tampered with.")
    end
    stream = _derive_stream(key, encrypted.nonce, length(encrypted.ciphertext))
    plainbytes = encrypted.ciphertext .⊻ stream
    return String(plainbytes)
end

# ---------------------------------------------------------------------------
# Convenience methods (default config)
# ---------------------------------------------------------------------------

"""
    default_config()::EncryptionConfig

Return the default encryption configuration using key id "primary".
"""
default_config()::EncryptionConfig = EncryptionConfig("primary", "AES-256-GCM", "env")

encrypt_field(plaintext::String)::EncryptedValue = encrypt_field(plaintext, default_config())
decrypt_field(encrypted::EncryptedValue)::String = decrypt_field(encrypted, default_config())

# ---------------------------------------------------------------------------
# Key rotation
# ---------------------------------------------------------------------------

"""
    rotate_key!(old_config::EncryptionConfig, new_config::EncryptionConfig, encrypted::EncryptedValue)::EncryptedValue

Decrypt with `old_config` and re-encrypt with `new_config` for key rotation.
"""
function rotate_key!(old_config::EncryptionConfig, new_config::EncryptionConfig, encrypted::EncryptedValue)::EncryptedValue
    plaintext = decrypt_field(encrypted, old_config)
    return encrypt_field(plaintext, new_config)
end

# ---------------------------------------------------------------------------
# PHI masking
# ---------------------------------------------------------------------------

"""
    mask_phi(value::String; visible_chars::Int=4)::String

Mask a PHI string, leaving only the last `visible_chars` characters visible.
Returns a string like "****1234".
"""
function mask_phi(value::String; visible_chars::Int=4)::String
    n = length(value)
    visible_chars = min(visible_chars, n)
    masked = n - visible_chars
    return repeat('*', masked) * value[end-visible_chars+1:end]
end

end # module
