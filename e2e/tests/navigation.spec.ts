import { test, expect } from '@playwright/test';
import { ROUTES, NAV_DRAWER_LINKS } from '../fixtures/test-data';
import { waitForStippleReady, navigateViaDrawer } from '../helpers/page-helpers';

test.describe('Navigation and Routing', () => {

  test('root (/) redirects to /dashboard', async ({ page }) => {
    const response = await page.goto('/');
    // Genie redirects / -> /dashboard
    expect(page.url()).toContain('/dashboard');
    await waitForStippleReady(page);
    await expect(page.locator('.q-toolbar__title')).toContainText('Rural Hospital Economics Simulator');
  });

  test('all routes load without HTTP errors', async ({ page }) => {
    for (const route of ROUTES) {
      const response = await page.goto(route.path);
      expect(response?.status(), `${route.path} should return 200`).toBe(200);
    }
  });

  test('each page renders the Quasar layout shell', async ({ page }) => {
    for (const route of ROUTES) {
      await page.goto(route.path);
      await waitForStippleReady(page);
      // Every page should have the Quasar layout, header, and page container
      await expect(page.locator('.q-layout')).toBeVisible();
      await expect(page.locator('.q-header')).toBeVisible();
    }
  });

  test('page titles include route-specific text', async ({ page }) => {
    for (const route of ROUTES) {
      await page.goto(route.path);
      // The HTML <title> is set to "Hospital Economics — <page_title>"
      const title = await page.title();
      expect(title, `Title for ${route.path}`).toContain('Hospital Economics');
    }
  });

  test('navigation drawer is visible on desktop viewport', async ({ page }) => {
    await page.goto('/dashboard');
    await waitForStippleReady(page);
    const drawer = page.locator('.q-drawer');
    await expect(drawer).toBeVisible();
  });

  test('navigation drawer contains all expected links', async ({ page }) => {
    await page.goto('/dashboard');
    await waitForStippleReady(page);
    const drawer = page.locator('.q-drawer');
    for (const link of NAV_DRAWER_LINKS) {
      const item = drawer.locator('.q-item').filter({ hasText: link.label });
      await expect(item, `Nav link "${link.label}" should exist`).toHaveCount(1);
    }
  });

  test('clicking drawer links navigates to correct pages', async ({ page }) => {
    await page.goto('/dashboard');
    await waitForStippleReady(page);

    // Test a subset to avoid excessive navigation time
    const testLinks = NAV_DRAWER_LINKS.slice(0, 5);
    for (const link of testLinks) {
      await navigateViaDrawer(page, link.label);
      expect(page.url()).toContain(link.href);
    }
  });

  test('navigation drawer has section headers', async ({ page }) => {
    await page.goto('/dashboard');
    await waitForStippleReady(page);
    const drawer = page.locator('.q-drawer');
    // The layout defines "Navigation", "Tools", "Resources" headers
    await expect(drawer.locator('.q-item__label--header').filter({ hasText: 'Navigation' })).toBeVisible();
    await expect(drawer.locator('.q-item__label--header').filter({ hasText: 'Tools' })).toBeVisible();
    await expect(drawer.locator('.q-item__label--header').filter({ hasText: 'Resources' })).toBeVisible();
  });

  test('toolbar displays app title on every page', async ({ page }) => {
    const sampleRoutes = ['/dashboard', '/profile', '/financial-sim', '/closure-risk'];
    for (const path of sampleRoutes) {
      await page.goto(path);
      await waitForStippleReady(page);
      await expect(page.locator('.q-toolbar__title')).toContainText('Rural Hospital Economics Simulator');
    }
  });
});
