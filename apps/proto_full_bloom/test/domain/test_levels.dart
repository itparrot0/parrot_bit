import 'package:proto_full_bloom/domain/domain.dart';

/// [columns]x[rows] 전체를 한 색으로 채운 레벨. [canCounts]의 각 횟수가
/// **레인 하나**가 된다 (앞이 곧 전부라 꺼내는 순서만 남는다).
///
/// 색이 하나면 큐의 모든 칸이 대상이라 색 매칭이 끼어들지 않는다 —
/// 큐 순서만 보고 싶을 때 쓴다.
BloomLevel monoLevel({
  required CellPos start,
  required List<int> canCounts,
  int columns = 5,
  int rows = 5,
  int activeSlotCount = 2,
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
  lanes: [
    for (final count in canCounts) [(color: BloomColor.red, count: count)],
  ],
  activeSlotCount: activeSlotCount,
);

/// 한 줄 보드 레벨. `cells`를 왼쪽부터 늘어놓고 맨 왼쪽에서 시작한다.
BloomLevel lineLevel({
  required String name,
  required List<BloomColor> cells,
  required List<List<CanSpec>> lanes,
  int activeSlotCount = 2,
}) => BloomLevel(
  name: name,
  columns: cells.length,
  rows: 1,
  colors: {
    for (var col = 0; col < cells.length; col++) (col: col, row: 0): cells[col],
  },
  startPoints: const [(col: 0, row: 0)],
  lanes: lanes,
  activeSlotCount: activeSlotCount,
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
    lanes: const [
      [(color: BloomColor.red, count: 3)],
    ],
  );

  /// 빨강 x3이 **그 순간 닿을 수 있는 빨강 2칸**만 피우고 x1을 든 채
  /// 주차되는 레벨.
  ///
  /// `빨 빨 파 빨` — 세 번째 빨강은 파랑을 지나야 깨어난다. 주차된 x1은
  /// 파랑이 핀 뒤 재개할 수 있다.
  static BloomLevel get stalls => lineLevel(
    name: '주차',
    cells: const [
      BloomColor.red,
      BloomColor.red,
      BloomColor.blue,
      BloomColor.red,
    ],
    lanes: const [
      [(color: BloomColor.red, count: 3)],
      [(color: BloomColor.blue, count: 1)],
    ],
  );

  /// 교착 분기가 있지만 풀리기도 하는 레벨.
  ///
  /// `빨 빨 파 파`, 활성화 슬롯 1개.
  /// 정답: R1 → R1 → B1 → B1 (레인 3을 두 번 파고 파랑으로).
  /// 함정: 파랑을 먼저 꺼내면 대상이 없어 주차되고, 슬롯 1개가 막혀
  /// **둘 수 있는 수가 사라진다** = 교착.
  static BloomLevel get deadlockable => lineLevel(
    name: '교착 가능',
    cells: const [
      BloomColor.red,
      BloomColor.red,
      BloomColor.blue,
      BloomColor.blue,
    ],
    lanes: const [
      [(color: BloomColor.blue, count: 1)],
      [(color: BloomColor.blue, count: 1)],
      [(color: BloomColor.red, count: 1), (color: BloomColor.red, count: 1)],
    ],
    activeSlotCount: 1,
  );

  /// 절대 풀리지 않는 레벨.
  ///
  /// `빨 빨 파 파`, 레인 1줄 `파→파→빨→빨`, 슬롯 1개. 첫 수가 파랑 꺼내기뿐이고
  /// 그 즉시 주차돼 슬롯이 막힌다. 정확 일치는 지켜도 순서가 막으면 못 푼다 —
  /// 생성기가 이런 배치를 걸러내야 하는 이유다.
  static BloomLevel get unsolvable => lineLevel(
    name: '불가능',
    cells: const [
      BloomColor.red,
      BloomColor.red,
      BloomColor.blue,
      BloomColor.blue,
    ],
    lanes: const [
      [
        (color: BloomColor.blue, count: 1),
        (color: BloomColor.blue, count: 1),
        (color: BloomColor.red, count: 1),
        (color: BloomColor.red, count: 1),
      ],
    ],
    activeSlotCount: 1,
  );
}
