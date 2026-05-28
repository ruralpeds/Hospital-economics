"""
    hash_chain_audit.jl

Hash-chained, tamper-evident audit log for 21 CFR Part 11 §11.10(e) and
HIPAA §164.312(b)(c) compliance.

Each [`HashChainedEntry`] embeds the SHA-256 hex digest of its predecessor in
`prev_hash` and its own SHA-256 hex digest (computed over a canonical, key-sorted
JSON serialization of every field except `entry_hash`) in `entry_hash`. Any
edit, reorder, or deletion of a previously persisted entry breaks the chain and
is detected by [`verify_chain`].

This module is the Julia equivalent of the Rust
`cah_validation::audit_log::PersistentAuditLog`. It complements the existing
in-memory `AuditLogStore` (see `src/data_ingestion/audit_logger.jl`) by adding
durability and cross-run integrity verification.

Persistence is JSONL (one entry per line) under a `ReentrantLock` for thread
safety. The first entry's `prev_hash` is the literal sentinel returned by
`genesis_sentinel()` (64 "0" characters by default).
"""

using Dates
using SHA
using JSON3

# ============================================================================
# TYPES
# ============================================================================

"""
    HashChainedEntry

One immutable record in the hash-chained audit log.

# Fields
- `index::Int`: sequential, starts at 0
- `timestamp::DateTime`: UTC instant the event was appended
- `event_type::String`: free-form event name (e.g. "PHI_ACCESS")
- `user_id::String`: identity of the actor
- `resource::String`: opaque resource identifier
- `action::String`: action performed (e.g. "VIEW", "EXPORT")
- `details::Dict{String,Any}`: arbitrary structured context
- `prev_hash::String`: hex SHA-256 of the previous entry's `entry_hash`,
  or the genesis sentinel for `index == 0`
- `entry_hash::String`: hex SHA-256 of this entry's canonical serialization
"""
struct HashChainedEntry
    index::Int
    timestamp::DateTime
    event_type::String
    user_id::String
    resource::String
    action::String
    details::Dict{String, Any}
    prev_hash::String
    entry_hash::String
end

"""
    HashChainedLog

File-backed hash-chained audit log with thread-safe append.

# Fields
- `entries::Vector{HashChainedEntry}`: in-memory replay of the chain
- `lock::ReentrantLock`: serializes mutating operations
- `log_path::String`: JSONL file used for durable persistence
- `genesis_hash::String`: sentinel used as `prev_hash` for index 0
"""
mutable struct HashChainedLog
    entries::Vector{HashChainedEntry}
    lock::ReentrantLock
    log_path::String
    genesis_hash::String

    function HashChainedLog(log_path::String = ""; genesis_hash::String = "0"^64)
        new(Vector{HashChainedEntry}(), ReentrantLock(), log_path, genesis_hash)
    end
end

# ============================================================================
# CANONICAL SERIALIZATION
# ============================================================================

"""
    canonical_json(v)::String

Deterministic JSON-style serialization with object keys sorted lexicographically
at every depth. This guarantees byte-for-byte stability of the hash input across
runs, platforms, and language implementations.
"""
function canonical_json(v)::String
    if v === nothing || ismissing(v)
        return "null"
    elseif v isa Bool
        return v ? "true" : "false"
    elseif v isa Integer
        return string(v)
    elseif v isa AbstractFloat
        if isnan(v) || isinf(v)
            return "null"
        end
        return string(v)
    elseif v isa AbstractString
        return JSON3.write(String(v))
    elseif v isa DateTime
        return JSON3.write(Dates.format(v, dateformat"yyyy-mm-ddTHH:MM:SS.sss"))
    elseif v isa Date
        return JSON3.write(Dates.format(v, dateformat"yyyy-mm-dd"))
    elseif v isa AbstractDict
        # Build (string_key, value) pairs so Symbol/String keys both sort.
        kv_pairs = [(string(k), val) for (k, val) in v]
        sort!(kv_pairs, by = first)
        parts = String[]
        for (k, val) in kv_pairs
            push!(parts, string(JSON3.write(k), ":", canonical_json(val)))
        end
        return string("{", join(parts, ","), "}")
    elseif v isa AbstractVector || v isa Tuple
        parts = [canonical_json(x) for x in v]
        return string("[", join(parts, ","), "]")
    else
        # Fallback: stringify
        return JSON3.write(string(v))
    end
end

"""
    compute_entry_hash(entry::HashChainedEntry)::String

Return the lowercase hex SHA-256 digest of `entry`'s canonical JSON serialization
covering every field except `entry_hash` itself. Used for both append-time
hashing and verification-time recomputation.
"""
function compute_entry_hash(entry::HashChainedEntry)::String
    payload = Dict{String, Any}(
        "index" => entry.index,
        "timestamp" => Dates.format(entry.timestamp, dateformat"yyyy-mm-ddTHH:MM:SS.sss"),
        "event_type" => entry.event_type,
        "user_id" => entry.user_id,
        "resource" => entry.resource,
        "action" => entry.action,
        "details" => entry.details,
        "prev_hash" => entry.prev_hash,
    )
    canonical = canonical_json(payload)
    return bytes2hex(sha256(canonical))
