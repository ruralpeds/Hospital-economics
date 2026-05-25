# Hash Chain Audit Log — Tamper-Evident Audit Trail
#
# Implements a SHA-256 hash chain for immutable audit logging. Each entry's
# hash incorporates the previous entry's hash, forming a linked chain that
# detects any retroactive modification of the log.

using SHA
using Dates

# ============================================================================
# Types
# ============================================================================

"""
    AuditEntry

A single entry in the hash-chain audit log.

# Fields
- `sequence::Int`: monotonically increasing sequence number
- `timestamp::DateTime`: when the event occurred
- `actor::String`: identity of the user or system performing the action
- `action::String`: description of the action taken
- `resource::String`: target resource identifier
- `detail::String`: additional context or payload
- `prev_hash::String`: SHA-256 hex digest of the previous entry (empty for first entry)
- `entry_hash::String`: SHA-256 hex digest of this entry's content + prev_hash
"""
@kwdef struct AuditEntry
    sequence::Int
    timestamp::DateTime
    actor::String
    action::String
    resource::String
    detail::String              = ""
    prev_hash::String           = ""
    entry_hash::String
end

function Base.show(io::IO, e::AuditEntry)
    print(io, "AuditEntry(#$(e.sequence) $(e.actor):$(e.action) on $(e.resource) @ $(e.timestamp))")
end

"""
    HashChainAuditLog

An append-only audit log secured by a SHA-256 hash chain.

# Fields
- `entries::Vector{AuditEntry}`: ordered log entries
- `log_id::String`: unique identifier for this audit log
- `created_at::DateTime`: when the log was initialized
"""
@kwdef mutable struct HashChainAuditLog
    entries::Vector{AuditEntry}  = AuditEntry[]
    log_id::String               = string(rand(UInt64), base=16)
    created_at::DateTime         = Dates.now()
end

function Base.show(io::IO, log::HashChainAuditLog)
    print(io, "HashChainAuditLog(id=$(log.log_id), entries=$(length(log.entries)))")
end

# ============================================================================
# Hash Computation
# ============================================================================

"""
    _compute_entry_hash(sequence::Int, timestamp::DateTime, actor::String,
                         action::String, resource::String, detail::String,
                         prev_hash::String) -> String

Compute the SHA-256 hex digest for an audit entry by concatenating all
fields with a pipe delimiter.
"""
function _compute_entry_hash(sequence::Int, timestamp::DateTime, actor::String,
                              action::String, resource::String, detail::String,
                              prev_hash::String)::String
    content = join([
        string(sequence),
        string(timestamp),
        actor,
        action,
        resource,
        detail,
        prev_hash,
    ], "|")
    return bytes2hex(sha256(Vector{UInt8}(content)))
end

# ============================================================================
# Core Functions
# ============================================================================

"""
    create_audit_log(; log_id::String="") -> HashChainAuditLog

Create a new, empty hash-chain audit log.

# Arguments
- `log_id::String`: optional log identifier (auto-generated if empty)

# Returns
- `HashChainAuditLog`: initialized empty log
"""
function create_audit_log(; log_id::String="")::HashChainAuditLog
    id = isempty(log_id) ? string(rand(UInt64), base=16) : log_id
    return HashChainAuditLog(
        entries = AuditEntry[],
        log_id = id,
        created_at = Dates.now(),
    )
end

"""
    append_entry!(log::HashChainAuditLog, actor::String, action::String,
                   resource::String; detail::String="") -> AuditEntry

Append a new entry to the audit log. The entry's hash is computed from its
content and the previous entry's hash, forming the chain link.

# Arguments
- `log::HashChainAuditLog`: the audit log to append to
- `actor::String`: identity performing the action
- `action::String`: description of the action
- `resource::String`: target resource
- `detail::String`: optional additional detail

# Returns
- `AuditEntry`: the newly created and appended entry
"""
function append_entry!(log::HashChainAuditLog, actor::String, action::String,
                        resource::String; detail::String="")::AuditEntry
    sequence = length(log.entries) + 1
    timestamp = Dates.now()

    prev_hash = if isempty(log.entries)
        ""
    else
        log.entries[end].entry_hash
    end

    entry_hash = _compute_entry_hash(sequence, timestamp, actor, action,
                                      resource, detail, prev_hash)

    entry = AuditEntry(
        sequence = sequence,
        timestamp = timestamp,
        actor = actor,
        action = action,
        resource = resource,
        detail = detail,
        prev_hash = prev_hash,
        entry_hash = entry_hash,
    )

    push!(log.entries, entry)
    return entry
end

"""
    verify_chain_integrity(log::HashChainAuditLog) -> NamedTuple

Verify the integrity of the entire hash chain by recomputing each entry's
hash and checking prev_hash linkage.

Returns a NamedTuple with:
- `valid::Bool`: `true` if the entire chain is intact
- `entries_checked::Int`: number of entries verified
- `first_failure::Union{Nothing,Int}`: sequence number of first integrity failure, or `nothing`
- `message::String`: human-readable summary
"""
function verify_chain_integrity(log::HashChainAuditLog)
    if isempty(log.entries)
        return (valid=true, entries_checked=0, first_failure=nothing,
                message="Empty log — no entries to verify")
    end

    for (i, entry) in enumerate(log.entries)
        # Check prev_hash linkage
        expected_prev = if i == 1
            ""
        else
            log.entries[i-1].entry_hash
        end

        if entry.prev_hash != expected_prev
            return (valid=false, entries_checked=i, first_failure=entry.sequence,
                    message="Chain broken at entry #$(entry.sequence): prev_hash mismatch")
        end

        # Recompute hash and compare
        computed = _compute_entry_hash(
            entry.sequence, entry.timestamp, entry.actor, entry.action,
            entry.resource, entry.detail, entry.prev_hash,
        )

        if computed != entry.entry_hash
            return (valid=false, entries_checked=i, first_failure=entry.sequence,
                    message="Hash mismatch at entry #$(entry.sequence): content may have been tampered")
        end
    end

    n = length(log.entries)
    return (valid=true, entries_checked=n, first_failure=nothing,
            message="All $(n) entries verified — chain integrity intact")
end
