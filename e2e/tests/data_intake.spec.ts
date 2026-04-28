import { test, expect } from '@playwright/test';
import { waitForStippleReady } from '../helpers/page-helpers';

test.describe('Data Intake (E4)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/data/intake');
    await waitForStippleReady(page);
  });

  test('page renders title and run validation button', async ({ page }) => {
    await expect(page.locator('h5').filter({ hasText: 'Data Intake' })).toBeVisible();
    await expect(page.locator('.q-btn').filter({ hasText: 'Run Validation' })).toBeVisible();
  });

  test('source type selector is present', async ({ page }) => {
    await expect(page.locator('.q-select').filter({ hasText: /Source Type/ })).toBeVisible();
  });

  test('recent assets table renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Recent Uploads' })).toBeVisible();
  });

  test('validation rules toggles are visible', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Validation Rules' })).toBeVisible();
  });

  test('layout renders', async ({ page }) => {
    await expect(page.locator('.q-layout')).toBeVisible();
  });
});
