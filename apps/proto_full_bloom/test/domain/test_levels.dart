import 'package:proto_full_bloom/domain/domain.dart';

/// [columns]x[rows] 전체를 한 색으로 채운 레벨.
///
/// 색이 하나면 큐의 모든 칸이 대상이라 색 매칭이 끼어들지 않는다 —
/// 큐 순서만 보고 싶을 때 쓴다.
BloomLevel monoLevel({
  required CellPos start,
  required List<int> canCounts,
  int columns = 5,
  int rows = 5,
  int slotCount = 3,
}) => BloomLevel(
  name: '단색 ${columns}x$rows',
  columns: columns,
  rows: rows,
  colors: {
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < columns; col++)
        (col: col, row: row): BloomColor.red,
  },
  startPoints: [start],
  cans: [for (final count in canCounts) (color: BloomColor.red, count: count)],
  slotCount: slotCount,
);

/// 한 줄 레벨. `colors`를 왼쪽부터 늘어놓는다.
BloomLevel lineLevel({
  required String name,
  required List<BloomColor> cells,
  required List<CanSpec> cans,
  int slotCount = 3,
}) => BloomLevel(
  name: name,
  columns: cells.length,
  rows: 1,
  colors: {
    for (var col = 0; col < cells.length; col++) (col: col, row: 0): cells[col],
  },
  startPoints: const [(col: 0, row: 0)],
  cans: cans,
  slotCount: slotCount,
);

/// 테스트 전용 레벨들. 플레이용이 아니라 특정 상황을 만들기 위한 것이다.
abstract final class TestLevels {
  /// 시작 지점 2개의 큐 초기 순서를 보는 레벨.
  static BloomLevel get twoStarts => BloomLevel(
    name: '시작 둘',
    columns: 3,
    rows: 1,
    colors: const {
      (col: 0, row: 0): BloomColor.red,
      (col: 1, row: 0): BloomColor.red,
      (col: 2, row: 0): BloomColor.red,
    },
    startPoints: const [(col: 0, row: 0), (col: 2, row: 0)],
    cans: const [(color: BloomColor.red, count: 3)],
  );

  /// 빨강 x3을 쓰지만 **그 순간 닿을 수 있는 빨강이 2칸뿐**이라 1이 남는다.
  ///
  /// `빨 빨 파 빨` — 세 번째 빨강은 파랑을 지나야 깨어난다.
  /// §3.7은 지켜진다(빨강 3칸 = x3): 남은 1은 버려지지 않고 슬롯에서 기다린다.
  static BloomLevel get stalls => lineLevel(
    name: '멈춤',
    cells: const [
      BloomColor.red,
      BloomColor.red,
      BloomColor.blue,
      BloomColor.red,
    ],
    cans: const [
      (color: BloomColor.red, count: 3),
      (color: BloomColor.blue, count: 1),
    ],
  );

  /// 한 수 뒤에 교착이 나는 레벨.
  ///
  /// `빨 빨 파 파`, 슬롯 2개, 대기열 `빨1 → 파1 → 파1 → 빨1`.
  /// 첫 수는 빨강밖에 쓸 수 없고(큐에 빨강만 있다), 그걸 쓰면 슬롯이
  /// `파1·파1`로 채워지는데 큐에는 빨강만 남아 **모든 슬롯이 막힌다.**
  /// 남은 빨강은 파랑 뒤에 갇혀 영원히 올라오지 못한다 (PRD §3.8).
  static BloomLevel get deadlockable => lineLevel(
    name: '교착',
    cells: const [
      BloomColor.red,
      BloomColor.red,
      BloomColor.blue,
      BloomColor.blue,
    ],
    cans: const [
      (color: BloomColor.red, count: 1),
      (color: BloomColor.blue, count: 1),
      (color: BloomColor.blue, count: 1),
      (color: BloomColor.red, count: 1),
    ],
    slotCount: 2,
  );
}
