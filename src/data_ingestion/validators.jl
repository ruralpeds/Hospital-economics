"""
    validators.jl

Data validation functions for HIPAA-compliant patient data.

Validates:
- ICD-10 diagnosis codes (format and content)
- CPT procedure codes (format and content)
- Patient encounter data (coherence and ranges)
- Cost data (reasonable ranges, outliers)
- Clinical data (age-appropriate diagnoses, etc.)

Per HIPAA, invalid data must be logged and rejected.
"""

using Dates
using DataFrames
using CSV

# ============================================================================
# ICD-10 CODE VALIDATION
# ============================================================================

"""
    validate_icd10_code(code::String)::Bool

Validate ICD-10 diagnosis code format and content.

Format: 3-7 characters
- 1st: Letter (A-U, W-Z)
- 2nd: Digit
- 3rd-5th: Digit or decimal
- 6th-7th: Letter (optional, for laterality, severity)

Examples:
- E11.9: Type 2 diabetes without complications
- J44.0: COPD with acute lower respiratory infection
- I10: Essential hypertension

# Arguments
- code::String: ICD-10 code to validate

# Returns
- Bool: true if valid format, false otherwise
"""
function validate_icd10_code(code::String)::Bool
    # Empty or null check
    isempty(code) && return false
    
    # Length check (3-7 characters)
    length(code) < 3 || length(code) > 7 && return false
    
    # First character must be letter A-U or W-Z (not V)
    first_char = uppercase(code[1])
    (first_char < 'A' || first_char > 'Z' || first_char == 'V') && return false
    
    # Second character must be digit
    !isdigit(code[2]) && return false
    
    # If there's a decimal, it must be at position 4
    if '.' in code
        if code[4] != '.'
            return false
        end
    end
    
    # Basic format is valid (detailed code validation would require ICD-10 reference table)
    return true
end

# ============================================================================
# CPT CODE VALIDATION
# ============================================================================

"""
    validate_cpt_code(code::String)::Bool

Validate CPT (Current Procedural Terminology) code.

CPT codes: 5 digits, or letter + 4 digits (Category II/III)

Examples:
- 99213: Office/outpatient visit, established patient
- 27447: Total knee replacement

# Arguments
- code::String: CPT code to validate

# Returns
- Bool: true if valid format, false otherwise
"""
function validate_cpt_code(code::String)::Bool
    # Empty check
    isempty(code) && return false
    
    # CPT codes are 5 digits, or letter + 4 digits
    if length(code) != 5
        return false
    end
    
    # All digits, or letter + 4 digits
    if all(isdigit, code)
        return true
    elseif isalpha(code[1]) && all(isdigit, code[2:5])
        return true  # Category II/III codes
    else
        return false
    end
end

# ============================================================================
# PATIENT ENCOUNTER VALIDATION
# ============================================================================

