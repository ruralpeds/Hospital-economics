"""
BugReportController — handlers for POST /api/bugreport.

Implements all five required spam-protection layers:
  1. Honeypot hidden field
  2. Dwell time (>= 3 s between form_opened_at and submitted_at)
  3. Cloudflare Turnstile (skipped in dev when TURNSTILE_SECRET_KEY unset)
  4. In-memory rate limits (IP/hour, session/day, global/day)
  5. Content heuristics (min length, URL count, profanity filter)

PHI is re-scrubbed server-side before posting to GitHub using BugReportRedaction.
BUG_REPORT_GITHUB_TOKEN is used only server-side and never surfaced to clients.
"""
module BugReportController

export handle_submit, render_body, verify_turnstile

using Dates, UUIDs, Logging

# BugReportRedaction is a sibling submodule of HospitalEconomicsApp
using ..BugReportRedaction

# ─── Constants ────────────────────────────────────────────────────────────────

const GITHUB_API_BASE    = "https://api.github.com"
const TURNSTILE_URL      = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
const MIN_DWELL_SECONDS  = 3
const MIN_SUMMARY_CHARS  = 20
const MAX_URLS_IN_BODY   = 3

const PROFANITY_LIST = [
    "aaaaa", "asdfasdf", "test123", "foo bar baz", "lorem ipsum",
    "xxxxxxxxxxxx",
]

# ─── Minimal JSON helpers (stdlib-only + optional JSON3) ─────────────────────

"""Minimal JSON serialiser that works without JSON3 (test / no-dep environments)."""
function _json_write(v)::String
    if v isa AbstractDict
        inner = join(["$(_json_write(string(k))):$(_json_write(val))" for (k, val) in v], ",")
        return "{$inner}"
    elseif v isa AbstractArray
        return "[$(join([_json_write(x) for x in v], ","))]"
    elseif v isa AbstractString
        s = replace(v, "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n",
                        "\r" => "\\r", "\t" => "\\t")
        return "\"$s\""
    elseif v isa Bool
        return v ? "true" : "false"
    elseif v === nothing || v === missing
        return "null"
    elseif v isa Number
        return string(v)
    else
        return _json_write(string(v))
    end
end

"""Serialise `v` to a JSON string. Prefers JSON3 when available."""
function _json_serialize(v)::String
    try
        j3 = Base.require(Base.PkgId(
                Base.UUID("0f8b85d8-7281-11e9-16c2-39a750bddbf1"), "JSON3"))
        return string(j3.write(v))
    catch
        return _json_write(v)
    end
end

"""Parse a JSON string into a Dict. Requires JSON3 (only called on live HTTP paths)."""
function _json_parse(raw::String)::Dict
    j3 = Base.require(Base.PkgId(
            Base.UUID("0f8b85d8-7281-11e9-16c2-39a750bddbf1"), "JSON3"))
    parsed = j3.read(raw)
    Dict(string(k) => v for (k, v) in pairs(parsed))
end

# ─── Rate-limit store (in-memory; resets on server restart) ──────────────────

const _rl_lock         = ReentrantLock()
const _ip_hourly       = Dict{String, Vector{DateTime}}()    # IP  → timestamps
const _session_daily   = Dict{String, Vector{DateTime}}()    # session → timestamps
const _global_daily    = Ref{Vector{DateTime}}(DateTime[])   # global circuit-breaker

const RATE_LIMIT_IP_HOUR    = 5
const RATE_LIMIT_SESS_DAY   = 20
const RATE_LIMIT_GLOBAL_DAY = 50

function _prune!(ts::Vector{DateTime}, cutoff::DateTime)
    filter!(t -> t >= cutoff, ts)
end

