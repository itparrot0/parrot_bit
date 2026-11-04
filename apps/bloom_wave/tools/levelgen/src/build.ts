// levelgen build <config> : 설정 → worker_threads 병렬 생성 → 정렬·배치 → out/<pack>.json, report.csv, previews/*.png
import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { availableParallelism } from "node:os";
import { dirname, join, resolve } from "node:path";
import { Worker } from "node:worker_threads";
import { createState, type Level } from "@bloom-wave/core/engine";
import type { PackConfig } from "./config.ts";
import { runJob, type Job, type JobResult } from "./generate-one.ts";
import { writePreview } from "./png.ts";

// 레벨 하나를 한 줄로: diff가 읽기 쉽고 파일이 작다. 같은 입력이면 바이트 단위로 같다.
export function serializePack(levels: Level[]): string {
  return "[\n" + levels.map((l) => "  " + JSON.stringify(l)).join(",\n") + "\n]\n";
}

function runPool(jobs: Job[], threads: number, onDone: (r: JobResult, done: number) => void): Promise<JobResult[]> {
  if (threads <= 1) {
    return Promise.resolve(jobs.map((j, k) => { const r = runJob(j); onDone(r, k + 1); return r; }));
  }
  return new Promise((res, rej) => {
    const results: JobResult[] = [];
    let next = 0, done = 0;
    const workers: Worker[] = [];
    const feed = (w: Worker) => { if (next < jobs.length) w.postMessage(jobs[next++]); };
    for (let t = 0; t < Math.min(threads, jobs.length); t++) {
      const w = new Worker(new URL("./worker.ts", import.meta.url));
      workers.push(w);
      w.on("message", (m: { ok: boolean; result?: JobResult; index?: number; error?: string }) => {
        if (!m.ok) { workers.forEach((x) => x.terminate()); rej(new Error(`level #${m.index! + 1}: ${m.error}`)); return; }
        results.push(m.result!); done++;
        onDone(m.result!, done);
        if (done === jobs.length) { workers.forEach((x) => x.terminate()); res(results); } else feed(w);
      });
      w.on("error", rej);
      feed(w);
    }
  });
}

// 구간 안에서: 숨 돌리기/보스는 설정 위치에 고정, 나머지는 score 오름차순으로 채운다. 튜토리얼은 설정 순서 그대로.
export function arrange(config: PackConfig, results: JobResult[]): JobResult[] {
  const byIndex = new Map(results.map((r) => [r.index, r]));
  const out: JobResult[] = [];
  const bands = [...new Set(config.levels.map((l) => l.band))];
  for (const band of bands) {
    const idx = config.levels.map((l, i) => (l.band === band ? i : -1)).filter((i) => i >= 0);
    if (band === "tutorial") { out.push(...idx.map((i) => byIndex.get(i)!)); continue; }
    const regular = idx.filter((i) => !config.levels[i].role).map((i) => byIndex.get(i)!)
      .sort((a, b) => a.report.score - b.report.score || a.index - b.index);
    let k = 0;
    for (const i of idx) out.push(config.levels[i].role ? byIndex.get(i)! : regular[k++]);
  }
  return out;
}

export async function build(configPath: string, flags: { threads?: number; limit?: number } = {}) {
  const cfgFile = resolve(configPath);
  const base = dirname(cfgFile);
  const config: PackConfig = JSON.parse(readFileSync(cfgFile, "utf8"));
  const limited = !!flags.limit;
  if (flags.limit) config.levels = config.levels.slice(0, flags.limit);
  const names: Record<string, { ko: string; en: string }> = JSON.parse(readFileSync(join(base, "art", "names.json"), "utf8"));
  const jobs: Job[] = config.levels.map((spec, index) => ({
    index, spec, defaults: config.defaults, artPath: join(base, "art", `${spec.art}.png`),
    names: names[spec.art] ?? { ko: spec.art, en: spec.art },
  }));
  const threads = flags.threads ?? Math.max(1, availableParallelism() - 1);
  const t0 = Date.now();
  console.log(`building ${jobs.length} levels on ${threads} threads…`);
  const results = await runPool(jobs, threads, (r, done) => {
    const ms = r.tried.reduce((a, t) => a + t.ms, 0);
    console.log(`[${String(done).padStart(3)}/${jobs.length}] #${r.index + 1} ${r.level.id} seed=${r.seed} ` +
      `${r.level.width}x${r.level.height} lanes=${r.level.lanes.length} win=${(r.report.randomWinRate * 100).toFixed(0)}% ${r.report.difficulty} score=${r.report.score} (${ms}ms)`);
  });
  const ordered = arrange(config, results);
  const levels = ordered.map((r) => r.level);

  const out = join(base, "out");
  mkdirSync(join(out, "previews"), { recursive: true });
  const packFile = join(out, `${config.pack}.json`);
  writeFileSync(packFile, serializePack(levels));
  const csv = ["no,id,band,role,size,lanes,colors,cells,drops,peakSlots,avgSlots,randomWinRate,difficulty,solverNodes,score,seed"];
  ordered.forEach((r, i) => {
    const spec = config.levels[r.index];
    const m = r.level.meta!;
    csv.push([i + 1, r.level.id, spec.band, spec.role ?? "", `${r.level.width}x${r.level.height}`, r.level.lanes.length,
      r.report.colors, r.report.cells, r.report.drops, m.peakSlots, m.avgSlots, m.randomWinRate, m.difficulty, m.solverNodes, m.score, r.seed].join(","));
    writePreview(join(out, "previews", `${String(i + 1).padStart(3, "0")}-${r.level.id}.png`), r.level, createState(r.level));
  });
  writeFileSync(join(out, "report.csv"), csv.join("\n") + "\n");
  for (const w of [...new Set(results.flatMap((r) => r.warnings))]) console.warn("warn:", w);
  if (!limited) {
    for (const dest of config.copyTo ?? []) {
      const d = resolve(base, dest);
      mkdirSync(dirname(d), { recursive: true });
      copyFileSync(packFile, d);
      console.log(`copied → ${d}`);
    }
  }
  console.log(`done: ${levels.length} levels in ${((Date.now() - t0) / 1000).toFixed(1)}s → ${packFile}`);
  return levels;
}
