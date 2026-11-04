// 앱 공통 컨텍스트: Pixi 앱, 논리 해상도 스케일링, 씬 전환, 저장, 레벨 팩
import { Application, Container, Graphics } from "pixi.js";
import type { Level } from "@bloom-wave/core/engine";
import { C, H, W } from "./ui/theme";
import { tweens } from "./ui/tween";
import { SaveStore } from "./save/save";
import { safeArea } from "./platform";

export interface Scene {
  readonly name: string;
  readonly view: Container;
  enter?(): void;
  exit?(): void;
  update?(dt: number): void;
  /** 뒤로 가기를 직접 처리했으면 true */
  back?(): boolean;
  /** 앱이 백그라운드로 갔을 때 */
  pause?(): void;
}

export class Ctx {
  readonly root = new Container(); // 논리 좌표 1080×2340
  private bg = new Graphics();
  private stack: Scene[] = [];
  /** 논리 좌표 기준 안전 영역(노치·내비게이션 바) 여백 */
  safeTop = 0;
  safeBottom = 0;
  readonly params = new URLSearchParams(location.search);

  constructor(readonly app: Application, readonly save: SaveStore, readonly levels: Level[]) {
    app.stage.addChild(this.bg, this.root);
    this.layout();
    app.renderer.on("resize", () => this.layout());
    app.ticker.add((tk) => {
      const dt = Math.min(100, tk.deltaMS);
      // 게임 진행(틱)을 연출보다 먼저, 서로의 오류에 영향받지 않게
      try { this.current?.update?.(dt); } catch (e) { console.error(e); }
      tweens.update(dt);
    });
  }

  get current(): Scene | undefined { return this.stack[this.stack.length - 1]; }

  layout() {
    const sw = this.app.screen.width; // CSS 픽셀
    const sh = this.app.screen.height;
    const s = Math.min(sw / W, sh / H);
    this.root.scale.set(s);
    this.root.position.set((sw - W * s) / 2, (sh - H * s) / 2);
    this.bg.clear().rect(0, 0, sw, sh).fill({ color: C.bg });
    const sa = safeArea();
    // 화면이 논리 해상도보다 길면 남는 여백이 이미 안전 영역 역할을 한다
    const spareY = (sh - H * s) / 2;
    this.safeTop = Math.max(0, sa.top - spareY) / s;
    this.safeBottom = Math.max(0, sa.bottom - spareY) / s;
  }

  /** 씬 교체 (스택 맨 위를 바꿈) */
  replace(scene: Scene) {
    const prev = this.stack.pop();
    if (prev) this.detach(prev);
    this.push(scene);
  }

  push(scene: Scene) {
    const cur = this.current;
    if (cur) cur.view.visible = false;
    this.stack.push(scene);
    this.root.addChild(scene.view);
    scene.enter?.();
  }

  /** 스택을 비우고 이 씬 하나만 */
  reset(scene: Scene) {
    while (this.stack.length) this.detach(this.stack.pop()!);
    this.push(scene);
  }

  pop(): boolean {
    if (this.stack.length <= 1) return false;
    this.detach(this.stack.pop()!);
    const cur = this.current!;
    cur.view.visible = true;
    cur.enter?.();
    return true;
  }

  back() {
    const cur = this.current;
    if (cur?.back?.()) return;
    this.pop();
  }

  private detach(s: Scene) {
    s.exit?.();
    tweens.clear(); // 떠나는 씬의 연출이 파괴된 객체를 건드리지 않도록
    this.root.removeChild(s.view);
    s.view.destroy({ children: true });
  }

  levelNo(id: string) { return this.levels.findIndex((l) => l.id === id) + 1; }
}
