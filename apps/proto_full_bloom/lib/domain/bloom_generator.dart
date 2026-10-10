import 'dart:math';

import 'bloom_color.dart';
import 'bloom_level.dart';
import 'bloom_solver.dart';
import 'cell_pos.dart';

/// 생성 결과 — 레벨과 그 난이도 지표.
typedef GeneratedLevel = ({BloomLevel level, SolveReport report});

/// 색이 입혀진 그림 — 레벨의 "미술" 절반.
///
/// 레인·물뿌리개는 여기 없다. **그림 하나에 레인 시드만 바꿔 끼우면 같은
/// 그림의 레벨이 계속 나온다** ([BloomGenerator.generateFromPicture]).
typedef BloomPicture = ({
  int columns,
  int rows,
  Map<CellPos, BloomColor> colors,
});

/// 난이도 프리셋 — 기획서 §13의 등급을 생성 파라미터로 옮긴 것.
///
/// 색 수가 1차 다이얼이다: 색이 늘수록 같은 색 발아가 귀해져 순서 의존이
/// 커진다. 물뿌리개 최소 크기가 2차 다이얼: 큰 덩어리는 초반에 주차로 슬롯을
/// 오래 막는다. 숫자는 전부 첫 값이고 플레이로 교정한다.
enum BloomDifficulty {
  easy(colorCount: 2, minCanSize: 1, maxCanSize: 3, activeSlotCount: 4),
  normal(colorCount: 3, minCanSize: 1, maxCanSize: 4, activeSlotCount: 4),
  hard(colorCount: 4, minCanSize: 2, maxCanSize: 5, activeSlotCount: 3),
  expert(colorCount: 5, minCanSize: 3, maxCanSize: 6, activeSlotCount: 3);

  const BloomDifficulty({
    required this.colorCount,
    required this.minCanSize,
    required this.maxCanSize,
    required this.activeSlotCount,
  });

  final int colorCount;
  final int minCanSize;
  final int maxCanSize;
  final int activeSlotCount;
}

/// 랜덤 레벨 생성기 — **그림 먼저, 레인은 그 다음**.
///
/// 파이프라인이 두 단계로 갈라져 있다:
///
/// 1. [drawPicture] — 실루엣 위에 색을 칠해 **그림**을 만든다 (색 수 =
///    난이도). 프로그램이 그리든 사람이 [parsePicture]로 직접 그리든,
///    결과물은 같은 [BloomPicture]다.
/// 2. [generateFromPicture] — 그림은 **고정**하고 시작 지점·물뿌리개
///    분할·레인 배치만 생성한 뒤 솔버로 풀림을 검증한다. 정확 일치는
///    색깔별 칸 수 역산이 구조적으로 보장한다.
///
/// 그래서 그림 라이브러리 × 레인 시드가 곧 무한 레벨이다. [generate]는
/// 두 단계를 한 번에 돌리는 편의 함수다.
///
/// 같은 시드는 항상 같은 결과를 만든다 — 재현·공유·버그 리포트용.
abstract final class BloomGenerator {
  /// 내장 그림 실루엣 — `#`이 칸, `.`이 빈칸이다.
  ///
  /// **4방향으로 연결돼 있어야 한다** (끊기면 개화가 건너갈 수 없다).
  /// 새 실루엣은 여기 추가한다. 색까지 직접 정한 그림은 [parsePicture]의
  /// 색 문자(R/B/Y/G/P)로 그린다.
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

  /// 색 문자 ↔ 색. 그림을 텍스트로 그리고 저장할 때 쓴다.
  static const Map<String, BloomColor> colorLetters = {
    'R': BloomColor.red,
    'B': BloomColor.blue,
    'Y': BloomColor.yellow,
    'G': BloomColor.green,
    'P': BloomColor.purple,
  };

  static final Map<BloomColor, String> _letterOf = {
    for (final entry in colorLetters.entries) entry.value: entry.key,
  };

  /// [generate]가 그림을 바꿔가며 재시도하는 횟수.
  static const int _pictureAttempts = 12;

  /// [generateFromPicture]의 (시작 지점 × 분할) 재시도 횟수.
  static const int _startAttempts = 6;
  static const int _laneAttemptsPerStart = 6;

  /// 생성 중 솔버 탐색 상한. 넘으면 그 배치는 버린다.
  static const int _solverBudget = 30000;

  // ── 1단계: 그림 ───────────────────────────────────────────────────────

  /// 실루엣 위에 색을 칠해 그림을 그린다. 같은 시드는 같은 그림이다.
  ///
  /// [shape]가 null이면 [shapes]에서 시드로 고른다. [colorCount]가 난이도의
  /// 1차 다이얼이다 (기획서 §13: Easy 2~3색 … Expert 5색+).
  static BloomPicture drawPicture({
    required int seed,
    String? shape,
    int colorCount = 3,
  }) {
    final random = Random(seed);
    final mask = _parseShape(shape ?? shapes[random.nextInt(shapes.length)]);
    return (
      columns: mask.columns,
      rows: mask.rows,
      colors: _growRegions(random, mask.cells, colorCount),
    );
  }

