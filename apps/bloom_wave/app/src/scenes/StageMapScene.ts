// 스테이지 맵: 레벨을 순서대로, 완성 여부와 잠금 상태 (별점 없음)
import { Container, Graphics } from "pixi.js";
import type { Ctx, Scene } from "../app";
import { C, W, H } from "../ui/theme";
import { iconButton, label } from "../ui/widgets";
import { ScrollView } from "../ui/scroll";
import { t, type Key } from "../i18n/i18n";
import { sfx } from "../audio/audio";
import { GameScene } from "./GameScene";

const COLS = 5;
const CELL = 196;
const BANDS: { from: number; key: Key }[] = [
  { from: 1, key: "bandIntro" }, { from: 31, key: "bandMid" }, { from: 81, key: "bandHard" },
];

export class StageMapScene implements Scene {
  readonly name = "map";
  readonly view = new Container();
  private scroll: ScrollView;
  private countText;

  constructor(private ctx: Ctx) {
    const top = ctx.safeTop;
    const back = iconButton("‹", 120);
    back.label = "btn-back";
    back.position.set(100, top + 110);
    back.onTap = () => ctx.back();
    const title = label(t("stages"), 60);
    title.position.set(W / 2, top + 110);
    this.countText = label("", 36, C.inkSoft, { fontWeight: "600" });
    this.countText.anchor.set(1, 0.5);
    this.countText.position.set(W - 50, top + 110);
    this.view.addChild(back, title, this.countText);
    const y0 = top + 220;
    this.scroll = new ScrollView(W, H - y0 - ctx.safeBottom);
    this.scroll.y = y0;
    this.view.addChild(this.scroll);
    this.build();
  }

  private build() {
    const c = this.scroll.content;
    c.removeChildren().forEach((x) => x.destroy({ children: true }));
    const { unlocked, cleared } = this.ctx.save.data;
    const levels = this.ctx.levels;
    let y = 0;
    let total = 0;
    const x0 = (W - COLS * CELL) / 2 + CELL / 2;
    let col = 0;
    let unlockedY = 0;
    for (let n = 1; n <= levels.length; n++) {
      const band = BANDS.find((b) => b.from === n);
      if (band || n === 1) {
        if (col) { y += CELL; col = 0; }
        const h = label(n === 1 ? t("bandIntro") : t(band!.key), 44, C.inkSoft);
        h.anchor.set(0, 0.5);
        h.position.set(60, y + 50);
        c.addChild(h);
        y += 110;
      }
      const lv = levels[n - 1];
      const s = !!cleared[lv.id];
      if (s) total++;
      const open = n <= unlocked;
      const item = new Container();
      item.position.set(x0 + col * CELL, y + CELL / 2);
      item.label = `stage-${n}`;
      const g = new Graphics();
      const boss = n === 30 || n === 80 || n === 120;
      g.roundRect(-80, -72, 160, 160, 40).fill({ color: 0x000000, alpha: 0.08 });
      g.roundRect(-80, -80, 160, 160, 40).fill({ color: !open ? C.locked : n === unlocked && !s ? C.accent : C.panel });
      if (boss) g.roundRect(-80, -80, 160, 160, 40).stroke({ color: C.gold, width: 8 });
      item.addChild(g);
      const num = label(open ? String(n) : "🔒", open ? 56 : 46, open && n === unlocked && !s ? 0xffffff : C.ink);
      num.y = -12;
      item.addChild(num);
      if (s) {
        // 완성 표시: 초록 꽃 배지
        const b = new Graphics().circle(0, 0, 22).fill({ color: C.accent });
        b.position.set(52, -52);
        const chk = label("✓", 30, 0xffffff);
        chk.position.set(52, -54);
        item.addChild(b, chk);
      }
      if (open) {
        item.eventMode = "static";
        item.cursor = "pointer";
        item.on("pointertap", () => { if (this.scroll.dragged) return; sfx.click(); this.ctx.push(new GameScene(this.ctx, n)); });
      }
      if (n === unlocked) unlockedY = y + CELL / 2;
      c.addChild(item);
      col++;
      if (col === COLS) { col = 0; y += CELL; }
    }
    if (col) y += CELL;
    this.scroll.contentHeight = y + 60;
    this.scroll.scrollTo(unlockedY);
    this.countText.text = t("clearedCount", { n: total, total: levels.length });
  }

  enter() { this.build(); }
  update(dt: number) { this.scroll.update(dt); }
}
