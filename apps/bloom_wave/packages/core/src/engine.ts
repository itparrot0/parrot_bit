// Bloom Wave 규칙 엔진 (참조 구현, 규칙 v2 — 2026-10-28 확정 규칙)
// 렌더링/입력과 무관한 순수 로직이며, 앱과 레벨 생성기가 이 모듈을 공유한다.
//
// 확정 규칙 요약 (01_게임기획서.md 4장)
//  - 플레이어는 대기열 맨 앞 물방울만 탭할 수 있고, 탭한 물방울은 빈 활성 슬롯으로 이동한다.
//  - 웨이브가 진행 중일 때도 탭할 수 있다(2026-10-28 결정). 틱 사이 언제 넣느냐가 플레이어의 선택이다.
//  - 활성 슬롯의 물방울은 자동으로 동작한다. 한 틱에 "한 링"씩 퍼진다.
//    링 = 그 물방울과 같은 색인 발아 칸 전체 (발아한 순서대로). 남은 양만큼만 개화.
//  - 개화한 칸은 8방향(남동>남>남서>서>북서>북>북동>동)의 씨앗을 색과 상관없이 발아시킨다.
//  - 물방울은 발아 칸에만 소모된다. 양이 남으면 슬롯에 남아 다음 틱에 다음 링을 다시 계산한다.
//  - 슬롯의 어떤 물방울도 더 퍼질 수 없으면 "안정" 상태. 이때 슬롯 4칸이 모두 차 있으면 실패.

export const EMPTY = -1; // 투명 픽셀 (칸 없음)
export const SEED = 0; // 씨앗 (-)
export const SPROUT = 1; // 발아 (*)
export const BLOOM = 2; // 개화 (@)

export type Drop = { color: number; amount: number };

export type Level = {
  id: string;
  width: number;
  height: number;
  palette: string[]; // 색상 인덱스 -> 표시용 HEX
  cells: number[]; // 칸별 색상 인덱스, 빈 칸은 EMPTY
  starts: number[]; // 시작 발아 칸 인덱스 (이 순서가 첫 발아 순서)
  queue: Drop[]; // 대기열 (앞에서부터)
  slotCount: number; // 활성 슬롯 수 (기본 4: 좌 2 + 우 2, 인덱스 0,1 = 왼쪽 위/아래, 2,3 = 오른쪽 위/아래)
  options?: Partial<Options>; // 생략하면 확정 규칙 (DEFAULT_OPTIONS)
  meta?: LevelMeta; // 생성기가 기록한 난이도 지표 (규칙에는 영향 없음)
};

export type LevelMeta = {
  score: number;
  peakSlots: number;
  avgSlots: number;
  randomWinRate: number;
  solverNodes: number;
  star3Peak?: number; // ★3 기준: 이 값 이하의 슬롯 최대 점유로 클리어
  art?: string;
  name?: { ko: string; en: string };
};

// 규칙 옵션 (00_규칙_확인_질문.md 참고). 기본값이 확정 규칙.
export type Options = {
  queuePick: number; // 대기열 앞에서 몇 개까지 탭할 수 있나 (확정: 1)
  realtime: boolean; // 웨이브가 진행 중일 때도 탭할 수 있나 (확정: true)
};
export const DEFAULT_OPTIONS: Options = { queuePick: 1, realtime: true };
// 비교용: 웨이브가 멈춘 뒤에만 탭 (선택지가 없어 결과가 대기열 순서로 정해짐)
export const TURN_BASED: Options = { queuePick: 1, realtime: false };

export function levelOptions(level: Level): Options {
  return { ...DEFAULT_OPTIONS, ...(level.options ?? {}) };
}

export type Status = "playing" | "cleared" | "failed";

export type State = {
  cell: Int8Array; // 칸별 상태 (EMPTY/SEED/SPROUT/BLOOM)
  seq: Int32Array; // 발아한 순서 (링 안의 개화 순서를 정함)
  bornTick: Int32Array; // 발아한 틱. 이번 틱에 막 발아한 칸은 다음 틱 링부터 포함
  nextSeq: number;
  tick: number;
  sproutCount: Int32Array; // 색상별 발아 칸 수
  remaining: number; // 아직 개화하지 않은 칸 수
  queue: Drop[]; // 남은 대기열
  slots: (Drop | null)[];
  status: Status;
};

