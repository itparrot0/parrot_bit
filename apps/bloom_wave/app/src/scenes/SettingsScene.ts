// 설정: 사운드, 진동, 틱 속도(기본/느리게), 빠른 연출, 언어, 광고 제거(인앱 결제), 개인정보처리방침, 버전
import { Container, Graphics } from "pixi.js";
import type { Ctx, Scene } from "../app";
import { C, W, H } from "../ui/theme";
import { Button, Overlay, Segmented, Toggle, iconButton, label } from "../ui/widgets";
import { t, setLang, type Key } from "../i18n/i18n";
import { sfx } from "../audio/audio";
import { setVibration } from "../platform";
import { billing, PRODUCTS } from "../monetize/billing";
import pkg from "../../package.json";

const PRIVACY = {
  ko: "Bloom Wave 개인정보처리방침\n\n게임 진행도와 설정은 이 기기 안에만 저장되며,\n앱을 삭제하면 함께 지워집니다.\n스테이지 완성 후 Google AdMob 광고가 표시되며,\nAdMob은 광고 제공을 위해 광고 ID 등 기기 정보를\n수집할 수 있습니다 (Google 개인정보처리방침 적용).\n광고 제거를 구매하면 광고가 표시되지 않습니다.\n계정·분석 기능은 없습니다.",
  en: "Bloom Wave Privacy Policy\n\nYour progress and settings are stored only on this device\nand are removed when you uninstall the app.\nAfter a stage is complete, Google AdMob ads are shown.\nAdMob may collect device data such as the advertising ID\nto serve ads (Google's Privacy Policy applies).\nBuying Remove Ads turns ads off.\nThere are no accounts or analytics.",
};

export class SettingsScene implements Scene {
  readonly name = "settings";
  readonly view = new Container();

  constructor(private ctx: Ctx) { this.build(); }

  private build() {
    const ctx = this.ctx;
    this.view.removeChildren().forEach((c) => c.destroy({ children: true }));
    const s = ctx.save.data.settings;
    const top = ctx.safeTop;
    const back = iconButton("‹", 120);
    back.label = "btn-back";
    back.position.set(100, top + 110);
    back.onTap = () => ctx.back();
    const title = label(t("settings"), 60);
    title.position.set(W / 2, top + 110);
    this.view.addChild(back, title);

    let y = top + 300;
    const row = (key: Key, control: Container) => {
      const bg = new Graphics().roundRect(60, y - 80, W - 120, 160, 40).fill({ color: C.panel });
      const l = label(t(key), 46);
      l.anchor.set(0, 0.5);
      l.position.set(110, y);
      control.position.set(W - 120 - (control.width / 2), y);
      this.view.addChild(bg, l, control);
      y += 190;
    };
    const sound = new Toggle(s.sound, "toggle-sound");
    sound.onChange = (v) => { sfx.enabled = v; void ctx.save.updateSettings({ sound: v }); };
    row("sound", sound);
    const vib = new Toggle(s.vibration, "toggle-vibration");
    vib.onChange = (v) => { setVibration(v); void ctx.save.updateSettings({ vibration: v }); };
    row("vibration", vib);
    const speed = new Segmented([{ key: "normal", text: t("tickNormal") }, { key: "slow", text: t("tickSlow") }], s.tickSpeed, 180, "seg-speed");
    speed.onChange = (v) => void ctx.save.updateSettings({ tickSpeed: v as "normal" | "slow" });
    row("tickSpeed", speed);
    const fast = new Toggle(s.fastFx, "toggle-fastfx");
    fast.onChange = (v) => void ctx.save.updateSettings({ fastFx: v });
    row("fastFx", fast);
    const lang = new Segmented([{ key: "ko", text: "한국어" }, { key: "en", text: "English" }], s.lang, 200, "seg-lang");
    lang.onChange = (v) => { setLang(v as "ko" | "en"); void ctx.save.updateSettings({ lang: v as "ko" | "en" }).then(() => this.build()); };
    row("language", lang);

    // 광고 제거 (관리형 상품 remove_ads). 구매하면 완성 후 광고를 건너뛴다
    const owned = ctx.save.data.noAds;
    const noAds = new Button(owned ? t("removeAdsOwned") : t("removeAds"), { w: 600, h: 140, color: owned ? C.bgDeep : C.accent, textColor: owned ? C.inkSoft : 0xffffff, id: "btn-remove-ads" });
    noAds.position.set(60 + 300, y);
    noAds.enabled = !owned;
    noAds.onTap = () => void this.buyNoAds();
    const restore = new Button(t("restorePurchases"), { w: W - 120 - 620, h: 140, color: C.panel, textColor: C.ink, size: 38, id: "btn-restore" });
    restore.position.set(W - 60 - (W - 120 - 620) / 2, y);
    restore.onTap = () => void this.restore();
    this.view.addChild(noAds, restore);
    y += 180;

    const privacy = new Button(t("privacy"), { w: W - 120, h: 140, color: C.panel, textColor: C.ink, id: "btn-privacy" });
    privacy.position.set(W / 2, y);
    privacy.onTap = () => this.showPrivacy();
    this.view.addChild(privacy);
    const ver = label(t("version", { v: pkg.version }), 36, C.inkSoft, { fontWeight: "500" });
    ver.position.set(W / 2, y + 160);
    this.view.addChild(ver);
  }

  private async buyNoAds() {
    const ok = await billing.purchase(PRODUCTS.removeAds).catch(() => false);
    if (ok) await this.ctx.save.setNoAds(true);
    this.build();
    this.notice(ok ? t("purchaseDone") : t("purchaseFailed"));
  }

  private async restore() {
    const owned: string[] = await billing.restore().catch(() => []);
    if (owned.includes(PRODUCTS.removeAds)) { await this.ctx.save.setNoAds(true); this.build(); this.notice(t("purchaseDone")); }
  }

  private notice(text: string) {
    const o = new Overlay(W, H, 820, 420, "overlay-notice");
    const l = label(text, 46);
    l.y = -60;
    const ok = new Button("OK", { w: 360, id: "btn-notice-ok" });
    ok.y = 100;
    ok.onTap = () => o.destroy({ children: true });
    o.box.addChild(l, ok);
    this.view.addChild(o);
  }

  private showPrivacy() {
    const o = new Overlay(W, H, 980, 1120, "overlay-privacy");
    const text = label(PRIVACY[this.ctx.save.data.settings.lang], 38, C.ink, { fontWeight: "500", wordWrap: true, wordWrapWidth: 860, lineHeight: 62 });
    text.y = -90;
    const ok = new Button("OK", { w: 400 });
    ok.y = 420;
    ok.onTap = () => o.destroy({ children: true });
    o.box.addChild(text, ok);
    this.view.addChild(o);
  }
}
