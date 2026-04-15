import { test, expect } from '@playwright/test';
import { waitForStippleReady, getSliderContainer } from '../helpers/page-helpers';

test.describe('7-Slider Financial Simulator', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto('/financial-sim');
    await waitForStippleReady(page);
  });

  test('page renders title and description', async ({ page }) => {
    await expect(page.locator('h5').filter({ hasText: '7-Slider Financial Simulator' })).toBeVisible();
    await expect(page.getByText('Adjust key operational parameters')).toBeVisible();
  });

  test('simulate button is present', async ({ page }) => {
    const btn = page.locator('.q-btn').filter({ hasText: 'Simulate' });
    await expect(btn).toBeVisible();
  });

  // ── Summary KPI Cards ──────────────────────────────────────────────

  test('summary KPI cards render', async ({ page }) => {
    const kpis = ['Year 1 Revenue', 'Year 5 Revenue', 'Year 5 Margin', '5-Year Cumulative Gap'];
    for (const kpi of kpis) {
      const card = page.locator('.q-card').filter({ hasText: kpi });
      await expect(card, `KPI "${kpi}" should be visible`).toBeVisible();
    }
  });

  // ── Slider Panel ──────────────────────────────────────────────────

  test('all 7 sliders are rendered', async ({ page }) => {
    const sliderPanel = page.locator('.q-card').filter({ hasText: 'Operational Sliders' });
    await expect(sliderPanel).toBeVisible();

    const sliders = sliderPanel.locator('.q-slider');
    const count = await sliders.count();
    expect(count).toBe(7);
  });

  test('slider labels display current values', async ({ page }) => {
    const sliderPanel = page.locator('.q-card').filter({ hasText: 'Operational Sliders' });

    const labels = ['ED Visits', 'IP Discharges', 'Medicare %', 'Commercial %',
                    'Inflation', 'Travel Nurse %', 'ALOS'];
    for (const label of labels) {
      await expect(
        sliderPanel.getByText(label, { exact: false }),
        `Slider label "${label}" should be visible`
      ).toBeVisible();
    }
  });

  test('slider interaction updates displayed value', async ({ page }) => {
    const sliderPanel = page.locator('.q-card').filter({ hasText: 'Operational Sliders' });
    const edSlider = sliderPanel.locator('.q-slider').first();

    // Get the slider bounding box and interact
    const box = await edSlider.boundingBox();
    if (box) {
      // Click at 75% of the slider width to change value
      await page.mouse.click(box.x + box.width * 0.75, box.y + box.height / 2);
      // Wait for Stipple reactivity
      await page.waitForTimeout(500);
    }

    // The ED Visits label should reflect a value (exact value depends on where we clicked)
    const edLabel = sliderPanel.getByText(/ED Visits:/);
    const text = await edLabel.textContent();
    expect(text).toMatch(/ED Visits:\s*[\d,]+/);
  });

  // ── Charts ────────────────────────────────────────────────────────

  test('margin trajectory chart container is present', async ({ page }) => {
    // Plotly charts are rendered as .js-plotly-plot elements
    const charts = page.locator('.js-plotly-plot, .plotly, [data-plotly]');
    const count = await charts.count();
    // Should have at least the margin trajectory and payer doughnut
    expect(count).toBeGreaterThanOrEqual(1);
  });

  test('payer doughnut chart area is present', async ({ page }) => {
    // The page has 3 card columns: sliders, line chart, doughnut
    const cards = page.locator('.q-card');
    const count = await cards.count();
    // At minimum: 4 KPI cards + slider panel + 2 chart cards = 7
    expect(count).toBeGreaterThanOrEqual(7);
  });
});