end

# ============================================================================
# JSONL (DE)SERIALIZATION
# ============================================================================

const _TS_FMT = dateformat"yyyy-mm-ddTHH:MM:SS.sss"

function _entry_to_json_line(entry::HashChainedEntry)::String
    obj = Dict{String, Any}(
        "index" => entry.index,
        "timestamp" => Dates.format(entry.timestamp, _TS_FMT),
        "event_type" => entry.event_type,
        "user_id" => entry.user_id,
        "resource" => entry.resource,
        "action" => entry.action,
        "details" => entry.details,
        "prev_hash" => entry.prev_hash,
        "entry_hash" => entry.entry_hash,
    )
    return JSON3.write(obj)
end

function _entry_from_json_line(line::AbstractString)::HashChainedEntry
    obj = JSON3.read(line)
    ts_raw = String(obj.timestamp)
    ts = try
        DateTime(ts_raw, _TS_FMT)
    catch
        DateTime(ts_raw)
    end
    details_raw = obj.details
    details = Dict{String, Any}()
    for (k, v) in pairs(details_raw)
        details[String(k)] = _normalize_json_value(v)
    end
    return HashChainedEntry(
        Int(obj.index),
        ts,
        String(obj.event_type),
        String(obj.user_id),
        String(obj.resource),
        String(obj.action),
        details,
        String(obj.prev_hash),
        String(obj.entry_hash),
    )
end

function _normalize_json_value(v)
    if v isa JSON3.Object
        d = Dict{String, Any}()
        for (k, vv) in pairs(v)
            d[String(k)] = _normalize_json_value(vv)
        end
        return d
    elseif v isa JSON3.Array
        return [_normalize_json_value(x) for x in v]
    elseif v isa AbstractString
        return String(v)
    else
        return v
    end
end

# ============================================================================
# APPEND
# ============================================================================

"""
    append_entry!(log, event_type, user_id, resource, action; details=Dict()) -> HashChainedEntry

Append a new event to `log`. Computes `prev_hash` from the previous entry's
`entry_hash` (or the genesis sentinel for the first record), assigns a
sequential `index`, and atomically writes the line to `log.log_path` (if set)
under `log.lock`.

Returns the persisted [`HashChainedEntry`].
"""
function append_entry!(
    log::HashChainedLog,
    event_type::AbstractString,
    user_id::AbstractString,
    resource::AbstractString,
    action::AbstractString;
    details::Dict{String, Any} = Dict{String, Any}(),
    timestamp::DateTime = now(),
)::HashChainedEntry
    lock(log.lock) do
        idx = length(log.entries)
        prev_hash = isempty(log.entries) ? log.genesis_hash : log.entries[end].entry_hash

        # Build a temporary entry with placeholder entry_hash, then compute the
        # real hash off of it.
        placeholder = HashChainedEntry(
            idx,
            timestamp,
            String(event_type),
            String(user_id),
            String(resource),
            String(action),
            details,
            prev_hash,
            "",
        )
        h = compute_entry_hash(placeholder)
        entry = HashChainedEntry(
            idx,
            timestamp,
            String(event_type),
            String(user_id),
            String(resource),
            String(action),
            details,
            prev_hash,
            h,
        )

        push!(log.entries, entry)
        _persist_line!(log, entry)
        return entry
    end
end

function _persist_line!(log::HashChainedLog, entry::HashChainedEntry)
    isempty(log.log_path) && return
    parent = dirname(log.log_path)
    if !isempty(parent) && !isdir(parent)
        mkpath(parent)
    end
    line = _entry_to_json_line(entry)
    open(log.log_path, "a") do io
        write(io, line)
        write(io, '\n')
        flush(io)
    end
end

# ============================================================================
# VERIFY
# ============================================================================

"""
    verify_chain(log) -> (valid, first_tampered_index, errors)

Walk the in-memory chain from index 0. For each entry:

1. Recompute its hash via [`compute_entry_hash`] and compare to the stored
   `entry_hash`.
2. Confirm `prev_hash` equals the previous entry's `entry_hash` (or the genesis
   sentinel for index 0).
3. Confirm `index` is sequential.

Returns a `NamedTuple` of `(valid::Bool, first_tampered_index::Union{Int,Nothing},
errors::Vector{String})`. The `first_tampered_index` is the index of the first
entry that fails any check; subsequent failures are still reported in `errors`.
"""
function verify_chain(log::HashChainedLog)
    errors = String[]
    first_tampered::Union{Int, Nothing} = nothing
    expected_prev = log.genesis_hash

    for (i, entry) in enumerate(log.entries)
        expected_idx = i - 1
        local_bad = false

        if entry.index != expected_idx
            push!(errors, "index gap at position $i: expected $expected_idx, got $(entry.index)")
            local_bad = true
        end

        if entry.prev_hash != expected_prev
            push!(errors,
                "prev_hash mismatch at index $(entry.index): expected $(expected_prev), got $(entry.prev_hash)",
            )
            local_bad = true
        end

        recomputed = compute_entry_hash(entry)
        if recomputed != entry.entry_hash
            push!(errors,
                "entry_hash mismatch at index $(entry.index): expected $(recomputed), got $(entry.entry_hash)",
            )
            local_bad = true
        end

        if local_bad && first_tampered === nothing
            first_tampered = entry.index
        end

        expected_prev = entry.entry_hash
    end

    return (valid = isempty(errors), first_tampered_index = first_tampered, errors = errors)
