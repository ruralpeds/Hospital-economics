import { test, expect } from '@playwright/test';
import { waitForStippleReady } from '../helpers/page-helpers';

test.describe('Cohort Builder (E6)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/cohorts');
    await waitForStippleReady(page);
  });

  test('page renders title and preview button', async ({ page }) => {
    await expect(page.locator('h5').filter({ hasText: 'Cohort Builder' })).toBeVisible();
    await expect(page.locator('.q-btn').filter({ hasText: 'Preview Cohort' })).toBeVisible();
  });

  test('matching patients KPI card renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Matching Patients' })).toBeVisible();
  });

  test('inclusion criteria form renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Inclusion Criteria' })).toBeVisible();
  });

  test('exclusion criteria form renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Exclusion Criteria' })).toBeVisible();
  });

  test('saved cohorts table renders', async ({ page }) => {
    await expect(page.locator('.q-card').filter({ hasText: 'Saved Cohorts' })).toBeVisible();
  });

  test('save cohort button is visible', async ({ page }) => {
    await expect(page.locator('.q-btn').filter({ hasText: 'Save Cohort' })).toBeVisible();
  });

  test('layout renders', async ({ page }) => {
    await expect(page.locator('.q-layout')).toBeVisible();
  });
});
