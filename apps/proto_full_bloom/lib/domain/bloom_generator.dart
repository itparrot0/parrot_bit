import 'dart:math';

import 'bloom_color.dart';
import 'bloom_level.dart';
import 'bloom_solver.dart';
import 'cell_pos.dart';

/// 생성 결과 — 레벨과 그 난이도 지표.
typedef GeneratedLevel = ({BloomLevel level, SolveReport report});

/// 랜덤 레벨 생성기.
///
/// 단순 변형이다: **그림 실루엣** 위에 색을 칠하고 → 물뿌리개를 **색깔별
/// 칸 수에서 역산**하고 → 레인에 나눠 담은 뒤 → **솔버로 풀리는지 확인**하고,
/// 안 풀리면 분할부터 다시 돌린다. 정확 일치는 역산이 구조적으로 보장하므로
/// 검증할 것은 교착 회피(풀림) 하나다.
///
/// 같은 [seed]는 항상 같은 레벨을 만든다 — 재현·공유·버그 리포트용.
///
/// 기획서 §14의 역생성(원하는 연쇄를 먼저 설계)은 이후 단계다. 이 변형은
/// 재미 검증에 쓸 레벨을 빠르게 뽑는 도구다.
abstract final class BloomGenerator {
  /// 내장 그림 실루엣 — `#`이 칸, `.`이 빈칸이다.
  ///
  /// **4방향으로 연결돼 있어야 한다** (끊기면 개화가 건너갈 수 없고,
  /// 색칠도 멈춰 생성이 실패한다). 새 그림은 여기 추가한다 — 사람이 만드는
  /// 유일한 재료다 (기획서 §14의 템플릿).
  static const List<String> shapes = [
    // 하트 (7x6, 27칸)
    '''
.##.##.
#######
#######
.#####.
..###..
...#...''',
    // 꽃 (7x8, 40칸)
    '''
..###..
.#####.
#######
#######
.#####.
..###..
...#...
...#...''',
    // 나비 (9x6, 40칸)
    '''
##.....##
###.#.###
#########
#########
###.#.###
##.....##''',
    // 다이아몬드 (9x9, 41칸)
    '''
....#....
...###...
..#####..
.#######.
#########
.#######.
..#####..
...###...
....#....''',
  ];

  /// 생성 실패로 판단하기 전까지의 (색칠 × 분할) 재시도 횟수.
  static const int _colorAttempts = 12;
  static const int _laneAttemptsPerColoring = 6;

  /// 생성 중 솔버 탐색 상한. 넘으면 그 배치는 버린다.
  static const int _solverBudget = 30000;

