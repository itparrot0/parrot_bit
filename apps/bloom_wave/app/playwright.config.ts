import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "e2e",
  timeout: 120_000,
  // 브라우저: PW_CHANNEL 로 설치된 Chrome/Edge 를 쓸 수 있다 (기본: Playwright 번들 chromium)
  use: { baseURL: "http://localhost:4173", ...devices["Pixel 7"], browserName: "chromium", channel: process.env.PW_CHANNEL || undefined },
  webServer: { command: "npx vite build && npx vite preview --port 4173 --strictPort", port: 4173, reuseExistingServer: true, timeout: 120_000 },
});
