import 'dart:math';

/// 보드 좌표 (0-기준 열/행).
typedef CellPos = ({int col, int row});

/// 드롭 판정 결과.
enum MoveOutcome { merged, moved, rejected }

/// 머지 보드의 순수 Dart 모델. Flame 없이 단위 테스트한다.
///
/// 규칙은 docs/prd/proto_merge.md "게임 규칙 명세"를 따른다.
/// 렌더링 계층(MergeGame)은 이 모델의 판정 결과를 그리기만 한다.
class BoardModel {
  BoardModel({
    this.columns = 5,
    this.rows = 6,
    this.maxLevel = 5,
    Random? random,
  }) : _random = random ?? Random() {
    reset();
  }

  final int columns;
  final int rows;
  final int maxLevel;
  final Random _random;

  final Map<CellPos, int> _items = {};

  int mergeCount = 0;
  int highestLevel = 1;

  /// 생성기가 차지하는 고정 칸 (최하단 행 중앙).
  CellPos get generatorCell => (col: columns ~/ 2, row: rows - 1);

  /// 현재 배치된 아이템 (칸 → 레벨). 읽기 전용 뷰.
  Map<CellPos, int> get items => Map.unmodifiable(_items);

  bool isInside(CellPos pos) =>
      pos.col >= 0 && pos.col < columns && pos.row >= 0 && pos.row < rows;

  int? levelAt(CellPos pos) => _items[pos];

  /// 아이템을 놓을 수 있는 빈 칸인가 (보드 안 + 생성기 아님 + 비어 있음).
  bool isEmptyCell(CellPos pos) =>
      isInside(pos) && pos != generatorCell && !_items.containsKey(pos);

  List<CellPos> get emptyCells => [
        for (var row = 0; row < rows; row++)
          for (var col = 0; col < columns; col++)
            if (isEmptyCell((col: col, row: row))) (col: col, row: row),
      ];

  /// 초기 배치로 되돌린다: 레벨 1 아이템 2개 (첫 머지를 바로 체험하도록).
  void reset() {
    _items.clear();
    mergeCount = 0;
    highestLevel = 1;
    placeItem((col: 1, row: 2), 1);
    placeItem((col: 3, row: 2), 1);
  }

  /// 직접 배치 (초기 배치·테스트용). 놓을 수 없는 칸이면 무시한다.
  void placeItem(CellPos pos, int level) {
    if (!isEmptyCell(pos) || level < 1 || level > maxLevel) return;
    _items[pos] = level;
    if (level > highestLevel) highestLevel = level;
  }

  /// 생성기 탭: 무작위 빈 칸에 레벨 1 아이템을 놓는다. 빈 칸이 없으면 null.
  CellPos? spawn() {
    final candidates = emptyCells;
    if (candidates.isEmpty) return null;
    final pos = candidates[_random.nextInt(candidates.length)];
    placeItem(pos, 1);
    return pos;
  }

  /// [from]의 아이템을 [to]에 드롭했을 때의 판정과 상태 반영.
  MoveOutcome tryMove(CellPos from, CellPos to) {
    final moving = _items[from];
    if (moving == null || !isInside(to) || to == from || to == generatorCell) {
      return MoveOutcome.rejected;
    }

    final target = _items[to];
    if (target == null) {
      _items.remove(from);
      _items[to] = moving;
      return MoveOutcome.moved;
    }

    if (target == moving && moving < maxLevel) {
      _items.remove(from);
      _items[to] = moving + 1;
      mergeCount++;
      if (moving + 1 > highestLevel) highestLevel = moving + 1;
      return MoveOutcome.merged;
    }

    return MoveOutcome.rejected;
  }
}
