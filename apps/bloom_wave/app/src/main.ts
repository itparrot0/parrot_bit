import { Application } from "pixi.js";
import { solve } from "@bloom-wave/core/solver";
import type { Level } from "@bloom-wave/core/engine";
import { Ctx } from "./app";
import { C } from "./ui/theme";
import { makeTextures } from "./ui/textures";
import { SaveStore } from "./save/save";
import { detectLang, setLang } from "./i18n/i18n";
import { sfx } from "./audio/audio";
import { onBackButton, onLifecycle, prefsStore, setVibration } from "./platform";
import { TitleScene } from "./scenes/TitleScene";
import { GameScene } from "./scenes/GameScene";
import pack from "./levels/pack-01.json";

async function boot() {
  const levels = pack as unknown as Level[];
  const save = new SaveStore(prefsStore);
  const data = await save.load(detectLang());
  setLang(data.settings.lang);
  sfx.enabled = data.settings.sound;
  setVibration(data.settings.vibration);

  const app = new Application();
  await app.init({
    resizeTo: window, background: C.bg, antialias: true,
    resolution: Math.min(2, window.devicePixelRatio || 1), autoDensity: true,
    preference: "webgl",
  });
  document.getElementById("app")!.appendChild(app.canvas);
  makeTextures(app.renderer);

  const ctx = new Ctx(app, save, levels);
  ctx.reset(new TitleScene(ctx));

  onBackButton(() => ctx.back());
  onLifecycle(() => ctx.current?.pause?.(), () => {});

  // 테스트·디버그용 훅 (?manualTick=1 과 함께 Playwright 가 사용)
  const w = window as unknown as Record<string, unknown>;
  w.__bloom = {
    ctx, levels, solve,
    /** 레벨 n 을 바로 연다 */
    open(n: number) { ctx.reset(new TitleScene(ctx)); const g = new GameScene(ctx, n); ctx.push(g); return g; },
    game(): GameScene | null { return ctx.current instanceof GameScene ? ctx.current : null; },
  };
}

void boot();
