// Capacitor 플러그인 래퍼. 웹(개발·테스트)에서도 그대로 돌도록 실패는 조용히 무시한다.
import { Capacitor } from "@capacitor/core";
import { App } from "@capacitor/app";
import { Haptics, ImpactStyle, NotificationType } from "@capacitor/haptics";
import { Preferences } from "@capacitor/preferences";
import type { KeyValueStore } from "./save/save";

export const isNative = Capacitor.isNativePlatform();

export const prefsStore: KeyValueStore = {
  async get(key) { return (await Preferences.get({ key })).value; },
  async set(key, value) { await Preferences.set({ key, value }); },
};

let vibrate = true;
let lastHaptic = 0;
export function setVibration(on: boolean) { vibrate = on; }
export function hapticLight() {
  if (!vibrate) return;
  const now = performance.now();
  if (now - lastHaptic < 90) return; // 틱마다 울리면 너무 잦다
  lastHaptic = now;
  Haptics.impact({ style: ImpactStyle.Light }).catch(() => {});
}
export function hapticFail() { if (vibrate) Haptics.notification({ type: NotificationType.Error }).catch(() => {}); }
export function hapticSuccess() { if (vibrate) Haptics.notification({ type: NotificationType.Success }).catch(() => {}); }

/** 앱이 백그라운드로 가거나(전화 수신 포함) 탭이 가려지면 onPause */
export function onLifecycle(onPause: () => void, onResume: () => void) {
  document.addEventListener("visibilitychange", () => (document.hidden ? onPause() : onResume()));
  if (isNative) {
    App.addListener("pause", onPause).catch(() => {});
    App.addListener("resume", onResume).catch(() => {});
  }
}

export function onBackButton(handler: () => void) {
  if (isNative) App.addListener("backButton", handler).catch(() => {});
  window.addEventListener("keydown", (e) => { if (e.key === "Escape") handler(); });
}

export function exitApp() { if (isNative) App.exitApp().catch(() => {}); }

export function openUrl(url: string) { window.open(url, "_blank", "noopener"); }

/** CSS env(safe-area-inset-*) 를 px로 읽는다 */
export function safeArea(): { top: number; bottom: number; left: number; right: number } {
  const el = document.getElementById("safe");
  if (!el) return { top: 0, bottom: 0, left: 0, right: 0 };
  const cs = getComputedStyle(el);
  const n = (v: string) => parseFloat(v) || 0;
  return { top: n(cs.paddingTop), bottom: n(cs.paddingBottom), left: n(cs.paddingLeft), right: n(cs.paddingRight) };
}
