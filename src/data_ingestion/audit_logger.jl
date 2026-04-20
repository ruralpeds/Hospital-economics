"""
    audit_logger.jl

HIPAA-compliant audit logging for all PHI access and data processing.

Per HIPAA §164.312(b) - Audit Controls:
- All PHI access must be logged
- Logs must include: user ID, timestamp, action, resource, outcome
- Logs must be protected from modification (immutable)
- Logs must be retained per organizational policy (min 6 years)

This module provides:
- Creating audit log entries
- Logging ingestion events
- Logging data access
- Protecting logs from modification
"""

using Dates
using UUIDs

# ============================================================================
# AUDIT LOGGING
# ============================================================================

"""
    log_ingestion_event(
        user_id::String,
        event_type::String,
        resource_id::String = "";
        record_count::Int = 0,
        details::Dict = Dict(),
        ip_address::String = "127.0.0.1",
        status::String = "SUCCESS",
    )::AuditLogEntry

Create an audit log entry for PHI access event.

Per HIPAA §164.312(b), all PHI access must include:
- User identification (user_id)
- Timestamp (automatic)
- Action type (event_type)
- Resource accessed (resource_id)
- Outcome (status)

# Arguments
- user_id::String: User ID who initiated action
- event_type::String: Type of event
  - "INGESTION_START": Beginning data import
  - "INGESTION_COMPLETE": Data import finished
  - "RECORD_VALIDATED": Individual record validated
  - "RECORD_DEIDENTIFIED": Record de-identified
  - "VALIDATION_ERROR": Validation failed
  - "QUALITY_REPORT": Data quality assessed
  - "EXPORT_INITIATED": Data export started
  - "EXPORT_COMPLETE": Data export finished
- resource_id::String: ID of resource accessed (file, cohort, etc.)
- record_count::Int: Number of records affected
- details::Dict: Additional context (file_size, batch_id, etc.)
- ip_address::String: IP address of requestor
- status::String: Outcome ("SUCCESS", "PARTIAL_SUCCESS", "FAILED")

# Returns
- AuditLogEntry: Immutable log entry

# Example
```julia
log = log_ingestion_event(
    "user@hospital.org",
    "INGESTION_START",
    "patients_2024_q1.csv";
    record_count = 5000,
    details = Dict("file_size" => 2_500_000),
    status = "SUCCESS"
)
```
"""
function log_ingestion_event(
    user_id::String,
    event_type::String,
    resource_id::String = "";
    record_count::Int = 0,
    details::Dict{String, Any} = Dict{String, Any}(),
    ip_address::String = "127.0.0.1",
    status::String = "SUCCESS",
)::AuditLogEntry
    
    return AuditLogEntry(
        string(uuid4()),  # entry_id
        now(),  # timestamp
        user_id,
        event_type,
        "PATIENT_ENCOUNTER",  # resource_type
        resource_id,
        "INGESTION",  # action
        details,
        ip_address,
        status,
        record_count,
        "",  # outcome
    )
end

"""
    log_data_access(
        user_id::String,
        resource_id::String,
        action::String;
        details::Dict = Dict(),
        ip_address::String = "127.0.0.1",
        status::String = "SUCCESS",
        outcome::String = "",
    )::AuditLogEntry

Log access to PHI (Protected Health Information).

Used when users query, view, or export patient data.

# Arguments
- user_id::String: User ID accessing data
- resource_id::String: ID of data accessed (cohort, report, etc.)
- action::String: Action performed ("VIEW", "EXPORT", "ANALYZE", "COMPARE")
- details::Dict: Additional context
- ip_address::String: Requestor IP address
- status::String: Outcome status
- outcome::String: Narrative outcome description

# Returns
- AuditLogEntry: Immutable log entry

# Example
```julia
log = log_data_access(
    "analyst@hospital.org",
    "cohort_diabetes_001",
    "EXPORT";
    details = Dict("export_format" => "CSV", "record_count" => 150),
    outcome = "Successfully exported de-identified cohort"
)
```
"""
function log_data_access(
    user_id::String,
    resource_id::String,
    action::String;
    details::Dict{String, Any} = Dict{String, Any}(),
    ip_address::String = "127.0.0.1",
    status::String = "SUCCESS",
    outcome::String = "",
)::AuditLogEntry
    
    return AuditLogEntry(
        string(uuid4()),  # entry_id
        now(),  # timestamp
        user_id,
        "PHI_ACCESS",  # event_type
        "PATIENT_ENCOUNTER",  # resource_type
        resource_id,
        action,
        details,
        ip_address,
        status,
        0,  # record_count
        outcome,
    )
end

