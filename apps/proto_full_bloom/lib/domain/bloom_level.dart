import 'bloom_color.dart';
import 'cell_pos.dart';
import 'watering_can.dart';

/// 물뿌리개 하나의 정의 (레벨 데이터). 플레이 중 상태는 [WateringCan]이 든다.
typedef CanSpec = ({BloomColor color, int count});

/// 레벨 하나의 정의. 불변이다 — 플레이 상태는 BloomBoard가 따로 든다.
final class BloomLevel {
  BloomLevel({
    required this.name,
    required this.columns,
    required this.rows,
    required this.colors,
    required this.startPoints,
    required this.lanes,
    this.activeSlotCount = 2,
    this.hiddenCans = const {},
  }) {
    _validate();
  }

  final String name;
  final int columns;
  final int rows;

  /// 칸 색 배치. **키가 없는 좌표는 빈칸**이다 (그림의 바깥).
  final Map<CellPos, BloomColor> colors;

  /// 발아로 시작하는 칸들. 보드 큐의 초기 내용이 된다.
  final List<CellPos> startPoints;

  /// 물뿌리개 레인들. **각 레인은 맨 앞만 꺼낼 수 있는 줄**이고,
  /// 어떤 색을 어느 레인에 얼마나 깊이 묻는가가 레벨 디자인이다 (기획서 §8·§9).
  final List<List<CanSpec>> lanes;

  /// 활성화 슬롯 수. 꺼낸 물뿌리개는 소진될 때까지 여기 주차된다.
  final int activeSlotCount;

  /// 숨김 물뿌리개의 위치들 — (레인 번호, 레인 안 인덱스).
  ///
  /// **기본은 전부 공개다** (모든 레인의 색·개수가 보인다). 여기 적힌 것만
  /// **레인 맨 앞에 올 때까지** 가려진다 — 난이도 요소이고, 나중에 "맨 앞에
  /// 올 때 드러나는" 다른 요소들도 이 자리에 같은 방식으로 붙는다.
  final Set<(int, int)> hiddenCans;

  int get cellCount => colors.length;

  /// 모든 레인의 물뿌리개를 펼친 목록.
  Iterable<CanSpec> get allCans => lanes.expand((lane) => lane);

  /// 색깔별 칸 수.
  Map<BloomColor, int> get cellCountByColor {
    final counts = <BloomColor, int>{};
    for (final color in colors.values) {
      counts[color] = (counts[color] ?? 0) + 1;
    }
    return counts;
  }

  /// 색깔별 물뿌리개 횟수 합.
  Map<BloomColor, int> get waterCountByColor {
    final counts = <BloomColor, int>{};
    for (final can in allCans) {
      counts[can.color] = (counts[can.color] ?? 0) + can.count;
    }
    return counts;
  }

  /// 색깔별 물 횟수 = 색깔별 칸 수 불변식 검사.
  ///
  /// 물 한 번이 정확히 그 색 한 칸을 피우므로 산수로 강제되고, 어긋나면
  /// 레벨이 절대 풀리지 않는다. 플레이 중에 발견하면 늦으므로 생성 시점에
  /// 던진다.
  void _validate() {
    if (columns < 1 || rows < 1) {
      throw ArgumentError('격자 크기가 잘못됐다: $columns x $rows');
    }
    for (final pos in colors.keys) {
      if (pos.col < 0 || pos.col >= columns || pos.row < 0 || pos.row >= rows) {
        throw ArgumentError('격자 밖의 칸이 있다: $pos ($name)');
      }
    }
    if (startPoints.isEmpty) {
      throw ArgumentError('시작 지점이 없다 ($name)');
    }
    for (final start in startPoints) {
      if (!colors.containsKey(start)) {
        throw ArgumentError('시작 지점이 빈칸이다: $start ($name)');
      }
    }
    if (startPoints.toSet().length != startPoints.length) {
      throw ArgumentError('시작 지점이 중복됐다 ($name)');
    }
    if (activeSlotCount < 1) {
      throw ArgumentError.value(
        activeSlotCount,
        'activeSlotCount',
        '1 이상이어야 한다',
      );
    }
    if (lanes.isEmpty || lanes.any((lane) => lane.isEmpty)) {
      throw ArgumentError('빈 레인이 있다 ($name) — 레인은 최소 1개의 물뿌리개를 갖는다');
    }

    for (final (lane, index) in hiddenCans) {
      if (lane < 0 ||
          lane >= lanes.length ||
          index < 0 ||
          index >= lanes[lane].length) {
        throw ArgumentError('숨김 위치가 레인 밖이다: ($lane, $index) ($name)');
      }
    }

    final cells = cellCountByColor;
    final water = waterCountByColor;
    if (cells.length != water.length ||
        !cells.keys.every((color) => water[color] == cells[color])) {
      throw ArgumentError(
        '색깔별 물뿌리개 횟수가 칸 수와 맞지 않는다 ($name).\n'
        '  칸:       $cells\n'
        '  물뿌리개: $water\n'
        '  색마다 정확히 일치해야 한다.',
      );
    }
  }

  @override
  String toString() => 'BloomLevel($name, $columns x $rows, $cellCount칸)';
}
