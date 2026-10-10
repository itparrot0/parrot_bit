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
    required this.cans,
    this.slotCount = 3,
  }) {
    _validate();
  }

  final String name;
  final int columns;
  final int rows;

  /// 칸 색 배치. **키가 없는 좌표는 빈칸**이다 (그림의 바깥).
  final Map<CellPos, BloomColor> colors;

  /// 발아로 시작하는 칸들. 큐의 초기 내용이 된다 (PRD §3.3).
  final List<CellPos> startPoints;

  /// 대기열 순서. 앞에서부터 슬롯에 올라간다.
  final List<CanSpec> cans;

  /// 활성화 슬롯 수 (PRD §3.6).
  final int slotCount;

  int get cellCount => colors.length;

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
    for (final can in cans) {
      counts[can.color] = (counts[can.color] ?? 0) + can.count;
    }
    return counts;
  }

  List<WateringCan> createCans() => [
    for (final spec in cans) WateringCan(color: spec.color, count: spec.count),
  ];

  /// PRD §3.7 불변식 검사.
  ///
  /// **색깔별 물뿌리개 횟수 합 = 색깔별 칸 수**여야 한다. 물 한 번이 정확히
  /// 그 색 한 칸을 피우므로 산수로 강제되고, 어긋나면 레벨이 절대 풀리지
  /// 않는다. 플레이 중에 발견하면 늦으므로 생성 시점에 던진다 (PRD §10).
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
    if (slotCount < 1) {
      throw ArgumentError.value(slotCount, 'slotCount', '1 이상이어야 한다');
    }

    final cells = cellCountByColor;
    final water = waterCountByColor;
    if (cells.length != water.length ||
        !cells.keys.every((color) => water[color] == cells[color])) {
      throw ArgumentError(
        '색깔별 물뿌리개 횟수가 칸 수와 맞지 않는다 ($name).\n'
        '  칸:       $cells\n'
        '  물뿌리개: $water\n'
        '  PRD §3.7 — 색마다 정확히 일치해야 한다.',
      );
    }
  }

  @override
  String toString() => 'BloomLevel($name, $columns x $rows, $cellCount칸)';
}
