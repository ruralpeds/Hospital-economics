"""
Electronic signature service for regulatory records (FDA 21 CFR Part 11 §11.50).

Ported from `cah-auth::signature` (Rust). The Rust implementation uses ECDSA-P256;
in pure Julia we use HMAC-SHA256 by default to avoid an OpenSSL/asymmetric-crypto
dependency. The signature wire format (`SignedRecord`) is algorithm-agnostic so
swapping in Ed25519 via `ccall(:EVP_DigestSign*, libcrypto)` is a localised change.

Provides:

* `SignatureService`         -- per-process key registry + sign/verify primitives
* `SignedRecord`             -- the immutable signature artifact (audit-trail unit)
* `ApprovalChain`            -- multi-signer workflow with expiry
* Audit-trail JSON export
"""
module ESignature

using Dates
using Random
using SHA
using JSON3

export SignedRecord, SignatureService, ApprovalChain
export create_signature_service, register_signer!, sign_record, verify_signature
export revoke_signer!, signed_records_for_signer, export_audit_trail
export create_approval_chain, add_signature!, is_approved, pending_signers

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

"""
    SignedRecord

Immutable record of a single electronic signature event.
Mirrors `ElectronicSignature` in the Rust port.
"""
struct SignedRecord
    record_id::String
    content::String
    signer_id::String
    signer_role::String
    signed_at::DateTime
    signature::String          # hex-encoded
    algorithm::String          # "HMAC-SHA256" | "Ed25519"
    certificate_id::String     # optional, may be ""
end

"""
    SignatureService

Per-process registry of signer keys and the audit trail of issued signatures.

* `private_keys` : signer_id -> secret bytes (HMAC key, or Ed25519 private key)
* `public_keys`  : signer_id -> verification material (for HMAC == private key)
* `algorithm`    : default algorithm used by `sign_record`
* `records`      : append-only audit trail of every signature issued
* `revoked`      : signer_id -> reason
* `roles`        : signer_id -> role
* `lock`         : guards mutation under multi-threaded use
"""
mutable struct SignatureService
    private_keys::Dict{String, Vector{UInt8}}
    public_keys::Dict{String, Vector{UInt8}}
    algorithm::String
    records::Vector{SignedRecord}
    revoked::Dict{String, String}
    roles::Dict{String, String}
    lock::ReentrantLock
end

"""
    ApprovalChain

Multi-signer workflow. The chain is `:approved` once every role in
`required_signers` has a matching signature and the chain has not expired.
"""
mutable struct ApprovalChain
    record_id::String
    required_signers::Vector{String}   # role names, e.g. ["CFO", "Compliance Officer"]
    signatures::Vector{SignedRecord}
    status::Symbol                     # :pending | :approved | :rejected | :expired
    expires_at::DateTime
end

# ---------------------------------------------------------------------------
# Construction / signer management
# ---------------------------------------------------------------------------

"""
    create_signature_service(; algorithm="HMAC-SHA256") -> SignatureService

Create an empty service. Supported algorithms: "HMAC-SHA256" (default) and the
string "Ed25519" (reserved -- emits HMAC-SHA256 internally; swap in a real
Ed25519 backend in production).
"""
function create_signature_service(; algorithm::String="HMAC-SHA256")::SignatureService
    return SignatureService(
        Dict{String, Vector{UInt8}}(),
        Dict{String, Vector{UInt8}}(),
        algorithm,
        SignedRecord[],
        Dict{String, String}(),
        Dict{String, String}(),
        ReentrantLock(),
    )
end

"""
    register_signer!(service, signer_id, signer_role; key=nothing)

Generate (or accept) a key for `signer_id` and tag it with `signer_role`.
Returns the public-key material (for HMAC this equals the private key bytes;
the dichotomy exists for forward compatibility with asymmetric algorithms).
"""
function register_signer!(
    service::SignatureService,
    signer_id::AbstractString,
    signer_role::AbstractString;
    key::Union{Nothing, Vector{UInt8}}=nothing,
)::Vector{UInt8}
    lock(service.lock) do
        sid = String(signer_id)
        k = key === nothing ? rand(UInt8, 32) : key
        service.private_keys[sid] = k
        service.public_keys[sid]  = copy(k)   # HMAC: shared secret
        service.roles[sid] = String(signer_role)
        delete!(service.revoked, sid)
        return service.public_keys[sid]
    end
end

"""
    revoke_signer!(service, signer_id, reason)

Mark `signer_id` as revoked. Subsequent `sign_record` calls for that signer
fail; `verify_signature` still works against historical records, but emits a
revocation note via `service.revoked`.
"""
function revoke_signer!(
    service::SignatureService,
    signer_id::AbstractString,
    reason::AbstractString,
)
    lock(service.lock) do
        sid = String(signer_id)
        service.revoked[sid] = String(reason)
        delete!(service.private_keys, sid)
    end
    return nothing
end

# ---------------------------------------------------------------------------
# Signing & verification
# ---------------------------------------------------------------------------

# Internal: compute HMAC-SHA256(key, message) -> hex string
function _hmac_sha256_hex(key::Vector{UInt8}, message::AbstractString)::String
    return bytes2hex(hmac_sha256(key, Vector{UInt8}(codeunits(message))))
end

# Canonical pre-signature payload. Binding signer/role/algo/time
# prevents replay across signers and algorithms.
function _signing_payload(
    record_id::AbstractString,
    content::AbstractString,
    signer_id::AbstractString,
    signer_role::AbstractString,
    algorithm::AbstractString,
    signed_at::DateTime,
)::String
    return string(
        "rec=", record_id,
        "|signer=", signer_id,
        "|role=", signer_role,
        "|alg=", algorithm,
        "|ts=", Dates.format(signed_at, dateformat"yyyy-mm-ddTHH:MM:SS.sss"),
        "|content=", content,
    )
