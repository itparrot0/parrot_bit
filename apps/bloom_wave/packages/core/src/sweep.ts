// 규칙 변형별 난이도 분포 확인용: node src/sweep.ts
import { generate } from "./generator.ts";
import { ARTS } from "./arts.ts";
import type { Options } from "./engine.ts";
const variants: [string, Options][] = [
  // 참고: 대기열 앞 N개 중 선택 변형
  ["확정 규칙 (맨 앞 1개, 웨이브 중 탭 가능)", { queuePick: 1, realtime: true }],
  ["비교: 웨이브가 멈춘 뒤에만 탭", { queuePick: 1, realtime: false }],
  ["변형: 대기열 앞 2개 중 선택", { queuePick: 2, realtime: false }],
  ["변형: 대기열 앞 3개 중 선택", { queuePick: 3, realtime: false }],
];
for (const [label, options] of variants) {
  console.log(`\n## ${label}`);
  for (const art of ARTS) {
    const rows: string[] = [];
    for (let seed = 1; seed <= 4; seed++) {
      const t = Date.now();
      const r = generate(art, { seed, starts: 1, dropMin: 1, dropMax: 4, displacements: 150, options });
      rows.push(`win=${(r.randomWinRate * 100).toFixed(0)}% peak=${r.peakSlots} avg=${r.avgSlots} drops=${r.drops} score=${r.score} ${Date.now() - t}ms`);
    }
    console.log(art.name, "\n  " + rows.join("\n  "));
  }
}
