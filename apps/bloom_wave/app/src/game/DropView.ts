// 활성 슬롯(보드 아래 한 줄)과 대기열(세로 줄 여러 개).
// 줄마다 맨 위가 탭할 물방울이고, 그 아래로 options.visible 개까지만 보이며 나머지는 숫자로만 표시한다.
import { Container, Graphics, Sprite, Text } from "pixi.js";
import type { Drop, Level, State } from "@bloom-wave/core/engine";
import { TEX } from "../ui/textures";
import { C, hexToNum, mix } from "../ui/theme";
import { label } from "../ui/widgets";
import { tweens, ease } from "../ui/tween";

class DropSprite extends Container {
  readonly body: Sprite;
  readonly num: Text;
  constructor(public r: number) {
    super();
    this.body = new Sprite(TEX.drop);
    this.body.anchor.set(0.5, 0.58);
    this.body.width = this.body.height = r * 2;
    this.num = label("", r * 0.78, 0xffffff);
    this.num.y = r * 0.12;
    this.addChild(this.body, this.num);
  }
  set(d: Drop, level: Level) {
    const col = hexToNum(level.palette[d.color]);
    this.body.tint = col;
    this.num.text = String(d.amount);
    // 흰색·밝은 물방울에서도 숫자가 보이도록
    const lum = ((col >> 16) & 255) * 0.3 + ((col >> 8) & 255) * 0.59 + (col & 255) * 0.11;
    this.num.style.fill = lum > 200 ? C.ink : 0xffffff;
  }
}

export type DropLayout = {
  slots: { x: number; y: number }[];
  slotR: number;
  laneTop: number; // 줄 맨 앞 물방울 중심 y
  laneBottom: number; // 줄 영역 아래 끝 (터치 영역)
  laneXs: number[]; // 줄마다 중심 x
  laneW: number; // 줄 하나의 터치 폭
};

export class DropView extends Container {
  private slotBg: Graphics[] = [];
  private slotDrops: DropSprite[] = [];
  private lanes: { bg: Graphics; drops: DropSprite[]; more: Text; hit: Graphics }[] = [];
  private bounceT = -1;
  private bounceLanes: number[] = [];
  private visibleCount: number;
  onTap: (lane: number) => void = () => {};

  constructor(private level: Level, private L: DropLayout, visible: number) {
    super();
    this.visibleCount = Math.max(1, visible);
    L.slots.forEach((p, i) => {
      const g = new Graphics();
      g.position.set(p.x, p.y);
      g.label = `slot-bg-${i}`;
      this.slotBg.push(g);
      const d = new DropSprite(L.slotR * 0.8);
      d.position.set(p.x, p.y);
      d.visible = false;
      d.label = `slot-${i}`;
      this.slotDrops.push(d);
      this.addChild(g, d);
    });
    this.drawSlots(0);

    const frontR = Math.min(84, L.laneW * 0.36);
    const nextR = frontR * 0.62;
    level.lanes.forEach((_, li) => {
      const x = L.laneXs[li];
      const root = new Container();
      root.label = `lane-${li}`;
      const bg = new Graphics();
      const h = L.laneBottom - L.laneTop + frontR + 30;
      bg.roundRect(x - L.laneW / 2, L.laneTop - frontR - 30, L.laneW, h, 40).fill({ color: C.bgDeep, alpha: 0.6 });
      bg.circle(x, L.laneTop, frontR + 18).fill({ color: C.panel });
      root.addChild(bg);
      const drops: DropSprite[] = [];
      for (let k = 0; k < this.visibleCount; k++) {
        const d = new DropSprite(k === 0 ? frontR : nextR);
        d.position.set(x, k === 0 ? L.laneTop : L.laneTop + frontR + 40 + (k - 0.5) * nextR * 2.3);
        d.alpha = k === 0 ? 1 : 0.85;
        d.label = k === 0 ? `lane-front-${li}` : `lane-${li}-${k}`;
        drops.push(d);
        root.addChild(d);
      }
      const more = label("", 38, C.inkSoft);
      more.position.set(x, L.laneBottom - 34);
      root.addChild(more);
      // 줄 전체가 터치 영역 (한 손 조작)
      const hit = new Graphics().rect(x - L.laneW / 2, L.laneTop - frontR - 30, L.laneW, h).fill({ color: 0xffffff, alpha: 0.001 });
      hit.eventMode = "static";
      hit.cursor = "pointer";
      hit.label = `lane-hit-${li}`;
      hit.on("pointerdown", () => this.onTap(li));
      root.addChild(hit);
      this.lanes.push({ bg, drops, more, hit });
      this.addChild(root);
    });
  }

