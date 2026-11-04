// 버튼·패널·토글 같은 공통 UI (Pixi Graphics 플레이스홀더)
import { Container, Graphics, Text, type TextStyleOptions } from "pixi.js";
import { C, FONT } from "./theme";
import { tweens, ease } from "./tween";
import { sfx } from "../audio/audio";

export function label(text: string, size = 44, color = C.ink, extra: Partial<TextStyleOptions> = {}): Text {
  const tx = new Text({ text, style: { fontFamily: FONT, fontSize: size, fill: color, fontWeight: "700", align: "center", ...extra } });
  tx.anchor.set(0.5);
  return tx;
}

export type ButtonOpts = { w?: number; h?: number; color?: number; textColor?: number; size?: number; radius?: number; id?: string };

export class Button extends Container {
  private bg = new Graphics();
  readonly text: Text;
  private _enabled = true;
  private opts: Required<Omit<ButtonOpts, "id">>;
  onTap: () => void = () => {};

  constructor(text: string, opts: ButtonOpts = {}) {
    super();
    this.opts = { w: 420, h: 130, color: C.accent, textColor: 0xffffff, size: 46, radius: 40, ...opts };
    this.text = label(text, this.opts.size, this.opts.textColor);
    this.addChild(this.bg, this.text);
    this.draw();
    this.eventMode = "static";
    this.cursor = "pointer";
    if (opts.id) this.label = opts.id;
    this.on("pointerdown", () => { if (this._enabled) this.scale.set(0.96); });
    this.on("pointerupoutside", () => this.scale.set(1));
    this.on("pointerup", () => this.scale.set(1));
    this.on("pointertap", () => { if (this._enabled) { sfx.click(); this.onTap(); } });
  }

  setText(s: string) { this.text.text = s; }
  set enabled(v: boolean) { this._enabled = v; this.alpha = v ? 1 : 0.4; this.cursor = v ? "pointer" : "default"; }
  get enabled() { return this._enabled; }
  setColor(c: number) { this.opts.color = c; this.draw(); }

  private draw() {
    const { w, h, color, radius } = this.opts;
    this.bg.clear();
    this.bg.roundRect(-w / 2, -h / 2 + 8, w, h, radius).fill({ color: 0x000000, alpha: 0.12 });
    this.bg.roundRect(-w / 2, -h / 2, w, h, radius).fill({ color });
  }
}

/** 동그란 아이콘 버튼 (뒤로, 일시정지 등). 아이콘은 글자 하나로 그린다 */
export function iconButton(glyph: string, size = 120, color = C.panel, glyphColor = C.ink): Button {
  return new Button(glyph, { w: size, h: size, radius: size / 2, color, textColor: glyphColor, size: size * 0.45 });
}

export function panel(w: number, h: number, color = C.panel, radius = 48): Graphics {
  const g = new Graphics();
  g.roundRect(-w / 2, -h / 2 + 10, w, h, radius).fill({ color: 0x000000, alpha: 0.1 });
  g.roundRect(-w / 2, -h / 2, w, h, radius).fill({ color });
  return g;
}

/** 화면 전체를 덮는 반투명 막 + 가운데 패널. 막을 탭해도 아래로 입력이 가지 않는다 */
export class Overlay extends Container {
  readonly box = new Container();
  constructor(w: number, h: number, boxW: number, boxH: number, id?: string) {
    super();
    const dim = new Graphics().rect(-4000, -4000, 8000 + w, 8000 + h).fill({ color: 0x1d1a16, alpha: 0.55 });
    dim.eventMode = "static";
    this.addChild(dim, this.box);
    this.box.position.set(w / 2, h / 2);
    this.box.addChild(panel(boxW, boxH));
    if (id) this.label = id;
    this.alpha = 0;
    tweens.add(200, (v) => { this.alpha = v; this.box.scale.set(0.9 + 0.1 * v); }, { ease: ease.outBack });
  }
}

export function stars(n: number, size = 56, gap = 10): Container {
  const c = new Container();
  for (let i = 0; i < 3; i++) {
    const g = new Graphics();
    starPath(g, 0, 0, size / 2, size / 4.4);
    g.fill({ color: i < n ? C.gold : 0xd9d2c5 });
    g.x = (i - 1) * (size + gap);
    c.addChild(g);
  }
  return c;
}

export function starPath(g: Graphics, cx: number, cy: number, r1: number, r2: number) {
  const pts: number[] = [];
  for (let i = 0; i < 10; i++) {
    const r = i % 2 ? r2 : r1;
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    pts.push(cx + Math.cos(a) * r, cy + Math.sin(a) * r);
  }
  g.poly(pts);
}

export class Toggle extends Container {
  private bg = new Graphics();
  private knob = new Graphics();
  value: boolean;
  onChange: (v: boolean) => void = () => {};
  constructor(value: boolean, id?: string) {
    super();
    this.value = value;
    this.addChild(this.bg, this.knob);
    this.knob.circle(0, 0, 34).fill({ color: 0xffffff });
    this.eventMode = "static";
    this.cursor = "pointer";
    if (id) this.label = id;
    this.on("pointertap", () => { this.value = !this.value; sfx.click(); this.draw(); this.onChange(this.value); });
    this.draw();
  }
  draw() {
    this.bg.clear().roundRect(-70, -44, 140, 88, 44).fill({ color: this.value ? C.accent : C.locked });
    this.knob.x = this.value ? 26 : -26;
  }
}

/** 선택지 두 개짜리 세그먼트 버튼 (틱 속도, 언어) */
export class Segmented extends Container {
  private items: { key: string; bg: Graphics; text: Text }[] = [];
  value: string;
  onChange: (v: string) => void = () => {};
  constructor(options: { key: string; text: string }[], value: string, w = 200, id?: string) {
    super();
    this.value = value;
    if (id) this.label = id;
    options.forEach((o, i) => {
      const item = new Container();
      const bg = new Graphics();
      const text = label(o.text, 38);
      item.addChild(bg, text);
      item.x = (i - (options.length - 1) / 2) * (w + 12);
      item.eventMode = "static";
      item.cursor = "pointer";
      item.label = `${id ?? "seg"}-${o.key}`;
      item.on("pointertap", () => { this.value = o.key; sfx.click(); this.draw(w); this.onChange(o.key); });
      this.items.push({ key: o.key, bg, text });
      this.addChild(item);
    });
    this.draw(w);
  }
  private draw(w: number) {
    for (const it of this.items) {
      const on = it.key === this.value;
      it.bg.clear().roundRect(-w / 2, -44, w, 88, 30).fill({ color: on ? C.accent : C.bgDeep });
      it.text.style.fill = on ? 0xffffff : C.ink;
    }
  }
}
