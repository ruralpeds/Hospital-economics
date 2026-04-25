"""
Bug reporting utilities.

Provides the `BugReport` type used to capture end-user bug reports submitted
through the portal, plus helpers for formatting GitHub issues and scoring
submissions for likely spam.

Privacy: `contact_email` is **never** included in GitHub issue bodies. It is
only persisted server-side so the team can follow up with the user directly.
"""

using UUIDs
using Dates

# ── Severity ─────────────────────────────────────────────────────────────────
@enum BugReportSeverity SEVERITY_LOW SEVERITY_MEDIUM SEVERITY_HIGH SEVERITY_CRITICAL

"""
    severity_label(s::BugReportSeverity) -> String

Human-readable severity label used in issue titles and the admin UI.
"""
function severity_label(s::BugReportSeverity)::String
    s == SEVERITY_CRITICAL && return "Critical"
    s == SEVERITY_HIGH     && return "High"
    s == SEVERITY_LOW      && return "Low"
    return "Medium"
end

"""
    severity_github_label(s::BugReportSeverity) -> String

GitHub issue-label form (lowercase, colon-prefixed) used for filtering.
"""
function severity_github_label(s::BugReportSeverity)::String
    s == SEVERITY_CRITICAL && return "severity: critical"
    s == SEVERITY_HIGH     && return "severity: high"
    s == SEVERITY_LOW      && return "severity: low"
    return "severity: medium"
end

# ── Category ─────────────────────────────────────────────────────────────────
@enum BugReportCategory begin
    CATEGORY_CALCULATION
    CATEGORY_DATA
    CATEGORY_UI_UX
    CATEGORY_PERFORMANCE
    CATEGORY_DOCUMENTATION
    CATEGORY_OTHER
end

"""
    category_label(c::BugReportCategory) -> String
"""
function category_label(c::BugReportCategory)::String
    c == CATEGORY_CALCULATION   && return "Calculation Error"
    c == CATEGORY_DATA          && return "Data Issue"
    c == CATEGORY_UI_UX         && return "UI/UX"
    c == CATEGORY_PERFORMANCE   && return "Performance"
    c == CATEGORY_DOCUMENTATION && return "Documentation"
    return "Other"
end

"""
    category_github_label(c::BugReportCategory) -> String
"""
function category_github_label(c::BugReportCategory)::String
    c == CATEGORY_CALCULATION   && return "calculation"
    c == CATEGORY_DATA          && return "data"
    c == CATEGORY_UI_UX         && return "ui/ux"
    c == CATEGORY_PERFORMANCE   && return "performance"
    c == CATEGORY_DOCUMENTATION && return "documentation"
    return "other"
end

# ── BugReport struct ─────────────────────────────────────────────────────────
"""
    BugReport(; title, description, ...)

A bug report captured from an end user via the portal's submission form.

Only `title` and `description` are required. Optional fields improve issue
triage and are surfaced in the GitHub issue body, except `contact_email`
which is held server-side only.
"""
Base.@kwdef struct BugReport
    id::UUID                        = uuid4()
    submitted_at::DateTime          = Dates.now(Dates.UTC)

    title::String
    description::String

    steps_to_reproduce::String      = ""
    expected_behavior::String       = ""
    actual_behavior::String         = ""

    severity::BugReportSeverity     = SEVERITY_MEDIUM
    category::BugReportCategory     = CATEGORY_OTHER

    app_name::String                = "portal"
    app_version::String             = ""

    # Server-side only — never serialized into the GitHub issue body.
    contact_email::String           = ""

    session_id::String              = ""
    browser_info::String            = ""
    platform_url::String            = ""
end

function Base.show(io::IO, r::BugReport)
    print(io, "BugReport(", severity_label(r.severity), " ", category_label(r.category),
              " — \"", r.title, "\")")
end

# ── Formatters for GitHub Issues ─────────────────────────────────────────────