  private drawSlots(occupied: number) {
    const r = this.L.slotR;
    const warn = occupied >= 3;
    this.slotBg.forEach((g) => {
      g.clear();
      g.circle(0, 6, r).fill({ color: 0x000000, alpha: 0.08 });
      g.circle(0, 0, r).fill({ color: warn ? mix(C.slot, C.warn, 0.18) : C.slot });
      g.circle(0, 0, r).stroke({ color: warn ? C.warn : C.slotEdge, width: 6 });
    });
  }

  /** 상태 전체를 다시 그림 */
  sync(s: State, flying = -1) {
    s.slots.forEach((d, i) => {
      const v = this.slotDrops[i];
      if (!d) { if (i !== flying) v.visible = false; return; }
      v.set(d, this.level);
      if (i !== flying) {
        tweens.cancel(v);
        v.visible = true;
        v.position.set(this.L.slots[i].x, this.L.slots[i].y);
        v.scale.set(1);
      }
    });
    this.drawSlots(s.slots.filter(Boolean).length);
    this.lanes.forEach((lane, li) => {
      const q = s.lanes[li] ?? [];
      lane.drops.forEach((v, k) => {
        const d = q[k];
        v.visible = !!d;
        if (d) v.set(d, this.level);
      });
      const extra = q.length - this.visibleCount;
      lane.more.text = extra > 0 ? `+${extra}` : q.length ? "" : "—";
    });
  }

  /** 줄 맨 앞 → 슬롯 곡선 비행 (엔진 상태는 이미 슬롯에 있음) */
  fly(slot: number, lane: number, s: State) {
    const v = this.slotDrops[slot];
    const from = this.lanes[lane].drops[0].position.clone();
    const to = this.L.slots[slot];
    const k0 = this.lanes[lane].drops[0].r / v.r;
    this.sync(s, slot);
    v.visible = true;
    tweens.cancel(v);
    tweens.add(380, (k) => {
      const mx = (from.x + to.x) / 2, my = Math.min(from.y, to.y) - 160;
      const a = (1 - k) * (1 - k), b = 2 * (1 - k) * k, c = k * k;
      v.position.set(a * from.x + b * mx + c * to.x, a * from.y + b * my + c * to.y);
      v.scale.set(k0 + (1 - k0) * k);
    }, { ease: ease.inOutSine, owner: v, done: () => { v.position.set(to.x, to.y); v.scale.set(1); } });
  }

  pulseSlot(slot: number) {
    const v = this.slotDrops[slot];
    tweens.add(220, (k) => v.scale.set(1 + 0.12 * Math.sin(k * Math.PI)), { ease: ease.linear });
  }

  /** 빈 슬롯이 없을 때 탭: 슬롯이 짧게 흔들림 */
  shake() {
    this.slotBg.forEach((g, i) => {
      const p = this.L.slots[i];
      tweens.add(320, (k) => { g.x = p.x + Math.sin(k * Math.PI * 6) * 14 * (1 - k); }, { ease: ease.linear, done: () => { g.x = p.x; } });
    });
  }

  /** 실패: 슬롯이 흔들리며 회색 */
  failFx() {
    this.shake();
    this.slotDrops.forEach((d) => { d.body.tint = mix(d.body.tint as number, 0x8a8a8a, 0.7); });
  }

  /** 웨이브가 멈추면 맨 앞 물방울들이 살짝 튄다 ("이제 넣어야 한다") */
  bounceFront() { this.bounceLaneList(this.lanes.map((_, i) => i)); }

  /** 힌트: 탭할 줄 하나만 튄다 */
  bounceLane(lane: number) { if (this.lanes[lane]) this.bounceLaneList([lane]); }

  private bounceLaneList(list: number[]) {
    for (const l of this.lanes) l.drops[0].y = this.L.laneTop;
    this.bounceLanes = list;
    this.bounceT = 0;
  }

  update(dt: number) {
    if (this.bounceT < 0) return;
    this.bounceT += dt;
    const k = this.bounceT / 900;
    const off = Math.abs(Math.sin(k * Math.PI * 2)) * 22 * Math.max(0, 1 - k);
    for (const li of this.bounceLanes) this.lanes[li].drops[0].y = this.L.laneTop - off;
    if (k >= 1) { this.bounceT = -1; for (const l of this.lanes) l.drops[0].y = this.L.laneTop; }
  }

  slotCenter(i: number) { return this.L.slots[i]; }
  laneFront(li: number) { return this.lanes[li].drops[0]; }
}
