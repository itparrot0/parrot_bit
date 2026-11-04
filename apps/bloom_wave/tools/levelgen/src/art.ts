// art-source.ts의 텍스트 픽셀 아트를 art/<name>.png 와 art/names.json 으로 내보낸다.
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { ART_SOURCES } from "./art-source.ts";
import { encodeArt } from "./png.ts";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dir = join(root, "art");
mkdirSync(dir, { recursive: true });
const names: Record<string, { ko: string; en: string }> = {};
for (const a of ART_SOURCES) {
  const w = Math.max(...a.rows.map((r) => r.length));
  writeFileSync(join(dir, `${a.name}.png`), encodeArt({ name: a.name, palette: a.palette, rows: a.rows.map((r) => r.padEnd(w, ".")) }));
  names[a.name] = { ko: a.ko, en: a.en };
}
writeFileSync(join(dir, "names.json"), JSON.stringify(names, null, 2) + "\n");
console.log(`wrote ${ART_SOURCES.length} PNGs to art/`);
