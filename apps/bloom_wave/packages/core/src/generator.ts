// 레벨 생성기: 픽셀 아트 -> (해상도 배율) -> 시작 발아 지점 -> 물방울 순서 -> 여러 줄 대기열.
// 핵심 아이디어: 한 판을 "두어 보면서" 쓰인 물방울을 기록해 순서를 만들고(구성적 생성),
// 그 순서를 여러 줄에 나눠 담는다. 각 줄이 원래 순서의 부분열이므로 원래 순서대로 꺼내면 항상 클리어된다.
// 이후 줄 안에서 앞당기기 / 다른 줄로 옮기기를 할 때마다 솔버로 다시 검증한다.

import {
  EMPTY, DIR8, type Action, type Difficulty, type Drop, type Level, type Options, DEFAULT_OPTIONS,
  applyAction, cloneState, createState, deploy, runUntilStable,
} from "./engine.ts";
import { randomWinRate, solve } from "./solver.ts";

export type PixelArt = { name: string; palette: string[]; rows: string[] }; // rows: 팔레트 문자 또는 '.'

export type GenParams = {
  seed: number;
  starts: number; // 시작 발아 지점 수 (8방향으로 이어진 덩어리마다 최소 1개는 자동 보장)
  dropMin: number; // 물방울 하나의 최소 양
  dropMax: number; // 물방울 하나의 최대 양
  displacements: number; // 대기열을 흔드는 시도 횟수
  lanes?: number; // 대기열 줄 수 (기본 3)
  scale?: number; // 그림 해상도 배율 (2면 한 픽셀이 2×2 칸)
  targetPeak?: number; // 목표: 클리어 수순 중 활성 슬롯이 동시에 몇 칸까지 차는가 (기본 slotCount-1)
  targetWinRate?: number; // 무작위 클리어율 목표 (기본 0.3)
  options?: Options;
  slotCount?: number;
  maxSolverNodes?: number;
  trials?: number; // 최종 무작위 클리어율 측정 판 수 (기본 300)
};

export type GenReport = {
  level: Level;
  colors: number;
  cells: number;
  drops: number;
  displacementsApplied: number;
  peakSlots: number; // 클리어 수순에서 슬롯 최대 점유
  avgSlots: number; // 탭할 때마다 차 있던 슬롯 수의 평균
  randomWinRate: number;
  solverNodes: number;
  score: number; // 0~100 대략적 난이도
  difficulty: Difficulty;
};

export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** 무작위 클리어율 → 난이도 등급. 앱은 hard 이상에서 시작 전에 경고창을 띄운다 */
export function difficultyOf(winRate: number): Difficulty {
  if (winRate >= 0.3) return "normal";
  if (winRate >= 0.15) return "hard";
  if (winRate >= 0.08) return "superHard";
  return "megaHard";
}

export function scaleArt(art: PixelArt, scale: number): PixelArt {
  if (scale <= 1) return art;
  const rows: string[] = [];
  for (const r of art.rows) {
    const wide = [...r].map((ch) => ch.repeat(scale)).join("");
    for (let k = 0; k < scale; k++) rows.push(wide);
  }
  return { ...art, rows };
}

export function artToCells(art: PixelArt): { width: number; height: number; cells: number[]; palette: string[] } {
  const keys = art.palette.map((p) => p.split("=")[0]);
  const hex = art.palette.map((p) => p.split("=")[1]);
  const height = art.rows.length, width = Math.max(...art.rows.map((r) => r.length));
  const cells: number[] = [];
  for (const row of art.rows) for (const ch of row.padEnd(width, ".")) cells.push(ch === "." ? EMPTY : keys.indexOf(ch));
  if (cells.some((c) => c < EMPTY)) throw new Error(`unknown palette char in ${art.name}`);
  return { width, height, cells, palette: hex };
}

