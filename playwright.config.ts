import { defineConfig, devices } from '@playwright/test';

/**
 * See https://playwright.dev/docs/test-configuration.
 */
export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: false, // Run tests sequentially to avoid rate limiting
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1, // Use single worker to avoid parallel requests hitting rate limits
  reporter: 'html',
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:1337',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    // Run in headed mode if HEADED environment variable is set
    headless: !process.env.HEADED,
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  webServer: {
    command: 'pnpm start',
    url: 'http://localhost:1337',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
});

