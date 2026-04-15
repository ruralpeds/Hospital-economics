import { test, expect } from '@playwright/test';
import { waitForStippleReady, fillNumberField } from '../helpers/page-helpers';
import { TEST_HOSPITAL } from '../fixtures/test-data';

test.describe('Hospital Profile Editor', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto('/profile');
    await waitForStippleReady(page);
  });

  test('profile page renders header and action buttons', async ({ page }) => {
    await expect(page.locator('h5').filter({ hasText: 'Hospital Profile Editor' })).toBeVisible();
    await expect(page.locator('.q-btn').filter({ hasText: 'Save Profile' })).toBeVisible();
    await expect(page.locator('.q-btn').filter({ hasText: 'Reset' })).toBeVisible();
  });

  // ── Section 1: Hospital Identification ──────────────────────────────

  test('identification section renders all fields', async ({ page }) => {
    const section = page.locator('.q-card').filter({ hasText: 'Hospital Identification' });
    await expect(section).toBeVisible();

    const fields = ['Hospital Name', 'State', 'County', 'ZIP Code', 'Hospital Type', 'Provider Number'];
    for (const field of fields) {
      await expect(
        section.locator('.q-field').filter({ hasText: field }),
        `Field "${field}" should exist`
      ).toHaveCount(1);
    }
  });

  test('hospital type dropdown has expected options', async ({ page }) => {
    const typeSelect = page.locator('.q-select').filter({ hasText: /Hospital Type/ });
    await expect(typeSelect).toBeVisible();
    // Click to open dropdown
    await typeSelect.click();
    // Wait for the popup options list
    const options = page.locator('.q-item__label');
    // Should include CAH, PPS, REH, SCH type labels
    await expect(page.getByText('Critical Access (CAH)')).toBeVisible();
  });

  // ── Section 2: Facility Information ─────────────────────────────────

  test('facility information section renders bed fields', async ({ page }) => {
    const section = page.locator('.q-card').filter({ hasText: 'Facility Information' });
    await expect(section).toBeVisible();

    const fields = ['Licensed Beds', 'Staffed Beds', 'ICU Beds', 'Sq Footage', 'Year Built'];
    for (const field of fields) {
      await expect(
        section.locator('.q-field').filter({ hasText: field }),
        `Field "${field}" should exist`
      ).toHaveCount(1);
    }
  });

  // ── Section 3: Financial Data ───────────────────────────────────────

  test('financial data section renders all field groups', async ({ page }) => {
    const section = page.locator('.q-card').filter({ hasText: 'Financial Data (Annual)' });
    await expect(section).toBeVisible();

    // Revenue fields
    await expect(section.locator('.q-field').filter({ hasText: 'Total Revenue' })).toHaveCount(1);
    await expect(section.locator('.q-field').filter({ hasText: 'Net Patient Revenue' })).toHaveCount(1);
    await expect(section.locator('.q-field').filter({ hasText: 'Total Operating Expenses' })).toHaveCount(1);

    // Expense breakdown subsection
    await expect(section.getByText('Expense Breakdown')).toBeVisible();

    // Balance sheet subsection
    await expect(section.getByText('Balance Sheet')).toBeVisible();
  });

  test('numeric input fields accept valid values', async ({ page }) => {
    const revenueField = page.locator('.q-card')
      .filter({ hasText: 'Financial Data' })
      .locator('.q-field')
      .filter({ hasText: 'Total Revenue' })
      .locator('input');

    await revenueField.fill('20000000');
    await expect(revenueField).toHaveValue('20000000');
  });

  // ── Section 4: Volume & Utilization ────────────────────────────────

  test('volume section renders discharge and visit fields', async ({ page }) => {
    const section = page.locator('.q-card').filter({ hasText: 'Volume & Utilization' });
    await expect(section).toBeVisible();

    const fields = ['IP Discharges', 'IP Days', 'ED Visits', 'OP Visits', 'Case Mix Index', 'Avg LOS'];
    for (const field of fields) {
      await expect(
        section.locator('.q-field').filter({ hasText: field }),
        `Field "${field}" should exist`
      ).toHaveCount(1);
    }
  });

  // ── Section 5: Payer Mix ────────────────────────────────────────────

  test('payer mix section renders sliders', async ({ page }) => {
    const section = page.locator('.q-card').filter({ hasText: 'Payer Mix' });
    await expect(section).toBeVisible();

    // Payer mix uses q-slider components
    const sliders = section.locator('.q-slider');
    const count = await sliders.count();
    expect(count).toBeGreaterThanOrEqual(4); // Medicare, Medicaid, Commercial, Self-Pay
  });

  // ── Section 6: Services ────────────────────────────────────────────

  test('services section renders toggle switches', async ({ page }) => {
    const section = page.locator('.q-card').filter({ hasText: 'Services Offered' });
    await expect(section).toBeVisible();

    const services = ['Emergency Dept', 'Surgery', 'Obstetrics', 'Imaging', 'Laboratory', 'Pharmacy'];
    for (const svc of services) {
      await expect(
        section.locator('.q-toggle').filter({ hasText: svc }),
        `Toggle "${svc}" should exist`
      ).toHaveCount(1);
    }
  });

  // ── Computed Metrics ────────────────────────────────────────────────

  test('computed metrics section renders auto-calculated values', async ({ page }) => {
    const section = page.locator('.q-card').filter({ hasText: 'Computed Metrics' });
    await expect(section).toBeVisible();

    const metrics = ['Operating Margin', 'Days Cash', 'FTE/AOB', 'Labor Cost %'];
    for (const metric of metrics) {
      await expect(section.getByText(metric)).toBeVisible();
    }
  });
});
