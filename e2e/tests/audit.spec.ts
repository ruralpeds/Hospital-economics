import { test, expect } from '@playwright/test';
import { waitForStippleReady } from '../helpers/page-helpers';

test.describe('Audit Log tab', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/audit');
    await waitForStippleReady(page);
  });

  test('page loads and shows heading', async ({ page }) => {
    await expect(page.locator('h5, h4, h3').first()).toBeVisible({ timeout: 10000 });
  });

  test('run button is present', async ({ page }) => {
    await expect(page.locator('button').first()).toBeVisible();
  });

  test('layout renders without errors', async ({ page }) => {
    await expect(page.locator('.q-layout')).toBeVisible();
  });
});
