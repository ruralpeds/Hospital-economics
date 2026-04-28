import { test, expect } from '@playwright/test';
import { waitForStippleReady } from '../helpers/page-helpers';

test.describe('Cost Analysis (E7)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/cost-analysis');
    await waitForStippleReady(page);
  });

  test('page renders title and run analysis button', async ({ page }) => {
    await expect(page.locator('h5').filter({ hasText: 'Cost Analysis' })).toBeVisible();
    await expect(page.locator('.q-btn').filter({ hasText: 'Run Analysis' })).toBeVisible();
  });

  test('total cost KPI card renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Total Cost' })).toBeVisible();
  });

  test('cost per QALY KPI card renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Cost per QALY' })).toBeVisible();
  });

  test('high-cost patients KPI card renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'High-Cost Patients' })).toBeVisible();
  });

  test('analysis parameters form renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Analysis Parameters' })).toBeVisible();
  });

  test('layout renders', async ({ page }) => {
    await expect(page.locator('.q-layout')).toBeVisible();
  });
});
