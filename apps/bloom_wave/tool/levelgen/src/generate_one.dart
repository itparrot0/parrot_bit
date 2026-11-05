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

/// 같은 그림의 n 번째 레벨 이름 뒤에 붙는 로마 숫자 (2 → II, 14 → XIV)
String roman(int n) {
  const v = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
  const r = [
    'M',
    'CM',
    'D',
    'CD',
    'C',
    'XC',
    'L',
    'XL',
    'X',
    'IX',
    'V',
    'IV',
    'I',
  ];
  final b = StringBuffer();
  for (var i = 0; i < v.length; i++) {
    while (n >= v[i]) {
      b.write(r[i]);
      n -= v[i];
    }
  }
  return b.toString();
}

JobResult runJob(Job job) {
  final spec = job.spec, defaults = job.defaults;
  final (:art, warnings: imported) = readPngArt(
    job.artPath,
    spec.art,
    defaults.maxColors,
  );
  final warnings = [...imported];
  // {...DEFAULT_OPTIONS, ...defaults.options, ...spec.options}
  final options = (spec.options ?? const PartialOptions()).over(
    defaults.options,
  );
  final tried = <Tried>[];
  ({GenReport r, int seed, double d})? best;
  final lo = spec.winRange.$1, hi = spec.winRange.$2;
  final target = spec.targetWinRate;
  final want = spec.difficulty == null
      ? null
      : Difficulty.parse(spec.difficulty!);
  // 등급을 지정한 레벨: 시드를 다 써도 그 등급이 안 나오면 조건을 조금씩 조이거나(너무 쉬움) 풀어서(너무 어려움) 다시
  var dropMin = spec.dropMin, dropMax = spec.dropMax, lanes = spec.lanes;
  var starts = spec.starts;
  var displacements = spec.displacements ?? defaults.displacements;
  ({GenReport r, int seed, double d})? hit;
  for (var round = 0; round < (want == null ? 1 : 4) && hit == null; round++) {
    if (round > 0 && best != null) {
      final tooEasy = best.r.randomWinRate > target;
      // 물방울 크기를 비율로 조인다(풀어 준다): 큰 물방울(두 자리 수)에서도 한 번에 충분히 움직이게
      if (tooEasy) {
        starts = 1;
        lanes = math.min(4, lanes + 1);
        dropMax = math.max(dropMin + 1, (dropMax * 0.7).floor());
        dropMin = math.max(1, (dropMin * 0.7).floor());
        displacements = math.max(displacements, 600);
      } else {
        dropMin = (dropMin * 1.3).ceil();
        dropMax = (dropMax * 1.3).ceil();
        starts += 1;
        lanes = math.max(3, lanes - 1);
      }
    }
    for (final seed in spec.seeds) {
      final sw = Stopwatch()..start();
      try {
        final r = generate(
          art,
          GenParams(
            seed: seed + round * 1000,
            starts: starts,
            dropMin: dropMin,
            dropMax: dropMax,
            lanes: lanes,
            scale: spec.scale ?? 1,
            displacements: displacements,
            targetWinRate: target.toDouble(),
            options: options,
            slotCount: defaults.slotCount,
            maxSolverNodes: defaults.maxSolverNodes,
          ),
        );
        tried.add(
          Tried(
            seed + round * 1000,
            r.randomWinRate,
            r.score,
            sw.elapsedMilliseconds,
          ),
        );
        // 구간 안이면 목표와의 거리, 밖이면 구간까지의 거리 + 1 (구간 안을 항상 우선)
        final w = r.randomWinRate;
        final inRange = w >= lo && w <= hi;
        final double d = inRange
            ? (w - target).abs().toDouble()
            : 1 + math.min((w - lo).abs(), (w - hi).abs()).toDouble();
        if (best == null || d < best.d) {
          best = (r: r, seed: seed + round * 1000, d: d);
        }
        if (want != null) {
          if (r.difficulty == want) {
            if (hit == null || d < hit.d) {
              hit = (r: r, seed: seed + round * 1000, d: d);
            }
            if ((w - target).abs() < 0.05) break;
          }
          continue;
        }
        if (inRange && (w - target).abs() < 0.05) break; // 충분히 가까우면 그만
      } catch (e) {
        tried.add(
          Tried(
            seed + round * 1000,
            double.nan,
            double.nan,
            sw.elapsedMilliseconds,
            '$e',
          ),
        );
      }
    }
  }
  if (want != null) {
    if (hit != null) {
      best = hit;
    } else if (best != null) {
      warnings.add(
        '${spec.art}${spec.variant != null ? '-${spec.variant}' : ''}: '
        '${want.name} 을(를) 만들지 못함 → ${best.r.difficulty.name} (win ${best.r.randomWinRate})',
      );
    }
  }
  if (best == null) throw StateError('${spec.art}: no seed produced a level');
  final report = best.r, raw = report.level;
  final v2 = spec.variant != null && spec.variant! > 1;
  final id = v2 ? '${spec.art}-${spec.variant}' : spec.art;
  final suffix = v2 ? ' ${roman(spec.variant!)}' : '';
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
