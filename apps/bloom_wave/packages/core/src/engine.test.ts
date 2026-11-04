// npm test 로 실행
import test from "node:test";
import assert from "node:assert/strict";
import {
  BLOOM, SEED, SPROUT, type Level, TURN_BASED,
  applyAction, createState, legalActions, tick, deploy, queueLength,
} from "./engine.ts";
import { generate, replay, scaleArt, artToCells, difficultyOf } from "./generator.ts";
import { solve, solveFrom } from "./solver.ts";
import { ARTS } from "./arts.ts";

// 1행 5칸: a a b a a, 시작 발아는 0번
const line = (lanes: Level["lanes"], slotCount = 4, starts = [0]): Level => ({
  id: "t", width: 5, height: 1, palette: ["#f00", "#00f"], cells: [0, 0, 1, 0, 0], starts, lanes, slotCount,
});

test("줄마다 맨 앞을 탭할 수 있고, 웨이브 중에는 기다리기(틱)도 선택지", () => {
  const lv = line([[{ color: 0, amount: 2 }, { color: 0, amount: 2 }], [{ color: 1, amount: 1 }], []]);
  const s = createState(lv);
  assert.deepEqual(legalActions(s), [{ type: "deploy", lane: 0 }, { type: "deploy", lane: 1 }]); // 빈 줄은 제외
  applyAction(lv, s, { type: "deploy", lane: 0 });
  assert.deepEqual(legalActions(s), [{ type: "deploy", lane: 0 }, { type: "deploy", lane: 1 }, { type: "tick" }]);
  assert.deepEqual(legalActions(s, TURN_BASED), [{ type: "tick" }]);
});

test("쓸 수 있는지와 무관하게 슬롯으로 이동", () => {
  const lv = line([[{ color: 1, amount: 1 }], [{ color: 0, amount: 2 }, { color: 0, amount: 2 }]]);
  const s = createState(lv);
  applyAction(lv, s, { type: "deploy", lane: 0 }); // b 발아 칸이 없어도 슬롯으로 감
  assert.deepEqual(s.slots, [{ color: 1, amount: 1 }, null, null, null]);
  assert.equal(queueLength(s), 2);
  assert.equal(s.status, "playing");
});

test("한 틱에 한 링씩: 같은 색 발아 칸 전체가 링, 개화는 8방향 씨앗을 색 무관 발아", () => {
  const lv = line([[{ color: 0, amount: 2 }, { color: 1, amount: 1 }, { color: 0, amount: 2 }]]);
  const s = createState(lv);
  deploy(lv, s, 0);
  const t0 = tick(lv, s);
  assert.deepEqual(t0.blooms, [{ slot: 0, color: 0, cells: [0] }]);
  assert.deepEqual(t0.sprouted, [1]);
  assert.deepEqual(s.slots[0], { color: 0, amount: 1 });
  const t1 = tick(lv, s);
  assert.deepEqual(t1.blooms[0].cells, [1]);
  assert.equal(s.cell[2], SPROUT);
  assert.equal(s.cell[3], SEED);
  assert.equal(s.slots[0], null);
});

test("물방울은 발아 칸에만 소모되고, 퍼질 곳이 없으면 슬롯에 남는다", () => {
  const lv = line([[{ color: 0, amount: 4 }], [{ color: 1, amount: 1 }]]);
  const s = createState(lv);
  applyAction(lv, s, { type: "deploy", lane: 0 }, TURN_BASED);
  assert.deepEqual(s.slots[0], { color: 0, amount: 2 });
  applyAction(lv, s, { type: "deploy", lane: 1 }, TURN_BASED);
  assert.equal(s.status, "cleared");
  assert.ok(Array.from(s.cell).every((c) => c === BLOOM));
});

test("8방향 순서: 남동 > 남 > 남서 > 서 > 북서 > 북 > 북동 > 동", () => {
  const lv: Level = { id: "o", width: 3, height: 3, palette: ["#f00"], cells: new Array(9).fill(0), starts: [4],
    lanes: [[{ color: 0, amount: 1 }, { color: 0, amount: 8 }]], slotCount: 4 };
  const s = createState(lv);
  applyAction(lv, s, { type: "deploy", lane: 0 }, TURN_BASED);
  const second = applyAction(lv, s, { type: "deploy", lane: 0 }, TURN_BASED);
  assert.deepEqual(second[0].blooms[0].cells, [8, 7, 6, 3, 0, 1, 2, 5]);
});

test("안정 상태에서 슬롯 4칸이 모두 차면 실패", () => {
  const lv = line([[{ color: 1, amount: 1 }, { color: 1, amount: 1 }], [{ color: 1, amount: 1 }, { color: 1, amount: 1 }], [{ color: 0, amount: 4 }]]);
  const s = createState(lv);
  for (const lane of [0, 0, 1]) applyAction(lv, s, { type: "deploy", lane }, TURN_BASED);
  assert.equal(s.status, "playing");
  applyAction(lv, s, { type: "deploy", lane: 1 }, TURN_BASED);
  assert.equal(s.status, "failed");
});

test("해상도 배율: 한 픽셀이 scale×scale 칸", () => {
  const art = { name: "x", palette: ["a=#f00", "b=#00f"], rows: ["a.", ".b"] };
  const c = artToCells(scaleArt(art, 2));
  assert.equal(c.width, 4);
  assert.equal(c.height, 4);
  assert.deepEqual(c.cells, [0, 0, -1, -1, 0, 0, -1, -1, -1, -1, 1, 1, -1, -1, 1, 1]);
});

test("난이도 등급", () => {
  assert.equal(difficultyOf(0.8), "normal");
  assert.equal(difficultyOf(0.2), "hard");
  assert.equal(difficultyOf(0.1), "superHard");
  assert.equal(difficultyOf(0.05), "megaHard");
});

for (const lanes of [1, 3, 4]) {
  test(`생성기 (대기열 ${lanes}줄): 물방울 총량 = 칸 수, 솔버 해법 재생 시 클리어`, () => {
    for (const art of ARTS) for (let seed = 1; seed <= 2; seed++) {
      const r = generate(art, { seed, starts: 1, dropMin: 1, dropMax: 4, displacements: 30, lanes, trials: 40 });
      assert.equal(r.level.lanes.length, lanes);
      assert.ok(r.level.lanes.every((l) => l.length > 0));
      assert.equal(r.level.lanes.flat().reduce((a, d) => a + d.amount, 0), r.cells);
      const sol = solve(r.level);
      assert.equal(sol.solvable, true);
      assert.ok(replay(r.level, sol.solution));
    }
  });
}

test("확대한 그림도 클리어 보장", () => {
  const r = generate(ARTS[0], { seed: 1, starts: 1, dropMin: 2, dropMax: 5, displacements: 20, lanes: 3, scale: 2, trials: 30 });
  assert.equal(r.level.width, 18);
  assert.equal(r.cells, 31 * 4);
  const sol = solve(r.level);
  assert.equal(sol.solvable, true);
  assert.ok(replay(r.level, sol.solution));
});

test("solveFrom: 진행 중 상태에서도 해법을 찾는다", () => {
  const r = generate(ARTS[1], { seed: 3, starts: 1, dropMin: 1, dropMax: 4, displacements: 30, lanes: 3, trials: 30 });
  const s = createState(r.level);
  const first = solve(r.level).solution[0];
  applyAction(r.level, s, first);
  const sol = solveFrom(r.level, s);
  assert.equal(sol.solvable, true);
});
