import { test, expect } from '@playwright/test';
import { waitForStippleReady } from '../helpers/page-helpers';

test.describe('Profitability & Operations (E9)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/profitability');
    await waitForStippleReady(page);
  });

  test('page renders title and calculate button', async ({ page }) => {
    await expect(page.locator('h5').filter({ hasText: 'Profitability & Operations' })).toBeVisible();
    await expect(page.locator('.q-btn').filter({ hasText: 'Calculate' })).toBeVisible();
  });

  test('contribution margin KPI card renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Contribution Margin' })).toBeVisible();
  });

  test('break-even volume KPI card renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Break-Even Volume' })).toBeVisible();
  });

  test('operating margin KPI card renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Operating Margin' })).toBeVisible();
  });

  test('volume sensitivity slider renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Volume Sensitivity' })).toBeVisible();
    await expect(page.locator('.q-slider')).toBeVisible();
  });

  test('financial inputs form renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Financial Inputs' })).toBeVisible();
  });

  test('departmental profitability table renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Departmental Profitability' })).toBeVisible();
  });

  test('layout renders', async ({ page }) => {
    await expect(page.locator('.q-layout')).toBeVisible();
  });
});
