import { test, expect } from '@playwright/test';
import { waitForStippleReady } from '../helpers/page-helpers';

test.describe('Data Preparation (E5)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/data/prepare');
    await waitForStippleReady(page);
  });

  test('page renders title and run pipeline button', async ({ page }) => {
    await expect(page.locator('h5').filter({ hasText: 'Data Preparation' })).toBeVisible();
    await expect(page.locator('.q-btn').filter({ hasText: 'Run Pipeline' })).toBeVisible();
  });

  test('transform selector is present', async ({ page }) => {
    await expect(page.locator('.q-select').filter({ hasText: /Transform/ })).toBeVisible();
  });

  test('commit output button renders disabled initially', async ({ page }) => {
    const commitBtn = page.locator('.q-btn').filter({ hasText: 'Commit Output' });
    await expect(commitBtn).toBeVisible();
  });

  test('layout renders', async ({ page }) => {
    await expect(page.locator('.q-layout')).toBeVisible();
  });
});