export type Action = { type: "deploy"; index: number } | { type: "tick" };

// 한 틱의 애니메이션 프레임: 슬롯별로 이번 링에서 개화한 칸들, 그리고 새로 발아한 칸들
export type TickEvent = {
  tick: number;
  blooms: { slot: number; color: number; cells: number[] }[];
  sprouted: number[];
  emptied: number[]; // 이번 틱에 다 써서 비워진 슬롯
};

// "8방향 사이클": 남동에서 시작해 시계 방향으로 한 바퀴
export const DIR8: [number, number][] = [
  [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1], [1, 0],
];

export function createState(level: Level): State {
  const n = level.width * level.height;
  const cell = new Int8Array(n);
  const seq = new Int32Array(n).fill(-1);
  const bornTick = new Int32Array(n).fill(-1);
  const sproutCount = new Int32Array(level.palette.length);
  let remaining = 0;
  for (let i = 0; i < n; i++) {
    if (level.cells[i] === EMPTY) cell[i] = EMPTY;
    else { cell[i] = SEED; remaining++; }
  }
  let nextSeq = 0;
  for (const s of level.starts) {
    if (cell[s] === SEED) { cell[s] = SPROUT; seq[s] = nextSeq++; sproutCount[level.cells[s]]++; }
  }
  const s: State = {
    cell, seq, bornTick, nextSeq, tick: 0, sproutCount, remaining,
    queue: level.queue.map((d) => ({ ...d })),
    slots: new Array(level.slotCount).fill(null),
    status: "playing",
  };
  judge(level, s);
  return s;
}

export function cloneState(s: State): State {
  return {
    cell: s.cell.slice(), seq: s.seq.slice(), bornTick: s.bornTick.slice(),
    nextSeq: s.nextSeq, tick: s.tick, sproutCount: s.sproutCount.slice(), remaining: s.remaining,
    queue: s.queue.map((d) => ({ ...d })),
    slots: s.slots.map((d) => (d ? { ...d } : null)),
    status: s.status,
  };
}

// 슬롯 물방울 중 하나라도 퍼질 칸이 있으면 웨이브 진행 중
export function isActive(s: State): boolean {
  return s.slots.some((d) => d && d.amount > 0 && s.sproutCount[d.color] > 0);
}

function judge(level: Level, s: State) {
  if (s.remaining === 0) { s.status = "cleared"; return; }
  if (isActive(s)) { s.status = "playing"; return; }
  const hasEmpty = s.slots.includes(null);
  // 안정 상태에서 슬롯이 꽉 찼거나, 더 넣을 물방울이 없으면 실패
  s.status = !hasEmpty || s.queue.length === 0 ? "failed" : "playing";
}

export function legalActions(s: State, opt: Options = DEFAULT_OPTIONS): Action[] {
  if (s.status !== "playing") return [];
  const out: Action[] = [];
  const active = isActive(s);
  if (s.slots.includes(null) && (!active || opt.realtime)) {
    for (let k = 0; k < Math.min(opt.queuePick, s.queue.length); k++) out.push({ type: "deploy", index: k });
  }
  if (active) out.push({ type: "tick" });
  return out;
}

// 대기열 index 번째 물방울을 첫 빈 슬롯으로 옮긴다 (쓸 수 있는지와 무관 — 확정 규칙 Q6)
export function deploy(level: Level, s: State, index = 0): number {
  const slot = s.slots.indexOf(null);
  if (slot < 0) throw new Error("no empty slot");
  if (index >= s.queue.length) throw new Error("no drop in queue");
  const [d] = s.queue.splice(index, 1);
  s.slots[slot] = d;
  judge(level, s);
  return slot;
}

