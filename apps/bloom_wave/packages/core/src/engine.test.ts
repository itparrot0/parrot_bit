// npm test 로 실행
import test from "node:test";
import assert from "node:assert/strict";
import {
  BLOOM, SEED, SPROUT, type Level, type Options, TURN_BASED,
  applyAction, createState, legalActions, tick, deploy,
} from "./engine.ts";
import { generate, replay } from "./generator.ts";
import { solve } from "./solver.ts";
import { ARTS } from "./arts.ts";

// 1행 5칸: a a b a a, 시작 발아는 0번
const line = (queue: Level["queue"], slotCount = 4, starts = [0]): Level => ({
  id: "t", width: 5, height: 1, palette: ["#f00", "#00f"], cells: [0, 0, 1, 0, 0], starts, queue, slotCount,
});

test("웨이브 진행 중에도 맨 앞을 탭할 수 있고, 기다리기(틱)도 선택지", () => {
  const lv = line([{ color: 0, amount: 2 }, { color: 1, amount: 1 }, { color: 0, amount: 2 }]);
  const s = createState(lv);
  applyAction(lv, s, { type: "deploy", index: 0 }); // 기본 규칙: 탭 후 바로 돌아옴(틱은 앱 타이머가 돌림)
  assert.deepEqual(legalActions(s), [{ type: "deploy", index: 0 }, { type: "tick" }]);
  assert.deepEqual(legalActions(s, TURN_BASED), [{ type: "tick" }]);
});

test("맨 앞 물방울만 탭할 수 있고, 쓸 수 있는지와 무관하게 슬롯으로 이동", () => {
  const lv = line([{ color: 1, amount: 1 }, { color: 0, amount: 2 }, { color: 0, amount: 2 }]);
  const s = createState(lv);
  assert.deepEqual(legalActions(s), [{ type: "deploy", index: 0 }]);
  applyAction(lv, s, { type: "deploy", index: 0 }); // b 발아 칸이 없어도 슬롯으로 감
  assert.deepEqual(s.slots, [{ color: 1, amount: 1 }, null, null, null]);
  assert.equal(s.status, "playing");
});

test("한 틱에 한 링씩: 같은 색 발아 칸 전체가 링, 개화는 8방향 씨앗을 색 무관 발아", () => {
  const lv = line([{ color: 0, amount: 2 }, { color: 1, amount: 1 }, { color: 0, amount: 2 }]);
  const s = createState(lv);
  deploy(lv, s);
  const t0 = tick(lv, s);
  assert.deepEqual(t0.blooms, [{ slot: 0, color: 0, cells: [0] }]);
  assert.deepEqual(t0.sprouted, [1]);
  assert.deepEqual(s.slots[0], { color: 0, amount: 1 }); // 남은 양은 슬롯에 남는다
  const t1 = tick(lv, s); // 다음 링을 다시 계산: 막 발아한 1번
  assert.deepEqual(t1.blooms[0].cells, [1]);
  assert.equal(s.cell[2], SPROUT); // 다른 색(b)도 발아
  assert.equal(s.cell[3], SEED);
  assert.equal(s.slots[0], null);
});

test("물방울은 발아 칸에만 소모되고, 퍼질 곳이 없으면 슬롯에 남는다", () => {
  const lv = line([{ color: 0, amount: 4 }, { color: 1, amount: 1 }]);
  const s = createState(lv);
  applyAction(lv, s, { type: "deploy", index: 0 }, TURN_BASED); // a 2칸만 닿고 2 남음
  assert.deepEqual(s.slots[0], { color: 0, amount: 2 });
  applyAction(lv, s, { type: "deploy", index: 0 }, TURN_BASED); // b 가 피며 3번을 깨우면 슬롯의 a 가 다시 퍼짐
  assert.equal(s.status, "cleared");
  assert.ok(Array.from(s.cell).every((c) => c === BLOOM));
});

test("8방향 순서: 남동 > 남 > 남서 > 서 > 북서 > 북 > 북동 > 동", () => {
  const lv: Level = { id: "o", width: 3, height: 3, palette: ["#f00"], cells: new Array(9).fill(0), starts: [4],
    queue: [{ color: 0, amount: 1 }, { color: 0, amount: 8 }], slotCount: 4 };
  const s = createState(lv);
  applyAction(lv, s, { type: "deploy", index: 0 }, TURN_BASED);
  const second = applyAction(lv, s, { type: "deploy", index: 0 }, TURN_BASED);
  assert.deepEqual(second[0].blooms[0].cells, [8, 7, 6, 3, 0, 1, 2, 5]);
});

test("안정 상태에서 슬롯 4칸이 모두 차면 실패", () => {
  const lv = line([{ color: 1, amount: 1 }, { color: 1, amount: 1 }, { color: 1, amount: 1 }, { color: 1, amount: 1 }, { color: 0, amount: 4 }]);
  const s = createState(lv);
  for (let k = 0; k < 3; k++) applyAction(lv, s, { type: "deploy", index: 0 }, TURN_BASED);
  assert.equal(s.status, "playing");
  applyAction(lv, s, { type: "deploy", index: 0 }, TURN_BASED);
  assert.equal(s.status, "failed");
});

const variants: Options[] = [
  { queuePick: 1, realtime: false }, { queuePick: 2, realtime: false }, { queuePick: 1, realtime: true },
];
for (const options of variants) {
  test(`생성기 ${JSON.stringify(options)}: 물방울 총량 = 칸 수, 솔버 해법 재생 시 클리어`, () => {
    for (const art of ARTS) for (let seed = 1; seed <= 2; seed++) {
      const r = generate(art, { seed, starts: 1, dropMin: 1, dropMax: 4, displacements: 40, options });
      assert.equal(r.level.queue.reduce((a, d) => a + d.amount, 0), r.cells);
      const sol = solve(r.level, options);
      assert.equal(sol.solvable, true);
      assert.ok(replay(r.level, sol.solution, options));
    }
  });
}

test("minPeakSlots: 같은 레벨에서 ★3 기준은 1 이상, 슬롯 수 이하", async () => {
  const { minPeakSlots, solveFrom } = await import("./solver.ts");
  for (const art of ARTS) {
    const r = generate(art, { seed: 1, starts: 1, dropMin: 1, dropMax: 4, displacements: 40 });
    const k = minPeakSlots(r.level);
    assert.ok(k !== null && k >= 1 && k <= r.level.slotCount);
    const sol = solveFrom(r.level, createState(r.level), undefined, 200_000, k!);
    assert.equal(sol.solvable, true);
    assert.ok(replay(r.level, sol.solution));
  }
});
