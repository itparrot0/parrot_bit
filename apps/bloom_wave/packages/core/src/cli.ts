// 사용법: node src/cli.ts [아트이름] [seed] [starts] [dropMin] [dropMax] [displacements] [queuePick] [realtime]
// 예)     node src/cli.ts mushroom 3 1 1 4 150        (realtime 기본 1 = 웨이브 중 탭 허용)
import { createState, render, applyAction, runUntilStable, type Options } from "./engine.ts";
import { generate } from "./generator.ts";
import { solve } from "./solver.ts";
import { ARTS } from "./arts.ts";

const [name = "tulip", seed = "1", starts = "1", dmin = "2", dmax = "5", disp = "300", pick = "1", rt = "1"] = process.argv.slice(2);
const art = ARTS.find((a) => a.name === name) ?? ARTS[0];
const options: Options = { queuePick: +pick, realtime: rt === "1" };
const rep = generate(art, { seed: +seed, starts: +starts, dropMin: +dmin, dropMax: +dmax, displacements: +disp, options });
const { level } = rep;
console.log(`level ${level.id}: colors=${rep.colors} cells=${rep.cells} drops=${rep.drops} moved=${rep.displacementsApplied} ` +
  `peakSlots=${rep.peakSlots} avgSlots=${rep.avgSlots} randomWin=${(rep.randomWinRate * 100).toFixed(0)}% score=${rep.score}`);
const s = createState(level);
console.log(render(level, s));
const sol = solve(level, options);
console.log(`\nsolution (${sol.solution.length} actions):`);
for (const a of sol.solution) {
  const evs = applyAction(level, s, a, options);
  if (a.type === "tick") { console.log(`\n> wait 1 tick`); }
  else console.log(`\n> tap queue[${a.index}] → ${evs.length} ticks, bloomed ${evs.reduce((n, e) => n + e.blooms.reduce((m, b) => m + b.cells.length, 0), 0)}`);
  console.log(render(level, s));
}