// 한 틱: 슬롯 순서대로 각 물방울이 한 링씩 퍼진다
export function tick(level: Level, s: State): TickEvent {
  const { width: w, height: h, cells } = level;
  const t = s.tick;
  const ev: TickEvent = { tick: t, blooms: [], sprouted: [], emptied: [] };
  for (let si = 0; si < s.slots.length; si++) {
    const d = s.slots[si];
    if (!d || d.amount <= 0 || s.sproutCount[d.color] === 0) continue;
    // 링: 같은 색 발아 칸 중 이번 틱 이전에 발아한 칸, 발아 순서대로
    const ring: number[] = [];
    for (let i = 0; i < s.cell.length; i++) {
      if (s.cell[i] === SPROUT && cells[i] === d.color && s.bornTick[i] < t) ring.push(i);
    }
    ring.sort((a, b) => s.seq[a] - s.seq[b]);
    const bloomed = ring.slice(0, d.amount);
    for (const i of bloomed) {
      s.cell[i] = BLOOM;
      s.sproutCount[d.color]--;
      s.remaining--;
      const x = i % w, y = (i / w) | 0;
      for (const [dx, dy] of DIR8) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        const j = ny * w + nx;
        if (s.cell[j] === SEED) {
          s.cell[j] = SPROUT;
          s.seq[j] = s.nextSeq++;
          s.bornTick[j] = t;
          s.sproutCount[cells[j]]++;
          ev.sprouted.push(j);
        }
      }
    }
    d.amount -= bloomed.length;
    if (bloomed.length) ev.blooms.push({ slot: si, color: d.color, cells: bloomed });
    if (d.amount === 0) { s.slots[si] = null; ev.emptied.push(si); }
  }
  s.tick++;
  judge(level, s);
  return ev;
}

// 안정될 때까지 틱을 돌린다. 이번 틱에 막 발아한 칸은 다음 틱 링에 들어가므로 항상 진행이 있다.
export function runUntilStable(level: Level, s: State): TickEvent[] {
  const evs: TickEvent[] = [];
  while (s.status === "playing" && isActive(s)) evs.push(tick(level, s));
  return evs;
}

export function applyAction(level: Level, s: State, a: Action, opt: Options = DEFAULT_OPTIONS): TickEvent[] {
  if (s.status !== "playing") throw new Error("game is over");
  if (a.type === "tick") {
    if (!isActive(s)) throw new Error("nothing to tick");
    return [tick(level, s)];
  }
  if (isActive(s) && !opt.realtime) throw new Error("wait for the wave to finish");
  if (a.index >= opt.queuePick) throw new Error("only the front of the queue can be tapped");
  deploy(level, s, a.index);
  return opt.realtime ? [] : runUntilStable(level, s);
}

export function stateKey(s: State): string {
  // 발아 칸의 상대 순서와 "막 발아함" 여부가 이후 결과를 바꾸므로 키에 포함
  const sprouts: number[] = [];
  for (let i = 0; i < s.cell.length; i++) if (s.cell[i] === SPROUT) sprouts.push(i);
  sprouts.sort((a, b) => s.seq[a] - s.seq[b]);
  const sp = sprouts.map((i) => (s.bornTick[i] === s.tick - 1 ? `${i}'` : `${i}`)).join(",");
  const cells = String.fromCharCode(...Array.from(s.cell, (c) => c + 66));
  const slots = s.slots.map((d) => (d ? `${d.color}:${d.amount}` : "_")).join(",");
  return `${cells}|${sp}|${s.queue.length}|${slots}`;
}

// 디버그용 텍스트 렌더: 색상은 a,b,c..., 상태는 - * @
export function render(level: Level, s: State): string {
  const rows: string[] = [];
  for (let y = 0; y < level.height; y++) {
    let row = "";
    for (let x = 0; x < level.width; x++) {
      const i = y * level.width + x;
      const c = s.cell[i];
      row += c === EMPTY ? " . " : String.fromCharCode(97 + level.cells[i]) + "-*@"[c] + " ";
    }
    rows.push(row);
  }
  const fmt = (d: Drop | null) => (d ? `${String.fromCharCode(97 + d.color)}${d.amount}` : "__");
  const sl = s.slots.map(fmt);
  rows.push(`slots[L ${sl.slice(0, 2).join(" ")} | R ${sl.slice(2).join(" ")}]  queue: ${s.queue.map(fmt).join(" ")}  status=${s.status}`);
  return rows.join("\n");
}