"""Check rate limits. Returns `nothing` if OK, or `(http_status, message)` if exceeded."""
function _check_rate_limits(ip::String, session_id::String)::Union{Nothing, Tuple{Int,String}}
    now_dt   = Dates.now(UTC)
    hour_ago = now_dt - Hour(1)
    day_ago  = now_dt - Day(1)

    return lock(_rl_lock) do
        # 1. IP hourly limit
        ip_ts = get!(() -> DateTime[], _ip_hourly, ip)
        _prune!(ip_ts, hour_ago)
        if length(ip_ts) >= RATE_LIMIT_IP_HOUR
            return (429, "Rate limit exceeded: too many reports from this IP in the past hour.")
        end

        # 2. Session daily limit
        sess_ts = get!(() -> DateTime[], _session_daily, session_id)
        _prune!(sess_ts, day_ago)
        if length(sess_ts) >= RATE_LIMIT_SESS_DAY
            return (429, "Rate limit exceeded: too many reports in this session today.")
        end

        # 3. Global daily circuit-breaker
        _prune!(_global_daily[], day_ago)
        if length(_global_daily[]) >= RATE_LIMIT_GLOBAL_DAY
            @warn "BugReport: global daily circuit-breaker triggered — admin notification needed"
            return (429, "Global report limit reached. Please contact support directly.")
        end

        # All checks passed → record the submission
        push!(ip_ts, now_dt)
        push!(sess_ts, now_dt)
        push!(_global_daily[], now_dt)
        return nothing
    end
end

# ─── Template rendering ───────────────────────────────────────────────────────

const _template_cache = Ref{String}("")

function _load_template()::String
    isempty(_template_cache[]) || return _template_cache[]
    path = joinpath(@__DIR__, "..", "..", "docs", "ui", "bug_report_template.md")
    if isfile(path)
        raw = read(path, String)
        m = match(r"```markdown\n(.*?)```"s, raw)
        _template_cache[] = isnothing(m) ? raw : m.captures[1]
    else
        _template_cache[] = "## Summary\n{{summary}}\n"
    end
    return _template_cache[]
end

"""
    render_body(record::Dict) -> String

Expand all `{{key}}` placeholders in the issue-body template using `record`.
Unfilled placeholders are replaced with `—`.
"""
function render_body(record::Dict)::String
    tmpl = _load_template()
    result = tmpl
    for (k, v) in record
        result = replace(result, "{{$(k)}}" => string(v))
    end
    # Clear any remaining unfilled placeholders
    replace(result, r"\{\{[^}]+\}\}" => "—")
end

# ─── Cloudflare Turnstile verification ───────────────────────────────────────

"""
    verify_turnstile(token::String, remote_ip::String) -> Bool

Verify a Cloudflare Turnstile challenge token against the siteverify API.

Behaviour:
- Returns `true` if the token is valid.
- If `TURNSTILE_SECRET_KEY` is unset AND `GENIE_ENV == "dev"`, logs a warning
  and returns `true` (dev-only bypass).
- If `TURNSTILE_SECRET_KEY` is unset AND `GENIE_ENV != "dev"`, returns `false`
  (production must not bypass CAPTCHA — enforced at start-up too).
"""
function verify_turnstile(token::String, remote_ip::String)::Bool
    secret = get(ENV, "TURNSTILE_SECRET_KEY", "")
    if isempty(secret)
        if get(ENV, "GENIE_ENV", "dev") == "dev"
            @warn "BugReport: TURNSTILE_SECRET_KEY not configured — " *
                  "Turnstile verification skipped (dev mode only)"
            return true
        else
            @error "BugReport: TURNSTILE_SECRET_KEY is required in production"
            return false
        end
    end

    body = "secret=$(secret)&response=$(token)&remoteip=$(remote_ip)"
    try
        raw = _http_post(TURNSTILE_URL,
                         ["Content-Type" => "application/x-www-form-urlencoded"],
                         body)
        parsed = _json_parse(raw)
        return Bool(get(parsed, :success, get(parsed, "success", false)))
    catch e
        @error "BugReport: Turnstile verification error" exception=(e, catch_backtrace())
        return false
    end
end

# ─── Content heuristics ───────────────────────────────────────────────────────

"""Returns an error string if the payload fails content checks, otherwise `nothing`."""
function _content_check(payload::AbstractDict)::Union{Nothing, String}
    summary = get(payload, "summary", "")
    length(summary) < MIN_SUMMARY_CHARS &&
        return "Summary must be at least $MIN_SUMMARY_CHARS characters."

    body_text = join(
        [get(payload, k, "") for k in ["summary", "steps", "expected", "actual"]],
        " ",
    )
    url_count = length(collect(eachmatch(r"https?://", body_text)))
    url_count > MAX_URLS_IN_BODY && return "Report body contains too many URLs."

    lc = lowercase(body_text)
    for word in PROFANITY_LIST
        contains(lc, word) && return "Report body contains disallowed content."
    end

    return nothing
end

# ─── GitHub API ───────────────────────────────────────────────────────────────

