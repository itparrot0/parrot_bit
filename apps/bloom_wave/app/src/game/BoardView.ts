// 보드: 칸 스프라이트 3종(씨앗/싹/꽃)에 tint 로 팔레트 색을 입힌다. 보드는 터치를 받지 않는다(자동 확산).
import { Container, Graphics, Sprite } from "pixi.js";
import { BLOOM, EMPTY, SEED, SPROUT, type Level, type State } from "@bloom-wave/core/engine";
import { TEX } from "../ui/textures";
import { hexToNum, mix } from "../ui/theme";
import { tweens, ease } from "../ui/tween";

export const BOARD_BG = 0x2f2a25;

type CellView = { root: Container; tile: Sprite; glyph: Sprite; glow: Sprite; st: number; color: number; ci: number };

export class BoardView extends Container {
  readonly cellSize: number;
  private views: (CellView | null)[] = [];
  private glowColor: number | null = null;
  private previewColor: number | null = null; // 팔레트 인덱스 (물방울을 누르고 있는 동안)
  private glowT = 0;
  private bg = new Graphics();
  readonly boardW: number;
  readonly boardH: number;
  /** 테두리(여백)까지 포함한 바깥 크기 */
  readonly outerW: number;
  readonly outerH: number;

  /** maxW·maxH 는 테두리까지 포함한 최대 크기 */
  constructor(private level: Level, maxW: number, maxH: number) {
    super();
    this.eventMode = "none";
    this.cellSize = Math.floor(Math.min(maxW / (level.width + 0.7), maxH / (level.height + 0.7)));
    this.boardW = this.cellSize * level.width;
    this.boardH = this.cellSize * level.height;
    const pad = Math.round(this.cellSize * 0.35);
    this.outerW = this.boardW + pad * 2;
    this.outerH = this.boardH + pad * 2;
    this.bg.roundRect(-this.boardW / 2 - pad, -this.boardH / 2 - pad, this.boardW + pad * 2, this.boardH + pad * 2, 36).fill({ color: BOARD_BG });
    this.addChild(this.bg);
    const cs = this.cellSize;
    for (let i = 0; i < level.cells.length; i++) {
      if (level.cells[i] === EMPTY) { this.views.push(null); continue; }
      const root = new Container();
      const p = this.localCenter(i);
      root.position.set(p.x, p.y);
      const mk = (tex: typeof TEX.tile, scale = 1) => {
        const s = new Sprite(tex);
        s.anchor.set(0.5);
        s.width = s.height = cs * scale;
        return s;
      };
      const tile = mk(TEX.tile), glyph = mk(TEX.seed, 0.9), glow = mk(TEX.glow, 1.02);
      glow.visible = false;
      root.addChild(tile, glyph, glow);
      this.addChild(root);
      this.views.push({ root, tile, glyph, glow, st: -99, color: hexToNum(level.palette[level.cells[i]]), ci: level.cells[i] });
    }
  }

  localCenter(i: number) {
    const x = i % this.level.width, y = Math.floor(i / this.level.width);
    return { x: -this.boardW / 2 + (x + 0.5) * this.cellSize, y: -this.boardH / 2 + (y + 0.5) * this.cellSize };
  }

  /** 부모 좌표계의 칸 중심 */
  cellCenter(i: number) {
    const p = this.localCenter(i);
    return { x: this.x + p.x * this.scale.x, y: this.y + p.y * this.scale.y };
  }

  sync(s: State) {
    tweens.cancel(this); // 진행 중인 연출은 버리고 상태를 그대로 그린다 (되돌리기·재시작)
    for (let i = 0; i < this.views.length; i++) {
      const v = this.views[i];
      if (!v) continue;
      v.st = -99;
      this.setCell(i, s.cell[i]);
    }
  }

