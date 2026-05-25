"""
    electronic_signatures.jl

Electronic Signatures per 21 CFR Part 11 compliance.

Provides HMAC-SHA256-based signing and verification for document approval
workflows. Implements:
- Signer identity binding (signer_id, signer_name per 11.50(a)(1))
- Timestamp recording (per 11.50(a)(2))
- Signing reason/meaning (per 11.50(a)(3))
- Payload integrity via cryptographic hash
- Multi-signature approval chains with required-reason tracking

Based on cah-modeling ECDSA signature service, adapted for Julia stdlib
using HMAC-SHA256 (SHA is in stdlib; no external crypto library needed).
"""

using Dates
using SHA

# ============================================================================
# SIGNING REASONS
# ============================================================================

"""
Valid signing reasons per 21 CFR Part 11 section 11.50(a)(3):
- `:review` — reviewed the document
- `:approval` — approved the document
- `:authorship` — authored the document
- `:attestation` — attested to accuracy
"""
const VALID_SIGNING_REASONS = [:review, :approval, :authorship, :attestation]

# ============================================================================
# TYPES
# ============================================================================

"""
    ElectronicSignature

A single electronic signature per 21 CFR Part 11 section 11.50.

# Fields
- `signer_id::String`: Unique signer identifier (11.50(a)(1))
- `signer_name::String`: Printed name of the signer (11.50(a)(1))
- `timestamp::DateTime`: Date and time of signing (11.50(a)(2))
- `reason::Symbol`: Meaning of the signature (11.50(a)(3))
- `payload_hash::String`: SHA-256 hex digest of the signed payload
- `signature_hex::String`: HMAC-SHA256 hex digest (signature value)
- `certificate_id::String`: Identifier for the signing key/certificate
"""
struct ElectronicSignature
    signer_id::String
    signer_name::String
    timestamp::DateTime
    reason::Symbol
    payload_hash::String
    signature_hex::String
    certificate_id::String

    function ElectronicSignature(signer_id, signer_name, timestamp, reason,
                                  payload_hash, signature_hex, certificate_id)
        if reason ∉ VALID_SIGNING_REASONS
            error("Invalid signing reason: $reason. Valid: $VALID_SIGNING_REASONS")
        end
        new(signer_id, signer_name, timestamp, reason,
            payload_hash, signature_hex, certificate_id)
    end
end

"""
    SignatureVerification

Result of verifying an electronic signature.

# Fields
- `valid::Bool`: Whether the signature is cryptographically valid
- `signer_id::String`: Signer from the signature being verified
- `timestamp::DateTime`: Timestamp from the signature
- `reason::Symbol`: Signing reason from the signature
- `message::String`: Human-readable verification result message
"""
struct SignatureVerification
    valid::Bool
    signer_id::String
    timestamp::DateTime
    reason::Symbol
    message::String
end

"""
    ApprovalChain

Multi-signature approval workflow for a document.

Tracks required signing reasons and collected signatures. Status transitions:
- `:pending` — waiting for signatures
- `:complete` — all required reasons have been signed

# Fields
- `document_id::String`: Identifier of the document being approved
- `required_signatures::Vector{Symbol}`: Signing reasons required to complete
- `collected_signatures::Vector{ElectronicSignature}`: Signatures collected so far
- `status::Symbol`: Current chain status (`:pending` or `:complete`)
"""
mutable struct ApprovalChain
    document_id::String
    required_signatures::Vector{Symbol}
    collected_signatures::Vector{ElectronicSignature}
    status::Symbol

    function ApprovalChain(document_id, required_signatures, collected_signatures, status)
        new(document_id, required_signatures, collected_signatures, status)
    end
end

# ============================================================================
# SIGNING & VERIFICATION
# ============================================================================

