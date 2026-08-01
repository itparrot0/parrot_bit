import 'dart:math';

import 'cell_content.dart';
import 'cell_pos.dart';
import 'generator.dart';
import 'item.dart';

export 'cell_content.dart';
export 'cell_pos.dart';
export 'generator.dart';
export 'item.dart';

/// 드롭 판정 결과.
enum MoveOutcome { merged, moved, rejected }

/// 머지 보드의 순수 Dart 모델. Flame 없이 단위 테스트한다.
///
/// 규칙은 docs/prd/proto_merge.md "게임 규칙 명세"를 따른다.
/// 렌더링 계층(MergeGame)은 이 모델의 판정 결과를 그리기만 한다.
///
/// 확장 지점:
/// - 아이템셋 추가 → [ItemChain] const 추가
/// - 생성기 추가/변경 → 생성자의 [generators] 목록
/// - 새 보드 요소 → [CellContent] 하위 타입 + [tryMove] 분기
class BoardModel {
  BoardModel({
    this.columns = 5,
    this.rows = 6,
    List<Generator>? generators,
    Map<CellPos, Item>? initialItems,
    Random? random,
  }) : _random = random ?? Random() {
    this.generators = List.unmodifiable(
      generators ??
          [
            Generator(
              cell: (col: columns ~/ 2, row: rows - 1),
              spawnChain: basicChain,
            ),
          ],
    );
    _initialItems = Map.unmodifiable(
      initialItems ??
          {
            (col: 1, row: 2): const Item(basicChain, 1),
            (col: 3, row: 2): const Item(basicChain, 1),
          },
    );
    reset();
  }

  final int columns;
  final int rows;
  final Random _random;

  /// 보드 위 생성기 목록 (생성 시 확정, 불변).
  late final List<Generator> generators;

  /// reset 시 되돌아갈 초기 아이템 배치.
  late final Map<CellPos, Item> _initialItems;

  final Map<CellPos, CellContent> _cells = {};

  int mergeCount = 0;
  int highestLevel = 1;

  /// 현재 배치된 아이템 (칸 → 아이템). 스냅샷.
  Map<CellPos, Item> get items => {
        for (final MapEntry(:key, :value) in _cells.entries)
          if (value is ItemContent) key: value.item,
      };

  bool isInside(CellPos pos) =>
      pos.col >= 0 && pos.col < columns && pos.row >= 0 && pos.row < rows;

  CellContent? contentAt(CellPos pos) => _cells[pos];

  Item? itemAt(CellPos pos) => switch (_cells[pos]) {
        ItemContent(:final item) => item,
        _ => null,
      };

  /// 아이템을 놓을 수 있는 빈 칸인가 (보드 안 + 아무 점유물 없음).
  bool isEmptyCell(CellPos pos) => isInside(pos) && !_cells.containsKey(pos);

  List<CellPos> get emptyCells => [
        for (var row = 0; row < rows; row++)
          for (var col = 0; col < columns; col++)
            if (isEmptyCell((col: col, row: row))) (col: col, row: row),
      ];

  /// 초기 배치로 되돌린다: 생성기들을 자기 칸에 놓고 초기 아이템을 배치한다.
  void reset() {
    _cells.clear();
    mergeCount = 0;
    highestLevel = 1;
    for (final generator in generators) {
      if (isInside(generator.cell) && !_cells.containsKey(generator.cell)) {
        _cells[generator.cell] = GeneratorContent(generator);
      }
    }
    _initialItems.forEach(placeItem);
  }

  /// 직접 배치 (초기 배치·테스트용). 놓을 수 없는 칸/레벨이면 무시한다.
  void placeItem(CellPos pos, Item item) {
    if (!isEmptyCell(pos) || item.level < 1 || item.level > item.chain.maxLevel) {
      return;
    }
    _cells[pos] = ItemContent(item);
    if (item.level > highestLevel) {
      highestLevel = item.level;
    }
  }

  /// [generator] 탭: 무작위 빈 칸에 생성기의 아이템을 놓는다. 빈 칸이 없으면 null.
  CellPos? spawnFrom(Generator generator) {
    final candidates = emptyCells;
    if (candidates.isEmpty) {
      return null;
    }
    final pos = candidates[_random.nextInt(candidates.length)];
    placeItem(pos, generator.produce());
    return pos;
  }

  /// [from]의 아이템을 [to]에 드롭했을 때의 판정과 상태 반영.
  MoveOutcome tryMove(CellPos from, CellPos to) {
    final source = _cells[from];
    if (source is! ItemContent || !isInside(to) || to == from) {
      return MoveOutcome.rejected;
    }

    final moving = source.item;
    switch (_cells[to]) {
      case null:
        _cells.remove(from);
        _cells[to] = source;
        return MoveOutcome.moved;
      case ItemContent(:final item) when moving.canMergeWith(item):
        _cells.remove(from);
        _cells[to] = ItemContent(moving.upgraded);
        mergeCount++;
        if (moving.level + 1 > highestLevel) {
          highestLevel = moving.level + 1;
        }
        return MoveOutcome.merged;
      case _:
        return MoveOutcome.rejected;
    }
  }
}
