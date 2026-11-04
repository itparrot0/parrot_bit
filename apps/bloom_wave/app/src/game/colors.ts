// 색 구분 도우미: 팔레트에서 서로 비슷한 색(명도·채도가 가까운 색) 찾기.
// 2026-11-04 2차 피드백: 비슷한 색이 많은 그림은 구분이 어려워, 처음 나오는 낮은 스테이지에서 도움말을 띄운다.
import type { Level } from "@bloom-wave/core/engine";

/** CIE Lab 거리(ΔE76) 가 이보다 작으면 "비슷한 색" */
export const SIMILAR_DE = 25;

function lab(hex: string): [number, number, number] {
  const n = parseInt(hex.replace("#", ""), 16);
  const lin = (v: number) => { v /= 255; return v > 0.04045 ? ((v + 0.055) / 1.055) ** 2.4 : v / 12.92; };
  const r = lin((n >> 16) & 255), g = lin((n >> 8) & 255), b = lin(n & 255);
  const x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  const y = r * 0.2126 + g * 0.7152 + b * 0.0722;
  const z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;
  const f = (t: number) => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

export function colorDistance(a: string, b: string): number {
  const A = lab(a), B = lab(b);
  return Math.hypot(A[0] - B[0], A[1] - B[1], A[2] - B[2]);
}

/** 레벨 팔레트에서 가장 비슷한 두 색 (인덱스). 기준보다 멀면 null */
export function similarPair(level: Level, maxDe = SIMILAR_DE): [number, number] | null {
  let best: [number, number] | null = null, bestD = maxDe;
  for (let a = 0; a < level.palette.length; a++)
    for (let b = a + 1; b < level.palette.length; b++) {
      const d = colorDistance(level.palette[a], level.palette[b]);
      if (d < bestD) { bestD = d; best = [a, b]; }
    }
  return best;
}

/** 비슷한 색이 처음 나오는 레벨 번호 (1부터). 없으면 0 */
export function firstSimilarLevel(levels: Level[]): number {
  return levels.findIndex((l) => similarPair(l) !== null) + 1;
}
