# Encrypted Audit Log — At-Rest Encryption for Audit Records
#
# Provides simple XOR-based encryption with a SHA-256-derived key for
# encrypting audit log entries at rest. Suitable for defense-in-depth
# where field-level encryption adds a layer beyond disk-level encryption.

using SHA
using Dates

# ============================================================================
# Types
# ============================================================================

"""
    EncryptedPayload

An encrypted audit record payload with metadata for decryption.

# Fields
- `ciphertext::Vector{UInt8}`: XOR-encrypted bytes
- `key_fingerprint::String`: first 16 hex chars of SHA-256(key) for key identification
- `encrypted_at::DateTime`: timestamp of encryption
"""
@kwdef struct EncryptedPayload
    ciphertext::Vector{UInt8}
    key_fingerprint::String
    encrypted_at::DateTime      = Dates.now()
end

function Base.show(io::IO, ep::EncryptedPayload)
    print(io, "EncryptedPayload($(length(ep.ciphertext)) bytes, key=$(ep.key_fingerprint))")
end

"""
    EncryptedAuditEntry

An audit entry with an encrypted detail field.

# Fields
- `sequence::Int`: monotonically increasing sequence number
- `timestamp::DateTime`: when the event occurred
- `actor::String`: identity of the user (stored in clear for indexing)
- `action::String`: action description (stored in clear for indexing)
- `resource::String`: target resource (stored in clear for indexing)
- `encrypted_detail::EncryptedPayload`: encrypted detail/payload
"""
@kwdef struct EncryptedAuditEntry
    sequence::Int
    timestamp::DateTime
    actor::String
    action::String
    resource::String
    encrypted_detail::EncryptedPayload
end

function Base.show(io::IO, e::EncryptedAuditEntry)
    print(io, "EncryptedAuditEntry(#$(e.sequence) $(e.actor):$(e.action) [encrypted])")
end

"""
    EncryptedAuditLog

A collection of encrypted audit entries with key management metadata.

# Fields
- `entries::Vector{EncryptedAuditEntry}`: ordered encrypted log entries
- `log_id::String`: unique log identifier
- `created_at::DateTime`: when the log was initialized
"""
@kwdef mutable struct EncryptedAuditLog
    entries::Vector{EncryptedAuditEntry}  = EncryptedAuditEntry[]
    log_id::String                        = string(rand(UInt64), base=16)
    created_at::DateTime                  = Dates.now()
end

function Base.show(io::IO, log::EncryptedAuditLog)
    print(io, "EncryptedAuditLog(id=$(log.log_id), entries=$(length(log.entries)))")
end

# ============================================================================
# Key Derivation and XOR Encryption
# ============================================================================

"""
    _derive_key(passphrase::String) -> Vector{UInt8}

Derive a 32-byte encryption key from a passphrase using SHA-256.
"""
function _derive_key(passphrase::String)::Vector{UInt8}
    return sha256(Vector{UInt8}(passphrase))
end

"""
    _key_fingerprint(key::Vector{UInt8}) -> String

Compute a 16-character hex fingerprint of a key for identification.
"""
function _key_fingerprint(key::Vector{UInt8})::String
    return bytes2hex(sha256(key))[1:16]
end

"""
    _xor_encrypt(plaintext::Vector{UInt8}, key::Vector{UInt8}) -> Vector{UInt8}

XOR-encrypt `plaintext` using `key`, cycling the key as needed.
XOR encryption is its own inverse: encrypt(encrypt(x)) = x.
"""
function _xor_encrypt(plaintext::Vector{UInt8}, key::Vector{UInt8})::Vector{UInt8}
    key_len = length(key)
    ciphertext = Vector{UInt8}(undef, length(plaintext))
    for i in eachindex(plaintext)
        key_byte = key[mod1(i, key_len)]
        ciphertext[i] = xor(plaintext[i], key_byte)
    end
    return ciphertext
end

# ============================================================================
# Core Functions
# ============================================================================