"""
    format_github_issue_title(r::BugReport) -> String

Produce a GitHub issue title in the form:
`[<Severity>] [<Category>] <user title>` (trimmed to ≤256 chars to
respect the GitHub API limit).
"""
function format_github_issue_title(r::BugReport)::String
    prefix = "[$(severity_label(r.severity))] [$(category_label(r.category))] "
    title  = r.title
    max_user_len = 256 - length(prefix)
    if length(title) > max_user_len
        title = title[1:max(1, max_user_len - 1)] * "…"
    end
    return prefix * title
end

# Remove characters that break Markdown formatting or would be interpreted as
# code-fence terminators inside a ```-delimited block.
_clean_md(s::AbstractString) = replace(String(s), "```" => "'''")

"""
    format_github_issue_body(r::BugReport) -> String

Format the issue body as Markdown. `contact_email` is intentionally omitted.
"""
function format_github_issue_body(r::BugReport)::String
    io = IOBuffer()
    println(io, "## Bug Report")
    println(io)
    println(io, "**App:** ", r.app_name,
            isempty(r.app_version) ? "" : " (v$(r.app_version))")
    println(io, "**Severity:** ", severity_label(r.severity))
    println(io, "**Category:** ", category_label(r.category))
    println(io, "**Submitted:** ", Dates.format(r.submitted_at, "yyyy-mm-dd HH:MM:SS"), " UTC")
    println(io, "**Report ID:** `", string(r.id), "`")
    println(io)

    println(io, "### Description")
    println(io)
    println(io, _clean_md(r.description))
    println(io)

    if !isempty(r.steps_to_reproduce)
        println(io, "### Steps to Reproduce")
        println(io)
        println(io, _clean_md(r.steps_to_reproduce))
        println(io)
    end

    if !isempty(r.expected_behavior)
        println(io, "### Expected Behavior")
        println(io)
        println(io, _clean_md(r.expected_behavior))
        println(io)
    end

    if !isempty(r.actual_behavior)
        println(io, "### Actual Behavior")
        println(io)
        println(io, _clean_md(r.actual_behavior))
        println(io)
    end

    println(io, "### System Information")
    println(io)
    println(io, "- **Platform URL:** ", isempty(r.platform_url) ? "_not provided_" : r.platform_url)
    println(io, "- **Browser:** ", isempty(r.browser_info) ? "_not provided_" : _clean_md(r.browser_info))
    println(io, "- **Session:** ", isempty(r.session_id) ? "_anonymous_" : _clean_md(r.session_id))
    println(io)

    println(io, "---")
    println(io, "_Submitted anonymously via the RuralHealthPlatform bug report form._")
    println(io, "_Reporter contact details (if any) are retained internally and **not** published here._")

    return String(take!(io))
end

"""
    github_issue_labels(r::BugReport) -> Vector{String}

Return the canonical set of labels applied to every forwarded issue:
`"bug"` plus the severity and category labels.
"""
function github_issue_labels(r::BugReport)::Vector{String}
    return String["bug", severity_github_label(r.severity), category_github_label(r.category)]
end

# ── Spam scoring ─────────────────────────────────────────────────────────────

"""
    BugReportSpamResult

Result of `score_bug_report_spam`:

- `score::Int` — total spam score (higher = more suspicious).
- `reasons::Vector{String}` — human-readable heuristics that fired.
- `is_spam::Bool` — true iff `score ≥ threshold`.
"""
struct BugReportSpamResult
    score::Int
    reasons::Vector{String}
    is_spam::Bool
end

const _SPAM_THRESHOLD_DEFAULT = 6

# Bag-of-tokens for common English-language spam content. These are applied
# case-insensitively; they are intentionally conservative so real reports with
# words like "loan" used in context don't get flagged on their own.
const _SPAM_TOKENS = String[
    "viagra", "cialis", "casino", "poker", "bitcoin giveaway", "crypto giveaway",
    "sex cam", "adult cam", "porn", "escort service", "weight loss pill",
    "replica watch", "replica handbag", "nude photo", "hot singles",
    "make money fast", "work from home \$", "click here to win",
    "free iphone", "free ipad", "seo services", "backlinks",
]

