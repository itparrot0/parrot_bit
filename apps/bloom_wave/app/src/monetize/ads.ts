// 광고: 스테이지 완성 후 전면 광고 1회. 실패 시에는 광고 없음. 광고 제거 구매자는 건너뛴다.
// 네이티브는 AdMob(@capacitor-community/admob), 웹(개발·테스트)은 화면 안의 가짜 광고로 흐름만 확인한다.
//
// 출시 전 할 일: AdMob 콘솔에서 앱/광고 단위를 만들고 아래 ID 두 개와
// android/app/src/main/AndroidManifest.xml 의 APPLICATION_ID 를 실제 값으로 바꾼다.
// 지금 값은 Google이 공개한 테스트 ID 라서 실제 수익이 나지 않는다.
import { AdMob, InterstitialAdPluginEvents } from "@capacitor-community/admob";
import type { PluginListenerHandle } from "@capacitor/core";
import { isNative } from "../platform";

export const ADMOB = {
  testing: true,
  interstitialId: "ca-app-pub-3940256099942544/1033173712", // Google 테스트 전면 광고 단위
};

/** 몇 스테이지마다 광고를 보여 줄지 (1 = 매 스테이지) */
export const AD_EVERY = 1;

export interface AdProvider {
  init(): Promise<void>;
  /** 전면 광고를 보여 주고 닫히면 끝난다. 실패해도 게임은 계속된다 */
  showInterstitial(): Promise<void>;
}

class AdMobProvider implements AdProvider {
  private ready = false;
  async init() {
    try {
      await AdMob.initialize({ initializeForTesting: ADMOB.testing });
      void this.prepare();
    } catch { /* 광고 SDK 실패는 게임에 영향을 주지 않는다 */ }
  }
  private async prepare() {
    try { await AdMob.prepareInterstitial({ adId: ADMOB.interstitialId, isTesting: ADMOB.testing }); this.ready = true; }
    catch { this.ready = false; }
  }
  async showInterstitial() {
    if (!this.ready) { await this.prepare(); if (!this.ready) return; }
    const handles: PluginListenerHandle[] = [];
    await new Promise<void>((resolve) => {
      let done = false;
      const finish = () => { if (!done) { done = true; resolve(); } };
      void AdMob.addListener(InterstitialAdPluginEvents.Dismissed, finish).then((h) => handles.push(h));
      void AdMob.addListener(InterstitialAdPluginEvents.FailedToShow, finish).then((h) => handles.push(h));
      AdMob.showInterstitial().catch(finish);
      setTimeout(finish, 60_000);
    });
    this.ready = false;
    for (const h of handles) void h.remove().catch(() => {});
    void this.prepare(); // 다음 광고 미리 받기
  }
}

/** 웹용 가짜 광고: 화면을 덮는 패널을 잠깐 띄운다. 테스트(?noAds=1)에서는 바로 끝난다 */
class WebMockProvider implements AdProvider {
  constructor(private show: (done: () => void) => void) {}
  async init() {}
  showInterstitial() { return new Promise<void>((resolve) => this.show(resolve)); }
}

let provider: AdProvider | null = null;
let counter = 0;

export function initAds(webShow: (done: () => void) => void) {
  provider = isNative ? new AdMobProvider() : new WebMockProvider(webShow);
  void provider.init();
}

/** 스테이지 완성 뒤 호출. 광고 제거 구매자이거나 주기가 아니면 바로 끝난다 */
export async function afterClearAd(noAds: boolean): Promise<boolean> {
  if (noAds || !provider) return false;
  counter++;
  if (counter % AD_EVERY !== 0) return false;
  await provider.showInterstitial();
  return true;
}
