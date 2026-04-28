"""
BugReportRedaction — server-side PHI redaction for the BugReport component.

Provides:
- `redact_text(str)` — apply all PHI patterns to a single string.
- `redact_state_delta(delta)` — recursively redact all string values in a Dict.

The same regex patterns are mirrored in client-side JS (see bug_report.jl) so
that redaction runs both before the network call AND before posting to GitHub.

PHI patterns covered:
  SSN, DOB, MRN, phone, email, insurance IDs, street addresses, and
  best-effort name matching against data/reference/pii_names.txt.
"""
module BugReportRedaction

export redact_text, redact_state_delta

using Dates

# ─── Regex patterns ───────────────────────────────────────────────────────────

"""Ordered list of (pattern, replacement) tuples applied by `redact_text`."""
const PHI_PATTERNS = [
    # SSN (dashed): 123-45-6789
    (r"\b\d{3}-\d{2}-\d{4}\b",                    "[SSN]"),
    # DOB: MM/DD/YYYY or MM-DD-YYYY or M/D/YYYY
    (r"\b(0?[1-9]|1[012])[-/](0?[1-9]|[12]\d|3[01])[-/](19|20)\d{2}\b", "[DOB]"),
    # MRN: MRN: 12345678 or MRN 12345678 (4–12 digits)
    (r"(?i)\bMRN[:\s]*\d{4,12}\b",                "[MRN]"),
    # Phone (run BEFORE bare SSN to consume formatted numbers first):
    # (800) 555-1234 / 800-555-1234 / +1.800.555.1234 etc.
    (r"\b(\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b", "[PHONE]"),
    # SSN (bare 9-digit): applied after phone so formatted numbers are already gone
    (r"\b\d{9}\b",                                  "[SSN]"),
    # Email
    (r"\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b", "[EMAIL]"),
    # Insurance member/claim/group IDs (keyword-prefixed)
    (r"(?i)\b(member|claim|group|policy|subscriber|plan|beneficiary)\s*(id|#|no\.?|number)[:\s#]*[A-Z0-9\-]{4,20}\b",
     "[INSURANCE_ID]"),
    # Generic alphanumeric IDs that look like insurance IDs (2–4 alpha prefix + 7–12 digits)
    (r"\b[A-Z]{2,4}\d{7,12}\b",                   "[INSURANCE_ID]"),
    # Street addresses: "123 Main Street" / "45 Oak Ave"
    (r"(?i)\b\d{1,5}\s+[A-Za-z]+\s+(Street|St\.?|Avenue|Ave\.?|Boulevard|Blvd\.?|Road|Rd\.?|Drive|Dr\.?|Lane|Ln\.?|Court|Ct\.?|Place|Pl\.?|Way|Circle|Cir\.?|Highway|Hwy)\b",
     "[ADDRESS]"),
    # ZIP codes (standalone 5-digit or ZIP+4)
    (r"\b\d{5}(-\d{4})?\b",                       "[ZIP]"),
]

# ─── Name list (loaded lazily) ────────────────────────────────────────────────

const _name_set        = Set{String}()
const _name_list_ready = Ref(false)
const _name_load_lock  = ReentrantLock()

function _ensure_name_list_loaded()
    _name_list_ready[] && return
    lock(_name_load_lock) do
        _name_list_ready[] && return
        path = joinpath(@__DIR__, "..", "..", "data", "reference", "pii_names.txt")
        if isfile(path)
            for raw in eachline(path)
                word = strip(raw)
                isempty(word) || startswith(word, '#') && continue
                push!(_name_set, lowercase(word))
            end
        end
        _name_list_ready[] = true
    end
end

# ─── Public API ───────────────────────────────────────────────────────────────

"""
    redact_text(str::String) -> String

Apply all configured PHI redaction patterns to `str`.
Mutates no input; returns a new scrubbed string.
"""
function redact_text(str::String)::String
    result = str
    for (pat, rep) in PHI_PATTERNS
        result = replace(result, pat => rep)
    end

    # Best-effort name redaction: replace words that appear in the name list.
    _ensure_name_list_loaded()
    if !isempty(_name_set)
        result = replace(result, r"\b[A-Za-z]+\b" => function(word)
            lowercase(word) in _name_set ? "[name]" : word
        end)
    end

    return result
end

"""
    redact_state_delta(delta::AbstractDict) -> Dict

Recursively apply PHI redaction to every String value in `delta`.
Non-string scalar values are passed through unchanged.
"""
function redact_state_delta(delta::AbstractDict)::Dict
    Dict(string(k) => _redact_value(v) for (k, v) in delta)
end

# ─── Internal helpers ─────────────────────────────────────────────────────────

_redact_value(v::String)              = redact_text(v)
_redact_value(v::AbstractDict)        = redact_state_delta(v)
_redact_value(v::AbstractArray)       = [_redact_value(x) for x in v]
_redact_value(v)                      = v   # numeric, bool, nothing → unchanged

end # module BugReportRedaction
