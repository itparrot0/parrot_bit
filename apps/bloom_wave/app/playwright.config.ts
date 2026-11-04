import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "e2e",
  timeout: 120_000,
  // 브라우저: PW_CHANNEL 로 설치된 Chrome/Edge 를 쓸 수 있다 (기본: Playwright 번들 chromium)
  // PW_EXECUTABLE_PATH 로 이미 설치된 chromium 실행 파일을 직접 지정할 수도 있다 (클라우드: /opt/pw-browsers/chromium)
  use: {
    baseURL: "http://localhost:4173", ...devices["Pixel 7"], browserName: "chromium", channel: process.env.PW_CHANNEL || undefined,
    launchOptions: process.env.PW_EXECUTABLE_PATH ? { executablePath: process.env.PW_EXECUTABLE_PATH } : {},
  },
  webServer: { command: "npx vite build && npx vite preview --port 4173 --strictPort", port: 4173, reuseExistingServer: true, timeout: 120_000 },
});