// 8방향으로 이어진 덩어리. 전염이 8방향이므로 덩어리마다 시작점이 하나는 있어야 한다.
function components(width: number, height: number, cells: number[]): number[][] {
  const seen = new Uint8Array(cells.length);
  const out: number[][] = [];
  for (let i = 0; i < cells.length; i++) {
    if (cells[i] === EMPTY || seen[i]) continue;
    const comp: number[] = [];
    const stack = [i];
    seen[i] = 1;
    while (stack.length) {
      const c = stack.pop()!;
      comp.push(c);
      const x = c % width, y = (c / width) | 0;
      for (const [dx, dy] of DIR8) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        const j = ny * width + nx;
        if (cells[j] !== EMPTY && !seen[j]) { seen[j] = 1; stack.push(j); }
      }
    }
    out.push(comp);
  }
  return out;
}

function pick<T>(arr: T[], rng: () => number): T {
  return arr[Math.floor(rng() * arr.length)];
}

type Measure = { solvable: boolean | null; win: number; peak: number; avg: number; nodes: number };

function replayStats(level: Level, actions: Action[], opt: Options) {
  const s = createState(level);
  let peak = 0, occ = 0, taps = 0;
  for (const a of actions) {
    if (a.type === "deploy") { occ += s.slots.filter(Boolean).length; taps++; }
    applyAction(level, s, a, opt);
    peak = Math.max(peak, s.slots.filter(Boolean).length);
  }
  return { cleared: s.status === "cleared", peak, avg: occ / Math.max(1, taps) };
}

function measure(level: Level, opt: Options, rng: () => number, trials: number, maxNodes: number, known?: Action[]): Measure {
  const r = solve(level, opt, maxNodes);
  const sol = r.solvable ? r.solution : known;
  if (!sol) return { solvable: r.solvable, win: 0, peak: 0, avg: 0, nodes: r.nodes };
  const st = replayStats(level, sol, opt);
  return { solvable: r.solvable ?? (st.cleared ? true : null), win: randomWinRate(level, opt, trials, rng), peak: st.peak, avg: st.avg, nodes: r.nodes };
}

