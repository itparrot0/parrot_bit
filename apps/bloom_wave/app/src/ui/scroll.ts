// 세로 스크롤 영역. 드래그로 움직이고, 조금만 움직였을 때는 안쪽 버튼의 탭으로 둔다.
import { Container, Graphics, type FederatedPointerEvent } from "pixi.js";

export class ScrollView extends Container {
  readonly content = new Container();
  private maskG = new Graphics();
  private dragY: number | null = null;
  private startY = 0;
  private vel = 0;
  private lastY = 0;
  private lastT = 0;
  /** 드래그로 간주된 직후에는 탭을 무시하도록 안쪽에서 확인 */
  dragged = false;
  contentHeight = 0;

  constructor(readonly w: number, readonly h: number) {
    super();
    this.maskG.rect(0, 0, w, h).fill({ color: 0xffffff });
    this.addChild(this.maskG, this.content);
    this.content.mask = this.maskG;
    this.eventMode = "static";
    this.hitArea = { contains: (x: number, y: number) => x >= 0 && y >= 0 && x <= w && y <= h };
    this.on("pointerdown", (e: FederatedPointerEvent) => {
      const p = this.toLocal(e.global);
      this.dragY = p.y; this.startY = this.content.y; this.dragged = false; this.vel = 0;
      this.lastY = p.y; this.lastT = performance.now();
    });
    this.on("globalpointermove", (e: FederatedPointerEvent) => {
      if (this.dragY === null) return;
      const p = this.toLocal(e.global);
      if (Math.abs(p.y - this.dragY) > 14) this.dragged = true;
      if (this.dragged) this.setY(this.startY + p.y - this.dragY);
      const now = performance.now();
      this.vel = (p.y - this.lastY) / Math.max(1, now - this.lastT);
      this.lastY = p.y; this.lastT = now;
    });
    const end = () => { this.dragY = null; setTimeout(() => (this.dragged = false), 0); };
    this.on("pointerup", end);
    this.on("pointerupoutside", end);
    this.on("wheel", (e: WheelEvent) => this.setY(this.content.y - e.deltaY));
  }

  private minY() { return Math.min(0, this.h - this.contentHeight); }
  setY(y: number) { this.content.y = Math.max(this.minY(), Math.min(0, y)); }
  scrollTo(contentY: number) { this.setY(-contentY + this.h / 2); }

  update(dt: number) {
    if (this.dragY !== null || Math.abs(this.vel) < 0.01) return;
    this.setY(this.content.y + this.vel * dt);
    this.vel *= Math.pow(0.995, dt);
  }
}
