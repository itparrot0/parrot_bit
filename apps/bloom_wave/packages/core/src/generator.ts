// 레벨 생성기: 픽셀 아트 -> 시작 발아 지점 -> 물방울 대기열.
// 핵심 아이디어: 대기열을 무작위로 만든 뒤 풀리는지 확인하는 게 아니라,
// 실제로 한 판을 "두어 보면서" 쓰인 물방울을 기록해 대기열을 만든다(구성적 생성).
// 그래서 출발점에서 항상 클리어 가능하고, 이후 순서를 흔들 때마다 솔버로 다시 검증한다.

import {
  EMPTY, DIR8, type Drop, type Level, type Options, DEFAULT_OPTIONS,
  applyAction, cloneState, createState, deploy, legalActions, runUntilStable,
} from "./engine.ts";
import { randomWinRate, solve } from "./solver.ts";

export type PixelArt = { name: string; palette: string[]; rows: string[] }; // rows: 팔레트 문자 또는 '.'

export type GenParams = {
  seed: number;
  starts: number; // 시작 발아 지점 수 (8방향으로 이어진 덩어리마다 최소 1개는 자동 보장)
  dropMin: number; // 물방울 하나의 최소 양
  dropMax: number; // 물방울 하나의 최대 양
  displacements: number; // 대기열 순서를 흔드는 시도 횟수
  targetPeak?: number; // 목표: 클리어 수순 중 활성 슬롯이 동시에 몇 칸까지 차는가 (기본 slotCount-1)
  targetWinRate?: number; // 선택지가 있는 변형 규칙에서 무작위 클리어율 목표 (기본 0.3)
  options?: Options;
  slotCount?: number;
  maxSolverNodes?: number;
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

export function artToCells(art: PixelArt): { width: number; height: number; cells: number[]; palette: string[] } {
  const keys = art.palette.map((p) => p.split("=")[0]);
  const hex = art.palette.map((p) => p.split("=")[1]);
  const height = art.rows.length, width = art.rows[0].length;
  const cells: number[] = [];
  for (const row of art.rows) for (const ch of row) cells.push(ch === "." ? EMPTY : keys.indexOf(ch));
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

// 확정 규칙(선택지 없음)에서는 수순이 하나뿐이므로 그대로 시뮬레이션해 지표를 잰다.
// 선택지가 있는 변형 규칙에서는 무작위 플레이 + 솔버로 잰다.
function measure(level: Level, opt: Options, rng: () => number, trials: number, maxNodes: number) {
  const s = createState(level);
  let peak = 0, occ = 0, taps = 0;
  const strict = opt.queuePick === 1 && !opt.realtime;
  if (strict) {
    while (s.status === "playing") {
      occ += s.slots.filter(Boolean).length; taps++;
      applyAction(level, s, legalActions(s, opt)[0], opt);
      peak = Math.max(peak, s.slots.filter(Boolean).length);
    }
    const ok = s.status === "cleared";
    return { solvable: ok as boolean | null, win: ok ? 1 : 0, peak, avg: occ / Math.max(1, taps), nodes: taps };
  }
  const r = solve(level, opt, maxNodes);
  // 지표용 수순: 솔버 해법을 재생
  if (r.solvable) {
    for (const a of r.solution) {
      if (a.type === "deploy") { occ += s.slots.filter(Boolean).length; taps++; }
      applyAction(level, s, a, opt);
      peak = Math.max(peak, s.slots.filter(Boolean).length);
    }
  }
  return { solvable: r.solvable, win: randomWinRate(level, opt, trials, rng), peak, avg: occ / Math.max(1, taps), nodes: r.nodes };
}

export function generate(art: PixelArt, p: GenParams): GenReport {
  const rng = mulberry32(p.seed);
  const { width, height, cells, palette } = artToCells(art);
  const slotCount = p.slotCount ?? 4;
  const opt = p.options ?? DEFAULT_OPTIONS;
  const maxNodes = p.maxSolverNodes ?? 50_000;
  const strict = opt.queuePick === 1 && !opt.realtime;

  // 1) 시작 발아 지점
  const comps = components(width, height, cells);
  const starts = new Set<number>(comps.map((c) => pick(c, rng)));
  const all = cells.map((c, i) => (c === EMPTY ? -1 : i)).filter((i) => i >= 0);
  while (starts.size < Math.max(p.starts, comps.length)) starts.add(pick(all, rng));

  // 2) 구성적 대기열: 슬롯이 빈 안정 상태마다 "지금 퍼질 수 있는 색" 물방울을 하나 넣어 보고 기록.
  //    물방울을 혼자 무한한 양으로 퍼뜨렸을 때 닿는 칸 수(max) 이하로만 양을 정하므로 항상 다 쓰인다.
  const base: Level = { id: `${art.name}-${p.seed}`, width, height, palette, cells, starts: [...starts], queue: [], slotCount };
  const s = createState({ ...base, queue: [{ color: 0, amount: 0 }] });
  s.queue = [];
  const queue: Drop[] = [];
  while (s.remaining > 0) {
    const colors = [...new Set(Array.from(s.sproutCount).map((n, c) => (n > 0 ? c : -1)).filter((c) => c >= 0))];
    if (!colors.length) throw new Error("dead end during construction"); // 덩어리별 시작점이 있으면 일어나지 않음
    const color = pick(colors, rng);
    const probe = cloneState(s);
    probe.queue = [{ color, amount: Number.MAX_SAFE_INTEGER }];
    deploy(base, probe);
    const before = probe.remaining;
    runUntilStable(base, probe);
    const max = before - probe.remaining;
    const want = p.dropMin + Math.floor(rng() * (p.dropMax - p.dropMin + 1));
    const amount = Math.min(max, want);
    s.queue = [{ color, amount }];
    s.status = "playing";
    deploy(base, s);
    runUntilStable(base, s);
    queue.push({ color, amount });
  }

  let level: Level = { ...base, queue };
  let m = measure(level, opt, rng, 60, maxNodes);
  if (!m.solvable) throw new Error("constructed level not solvable (bug)");

  // 3) 난이도: 물방울 하나를 앞으로 당겨 "지금은 못 쓰는" 물방울이 슬롯을 차지하게 만든다.
  //    클리어 가능(확정 규칙: 시뮬레이션 결과 클리어, 변형 규칙: 솔버 확인)할 때만 받아들이고,
  //    슬롯 압박(최대 점유, 평균 점유)과 무작위 실패율이 나빠지지 않는 쪽으로만 움직인다.
  const targetPeak = p.targetPeak ?? slotCount - 1;
  const targetWin = p.targetWinRate ?? (strict ? 1 : 0.3);
  const objective = (x: typeof m) => (1 - x.win) * 100 + x.peak * 10 + x.avg;
  let applied = 0;
  for (let tries = 0; tries < p.displacements && !(m.peak >= targetPeak && m.win <= targetWin); tries++) {
    const q = level.queue.slice();
    const from = 1 + Math.floor(rng() * (q.length - 1));
    const to = Math.floor(rng() * from);
    const [d] = q.splice(from, 1);
    q.splice(to, 0, d);
    const cand: Level = { ...level, queue: q };
    const cm = measure(cand, opt, rng, 60, maxNodes);
    if (cm.solvable !== true || objective(cm) < objective(m)) continue;
    level = cand; m = cm; applied++;
  }

  if (!strict) m = measure(level, opt, rng, 300, maxNodes);
  const colors = new Set(cells.filter((c) => c !== EMPTY)).size;
  const score = Math.round(Math.min(100,
    (1 - m.win) * 50 + (m.peak / slotCount) * 25 + Math.min(15, colors * 3) + Math.min(10, level.queue.length / 4)));
  return {
    level, colors, cells: all.length, drops: level.queue.length, displacementsApplied: applied,
    peakSlots: m.peak, avgSlots: Math.round(m.avg * 100) / 100, randomWinRate: m.win, solverNodes: m.nodes, score,
  };
}

// 수순을 재생해 클리어되는지 확인 (테스트용)
export function replay(level: Level, actions: import("./engine.ts").Action[], opt: Options = DEFAULT_OPTIONS): boolean {
  const s = createState(level);
  for (const a of actions) applyAction(level, s, a, opt);
  return s.status === "cleared";
}
