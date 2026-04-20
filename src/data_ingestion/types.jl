"""
    types.jl

Core data structures for HIPAA-compliant patient data ingestion pipeline.

Defines:
- PatientEncounter: De-identified patient encounter data (HIPAA Safe Harbor)
- IngestionConfig: Configuration for data import jobs
- IngestionResult: Results and metrics from ingestion
- ValidationResult: Per-record validation outcomes
- AuditLogEntry: Immutable audit trail entries
"""

using Dates
using UUIDs

# ============================================================================
# PATIENT ENCOUNTER: Core De-Identified Patient Data Structure
# ============================================================================

"""
    PatientEncounter

De-identified patient encounter data following HIPAA Safe Harbor method.

All personally identifiable information has been removed or masked:
- patient_id: Pseudonymized identifier (hash-based)
- encrypted_patient_id: Encrypted version for audit trail linking
- Age >89 stored as ≥90 per Safe Harbor
- Exact dates masked to year only
- Zip code reduced to first 3 digits
- No direct identifiers (name, SSN, DOB, MRN, etc.)

# Fields
- patient_id::String: Pseudonymized patient identifier (deterministic hash)
- encrypted_patient_id::Vector{UInt8}: Encrypted identifier for audit linking
- encounter_id::String: Unique encounter identifier
- birth_year::Int: Birth year (not exact DOB)
- age_at_admission::Int: Age at admission (≥90 if age >89)
- sex::String: "M", "F", or "O" (CDC standard)
- race_code::String: Race code per CDC (W/B/H/A/N/2+/O)
- ethnicity_code::String: Ethnicity (Hispanic/Non-Hispanic)
- zip_code_prefix::String: First 3 digits of zip code (per Safe Harbor)
- admission_date::Date: Date of admission
- discharge_date::Date: Date of discharge
- length_of_stay::Int: LOS in days (calculated)
- admission_type::String: "Emergency", "Urgent", "Scheduled"
- discharge_disposition::String: "Home", "SNF", "LTC", "Hospice", "AMA", "Expired"
- primary_diagnosis::String: Primary ICD-10 code
- secondary_diagnoses::Vector{String}: Secondary ICD-10 codes (if any)
- procedures::Vector{String}: CPT or ICD-10-PCS procedure codes
- total_charges::Float64: Total charges ($)
- allowed_amount::Float64: Allowed/negotiated amount ($)
- paid_amount::Float64: Amount paid ($)
- patient_cost_share::Float64: Patient out-of-pocket ($)
- payer::String: "Medicare", "Medicaid", "Commercial", "Uninsured"
- source_system::String: Origin system (e.g., "CSV_2024_Q1")
- ingestion_date::DateTime: When this record was ingested
- validation_status::String: "Valid", "Warning", "Error"
- quality_flags::Vector{String}: Data quality issues (if any)
- metadata::Dict: Additional unstructured data
"""
mutable struct PatientEncounter
    # De-identified identifiers (HIPAA Safe Harbor)
    patient_id::String                # Pseudonym (SHA-256 hash)
    encrypted_patient_id::Vector{UInt8}  # For audit trail linking
    encounter_id::String

    # Demographics (HIPAA Safe Harbor compliant)
    birth_year::Int                 # Not exact DOB
    age_at_admission::Int           # Age at admission (capped at 90)
    sex::String                     # M/F/O
    race_code::String               # CDC codes (W/B/H/A/N/2+/O)
    ethnicity_code::String          # Hispanic/Non-Hispanic
    zip_code_prefix::String         # First 3 digits only

    # Clinical
    admission_date::Date
    discharge_date::Date
    length_of_stay::Int
    admission_type::String          # Emergency/Urgent/Scheduled
    discharge_disposition::String   # Home/SNF/LTC/Hospice/AMA/Expired
    primary_diagnosis::String       # ICD-10
    secondary_diagnoses::Vector{String}
    procedures::Vector{String}      # CPT codes

    # Financial
    total_charges::Float64
    allowed_amount::Float64
    paid_amount::Float64
    patient_cost_share::Float64
    payer::String                   # Medicare/Medicaid/Commercial/Uninsured

    # Metadata & tracking
    source_system::String
    ingestion_date::DateTime
    validation_status::String       # Valid/Warning/Error
    quality_flags::Vector{String}   # Data quality issues

    metadata::Dict{String, Any}
end

