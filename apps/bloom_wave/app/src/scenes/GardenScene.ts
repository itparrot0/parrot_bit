// 정원(도감): 클리어한 그림을 꽃 핀 상태로 모아 본다. 같은 그림의 II 레벨은 하나로 친다.
import { Container, Graphics } from "pixi.js";
import type { Level } from "@bloom-wave/core/engine";
import type { Ctx, Scene } from "../app";
import { C, W, H } from "../ui/theme";
import { iconButton, label } from "../ui/widgets";
import { ScrollView } from "../ui/scroll";
import { artGraphic } from "../ui/art";
import { t, getLang } from "../i18n/i18n";

const COLS = 3;
const CELL = 320;

export class GardenScene implements Scene {
  readonly name = "garden";
  readonly view = new Container();

  constructor(ctx: Ctx) {
    const top = ctx.safeTop;
    const back = iconButton("‹", 120);
    back.label = "btn-back";
    back.position.set(100, top + 110);
    back.onTap = () => ctx.back();
    const title = label(t("garden"), 60);
    title.position.set(W / 2, top + 110);
    this.view.addChild(back, title);

    // 그림별로 처음 나오는 레벨
    const arts = new Map<string, Level>();
    for (const l of ctx.levels) { const a = l.meta?.art ?? l.id; if (!arts.has(a)) arts.set(a, l); }
    const cleared = new Set(ctx.levels.filter((l) => ctx.save.data.stars[l.id]).map((l) => l.meta?.art ?? l.id));
    const count = label(t("gardenCount", { n: cleared.size, total: arts.size }), 40, C.inkSoft);
    count.position.set(W / 2, top + 200);
    this.view.addChild(count);

    const y0 = top + 260;
    const scroll = new ScrollView(W, H - y0 - ctx.safeBottom);
    scroll.y = y0;
    this.view.addChild(scroll);
    this.update = (dt) => scroll.update(dt);
    if (!cleared.size) {
      const empty = label(t("gardenEmpty"), 44, C.inkSoft, { fontWeight: "500", lineHeight: 70 });
      empty.position.set(W / 2, 500);
      scroll.content.addChild(empty);
      scroll.contentHeight = 800;
      return;
    }
    // 완성한 그림 먼저, 아직인 그림은 실루엣
    const list = [...arts.entries()].sort((a, b) => Number(cleared.has(b[0])) - Number(cleared.has(a[0])));
    const x0 = (W - COLS * CELL) / 2 + CELL / 2;
    list.forEach(([art, lv], k) => {
      const done = cleared.has(art);
      const item = new Container();
      item.position.set(x0 + (k % COLS) * CELL, Math.floor(k / COLS) * (CELL + 60) + CELL / 2);
      item.label = done ? `garden-${art}` : "garden-locked";
      const bg = new Graphics().roundRect(-140, -140, 280, 280, 36).fill({ color: done ? C.panel : C.bgDeep });
      item.addChild(bg, artGraphic(lv, 220, { silhouette: !done }));
      const name = label(done ? (lv.meta?.name?.[getLang()] ?? art).replace(/ II$/, "") : "?", 34, done ? C.ink : C.inkSoft, { fontWeight: "600" });
      name.y = 175;
      item.addChild(name);
      scroll.content.addChild(item);
    });
    scroll.contentHeight = Math.ceil(list.length / COLS) * (CELL + 60) + 40;
  }

  update(_dt: number) {}
}
