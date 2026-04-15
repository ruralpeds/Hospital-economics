import { test, expect } from '@playwright/test';
import { waitForStippleReady, getKPIValue, getKPILabels } from '../helpers/page-helpers';

test.describe('Financial Dashboard', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard');
    await waitForStippleReady(page);
  });

  test('dashboard page renders correctly', async ({ page }) => {
    await expect(page.locator('h5').filter({ hasText: /Hospital|Dashboard/ })).toBeVisible();
    await expect(page.locator('.q-layout')).toBeVisible();
  });

  test('KPI cards row 1 - financial metrics render', async ({ page }) => {
    const financialKPIs = ['Operating Margin', 'Total Margin', 'Net Patient Revenue', 'Days Cash on Hand'];
    for (const kpi of financialKPIs) {
      const card = page.locator('.q-card').filter({ hasText: kpi });
      await expect(card, `KPI card "${kpi}" should be visible`).toBeVisible();
    }
  });

  test('KPI cards row 2 - operations metrics render', async ({ page }) => {
    const opsKPIs = ['Current Ratio', 'Debt/Capital', 'Case Mix Index', 'FTE/AOB', 'Avg Age of Plant'];
    for (const kpi of opsKPIs) {
      const card = page.locator('.q-card').filter({ hasText: kpi });
      await expect(card, `KPI card "${kpi}" should be visible`).toBeVisible();
    }
  });

  test('KPI cards row 3 - volume metrics render', async ({ page }) => {
    const volumeKPIs = ['Avg Daily Census', 'Occupancy', 'ED Visits/Year', 'Outpatient %'];
    for (const kpi of volumeKPIs) {
      const card = page.locator('.q-card').filter({ hasText: kpi });
      await expect(card, `KPI card "${kpi}" should be visible`).toBeVisible();
    }
  });

  test('Plotly chart containers are present', async ({ page }) => {
    // StipplePlotly renders into .js-plotly-plot containers
    const plotContainers = page.locator('.js-plotly-plot, .plotly, [data-plotly]');
    // Dashboard has 4 charts: margin trend, revenue/expense, volume, payer mix
    const count = await plotContainers.count();
    expect(count).toBeGreaterThanOrEqual(1);
  });

  test('hospital selector dropdown exists', async ({ page }) => {
    // The dashboard has a q-select for hospital selection
    const selector = page.locator('.q-select').filter({ hasText: /Hospital/ });
    await expect(selector).toBeVisible();
  });

  test('benchmark comparison dropdown exists', async ({ page }) => {
    const benchmarkSelect = page.locator('.q-select').filter({ hasText: /Benchmark/ });
    await expect(benchmarkSelect).toBeVisible();
  });

  test('projection months input exists', async ({ page }) => {
    const projInput = page.locator('.q-field').filter({ hasText: /Projection Months/ });
    await expect(projInput).toBeVisible();
  });

  test('refresh button is present', async ({ page }) => {
    const refreshBtn = page.locator('.q-btn').filter({ hasText: /Refresh/ });
    await expect(refreshBtn).toBeVisible();
  });
});
