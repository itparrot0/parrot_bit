// 설정 한 줄 → 시드별 생성 → 목표에 가장 가까운 레벨 하나 (worker 와 테스트가 함께 쓴다)
import { DEFAULT_OPTIONS, type Level, type Options } from "@bloom-wave/core/engine";
import { generate, type GenReport } from "@bloom-wave/core/generator";
import { readPngArt } from "./png.ts";
import type { LevelSpec, PackConfig } from "./config.ts";

export type Job = { index: number; spec: LevelSpec; defaults: PackConfig["defaults"]; artPath: string; names: { ko: string; en: string } };
export type JobResult = {
  index: number;
  level: Level;
  report: Omit<GenReport, "level">;
  seed: number;
  tried: { seed: number; win: number; score: number; ms: number; error?: string }[];
  warnings: string[];
};

export function runJob(job: Job): JobResult {
  const { spec, defaults } = job;
  const { art, warnings } = readPngArt(job.artPath, spec.art, defaults.maxColors);
  const options: Options = { ...DEFAULT_OPTIONS, ...defaults.options, ...(spec.options ?? {}) };
  const tried: JobResult["tried"] = [];
  let best: { r: GenReport; seed: number; d: number } | null = null;
  const [lo, hi] = spec.winRange;
  for (const seed of spec.seeds) {
    const t = Date.now();
    try {
      const r = generate(art, {
        seed, starts: spec.starts, dropMin: spec.dropMin, dropMax: spec.dropMax, lanes: spec.lanes, scale: spec.scale ?? 1,
        displacements: spec.displacements ?? defaults.displacements, targetWinRate: spec.targetWinRate,
        options, slotCount: defaults.slotCount, maxSolverNodes: defaults.maxSolverNodes,
      });
      tried.push({ seed, win: r.randomWinRate, score: r.score, ms: Date.now() - t });
      // 구간 안이면 목표와의 거리, 밖이면 구간까지의 거리 + 1 (구간 안을 항상 우선)
      const w = r.randomWinRate;
      const d = w >= lo && w <= hi ? Math.abs(w - spec.targetWinRate) : 1 + Math.min(Math.abs(w - lo), Math.abs(w - hi));
      if (!best || d < best.d) best = { r, seed, d };
      if (w >= lo && w <= hi && Math.abs(w - spec.targetWinRate) < 0.05) break; // 충분히 가까우면 그만
    } catch (e) {
      tried.push({ seed, win: NaN, score: NaN, ms: Date.now() - t, error: (e as Error).message });
    }
  }
  if (!best) throw new Error(`${spec.art}: no seed produced a level`);
  const { level: raw, ...report } = best.r;
  const id = spec.variant && spec.variant > 1 ? `${spec.art}-${spec.variant}` : spec.art;
  const suffix = spec.variant && spec.variant > 1 ? " II" : "";
  const optDiff: Partial<Options> = {};
  if (options.visible !== DEFAULT_OPTIONS.visible) optDiff.visible = options.visible;
  if (options.realtime !== DEFAULT_OPTIONS.realtime) optDiff.realtime = options.realtime;
  const level: Level = {
    id, width: raw.width, height: raw.height, palette: raw.palette, cells: raw.cells, starts: raw.starts,
    lanes: raw.lanes, slotCount: raw.slotCount,
    ...(Object.keys(optDiff).length ? { options: optDiff } : {}),
    meta: {
      score: report.score, difficulty: report.difficulty, peakSlots: report.peakSlots, avgSlots: report.avgSlots,
      randomWinRate: Math.round(report.randomWinRate * 1000) / 1000, solverNodes: report.solverNodes,
      art: spec.art, ...(spec.scale && spec.scale > 1 ? { scale: spec.scale } : {}),
      name: { ko: job.names.ko + suffix, en: job.names.en + suffix },
    },
  };
  return { index: job.index, level, report, seed: best.seed, tried, warnings };
}