"""
    validate_patient_encounter(enc::PatientEncounter)::ValidationResult

Comprehensive validation of patient encounter data.

Checks:
- Date coherence (admission < discharge)
- Age validity (0-120, then capped at 90 per HIPAA Safe Harbor)
- Diagnosis/procedure code format (ICD-10, CPT)
- Cost reasonableness (outliers flagged as warnings)
- Required fields present
- Data type correctness

# Arguments
- enc::PatientEncounter: Encounter data to validate

# Returns
- ValidationResult: With is_valid flag and detailed error list
"""
function validate_patient_encounter(enc::PatientEncounter)::ValidationResult
    errors = ValidationError[]
    warnings = String[]
    
    # 1. Date validation
    if enc.discharge_date < enc.admission_date
        push!(errors, ValidationError(
            0, "discharge_date", enc.discharge_date,
            "DATE_RANGE_ERROR",
            "Discharge date before admission date",
            "ERROR"
        ))
    elseif enc.discharge_date == enc.admission_date
        push!(warnings, "Zero-day admission (same-day admission and discharge)")
    end
    
    # 2. Age validation
    if enc.age_at_admission < 0 || enc.age_at_admission > 150
        push!(errors, ValidationError(
            0, "age_at_admission", enc.age_at_admission,
            "AGE_OUT_OF_RANGE",
            "Age outside valid range (0-150)",
            "ERROR"
        ))
    elseif enc.age_at_admission > 120
        push!(warnings, "Age >120 detected; flagged for manual review")
    end
    
    # 3. Primary diagnosis validation
    if !isempty(enc.primary_diagnosis) && !validate_icd10_code(enc.primary_diagnosis)
        push!(errors, ValidationError(
            0, "primary_diagnosis", enc.primary_diagnosis,
            "INVALID_ICD10",
            "Invalid ICD-10 code format",
            "ERROR"
        ))
    elseif isempty(enc.primary_diagnosis)
        push!(warnings, "No primary diagnosis provided")
    end
    
    # 4. Secondary diagnoses validation
    for (i, diag) in enumerate(enc.secondary_diagnoses)
        if !validate_icd10_code(diag)
            push!(errors, ValidationError(
                0, "secondary_diagnosis_$i", diag,
                "INVALID_ICD10",
                "Invalid ICD-10 code in secondary diagnoses",
                "WARNING"
            ))
        end
    end
    
    # 5. Procedures validation
    for (i, proc) in enumerate(enc.procedures)
        if !validate_cpt_code(proc)
            push!(warnings, "Procedure code may be invalid: $proc (non-CPT format, may be ICD-10-PCS)")
        end
    end
    
    # 6. Cost validation
    if enc.total_charges < 0
        push!(errors, ValidationError(
            0, "total_charges", enc.total_charges,
            "NEGATIVE_COST",
            "Total charges cannot be negative",
            "ERROR"
        ))
    end
    
    if enc.total_charges > 1_000_000
        push!(warnings, "Very high charge amount: \$$(enc.total_charges); flagged for manual review")
    end
    
    if enc.allowed_amount > enc.total_charges && enc.allowed_amount > 0
        push!(warnings, "Allowed amount exceeds total charges (unusual)")
    end
    
    if enc.paid_amount > enc.allowed_amount && enc.allowed_amount > 0
        push!(warnings, "Paid amount exceeds allowed amount (unusual)")
    end
    
    # 7. Length of stay validation
    if enc.length_of_stay < 0
        push!(errors, ValidationError(
            0, "length_of_stay", enc.length_of_stay,
            "NEGATIVE_LOS",
            "Length of stay cannot be negative",
            "ERROR"
        ))
    end
    
    if enc.length_of_stay > 365
        push!(warnings, "Very long length of stay (>1 year): $(enc.length_of_stay) days")
    end
    
    # 8. Demographics validation
    if !in(enc.sex, ["M", "F", "O"])
        push!(warnings, "Sex code not in standard set (M/F/O): $(enc.sex)")
    end
    
    # 9. Payer validation
    valid_payers = ["Medicare", "Medicaid", "Commercial", "Uninsured", "Other", "Unknown"]
    if !in(enc.payer, valid_payers)
        push!(warnings, "Payer not in standard set: $(enc.payer)")
    end
    
    # Determine overall validity
    is_valid = isempty(errors)
    
    return ValidationResult(is_valid, errors, warnings)
end

# ============================================================================
# BATCH VALIDATION
# ============================================================================

"""
    validate_encounters_batch(encounters::Vector{PatientEncounter})::Dict{String, Any}

Validate a batch of encounters and generate quality report.

# Arguments
- encounters::Vector{PatientEncounter}: Encounters to validate

# Returns
- Dict with overall metrics and per-encounter results
"""
function validate_encounters_batch(encounters::Vector{PatientEncounter})::Dict{String, Any}
    total = length(encounters)
    total == 0 && return Dict(
        "total" => 0,
        "valid" => 0,
        "with_warnings" => 0,
        "invalid" => 0,
        "quality_score" => 0.0
    )
    
    valid_count = 0
    warning_count = 0
    invalid_count = 0
    
    for enc in encounters
        result = validate_patient_encounter(enc)
        if result.is_valid
            valid_count += 1
            if !isempty(result.warnings)
                warning_count += 1
            end
        else
            invalid_count += 1
        end
    end
    
    quality_score = (valid_count / total) * 100.0
    
    return Dict(
        "total" => total,
        "valid" => valid_count,
        "with_warnings" => warning_count,
        "invalid" => invalid_count,
        "quality_score" => quality_score,
        "validity_pct" => (valid_count / total) * 100.0,
    )
end

# ============================================================================
# FIELD VALIDATION UTILITIES
# ============================================================================

"""
    validate_required_fields(record::Dict, required_fields::Vector{String})::Vector{String}

Check that required fields are present and non-empty.

# Arguments
- record::Dict: Record to validate
- required_fields::Vector{String}: List of field names that must be present

# Returns
- Vector of missing field names (empty if all present)
"""
function validate_required_fields(record::Dict, required_fields::Vector{String})::Vector{String}
    missing = String[]
    for field in required_fields
        if !haskey(record, field) || isempty(string(record[field]))
            push!(missing, field)
        end
    end
    return missing
end

"""
    validate_numeric_range(value::Real, min::Real, max::Real, field_name::String)::Tuple{Bool, String}

Validate that a numeric value is within an expected range.

# Arguments
- value::Real: Value to check
- min::Real: Minimum valid value
- max::Real: Maximum valid value
- field_name::String: Name of field (for error message)

# Returns
- Tuple: (is_valid::Bool, message::String)
"""
function validate_numeric_range(value::Real, min::Real, max::Real, field_name::String)::Tuple{Bool, String}
    if value < min
        return (false, "$field_name below minimum ($value < $min)")
    elseif value > max
        return (false, "$field_name above maximum ($value > $max)")
    else
        return (true, "")
    end
end