# Default constructor with sensible defaults
function PatientEncounter(
    patient_id::String,
    encounter_id::String,
    admission_date::Date,
    discharge_date::Date;
    encrypted_patient_id::Vector{UInt8} = UInt8[],
    birth_year::Int = 1950,
    age_at_admission::Int = 0,
    sex::String = "O",
    race_code::String = "O",
    ethnicity_code::String = "Unknown",
    zip_code_prefix::String = "000",
    admission_type::String = "Scheduled",
    discharge_disposition::String = "Home",
    primary_diagnosis::String = "",
    secondary_diagnoses::Vector{String} = String[],
    procedures::Vector{String} = String[],
    total_charges::Float64 = 0.0,
    allowed_amount::Float64 = 0.0,
    paid_amount::Float64 = 0.0,
    patient_cost_share::Float64 = 0.0,
    payer::String = "Uninsured",
    source_system::String = "Unknown",
    validation_status::String = "Pending",
    quality_flags::Vector{String} = String[],
    metadata::Dict{String, Any} = Dict(),
)
    los = Int(discharge_date - admission_date)
    ingestion_date = now()
    
    PatientEncounter(
        patient_id,
        encrypted_patient_id,
        encounter_id,
        birth_year,
        age_at_admission,
        sex,
        race_code,
        ethnicity_code,
        zip_code_prefix,
        admission_date,
        discharge_date,
        los,
        admission_type,
        discharge_disposition,
        primary_diagnosis,
        secondary_diagnoses,
        procedures,
        total_charges,
        allowed_amount,
        paid_amount,
        patient_cost_share,
        payer,
        source_system,
        ingestion_date,
        validation_status,
        quality_flags,
        metadata,
    )
end

# ============================================================================
# INGESTION CONFIGURATION
# ============================================================================

"""
    IngestionConfig

Configuration parameters for data ingestion job.

# Fields
- filepath::String: Path to source data file
- delimiter::Char: Field delimiter (default: ',')
- skip_lines::Int: Lines to skip before headers
- field_mapping::Dict: CSV column → PatientEncounter field mapping
- deidentify::Bool: Whether to apply de-identification
- validate::Bool: Whether to validate records
- batch_size::Int: Records to process per batch
- dry_run::Bool: If true, validate only without loading
"""
struct IngestionConfig
    filepath::String
    delimiter::Char = ','
    skip_lines::Int = 0
    field_mapping::Dict{String, String}  # CSV_col_name => encounter_field
    deidentify::Bool = true
    validate::Bool = true
    batch_size::Int = 1000
    dry_run::Bool = false
end

# ============================================================================
# VALIDATION RESULTS
# ============================================================================

"""
    ValidationError

Details of a validation error for a single record.

# Fields
- record_index::Int: Index of record with error (for tracing)
- field::String: Field that failed validation
- value::Any: The invalid value
- error_code::String: Standardized error code
- message::String: Human-readable error message
- severity::String: "ERROR" or "WARNING"
"""
struct ValidationError
    record_index::Int
    field::String
    value::Any
    error_code::String  # e.g., "INVALID_ICD10", "DATE_RANGE_ERROR"
    message::String
    severity::String  # ERROR or WARNING
end

"""
    ValidationResult

Outcome of validation for a single record.

# Fields
- is_valid::Bool: Whether record passed all validations
- errors::Vector{ValidationError}: All validation errors/warnings
- warnings::Vector{String}: Non-fatal issues to note
"""
struct ValidationResult
    is_valid::Bool
    errors::Vector{ValidationError}
    warnings::Vector{String}
end

# ============================================================================
# AUDIT LOGGING
# ============================================================================

"""
    AuditLogEntry

Immutable audit trail entry for PHI access and data processing events.

Per HIPAA §164.312(b), all PHI access must be logged with:
- Timestamp and user identification
- Action type and resource accessed
- Outcome status

# Fields
- entry_id::String: Unique UUID for this log entry
- timestamp::DateTime: Exact time of event
- user_id::String: User who initiated action
- event_type::String: Type of event ("INGESTION_START", "RECORD_VALIDATED", etc.)
- resource_type::String: Type of resource accessed ("PATIENT_ENCOUNTER", "COHORT")
- resource_id::String: ID of specific resource
- action::String: Action performed ("INGESTION", "VALIDATION", "DEIDENTIFICATION")
- details::Dict: Additional context (record_count, file_size, etc.)
- ip_address::String: IP address of requestor
- status::String: "SUCCESS", "PARTIAL_SUCCESS", or "FAILED"
- record_count::Int: Number of records affected
- outcome::String: Overall outcome description
"""
struct AuditLogEntry
    entry_id::String  # UUID
    timestamp::DateTime
    user_id::String
    event_type::String  # INGESTION_START, RECORD_LOADED, VALIDATION_ERROR, etc.
    resource_type::String  # PATIENT_ENCOUNTER
    resource_id::String
    action::String  # INGESTION, VALIDATION, DEIDENTIFICATION
    details::Dict{String, Any}
    ip_address::String
    status::String  # SUCCESS, FAILED, PARTIAL
    record_count::Int
    outcome::String  # Optional outcome description
