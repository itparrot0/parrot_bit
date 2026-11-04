// levels.config.json 을 만든다 (한 번 만들고 커밋한 뒤 사람이 손으로 고쳐도 된다).
// 01_게임기획서.md 7.3 난이도 곡선: 튜토리얼 1~5 / 입문 6~30 / 중급 31~80 / 상급 81~120.
import { writeFileSync } from "node:fs";
import { ART_SOURCES } from "./art-source.ts";
import type { LevelSpec, PackConfig } from "./config.ts";

const size = (name: string) => {
  const a = ART_SOURCES.find((x) => x.name === name)!;
  const cells = a.rows.join("").replace(/\./g, "").length;
  return { cells, colors: a.palette.length, complexity: cells * (1 + 0.25 * a.palette.length) };
};

const tutorial: LevelSpec[] = [
  { art: "dewdrop", band: "tutorial", tutorial: "wave", seeds: [1], starts: 1, dropMin: 6, dropMax: 9, displacements: 0, targetWinRate: 1, winRange: [1, 1], options: { realtime: false } },
  { art: "sprout", band: "tutorial", tutorial: "colors", seeds: [1, 2, 3], starts: 1, dropMin: 5, dropMax: 8, displacements: 0, targetWinRate: 1, winRange: [1, 1], options: { realtime: false } },
  { art: "heart", band: "tutorial", tutorial: "realtime", seeds: [1, 2, 3], starts: 2, dropMin: 4, dropMax: 8, displacements: 0, targetWinRate: 1, winRange: [1, 1] },
  { art: "sun", band: "tutorial", tutorial: "waiting", seeds: [1, 2, 3, 4], starts: 1, dropMin: 3, dropMax: 6, displacements: 30, targetWinRate: 1, winRange: [0.95, 1] },
  { art: "snowflake", band: "tutorial", tutorial: "slots", seeds: [1, 2, 3], starts: 2, dropMin: 3, dropMax: 6, displacements: 60, targetWinRate: 1, winRange: [0.9, 1] },
];
const used = new Set(tutorial.map((t) => t.art));
const pool = ART_SOURCES.map((a) => a.name).filter((n) => !used.has(n)).sort((a, b) => size(a).complexity - size(b).complexity);

// 구간별 그림 배정
const intro = pool.slice(0, 25); // 6~30
const mid = pool.slice(25, 75); // 31~80
const hardUnique = pool.slice(75); // 81~ (가장 큰 그림)
const hardRepeat = pool.slice(45, 75).reverse(); // 중급 후반 그림을 더 어려운 설정으로 한 번 더 ("II")

const levels: LevelSpec[] = [...tutorial];
const seeds = [1, 2, 3, 4, 5, 6];

// 입문: 큰 물방울, 시작 지점 여러 곳. 마지막(30)은 보스: 입문 구간에서 가장 큰 그림.
intro.forEach((art, i) => levels.push({
  art, band: "intro", role: i === intro.length - 1 ? "boss" : undefined, seeds: seeds.slice(0, 4),
  starts: 2, dropMin: 2, dropMax: 6, targetWinRate: 0.85, winRange: [0.7, 1],
}));
// 중급: 시작 지점 1곳, 물방울 1~4. 10레벨마다 숨 돌리기 1개(35, 45, ...), 마지막(80) 보스.
mid.forEach((art, i) => {
  const breather = i % 10 === 4;
  const boss = i === mid.length - 1;
  levels.push(breather
    ? { art, band: "mid", role: "breather", seeds: seeds.slice(0, 4), starts: 2, dropMin: 3, dropMax: 6, targetWinRate: 0.9, winRange: [0.75, 1] }
    : { art, band: "mid", role: boss ? "boss" : undefined, seeds, starts: 1, dropMin: 1, dropMax: 4, targetWinRate: 0.5, winRange: [0.3, 0.7] });
});
// 상급: 물방울 1~3. 큰 그림 + 중급 그림 II. 마지막(120)은 가장 큰 그림.
const hard = [...hardRepeat.map((art) => ({ art, variant: 2 as number | undefined })), ...hardUnique.map((art) => ({ art, variant: undefined as number | undefined }))];
const boss = hard.splice(hard.findIndex((h) => h.art === hardUnique[hardUnique.length - 1]), 1)[0];
hard.push(boss);
hard.forEach(({ art, variant }, i) => {
  const breather = i % 10 === 4;
  levels.push(breather
    ? { art, variant, band: "hard", role: "breather", seeds: seeds.slice(0, 4), starts: 2, dropMin: 2, dropMax: 5, targetWinRate: 0.7, winRange: [0.5, 1] }
    : { art, variant, band: "hard", role: i === hard.length - 1 ? "boss" : undefined, seeds, starts: 1, dropMin: 1, dropMax: 3, targetWinRate: 0.15, winRange: [0.05, 0.3] });
});

const config: PackConfig = {
  pack: "pack-01",
  copyTo: ["../../app/src/levels/pack-01.json"],
  defaults: { slotCount: 4, options: { queuePick: 1, realtime: true }, displacements: 1500, maxSolverNodes: 50000, maxColors: 6 },
  levels,
};
writeFileSync(new URL("../levels.config.json", import.meta.url), JSON.stringify(config, null, 2) + "\n");
console.log(`levels: ${levels.length} (tutorial ${tutorial.length}, intro ${intro.length}, mid ${mid.length}, hard ${hard.length})`);
