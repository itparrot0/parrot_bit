// 스테이지 맵: 레벨을 순서대로, 별점과 잠금 상태
import { Container, Graphics } from "pixi.js";
import type { Ctx, Scene } from "../app";
import { C, W, H } from "../ui/theme";
import { iconButton, label, stars, starPath } from "../ui/widgets";
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
  private starText;

  constructor(private ctx: Ctx) {
    const top = ctx.safeTop;
    const back = iconButton("‹", 120);
    back.label = "btn-back";
    back.position.set(100, top + 110);
    back.onTap = () => ctx.back();
    const title = label(t("stages"), 60);
    title.position.set(W / 2, top + 110);
    this.starText = label("", 42, C.inkSoft);
    this.starText.position.set(W - 150, top + 110);
    const st = new Graphics();
    starPath(st, 0, 0, 26, 12);
    st.fill({ color: C.gold });
    st.position.set(W - 240, top + 108);
    this.view.addChild(back, title, st, this.starText);
    const y0 = top + 220;
    this.scroll = new ScrollView(W, H - y0 - ctx.safeBottom);
    this.scroll.y = y0;
    this.view.addChild(this.scroll);
    this.build();
  }

  private build() {
    const c = this.scroll.content;
    c.removeChildren().forEach((x) => x.destroy({ children: true }));
    const { unlocked, stars: got } = this.ctx.save.data;
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
      const s = got[lv.id] ?? 0;
      total += s;
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
      if (s) { const ss = stars(s, 34, 4); ss.y = 46; item.addChild(ss); }
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
    this.starText.text = `${total} / ${levels.length * 3}`;
  }

  enter() { this.build(); }
  update(dt: number) { this.scroll.update(dt); }
}