end

function AuditLogEntry(
    user_id::String,
    event_type::String,
    action::String;
    resource_type::String = "PATIENT_ENCOUNTER",
    resource_id::String = "",
    details::Dict{String, Any} = Dict(),
    ip_address::String = "127.0.0.1",
    status::String = "SUCCESS",
    record_count::Int = 0,
    outcome::String = "",
)
    AuditLogEntry(
        string(uuid4()),
        now(),
        user_id,
        event_type,
        resource_type,
        resource_id,
        action,
        details,
        ip_address,
        status,
        record_count,
        outcome,
    )
end

# ============================================================================
# INGESTION RESULTS
# ============================================================================

"""
    IngestionResult

Summary and results of data ingestion job.

Tracks both successful records and failures, with complete audit trail.

# Fields
- success::Bool: Whether overall ingestion succeeded
- records_loaded::Int: Total records processed
- records_valid::Int: Records that passed validation
- records_with_warnings::Int: Records with non-fatal issues
- records_rejected::Int: Records that failed validation
- encounters::Vector{PatientEncounter}: Valid, de-identified encounters
- validation_errors::Vector{ValidationError}: All validation errors
- quality_summary::Dict: Data quality metrics (completeness, validity %)
- audit_log_entries::Vector{AuditLogEntry}: Complete audit trail
- processing_time::Float64: Elapsed time in seconds
"""
struct IngestionResult
    success::Bool
    records_loaded::Int
    records_valid::Int
    records_with_warnings::Int
    records_rejected::Int
    encounters::Vector{PatientEncounter}
    validation_errors::Vector{ValidationError}
    quality_summary::Dict{String, Any}
    audit_log_entries::Vector{AuditLogEntry}
    processing_time::Float64
end

# Constructor with defaults
function IngestionResult(
    success::Bool = false,
    records_loaded::Int = 0,
    records_valid::Int = 0,
    records_with_warnings::Int = 0,
    records_rejected::Int = 0;
    encounters::Vector{PatientEncounter} = PatientEncounter[],
    validation_errors::Vector{ValidationError} = ValidationError[],
    quality_summary::Dict{String, Any} = Dict(),
    audit_log_entries::Vector{AuditLogEntry} = AuditLogEntry[],
    processing_time::Float64 = 0.0,
)
    IngestionResult(
        success,
        records_loaded,
        records_valid,
        records_with_warnings,
        records_rejected,
        encounters,
        validation_errors,
        quality_summary,
        audit_log_entries,
        processing_time,
    )
end

# ============================================================================
# DATA QUALITY REPORTING
# ============================================================================

"""
    QualityReport

Assessment of data quality across a set of records.

Implements DAMA data quality dimensions:
- Completeness: % of fields populated
- Validity: % of records passing validation
- Consistency: Cross-field logical coherence
- Accuracy: Conformance to expected ranges
- Timeliness: Data recency

# Fields
- completeness_pct::Float64: % of non-null fields (0-100)
- validity_pct::Float64: % of records passing validation (0-100)
- consistency_pct::Float64: % of records with logical cross-field consistency
- outlier_count::Int: Number of outlier records detected
- missing_fields::Dict{String, Int}: Count of missing values by field
- quality_score::Float64: Overall quality score (0-100)
- issues::Vector{String}: Identified quality issues
- recommendations::Vector{String}: Recommended remediation actions
"""
struct QualityReport
    completeness_pct::Float64
    validity_pct::Float64
    consistency_pct::Float64
    outlier_count::Int
    missing_fields::Dict{String, Int}
    quality_score::Float64
    issues::Vector{String}
    recommendations::Vector{String}
end

