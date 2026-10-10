import 'dart:math';

import 'bloom_color.dart';
import 'bloom_level.dart';
import 'bloom_solver.dart';
import 'cell_pos.dart';

/// 생성 결과 — 레벨과 그 난이도 지표.
typedef GeneratedLevel = ({BloomLevel level, SolveReport report});

/// 랜덤 레벨 생성기.
///
/// 단순 변형이다: 색을 칠하고 → 물뿌리개를 **색깔별 칸 수에서 역산**하고 →
/// 레인에 나눠 담은 뒤 → **솔버로 풀리는지 확인**하고, 안 풀리면 분할부터
/// 다시 돌린다. 정확 일치는 역산이 구조적으로 보장하므로 검증할 것은
/// 교착 회피(풀림) 하나다.
///
/// 같은 [seed]는 항상 같은 레벨을 만든다 — 재현·공유·버그 리포트용.
///
/// 기획서 §14의 역생성(원하는 연쇄를 먼저 설계)은 이후 단계다. 이 변형은
/// 재미 검증에 쓸 레벨을 빠르게 뽑는 도구다.
abstract final class BloomGenerator {
  /// 생성 실패로 판단하기 전까지의 (색칠 × 분할) 재시도 횟수.
  static const int _colorAttempts = 12;
  static const int _laneAttemptsPerColoring = 6;

  /// 생성 중 솔버 탐색 상한. 넘으면 그 배치는 버린다.
  static const int _solverBudget = 30000;

  static GeneratedLevel generate({
    required int seed,
    int columns = 5,
    int rows = 6,
    int colorCount = 3,
    int laneCount = 3,
    int activeSlotCount = 2,
    int maxCanSize = 4,
  }) {
    final random = Random(seed);

    for (var attempt = 0; attempt < _colorAttempts; attempt++) {
      final colors = _growRegions(random, columns, rows, colorCount);
      final start = colors.keys.elementAt(random.nextInt(colors.length));

      for (var laneTry = 0; laneTry < _laneAttemptsPerColoring; laneTry++) {
        final lanes = _dealLanes(
          random,
          _splitCans(random, colors, maxCanSize),
          laneCount,
        );
        final level = BloomLevel(
          name: '랜덤 #$seed',
          columns: columns,
          rows: rows,
          colors: colors,
          startPoints: [start],
          lanes: lanes,
          activeSlotCount: activeSlotCount,
        );

        final report = BloomSolver.solve(level, maxStates: _solverBudget);
        if (report.solution != null) {
          return (level: level, report: report);
        }
      }
    }
    throw StateError('랜덤 레벨 생성 실패 (seed $seed) — 파라미터가 너무 빡빡하다');
  }

  /// 색 영역 키우기 — 색마다 씨앗 칸을 하나 심고, 색칠된 이웃이 있는 칸을
  /// 하나씩 골라 그 이웃의 색으로 칠한다. 노이즈가 아니라 덩어리가 나온다.
  static Map<CellPos, BloomColor> _growRegions(
    Random random,
    int columns,
    int rows,
    int colorCount,
  ) {
    final all = [
      for (var row = 0; row < rows; row++)
        for (var col = 0; col < columns; col++) (col: col, row: row),
    ]..shuffle(random);

    final palette = BloomColor.values.take(colorCount).toList();
    final colors = <CellPos, BloomColor>{
      for (var index = 0; index < colorCount; index++)
        all[index]: palette[index],
    };

    while (colors.length < all.length) {
      // 색칠된 이웃이 있는 미색칠 칸 중 하나를 무작위로 집는다.
      final candidates = [
        for (final pos in all)
          if (!colors.containsKey(pos) &&
              neighborsInOrder(pos).any(colors.containsKey))
            pos,
      ];
      final pick = candidates[random.nextInt(candidates.length)];
      final coloredNeighbors = [
        for (final neighbor in neighborsInOrder(pick))
          if (colors.containsKey(neighbor)) colors[neighbor]!,
      ];
      colors[pick] = coloredNeighbors[random.nextInt(coloredNeighbors.length)];
    }
    return colors;
  }

  /// 색깔별 칸 수를 세어 물뿌리개 횟수로 쪼갠다 — 정확 일치의 역산.
  static List<CanSpec> _splitCans(
    Random random,
    Map<CellPos, BloomColor> colors,
    int maxCanSize,
  ) {
    final counts = <BloomColor, int>{};
    for (final color in colors.values) {
      counts[color] = (counts[color] ?? 0) + 1;
    }

    final cans = <CanSpec>[];
    counts.forEach((color, total) {
      var left = total;
      while (left > 0) {
        final size = 1 + random.nextInt(min(maxCanSize, left));
        cans.add((color: color, count: size));
        left -= size;
      }
    });
    return cans..shuffle(random);
  }

  /// 물뿌리개들을 레인에 돌아가며 나눠 담는다.
  static List<List<CanSpec>> _dealLanes(
    Random random,
    List<CanSpec> cans,
    int laneCount,
  ) {
    final dealt = List.generate(
      min(laneCount, cans.length),
      (_) => <CanSpec>[],
    );
    for (var index = 0; index < cans.length; index++) {
      dealt[index % dealt.length].add(cans[index]);
    }
    return dealt;
  }
}
