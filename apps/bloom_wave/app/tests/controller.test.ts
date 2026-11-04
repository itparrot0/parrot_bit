import { describe, expect, it } from "vitest";
import { type Level, BLOOM } from "@bloom-wave/core/engine";
import { generate } from "@bloom-wave/core/generator";
import { solve } from "@bloom-wave/core/solver";
import { ARTS } from "@bloom-wave/core/arts";
import { GameController, TICK_MS, UNDO_LIMIT } from "../src/game/GameController";
import { SaveStore, memoryStore, migrate, SAVE_KEY } from "../src/save/save";
import pack from "../src/levels/pack-01.json";

// 1행 5칸: a a b a a, 시작 발아는 0번. lanes 는 줄들 (기본: 한 줄 + 빈 줄 둘)
const line = (queue: Level["lanes"][number], extra: Level["lanes"] = [[], []]): Level => ({
  id: "t", width: 5, height: 1, palette: ["#f00", "#00f"], cells: [0, 0, 1, 0, 0], starts: [0], lanes: [queue, ...extra], slotCount: 4,
});
const qlen = (c: GameController) => c.queueLeft;

function playSolution(level: Level) {
  const c = new GameController(level, { manual: true });
  const sol = solve(level, c.options);
  expect(sol.solvable).toBe(true);
  for (const a of sol.solution) {
    if (a.type === "deploy") {
      expect(c.tap(a.lane).ok).toBe(true);
      // 웨이브 후에만 탭하는 레벨: 엔진의 applyAction 은 안정될 때까지 진행하므로 똑같이 틱을 돌린다
      if (!c.options.realtime) while (c.step());
    } else expect(c.step()).not.toBeNull();
  }
  return c;
}

describe("GameController", () => {
  it("고정 간격 타이머: 300ms마다 한 틱, 일시정지 중에는 멈춤", () => {
    const c = new GameController(line([{ color: 0, amount: 2 }, { color: 1, amount: 1 }, { color: 0, amount: 2 }]));
    expect(TICK_MS.normal).toBe(300);
    const ticks: number[] = [];
    c.listen({ tick: (ev) => ticks.push(ev.tick) });
    c.tap(0);
    c.update(250);
    expect(ticks).toEqual([]);
    c.update(60);
    expect(ticks).toEqual([0]);
    c.pause();
    c.update(1000);
    expect(ticks).toEqual([0]);
    c.resume();
    c.update(300);
    expect(ticks).toEqual([0, 1]);
  });

  it("아무 줄이나 맨 앞을 탭, 빈 줄은 empty, 쓸 수 없는 물방울로 슬롯이 꽉 차면 실패", () => {
    const c = new GameController(line([{ color: 1, amount: 1 }, { color: 1, amount: 1 }], [[{ color: 1, amount: 1 }, { color: 1, amount: 1 }], [], [{ color: 0, amount: 4 }]]));
    expect(c.usable(0)).toBe(false); // b 발아 칸이 없음
    expect(c.usable(3)).toBe(true);
    expect(c.canTap(2)).toBe(false);
    expect(c.tap(2)).toEqual({ ok: false, reason: "empty" });
    const r = c.tap(1);
    expect(r).toMatchObject({ ok: true, slot: 0, lane: 1 });
    expect(c.front(1)).toEqual({ color: 1, amount: 1 });
    expect(c.tap(0).ok).toBe(true);
    expect(c.tap(0).ok).toBe(true);
    expect(c.tap(1).ok).toBe(true);
    expect(c.status).toBe("failed");
    expect(c.tap(3)).toEqual({ ok: false, reason: "over" });
  });

  it("deploy 이벤트에 줄 번호가 실린다", () => {
    const c = new GameController(line([{ color: 0, amount: 2 }], [[{ color: 0, amount: 1 }], []]), { manual: true });
    const got: number[][] = [];
    c.listen({ deploy: (slot, _d, lane) => got.push([slot, lane]) });
    c.tap(1);
    c.tap(0);
    expect(got).toEqual([[0, 1], [1, 0]]);
  });

  it("realtime=false 레벨은 웨이브 중 탭을 거절한다", () => {
    const lv: Level = { ...line([{ color: 0, amount: 2 }, { color: 1, amount: 1 }, { color: 0, amount: 2 }]), options: { realtime: false } };
    const c = new GameController(lv, { manual: true });
    expect(c.tap(0).ok).toBe(true);
    expect(c.active).toBe(true);
    expect(c.tap(0)).toEqual({ ok: false, reason: "wait" });
  });

  it("되돌리기: 마지막 탭 직전으로, 일시정지 상태로 돌아간다", () => {
    const c = new GameController(line([{ color: 0, amount: 2 }, { color: 1, amount: 1 }, { color: 0, amount: 2 }]), { manual: true });
    c.tap(0);
    c.step();
    c.step();
    const before = Array.from(c.state.cell);
    c.tap(0);
    c.step();
    expect(c.undo()).toBe(true);
    expect(Array.from(c.state.cell)).toEqual(before);
    expect(qlen(c)).toBe(2);
    expect(c.paused).toBe(true);
    expect(c.undo()).toBe(true);
    expect(qlen(c)).toBe(3);
    expect(c.undo()).toBe(false);
  });

  it(`되돌리기 스택은 최대 ${UNDO_LIMIT}개`, () => {
    const n = 60;
    const lv: Level = { id: "u", width: n, height: 1, palette: ["#f00"], cells: new Array(n).fill(0), starts: [0],
      lanes: [new Array(n).fill(0).map(() => ({ color: 0, amount: 1 })), [], []], slotCount: 4 };
    const c = new GameController(lv, { manual: true });
    let taps = 0;
    while (c.status === "playing") { if (c.tap(0).ok) taps++; else c.step(); }
    expect(taps).toBe(n);
    let undos = 0;
    while (c.undo()) undos++;
    expect(undos).toBe(UNDO_LIMIT);
  });

  it("솔버 해법대로 두면 클리어된다 (3줄 대기열, 별점 없음)", () => {
    for (const art of ARTS) {
      const r = generate(art, { seed: 2, starts: 1, dropMin: 1, dropMax: 4, displacements: 30, lanes: 3, trials: 20 });
      const c = playSolution(r.level);
      expect(c.status).toBe("cleared");
      expect(Array.from(c.state.cell).every((x) => x === BLOOM || x === -1)).toBe(true);
      expect("stars" in c).toBe(false);
    }
  });

  it("재시작하면 처음 상태", () => {
    const c = new GameController(line([{ color: 0, amount: 2 }, { color: 1, amount: 1 }, { color: 0, amount: 2 }]), { manual: true });
    c.tap(0); c.step();
    c.restart();
    expect(qlen(c)).toBe(3);
    expect(c.canUndo).toBe(false);
    expect(c.peak).toBe(0);
  });

  it("힌트는 클리어로 가는 다음 수를 알려 준다", () => {
    const r = generate(ARTS[1], { seed: 3, starts: 1, dropMin: 1, dropMax: 4, displacements: 60, lanes: 3, trials: 20 });
    const c = new GameController(r.level, { manual: true });
    let guard = 0;
    while (c.status === "playing" && guard++ < 2000) {
      const h = c.hint();
      expect(h.action).not.toBeNull();
      if (h.action === "tap") { expect(c.canTap(h.lane)).toBe(true); c.tap(h.lane); } else c.step();
    }
    expect(c.status).toBe("cleared");
  });
});

