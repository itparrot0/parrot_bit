// 앱 아이콘 원본(1024×1024) 생성: app/assets/icon-only.png, icon-foreground.png, icon-background.png, splash.png
// 디자이너 아이콘이 오면 이 파일들만 교체하고 `npx capacitor-assets generate --android` 를 다시 실행한다.
import { writeFileSync } from "node:fs";
import pngjs from "pngjs";
const { PNG } = pngjs;

function draw(size: number, bg: [number, number, number] | null, scale: number) {
  const png = new PNG({ width: size, height: size });
  const c = size / 2;
  const petal: [number, number, number] = [0xe5, 0x48, 0x4d], center: [number, number, number] = [0xf5, 0xd9, 0x0a];
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const o = (y * size + x) * 4;
    let col: [number, number, number] | null = bg;
    // 픽셀 아트 느낌: 32칸 격자로 양자화
    const g = size / 32;
    const qx = (Math.floor(x / g) + 0.5) * g - c, qy = (Math.floor(y / g) + 0.5) * g - c;
    const r = Math.hypot(qx, qy) / (size * scale);
    const a = Math.atan2(qy, qx);
    const petalR = 0.42 * (0.72 + 0.28 * Math.cos(5 * (a + Math.PI / 2)));
    if (r < 0.13) col = center;
    else if (r < petalR) col = petal;
    if (col) { png.data[o] = col[0]; png.data[o + 1] = col[1]; png.data[o + 2] = col[2]; png.data[o + 3] = 255; }
    else png.data[o + 3] = 0;
  }
  return PNG.sync.write(png);
}
const out = process.argv[2] ?? "../../app/assets";
const bg: [number, number, number] = [0x46, 0xa7, 0x58];
writeFileSync(`${out}/icon-only.png`, draw(1024, bg, 1));
writeFileSync(`${out}/icon-foreground.png`, draw(1024, null, 0.62)); // 적응형 아이콘 안전 영역 안에
writeFileSync(`${out}/icon-background.png`, (() => { const p = new PNG({ width: 1024, height: 1024 }); for (let i = 0; i < p.data.length; i += 4) { p.data[i] = bg[0]; p.data[i + 1] = bg[1]; p.data[i + 2] = bg[2]; p.data[i + 3] = 255; } return PNG.sync.write(p); })());
writeFileSync(`${out}/splash.png`, draw(2732, [0xf3, 0xef, 0xe6], 0.18));
console.log("icons written to", out);
