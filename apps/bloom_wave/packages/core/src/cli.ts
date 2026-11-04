// 사용법: node src/cli.ts [아트이름] [seed] [lanes] [scale] [dropMin] [dropMax] [displacements]
// 예)     node src/cli.ts mushroom 3 3 1 1 4 300
import { createState, render, applyAction } from "./engine.ts";
import { generate } from "./generator.ts";
import { solve } from "./solver.ts";
import { ARTS } from "./arts.ts";

const [name = "tulip", seed = "1", lanes = "3", scale = "1", dmin = "1", dmax = "4", disp = "300"] = process.argv.slice(2);
const art = ARTS.find((a) => a.name === name) ?? ARTS[0];
const t = Date.now();
const rep = generate(art, { seed: +seed, starts: 1, lanes: +lanes, scale: +scale, dropMin: +dmin, dropMax: +dmax, displacements: +disp });
const { level } = rep;
console.log(`level ${level.id}: ${level.width}x${level.height} colors=${rep.colors} cells=${rep.cells} drops=${rep.drops} moved=${rep.displacementsApplied} ` +
  `peak=${rep.peakSlots} avg=${rep.avgSlots} randomWin=${(rep.randomWinRate * 100).toFixed(0)}% ${rep.difficulty} score=${rep.score} nodes=${rep.solverNodes} ${Date.now() - t}ms`);
const s = createState(level);
console.log(render(level, s));
const sol = solve(level);
console.log(`\nsolution (${sol.solution.length} actions)`);
for (const a of sol.solution) {
  applyAction(level, s, a);
  if (a.type === "deploy") console.log(`> tap lane ${a.lane}`);
}
console.log(render(level, s));
