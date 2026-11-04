// levelgen verify <pack.json>
// ①물방울 총량 = 칸 수 ②8방향 덩어리마다 시작 지점 ③솔버 클리어 가능 ④해법 재생 시 클리어. 하나라도 실패하면 종료 코드 1.
import { readFileSync } from "node:fs";
import { DIR8, EMPTY, levelOptions, type Level } from "@bloom-wave/core/engine";
import { solve } from "@bloom-wave/core/solver";
import { replay } from "@bloom-wave/core/generator";

export function checkLevel(level: Level, maxNodes = 200_000): string[] {
  const errs: string[] = [];
  const n = level.width * level.height;
  if (level.cells.length !== n) errs.push(`cells length ${level.cells.length} != ${n}`);
  const cellCount = level.cells.filter((c) => c !== EMPTY).length;
  const total = level.queue.reduce((a, d) => a + d.amount, 0);
  if (total !== cellCount) errs.push(`drop total ${total} != cells ${cellCount}`);
  if (level.queue.some((d) => d.amount <= 0 || d.color < 0 || d.color >= level.palette.length)) errs.push("bad drop in queue");
  const seen = new Uint8Array(n);
  const starts = new Set(level.starts);
  for (let i = 0; i < n; i++) {
    if (level.cells[i] === EMPTY || seen[i]) continue;
    const stack = [i];
    seen[i] = 1;
    let has = false;
    while (stack.length) {
      const c = stack.pop()!;
      if (starts.has(c)) has = true;
      const x = c % level.width, y = (c / level.width) | 0;
      for (const [dx, dy] of DIR8) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= level.width || ny >= level.height) continue;
        const j = ny * level.width + nx;
        if (level.cells[j] !== EMPTY && !seen[j]) { seen[j] = 1; stack.push(j); }
      }
    }
    if (!has) errs.push(`component at cell ${i} has no start`);
  }
  if (errs.length) return errs;
  const opt = levelOptions(level);
  const r = solve(level, opt, maxNodes);
  if (r.solvable !== true) errs.push(`solver: ${r.solvable === null ? "node limit" : "unsolvable"} (${r.nodes} nodes)`);
  else if (!replay(level, r.solution, opt)) errs.push("solution replay did not clear");
  return errs;
}

export function verify(packPath: string): boolean {
  const levels: Level[] = JSON.parse(readFileSync(packPath, "utf8"));
  let ok = true;
  const ids = new Set<string>();
  levels.forEach((l, i) => {
    const errs = checkLevel(l);
    if (ids.has(l.id)) errs.push("duplicate id");
    ids.add(l.id);
    if (errs.length) { ok = false; console.error(`x #${i + 1} ${l.id}: ${errs.join("; ")}`); }
  });
  console.log(ok ? `ok: ${levels.length} levels verified` : "verify FAILED");
  return ok;
}
