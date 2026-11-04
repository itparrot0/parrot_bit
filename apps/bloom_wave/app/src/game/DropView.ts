// 활성 슬롯 4칸(좌 2 · 우 2)과 대기열(맨 앞 강조, 최대 7개 + "+N")
import { Container, Graphics, Sprite, Text } from "pixi.js";
import type { Drop, Level, State } from "@bloom-wave/core/engine";
import { TEX } from "../ui/textures";
import { C, hexToNum, mix } from "../ui/theme";
import { label } from "../ui/widgets";
import { tweens, ease } from "../ui/tween";
import { t } from "../i18n/i18n";

export const QUEUE_VISIBLE = 7;

class DropSprite extends Container {
  readonly body: Sprite;
  readonly num: Text;
  readonly tag: Container;
  constructor(public r: number) {
    super();
    this.body = new Sprite(TEX.drop);
    this.body.anchor.set(0.5, 0.58);
    this.body.width = this.body.height = r * 2;
    this.num = label("", r * 0.78, 0xffffff, { stroke: { color: 0x000000, width: r * 0.1, alpha: 0.35 } as never });
    this.num.y = r * 0.12;
    this.tag = new Container();
    const tg = new Graphics().roundRect(-r * 0.75, -r * 0.24, r * 1.5, r * 0.48, r * 0.24).fill({ color: C.ink });
    const tt = label(t("waiting"), r * 0.3, 0xffffff);
    this.tag.addChild(tg, tt);
    this.tag.y = -r * 1.05;
    this.addChild(this.body, this.num, this.tag);
  }
  set(d: Drop, level: Level, usable: boolean) {
    const col = hexToNum(level.palette[d.color]);
    this.body.tint = col;
    this.num.text = String(d.amount);
    // 흰색·밝은 물방울에서도 숫자가 보이도록
    const lum = ((col >> 16) & 255) * 0.3 + ((col >> 8) & 255) * 0.59 + (col & 255) * 0.11;
    this.num.style.fill = lum > 200 ? C.ink : 0xffffff;
    this.tag.visible = !usable;
  }
}

export class DropView extends Container {
  readonly slotPos: { x: number; y: number }[];
  private slotBg: Graphics[] = [];
  private slotDrops: DropSprite[] = [];
  private queueDrops: DropSprite[] = [];
  private more: Text;
  readonly queueRoot = new Container();
  private frontPos: { x: number; y: number };
  private bounceT = -1;
  onTapFront: () => void = () => {};

  constructor(private level: Level, slotPos: { x: number; y: number }[], queueY: number, queueLeft: number, queueRight: number) {
    super();
    this.slotPos = slotPos;
    const slotR = 78;
    slotPos.forEach((p, i) => {
      const g = new Graphics();
      g.position.set(p.x, p.y);
      this.slotBg.push(g);
      const d = new DropSprite(62);
      d.position.set(p.x, p.y);
      d.visible = false;
      d.label = `slot-${i}`;
      this.slotDrops.push(d);
      this.addChild(g, d);
    });
    this.drawSlots(0, slotR);

    // 대기열: 맨 앞은 크게, 나머지는 작게 한 줄
    this.addChild(this.queueRoot);
    this.frontPos = { x: queueLeft + 100, y: queueY };
    const frontBg = new Graphics().circle(0, 0, 112).fill({ color: C.panel }).circle(0, 0, 112).stroke({ color: C.slotEdge, width: 6 });
    frontBg.position.set(this.frontPos.x, this.frontPos.y);
    this.queueRoot.addChild(frontBg);
    const front = new DropSprite(86);
    front.position.set(this.frontPos.x, this.frontPos.y);
    front.label = "queue-front";
    this.queueDrops.push(front);
    const gap = (queueRight - (queueLeft + 250)) / (QUEUE_VISIBLE - 1);
    for (let k = 1; k < QUEUE_VISIBLE; k++) {
      const d = new DropSprite(50);
      d.position.set(queueLeft + 250 + (k - 1) * gap, queueY + 10);
      this.queueDrops.push(d);
    }
    this.queueDrops.forEach((d) => this.queueRoot.addChild(d));
    this.more = label("", 40, C.inkSoft);
    this.more.position.set(queueRight + 10, queueY + 10);
    this.queueRoot.addChild(this.more);

    // 대기열 영역 전체가 "맨 앞 탭" (한 손 조작, 큰 터치 영역)
    const hit = new Graphics().rect(queueLeft - 20, queueY - 150, queueRight - queueLeft + 120, 300).fill({ color: 0xffffff, alpha: 0.001 });
    hit.eventMode = "static";
    hit.cursor = "pointer";
    hit.label = "queue-hit";
    hit.on("pointerdown", () => this.onTapFront());
    this.queueRoot.addChildAt(hit, 0);
  }