function _count_urls(s::AbstractString)::Int
    # Count explicit URL-like substrings without pulling in a regex dependency.
    n = 0
    for marker in ("http://", "https://", "www.")
        idx = 1
        while true
            pos = findnext(marker, s, idx)
            pos === nothing && break
            n   += 1
            idx = last(pos) + 1
        end
    end
    return n
end

function _uppercase_ratio(s::AbstractString)::Float64
    letters = count(isletter, s)
    letters == 0 && return 0.0
    uppers  = count(c -> isletter(c) && isuppercase(c), s)
    return uppers / letters
end

function _repeat_run(s::AbstractString)::Int
    run   = 1
    best  = 1
    prev  = '\0'
    for c in s
        if c == prev
            run += 1
            best = max(best, run)
        else
            run  = 1
        end
        prev = c
    end
    return best
end

"""
    score_bug_report_spam(r::BugReport; threshold = 6) -> BugReportSpamResult

Heuristic spam scoring for a `BugReport`. Applied **after** the honeypot and
rate-limit checks, this acts as a final content-based filter before forwarding
to GitHub.

Scoring signals:

| Signal                                          | Points |
|-------------------------------------------------|-------:|
| Description shorter than 20 characters           |     3 |
| Description contains 2+ URLs                     |     2 |
| Description contains 4+ URLs                     |   +3 |
| Title contains a URL                             |     2 |
| >60% of title letters uppercase (length > 8)     |     2 |
| >50% of body letters uppercase (length > 50)     |     2 |
| Repeated character run ≥ 10 (e.g. "aaaaaaaaaa") |     2 |
| Any spam token matched (case-insensitive)        |     4 |
| No whitespace anywhere in description            |     2 |
| Contact email contains suspicious TLD            |     2 |

Returns a `BugReportSpamResult`; caller decides whether to honor `is_spam`.
"""
function score_bug_report_spam(r::BugReport;
                               threshold::Int = _SPAM_THRESHOLD_DEFAULT)::BugReportSpamResult
    score   = 0
    reasons = String[]

    desc = r.description
    ttl  = r.title
    body_lc = lowercase(desc * " " * r.steps_to_reproduce * " " *
                        r.expected_behavior * " " * r.actual_behavior)

    if length(desc) < 20
        score += 3
        push!(reasons, "description too short (<20 chars)")
    end

    n_urls = _count_urls(desc) + _count_urls(r.steps_to_reproduce)
    if n_urls >= 2
        score += 2
        push!(reasons, "description contains $n_urls URLs")
    end
    if n_urls >= 4
        score += 3
        push!(reasons, "description contains $n_urls URLs (very high)")
    end

    if _count_urls(ttl) >= 1
        score += 2
        push!(reasons, "title contains URL")
    end

    if length(ttl) > 8 && _uppercase_ratio(ttl) > 0.6
        score += 2
        push!(reasons, "title is mostly uppercase")
    end

    if length(desc) > 50 && _uppercase_ratio(desc) > 0.5
        score += 2
        push!(reasons, "description is mostly uppercase")
    end

    if _repeat_run(desc) >= 10 || _repeat_run(ttl) >= 10
        score += 2
        push!(reasons, "repeated-character run detected")
    end

    for tok in _SPAM_TOKENS
        if occursin(tok, body_lc)
            score += 4
            push!(reasons, "matched spam token: $tok")
            break  # one hit is enough
        end
    end

    if !isempty(desc) && !any(isspace, desc)
        score += 2
        push!(reasons, "description has no whitespace")
    end

    if !isempty(r.contact_email)
        el = lowercase(r.contact_email)
        # A handful of TLDs are overwhelmingly used for disposable / spam mail.
        for suffix in (".ru", ".top", ".xyz", ".click", ".work", ".loan")
            if endswith(el, suffix)
                score += 2
                push!(reasons, "contact email uses suspicious TLD ($suffix)")
                break
            end
        end
    end

    return BugReportSpamResult(score, reasons, score >= threshold)
end
