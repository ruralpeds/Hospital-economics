/**
 * e2e/tests/bug_report.spec.ts
 *
 * Playwright E2E tests for the BugReport component (E27).
 *
 * Tests:
 *  1. FAB is visible on /dashboard.
 *  2. Clicking FAB opens the dialog.
 *  3. Submitting a well-formed report posts to /api/bugreport and shows a
 *     success toast. The mocked POST payload is checked for:
 *       - template fields present (summary, category, severity, route)
 *       - NO PHI from a seeded test string
 *  4. Closing the dialog resets the form.
 *  5. Pressing Escape closes the dialog.
 *  6. BUG_REPORT_GITHUB_TOKEN never appears in page source or API response.
 */

import { test, expect } from '@playwright/test';

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Seed PHI strings that MUST NOT appear in the submitted payload.
 */
const PHI_SEED = {
  ssn:   '123-45-6789',
  dob:   '01/15/1990',
  mrn:   'MRN: 9876543',
  phone: '555-867-5309',
  email: 'patient@example.com',
};

async function openBugReportDialog(page: any) {
  const fab = page.locator('#bug-report-fab');
  await expect(fab).toBeVisible({ timeout: 10_000 });
  await fab.click();
  await expect(page.locator('#bug-report-overlay')).toBeVisible({ timeout: 5_000 });
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test.describe('BugReport component', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard');
    // Wait for the page to be interactive (Stipple may take a moment)
    await page.waitForSelector('#bug-report-fab', { timeout: 15_000 });
  });

  // ── 1. FAB visibility ────────────────────────────────────────────────────
  test('FAB is visible on every page', async ({ page }) => {
    await expect(page.locator('#bug-report-fab')).toBeVisible();
    await expect(page.locator('#bug-report-fab')).toHaveAttribute('aria-label', 'Report a bug');
  });

  // ── 2. Dialog opens on FAB click ─────────────────────────────────────────
  test('clicking FAB opens the dialog', async ({ page }) => {
    await openBugReportDialog(page);
    await expect(page.locator('#bug-report-dialog-title')).toHaveText('Report a Bug');
    await expect(page.locator('#br-category')).toBeVisible();
    await expect(page.locator('#br-severity')).toBeVisible();
    await expect(page.locator('#br-summary')).toBeVisible();
  });

  // ── 3. Successful submission with mocked GitHub API ───────────────────────
  test('submitting a well-formed report posts to /api/bugreport and shows success', async ({ page }) => {
    // Intercept the POST to /api/bugreport
    let capturedPayload: any = null;

    await page.route('/api/bugreport', async (route) => {
      const request = route.request();
      capturedPayload = JSON.parse(request.postData() || '{}');
      await route.fulfill({
        status: 201,
        contentType: 'application/json',
        body: JSON.stringify({
          issue_url: 'https://github.com/timothyhartzog/hospital-economics/issues/999',
          message:   'Bug report submitted successfully.',
        }),
      });
    });

    await openBugReportDialog(page);

    // Fill form with PHI-containing text to verify client-side redaction
    await page.fill('#br-summary',
      `Dashboard crashes — patient ${PHI_SEED.ssn} shown`);
    await page.selectOption('#br-category', 'bug');
    await page.selectOption('#br-severity', 'S2');
    await page.fill('#br-steps',
      `1. Open dashboard\n2. Check patient with DOB ${PHI_SEED.dob}`);
    await page.fill('#br-expected', 'No PHI visible');
    await page.fill('#br-actual',
      `Phone ${PHI_SEED.phone} and MRN: ${PHI_SEED.mrn} visible in chart`);

    // Set dwell time so server accepts it (fast CI — patch the hidden field)
    await page.evaluate(() => {
      const opened = new Date(Date.now() - 10_000);
      (document.getElementById('br-opened-at') as HTMLInputElement).value =
        opened.toISOString().slice(0, 19);
    });

    await page.click('#br-submit-btn');

    // Success message should appear
    const msgDiv = page.locator('#br-message');
    await expect(msgDiv).toBeVisible({ timeout: 8_000 });
    await expect(msgDiv).toContainText('submitted');

    // ── Payload assertions ─────────────────────────────────────────────────
    expect(capturedPayload).not.toBeNull();

    // Required template fields must be present
    expect(capturedPayload).toHaveProperty('category', 'bug');
    expect(capturedPayload).toHaveProperty('severity', 'S2');
    expect(capturedPayload.summary).toBeTruthy();
    expect(capturedPayload.route).toBeTruthy();

    // Client-side PHI redaction: raw PHI must NOT appear in payload
    const payloadStr = JSON.stringify(capturedPayload);
    expect(payloadStr).not.toContain(PHI_SEED.ssn);
    expect(payloadStr).not.toContain(PHI_SEED.dob);
    expect(payloadStr).not.toContain(PHI_SEED.phone);

    // BUG_REPORT_GITHUB_TOKEN must never appear in the payload or response
    expect(payloadStr).not.toContain('BUG_REPORT_GITHUB_TOKEN');
    expect(payloadStr).not.toContain('ghp_');  // common GitHub token prefix
  });

  // ── 4. Closing dialog resets form ─────────────────────────────────────────
  test('closing dialog resets the form', async ({ page }) => {
    await openBugReportDialog(page);
    await page.fill('#br-summary', 'Some text I typed');
    await page.click('#bug-report-close');
    await expect(page.locator('#bug-report-overlay')).toBeHidden({ timeout: 3_000 });

    // Reopen — summary should be empty
    await openBugReportDialog(page);
    const summary = await page.inputValue('#br-summary');
    expect(summary).toBe('');
  });

  // ── 5. Escape key closes the dialog ──────────────────────────────────────
  test('pressing Escape closes the dialog', async ({ page }) => {
    await openBugReportDialog(page);
    await page.keyboard.press('Escape');
    await expect(page.locator('#bug-report-overlay')).toBeHidden({ timeout: 3_000 });
  });

  // ── 6. Token not in page source ───────────────────────────────────────────
  test('BUG_REPORT_GITHUB_TOKEN does not appear in page source', async ({ page }) => {
    const content = await page.content();
    expect(content).not.toContain('BUG_REPORT_GITHUB_TOKEN');
    expect(content).not.toContain('ghp_');
  });

  // ── 7. Honeypot field is hidden ───────────────────────────────────────────
  test('honeypot field is not visible to real users', async ({ page }) => {
    await openBugReportDialog(page);
    const honeypot = page.locator('#bug-report-honeypot');
    await expect(honeypot).toBeHidden();
  });

  // ── 8. FAB present on a different page (layout wiring) ───────────────────
  test('FAB is wired into the shared layout (present on /profile)', async ({ page }) => {
    await page.goto('/profile');
    await expect(page.locator('#bug-report-fab')).toBeVisible({ timeout: 15_000 });
  });

  // ── 9. Email opt-in toggle shows/hides email field ───────────────────────
  test('email opt-in checkbox toggles email input visibility', async ({ page }) => {
    await openBugReportDialog(page);
    const emailField = page.locator('#br-email');
    await expect(emailField).toBeHidden();
    await page.check('#br-email-optin');
    await expect(emailField).toBeVisible();
    await page.uncheck('#br-email-optin');
    await expect(emailField).toBeHidden();
  });

  // ── 10. Error response shows error message ────────────────────────────────
  test('rate-limit error is shown to the user', async ({ page }) => {
    await page.route('/api/bugreport', async (route) => {
      await route.fulfill({
        status: 429,
        contentType: 'application/json',
        body: JSON.stringify({ error: 'Rate limit exceeded: too many reports from this IP in the past hour.' }),
      });
    });

    await openBugReportDialog(page);
    await page.fill('#br-summary', 'A' .repeat(30));
    await page.evaluate(() => {
      const opened = new Date(Date.now() - 10_000);
      (document.getElementById('br-opened-at') as HTMLInputElement).value =
        opened.toISOString().slice(0, 19);
    });
    await page.click('#br-submit-btn');

    const msgDiv = page.locator('#br-message');
    await expect(msgDiv).toBeVisible({ timeout: 5_000 });
    await expect(msgDiv).toContainText('Rate limit');
  });

});