  /// 색 문자 도트아트를 그림으로 푼다 — **사람이 색까지 정해 그리는 길**.
  ///
  /// `.`은 빈칸, R/B/Y/G/P는 그 색 칸이다 (소문자 허용). 예:
  ///
  /// ```text
  /// .RR.
  /// RYYB
  /// .BB.
  /// ```
  static BloomPicture parsePicture(String art) {
    final lines = [
      for (final line in art.split('\n'))
        if (line.trim().isNotEmpty) line.trimRight(),
    ];
    if (lines.isEmpty) {
      throw ArgumentError('그림이 비어 있다');
    }
    final columns = lines.map((line) => line.length).reduce(max);
    final colors = <CellPos, BloomColor>{};
    for (var row = 0; row < lines.length; row++) {
      for (var col = 0; col < lines[row].length; col++) {
        final letter = lines[row][col];
        if (letter == '.') {
          continue;
        }
        final color = colorLetters[letter.toUpperCase()];
        if (color == null) {
          throw ArgumentError(
            "모르는 색 문자 '$letter' — 쓸 수 있는 것: ${colorLetters.keys.join(' ')} .",
          );
        }
        colors[(col: col, row: row)] = color;
      }
    }
    if (colors.isEmpty) {
      throw ArgumentError('그림에 칸이 없다');
    }
    _assertConnected(colors.keys.toList());
    return (columns: columns, rows: lines.length, colors: colors);
  }

  /// 그림을 색 문자 도트아트로 되돌린다 — 프로그램이 그린 그림을 저장해
  /// 라이브러리에 넣거나 손으로 다듬을 때 쓴다. [parsePicture]와 왕복된다.
  static String renderPicture(BloomPicture picture) {
    final buffer = StringBuffer();
    for (var row = 0; row < picture.rows; row++) {
      for (var col = 0; col < picture.columns; col++) {
        final color = picture.colors[(col: col, row: row)];
        buffer.write(color == null ? '.' : _letterOf[color]);
      }
      if (row < picture.rows - 1) {
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  // ── 2단계: 레인 ───────────────────────────────────────────────────────

  /// **그림은 고정하고** 시작 지점·물뿌리개 분할·레인 배치만 생성한다.
  ///
  /// 같은 그림에 시드만 바꾸면 미술은 같고 퍼즐만 다른 레벨이 계속 나온다.
  /// 솔버가 풀림을 검증하고, 못 찾으면 시작 지점과 분할을 바꿔 재시도한다.
  static GeneratedLevel generateFromPicture({
    required int seed,
    required BloomPicture picture,
    String? name,
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
    // 손으로 만든 그림도 받으므로 연결성을 다시 확인한다.
    final cells = picture.colors.keys.toList()
      ..sort(
        (a, b) => a.row != b.row ? a.row - b.row : a.col - b.col,
      ); // 행 우선 — Map 순서에 기대지 않아야 시드가 결정적이다.
    _assertConnected(cells);

    final random = Random(seed);
    for (var startTry = 0; startTry < _startAttempts; startTry++) {
      final start = cells[random.nextInt(cells.length)];

      for (var laneTry = 0; laneTry < _laneAttemptsPerStart; laneTry++) {
        final lanes = _dealLanes(
          _splitCans(random, picture.colors, minCanSize, maxCanSize),
          laneCount,
        );
        final level = BloomLevel(
          name: name ?? '그림 #$seed',
          columns: picture.columns,
          rows: picture.rows,
          colors: picture.colors,
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
    throw StateError('이 그림으로 풀리는 배치를 못 찾았다 (seed $seed)');
  }

  // ── 편의 함수 ─────────────────────────────────────────────────────────

  /// 두 단계를 한 번에: 그림을 그리고 그 위에 레인을 생성한다.
  ///
  /// 한 그림이 끝내 안 풀리면 시드를 비켜 새 그림으로 재시도한다.
  static GeneratedLevel generate({
    required int seed,
    String? shape,
    int colorCount = 3,
    int laneCount = 3,
    int activeSlotCount = 4,
    int minCanSize = 1,
    int maxCanSize = 4,
  }) {
    if (minCanSize < 1 || minCanSize > maxCanSize) {
      throw ArgumentError('물뿌리개 횟수 범위가 잘못됐다: $minCanSize..$maxCanSize');
    }
    for (var attempt = 0; attempt < _pictureAttempts; attempt++) {
      final subSeed = seed + attempt * 7919;
      final picture = drawPicture(
        seed: subSeed,
        shape: shape,
        colorCount: colorCount,
      );
      try {
        return generateFromPicture(
          seed: subSeed,
          picture: picture,
          name: '랜덤 #$seed',
          laneCount: laneCount,
          activeSlotCount: activeSlotCount,
          minCanSize: minCanSize,
          maxCanSize: maxCanSize,
        );
      } on StateError {
        continue; // 이 그림은 버리고 새로 그린다.
      }
    }
    throw StateError('랜덤 레벨 생성 실패 (seed $seed) — 파라미터가 너무 빡빡하다');
  }

  /// 난이도 프리셋으로 생성한다 (기획서 §13).
  static GeneratedLevel generateAtDifficulty({
    required int seed,
    required BloomDifficulty difficulty,
    String? shape,
  }) => generate(
    seed: seed,
    shape: shape,
    colorCount: difficulty.colorCount,
    activeSlotCount: difficulty.activeSlotCount,
    minCanSize: difficulty.minCanSize,
    maxCanSize: difficulty.maxCanSize,
  );

  // ── 내부 ──────────────────────────────────────────────────────────────

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
    _assertConnected(cells);
    return (columns: columns, rows: lines.length, cells: cells);
  }

  /// 4방향 연결성 검사 — 끊긴 그림은 개화가 건너갈 수 없어 절대 풀리지
  /// 않는다. 솔버 재시도로 낭비하지 말고 입구에서 바로 거부한다.
  static void _assertConnected(List<CellPos> cells) {
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