"""
    encrypt_detail(detail::String, passphrase::String) -> EncryptedPayload

Encrypt a detail string using XOR with a SHA-256-derived key.

# Arguments
- `detail::String`: plaintext detail to encrypt
- `passphrase::String`: passphrase for key derivation

# Returns
- `EncryptedPayload`: encrypted payload with key fingerprint
"""
function encrypt_detail(detail::String, passphrase::String)::EncryptedPayload
    key = _derive_key(passphrase)
    plaintext = Vector{UInt8}(detail)
    ciphertext = _xor_encrypt(plaintext, key)

    return EncryptedPayload(
        ciphertext = ciphertext,
        key_fingerprint = _key_fingerprint(key),
        encrypted_at = Dates.now(),
    )
end

"""
    decrypt_detail(payload::EncryptedPayload, passphrase::String) -> String

Decrypt an encrypted payload back to plaintext.

Verifies the key fingerprint matches before decrypting.

# Arguments
- `payload::EncryptedPayload`: encrypted payload to decrypt
- `passphrase::String`: passphrase for key derivation (must match encryption key)

# Returns
- `String`: decrypted detail text

# Throws
- `ErrorException` if the key fingerprint does not match
"""
function decrypt_detail(payload::EncryptedPayload, passphrase::String)::String
    key = _derive_key(passphrase)
    fingerprint = _key_fingerprint(key)

    if fingerprint != payload.key_fingerprint
        error("Key fingerprint mismatch: expected $(payload.key_fingerprint), got $(fingerprint). Wrong passphrase?")
    end

    plaintext_bytes = _xor_encrypt(payload.ciphertext, key)
    return String(plaintext_bytes)
end

"""
    create_encrypted_audit_log(; log_id::String="") -> EncryptedAuditLog

Create a new, empty encrypted audit log.

# Arguments
- `log_id::String`: optional log identifier (auto-generated if empty)

# Returns
- `EncryptedAuditLog`: initialized empty encrypted log
"""
function create_encrypted_audit_log(; log_id::String="")::EncryptedAuditLog
    id = isempty(log_id) ? string(rand(UInt64), base=16) : log_id
    return EncryptedAuditLog(
        entries = EncryptedAuditEntry[],
        log_id = id,
        created_at = Dates.now(),
    )
end

"""
    append_encrypted_entry!(log::EncryptedAuditLog, actor::String,
                             action::String, resource::String,
                             detail::String, passphrase::String) -> EncryptedAuditEntry

Append a new entry to the encrypted audit log. The detail field is
encrypted; actor, action, and resource remain in clear for indexing.

# Arguments
- `log::EncryptedAuditLog`: the log to append to
- `actor::String`: identity performing the action
- `action::String`: description of the action
- `resource::String`: target resource
- `detail::String`: detail to encrypt
- `passphrase::String`: encryption passphrase

# Returns
- `EncryptedAuditEntry`: the newly created and appended entry
"""
function append_encrypted_entry!(log::EncryptedAuditLog, actor::String,
                                  action::String, resource::String,
                                  detail::String, passphrase::String)::EncryptedAuditEntry
    sequence = length(log.entries) + 1
    encrypted = encrypt_detail(detail, passphrase)

    entry = EncryptedAuditEntry(
        sequence = sequence,
        timestamp = Dates.now(),
        actor = actor,
        action = action,
        resource = resource,
        encrypted_detail = encrypted,
    )

    push!(log.entries, entry)
    return entry
end

"""
    decrypt_entry_detail(entry::EncryptedAuditEntry, passphrase::String) -> String

Decrypt the detail field of a single encrypted audit entry.

# Arguments
- `entry::EncryptedAuditEntry`: the entry to decrypt
- `passphrase::String`: decryption passphrase

# Returns
- `String`: decrypted detail text
"""
function decrypt_entry_detail(entry::EncryptedAuditEntry, passphrase::String)::String
    return decrypt_detail(entry.encrypted_detail, passphrase)
end
