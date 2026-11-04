// 흰색으로 그린 플레이스홀더 스프라이트. 색은 Sprite.tint 로 입힌다 (04 지시서: "흰색으로 그려 색은 코드에서").
// 디자이너 아트가 오면 public/assets 의 이미지로 이 텍스처들만 바꾸면 된다.
import { Graphics, type Renderer, type Texture } from "pixi.js";

export type Tex = {
  tile: Texture; // 칸 바탕 (둥근 사각형)
  seed: Texture; // 씨앗 점
  sprout: Texture; // 싹
  bloom: Texture; // 꽃
  glow: Texture; // 맨 앞 물방울 색 발아 칸 강조 테두리
  drop: Texture; // 물방울
  petal: Texture; // 꽃잎 파티클
  ring: Texture; // 슬롯 테두리
};

const S = 128;
export let TEX: Tex;

export function makeTextures(renderer: Renderer) {
  const gen = (draw: (g: Graphics) => void) => {
    const g = new Graphics();
    g.rect(0, 0, S, S).fill({ color: 0xffffff, alpha: 0 }); // 크기를 S×S로 고정
    draw(g);
    const t = renderer.generateTexture({ target: g, resolution: 1, antialias: true });
    g.destroy();
    return t;
  };
  TEX = {
    tile: gen((g) => g.roundRect(4, 4, S - 8, S - 8, 26).fill({ color: 0xffffff })),
    seed: gen((g) => { g.circle(S / 2, S / 2 + 6, 15).fill({ color: 0xffffff }); g.ellipse(S / 2, S / 2 - 4, 9, 13).fill({ color: 0xffffff }); }),
    sprout: gen((g) => {
      g.rect(S / 2 - 5, S / 2 - 6, 10, 40).fill({ color: 0xffffff });
      g.ellipse(S / 2 - 20, S / 2 - 14, 22, 12).fill({ color: 0xffffff });
      g.ellipse(S / 2 + 20, S / 2 - 22, 22, 12).fill({ color: 0xffffff });
    }),
    bloom: gen((g) => {
      for (let i = 0; i < 5; i++) {
        const a = -Math.PI / 2 + (i * 2 * Math.PI) / 5;
        g.circle(S / 2 + Math.cos(a) * 26, S / 2 + Math.sin(a) * 26, 22).fill({ color: 0xffffff });
      }
      g.circle(S / 2, S / 2, 16).fill({ color: 0xffffff });
    }),
    glow: gen((g) => g.roundRect(6, 6, S - 12, S - 12, 26).stroke({ color: 0xffffff, width: 12 })),
    drop: gen((g) => {
      g.moveTo(S / 2, 6).bezierCurveTo(S / 2 + 18, 40, S - 14, 62, S - 14, 82)
        .arc(S / 2, 82, S / 2 - 14, 0, Math.PI).bezierCurveTo(14, 62, S / 2 - 18, 40, S / 2, 6).fill({ color: 0xffffff });
    }),
    petal: gen((g) => g.ellipse(S / 2, S / 2, 40, 22).fill({ color: 0xffffff })),
    ring: gen((g) => g.circle(S / 2, S / 2, S / 2 - 8).stroke({ color: 0xffffff, width: 8 })),
  };
}
