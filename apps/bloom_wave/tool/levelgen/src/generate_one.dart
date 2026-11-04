// 설정 한 줄 → 시드별 생성 → 목표에 가장 가까운 레벨 하나 (빌드 isolate 와 테스트가 함께 쓴다)
import 'dart:math' as math;

import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/domain/generator.dart';

import 'config.dart';
import 'png.dart';

class Job {
  const Job({
    required this.index,
    required this.spec,
    required this.defaults,
    required this.artPath,
    required this.names,
  });
  final int index;
  final LevelSpec spec;
  final PackDefaults defaults;
  final String artPath;
  final LevelName names;
}

class Tried {
  const Tried(this.seed, this.win, this.score, this.ms, [this.error]);
  final int seed;
  final double win;
  final num score;
  final int ms;
  final String? error;
}

class JobResult {
  const JobResult({
    required this.index,
    required this.level,
    required this.report,
    required this.seed,
    required this.tried,
    required this.warnings,
  });
  final int index;
  final Level level;

  /// 지표만 쓴다 (report.level 은 id·meta 를 붙이기 전의 원본)
  final GenReport report;
  final int seed;
  final List<Tried> tried;
  final List<String> warnings;
}

JobResult runJob(Job job) {
  final spec = job.spec, defaults = job.defaults;
  final (:art, :warnings) = readPngArt(
    job.artPath,
    spec.art,
    defaults.maxColors,
  );
  // {...DEFAULT_OPTIONS, ...defaults.options, ...spec.options}
  final options = (spec.options ?? const PartialOptions()).over(
    defaults.options,
  );
  final tried = <Tried>[];
  ({GenReport r, int seed, double d})? best;
  final lo = spec.winRange.$1, hi = spec.winRange.$2;
  final target = spec.targetWinRate;
  for (final seed in spec.seeds) {
    final sw = Stopwatch()..start();
    try {
      final r = generate(
        art,
        GenParams(
          seed: seed,
          starts: spec.starts,
          dropMin: spec.dropMin,
          dropMax: spec.dropMax,
          lanes: spec.lanes,
          scale: spec.scale ?? 1,
          displacements: spec.displacements ?? defaults.displacements,
          targetWinRate: target.toDouble(),
          options: options,
          slotCount: defaults.slotCount,
          maxSolverNodes: defaults.maxSolverNodes,
        ),
      );
      tried.add(Tried(seed, r.randomWinRate, r.score, sw.elapsedMilliseconds));
      // 구간 안이면 목표와의 거리, 밖이면 구간까지의 거리 + 1 (구간 안을 항상 우선)
      final w = r.randomWinRate;
      final inRange = w >= lo && w <= hi;
      final double d = inRange
          ? (w - target).abs().toDouble()
          : 1 + math.min((w - lo).abs(), (w - hi).abs()).toDouble();
      if (best == null || d < best.d) best = (r: r, seed: seed, d: d);
      if (inRange && (w - target).abs() < 0.05) break; // 충분히 가까우면 그만
    } catch (e) {
      tried.add(
        Tried(seed, double.nan, double.nan, sw.elapsedMilliseconds, '$e'),
      );
    }
  }
  if (best == null) throw StateError('${spec.art}: no seed produced a level');
  final report = best.r, raw = report.level;
  final v2 = spec.variant != null && spec.variant! > 1;
  final id = v2 ? '${spec.art}-${spec.variant}' : spec.art;
  final suffix = v2 ? ' II' : '';
  final level = Level(
    id: id,
    width: raw.width,
    height: raw.height,
    palette: raw.palette,
    cells: raw.cells,
    starts: raw.starts,
    lanes: raw.lanes,
    slotCount: raw.slotCount,
    // 기본값과 다른 옵션만 기록 (키 순서 visible → realtime, Level.toJson 이 지킨다)
    visible: options.visible != defaultOptions.visible ? options.visible : null,
    realtime: options.realtime != defaultOptions.realtime
        ? options.realtime
        : null,
    meta: LevelMeta(
      score: report.score,
      difficulty: report.difficulty,
      peakSlots: report.peakSlots,
      avgSlots: report.avgSlots,
      randomWinRate: jsRound(report.randomWinRate * 1000) / 1000,
      solverNodes: report.solverNodes,
      art: spec.art,
      scale: spec.scale != null && spec.scale! > 1 ? spec.scale : null,
      name: LevelName(job.names.ko + suffix, job.names.en + suffix),
    ),
  );
  return JobResult(
    index: job.index,
    level: level,
    report: report,
    seed: best.seed,
    tried: tried,
    warnings: warnings,
  );
}
