"""
Input validation utilities for boundary checking.
"""

"""
    validate_fips(fips::String)::Bool

Check if string is a valid 5-digit FIPS code.
"""
function validate_fips(fips::String)::Bool
    length(fips) == 5 && all(isdigit, fips)
end

"""
    validate_hospital_beds(beds::Int)::Bool

Check if bed count is valid (≥1, ≤1000).
"""
function validate_hospital_beds(beds::Int)::Bool
    1 <= beds <= 1000
end

"""
    validate_payer_mix(; medicare, medicaid, commercial, self_pay, other)::Bool

Check if payer mix proportions sum to ~1.0.
"""
function validate_payer_mix(; medicare=0.0, medicaid=0.0, commercial=0.0, self_pay=0.0, other=0.0)::Bool
    total = medicare + medicaid + commercial + self_pay + other
    0.99 <= total <= 1.01
end

"""
    validate_year(year::Int)::Bool

Check if year is in reasonable range.
"""
function validate_year(year::Int)::Bool
    1900 <= year <= 2100
end

"""
    validate_percentage(value::Number)::Bool

Check if value is between 0 and 1.
"""
function validate_percentage(value::Number)::Bool
    0 <= value <= 1
end

"""
    validate_positive(value::Number, field::String="value")::Bool

Check if value is positive.
"""
function validate_positive(value::Number, field::String="value")::Bool
    if value <= 0
        throw(DomainValidationError(field, string(value), "> 0", "Value must be positive"))
    end
    true
end

"""
    validate_nonnegative(value::Number, field::String="value")::Bool

Check if value is non-negative.
"""
function validate_nonnegative(value::Number, field::String="value")::Bool
    if value < 0
        throw(DomainValidationError(field, string(value), "≥ 0", "Value cannot be negative"))
    end
    true
end

"""
    validate_not_empty(s::AbstractString, field::String="field")

Check if string is not empty.
"""
function validate_not_empty(s::AbstractString, field::String="field")::Bool
    if isempty(s)
        throw(DataValidationError("$field cannot be empty"))
    end
    true
end

"""
    validate_finite(value::Number, field::String="value")::Bool

Check if value is finite (not NaN or Inf).
"""
function validate_finite(value::Number, field::String="value")::Bool
    if !isfinite(value)
        throw(CalculationError("$field is not finite: $value"))
    end
    true
end
