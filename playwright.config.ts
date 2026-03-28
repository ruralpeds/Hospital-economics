import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for Rural Hospital Economics Simulator.
 * See https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
  testDir: './e2e/tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 1,
  workers: process.env.CI ? 1 : undefined,
  reporter: [['html', { open: 'never' }]],
  timeout: 30_000,

  use: {
    baseURL: 'http://localhost:8000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  /* Optionally start the Genie.jl server before tests */
  // webServer: {
  //   command: 'julia --project=. app/app.jl',
  //   url: 'http://localhost:8000/api/health',
  //   reuseExistingServer: !process.env.CI,
  //   timeout: 120_000,
  // },
});
