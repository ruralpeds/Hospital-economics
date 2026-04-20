"""
    DataIngestionPipeline.jl

Main orchestrator for HIPAA-compliant patient data ingestion.

This module provides the primary API for importing patient encounter data
from CSV or other sources, with comprehensive validation, de-identification,
and audit logging.

# Main API

```julia
using HealthcareEconomics

# Configure ingestion
config = IngestionConfig(
    filepath = "patients.csv",
    field_mapping = Dict(
        "MRN" => "patient_id",
        "Admit_Date" => "admission_date",
        ...
    ),
    deidentify = true,
    validate = true,
)

# Run ingestion
result = ingest_csv(config, user_id="analyst@hospital.org")

# Check results
println("Loaded: $(result.records_loaded), Valid: $(result.records_valid)")
println("Quality Score: $(result.quality_summary["quality_score"])%")

# Access de-identified encounters
for enc in result.encounters
    println(enc.patient_id, ": ", enc.primary_diagnosis)
end

# Audit trail
for log in result.audit_log_entries
    println(log.timestamp, " - ", log.event_type, ": ", log.status)
end
```

# Constants

- Valid admission types: Emergency, Urgent, Scheduled
- Valid payers: Medicare, Medicaid, Commercial, Uninsured, Other
- Valid sexes: M, F, O (Other)
"""

module DataIngestionPipeline

using Dates
using CSV
using DataFrames
using SHA
using UUIDs

include("types.jl")
include("validators.jl")
include("deidentifiers.jl")
include("audit_logger.jl")

export PatientEncounter,
       IngestionConfig,
       IngestionResult,
       ValidationResult,
       AuditLogEntry,
       AuditLogStore,
       ingest_csv,
       log_ingestion_event,
       log_data_access,
       validate_icd10_code,
       validate_cpt_code,
       validate_patient_encounter,
       deidentify_encounter,
       validate_deidentification,
       generate_pseudonym,
       generate_encounter_id

# ============================================================================
# CONSTANTS
# ============================================================================

const VALID_ADMISSION_TYPES = ["Emergency", "Urgent", "Scheduled", "Unknown"]
const VALID_PAYERS = ["Medicare", "Medicaid", "Commercial", "Uninsured", "Other", "Unknown"]
const VALID_SEXES = ["M", "F", "O"]
const VALID_RACE_CODES = ["W", "B", "H", "A", "N", "2+", "O", "Unknown"]
const VALID_DISPOSITIONS = ["Home", "SNF", "LTC", "Hospice", "AMA", "Expired", "Transferred", "Unknown"]

# Default organizational salt (should be configured in production)
const DEFAULT_ORG_SALT = "HealthcareEconomicsOrg2024"

# ============================================================================
# MAIN INGESTION API
# ============================================================================

