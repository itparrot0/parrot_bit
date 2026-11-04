// 대기열 줄 수·해상도 배율별 난이도 분포 확인용: node src/sweep.ts
import { generate } from "./generator.ts";
import { ARTS } from "./arts.ts";
for (const [lanes, scale] of (process.argv[2] ? JSON.parse(process.argv[2]) : [[1, 1], [3, 1], [4, 1], [3, 2]])) {
  console.log(`\n## lanes=${lanes} scale=${scale}`);
  for (const art of ARTS) {
    const rows: string[] = [];
    for (let seed = 1; seed <= 3; seed++) {
      const t = Date.now();
      const r = generate(art, { seed, starts: 1, dropMin: 1, dropMax: 4, displacements: 150, lanes, scale, trials: 150 });
      rows.push(`win=${(r.randomWinRate * 100).toFixed(0)}% ${r.difficulty} peak=${r.peakSlots} drops=${r.drops} nodes=${r.solverNodes} score=${r.score} ${Date.now() - t}ms`);
    }
    console.log(art.name, "\n  " + rows.join("\n  "));
  }
}
