"""
HIPAA Safe Harbor PHI scrubbing and detection.

Regex-based detection and redaction of the 18 HIPAA Safe Harbor identifiers
(45 CFR §164.514(b)(2)) for use in logs, error messages, and exported data.

Ported from `cah-telemetry::hipaa` (Rust). Extended to cover the full 18-identifier
list with categorization and richer detection metadata.
"""
module PhiScrubber

export PHIPattern, ScrubResult, HIPAA_PHI_PATTERNS
export scrub_phi, detect_phi, phi_safe, scrub_dict, scrub_log_message
export add_custom_pattern!

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

"""
    PHIPattern

A named regex pattern describing one class of Protected Health Information.

Fields:
- `name`        : human-readable identifier (e.g. "SSN", "MRN", "Phone")
- `regex`       : compiled `Regex` used for matching
- `replacement` : token substituted in scrubbed output (e.g. "[REDACTED-SSN]")
- `category`    : one of `:direct_identifier`, `:quasi_identifier`, `:phi_special`
"""
struct PHIPattern
    name::String
    regex::Regex
    replacement::String
    category::Symbol
end

"""
    ScrubResult

Result of scrubbing a string for PHI.

Fields:
- `original`   : the input text
- `scrubbed`   : the text with PHI replaced by redaction tokens
- `redactions` : per-match record of `(pattern, start, length)` in the *original* text
- `phi_found`  : `true` if any pattern matched
"""
struct ScrubResult
    original::String
    scrubbed::String
    redactions::Vector{NamedTuple{(:pattern, :start, :length), Tuple{String, Int, Int}}}
    phi_found::Bool
end

# ---------------------------------------------------------------------------
# HIPAA Safe Harbor identifiers (18)
#
# 1.  Names
# 2.  Geographic subdivisions smaller than a state (street, city, county, ZIP)
# 3.  Dates (other than year) directly related to an individual
# 4.  Telephone numbers
# 5.  Fax numbers
# 6.  Email addresses
# 7.  Social Security numbers
# 8.  Medical record numbers
# 9.  Health-plan beneficiary numbers
# 10. Account numbers
# 11. Certificate / license numbers
# 12. Vehicle identifiers and serial numbers (incl. license plates)
# 13. Device identifiers and serial numbers
# 14. Web URLs
# 15. IP addresses (v4 and v6)
# 16. Biometric identifiers (out of scope for regex; flagged via custom patterns)
# 17. Full-face photographs and comparable images (out of scope)
# 18. Any other unique identifying number, characteristic, or code
# ---------------------------------------------------------------------------

const HIPAA_PHI_PATTERNS = PHIPattern[
    # 4/5. Phone / Fax -- North American 10-digit (runs before SSN so a phone
    # like "555-123-4567" is not partially consumed by the looser SSN regex).
    PHIPattern(
        "Phone",
        r"\b\d{3}[-.\s]\d{3}[-.\s]\d{4}\b",
        "[REDACTED-PHONE]",
        :direct_identifier,
    ),
    # 7. SSN  -- nine digits with optional separators
    PHIPattern(
        "SSN",
        r"\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b",
        "[REDACTED-SSN]",
        :direct_identifier,
    ),
    # 6. Email
    PHIPattern(
        "Email",
        r"\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b",
        "[REDACTED-EMAIL]",
        :direct_identifier,
    ),
    # 8. Medical Record Number (labeled form)
    PHIPattern(
        "MRN",
        r"\bMRN[:\s]*\d+\b",
        "[REDACTED-MRN]",
        :direct_identifier,
    ),
    # 8. Medical Record Number (alphanumeric form, e.g. AB123456)
    PHIPattern(
        "MRN-Alpha",
        r"\b[A-Z]{1,3}\d{6,10}\b",
        "[REDACTED-MRN]",
        :direct_identifier,
    ),
    # 9. Medicare Beneficiary Identifier (MBI)
    PHIPattern(
        "MBI",
        r"\b[1-9][A-Z]\d[A-Z\d]\d[A-Z\d]\d[A-Z]{2}\d{2}\b",
        "[REDACTED-MBI]",
        :direct_identifier,
    ),
    # 3. Dates of birth / service dates (MM/DD/YYYY, M-D-YY, etc.)
    PHIPattern(
        "Date",
        r"\b\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}\b",
        "[REDACTED-DATE]",
        :quasi_identifier,
    ),
    # 2. ZIP code -- only full 5-digit (3-digit prefix permitted by Safe Harbor)
    PHIPattern(
        "ZIP",
        r"\b\d{5}(?:-\d{4})?\b",
        "[REDACTED-ZIP]",
        :quasi_identifier,
    ),
    # 10. Account numbers (labeled)
    PHIPattern(
        "Account",
        r"\b(?:Acct|Account)[#:\s]*[A-Z0-9\-]{4,}\b"i,
        "[REDACTED-ACCOUNT]",
        :direct_identifier,
    ),
    # 11. Certificate / license numbers (labeled)
    PHIPattern(
        "License",
        r"\b(?:License|Lic|Cert)[#:\s]*[A-Z0-9\-]{4,}\b"i,
        "[REDACTED-LICENSE]",
        :direct_identifier,
    ),
    # 12. Vehicle / VIN (17-char) and license plates (labeled)
    PHIPattern(
        "VIN",
        r"\b[A-HJ-NPR-Z0-9]{17}\b",
        "[REDACTED-VIN]",
        :direct_identifier,
    ),
    PHIPattern(
        "Plate",
        r"\b(?:Plate|Tag)[#:\s]*[A-Z0-9\-]{4,8}\b"i,
        "[REDACTED-PLATE]",
        :direct_identifier,
    ),
    # 14. Web URLs
    PHIPattern(
        "URL",
        r"https?://[^\s<>\"']+",
        "[REDACTED-URL]",
        :direct_identifier,
    ),
    # 15. IPv4
    PHIPattern(
        "IPv4",
        r"\b(?:\d{1,3}\.){3}\d{1,3}\b",
        "[REDACTED-IP]",
        :direct_identifier,
    ),
    # 15. IPv6 (covers compressed forms via "::")
    PHIPattern(
        "IPv6",
        r"\b(?:[A-Fa-f0-9]{1,4}:){2,7}[A-Fa-f0-9]{1,4}\b|::[A-Fa-f0-9:]+",
        "[REDACTED-IP]",
        :direct_identifier,
    ),
    # 1. Names -- heuristic only: Title + Capitalized name(s)
    PHIPattern(
        "Name",
        r"\b(?:Mr|Mrs|Ms|Dr|Prof)\.?\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b",
        "[REDACTED-NAME]",
        :phi_special,
    ),
    # 18. Generic long numeric/alpha sequences that look like unique IDs
    PHIPattern(
        "PatientID",
        r"\b(?:Patient|Pt|PT)[#:\s]*\d{4,}\b"i,
        "[REDACTED-PATIENT-ID]",
        :phi_special,
    ),
]