  private drawSlots(occupied: number, r = 78) {
    const warn = occupied >= 3;
    this.slotBg.forEach((g) => {
      g.clear();
      g.circle(0, 6, r).fill({ color: 0x000000, alpha: 0.08 });
      g.circle(0, 0, r).fill({ color: warn ? mix(C.slot, C.warn, 0.18) : C.slot });
      g.circle(0, 0, r).stroke({ color: warn ? C.warn : C.slotEdge, width: 6 });
    });
  }

  /** 상태 전체를 다시 그림 (재시작·되돌리기·매 변경 후) */
  sync(s: State, flying = -1) {
    s.slots.forEach((d, i) => {
      const v = this.slotDrops[i];
      if (!d) { v.visible = false; return; }
      v.set(d, this.level, s.sproutCount[d.color] > 0);
      if (i !== flying) { v.visible = true; v.position.set(this.slotPos[i].x, this.slotPos[i].y); v.scale.set(1); }
    });
    this.drawSlots(s.slots.filter(Boolean).length);
    this.queueDrops.forEach((v, k) => {
      const d = s.queue[k];
      v.visible = !!d;
      if (d) v.set(d, this.level, s.sproutCount[d.color] > 0);
    });
    const extra = s.queue.length - QUEUE_VISIBLE;
    this.more.text = extra > 0 ? `+${extra}` : "";
  }

  /** 대기열 → 슬롯 곡선 비행 (엔진 상태는 이미 슬롯에 있음) */
  fly(slot: number, s: State) {
    const v = this.slotDrops[slot];
    const from = this.frontPos, to = this.slotPos[slot];
    this.sync(s, slot);
    v.visible = true;
    tweens.add(250, (k) => {
      const mx = (from.x + to.x) / 2, my = Math.min(from.y, to.y) - 260;
      const a = (1 - k) * (1 - k), b = 2 * (1 - k) * k, c = k * k;
      v.position.set(a * from.x + b * mx + c * to.x, a * from.y + b * my + c * to.y);
      v.scale.set(86 / 62 + (1 - 86 / 62) * k);
    }, { ease: ease.inOutSine, owner: v, done: () => v.scale.set(1) });
  }

  /** 슬롯 숫자 갱신 (틱마다) */
  pulseSlot(slot: number) {
    const v = this.slotDrops[slot];
    tweens.add(140, (k) => v.scale.set(1 + 0.12 * Math.sin(k * Math.PI)), { ease: ease.linear });
  }

  /** 빈 슬롯이 없을 때 탭: 슬롯이 짧게 흔들림 */
  shake() {
    [...this.slotBg, ...this.slotDrops].forEach((g, idx) => {
      const p = this.slotPos[idx % this.slotPos.length];
      tweens.add(300, (k) => { g.x = p.x + Math.sin(k * Math.PI * 6) * 14 * (1 - k); }, { ease: ease.linear, done: () => { g.x = p.x; } });
    });
  }

  /** 실패: 슬롯 4칸이 흔들리며 회색 */
  failFx() {
    this.shake();
    this.slotDrops.forEach((d) => { d.body.tint = mix(d.body.tint as number, 0x8a8a8a, 0.7); });
  }

  /** 웨이브가 멈추면 맨 앞이 살짝 튄다 ("이제 넣어야 한다") */
  bounceFront() { this.bounceT = 0; }

  update(dt: number) {
    const f = this.queueDrops[0];
    if (this.bounceT >= 0) {
      this.bounceT += dt;
      const k = this.bounceT / 900;
      f.y = this.frontPos.y - Math.abs(Math.sin(k * Math.PI * 2)) * 28 * Math.max(0, 1 - k);
      if (k >= 1) { this.bounceT = -1; f.y = this.frontPos.y; }
    }
  }

  slotCenter(i: number) { return this.slotPos[i]; }
}
