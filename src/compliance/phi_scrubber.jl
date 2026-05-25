# PHI Scrubbing — HIPAA Safe Harbor De-identification
#
# Detects and redacts Protected Health Information (PHI) from free text using
# regex-based pattern matching. Covers the 18 HIPAA Safe Harbor identifiers
# that are amenable to pattern recognition: SSN, MRN, DOB, email, phone.

# ============================================================================
# Types
# ============================================================================

"""
    PHIPattern

A named regex pattern that matches a specific category of PHI.

# Fields
- `name::String`: human-readable category (e.g. "SSN", "MRN", "Email")
- `regex::Regex`: compiled regular expression to match the pattern
- `replacement::String`: redaction placeholder (e.g. "[SSN-REDACTED]")
"""
struct PHIPattern
    name::String
    regex::Regex
    replacement::String
end

# ============================================================================
# Default Patterns
# ============================================================================

"""
    default_phi_patterns() -> Vector{PHIPattern}

Return the standard set of PHI detection patterns covering:
- **SSN**: Social Security Numbers (###-##-####)
- **MRN**: Medical Record Numbers (MRN followed by 6–10 digits)
- **DOB**: Dates of birth (M/D/YYYY format)
- **Email**: Email addresses
- **Phone**: US phone numbers (with optional area code parentheses)
"""
function default_phi_patterns()::Vector{PHIPattern}
    return [
        PHIPattern("SSN", r"\b\d{3}-\d{2}-\d{4}\b", "[SSN-REDACTED]"),
        PHIPattern("MRN", r"\bMRN[:\s]?\d{6,10}\b"i, "[MRN-REDACTED]"),
        PHIPattern("DOB", r"\b\d{1,2}/\d{1,2}/\d{4}\b", "[DOB-REDACTED]"),
        PHIPattern("Email", r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b", "[EMAIL-REDACTED]"),
        PHIPattern("Phone", r"\b\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b", "[PHONE-REDACTED]"),
    ]
end

# ============================================================================
# Core Functions
# ============================================================================

"""
    scrub_phi(text::String; patterns=default_phi_patterns()) -> String

Remove all PHI from `text` by replacing each match with its redaction placeholder.

Patterns are applied sequentially; earlier patterns take precedence where
matches overlap.

# Arguments
- `text::String`: input text potentially containing PHI
- `patterns`: vector of `PHIPattern` to apply (defaults to `default_phi_patterns()`)

# Returns
- `String`: scrubbed text with PHI replaced by redaction placeholders
"""
function scrub_phi(text::String; patterns=default_phi_patterns())::String
    result = text
    for pat in patterns
        result = replace(result, pat.regex => pat.replacement)
    end
    return result
end

"""
    detect_phi(text::String; patterns=default_phi_patterns()) -> Vector{NamedTuple}

Scan `text` for PHI matches without modifying the text.

Returns a vector of named tuples, one per match, with:
- `category::String`: the PHI category name (e.g. "SSN")
- `match_text::String`: the matched text
- `position::UnitRange{Int}`: byte offset range of the match in the input

# Arguments
- `text::String`: input text to scan
- `patterns`: vector of `PHIPattern` to apply (defaults to `default_phi_patterns()`)

# Returns
- `Vector{NamedTuple}`: detected PHI instances with category, text, and position
"""
function detect_phi(text::String; patterns=default_phi_patterns())::Vector{NamedTuple}
    findings = NamedTuple[]

    for pat in patterns
        for m in eachmatch(pat.regex, text)
            push!(findings, (
                category = pat.name,
                match_text = m.match,
                position = m.offset:(m.offset + length(m.match) - 1),
            ))
        end
    end

    # Sort by position for consistent output ordering
    sort!(findings, by=f -> first(f.position))
    return findings
end
