// PNG ↔ 칸 배열. 알파 < 128 → 빈 칸, 같은 RGB → 같은 색, maxColors를 넘으면 가까운 색끼리 병합.
import { readFileSync, writeFileSync } from "node:fs";
import pngjs from "pngjs";
import type { PixelArt } from "@bloom-wave/core/generator";
import { BLOOM, EMPTY, SEED, SPROUT, type Level, type State } from "@bloom-wave/core/engine";

const { PNG } = pngjs;

export type ImportResult = { art: PixelArt; warnings: string[] };

const hex = (r: number, g: number, b: number) =>
  "#" + [r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("").toUpperCase();
const rgb = (h: string) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const dist = (a: string, b: string) => {
  const [x, y] = [rgb(a), rgb(b)];
  return (x[0] - y[0]) ** 2 + (x[1] - y[1]) ** 2 + (x[2] - y[2]) ** 2;
};

export function decodePng(buf: Buffer, name: string, maxColors = 6): ImportResult {
  const png = PNG.sync.read(buf);
  const { width, height, data } = png;
  const warnings: string[] = [];
  if (width > 16 || height > 16) warnings.push(`${name}: ${width}x${height} — 16x16을 넘으면 모바일에서 칸이 너무 작아집니다`);
  const px: (string | null)[] = [];
  for (let i = 0; i < width * height; i++) {
    const o = i * 4;
    px.push(data[o + 3] < 128 ? null : hex(data[o], data[o + 1], data[o + 2]));
  }
  // 색별 칸 수 (등장 순서 유지 → 결정적)
  const counts = new Map<string, number>();
  for (const p of px) if (p) counts.set(p, (counts.get(p) ?? 0) + 1);
  const remap = new Map<string, string>([...counts.keys()].map((c) => [c, c]));
  // 가장 가까운 두 색을 합치기를 반복 (적은 쪽을 많은 쪽으로)
  let colors = [...counts.keys()];
  while (colors.length > maxColors) {
    let best: [string, string] = [colors[0], colors[1]], bd = Infinity;
    for (let i = 0; i < colors.length; i++) for (let j = i + 1; j < colors.length; j++) {
      const d = dist(colors[i], colors[j]);
      if (d < bd) { bd = d; best = [colors[i], colors[j]]; }
    }
    const [a, b] = best;
    const [keep, drop] = counts.get(a)! >= counts.get(b)! ? [a, b] : [b, a];
    counts.set(keep, counts.get(keep)! + counts.get(drop)!);
    counts.delete(drop);
    for (const [k, v] of remap) if (v === drop) remap.set(k, keep);
    colors = colors.filter((c) => c !== drop);
    warnings.push(`${name}: 색 ${drop} → ${keep} 병합 (최대 ${maxColors}색)`);
  }
  for (const c of colors) if (counts.get(c)! < 3) warnings.push(`${name}: 색 ${c}이 ${counts.get(c)}칸뿐입니다 — 이웃 색으로 합칠지 검토하세요`);
  const keys = "abcdefghijklmnopqrstuvwxyz";
  const palette = colors.map((c, i) => `${keys[i]}=${c}`);
  const rows: string[] = [];
  for (let y = 0; y < height; y++) {
    let row = "";
    for (let x = 0; x < width; x++) {
      const p = px[y * width + x];
      row += p ? keys[colors.indexOf(remap.get(p)!)] : ".";
    }
    rows.push(row);
  }
  return { art: { name, palette, rows }, warnings };
}

export function readPngArt(path: string, name: string, maxColors = 6): ImportResult {
  return decodePng(readFileSync(path), name, maxColors);
}

// 1칸 = 1픽셀 PNG
export function encodeArt(art: PixelArt): Buffer {
  const width = Math.max(...art.rows.map((r) => r.length)), height = art.rows.length;
  const png = new PNG({ width, height });
  const map = new Map(art.palette.map((p) => [p.split("=")[0], rgb(p.split("=")[1])]));
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const o = (y * width + x) * 4;
    const c = map.get(art.rows[y][x] ?? ".");
    if (c) { png.data[o] = c[0]; png.data[o + 1] = c[1]; png.data[o + 2] = c[2]; png.data[o + 3] = 255; }
    else png.data[o + 3] = 0;
  }
  return PNG.sync.write(png);
}

// 미리보기: 시작 상태(씨앗 = 어두운 색, 발아 = 밝은 색 + 테두리)를 칸당 scale 픽셀로
export function writePreview(path: string, level: Level, s: State, scale = 12) {
  const W = level.width * scale, H = level.height * scale;
  const png = new PNG({ width: W, height: H });
  for (let i = 0; i < level.cells.length; i++) {
    const st = s.cell[i];
    if (st === EMPTY) continue;
    const [r, g, b] = rgb(level.palette[level.cells[i]]);
    const k = st === SEED ? 0.35 : st === SPROUT ? 0.8 : st === BLOOM ? 1 : 0;
    const x0 = (i % level.width) * scale, y0 = Math.floor(i / level.width) * scale;
    for (let y = 0; y < scale; y++) for (let x = 0; x < scale; x++) {
      const o = ((y0 + y) * W + x0 + x) * 4;
      const edge = x === 0 || y === 0 || x === scale - 1 || y === scale - 1;
      const ring = st === SPROUT && (x < 2 || y < 2 || x >= scale - 2 || y >= scale - 2);
      const f = ring ? 1.25 : edge ? k * 0.8 : k;
      png.data[o] = Math.min(255, r * f); png.data[o + 1] = Math.min(255, g * f); png.data[o + 2] = Math.min(255, b * f);
      png.data[o + 3] = 255;
    }
  }
  writeFileSync(path, PNG.sync.write(png));
}
