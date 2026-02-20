import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
  ],
});
