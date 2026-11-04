// 설정: 사운드, 진동, 틱 속도(기본/느리게), 빠른 연출, 언어, 개인정보처리방침, 버전
import { Container, Graphics } from "pixi.js";
import type { Ctx, Scene } from "../app";
import { C, W, H } from "../ui/theme";
import { Button, Overlay, Segmented, Toggle, iconButton, label } from "../ui/widgets";
import { t, setLang, type Key } from "../i18n/i18n";
import { sfx } from "../audio/audio";
import { setVibration } from "../platform";
import pkg from "../../package.json";

const PRIVACY = {
  ko: "Bloom Wave 개인정보처리방침\n\nBloom Wave는 어떤 개인정보도 수집하거나 외부로 보내지 않습니다.\n게임 진행도와 설정은 이 기기 안에만 저장되며,\n앱을 삭제하면 함께 지워집니다.\n광고, 분석, 계정 기능이 없습니다.",
  en: "Bloom Wave Privacy Policy\n\nBloom Wave does not collect or transmit any personal data.\nYour progress and settings are stored only on this device\nand are removed when you uninstall the app.\nThere are no ads, analytics or accounts.",
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

    const privacy = new Button(t("privacy"), { w: W - 120, h: 140, color: C.panel, textColor: C.ink, id: "btn-privacy" });
    privacy.position.set(W / 2, y);
    privacy.onTap = () => this.showPrivacy();
    this.view.addChild(privacy);
    const ver = label(t("version", { v: pkg.version }), 36, C.inkSoft, { fontWeight: "500" });
    ver.position.set(W / 2, y + 160);
    this.view.addChild(ver);
  }

  private showPrivacy() {
    const o = new Overlay(W, H, 960, 1000, "overlay-privacy");
    const text = label(PRIVACY[this.ctx.save.data.settings.lang], 38, C.ink, { fontWeight: "500", wordWrap: true, wordWrapWidth: 860, lineHeight: 62 });
    text.y = -100;
    const ok = new Button("OK", { w: 400 });
    ok.y = 360;
    ok.onTap = () => o.destroy({ children: true });
    o.box.addChild(text, ok);
    this.view.addChild(o);
  }
}
