import { defineConfig } from "vitest/config";

export default defineConfig({
  base: "./", // Capacitor WebView에서 상대 경로로 로드
  build: { target: "es2022", outDir: "dist", chunkSizeWarningLimit: 1500 },
  server: { host: true, port: 5173 },
  test: { include: ["tests/**/*.test.ts"], testTimeout: 60_000 },
});
