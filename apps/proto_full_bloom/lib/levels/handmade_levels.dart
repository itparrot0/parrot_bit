import '../domain/domain.dart';

/// 손으로 만든 검증용 레벨들.
///
/// **생성기보다 먼저 이것으로 재미를 본다** (PRD §9.1) — 손으로 만든 레벨에서
/// 재미가 안 나오면 생성기는 의미가 없다.
///
/// 모든 레벨은 [BloomLevel] 생성자가 §3.7 불변식(색깔별 물 횟수 = 칸 수)을
/// 검사하고, 테스트가 솔버로 풀림까지 확인한다.
abstract final class HandmadeLevels {
  static List<BloomLevel> get all => [tutorial, cross, split, flower];

  /// 1. 한 가지 색. 큐가 어떻게 뻗는지 보는 것이 전부다.
  ///
  /// 색이 하나면 큐의 모든 칸이 대상이라 교착이 없다 — 규칙을 익히는 판.
  static BloomLevel get tutorial => BloomLevel(
    name: '튜토리얼',
    columns: 3,
    rows: 3,
    colors: {
      for (var row = 0; row < 3; row++)
        for (var col = 0; col < 3; col++) (col: col, row: row): BloomColor.red,
    },
    startPoints: const [(col: 1, row: 1)],
    cans: const [
      (color: BloomColor.red, count: 1),
      (color: BloomColor.red, count: 4),
      (color: BloomColor.red, count: 4),
    ],
  );

  /// 2. 십자. 두 색이 처음 만나고, **파랑은 첫 수에 쓸 수 없다.**
  ///
  /// 시작 지점이 빨강이라 큐에 파랑이 없다 — 색이 슬롯을 막는다는 것을
  /// 가장 작은 판으로 보여준다 (PRD §3.5).
  static BloomLevel get cross => BloomLevel(
    name: '십자',
    columns: 5,
    rows: 5,
    colors: const {
      // 세로 기둥 — 빨강 5칸
      (col: 2, row: 0): BloomColor.red,
      (col: 2, row: 1): BloomColor.red,
      (col: 2, row: 2): BloomColor.red,
      (col: 2, row: 3): BloomColor.red,
      (col: 2, row: 4): BloomColor.red,
      // 가로 팔 — 파랑 4칸
      (col: 0, row: 2): BloomColor.blue,
      (col: 1, row: 2): BloomColor.blue,
      (col: 3, row: 2): BloomColor.blue,
      (col: 4, row: 2): BloomColor.blue,
    },
    startPoints: const [(col: 2, row: 2)],
    cans: const [
      (color: BloomColor.red, count: 2),
      (color: BloomColor.blue, count: 4),
      (color: BloomColor.red, count: 3),
    ],
  );

  /// 3. 좌우 분단. 큰 물뿌리개가 슬롯을 오래 막는 느낌을 보는 판.
  static BloomLevel get split => BloomLevel(
    name: '분단',
    columns: 4,
    rows: 4,
    colors: {
      for (var row = 0; row < 4; row++)
        for (var col = 0; col < 4; col++)
          (col: col, row: row): col < 2 ? BloomColor.red : BloomColor.blue,
    },
    startPoints: const [(col: 1, row: 1)],
    cans: const [
      (color: BloomColor.red, count: 3),
      (color: BloomColor.blue, count: 2),
      (color: BloomColor.red, count: 5),
      (color: BloomColor.blue, count: 6),
    ],
  );

  /// 4. 꽃. 세 색 + 시작 지점 2개.
  static BloomLevel get flower => BloomLevel(
    name: '꽃',
    columns: 5,
    rows: 5,
    colors: const {
      // 꽃잎 — 노랑 8칸
      (col: 1, row: 0): BloomColor.yellow,
      (col: 2, row: 0): BloomColor.yellow,
      (col: 3, row: 0): BloomColor.yellow,
      (col: 0, row: 1): BloomColor.yellow,
      (col: 4, row: 1): BloomColor.yellow,
      (col: 0, row: 2): BloomColor.yellow,
      (col: 4, row: 2): BloomColor.yellow,
      (col: 2, row: 4): BloomColor.yellow,
      // 꽃심 — 빨강 4칸
      (col: 1, row: 1): BloomColor.red,
      (col: 2, row: 1): BloomColor.red,
      (col: 3, row: 1): BloomColor.red,
      (col: 2, row: 2): BloomColor.red,
      // 줄기 — 초록 3칸
      (col: 1, row: 2): BloomColor.green,
      (col: 3, row: 2): BloomColor.green,
      (col: 2, row: 3): BloomColor.green,
    },
    startPoints: const [(col: 2, row: 1), (col: 2, row: 3)],
    cans: const [
      (color: BloomColor.red, count: 2),
      (color: BloomColor.green, count: 3),
      (color: BloomColor.yellow, count: 5),
      (color: BloomColor.red, count: 2),
      (color: BloomColor.yellow, count: 3),
    ],
  );
}
