// 깊이 우선 탐색 솔버 + 실패 상태 메모이제이션.
// 확정 규칙(맨 앞만 탭, 웨이브 중 탭 불가)에서는 둘 수 있는 수가 항상 하나라 결과가 정해져 있다.
// 그래서 솔버는 "선택지가 있는 변형 규칙"(queuePick > 1 또는 realtime)에서 의미가 있고,
// 확정 규칙에서는 한 번의 시뮬레이션과 같다.

import {
  type Action, type Level, type Options, type State, DEFAULT_OPTIONS,
  applyAction, cloneState, createState, legalActions, stateKey,
} from "./engine.ts";

export type SolveResult = {
  solvable: boolean | null; // null = 노드 한도 초과로 판정 불가
  solution: Action[];
  nodes: number;
};

export function solve(level: Level, opt: Options = DEFAULT_OPTIONS, maxNodes = 200_000): SolveResult {
  const dead = new Set<string>();
  const path: Action[] = [];
  let nodes = 0;
  let aborted = false;

  function dfs(s: State): boolean {
    if (s.status === "cleared") return true;
    if (s.status === "failed") return false;
    if (++nodes > maxNodes) { aborted = true; return false; }
    const key = stateKey(s);
    if (dead.has(key)) return false;
    for (const a of legalActions(s, opt)) {
      const c = cloneState(s);
      applyAction(level, c, a, opt);
      path.push(a);
      if (dfs(c)) return true;
      path.pop();
      if (aborted) return false;
    }
    dead.add(key);
    return false;
  }

  const ok = dfs(createState(level));
  return { solvable: ok ? true : aborted ? null : false, solution: ok ? path.slice() : [], nodes };
}

export type PlayStats = { cleared: boolean; peakSlots: number; ticks: number };

// 정해진 수순(또는 무작위 선택)으로 끝까지 둔다
export function playout(level: Level, opt: Options, rng: () => number): PlayStats {
  const s = createState(level);
  let peak = 0;
  while (s.status === "playing") {
    const as = legalActions(s, opt);
    applyAction(level, s, as[Math.floor(rng() * as.length)], opt);
    peak = Math.max(peak, s.slots.filter(Boolean).length);
  }
  return { cleared: s.status === "cleared", peakSlots: peak, ticks: s.tick };
}

// 무작위로 선택하는 플레이어의 클리어율. 선택지가 없는 확정 규칙에서는 0 또는 1.
export function randomWinRate(level: Level, opt: Options, trials: number, rng: () => number): number {
  let wins = 0;
  for (let t = 0; t < trials; t++) if (playout(level, opt, rng).cleared) wins++;
  return wins / trials;
}

// ---- 앱/생성기 확장 (규칙은 engine.ts 그대로) ----

// 임의의 상태에서 출발하는 솔버. peakLimit를 주면 활성 슬롯 점유가 그 값을 넘는 수는 두지 않는다.
// 앱의 힌트와 ★3 기준값(슬롯 최대 점유 최소화) 계산에 쓴다.
export function solveFrom(
  level: Level, start: State, opt: Options = DEFAULT_OPTIONS, maxNodes = 200_000, peakLimit = Infinity,
): SolveResult {
  const dead = new Set<string>();
  const path: Action[] = [];
  let nodes = 0;
  let aborted = false;
  const occ = (s: State) => s.slots.reduce((n, d) => n + (d ? 1 : 0), 0);

  function dfs(s: State): boolean {
    if (s.status === "cleared") return true;
    if (s.status === "failed") return false;
    if (++nodes > maxNodes) { aborted = true; return false; }
    const key = stateKey(s);
    if (dead.has(key)) return false;
    for (const a of legalActions(s, opt)) {
      if (a.type === "deploy" && occ(s) + 1 > peakLimit) continue;
      const c = cloneState(s);
      applyAction(level, c, a, opt);
      path.push(a);
      if (dfs(c)) return true;
      path.pop();
      if (aborted) return false;
    }
    dead.add(key);
    return false;
  }

  const ok = dfs(cloneState(start));
  return { solvable: ok ? true : aborted ? null : false, solution: ok ? path.slice() : [], nodes };
}

// ★3 기준: 클리어 가능한 가장 작은 슬롯 최대 점유. 노드 한도 안에서 판정이 안 되면 null.
export function minPeakSlots(level: Level, opt: Options = DEFAULT_OPTIONS, maxNodes = 50_000): number | null {
  for (let k = 1; k <= level.slotCount; k++) {
    const r = solveFrom(level, createState(level), opt, maxNodes, k);
    if (r.solvable === true) return k;
    if (r.solvable === null) return null;
  }
  return null;
}