"""
    sign_document(signer_id::String, signer_name::String,
                  payload::Vector{UInt8}, reason::Symbol,
                  private_key::Vector{UInt8})::ElectronicSignature

Create an HMAC-SHA256 electronic signature over `payload`.

The signing process:
1. Compute SHA-256 digest of the payload
2. Build a signing message: `payload_hash * "|" * signer_id * "|" * string(reason)`
3. Compute HMAC-SHA256 of the signing message using `private_key`
4. Derive a certificate_id from SHA-256 of the key

# Arguments
- `signer_id::String`: Unique signer identifier
- `signer_name::String`: Human-readable signer name
- `payload::Vector{UInt8}`: Document bytes to sign
- `reason::Symbol`: One of `VALID_SIGNING_REASONS`
- `private_key::Vector{UInt8}`: Shared secret key for HMAC

# Returns
- `ElectronicSignature`: The completed signature
"""
function sign_document(signer_id::String, signer_name::String,
                       payload::Vector{UInt8}, reason::Symbol,
                       private_key::Vector{UInt8})::ElectronicSignature
    # 1. Hash the payload
    payload_hash = bytes2hex(sha256(payload))

    # 2. Build signing message: payload_hash | signer_id | reason
    signing_message = payload_hash * "|" * signer_id * "|" * string(reason)

    # 3. Compute HMAC-SHA256
    sig_bytes = hmac_sha256(private_key, Vector{UInt8}(signing_message))
    signature_hex = bytes2hex(sig_bytes)

    # 4. Certificate ID from key fingerprint
    certificate_id = bytes2hex(sha256(private_key))[1:16]

    return ElectronicSignature(
        signer_id,
        signer_name,
        now(),
        reason,
        payload_hash,
        signature_hex,
        certificate_id,
    )
end

"""
    verify_signature(sig::ElectronicSignature, payload::Vector{UInt8},
                     public_key::Vector{UInt8})::SignatureVerification

Verify an electronic signature against the original payload.

Recomputes the HMAC-SHA256 and compares to the stored signature.
For HMAC-based signatures, `public_key` is the same shared secret used to sign.

# Arguments
- `sig::ElectronicSignature`: Signature to verify
- `payload::Vector{UInt8}`: Original document bytes
- `public_key::Vector{UInt8}`: Shared secret key (same as signing key for HMAC)

# Returns
- `SignatureVerification`: Verification result with validity flag and message
"""
function verify_signature(sig::ElectronicSignature, payload::Vector{UInt8},
                          public_key::Vector{UInt8})::SignatureVerification
    # 1. Recompute payload hash
    payload_hash = bytes2hex(sha256(payload))

    # Check payload hash matches
    if payload_hash != sig.payload_hash
        return SignatureVerification(
            false, sig.signer_id, sig.timestamp, sig.reason,
            "Payload hash mismatch: document has been modified"
        )
    end

    # 2. Recompute HMAC
    signing_message = payload_hash * "|" * sig.signer_id * "|" * string(sig.reason)
    expected_sig = bytes2hex(hmac_sha256(public_key, Vector{UInt8}(signing_message)))

    # 3. Compare
    if expected_sig != sig.signature_hex
        return SignatureVerification(
            false, sig.signer_id, sig.timestamp, sig.reason,
            "Signature verification failed: HMAC mismatch"
        )
    end

    # 4. Check certificate ID
    expected_cert_id = bytes2hex(sha256(public_key))[1:16]
    if expected_cert_id != sig.certificate_id
        return SignatureVerification(
            false, sig.signer_id, sig.timestamp, sig.reason,
            "Certificate ID mismatch"
        )
    end

    return SignatureVerification(
        true, sig.signer_id, sig.timestamp, sig.reason,
        "Signature valid: signed by $(sig.signer_name) for $(sig.reason) at $(sig.timestamp)"
    )
end

# ============================================================================
# APPROVAL CHAINS
# ============================================================================

"""
    create_approval_chain(document_id::String,
                          required_reasons::Vector{Symbol})::ApprovalChain

Initialize a new approval chain requiring signatures for each listed reason.

# Arguments
- `document_id::String`: Identifier for the document
- `required_reasons::Vector{Symbol}`: Signing reasons that must be collected

# Returns
- `ApprovalChain` with status `:pending`
"""
function create_approval_chain(document_id::String,
                               required_reasons::Vector{Symbol})::ApprovalChain
    for r in required_reasons
        if r ∉ VALID_SIGNING_REASONS
            error("Invalid signing reason: $r. Valid: $VALID_SIGNING_REASONS")
        end
    end
    return ApprovalChain(document_id, required_reasons, ElectronicSignature[], :pending)
end

"""
    add_signature!(chain::ApprovalChain, sig::ElectronicSignature)

Add a signature to the approval chain.

If, after adding, all required reasons have at least one signature,
the chain status is updated to `:complete`.

# Arguments
- `chain::ApprovalChain`: The approval chain to update
- `sig::ElectronicSignature`: The signature to add
"""
function add_signature!(chain::ApprovalChain, sig::ElectronicSignature)
    push!(chain.collected_signatures, sig)

    # Check if all required reasons are now covered
    covered_reasons = Set(s.reason for s in chain.collected_signatures)
    required_set = Set(chain.required_signatures)

    if issubset(required_set, covered_reasons)
        chain.status = :complete
    end
end
