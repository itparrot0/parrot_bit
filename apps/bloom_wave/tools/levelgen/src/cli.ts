#!/usr/bin/env node
// levelgen build levels.config.json [--threads N] [--limit N]
// levelgen verify out/pack-01.json
import { build } from "./build.ts";
import { verify } from "./verify.ts";

const [cmd, file, ...rest] = process.argv.slice(2);
const flag = (name: string) => {
  const i = rest.indexOf(`--${name}`);
  return i >= 0 ? Number(rest[i + 1]) : undefined;
};
if (cmd === "build" && file) {
  await build(file, { threads: flag("threads"), limit: flag("limit") });
} else if (cmd === "verify" && file) {
  process.exit(verify(file) ? 0 : 1);
} else {
  console.error("usage: levelgen build <config.json> [--threads N] [--limit N] | levelgen verify <pack.json>");
  process.exit(2);
}
