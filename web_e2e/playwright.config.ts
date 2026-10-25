import { defineConfig } from '@playwright/test';

// Browser-level checks of the release web builds, in the installed Chrome
// (no browser download). Build first, from app/:
//   fvm flutter build web --release -o build/web-js
//   fvm flutter build web --release --wasm -o build/web-wasm
// Then, from web_e2e/:  npx playwright test
export default defineConfig({
  testDir: './tests',
  timeout: 120_000,
  expect: { timeout: 15_000 },
  workers: 1,
  reporter: [['list']],
  use: {
    channel: 'chrome',
    viewport: { width: 1280, height: 860 },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    // Prompts and pickers: headless is enough and keeps OS notifications quiet.
    { name: 'prompts', testMatch: /prompts\.spec\.ts/, use: { baseURL: 'http://localhost:5174', headless: true } },
    // Frame timings need a real, visible, unthrottled window.
    {
      name: 'perf',
      testMatch: /perf\.spec\.ts/,
      timeout: 600_000,
      use: {
        headless: false,
        launchOptions: {
          args: ['--disable-background-timer-throttling', '--disable-backgrounding-occluded-windows', '--disable-renderer-backgrounding'],
        },
      },
    },
  ],
  webServer: [
    { command: 'python ../tool/serve_web.py 5174 build/web-js', port: 5174, reuseExistingServer: true },
    { command: 'python ../tool/serve_web.py 5176 build/web-wasm --isolate', port: 5176, reuseExistingServer: true },
  ],
});
