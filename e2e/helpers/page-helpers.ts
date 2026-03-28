import { Page, expect, Locator } from '@playwright/test';

/**
 * Wait for the Stipple/Vue.js reactivity system to be ready.
 * Stipple renders a Vue app that binds to a WebSocket — we wait for
 * the Quasar layout container and Vue's mounted state.
 */
export async function waitForStippleReady(page: Page): Promise<void> {
  // Wait for the Quasar layout to mount (present in every page via app_layout)
  await page.waitForSelector('.q-layout', { timeout: 15_000 });
  // Give Vue/Stipple a moment to hydrate reactive bindings
  await page.waitForTimeout(500);
}

/**
 * Navigate to a page using the left navigation drawer.
 * Opens the drawer if needed, then clicks the matching link.
 */
export async function navigateViaDrawer(page: Page, linkText: string): Promise<void> {
  // Ensure drawer is visible (click menu button if drawer is hidden)
  const drawer = page.locator('.q-drawer');
  if (!(await drawer.isVisible())) {
    await page.locator('button:has(.q-icon)').first().click();
    await drawer.waitFor({ state: 'visible', timeout: 5_000 });
  }

  // Click the nav item whose label matches
  const navItem = drawer.locator('.q-item').filter({ hasText: linkText });
  await navItem.click();
  await waitForStippleReady(page);
}

/**
 * Extract a KPI card value by its overline label text.
 * KPI cards follow the pattern: <p class="text-overline">Label</p> <h4>Value</h4>
 */
export async function getKPIValue(page: Page, label: string): Promise<string> {
  const card = page.locator('.q-card').filter({ hasText: label });
  // The value is in the h4 (large KPIs) or h6 (small KPIs) following the label
  const valueEl = card.locator('h4, h5, h6').first();
  return (await valueEl.textContent()) ?? '';
}

/**
 * Get all visible KPI card labels on the current page.
 */
export async function getKPILabels(page: Page): Promise<string[]> {
  const labels = page.locator('.text-overline');
  return labels.allTextContents();
}

/**
 * Check that no JavaScript console errors occurred during page load.
 * Returns collected error messages.
 */
export function collectConsoleErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      errors.push(msg.text());
    }
  });
  return errors;
}

/**
 * Fill a Quasar number field (q-input type="number") identified by its label.
 */
export async function fillNumberField(page: Page, label: string, value: number): Promise<void> {
  const field = page.locator(`.q-field`).filter({ hasText: label }).locator('input');
  await field.fill(String(value));
}

/**
 * Get a Quasar slider locator by looking for the slider within a section
 * that contains the given text.
 */
export function getSliderContainer(page: Page, labelText: string): Locator {
  return page.locator('.q-card-section, .q-card__section').filter({ hasText: labelText });
}