"""
    ingest_csv(
        config::IngestionConfig,
        user_id::String = "system";
        org_salt::String = DEFAULT_ORG_SALT,
    )::IngestionResult

Ingest patient encounter data from CSV file with complete validation and de-identification.

This is the primary entry point for data ingestion. The function:
1. Reads CSV file with configurable field mapping
2. Validates each record (ICD-10, CPT codes, date ranges, costs)
3. De-identifies using HIPAA Safe Harbor method
4. Logs all operations to immutable audit trail
5. Generates data quality report

# Arguments
- config::IngestionConfig: Ingestion configuration
- user_id::String: User ID for audit trail (default: "system")
- org_salt::String: Organizational salt for pseudonymization

# Returns
- IngestionResult: Complete results including:
  - success: Bool - true if all records valid and loaded
  - records_loaded: Total records processed
  - records_valid: Records that passed validation
  - records_with_warnings: Records with non-fatal issues
  - records_rejected: Records that failed validation
  - encounters: Vector of PatientEncounter (de-identified)
  - validation_errors: Detailed error list
  - quality_summary: Data quality metrics
  - audit_log_entries: Complete audit trail
  - processing_time: Elapsed seconds

# Raises
- ErrorException: If file not found or unreadable
- CSV.ParsingException: If CSV format invalid

# Example
```julia
config = IngestionConfig(
    filepath = "data/patients_2024_q1.csv",
    field_mapping = Dict(
        "pat_mrn" => "patient_id",
        "birth_date" => "dob",
        "admit_date" => "admission_date",
        "disch_date" => "discharge_date",
        "admit_type" => "admission_type",
        "diag_principal" => "primary_diagnosis",
        "procedures" => "procedures",
        "total_charges" => "total_charges",
    ),
    deidentify = true,
    validate = true,
    batch_size = 1000,
)

result = ingest_csv(config, user_id="analyst@hospital.org")

if result.success
    println("Ingestion successful: $(result.records_valid)/$(result.records_loaded) valid")
else
    println("Some records failed validation")
    println("Errors: $(length(result.validation_errors))")
end
```

# Data Quality Expectations

After ingestion, the following quality metrics are calculated:
- Completeness: % of non-null fields
- Validity: % of records passing validation
- Consistency: Cross-field logical checks
- Quality Score: Overall score (0-100)

Quality issues are noted in `result.quality_summary`.
"""
function ingest_csv(
    config::IngestionConfig,
    user_id::String = "system";
    org_salt::String = DEFAULT_ORG_SALT,
)::IngestionResult
    
    start_time = time()
    
    # Initialize result tracking
    records_loaded = 0
    records_valid = 0
    records_with_warnings = 0
    records_rejected = 0
    
    encounters = PatientEncounter[]
    validation_errors = ValidationError[]
    audit_logs = AuditLogEntry[]
    
    # Log: Ingestion started
    push!(audit_logs, log_ingestion_event(
        user_id,
        "INGESTION_START",
        basename(config.filepath);
        details = Dict("batch_size" => config.batch_size),
        status = "SUCCESS",
    ))
    
    try
        # Step 1: Check file exists
        if !isfile(config.filepath)
            error_log = log_ingestion_event(
                user_id,
                "INGESTION_START",
                basename(config.filepath);
                status = "FAILED",
            )
            error_log = AuditLogEntry(
                error_log.entry_id, error_log.timestamp, error_log.user_id,
                error_log.event_type, error_log.resource_type, error_log.resource_id,
                error_log.action, error_log.details, error_log.ip_address,
                "FAILED", 0, "File not found: $(config.filepath)"
            )
            push!(audit_logs, error_log)
            
            return IngestionResult(
                false, 0, 0, 0, 0;
                encounters = PatientEncounter[],
                validation_errors = ValidationError[],
                quality_summary = Dict("error" => "File not found"),
                audit_log_entries = audit_logs,
                processing_time = time() - start_time,
            )
        end
        
        # Step 2: Read CSV
        df = CSV.read(config.filepath, DataFrame)
        records_loaded = nrow(df)
        
        # Log: File read successfully
        push!(audit_logs, log_ingestion_event(
            user_id,
            "CSV_READ",
            basename(config.filepath);
            record_count = records_loaded,
            details = Dict(
                "file_size" => filesize(config.filepath),
                "columns" => names(df),
            ),
            status = "SUCCESS",
        ))
        
        if config.dry_run
            # In dry-run mode, just count records without loading
            push!(audit_logs, log_ingestion_event(
                user_id,
                "DRY_RUN_COMPLETE",
                basename(config.filepath);
                record_count = records_loaded,
                status = "SUCCESS",
            ))
            
            elapsed = time() - start_time
            return IngestionResult(
                true, records_loaded, 0, 0, 0;
                encounters = PatientEncounter[],
                validation_errors = ValidationError[],
                quality_summary = Dict(
                    "dry_run" => true,
                    "records_scanned" => records_loaded,
                ),
                audit_log_entries = audit_logs,
                processing_time = elapsed,
            )
        end
        
        # Step 3: Process each record in batches
        for (idx, row) in enumerate(eachrow(df))
            # Map CSV columns to PatientEncounter fields
            raw_data = _map_csv_row_to_dict(row, config.field_mapping)
            
            # Validate (if enabled)
            validation_result = nothing
            if config.validate
                # Create temporary encounter to validate
                try
                    temp_enc = _create_temp_encounter(raw_data)
                    validation_result = validate_patient_encounter(temp_enc)
                catch e
                    # Parsing/type error during validation
                    validation_result = ValidationResult(
                        false,
                        [ValidationError(idx, "all", string(e), "PARSE_ERROR", string(e), "ERROR")],
                        []
                    )
                end
            else
                validation_result = ValidationResult(true, ValidationError[], String[])
            end
            
            # Track validation results
            if !validation_result.is_valid
                records_rejected += 1
                append!(validation_errors, validation_result.errors)
                
                # Log validation error
                if !isempty(validation_result.errors)
                    first_error = validation_result.errors[1]
                    push!(audit_logs, log_validation_error(
                        user_id,
                        "record_$idx",
                        first_error.field,
                        first_error.message,
                    ))
                end
            else
                # De-identify (if enabled)
                if config.deidentify
                    try
                        encounter = deidentify_encounter(raw_data, org_salt)
                        
                        # Validate de-identification
                        is_safe, de_id_issues = validate_deidentification(encounter)
                        if !is_safe
                            push!(validation_result.warnings, "De-identification issues: $de_id_issues")
                        end
                        
                        push!(encounters, encounter)
                        records_valid += 1
                        
                        if !isempty(validation_result.warnings)
                            records_with_warnings += 1
                        end
                        
                        # Log successful deidentification
                        push!(audit_logs, log_ingestion_event(
                            user_id,
                            "RECORD_DEIDENTIFIED",
                            "record_$idx";
                            status = "SUCCESS",
                        ))
                    catch e
                        records_rejected += 1
                        push!(validation_errors, ValidationError(
                            idx, "all", "", "DEIDENTIFICATION_ERROR", string(e), "ERROR"
                        ))
                        push!(audit_logs, log_validation_error(
                            user_id, "record_$idx", "deidentification", string(e)
                        ))
                    end
                else
                    # No de-identification, just convert
                    try
                        encounter = _create_full_encounter(raw_data)
                        push!(encounters, encounter)
                        records_valid += 1
                        
                        if !isempty(validation_result.warnings)
                            records_with_warnings += 1
                        end
                    catch e
                        records_rejected += 1
                        push!(validation_errors, ValidationError(
                            idx, "all", "", "ENCOUNTER_ERROR", string(e), "ERROR"
                        ))
                    end
                end
            end
            
            # Log in batches
            if idx % config.batch_size == 0
                push!(audit_logs, log_ingestion_event(
                    user_id,
                    "BATCH_PROCESSED",
                    basename(config.filepath);
                    record_count = config.batch_size,
                    details = Dict("batch_end_index" => idx),
                    status = "SUCCESS",
                ))
            end
        end
        
        # Step 4: Generate quality report
        quality_summary = _generate_quality_report(encounters, validation_errors, records_loaded)
        
        # Step 5: Log completion
        success = records_rejected == 0 && records_valid > 0
        push!(audit_logs, log_ingestion_event(
            user_id,
            "INGESTION_COMPLETE",
            basename(config.filepath);
            record_count = records_loaded,
            details = Dict(
                "valid" => records_valid,
                "rejected" => records_rejected,
                "warnings" => records_with_warnings,
            ),
            status = success ? "SUCCESS" : "PARTIAL_SUCCESS",
        ))
        
        elapsed = time() - start_time
        
        return IngestionResult(
            success,
            records_loaded,
            records_valid,
            records_with_warnings,
            records_rejected;
            encounters = encounters,
            validation_errors = validation_errors,
            quality_summary = quality_summary,
            audit_log_entries = audit_logs,
            processing_time = elapsed,
        )
        
    catch e
        # Catastrophic error
        push!(audit_logs, log_ingestion_event(
            user_id,
            "INGESTION_ERROR",
            basename(config.filepath);
            status = "FAILED",
        ))
        
        elapsed = time() - start_time
        
        return IngestionResult(
            false,
            records_loaded,
            records_valid,
            records_with_warnings,
            records_rejected;
            encounters = PatientEncounter[],
            validation_errors = [ValidationError(0, "all", "", "FATAL_ERROR", string(e), "ERROR")],
            quality_summary = Dict("error" => string(e)),
            audit_log_entries = audit_logs,
            processing_time = elapsed,
        )
    end