export function generate(art: PixelArt, p: GenParams): GenReport {
  const rng = mulberry32(p.seed);
  const scaled = scaleArt(art, p.scale ?? 1);
  const { width, height, cells, palette } = artToCells(scaled);
  const slotCount = p.slotCount ?? 4;
  const laneCount = Math.max(1, p.lanes ?? 3);
  const opt = p.options ?? DEFAULT_OPTIONS;
  const maxNodes = p.maxSolverNodes ?? 50_000;
  const trials = p.trials ?? 300;

  // 1) 시작 발아 지점
  const comps = components(width, height, cells);
  const starts = new Set<number>(comps.map((c) => pick(c, rng)));
  const all = cells.map((c, i) => (c === EMPTY ? -1 : i)).filter((i) => i >= 0);
  while (starts.size < Math.max(p.starts, comps.length)) starts.add(pick(all, rng));

  // 2) 구성적 순서: 슬롯이 빈 안정 상태마다 "지금 퍼질 수 있는 색" 물방울을 하나 넣어 보고 기록.
  //    물방울을 혼자 무한한 양으로 퍼뜨렸을 때 닿는 칸 수(max) 이하로만 양을 정하므로 항상 다 쓰인다.
  const base: Level = { id: `${art.name}-${p.seed}`, width, height, palette, cells, starts: [...starts], lanes: [], slotCount };
  const s = createState({ ...base, lanes: [[{ color: 0, amount: 0 }]] });
  s.lanes = [[]];
  const order: Drop[] = [];
  while (s.remaining > 0) {
    const colors = [...new Set(Array.from(s.sproutCount).map((n, c) => (n > 0 ? c : -1)).filter((c) => c >= 0))];
    if (!colors.length) throw new Error("dead end during construction"); // 덩어리별 시작점이 있으면 일어나지 않음
    const color = pick(colors, rng);
    const probe = cloneState(s);
    probe.lanes = [[{ color, amount: Number.MAX_SAFE_INTEGER }]];
    deploy(base, probe, 0);
    const before = probe.remaining;
    runUntilStable(base, probe);
    const max = before - probe.remaining;
    const want = p.dropMin + Math.floor(rng() * (p.dropMax - p.dropMin + 1));
    const amount = Math.min(max, want);
    s.lanes = [[{ color, amount }]];
    s.status = "playing";
    deploy(base, s, 0);
    runUntilStable(base, s);
    order.push({ color, amount });
  }

  // 3) 줄에 나눠 담기: 각 줄은 원래 순서의 부분열. 원래 순서대로 꺼내고 매번 안정될 때까지 기다리면 클리어.
  const lanes: Drop[][] = Array.from({ length: laneCount }, () => []);
  const known: Action[] = [];
  const level0: Level = { ...base, lanes };
  {
    const sim = createState({ ...base, lanes: [order.map((d) => ({ ...d }))] });
    order.forEach((d, k) => {
      const lane = k < laneCount ? k : Math.floor(rng() * laneCount); // 줄마다 최소 하나
      lanes[lane].push(d);
      known.push({ type: "deploy", lane });
      deploy(base, sim, 0);
      while (sim.status === "playing" && sim.slots.some((x) => x && sim.sproutCount[x.color] > 0)) {
        applyAction(base, sim, { type: "tick" }, opt);
        if (opt.realtime) known.push({ type: "tick" });
      }
    });
  }

  let level: Level = level0;
  let m = measure(level, opt, rng, 60, maxNodes, known);
  if (!m.solvable) throw new Error("constructed level not solvable (bug)");

  // 4) 난이도: 물방울을 줄 안에서 앞당기거나 다른 줄로 옮긴다. 솔버가 클리어 가능을 확인할 때만 받아들이고,
  //    슬롯 압박(최대 점유, 평균 점유)과 무작위 실패율이 나빠지지 않는 쪽으로만 움직인다.
  const targetPeak = p.targetPeak ?? slotCount - 1;
  const targetWin = p.targetWinRate ?? 0.3;
  const objective = (x: Measure) => (1 - x.win) * 100 + x.peak * 10 + x.avg;
  let applied = 0;
  for (let tries = 0; tries < p.displacements && !(m.peak >= targetPeak && m.win <= targetWin); tries++) {
    const ls = level.lanes.map((l) => l.slice());
    const from = Math.floor(rng() * ls.length);
    if (!ls[from].length) continue;
    const idx = Math.floor(rng() * ls[from].length);
    const [d] = ls[from].splice(idx, 1);
    const toLane = laneCount > 1 && rng() < 0.5 ? Math.floor(rng() * laneCount) : from;
    const pos = Math.floor(rng() * ((toLane === from ? idx : ls[toLane].length) + 1));
    ls[toLane].splice(pos, 0, d);
    if (ls.some((l) => !l.length)) continue; // 빈 줄은 만들지 않는다
    const cand: Level = { ...level, lanes: ls };
    const cm = measure(cand, opt, rng, 60, maxNodes);
    if (cm.solvable !== true || objective(cm) < objective(m)) continue;
    level = cand; m = cm; applied++;
  }

  m = measure(level, opt, rng, trials, maxNodes, applied ? undefined : known);
  const colors = new Set(cells.filter((c) => c !== EMPTY)).size;
  const drops = level.lanes.reduce((n, l) => n + l.length, 0);
  const score = Math.round(Math.min(100,
    (1 - m.win) * 50 + (m.peak / slotCount) * 25 + Math.min(15, colors * 3) + Math.min(10, drops / 4)));
  return {
    level, colors, cells: all.length, drops, displacementsApplied: applied,
    peakSlots: m.peak, avgSlots: Math.round(m.avg * 100) / 100, randomWinRate: m.win, solverNodes: m.nodes, score,
    difficulty: difficultyOf(m.win),
  };
}

// 수순을 재생해 클리어되는지 확인 (테스트용)
export function replay(level: Level, actions: Action[], opt: Options = DEFAULT_OPTIONS): boolean {
  const s = createState(level);
  for (const a of actions) applyAction(level, s, a, opt);
  return s.status === "cleared";
}