  setCell(i: number, st: number) {
    const v = this.views[i];
    if (!v || v.st === st) return;
    v.st = st;
    const cs = this.cellSize;
    v.root.scale.set(1);
    if (st === SEED) {
      v.tile.tint = mix(BOARD_BG, v.color, 0.32);
      v.glyph.texture = TEX.seed; v.glyph.tint = mix(BOARD_BG, v.color, 0.62); v.glyph.width = v.glyph.height = cs * 0.9;
    } else if (st === SPROUT) {
      v.tile.tint = mix(BOARD_BG, v.color, 0.7);
      v.glyph.texture = TEX.sprout; v.glyph.tint = mix(v.color, 0xffffff, 0.75); v.glyph.width = v.glyph.height = cs * 0.95;
    } else if (st === BLOOM) {
      v.tile.tint = v.color;
      v.glyph.texture = TEX.bloom; v.glyph.tint = mix(v.color, 0xffffff, 0.5); v.glyph.width = v.glyph.height = cs * 0.85;
    }
    this.applyGlow(v);
  }

  private applyGlow(v: CellView) {
    if (this.previewColor !== null) {
      const on = v.ci === this.previewColor;
      v.root.alpha = on ? 1 : 0.22;
      v.glow.visible = on && v.st !== BLOOM;
      return;
    }
    v.root.alpha = 1;
    v.glow.visible = v.st === SPROUT && this.glowColor === v.color;
  }

  /** 물방울을 누르고 있는 동안: 그 색 칸만 또렷하게 + 빛남, 나머지는 흐리게 (null = 끔) */
  preview(colorIndex: number | null) {
    this.previewColor = colorIndex;
    for (const v of this.views) if (v) this.applyGlow(v);
  }

  /** 개화 연출: scale 0.6 → 1.15 → 1 */
  bloomCell(i: number, delay: number) {
    const v = this.views[i];
    if (!v) return;
    tweens.add(70, () => {}, { delay, owner: this, done: () => {
      this.setCell(i, BLOOM);
      tweens.add(260, (t) => {
        const s = t < 0.5 ? 0.6 + (1.15 - 0.6) * (t / 0.5) : 1.15 - 0.15 * ((t - 0.5) / 0.5);
        v.root.scale.set(s);
      }, { ease: ease.linear, owner: this });
    } });
  }

  /** 발아 연출: 싹이 돋음 */
  sproutCell(i: number, delay: number) {
    const v = this.views[i];
    if (!v) return;
    tweens.add(60, () => {}, { delay, owner: this, done: () => {
      this.setCell(i, SPROUT);
      const base = (this.cellSize * 0.95) / v.glyph.texture.width;
      tweens.add(260, (t) => v.glyph.scale.set(base, base * (0.3 + 0.7 * t)), { ease: ease.outBack, owner: this,
        done: () => v.glyph.scale.set(base) });
    } });
  }

  /** 맨 앞 물방울과 같은 색 발아 칸을 은은하게 빛나게 (null = 끔) */
  highlight(colorIndex: number | null) {
    this.glowColor = colorIndex === null ? null : hexToNum(this.level.palette[colorIndex]);
    for (const v of this.views) if (v) this.applyGlow(v);
  }

  update(dt: number) {
    this.glowT += dt;
    const a = 0.35 + 0.35 * (0.5 + 0.5 * Math.sin(this.glowT / 180));
    for (const v of this.views) if (v && v.glow.visible) v.glow.alpha = a;
  }

  /** 클리어 연출: 그림 전체가 반짝 */
  celebrate() {
    this.views.forEach((v, i) => {
      if (!v) return;
      const x = i % this.level.width, y = Math.floor(i / this.level.width);
      tweens.add(520, (t) => v.root.scale.set(1 + 0.18 * Math.sin(t * Math.PI)), { delay: (x + y) * 35, ease: ease.linear, owner: this });
    });
  }

  /** 실패 연출: 회색으로 */
  dim(on: boolean) { this.alpha = on ? 0.55 : 1; }
}