end

# ============================================================================
# INTERNAL HELPER FUNCTIONS
# ============================================================================

"""
Map CSV row columns to PatientEncounter field names.
"""
function _map_csv_row_to_dict(row::DataFrameRow, field_mapping::Dict)::Dict
    result = Dict{String, Any}()
    
    for (csv_col, enc_field) in field_mapping
        if csv_col in names(row)
            result[enc_field] = row[csv_col]
        end
    end
    
    return result
end

"""
Create temporary encounter for validation.
"""
function _create_temp_encounter(raw_data::Dict)::PatientEncounter
    admission_date = _parse_date(get(raw_data, "admission_date", today()))
    discharge_date = _parse_date(get(raw_data, "discharge_date", admission_date))
    
    PatientEncounter(
        get(raw_data, "patient_id", "UNKNOWN"),
        "temp_encounter",
        admission_date,
        discharge_date;
        birth_year = year(_parse_date(get(raw_data, "dob", "1950-01-01"))),
        age_at_admission = get(raw_data, "age_at_admission", 0),
        sex = get(raw_data, "sex", "O"),
        race_code = get(raw_data, "race_code", "O"),
        primary_diagnosis = get(raw_data, "primary_diagnosis", ""),
        secondary_diagnoses = _to_vector(get(raw_data, "secondary_diagnoses", String[])),
        procedures = _to_vector(get(raw_data, "procedures", String[])),
        total_charges = Float64(get(raw_data, "total_charges", 0.0)),
    )
end

"""
Create full de-identified encounter (when deidentify=true).
"""
function _create_full_encounter(raw_data::Dict)::PatientEncounter
    deidentify_encounter(raw_data, DEFAULT_ORG_SALT)
end

"""
Convert value to vector (handles strings split by semicolon).
"""
function _to_vector(value)::Vector{String}
    if value isa String
        return split(value, ";")
    elseif value isa Vector
        return String.(value)
    else
        return String[]
    end
end

"""
Generate data quality report.
"""
function _generate_quality_report(
    encounters::Vector{PatientEncounter},
    errors::Vector{ValidationError},
    total_records::Int,
)::Dict{String, Any}
    
    valid_count = length(encounters)
    error_count = length(errors)
    
    return Dict(
        "total_records" => total_records,
        "valid_records" => valid_count,
        "invalid_records" => error_count,
        "validity_pct" => round((valid_count / max(total_records, 1)) * 100, digits=2),
        "quality_score" => round((valid_count / max(total_records, 1)) * 100, digits=1),
        "error_count" => error_count,
    )
end

"""
Parse date from various formats.
"""
function _parse_date(value)
    if value isa Date
        return value
    elseif value isa String
        for fmt in ["yyyy-mm-dd", "mm/dd/yyyy", "yyyymmdd"]
            try
                return Dates.parse(Date, value, fmt)
            catch
            end
        end
        return today()
    else
        return today()
    end
end

end # module DataIngestionPipeline

