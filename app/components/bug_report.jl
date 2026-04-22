"""
BugReport component — floating action button + Quasar dialog for in-app bug reporting.

Usage (called once in app/views/layouts/app_layout.jl):

    bug_report_button()                    # default: bottom-right FAB
    bug_report_button(position=:top_right) # other corner

Returns a Vector of HTML elements that are injected into the shared layout,
making the reporter available on every page without any per-tab code change.

Client-side behaviour (all self-contained in the emitted <script> block):
  - Tracks form_opened_at for dwell-time protection.
  - Runs PHI redaction (same regex set as server) before the fetch() call.
  - Renders the Cloudflare Turnstile widget when TURNSTILE_SITE_KEY is set.
  - Loads html2canvas for optional screenshot capture.
  - POSTs to /api/bugreport and shows a success / error toast.
"""

function bug_report_button(; position::Symbol = :bottom_right)
    pos_style = if position == :bottom_right
        "bottom:24px;right:24px;"
    elseif position == :bottom_left
        "bottom:24px;left:24px;"
    elseif position == :top_right
        "top:80px;right:24px;"
    else
        "top:80px;left:24px;"
    end

    # Read the Turnstile site-key at render time (server-side, never the secret)
    turnstile_site_key = get(ENV, "TURNSTILE_SITE_KEY", "")
    turnstile_widget = if isempty(turnstile_site_key)
        "<!-- Turnstile widget omitted: TURNSTILE_SITE_KEY not configured -->"
    else
        """<div class="cf-turnstile q-my-sm"
                  data-sitekey="$(turnstile_site_key)"
                  data-callback="bugReportTurnstileCallback"
                  id="bug-report-turnstile"></div>
             <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>"""
    end

    [
        raw_html("""
<!-- ═══════════════════════════════════════════════════════════════════ -->
<!-- BugReport Component (E27) — floating FAB + dialog                 -->
<!-- ═══════════════════════════════════════════════════════════════════ -->
<div id="bug-report-root" aria-label="Bug report widget">

  <!-- Floating Action Button -->
  <button id="bug-report-fab"
          type="button"
          aria-label="Report a bug"
          title="Report a bug"
          class="q-btn q-btn--fab shadow-4 text-white"
          style="position:fixed;$(pos_style)z-index:9000;
                 background:#d32f2f;border:none;cursor:pointer;
                 width:56px;height:56px;border-radius:50%;
                 display:flex;align-items:center;justify-content:center;">
    <i class="material-icons" style="font-size:24px;">bug_report</i>
  </button>

  <!-- Modal overlay -->
  <div id="bug-report-overlay"
       role="dialog"
       aria-modal="true"
       aria-labelledby="bug-report-dialog-title"
       style="display:none;position:fixed;inset:0;z-index:9001;
              background:rgba(0,0,0,.55);
              align-items:center;justify-content:center;">

    <div class="q-card bg-white"
         style="width:620px;max-width:96vw;max-height:92vh;
                overflow-y:auto;border-radius:8px;"
         role="document">

      <!-- Dialog header -->
      <div class="q-card__section row items-center bg-red-9 text-white"
           style="border-radius:8px 8px 0 0;">
        <i class="material-icons q-mr-sm">bug_report</i>
        <span id="bug-report-dialog-title" class="text-h6">Report a Bug</span>
        <div style="flex:1"></div>
        <button type="button"
                id="bug-report-close"
                aria-label="Close dialog"
                class="q-btn q-btn--flat q-btn--round text-white"
                style="background:none;border:none;cursor:pointer;
                       width:40px;height:40px;border-radius:50%;">
          <i class="material-icons">close</i>
        </button>
      </div>

      <!-- Form -->
      <form id="bug-report-form" novalidate
            class="q-card__section q-pt-md">

        <!-- Honeypot: hidden from real users but bots fill it -->
        <input name="website"
               id="bug-report-honeypot"
               type="text"
               tabindex="-1"
               autocomplete="off"
               aria-hidden="true"
               style="position:absolute;left:-9999px;width:1px;height:1px;"
               value="">

        <!-- Row 1: Category + Severity -->
        <div class="row q-gutter-md q-mb-md">
          <div class="col">
            <label for="br-category" class="text-caption text-grey-7 q-mb-xs block">
              Category <span aria-hidden="true" style="color:#c00">*</span>
            </label>
            <select id="br-category" name="category" required
                    class="q-field__native full-width"
                    style="border:1px solid #ccc;border-radius:4px;
                           padding:8px;font-size:14px;">
              <option value="bug">Bug</option>
              <option value="feature">Feature Request</option>
              <option value="data-quality">Data Quality</option>
              <option value="ux">UX / Usability</option>
              <option value="performance">Performance</option>
              <option value="security">Security</option>
            </select>
          </div>
          <div class="col">
            <label for="br-severity" class="text-caption text-grey-7 q-mb-xs block">
              Severity <span aria-hidden="true" style="color:#c00">*</span>
            </label>
            <select id="br-severity" name="severity" required
                    class="q-field__native full-width"
                    style="border:1px solid #ccc;border-radius:4px;
                           padding:8px;font-size:14px;">
              <option value="S3" selected>S3 — Minor</option>
              <option value="S2">S2 — Major</option>
              <option value="S1">S1 — Blocker</option>
              <option value="S4">S4 — Trivial</option>
            </select>
          </div>
        </div>

        <!-- Summary -->
        <div class="q-mb-md">
          <label for="br-summary" class="text-caption text-grey-7 q-mb-xs block">
            Summary (what went wrong?) <span aria-hidden="true" style="color:#c00">*</span>
          </label>
          <input id="br-summary" name="summary" type="text" required
                 minlength="20" maxlength="256"
                 placeholder="e.g. Clicking 'Run Simulation' crashes on Chrome 120"
                 class="q-field__native full-width"
                 style="border:1px solid #ccc;border-radius:4px;
                        padding:8px;font-size:14px;width:100%;box-sizing:border-box;">
        </div>

        <!-- Steps to reproduce -->
        <div class="q-mb-md">
          <label for="br-steps" class="text-caption text-grey-7 q-mb-xs block">
            Steps to reproduce
          </label>
          <textarea id="br-steps" name="steps" rows="3"
                    placeholder="1. Navigate to /simulate&#10;2. Click 'Run'&#10;3. …"
                    class="q-field__native full-width"
                    style="border:1px solid #ccc;border-radius:4px;
                           padding:8px;font-size:14px;width:100%;
                           box-sizing:border-box;resize:vertical;"></textarea>
        </div>

        <!-- Expected / Actual -->
        <div class="row q-gutter-md q-mb-md">
          <div class="col">
            <label for="br-expected" class="text-caption text-grey-7 q-mb-xs block">
              Expected behavior
            </label>
            <textarea id="br-expected" name="expected" rows="2"
                      class="q-field__native full-width"
                      style="border:1px solid #ccc;border-radius:4px;
                             padding:8px;font-size:14px;width:100%;
                             box-sizing:border-box;resize:vertical;"></textarea>
          </div>
          <div class="col">
            <label for="br-actual" class="text-caption text-grey-7 q-mb-xs block">
              Actual behavior
            </label>
            <textarea id="br-actual" name="actual" rows="2"
                      class="q-field__native full-width"
                      style="border:1px solid #ccc;border-radius:4px;
                             padding:8px;font-size:14px;width:100%;
                             box-sizing:border-box;resize:vertical;"></textarea>
          </div>
        </div>

        <!-- Email (optional) -->
        <div class="q-mb-md">
          <label class="row items-center q-gutter-sm" style="cursor:pointer;">
            <input type="checkbox" id="br-email-optin" name="email_optin"
                   style="margin:0;" aria-checked="false">
            <span class="text-caption">I'm OK being contacted about this report</span>
          </label>
          <input id="br-email" name="email" type="email"
                 placeholder="your@email.com (optional)"
                 disabled
                 class="q-field__native full-width q-mt-xs"
                 style="border:1px solid #ccc;border-radius:4px;
                        padding:8px;font-size:14px;width:100%;
                        box-sizing:border-box;display:none;">
        </div>

        <!-- Screenshot -->
        <div class="q-mb-md">
          <label class="text-caption text-grey-7 q-mb-xs block">
            Screenshot (optional)
          </label>
          <div class="row q-gutter-sm items-center">
            <button type="button" id="br-capture-btn"
                    class="q-btn q-btn--outline q-btn--sm"
                    style="border:1px solid #1976d2;color:#1976d2;
                           background:none;cursor:pointer;
                           padding:4px 12px;border-radius:4px;font-size:13px;">
              <i class="material-icons" style="font-size:16px;vertical-align:middle;">camera_alt</i>
              Capture screen
            </button>
            <span id="br-screenshot-status" class="text-caption text-grey-6"></span>
          </div>
          <input type="hidden" id="br-screenshot-data" name="screenshot_url">
        </div>

        <!-- Turnstile widget placeholder -->
        $(turnstile_widget)
        <input type="hidden" id="br-turnstile-token" name="cf_turnstile_response">

        <!-- Hidden timing fields -->
        <input type="hidden" id="br-opened-at"    name="form_opened_at">
        <input type="hidden" id="br-submitted-at" name="submitted_at">

        <!-- Error/success messages -->
        <div id="br-message" role="alert" aria-live="polite"
             style="display:none;padding:8px 12px;border-radius:4px;
                    margin-bottom:12px;font-size:14px;"></div>

        <!-- Actions -->
        <div class="row justify-end q-gutter-sm q-mt-sm">
          <button type="button" id="br-cancel-btn"
                  class="q-btn q-btn--flat"
                  style="background:none;border:none;cursor:pointer;
                         padding:8px 16px;border-radius:4px;
                         color:#555;font-size:14px;">
            Cancel
          </button>
          <button type="submit" id="br-submit-btn"
                  class="q-btn bg-red-9 text-white"
                  style="border:none;cursor:pointer;
                         padding:8px 20px;border-radius:4px;
                         font-size:14px;font-weight:600;">
            Submit Report
          </button>
        </div>

      </form><!-- /bug-report-form -->
    </div><!-- /q-card -->
  </div><!-- /overlay -->
</div><!-- /bug-report-root -->
"""),

        # ── Client-side JavaScript ────────────────────────────────────────────
        raw_html("""
<script>
(function () {
  'use strict';

  // ── PHI redaction patterns (mirrors server-side BugReportRedaction.jl) ──
  const PHI_PATTERNS = [
    [/\\b\\d{3}-\\d{2}-\\d{4}\\b/g,                              '[SSN]'],
    [/\\b\\d{9}\\b/g,                                             '[SSN]'],
    [/\\b(0?[1-9]|1[012])[-\\/](0?[1-9]|[12]\\d|3[01])[-\\/](19|20)\\d{2}\\b/g, '[DOB]'],
    [/\\bMRN[:\\s]*\\d{4,12}\\b/gi,                              '[MRN]'],
    [/\\b(\\+?1[-.\\s]?)?\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}\\b/g, '[PHONE]'],
    [/\\b[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}\\b/g, '[EMAIL]'],
    [/\\b(member|claim|group|policy|subscriber|plan|beneficiary)\\s*(id|#|no\\.?|number)[:\\s#]*[A-Z0-9\\-]{4,20}\\b/gi, '[INSURANCE_ID]'],
    [/\\b[A-Z]{2,4}\\d{7,12}\\b/g,                               '[INSURANCE_ID]'],
    [/\\b\\d{1,5}\\s+[A-Za-z]+\\s+(Street|St\\.?|Avenue|Ave\\.?|Boulevard|Blvd\\.?|Road|Rd\\.?|Drive|Dr\\.?|Lane|Ln\\.?|Court|Ct\\.?|Place|Pl\\.?|Way|Circle|Cir\\.?|Highway|Hwy)\\b/gi, '[ADDRESS]'],
    [/\\b\\d{5}(-\\d{4})?\\b/g,                                  '[ZIP]'],
  ];

  function redactText(str) {
    if (typeof str !== 'string') return str;
    let result = str;
    for (const [pat, rep] of PHI_PATTERNS) {
      result = result.replace(pat, rep);
    }
    return result;
  }

  // ── DOM refs ─────────────────────────────────────────────────────────────
  const fab       = document.getElementById('bug-report-fab');
  const overlay   = document.getElementById('bug-report-overlay');
  const form      = document.getElementById('bug-report-form');
  const closeBtn  = document.getElementById('bug-report-close');
  const cancelBtn = document.getElementById('br-cancel-btn');
  const submitBtn = document.getElementById('br-submit-btn');
  const msgDiv    = document.getElementById('br-message');
  const emailBox  = document.getElementById('br-email');
  const emailOptin= document.getElementById('br-email-optin');
  const captureBtn= document.getElementById('br-capture-btn');
  const screenshotStatus = document.getElementById('br-screenshot-status');

  // ── Open / close ─────────────────────────────────────────────────────────
  function openDialog() {
    overlay.style.display = 'flex';
    document.getElementById('br-opened-at').value = new Date().toISOString().slice(0,19);
    msgDiv.style.display = 'none';
    fab.setAttribute('aria-expanded', 'true');
    setTimeout(() => document.getElementById('br-summary').focus(), 100);
  }

  function closeDialog() {
    overlay.style.display = 'none';
    form.reset();
    emailBox.style.display = 'none';
    emailBox.disabled = true;
    document.getElementById('br-screenshot-data').value = '';
    screenshotStatus.textContent = '';
    fab.setAttribute('aria-expanded', 'false');
    // Reset Turnstile if present
    if (window.turnstile) {
      const el = document.getElementById('bug-report-turnstile');
      if (el) window.turnstile.reset(el);
    }
  }

  fab.addEventListener('click', openDialog);
  closeBtn.addEventListener('click', closeDialog);
  cancelBtn.addEventListener('click', closeDialog);
  overlay.addEventListener('click', function(e) {
    if (e.target === overlay) closeDialog();
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && overlay.style.display !== 'none') closeDialog();
  });

  // ── Email opt-in toggle ───────────────────────────────────────────────────
  emailOptin.addEventListener('change', function() {
    const checked = emailOptin.checked;
    emailBox.style.display = checked ? 'block' : 'none';
    emailBox.disabled = !checked;
    emailOptin.setAttribute('aria-checked', checked ? 'true' : 'false');
  });

  // ── Turnstile callback ────────────────────────────────────────────────────
  window.bugReportTurnstileCallback = function(token) {
    document.getElementById('br-turnstile-token').value = token;
  };

  // ── Screenshot capture ────────────────────────────────────────────────────
  captureBtn.addEventListener('click', async function() {
    captureBtn.disabled = true;
    screenshotStatus.textContent = 'Capturing…';
    try {
      // Blank out .phi elements before capture
      const phiEls = document.querySelectorAll('.phi');
      phiEls.forEach(el => { el._origOpacity = el.style.opacity; el.style.opacity = '0'; });

      let dataUrl = null;
      if (window.html2canvas) {
        const canvas = await html2canvas(document.body, { logging: false });
        dataUrl = canvas.toDataURL('image/png');
      } else {
        screenshotStatus.textContent = 'Screenshot library not loaded.';
        captureBtn.disabled = false;
        return;
      }

      // Restore .phi elements
      phiEls.forEach(el => { el.style.opacity = el._origOpacity || ''; delete el._origOpacity; });

      document.getElementById('br-screenshot-data').value = dataUrl;
      screenshotStatus.textContent = 'Screenshot captured ✓';
    } catch (err) {
      screenshotStatus.textContent = 'Capture failed: ' + err.message;
    } finally {
      captureBtn.disabled = false;
    }
  });

  // ── Message helper ────────────────────────────────────────────────────────
  function showMsg(text, type) {
    msgDiv.textContent = text;
    msgDiv.style.display = 'block';
    msgDiv.style.background = type === 'success' ? '#e8f5e9' : '#ffebee';
    msgDiv.style.color       = type === 'success' ? '#2e7d32' : '#c62828';
    msgDiv.style.border      = type === 'success'
      ? '1px solid #a5d6a7' : '1px solid #ef9a9a';
  }

  // ── Form submission ───────────────────────────────────────────────────────
  form.addEventListener('submit', async function(e) {
    e.preventDefault();

    submitBtn.disabled = true;
    submitBtn.textContent = 'Submitting…';
    document.getElementById('br-submitted-at').value = new Date().toISOString().slice(0,19);

    // Collect form data
    const data = {
      website:             document.getElementById('bug-report-honeypot').value,
      category:            document.getElementById('br-category').value,
      severity:            document.getElementById('br-severity').value,
      summary:             redactText(document.getElementById('br-summary').value),
      steps:               redactText(document.getElementById('br-steps').value),
      expected:            redactText(document.getElementById('br-expected').value),
      actual:              redactText(document.getElementById('br-actual').value),
      email_optin:         emailOptin.checked,
      email:               emailOptin.checked ? redactText(emailBox.value) : '',
      screenshot_url:      document.getElementById('br-screenshot-data').value,
      cf_turnstile_response: document.getElementById('br-turnstile-token').value,
      form_opened_at:      document.getElementById('br-opened-at').value,
      submitted_at:        document.getElementById('br-submitted-at').value,
      route:               window.location.pathname,
      browser_ua:          navigator.userAgent,
      viewport_w:          window.innerWidth,
      viewport_h:          window.innerHeight,
      locale:              navigator.language || 'en',
    };

    try {
      const resp = await fetch('/api/bugreport', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      });

      const json = await resp.json();

      if (resp.status === 201 || resp.status === 202) {
        const url = (json.body || json).issue_url || '';
        const msg = (json.body || json).message  || 'Report submitted.';
        showMsg(msg + (url ? ' View: ' + url : ''), 'success');
        setTimeout(closeDialog, 3500);
      } else {
        const err = (json.body || json).error || 'Submission failed — please try again.';
        showMsg(err, 'error');
      }
    } catch (err) {
      showMsg('Network error — please check your connection and try again.', 'error');
    } finally {
      submitBtn.disabled = false;
      submitBtn.textContent = 'Submit Report';
    }
  });

}());
</script>
"""),
    ]
end
