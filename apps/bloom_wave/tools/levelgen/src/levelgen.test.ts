// npm test -w @bloom-wave/levelgen
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { decodePng, encodeArt } from "./png.ts";
import { runJob, type Job } from "./generate-one.ts";
import { checkLevel } from "./verify.ts";
import { serializePack } from "./build.ts";
import type { PackConfig } from "./config.ts";

const config: PackConfig = JSON.parse(readFileSync(new URL("../levels.config.json", import.meta.url), "utf8"));
const job = (i: number): Job => ({
  index: i, spec: config.levels[i], defaults: config.defaults,
  artPath: fileURLToPath(new URL(`../art/${config.levels[i].art}.png`, import.meta.url)),
  names: { ko: "x", en: "x" },
});

test("PNG 왕복: 텍스트 아트 → PNG → 같은 칸 배열", () => {
  const art = { name: "t", palette: ["r=#E5484D", "g=#46A758"], rows: ["r.g", "rrg", ".g."] };
  const { art: back, warnings } = decodePng(encodeArt(art), "t");
  assert.deepEqual(back.rows, ["a.b", "aab", ".b."]);
  assert.deepEqual(back.palette, ["a=#E5484D", "b=#46A758"]);
  assert.equal(warnings.length, 0); // 두 색 모두 3칸 → 경고 없음
  const small = decodePng(encodeArt({ ...art, rows: ["r.g", "rgg", ".g."] }), "t").warnings;
  assert.ok(small.some((w) => w.includes("칸뿐"))); // r 2칸 → 경고
});

test("색이 maxColors 보다 많으면 가장 가까운 색끼리 병합", () => {
  const art = { name: "m", palette: ["a=#FF0000", "b=#FE0101", "c=#0000FF"], rows: ["aaab", "cccc"] };
  const { art: back, warnings } = decodePng(encodeArt(art), "m", 2);
  assert.equal(back.palette.length, 2);
  assert.deepEqual(back.rows, ["aaaa", "bbbb"]);
  assert.ok(warnings.some((w) => w.includes("병합")));
});

test("같은 설정·시드면 결과가 바이트 단위로 같다 (결정성)", () => {
  for (const i of [0, 3, 6]) {
    const a = serializePack([runJob(job(i)).level]);
    const b = serializePack([runJob(job(i)).level]);
    assert.equal(a, b);
  }
});

test("생성 레벨은 verify 를 통과한다", () => {
  for (const i of [1, 4, 8]) assert.deepEqual(checkLevel(runJob(job(i)).level), []);
});

test("verify 는 총량 불일치·시작점 없는 덩어리를 잡는다", () => {
  const lv = runJob(job(0)).level;
  assert.ok(checkLevel({ ...lv, queue: lv.queue.slice(1) }).some((e) => e.includes("drop total")));
  assert.ok(checkLevel({ ...lv, starts: [] }).some((e) => e.includes("no start")));
});

test("출시 팩: 120 레벨, 튜토리얼 1~2는 realtime false", () => {
  const pack = JSON.parse(readFileSync(new URL("../out/pack-01.json", import.meta.url), "utf8"));
  assert.equal(pack.length, 120);
  assert.equal(pack[0].options?.realtime, false);
  assert.equal(pack[1].options?.realtime, false);
  assert.equal(pack[2].options, undefined);
  assert.equal(new Set(pack.map((l: { id: string }) => l.id)).size, 120);
});