describe("SaveStore", () => {
  it("저장 → 불러오기 왕복: 완성 여부·해금·광고 제거 유지 (schema 2)", async () => {
    const kv = memoryStore();
    const a = new SaveStore(kv);
    await a.load();
    await a.recordClear("tulip", 1, 120);
    await a.recordClear("tulip", 1, 120);
    await a.setNoAds(true);
    await a.updateSettings({ tickSpeed: "slow", lang: "en" });
    const b = new SaveStore(kv);
    const d = await b.load();
    expect(d.schema).toBe(2);
    expect(d.cleared).toEqual({ tulip: true });
    expect("stars" in d).toBe(false);
    expect(d.unlocked).toBe(2);
    expect(d.noAds).toBe(true);
    expect(d.settings.tickSpeed).toBe("slow");
    expect(d.settings.lang).toBe("en");
  });

  it("schema 1(별점) 저장을 완성 여부로 옮긴다", async () => {
    const s = new SaveStore(memoryStore({ [SAVE_KEY]: JSON.stringify({ schema: 1, unlocked: 4, stars: { a: 3, b: 1, c: 0 } }) }));
    const d = await s.load();
    expect(d.schema).toBe(2);
    expect(d.cleared).toEqual({ a: true, b: true });
    expect(d.unlocked).toBe(4);
    expect(d.noAds).toBe(false);
  });

  it("깨진 저장은 기본값으로", async () => {
    const s = new SaveStore(memoryStore({ [SAVE_KEY]: "{not json" }));
    expect((await s.load()).unlocked).toBe(1);
    const m = migrate({ unlocked: -3, cleared: { a: true, b: "yes" }, noAds: "1", settings: { tickSpeed: "warp" } });
    expect(m.cleared).toEqual({ a: true });
    expect(m.noAds).toBe(false);
    expect(m.unlocked).toBe(1);
    expect(m.settings.tickSpeed).toBe("normal");
  });
});

describe("pack-01", () => {
  it("모든 레벨이 3줄 이상 대기열", () => {
    for (const lv of pack as unknown as Level[]) expect(lv.lanes.length).toBeGreaterThanOrEqual(3);
  });


  it("120 레벨, 모두 솔버 해법으로 클리어 (앞 10개)", () => {
    const levels = pack as unknown as Level[];
    expect(levels.length).toBe(120);
    for (const lv of levels.slice(0, 10)) expect(playSolution(lv).status).toBe("cleared");
  });
});
