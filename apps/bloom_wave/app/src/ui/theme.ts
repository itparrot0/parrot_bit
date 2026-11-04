// 논리 해상도 1080×2340 (9:19.5) 기준 레이아웃 상수와 색
export const W = 1080;
export const H = 2340;

export const C = {
  bg: 0xf3efe6,
  bgDeep: 0xe7e0d2,
  panel: 0xffffff,
  ink: 0x2d2a26,
  inkSoft: 0x7a736a,
  accent: 0x46a758,
  accentDark: 0x2a7e3b,
  warn: 0xe5484d,
  slot: 0xfbf8f2,
  slotEdge: 0xd9cfbf,
  gold: 0xf5b301,
  locked: 0xc9c1b4,
  water: 0x3e9bdb,
};

export const FONT = "'Pretendard', 'Apple SD Gothic Neo', 'Noto Sans KR', 'Malgun Gothic', system-ui, sans-serif";

export const hexToNum = (h: string) => parseInt(h.replace("#", ""), 16);

export function mix(a: number, b: number, t: number): number {
  const ar = (a >> 16) & 255, ag = (a >> 8) & 255, ab = a & 255;
  const br = (b >> 16) & 255, bg = (b >> 8) & 255, bb = b & 255;
  return (Math.round(ar + (br - ar) * t) << 16) | (Math.round(ag + (bg - ag) * t) << 8) | Math.round(ab + (bb - ab) * t);
}
