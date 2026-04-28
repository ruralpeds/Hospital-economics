# BugReport Component — `bug_report_button`

## Overview

`bug_report_button()` is a reusable Genie + Stipple component (E27) that lets
end-users file structured bug reports from anywhere in the app.  Reports are
posted as GitHub issues via the REST API, with layered spam protection and
HIPAA-aware PHI redaction.

The component is wired into `app/views/layouts/app_layout.jl` exactly once,
so every current and future tab inherits it without any per-tab code changes.

---

## Usage

```julia
# Called automatically from app_layout.jl — no per-tab changes needed.
bug_report_button(; position = :bottom_right)
```

**Parameters**

| Name       | Type     | Default          | Description                               |
|------------|----------|------------------|-------------------------------------------|
| `position` | `Symbol` | `:bottom_right`  | FAB corner: `:bottom_right`, `:bottom_left`, `:top_right`, `:top_left` |

---

## Architecture

```
Browser                            Server (Julia)
──────                             ──────────────
[FAB button]  →  click             
[Dialog opens]                     
  • Dwell timer starts             
  • Turnstile widget loads         
  • User fills form                
  • Client-side PHI redaction      
  • fetch() POST /api/bugreport  →  BugReportController.handle_submit()
                                     ├─ Layer 1: Honeypot check
                                     ├─ Layer 2: Dwell time (>= 3 s)
                                     ├─ Layer 3: Turnstile verify
                                     ├─ Layer 4: Rate limits
                                     │           (IP/hour, session/day, global/day)
                                     ├─ Layer 5: Content heuristics
                                     ├─ Server-side PHI re-scrub
                                     ├─ render_body() → Markdown from template
                                     └─ POST /repos/{owner}/{repo}/issues
                                          (BUG_REPORT_GITHUB_TOKEN — server only)
[Success toast / error message] ←  {issue_url, message}  or  {error}
```

---

## Spam-Protection Layers

All five layers are required and independently unit-tested:

| Layer | Mechanism | Rejection |
|-------|-----------|-----------|
| 1 | **Honeypot** hidden `<input name="website">` | 202 silent drop |
| 2 | **Dwell time** — `submitted_at - form_opened_at < 3 s` | 422 |
| 3 | **Cloudflare Turnstile** — widget + server `siteverify` | 403 |
| 4 | **Rate limits** — 5/hr/IP · 20/day/session · 50/day global | 429 |
| 5 | **Content heuristics** — min 20-char summary, max 3 URLs, profanity filter | 422 |

---

## PHI Redaction

Redaction runs **twice**:

1. **Client-side** (JavaScript) — before the `fetch()` POST to `/api/bugreport`.
2. **Server-side** (Julia) — inside `BugReportController.handle_submit()` before
   the body is rendered and posted to GitHub.

Both passes use the same regex corpus defined in
`app/components/bug_report_redaction.jl`:

| Pattern | Replacement |
|---------|-------------|
| SSN `\b\d{3}-\d{2}-\d{4}\b` | `[SSN]` |
| DOB `MM/DD/YYYY` or `MM-DD-YYYY` | `[DOB]` |
| MRN `MRN: 12345678` | `[MRN]` |
| Phone (US formats) | `[PHONE]` |
| Email address | `[EMAIL]` |
| Insurance IDs (member/claim/group/policy/subscriber) | `[INSURANCE_ID]` |
| Street addresses | `[ADDRESS]` |
| ZIP codes | `[ZIP]` |
| Names (best-effort, from `data/reference/pii_names.txt`) | `[name]` |

Screenshot: DOM elements with class `.phi` are blanked before html2canvas capture.

---

## Environment Variables

All vars live in `.env` (never committed).  See `.env.example` for the full list.

| Variable | Required in prod | Description |
|----------|-----------------|-------------|
| `BUG_REPORT_GITHUB_TOKEN` | ✅ | GitHub PAT with `repo` scope — **server-side only** |
| `BUG_REPORT_REPO` | ✅ | `owner/repo` for filed issues |
| `TURNSTILE_SITE_KEY` | ✅ | Cloudflare Turnstile public key (safe to embed in HTML) |
| `TURNSTILE_SECRET_KEY` | ✅ | Cloudflare Turnstile secret key — **server-side only** |

> **Security**: `BUG_REPORT_GITHUB_TOKEN` and `TURNSTILE_SECRET_KEY` are
> **never** rendered into HTML, JavaScript bundles, or API responses.

### Dev mode

When `TURNSTILE_SECRET_KEY` is unset and `GENIE_ENV=dev`, Turnstile verification
is **skipped with a logged warning**.  In production (`GENIE_ENV != "dev"`),
the server refuses to start if either `TURNSTILE_SECRET_KEY` or
`BUG_REPORT_GITHUB_TOKEN` is missing.

---

## Files

| File | Purpose |
|------|---------|
| `app/components/bug_report.jl` | `bug_report_button()` — FAB + dialog HTML/JS |
| `app/components/bug_report_redaction.jl` | `redact_text`, `redact_state_delta` |
| `app/components/bug_report_assets/html2canvas.min.js` | CDN loader for screenshot lib |
| `app/controllers/BugReportController.jl` | `handle_submit`, `render_body`, `verify_turnstile` |
| `app/views/layouts/app_layout.jl` | Single call-site: `bug_report_button()...` |
| `app/routes.jl` | `POST /api/bugreport` |
| `docs/ui/bug_report_template.md` | Issue body Mustache template |
| `data/reference/pii_names.txt` | Name redaction word list |
| `test/components/bug_report_redaction_test.jl` | ≥ 50 PHI pattern assertions |
| `test/controllers/bug_report_controller_test.jl` | Controller unit tests |
| `e2e/tests/bug_report.spec.ts` | Playwright E2E test |

---

## GitHub Issue Format

```
Title: [bug-report] <category> <severity>: <summary (80 chars)>

Labels:
  source: in-app
  category: <bug|feature|data-quality|ux|performance|security>
  severity: <S1|S2|S3|S4>
  route: <normalized URL path>

Assignees: timothyhartzog  (when severity=S1 OR category=security)
```

The body is rendered from `docs/ui/bug_report_template.md` with all
`{{placeholder}}` tokens expanded.

---

## Testing

```bash
# Unit tests (Julia)
julia --compiled-modules=no --startup-file=no \
  test/components/bug_report_redaction_test.jl

julia --compiled-modules=no --startup-file=no \
  test/controllers/bug_report_controller_test.jl

# Playwright E2E (requires running server on :8000)
npx playwright test e2e/tests/bug_report.spec.ts
```

---

## Accessibility

- FAB has `aria-label="Report a bug"` and `aria-expanded`.
- Dialog has `role="dialog"`, `aria-modal="true"`, `aria-labelledby`.
- Form fields have explicit `<label>` associations.
- Required fields marked with `aria-required` implied by `required` attribute.
- Keyboard: `Escape` closes, `Tab` order is logical.
- Target Lighthouse a11y score: **≥ 95**.
