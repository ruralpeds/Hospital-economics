# In-App Bug Report Template

The `BugReport` component (see `app/components/bug_report.jl`) posts bug
reports to GitHub issues using this body template. Keep it in sync with
`BugReportController.render_body`.

---

## Body template (Markdown)

```markdown
## Summary
{{summary}}

## Category / Severity
- **Category:** {{category}}    <!-- bug | feature | data-quality | ux | performance | security -->
- **Severity:** {{severity}}    <!-- S1 (blocker) | S2 (major) | S3 (minor) | S4 (trivial) -->

## Steps to reproduce
{{steps}}

## Expected behavior
{{expected}}

## Actual behavior
{{actual}}

## Screenshot
{{screenshot_markdown_or_gist_link_or_none}}

## Environment
- **App version:** {{app_version}}
- **Git SHA:** {{git_sha}}
- **Route:** `{{route}}`
- **Browser:** {{browser_ua}}
- **Viewport:** {{viewport_w}}×{{viewport_h}}
- **Locale:** {{locale}}
- **Authenticated user id:** {{user_id_or_anon}}
- **Submitted at:** {{timestamp_utc}}

## Reactive state snapshot (scrubbed)
<details>
<summary>Last 20 state deltas (PHI-redacted)</summary>

```json
{{state_delta_json}}
```

</details>

---

_Submitted from: in-app reporter. PHI was redacted client-side and
re-scanned server-side before this issue was created._
```

## Labels applied automatically

- `source: in-app`
- `category: {{category}}`
- `severity: {{severity}}`
- `route: {{normalized_route}}` (e.g. `route/cost-analysis`)

## Assignment rules

- `category: security` → assigned to `@timothyhartzog`.
- `severity: S1` → assigned to `@timothyhartzog`.
- All others → unassigned; triaged by `@copilot` via existing
  issue-review workflow.

## What is **never** stored in a bug report

- Protected Health Information (names, DOB, MRN, SSN, addresses,
  insurance ids).
- Auth tokens, session cookies, API keys.
- Raw uploaded file contents (only the `DataAsset` id).
- Email addresses of other users.

The redaction regex list lives in
`app/components/bug_report_redaction.jl` and is unit-tested against a
corpus in `test/components/bug_report_redaction_test.jl`.
