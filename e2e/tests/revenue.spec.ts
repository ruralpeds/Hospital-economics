import { test, expect } from '@playwright/test';
import { waitForStippleReady } from '../helpers/page-helpers';

test.describe('Revenue & Reimbursement (E8)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/revenue');
    await waitForStippleReady(page);
  });

  test('page renders title and run simulation button', async ({ page }) => {
    await expect(page.locator('h5').filter({ hasText: 'Revenue & Reimbursement' })).toBeVisible();
    await expect(page.locator('.q-btn').filter({ hasText: 'Run Simulation' })).toBeVisible();
  });

  test('total revenue KPI card renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Total Revenue' })).toBeVisible();
  });

  test('total denied KPI card renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Total Denied' })).toBeVisible();
  });

  test('denial rate KPI card renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Denial Rate' })).toBeVisible();
  });

  test('simulation parameters form renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Simulation Parameters' })).toBeVisible();
  });

  test('layout renders', async ({ page }) => {
    await expect(page.locator('.q-layout')).toBeVisible();
  });
});
