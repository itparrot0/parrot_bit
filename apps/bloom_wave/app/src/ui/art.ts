// 레벨 그림을 완성된(모두 개화한) 픽셀 아트로 그린다: 정원, 타이틀, 클리어 화면
import { Graphics } from "pixi.js";
import { EMPTY, type Level } from "@bloom-wave/core/engine";
import { hexToNum } from "./theme";

export function artGraphic(level: Level, maxSize: number, opts: { silhouette?: boolean } = {}): Graphics {
  const px = Math.max(1, Math.floor(maxSize / Math.max(level.width, level.height)));
  const g = new Graphics();
  const ox = (-level.width * px) / 2, oy = (-level.height * px) / 2;
  const gap = px >= 8 ? 1 : 0;
  for (let i = 0; i < level.cells.length; i++) {
    const c = level.cells[i];
    if (c === EMPTY) continue;
    const x = i % level.width, y = Math.floor(i / level.width);
    g.rect(ox + x * px + gap, oy + y * px + gap, px - gap * 2, px - gap * 2)
      .fill({ color: opts.silhouette ? 0xc9c1b4 : hexToNum(level.palette[c]) });
  }
  return g;
}