# ---------------------------------------------------------------------------
# Core scrubbing API
# ---------------------------------------------------------------------------

"""
    detect_phi(text::String) -> Vector{NamedTuple}

Return one named-tuple per match describing what PHI was found:
`(pattern, start, length, matched)`. Useful for auditing without modifying text.
"""
function detect_phi(text::String)::Vector{NamedTuple}
    out = NamedTuple[]
    for p in HIPAA_PHI_PATTERNS
        for m in eachmatch(p.regex, text)
            push!(out, (
                pattern = p.name,
                start = m.offset,
                length = sizeof(m.match),
                matched = String(m.match),
            ))
        end
    end
    return out
end

"""
    phi_safe(text::String) -> Bool

`true` iff no PHI pattern matches `text`.
"""
phi_safe(text::String)::Bool = !any(occursin(p.regex, text) for p in HIPAA_PHI_PATTERNS)

"""
    scrub_phi(text; patterns=HIPAA_PHI_PATTERNS) -> ScrubResult

Replace every match of every pattern with that pattern's `replacement` token.
Patterns are applied in declaration order; earlier matches win where ranges overlap.
"""
function scrub_phi(text::String; patterns::Vector{PHIPattern}=HIPAA_PHI_PATTERNS)::ScrubResult
    redactions = NamedTuple{(:pattern, :start, :length), Tuple{String, Int, Int}}[]
    scrubbed = text
    for p in patterns
        for m in eachmatch(p.regex, text)
            push!(redactions, (
                pattern = p.name,
                start = m.offset,
                length = sizeof(m.match),
            ))
        end
        scrubbed = replace(scrubbed, p.regex => p.replacement)
    end
    return ScrubResult(text, scrubbed, redactions, !isempty(redactions))
end

"""
    scrub_dict(d::Dict; recursive=true) -> Dict

Walk a dictionary scrubbing every string value. When `recursive=true`, descends
into nested `Dict` and `AbstractVector` values.
"""
function scrub_dict(d::AbstractDict; recursive::Bool=true)::Dict
    out = Dict{Any, Any}()
    for (k, v) in d
        out[k] = _scrub_value(v; recursive=recursive)
    end
    return out
end

function _scrub_value(v; recursive::Bool=true)
    if v isa AbstractString
        return scrub_phi(String(v)).scrubbed
    elseif recursive && v isa AbstractDict
        return scrub_dict(v; recursive=true)
    elseif recursive && v isa AbstractVector
        return [_scrub_value(x; recursive=true) for x in v]
    else
        return v
    end
end

"""
    scrub_log_message(message::String) -> String

Drop-in replacement for log middleware: returns the scrubbed message only.
"""
scrub_log_message(message::String)::String = scrub_phi(message).scrubbed

"""
    add_custom_pattern!(patterns, name, regex, replacement, category) -> Vector{PHIPattern}

Append a custom `PHIPattern` to the provided vector (typically a copy of
`HIPAA_PHI_PATTERNS`) so callers can extend the scrubber for site-specific IDs
without mutating the shared default.
"""
function add_custom_pattern!(
    patterns::Vector{PHIPattern},
    name::AbstractString,
    regex::Regex,
    replacement::AbstractString,
    category::Symbol,
)::Vector{PHIPattern}
    push!(patterns, PHIPattern(String(name), regex, String(replacement), category))
    return patterns
end

end # module PhiScrubber