end

# ============================================================================
# LOAD / EXPORT / SUMMARY
# ============================================================================

"""
    load_hash_chained_log(path::String) -> HashChainedLog

Read a JSONL audit log from `path` and return a [`HashChainedLog`] populated
with its entries. Does not verify integrity; call [`verify_chain`] on the
result.
"""
function load_hash_chained_log(path::String)::HashChainedLog
    log = HashChainedLog(path)
    isfile(path) || return log

    open(path, "r") do io
        for raw in eachline(io)
            line = strip(raw)
            isempty(line) && continue
            push!(log.entries, _entry_from_json_line(line))
        end
    end
    return log
end

"""
    chain_summary(log) -> NamedTuple

Quick statistics on the chain: entry count, genesis hash, latest hash, time
span of the recorded events, and whether the chain currently verifies.
"""
function chain_summary(log::HashChainedLog)
    n = length(log.entries)
    verify_result = verify_chain(log)

    if n == 0
        return (
            entry_count = 0,
            genesis_hash = log.genesis_hash,
            latest_hash = log.genesis_hash,
            first_timestamp = nothing,
            last_timestamp = nothing,
            time_span = nothing,
            valid = verify_result.valid,
        )
    end

    first_ts = log.entries[1].timestamp
    last_ts = log.entries[end].timestamp
    return (
        entry_count = n,
        genesis_hash = log.genesis_hash,
        latest_hash = log.entries[end].entry_hash,
        first_timestamp = first_ts,
        last_timestamp = last_ts,
        time_span = last_ts - first_ts,
        valid = verify_result.valid,
    )
end

"""
    export_audit_report(log, filepath::String)

Write a human-readable tamper-evidence report covering chain length, hash
endpoints, verification outcome, and any detected errors.
"""
function export_audit_report(log::HashChainedLog, filepath::String)
    summary = chain_summary(log)
    verification = verify_chain(log)

    parent = dirname(filepath)
    if !isempty(parent) && !isdir(parent)
        mkpath(parent)
    end

    open(filepath, "w") do io
        println(io, "HASH-CHAINED AUDIT TRAIL REPORT")
        println(io, "=" ^ 60)
        println(io, "Generated: ", now())
        println(io, "Log path: ", isempty(log.log_path) ? "(in-memory only)" : log.log_path)
        println(io)
        println(io, "CHAIN SUMMARY")
        println(io, "-" ^ 60)
        println(io, "Entry count:      ", summary.entry_count)
        println(io, "Genesis hash:     ", summary.genesis_hash)
        println(io, "Latest hash:      ", summary.latest_hash)
        println(io, "First timestamp:  ", summary.first_timestamp)
        println(io, "Last timestamp:   ", summary.last_timestamp)
        println(io, "Time span:        ", summary.time_span)
        println(io)
        println(io, "INTEGRITY VERIFICATION")
        println(io, "-" ^ 60)
        println(io, "Valid:            ", verification.valid)
        if verification.first_tampered_index !== nothing
            println(io, "First tampered:   index ", verification.first_tampered_index)
        end
        if !isempty(verification.errors)
            println(io)
            println(io, "ERRORS")
            println(io, "-" ^ 60)
            for err in verification.errors
                println(io, "  - ", err)
            end
        else
            println(io)
            println(io, "No tampering detected. Chain integrity verified.")
        end
    end
    return filepath
end

# ============================================================================
# GLOBAL SINGLETON
# ============================================================================

"""
    AUDIT_CHAIN

Application-wide [`HashChainedLog`] singleton. Defaults to in-memory only;
set `AUDIT_CHAIN.log_path` (or replace the binding via `configure_audit_chain`)
to enable JSONL persistence.
"""
const AUDIT_CHAIN = HashChainedLog()

"""
    configure_audit_chain!(log_path::String; genesis_hash::String = "0"^64) -> HashChainedLog

Reset the global [`AUDIT_CHAIN`] singleton to persist at `log_path` and reload
any existing entries from disk.
"""
function configure_audit_chain!(log_path::String; genesis_hash::String = "0"^64)
    lock(AUDIT_CHAIN.lock) do
        AUDIT_CHAIN.log_path = log_path
        AUDIT_CHAIN.genesis_hash = genesis_hash
        empty!(AUDIT_CHAIN.entries)
        if isfile(log_path)
            loaded = load_hash_chained_log(log_path)
            append!(AUDIT_CHAIN.entries, loaded.entries)
        end
    end
    return AUDIT_CHAIN
end
