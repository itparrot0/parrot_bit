// 깊이 우선 탐색 솔버 + 실패 상태 메모이제이션.
// 선택지: 줄마다 "맨 앞 넣기" + "기다리기(틱)". 탐색 순서만 휴리스틱으로 정하고 규칙은 engine.ts 그대로.

import {
  type Action, type Level, type Options, type State, DEFAULT_OPTIONS,
  applyAction, cloneState, createState, legalActions, stateKey,
} from "./engine.ts";

export type SolveResult = {
  solvable: boolean | null; // null = 노드 한도 초과로 판정 불가
  solution: Action[];
  nodes: number;
};

// 지금 바로 퍼질 수 있는 물방울 넣기 → 기다리기 → 못 쓰는 물방울 넣기 순으로 시도하면 해를 빨리 찾는다
function ordered(s: State, opt: Options): Action[] {
  const as = legalActions(s, opt);
  const rank = (a: Action) => {
    if (a.type === "tick") return 1;
    const d = s.lanes[a.lane][0];
    return s.sproutCount[d.color] > 0 ? 0 : 2;
  };
  return as.map((a, i) => ({ a, r: rank(a) * 100 + i })).sort((x, y) => x.r - y.r).map((x) => x.a);
}

// 임의의 상태에서 출발하는 솔버. peakLimit를 주면 활성 슬롯 점유가 그 값을 넘는 수는 두지 않는다.
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
    for (const a of ordered(s, opt)) {
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

export function solve(level: Level, opt: Options = DEFAULT_OPTIONS, maxNodes = 200_000): SolveResult {
  return solveFrom(level, createState(level), opt, maxNodes);
}

export type PlayStats = { cleared: boolean; peakSlots: number; ticks: number };

// 무작위 플레이어(사람 흉내): 지금 퍼질 수 있는 물방울 넣기 3, 기다리기 2, 못 쓰는 물방울 넣기 1의 비율로 고른다.
// 완전 무작위는 줄이 많을수록 지나치게 못 두어 난이도 지표가 왜곡된다.
export function playout(level: Level, opt: Options, rng: () => number): PlayStats {
  const s = createState(level);
  let peak = 0;
  while (s.status === "playing") {
    const as = legalActions(s, opt);
    const w = as.map((a) => (a.type === "tick" ? 2 : s.sproutCount[s.lanes[a.lane][0].color] > 0 ? 3 : 1));
    let r = rng() * w.reduce((x, y) => x + y, 0);
    let k = 0;
    while (k < as.length - 1 && (r -= w[k]) >= 0) k++;
    applyAction(level, s, as[k], opt);
    peak = Math.max(peak, s.slots.filter(Boolean).length);
  }
  return { cleared: s.status === "cleared", peakSlots: peak, ticks: s.tick };
}

export function randomWinRate(level: Level, opt: Options, trials: number, rng: () => number): number {
  let wins = 0;
  for (let t = 0; t < trials; t++) if (playout(level, opt, rng).cleared) wins++;
  return wins / trials;
}
