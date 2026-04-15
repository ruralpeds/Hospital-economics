import { test, expect } from '@playwright/test';
import { waitForStippleReady } from '../helpers/page-helpers';

test.describe('Analysis Tool Pages', () => {

  // ── Sensitivity / Tornado Analysis ────────────────────────────────

  test.describe('Sensitivity Analysis', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/sensitivity');
      await waitForStippleReady(page);
    });

    test('page renders title and analyze button', async ({ page }) => {
      await expect(page.locator('h5').filter({ hasText: /Sensitivity.*Tornado/ })).toBeVisible();
      await expect(page.locator('.q-btn').filter({ hasText: 'Analyze' })).toBeVisible();
    });

    test('summary KPIs render', async ({ page }) => {
      for (const kpi of ['Base Net Income', 'Most Sensitive Variable', 'Max Swing']) {
        await expect(page.locator('.q-card').filter({ hasText: kpi })).toBeVisible();
      }
    });

    test('base financials input fields exist', async ({ page }) => {
      await expect(page.locator('.q-field').filter({ hasText: 'Base Revenue' })).toBeVisible();
      await expect(page.locator('.q-field').filter({ hasText: 'Base Expenses' })).toBeVisible();
    });
  });

  // ── Benchmarking Radar ────────────────────────────────────────────

  test.describe('Benchmarking Radar', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/benchmark');
      await waitForStippleReady(page);
    });

    test('page renders title and benchmark button', async ({ page }) => {
      await expect(page.locator('h5').filter({ hasText: 'Benchmarking Radar' })).toBeVisible();
      await expect(page.locator('.q-btn').filter({ hasText: 'Benchmark' })).toBeVisible();
    });

    test('summary KPIs include composite score and areas', async ({ page }) => {
      for (const kpi of ['Composite Score', 'Above Median', 'Weakest Area', 'Strongest Area']) {
        await expect(page.locator('.q-card').filter({ hasText: kpi })).toBeVisible();
      }
    });
  });

  // ── Closure Risk Assessment ───────────────────────────────────────

  test.describe('Closure Risk Assessment', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/closure-risk');
      await waitForStippleReady(page);
    });

    test('page renders title and run assessment button', async ({ page }) => {
      await expect(page.locator('h5').filter({ hasText: 'Closure Risk Assessment' })).toBeVisible();
      await expect(page.locator('.q-btn').filter({ hasText: 'Run Assessment' })).toBeVisible();
    });

    test('overall risk score card with circular progress renders', async ({ page }) => {
      const scoreCard = page.locator('.q-card').filter({ hasText: 'Overall Risk Score' });
      await expect(scoreCard).toBeVisible();
      // Circular progress indicator
      const circularProgress = scoreCard.locator('.q-circular-progress');
      await expect(circularProgress).toBeVisible();
    });

    test('financial distress index card renders', async ({ page }) => {
      await expect(page.locator('.q-card').filter({ hasText: 'Financial Distress Index' })).toBeVisible();
    });

    test('hospital selector dropdown exists', async ({ page }) => {
      const selector = page.locator('.q-select').filter({ hasText: /Hospital/ });
      await expect(selector).toBeVisible();
    });
  });

  // ── Break-even Analysis ───────────────────────────────────────────

  test.describe('Break-even Analysis', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/break-even');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
      await expect(page.locator('h5')).toBeVisible();
    });
  });

  // ── Cash Flow Projections ─────────────────────────────────────────

  test.describe('Cash Flow Projections', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/cash-flow');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
      await expect(page.locator('h5')).toBeVisible();
    });
  });

  // ── Staffing Optimizer ────────────────────────────────────────────

  test.describe('Staffing Optimizer', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/staffing');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
      await expect(page.locator('h5')).toBeVisible();
    });
  });

  // ── Payer Margin Analysis ─────────────────────────────────────────

  test.describe('Payer Margin Analysis', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/payer-margin');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
    });
  });

  // ── 340B Drug Pricing ─────────────────────────────────────────────

  test.describe('340B Drug Pricing', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/340b');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
    });
  });

  // ── Debt Capacity ─────────────────────────────────────────────────

  test.describe('Debt Capacity', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/debt-capacity');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
    });
  });

  // ── Service Line Profitability ────────────────────────────────────

  test.describe('Service Line Profitability', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/service-lines');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
    });
  });

  // ── Revenue Cycle ─────────────────────────────────────────────────

  test.describe('Revenue Cycle', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/revenue-cycle');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
    });
  });

  // ── Cost Structure ────────────────────────────────────────────────

  test.describe('Cost Structure', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/cost-structure');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
    });
  });

  // ── Workforce RVU ─────────────────────────────────────────────────

  test.describe('Workforce RVU', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/workforce');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
    });
  });

  // ── Community Impact ──────────────────────────────────────────────

  test.describe('Community Impact', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/community-impact');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
    });
  });

  // ── Strategic Planner ─────────────────────────────────────────────

  test.describe('Strategic Planner', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/strategic-plan');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
    });
  });

  // ── Policy Impact ─────────────────────────────────────────────────

  test.describe('Policy Impact', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/policy');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
    });
  });

  // ── Payer Negotiation ─────────────────────────────────────────────

  test.describe('Payer Negotiation', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/payer-negotiation');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
    });
  });

  // ── Cost Reimbursement ────────────────────────────────────────────

  test.describe('Cost Reimbursement', () => {
    test('page loads and renders layout', async ({ page }) => {
      await page.goto('/cost-reimbursement');
      await waitForStippleReady(page);
      await expect(page.locator('.q-layout')).toBeVisible();
    });
  });
});