"""
    log_validation_error(
        user_id::String,
        resource_id::String,
        field::String,
        error_message::String;
        details::Dict = Dict(),
        ip_address::String = "127.0.0.1",
    )::AuditLogEntry

Log a validation error for audit trail.

# Arguments
- user_id::String: User initiating validation
- resource_id::String: Resource being validated
- field::String: Field that failed validation
- error_message::String: Error description
- details::Dict: Additional context
- ip_address::String: Requestor IP address

# Returns
- AuditLogEntry: Log entry with status="FAILED"
"""
function log_validation_error(
    user_id::String,
    resource_id::String,
    field::String,
    error_message::String;
    details::Dict{String, Any} = Dict{String, Any}(),
    ip_address::String = "127.0.0.1",
)::AuditLogEntry
    
    audit_details = merge(details, Dict(
        "field" => field,
        "error" => error_message,
    ))
    
    return AuditLogEntry(
        string(uuid4()),  # entry_id
        now(),  # timestamp
        user_id,
        "VALIDATION_ERROR",  # event_type
        "PATIENT_ENCOUNTER",  # resource_type
        resource_id,
        "VALIDATION",  # action
        audit_details,
        ip_address,
        "FAILED",
        0,  # record_count
        error_message,
    )
end

# ============================================================================
# AUDIT LOG STORAGE & PROTECTION
# ============================================================================

"""
    AuditLogStore

In-memory audit log storage with immutability protection.

Prevents modification or deletion of logs (simulating immutable database).
All operations are append-only.

# Fields
- entries::Vector{AuditLogEntry}: List of audit entries
- is_locked::Bool: If true, no new entries can be added
"""
mutable struct AuditLogStore
    entries::Vector{AuditLogEntry}
    is_locked::Bool
    
    function AuditLogStore()
        new(Vector{AuditLogEntry}(), false)
    end
end

"""
    append_log(store::AuditLogStore, entry::AuditLogEntry)::Bool

Append an entry to audit log.

Returns false if store is locked.
"""
function append_log(store::AuditLogStore, entry::AuditLogEntry)::Bool
    if store.is_locked
        @error "Audit log is locked; cannot add entries"
        return false
    end
    push!(store.entries, entry)
    return true
end

"""
    lock_audit_log(store::AuditLogStore)

Lock the audit log to prevent further modifications.

Once locked, can only read entries, not add new ones.
"""
function lock_audit_log(store::AuditLogStore)
    store.is_locked = true
end

"""
    get_audit_entries(
        store::AuditLogStore;
        user_id::Union{String, Nothing} = nothing,
        event_type::Union{String, Nothing} = nothing,
        date_from::Union{DateTime, Nothing} = nothing,
        date_to::Union{DateTime, Nothing} = nothing,
    )::Vector{AuditLogEntry}

Query audit logs with optional filtering.

# Arguments
- store::AuditLogStore: Audit log store
- user_id::String: Filter by user (optional)
- event_type::String: Filter by event type (optional)
- date_from::DateTime: Filter from date (optional)
- date_to::DateTime: Filter to date (optional)

# Returns
- Vector of matching audit entries
"""
function get_audit_entries(
    store::AuditLogStore;
    user_id::Union{String, Nothing} = nothing,
    event_type::Union{String, Nothing} = nothing,
    date_from::Union{DateTime, Nothing} = nothing,
    date_to::Union{DateTime, Nothing} = nothing,
)::Vector{AuditLogEntry}
    
    results = store.entries
    
    if !isnothing(user_id)
        results = filter(e -> e.user_id == user_id, results)
    end
    
    if !isnothing(event_type)
        results = filter(e -> e.event_type == event_type, results)
    end
    
    if !isnothing(date_from)
        results = filter(e -> e.timestamp >= date_from, results)
    end
    
    if !isnothing(date_to)
        results = filter(e -> e.timestamp <= date_to, results)
    end
    
    return results
end

"""
    audit_log_summary(store::AuditLogStore)::Dict

Generate summary statistics of audit log.

# Returns
- Dict with counts by event type, user, date range, etc.
"""
function audit_log_summary(store::AuditLogStore)::Dict{String, Any}
    if isempty(store.entries)
        return Dict(
            "total_entries" => 0,
            "date_range" => "No entries",
            "event_types" => Dict(),
            "users" => Dict(),
        )
    end
    
    # Count by event type
    event_counts = Dict{String, Int}()
    for entry in store.entries
        event_counts[entry.event_type] = get(event_counts, entry.event_type, 0) + 1
    end
    
    # Count by user
    user_counts = Dict{String, Int}()
    for entry in store.entries
        user_counts[entry.user_id] = get(user_counts, entry.user_id, 0) + 1
    end
    
    # Date range
    dates = [e.timestamp for e in store.entries]
    date_from = minimum(dates)
    date_to = maximum(dates)
    
    return Dict(
        "total_entries" => length(store.entries),
        "date_from" => date_from,
        "date_to" => date_to,
        "days_covered" => Int(date_to - date_from),
        "event_types" => event_counts,
        "users" => user_counts,
        "is_locked" => store.is_locked,
    )
end

