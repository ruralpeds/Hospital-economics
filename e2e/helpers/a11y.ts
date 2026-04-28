import { expect, Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

export async function checkA11y(page: Page) {
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();

  const seriousViolations = results.violations.filter(
    v => v.impact === 'serious' || v.impact === 'critical'
  );

  expect(seriousViolations,
    `A11y violations: ${JSON.stringify(seriousViolations.map(v => ({ id: v.id, description: v.description })), null, 2)}`
  ).toHaveLength(0);
}