end

"""
    sign_record(service, signer_id, content, signer_role; record_id=nothing) -> SignedRecord

Produce a `SignedRecord` over `content`. The record is also appended to the
service's audit trail.
"""
function sign_record(
    service::SignatureService,
    signer_id::AbstractString,
    content::AbstractString,
    signer_role::AbstractString;
    record_id::Union{Nothing, AbstractString}=nothing,
)::SignedRecord
    return lock(service.lock) do
        sid = String(signer_id)
        haskey(service.revoked, sid) &&
            error("Signer $(sid) is revoked: $(service.revoked[sid])")
        haskey(service.private_keys, sid) ||
            error("Signer $(sid) is not registered")

        rid = record_id === nothing ?
            string("rec-", bytes2hex(rand(UInt8, 8))) :
            String(record_id)
        ts = now(UTC)
        payload = _signing_payload(rid, content, sid, signer_role, service.algorithm, ts)
        sig_hex = _hmac_sha256_hex(service.private_keys[sid], payload)

        rec = SignedRecord(
            rid,
            String(content),
            sid,
            String(signer_role),
            ts,
            sig_hex,
            service.algorithm,
            "",                # certificate_id (unused for HMAC)
        )
        push!(service.records, rec)
        return rec
    end
end

"""
    verify_signature(service, record) -> Bool

Recompute the HMAC and compare in constant time. Returns `false` for unknown
signers or algorithm mismatches.
"""
function verify_signature(service::SignatureService, record::SignedRecord)::Bool
    record.algorithm == service.algorithm || return false
    key = get(service.public_keys, record.signer_id, nothing)
    key === nothing && return false
    payload = _signing_payload(
        record.record_id,
        record.content,
        record.signer_id,
        record.signer_role,
        record.algorithm,
        record.signed_at,
    )
    expected = _hmac_sha256_hex(key, payload)
    return _ct_eq(expected, record.signature)
end

# Constant-time string compare (avoid early-exit timing leak).
function _ct_eq(a::AbstractString, b::AbstractString)::Bool
    length(a) == length(b) || return false
    diff = 0
    for (x, y) in zip(codeunits(a), codeunits(b))
        diff |= xor(x, y)
    end
    return diff == 0
end

# ---------------------------------------------------------------------------
# Queries & audit export
# ---------------------------------------------------------------------------

"""
    signed_records_for_signer(service, signer_id) -> Vector{SignedRecord}
"""
function signed_records_for_signer(
    service::SignatureService,
    signer_id::AbstractString,
)::Vector{SignedRecord}
    sid = String(signer_id)
    return [r for r in service.records if r.signer_id == sid]
end

"""
    export_audit_trail(records, filepath)

Write `records` to `filepath` as a JSON array suitable for long-term audit
retention.
"""
function export_audit_trail(records::Vector{SignedRecord}, filepath::AbstractString)
    payload = [
        Dict(
            "record_id"      => r.record_id,
            "content"        => r.content,
            "signer_id"      => r.signer_id,
            "signer_role"    => r.signer_role,
            "signed_at"      => string(r.signed_at),
            "signature"      => r.signature,
            "algorithm"      => r.algorithm,
            "certificate_id" => r.certificate_id,
        )
        for r in records
    ]
    open(filepath, "w") do io
        JSON3.write(io, payload)
    end
    return filepath
end

# ---------------------------------------------------------------------------
# ApprovalChain
# ---------------------------------------------------------------------------

"""
    create_approval_chain(record_id, required_signers; expires_in_hours=72)
"""
function create_approval_chain(
    record_id::AbstractString,
    required_signers::Vector{<:AbstractString};
    expires_in_hours::Real=72,
)::ApprovalChain
    return ApprovalChain(
        String(record_id),
        String[String(s) for s in required_signers],
        SignedRecord[],
        :pending,
        now(UTC) + Hour(Int(round(expires_in_hours))),
    )
end

"""
    add_signature!(chain, signed_record)

Append `signed_record` to the chain and refresh its status. Raises if the
signature's `record_id` does not match the chain.
"""
function add_signature!(chain::ApprovalChain, signed_record::SignedRecord)
    signed_record.record_id == chain.record_id ||
        error("Signature record_id ($(signed_record.record_id)) does not match chain ($(chain.record_id))")
    push!(chain.signatures, signed_record)
    _refresh_status!(chain)
    return chain
end

function _refresh_status!(chain::ApprovalChain)
    if now(UTC) > chain.expires_at
        chain.status = :expired
        return
    end
    signed_roles = Set(s.signer_role for s in chain.signatures)
    if all(role -> role in signed_roles, chain.required_signers)
        chain.status = :approved
    else
        chain.status = :pending
    end
    return
end

"""
    is_approved(chain) -> Bool

`true` iff every required role has signed and the chain has not expired.
"""
function is_approved(chain::ApprovalChain)::Bool
    _refresh_status!(chain)
    return chain.status == :approved
end

"""
    pending_signers(chain) -> Vector{String}

Roles that still need to sign before the chain can be approved.
"""
function pending_signers(chain::ApprovalChain)::Vector{String}
    signed_roles = Set(s.signer_role for s in chain.signatures)
    return [r for r in chain.required_signers if !(r in signed_roles)]
end

end # module ESignature
