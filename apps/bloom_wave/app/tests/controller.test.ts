import { describe, expect, it } from "vitest";
import { type Level, BLOOM } from "@bloom-wave/core/engine";
import { generate } from "@bloom-wave/core/generator";
import { solve } from "@bloom-wave/core/solver";
import { ARTS } from "@bloom-wave/core/arts";
import { GameController, UNDO_LIMIT } from "../src/game/GameController";
import { SaveStore, memoryStore, migrate, SAVE_KEY } from "../src/save/save";
import pack from "../src/levels/pack-01.json";

// 1행 5칸: a a b a a, 시작 발아는 0번
const line = (queue: Level["queue"]): Level => ({
  id: "t", width: 5, height: 1, palette: ["#f00", "#00f"], cells: [0, 0, 1, 0, 0], starts: [0], queue, slotCount: 4,
});

function playSolution(level: Level) {
  const c = new GameController(level, { manual: true });
  const sol = solve(level, c.options);
  expect(sol.solvable).toBe(true);
  for (const a of sol.solution) {
    if (a.type === "deploy") {
      expect(c.tapFront().ok).toBe(true);
      // 웨이브 후에만 탭하는 레벨: 엔진의 applyAction 은 안정될 때까지 진행하므로 똑같이 틱을 돌린다
      if (!c.options.realtime) while (c.step());
    } else expect(c.step()).not.toBeNull();
  }
  return c;
}

describe("GameController", () => {
  it("고정 간격 타이머: 150ms마다 한 틱, 일시정지 중에는 멈춤", () => {
    const c = new GameController(line([{ color: 0, amount: 2 }, { color: 1, amount: 1 }, { color: 0, amount: 2 }]));
    const ticks: number[] = [];
    c.listen({ tick: (ev) => ticks.push(ev.tick) });
    c.tapFront();
    c.update(100);
    expect(ticks).toEqual([]);
    c.update(60);
    expect(ticks).toEqual([0]);
    c.pause();
    c.update(1000);
    expect(ticks).toEqual([0]);
    c.resume();
    c.update(150);
    expect(ticks).toEqual([0, 1]);
  });

  it("웨이브 중에도 맨 앞 탭 가능 (확정 규칙), 슬롯이 꽉 차면 full", () => {
    const c = new GameController(line([{ color: 1, amount: 1 }, { color: 1, amount: 1 }, { color: 1, amount: 1 }, { color: 1, amount: 1 }, { color: 0, amount: 4 }]));
    expect(c.frontUsable()).toBe(false); // b 발아 칸이 없음 → "대기"
    for (let k = 0; k < 4; k++) expect(c.tapFront().ok).toBe(true);
    expect(c.status).toBe("failed");
    expect(c.tapFront()).toEqual({ ok: false, reason: "over" });
  });

  it("realtime=false 레벨은 웨이브 중 탭을 거절한다", () => {
    const lv: Level = { ...line([{ color: 0, amount: 2 }, { color: 1, amount: 1 }, { color: 0, amount: 2 }]), options: { realtime: false } };
    const c = new GameController(lv, { manual: true });
    expect(c.tapFront().ok).toBe(true);
    expect(c.active).toBe(true);
    expect(c.tapFront()).toEqual({ ok: false, reason: "wait" });
  });

  it("되돌리기: 마지막 탭 직전으로, 일시정지 상태로 돌아간다", () => {
    const c = new GameController(line([{ color: 0, amount: 2 }, { color: 1, amount: 1 }, { color: 0, amount: 2 }]), { manual: true });
    c.tapFront();
    c.step();
    c.step();
    const before = Array.from(c.state.cell);
    c.tapFront();
    c.step();
    expect(c.undo()).toBe(true);
    expect(Array.from(c.state.cell)).toEqual(before);
    expect(c.state.queue.length).toBe(2);
    expect(c.paused).toBe(true);
    expect(c.undo()).toBe(true);
    expect(c.state.queue.length).toBe(3);
    expect(c.undo()).toBe(false);
  });

  it(`되돌리기 스택은 최대 ${UNDO_LIMIT}개`, () => {
    const n = 60;
    const lv: Level = { id: "u", width: n, height: 1, palette: ["#f00"], cells: new Array(n).fill(0), starts: [0],
      queue: new Array(n).fill(0).map(() => ({ color: 0, amount: 1 })), slotCount: 4 };
    const c = new GameController(lv, { manual: true });
    let taps = 0;
    while (c.status === "playing") { if (c.tapFront().ok) taps++; else c.step(); }
    expect(taps).toBe(n);
    let undos = 0;
    while (c.undo()) undos++;
    expect(undos).toBe(UNDO_LIMIT);
  });

  it("솔버 해법대로 두면 클리어되고 별점이 나온다", () => {
    for (const art of ARTS) {
      const r = generate(art, { seed: 2, starts: 1, dropMin: 1, dropMax: 4, displacements: 30 });
      const c = playSolution(r.level);
      expect(c.status).toBe("cleared");
      expect(Array.from(c.state.cell).every((x) => x === BLOOM || x === -1)).toBe(true);
      expect(c.stars()).toBeGreaterThanOrEqual(1);
    }
  });

  it("재시작하면 처음 상태", () => {
    const c = new GameController(line([{ color: 0, amount: 2 }, { color: 1, amount: 1 }, { color: 0, amount: 2 }]), { manual: true });
    c.tapFront(); c.step();
    c.restart();
    expect(c.state.queue.length).toBe(3);
    expect(c.canUndo).toBe(false);
    expect(c.peak).toBe(0);
  });

  it("힌트는 클리어로 가는 다음 수를 알려 준다", () => {
    const r = generate(ARTS[1], { seed: 3, starts: 1, dropMin: 1, dropMax: 4, displacements: 60 });
    const c = new GameController(r.level, { manual: true });
    let guard = 0;
    while (c.status === "playing" && guard++ < 2000) {
      const h = c.hint();
      expect(h.action).not.toBeNull();
      if (h.action === "tap") c.tapFront(); else c.step();
    }
    expect(c.status).toBe("cleared");
  });
});

describe("SaveStore", () => {
  it("저장 → 불러오기 왕복, 최고 별점과 해금 유지", async () => {
    const kv = memoryStore();
    const a = new SaveStore(kv);
    await a.load();
    await a.recordClear("tulip", 1, 2, 120);
    await a.recordClear("tulip", 1, 1, 120);
    await a.updateSettings({ tickSpeed: "slow", lang: "en" });
    const b = new SaveStore(kv);
    const d = await b.load();
    expect(d.schema).toBe(1);
    expect(d.stars.tulip).toBe(2);
    expect(d.unlocked).toBe(2);
    expect(d.settings.tickSpeed).toBe("slow");
    expect(d.settings.lang).toBe("en");
  });

  it("깨진 저장은 기본값으로", async () => {
    const s = new SaveStore(memoryStore({ [SAVE_KEY]: "{not json" }));
    expect((await s.load()).unlocked).toBe(1);
    expect(migrate({ unlocked: -3, stars: { a: 9, b: 2 }, settings: { tickSpeed: "warp" } }).stars).toEqual({ b: 2 });
  });
});

describe("pack-01", () => {
  it("120 레벨, 모두 솔버 해법으로 클리어 (앞 10개)", () => {
    const levels = pack as unknown as Level[];
    expect(levels.length).toBe(120);
    for (const lv of levels.slice(0, 10)) expect(playSolution(lv).status).toBe("cleared");
  });
});
