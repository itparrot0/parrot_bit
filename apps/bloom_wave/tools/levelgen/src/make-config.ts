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

const big = (name: string) => { const a = ART_SOURCES.find((x) => x.name === name)!; return Math.max(a.rows.length, ...a.rows.map((r) => r.length)); };

// 대기열은 항상 3줄 이상 (2026-11-04 결정). visible = 줄마다 미리 보이는 물방울 수 (2026-11-04 2차: 모든 레벨 3 = 탭할 1개 + 다음 2개)
const tutorial: LevelSpec[] = [
  { art: "dewdrop", band: "tutorial", tutorial: "wave", seeds: [1], starts: 1, lanes: 3, dropMin: 6, dropMax: 9, displacements: 0, targetWinRate: 1, winRange: [0.9, 1], options: { realtime: false, visible: 3 } },
  { art: "sprout", band: "tutorial", tutorial: "lanes", seeds: [1, 2, 3], starts: 1, lanes: 3, dropMin: 5, dropMax: 8, displacements: 0, targetWinRate: 1, winRange: [0.8, 1], options: { realtime: false, visible: 3 } },
  { art: "heart", band: "tutorial", tutorial: "realtime", seeds: [1, 2, 3, 4], starts: 2, lanes: 3, dropMin: 4, dropMax: 8, displacements: 0, targetWinRate: 1, winRange: [0.7, 1], options: { visible: 3 } },
  { art: "sun", band: "tutorial", tutorial: "waiting", seeds: [1, 2, 3, 4], starts: 1, lanes: 3, dropMin: 3, dropMax: 6, displacements: 0, targetWinRate: 0.9, winRange: [0.6, 1], options: { visible: 3 } },
  { art: "snowflake", band: "tutorial", tutorial: "slots", seeds: [1, 2, 3, 4], starts: 2, lanes: 3, dropMin: 3, dropMax: 6, displacements: 0, targetWinRate: 0.9, winRange: [0.6, 1], options: { visible: 3 } },
];
const used = new Set(tutorial.map((t) => t.art));
const pool = ART_SOURCES.map((a) => a.name).filter((n) => !used.has(n)).sort((a, b) => size(a).complexity - size(b).complexity);

// 구간별 그림 배정
const intro = pool.slice(0, 25); // 6~30
const mid = pool.slice(25, 75); // 31~80
const hardUnique = pool.slice(75); // 81~ (가장 큰 그림)
// 중급 그림을 해상도 2배로 키워 한 번 더 ("II"). 확대 후 24칸을 넘지 않는 그림만
const hardRepeat = pool.slice(0, 75).filter((n) => big(n) * 2 <= 24).reverse().slice(0, 30);

const levels: LevelSpec[] = [...tutorial];
const seeds = [1, 2, 3, 4, 5, 6];

// 입문: 큰 물방울, 시작 지점 여러 곳, 3개씩 미리 보임. 마지막(30)은 보스.
intro.forEach((art, i) => levels.push({
  art, band: "intro", role: i === intro.length - 1 ? "boss" : undefined, seeds: seeds.slice(0, 4),
  starts: 2, lanes: 3, dropMin: 3, dropMax: 6, displacements: 200, targetWinRate: 0.6, winRange: [0.4, 1], options: { visible: 3 },
}));
// 중급: 시작 지점 1곳, 물방울 1~4, 2개씩 미리 보임. 10레벨마다 숨 돌리기, 마지막(80) 보스.
mid.forEach((art, i) => {
  const breather = i % 10 === 4;
  const boss = i === mid.length - 1;
  levels.push(breather
    ? { art, band: "mid", role: "breather", seeds: seeds.slice(0, 4), starts: 2, lanes: 3, dropMin: 3, dropMax: 6, displacements: 100, targetWinRate: 0.6, winRange: [0.4, 1], options: { visible: 3 } }
    : { art, band: "mid", role: boss ? "boss" : undefined, seeds, starts: 1, lanes: 3, dropMin: 1, dropMax: 4, targetWinRate: 0.3, winRange: [0.2, 0.45], options: { visible: 3 } });
});
// 상급: 해상도 2배 그림 + 가장 큰 그림, 대기열 3~4줄, 맨 앞만 보임. 마지막(120)은 가장 큰 그림.
const hard = [
  ...hardRepeat.map((art) => ({ art, variant: 2 as number | undefined, scale: 2 })),
  ...hardUnique.map((art) => ({ art, variant: undefined as number | undefined, scale: 1 })),
];
const last = hard.splice(hard.findIndex((h) => h.art === hardUnique[hardUnique.length - 1]), 1)[0];
hard.push(last);
hard.forEach(({ art, variant, scale }, i) => {
  const breather = i % 10 === 4;
  const lanes = i % 3 === 2 ? 4 : 3;
  levels.push(breather
    ? { art, variant, scale, band: "hard", role: "breather", seeds: seeds.slice(0, 4), starts: 2, lanes: 3, dropMin: 3, dropMax: 6, displacements: 100, targetWinRate: 0.5, winRange: [0.3, 1], options: { visible: 3 } }
    : { art, variant, scale, band: "hard", role: i === hard.length - 1 ? "boss" : undefined, seeds, starts: 1, lanes, dropMin: 1, dropMax: scale > 1 ? 4 : 3, targetWinRate: 0.08, winRange: [0.02, 0.16], options: { visible: 3 } });
});

const config: PackConfig = {
  pack: "pack-01",
  copyTo: ["../../app/src/levels/pack-01.json"],
  defaults: { slotCount: 4, options: { realtime: true, visible: 3 }, displacements: 600, maxSolverNodes: 50000, maxColors: 6, maxSize: 24 },
  levels,
};
writeFileSync(new URL("../levels.config.json", import.meta.url), JSON.stringify(config, null, 2) + "\n");
console.log(`levels: ${levels.length} (tutorial ${tutorial.length}, intro ${intro.length}, mid ${mid.length}, hard ${hard.length})`);