  static GeneratedLevel generate({
    required int seed,

    /// `#`/`.` 도트아트. null이면 [shapes]에서 시드로 고른다.
    String? shape,
    int colorCount = 3,
    int laneCount = 3,
    int activeSlotCount = 4,

    /// 물뿌리개 횟수 범위. 크게 잡을수록 덩어리가 커져 주차가 길어진다 —
    /// 난이도 다이얼이다. 레벨 데이터 자체에는 제한이 없다.
    int minCanSize = 1,
    int maxCanSize = 4,
  }) {
    if (minCanSize < 1 || minCanSize > maxCanSize) {
      throw ArgumentError('물뿌리개 횟수 범위가 잘못됐다: $minCanSize..$maxCanSize');
    }
    final random = Random(seed);
    final mask = _parseShape(shape ?? shapes[random.nextInt(shapes.length)]);

    for (var attempt = 0; attempt < _colorAttempts; attempt++) {
      final colors = _growRegions(random, mask.cells, colorCount);
      final start = mask.cells[random.nextInt(mask.cells.length)];

      for (var laneTry = 0; laneTry < _laneAttemptsPerColoring; laneTry++) {
        final lanes = _dealLanes(
          _splitCans(random, colors, minCanSize, maxCanSize),
          laneCount,
        );
        final level = BloomLevel(
          name: '랜덤 #$seed',
          columns: mask.columns,
          rows: mask.rows,
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

  /// `#`/`.` 도트아트를 칸 목록으로 푼다. 칸 순서는 행 우선으로 고정이라
  /// 시드 결정성이 유지된다.
  static ({int columns, int rows, List<CellPos> cells}) _parseShape(
    String shape,
  ) {
    final lines = [
      for (final line in shape.split('\n'))
        if (line.trim().isNotEmpty) line.trimRight(),
    ];
    if (lines.isEmpty) {
      throw ArgumentError('그림이 비어 있다');
    }
    final columns = lines.map((line) => line.length).reduce(max);
    final cells = <CellPos>[
      for (var row = 0; row < lines.length; row++)
        for (var col = 0; col < lines[row].length; col++)
          if (lines[row][col] == '#') (col: col, row: row),
    ];
    if (cells.isEmpty) {
      throw ArgumentError('그림에 칸이 없다');
    }

    // 4방향 연결성 검사 — 끊긴 그림은 개화가 건너갈 수 없어 절대 풀리지
    // 않는다. 솔버 재시도로 낭비하지 말고 여기서 바로 거부한다.
    final cellSet = cells.toSet();
    final reached = <CellPos>{cells.first};
    final frontier = <CellPos>[cells.first];
    while (frontier.isNotEmpty) {
      final pos = frontier.removeLast();
      for (final neighbor in neighborsInOrder(pos)) {
        if (cellSet.contains(neighbor) && reached.add(neighbor)) {
          frontier.add(neighbor);
        }
      }
    }
    if (reached.length != cells.length) {
      throw ArgumentError('그림이 4방향으로 연결돼 있지 않다');
    }

    return (columns: columns, rows: lines.length, cells: cells);
  }

  /// 색 영역 키우기 — 색마다 씨앗 칸을 하나 심고, 색칠된 이웃이 있는 칸을
  /// 하나씩 골라 그 이웃의 색으로 칠한다. 노이즈가 아니라 덩어리가 나온다.
  static Map<CellPos, BloomColor> _growRegions(
    Random random,
    List<CellPos> cells,
    int colorCount,
  ) {
    final all = List.of(cells)..shuffle(random);
    final palette = BloomColor.values
        .take(min(colorCount, all.length))
        .toList();
    final colors = <CellPos, BloomColor>{
      for (var index = 0; index < palette.length; index++)
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
      if (candidates.isEmpty) {
        throw ArgumentError('그림이 4방향으로 연결돼 있지 않다 — 색칠이 건너갈 수 없다');
      }
      final pick = candidates[random.nextInt(candidates.length)];
      final coloredNeighbors = [
        for (final neighbor in neighborsInOrder(pick))
          if (colors.containsKey(neighbor)) colors[neighbor]!,
      ];
      colors[pick] = coloredNeighbors[random.nextInt(coloredNeighbors.length)];
    }
    return colors;
  }

  /// 색깔별 칸 수를 세어 [minCanSize]..[maxCanSize] 조각으로 쪼갠다 —
  /// 정확 일치의 역산.
  ///
  /// 매 조각은 **남은 양도 범위를 지킬 수 있는 크기만** 고른다 (예: min 3에
  /// 남은 7 → 4를 집으면 나머지 3 ✓, 5를 집으면 나머지 2 ✗). 색의 총량이
  /// min보다 작아 범위를 지킬 수 없으면 그 색만 전부 한 조각으로 담는다 —
  /// 정확 일치가 범위보다 우선이다.
  static List<CanSpec> _splitCans(
    Random random,
    Map<CellPos, BloomColor> colors,
    int minCanSize,
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
        final sizes = [
          for (var size = minCanSize; size <= min(maxCanSize, left); size++)
            if (left - size == 0 || left - size >= minCanSize) size,
        ];
        final size = sizes.isEmpty ? left : sizes[random.nextInt(sizes.length)];
        cans.add((color: color, count: size));
        left -= size;
      }
    });
    return cans..shuffle(random);
  }

  /// 물뿌리개들을 레인에 돌아가며 나눠 담는다.
  static List<List<CanSpec>> _dealLanes(List<CanSpec> cans, int laneCount) {
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
