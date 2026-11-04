// 게임 한 판의 진행: core 엔진 호출, 고정 간격 틱 타이머, 되돌리기 스택, 일시정지.
// 규칙은 전부 @bloom-wave/core 가 정한다. 여기서는 "언제 tick/deploy 를 부르는가"만 다룬다.
import {
  type Drop, type Level, type Options, type State, type TickEvent,
  cloneState, createState, deploy, isActive, legalActions, levelOptions, tick,
} from "@bloom-wave/core/engine";
import { solveFrom, type SolveResult } from "@bloom-wave/core/solver";

export const TICK_MS = { normal: 150, slow: 250 } as const;
export const UNDO_LIMIT = 50;

export type TapResult = { ok: true; slot: number; drop: Drop } | { ok: false; reason: "full" | "wait" | "over" | "empty" };

type Snapshot = { state: State; peak: number; ticks: number };

export type ControllerEvents = {
  tick?: (ev: TickEvent, c: GameController) => void;
  deploy?: (slot: number, drop: Drop, c: GameController) => void;
  status?: (status: State["status"], c: GameController) => void;
  reset?: (c: GameController) => void; // 재시작·되돌리기로 상태가 통째로 바뀜
  idle?: (c: GameController) => void; // 웨이브가 멈춤 (이제 넣어야 함)
};

export class GameController {
  readonly level: Level;
  readonly options: Options;
  state: State;
  tickMs: number;
  paused = false;
  /** true면 타이머로 틱을 돌리지 않는다 (테스트용 ?manualTick=1). step()으로만 진행 */
  manual: boolean;
  /** 이번 판 동안 활성 슬롯이 동시에 찬 최대 칸 수 (별점) */
  peak = 0;
  ticks = 0;
  private acc = 0;
  private undoStack: Snapshot[] = [];
  private wasActive = false;
  private on: ControllerEvents = {};

  constructor(level: Level, opts: { tickMs?: number; manual?: boolean } = {}) {
    this.level = level;
    this.options = levelOptions(level);
    this.tickMs = opts.tickMs ?? TICK_MS.normal;
    this.manual = opts.manual ?? false;
    this.state = createState(level);
  }

  listen(on: ControllerEvents) { this.on = on; }

  get status() { return this.state.status; }
  get active() { return isActive(this.state); }
  get front(): Drop | undefined { return this.state.queue[0]; }
  get occupied() { return this.state.slots.filter(Boolean).length; }
  get canUndo() { return this.undoStack.length > 0; }

  /** 맨 앞 물방울을 지금 탭할 수 있나 (판단은 core 의 legalActions 로만) */
  canTapFront(): boolean {
    return legalActions(this.state, this.options).some((a) => a.type === "deploy" && a.index === 0);
  }

  /** 맨 앞 물방울과 같은 색 발아 칸이 있나. 없으면 "대기" 물방울 */
  frontUsable(): boolean {
    const f = this.front;
    return !!f && this.state.sproutCount[f.color] > 0;
  }

  tapFront(): TapResult {
    const s = this.state;
    if (s.status !== "playing") return { ok: false, reason: "over" };
    if (!s.queue.length) return { ok: false, reason: "empty" };
    if (!this.canTapFront()) return { ok: false, reason: s.slots.includes(null) ? "wait" : "full" };
    this.undoStack.push({ state: cloneState(s), peak: this.peak, ticks: this.ticks });
    if (this.undoStack.length > UNDO_LIMIT) this.undoStack.shift();
    const drop = { ...s.queue[0] };
    const slot = deploy(this.level, s, 0);
    this.peak = Math.max(this.peak, this.occupied);
    this.acc = 0; // 탭한 물방울은 다음 틱부터 함께 퍼진다
    this.on.deploy?.(slot, drop, this);
    this.afterChange();
    return { ok: true, slot, drop };
  }

  /** 틱 하나 진행 (웨이브가 없으면 아무것도 안 함) */
  step(): TickEvent | null {
    if (this.state.status !== "playing" || !isActive(this.state)) return null;
    const ev = tick(this.level, this.state);
    this.ticks++;
    this.on.tick?.(ev, this);
    this.afterChange();
    return ev;
  }

  /** 프레임마다 호출. 누적 시간으로 고정 간격 틱 */
  update(dtMs: number) {
    if (this.paused || this.manual || this.state.status !== "playing") return;
    if (!isActive(this.state)) { this.acc = 0; return; }
    this.acc += dtMs;
    let guard = 0;
    while (this.acc >= this.tickMs && guard++ < 4) {
      this.acc -= this.tickMs;
      if (!this.step()) { this.acc = 0; break; }
    }
  }

  undo(): boolean {
    const snap = this.undoStack.pop();
    if (!snap) return false;
    this.state = snap.state;
    this.peak = snap.peak;
    this.ticks = snap.ticks;
    this.acc = 0;
    this.paused = true; // 되돌리면 일시정지 상태로 시작
    this.wasActive = isActive(this.state);
    this.on.reset?.(this);
    this.on.status?.(this.state.status, this);
    return true;
  }

  restart() {
    this.state = createState(this.level);
    this.undoStack = [];
    this.peak = 0;
    this.ticks = 0;
    this.acc = 0;
    this.paused = false;
    this.wasActive = false;
    this.on.reset?.(this);
    this.on.status?.(this.state.status, this);
  }

  pause() { this.paused = true; }
  resume() { this.paused = false; this.acc = 0; }

  /** 힌트: 지금 상태에서 솔버가 찾은 다음 수 */
  hint(maxNodes = 30_000): { action: "tap" | "wait" | null; result: SolveResult } {
    const r = solveFrom(this.level, this.state, this.options, maxNodes);
    const a = r.solution[0];
    return { action: a ? (a.type === "deploy" ? "tap" : "wait") : null, result: r };
  }

  /** 별점: ★1 클리어 / ★2 슬롯 최대 3칸 이하 / ★3 레벨 최적값 이하 (01 기획서 4.5) */
  stars(): number {
    if (this.state.status !== "cleared") return 0;
    const best = this.level.meta?.star3Peak ?? 1;
    let n = 1;
    if (this.peak <= 3) n++;
    if (this.peak <= 3 && this.peak <= best) n++;
    return n;
  }

  private afterChange() {
    const active = isActive(this.state);
    if (this.wasActive && !active && this.state.status === "playing") this.on.idle?.(this);
    this.wasActive = active;
    if (this.state.status !== "playing") this.on.status?.(this.state.status, this);
  }
}
