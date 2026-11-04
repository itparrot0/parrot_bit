// TickEvent → 연출 타임라인. 슬롯에서 링 칸으로 물줄기, 개화(링 안에서 발아 순서대로 시차), 8방향 전염 칸의 싹.
// 각 틱의 연출은 다음 틱 전에 끝나도록 틱 간격 안에 맞춘다. 입력은 잠그지 않는다.
import { Container, Graphics } from "pixi.js";
import type { Level, TickEvent } from "@bloom-wave/core/engine";
import type { BoardView } from "./BoardView";
import type { DropView } from "./DropView";
import { hexToNum } from "../ui/theme";
import { tweens, ease } from "../ui/tween";
import { sfx } from "../audio/audio";
import { hapticLight } from "../platform";

export class WavePlayer {
  readonly fx = new Container();
  fast = false;

  constructor(private level: Level, private board: BoardView, private drops: DropView) {
    this.fx.eventMode = "none";
  }

  play(ev: TickEvent, tickMs: number) {
    // 2026-11-04 피드백: 연출이 너무 빨라 약 2배로 늦춤. 다음 틱 전에 끝나도록 틱 간격의 80% 안에 맞춘다
    const budget = tickMs * 0.8;
    let any = false;
    for (const b of ev.blooms) {
      any = true;
      const stagger = this.fast ? 0 : Math.min(40, budget / Math.max(1, b.cells.length));
      const from = this.drops.slotCenter(b.slot);
      const color = hexToNum(this.level.palette[b.color]);
      b.cells.forEach((i, k) => {
        this.board.bloomCell(i, k * stagger);
        if (!this.fast) this.stream(from, this.board.cellCenter(i), color, k * stagger);
      });
      this.drops.pulseSlot(b.slot);
    }
    // 전염: 개화와 같은 프레임 (조금 늦게 돋아 보이도록)
    const sStagger = this.fast ? 0 : Math.min(24, budget / Math.max(1, ev.sprouted.length));
    ev.sprouted.forEach((i, k) => this.board.sproutCell(i, 80 + k * sStagger));
    if (any) { sfx.bloom(); hapticLight(); }
  }

  private stream(from: { x: number; y: number }, to: { x: number; y: number }, color: number, delay: number) {
    const g = new Graphics();
    this.fx.addChild(g);
    tweens.add(320, (k) => {
      g.clear();
      const head = Math.min(1, k * 1.6), tail = Math.max(0, k * 1.6 - 0.6);
      const p = (u: number) => ({ x: from.x + (to.x - from.x) * u, y: from.y + (to.y - from.y) * u - Math.sin(u * Math.PI) * 60 });
      const a = p(tail), b = p(head), m = p((tail + head) / 2);
      g.moveTo(a.x, a.y).quadraticCurveTo(m.x, m.y, b.x, b.y).stroke({ color, width: 10, alpha: 0.75 * (1 - tail), cap: "round" });
    }, { delay, ease: ease.linear, owner: this, done: () => g.destroy() });
  }

  clear() { tweens.cancel(this); this.fx.removeChildren().forEach((c) => c.destroy()); }
}
