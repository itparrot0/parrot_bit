import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.itparrot.bloomwave",
  appName: "Bloom Wave",
  webDir: "dist",
  backgroundColor: "#F3EFE6",
  android: { allowMixedContent: false },
};

export default config;