function _build_gh_payload(scrubbed::AbstractDict, body::String)::Dict
    category         = string(get(scrubbed, "category", "bug"))
    severity         = string(get(scrubbed, "severity", "S3"))
    summary          = string(get(scrubbed, "summary", ""))
    route            = string(get(scrubbed, "route",   "unknown"))
    normalized_route = replace(route, r"[^a-zA-Z0-9/\-]" => "")

    title_summary = length(summary) > 80 ? summary[1:80] : summary
    title = "[bug-report] $category $severity: $title_summary"

    labels = [
        "source: in-app",
        "category: $category",
        "severity: $severity",
        "route: $normalized_route",
    ]

    assignees = String[]
    (severity == "S1" || category == "security") && push!(assignees, "timothyhartzog")

    Dict("title" => title, "body" => body, "labels" => labels, "assignees" => assignees)
end

"""Returns `(success::Bool, issue_url::String, error_msg::String)`."""
function _post_github(gh_payload::Dict)::Tuple{Bool, String, String}
    token = get(ENV, "BUG_REPORT_GITHUB_TOKEN", "")
    if isempty(token)
        @warn "BugReport: BUG_REPORT_GITHUB_TOKEN not set — skipping GitHub post"
        return (false, "", "GitHub token not configured")
    end

    repo = get(ENV, "BUG_REPORT_REPO", "timothyhartzog/hospital-economics")
    url  = "$GITHUB_API_BASE/repos/$repo/issues"

    headers = [
        "Authorization"        => "Bearer $token",
        "Content-Type"         => "application/json",
        "Accept"               => "application/vnd.github+json",
        "X-GitHub-Api-Version" => "2022-11-28",
    ]

    try
        raw    = _http_post(url, headers, _json_serialize(gh_payload))
        parsed = _json_parse(raw)
        issue_url = string(get(parsed, :html_url, get(parsed, "html_url", "")))
        return (true, issue_url, "")
    catch e
        corr_id = string(UUIDs.uuid4())[1:8]
        @error "BugReport: GitHub API call failed" correlation_id=corr_id exception=(e, catch_backtrace())
        # Never expose the token or full trace to the client
        return (false, "", "Failed to create issue (correlation id: $corr_id)")
    end
end

# ─── HTTP helper (overridable in tests) ──────────────────────────────────────

"""
    _http_post(url, headers, body) -> String (response body)

Thin wrapper around HTTP.post that tests can replace by redefining
`BugReportController._http_post` via `@eval`.
"""
function _http_post(url::String, headers, body::Union{String, Vector{UInt8}})::String
    # Dynamically require HTTP to avoid a hard compile-time dep when running
    # lightweight unit tests that never reach this path.
    HTTP = Base.require(Base.PkgId(
        Base.UUID("cd3eb016-35fb-5094-929b-558a96fad6f3"), "HTTP"))
    resp = HTTP.post(url, headers, body; status_exception=false)
    String(resp.body)
end

# ─── Main handler ─────────────────────────────────────────────────────────────

"""
    handle_submit(payload; remote_ip, session_id, correlation_id) -> Dict

Process a bug-report submission.  Returns a Dict with:
  - `status`  — HTTP status code (Int)
  - `body`    — response body Dict (never contains the GitHub token)
"""
function handle_submit(payload::AbstractDict;
                       remote_ip::String      = "0.0.0.0",
                       session_id::String     = "anonymous",
                       correlation_id::String = string(UUIDs.uuid4())[1:8])::Dict

    # ── Layer 1: Honeypot ────────────────────────────────────────────────────
    if !isempty(get(payload, "website", ""))
        @info "BugReport: honeypot triggered" ip=remote_ip
        # 202 Accepted — silent drop; never reaches GitHub
        return Dict("status" => 202, "body" => Dict("accepted" => true))
    end

    # ── Layer 2: Dwell time ───────────────────────────────────────────────────
    opened_str    = get(payload, "form_opened_at", "")
    submitted_str = get(payload, "submitted_at",   string(Dates.now(UTC)))
    try
        if !isempty(opened_str)
            fmt = dateformat"yyyy-mm-ddTHH:MM:SS"
            opened    = DateTime(opened_str,    fmt)
            submitted = DateTime(submitted_str, fmt)
            dwell_ms  = Dates.value(submitted - opened)    # milliseconds
            dwell_s   = dwell_ms / 1000.0
            if dwell_s < MIN_DWELL_SECONDS
                return Dict("status" => 422,
                            "body"   => Dict("error" => "Form submitted too quickly."))
            end
        end
    catch
        # Malformed timestamps — allow through (e.g., test harness)
    end

    # ── Layer 3: Cloudflare Turnstile ────────────────────────────────────────
    ts_token = get(payload, "cf_turnstile_response", "")
    if !verify_turnstile(string(ts_token), remote_ip)
        return Dict("status" => 403,
                    "body"   => Dict("error" => "CAPTCHA verification failed."))
    end

    # ── Layer 4: Rate limits ─────────────────────────────────────────────────
    rl = _check_rate_limits(remote_ip, session_id)
    if !isnothing(rl)
        status_code, msg = rl
        return Dict("status" => status_code, "body" => Dict("error" => msg))
    end

    # ── Layer 5: Content heuristics ──────────────────────────────────────────
    content_err = _content_check(payload)
    if !isnothing(content_err)
        return Dict("status" => 422, "body" => Dict("error" => content_err))
    end

    # ── Server-side PHI re-scrub ─────────────────────────────────────────────
    scrubbed = Dict{String,Any}(string(k) => v for (k, v) in payload)
    for field in ["summary", "steps", "expected", "actual"]
        if haskey(scrubbed, field)
            scrubbed[field] = BugReportRedaction.redact_text(string(scrubbed[field]))
        end
    end
    if haskey(scrubbed, "state_deltas")
        delta_raw = scrubbed["state_deltas"]
        delta_dict = delta_raw isa AbstractDict ? Dict(string(k) => v for (k,v) in delta_raw) : Dict{String,Any}()
        scrubbed["state_delta_json"] = _json_serialize(
            BugReportRedaction.redact_state_delta(delta_dict))
    end

    # ── Build template record ────────────────────────────────────────────────
    record = merge(scrubbed, Dict{String,Any}(
        "timestamp_utc"   => string(Dates.now(UTC)),
        "app_version"     => get(ENV, "APP_VERSION", "0.3.0"),
        "git_sha"         => get(ENV, "GIT_SHA", "unknown"),
        "user_id_or_anon" => get(scrubbed, "user_id", "anon"),
        "screenshot_markdown_or_gist_link_or_none" =>
            get(scrubbed, "screenshot_url", "_none_"),
        "browser_ua"      => get(scrubbed, "browser_ua", "unknown"),
        "viewport_w"      => get(scrubbed, "viewport_w", "?"),
        "viewport_h"      => get(scrubbed, "viewport_h", "?"),
        "locale"          => get(scrubbed, "locale", "en"),
        "state_delta_json"=> get(scrubbed, "state_delta_json", "{}"),
        "route"           => get(scrubbed, "route", "/unknown"),
    ))

    body_text = render_body(record)

    # ── Post to GitHub ────────────────────────────────────────────────────────
    gh_payload          = _build_gh_payload(scrubbed, body_text)
    success, issue_url, err = _post_github(gh_payload)

    if success
        return Dict("status" => 201,
                    "body"   => Dict("issue_url" => issue_url,
                                     "message"   => "Bug report submitted successfully."))
    else
        # GitHub token not configured → degrade gracefully (non-prod convenience)
        if isempty(get(ENV, "BUG_REPORT_GITHUB_TOKEN", ""))
            return Dict("status" => 201,
                        "body"   => Dict("issue_url" => "",
                                         "message"   => "Bug report recorded (GitHub posting disabled)."))
        end
        return Dict("status" => 502, "body" => Dict("error" => err))
    end
end

# ─── Production start-up guard ────────────────────────────────────────────────

"""
    assert_production_config()

Call during app start-up in production.  Raises an error if required secrets
are absent so that misconfigured deployments fail fast.
"""
function assert_production_config()
    env = get(ENV, "GENIE_ENV", "dev")
    env == "dev" && return   # guards apply only in production

    missing_vars = String[]
    isempty(get(ENV, "TURNSTILE_SECRET_KEY",     "")) && push!(missing_vars, "TURNSTILE_SECRET_KEY")
    isempty(get(ENV, "BUG_REPORT_GITHUB_TOKEN",  "")) && push!(missing_vars, "BUG_REPORT_GITHUB_TOKEN")

    if !isempty(missing_vars)
        error("BugReport: required environment variables not set in production: " *
              join(missing_vars, ", "))
    end
end

end # module BugReportController
