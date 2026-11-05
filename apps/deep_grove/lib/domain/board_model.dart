import 'dart:math';

import 'cell_content.dart';
import 'cell_pos.dart';
import 'generator.dart';
import 'item.dart';
import 'producer.dart';
import 'theme.dart';
import 'zone.dart';

export 'cell_content.dart';
export 'cell_pos.dart';
export 'generator.dart';
export 'item.dart';
export 'producer.dart';
export 'theme.dart';
export 'zone.dart';

/// 드롭 판정 결과.
enum MoveOutcome { merged, moved, swapped, rejected }

/// 머지 보드의 순수 Dart 모델. Flame 없이 단위 테스트한다.
///
/// 조작 규칙은 `docs/prd/proto_merge.md` §4(프로토타입에서 검증) 그대로이고,
/// 정식판에서 더한 것은 `docs/design/deep_grove-themes.md` §8:
/// 산출원(최고 레벨 변신)·지대·보드 확장·생성기 확률 스폰.
///
/// 보드는 언제나 직사각형이다: [columns] 열 × ([forestRows] + [caveRows]) 행.
/// 숲이 위, 동굴이 아래. 확장은 열을 오른쪽에, 동굴 행을 아래에 붙이므로
/// 기존 조각의 좌표는 바뀌지 않는다.
///
/// 창고(아웃게임)는 모른다. 산출은 호출자가 넘겨준 창고 빈 공간까지만 쌓고,
/// 거둔 양은 호출자가 창고에 넣는다.
class BoardModel {
  BoardModel(this.theme, {Random? random})
    : _random = random ?? Random(),
      columns = theme.startColumns,
      caveRows = 0 {
    theme.startGenerators.forEach((pos, chain) {
      _cells[pos] = GeneratorContent(theme.generatorFor(chain));
    });
    theme.startItems.forEach((pos, entry) {
      final (chain, level) = entry;
      placeItem(pos, Item(chain, level));
    });
  }

  BoardModel._restored(
    this.theme, {
    required this.columns,
    required this.caveRows,
    required this.mergeCount,
    Random? random,
  }) : _random = random ?? Random();

  final GroveTheme theme;
  final Random _random;

  int columns;
  int caveRows;
  int mergeCount = 0;

  final Map<CellPos, CellContent> _cells = {};

  int get forestRows => theme.forestRows;
  int get rows => forestRows + caveRows;

  bool get canWiden => columns < theme.maxColumns;
  bool get canDig => caveRows < theme.maxCaveRows;
  bool get caveEntered => caveRows > 0;

  /// 현재 칸 점유 상태 스냅샷.
  Map<CellPos, CellContent> get cells => Map.unmodifiable(_cells);

  bool isInside(CellPos pos) =>
      pos.col >= 0 && pos.col < columns && pos.row >= 0 && pos.row < rows;

  Zone zoneOf(CellPos pos) => pos.row < forestRows ? Zone.forest : Zone.cave;

  CellContent? contentAt(CellPos pos) => _cells[pos];

  /// 조각을 놓을 수 있는 빈 칸인가 (보드 안 + 아무 점유물 없음).
  bool isEmptyCell(CellPos pos) => isInside(pos) && !_cells.containsKey(pos);

  List<CellPos> get emptyCells => [
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < columns; col++)
        if (isEmptyCell((col: col, row: row))) (col: col, row: row),
  ];

  /// 산출원 목록 (칸 → 산출원). 행·열 순서로 정렬돼 있다.
  List<(CellPos, Producer)> get producers => [
    for (final pos in _sortedPositions)
      if (_cells[pos] case ProducerContent(:final producer)) (pos, producer),
  ];

  Iterable<CellPos> get _sortedPositions =>
      _cells.keys.toList()
        ..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);

  /// 직접 배치 (초기 배치·테스트용). 놓을 수 없는 칸이면 무시한다.
  /// 최고 레벨 아이템은 산출원으로 놓인다.
  void placeItem(CellPos pos, Item item) {
    if (!isEmptyCell(pos) ||
        item.level < 1 ||
        item.level > item.chain.maxLevel) {
      return;
    }
    _cells[pos] = _contentFor(item);
  }

  /// 직접 배치 (테스트·저장 복원용).
  void placeContent(CellPos pos, CellContent content) {
    if (isEmptyCell(pos)) {
      _cells[pos] = content;
    }
  }

  CellContent _contentFor(Item item) => item.isMaxLevel
      ? ProducerContent(Producer(item.chain))
      : ItemContent(item);

  /// [generator] 탭: 무작위 빈 칸에 확률표로 뽑은 아이템을 놓는다. 빈 칸이 없으면 null.
  CellPos? spawnFrom(Generator generator) {
    final candidates = emptyCells;
    if (candidates.isEmpty) {
      return null;
    }
    final pos = candidates[_random.nextInt(candidates.length)];
    placeItem(pos, generator.produce(_random));
    return pos;
  }

  /// [from]의 조각을 [to]에 드롭했을 때의 판정과 상태 반영.
  ///
  /// 머지는 같은 종류끼리만(아이템↔아이템, 생성기↔생성기). 산출원은 머지되지 않는다.
  /// 머지 조건이 아닌 점유 칸에 드롭하면 자리를 교체하고,
  /// 거부는 보드 밖·제자리 드롭뿐이다.
  MoveOutcome tryMove(CellPos from, CellPos to) {
    final source = _cells[from];
    if (source == null || !isInside(to) || to == from) {
      return MoveOutcome.rejected;
    }

    final target = _cells[to];
    switch ((source, target)) {
      case (_, null):
        _cells.remove(from);
        _cells[to] = source;
        return MoveOutcome.moved;

      case (ItemContent(item: final moving), ItemContent(item: final resting))
          when moving.canMergeWith(resting):
        _cells.remove(from);
        _cells[to] = _contentFor(moving.upgraded);
        mergeCount++;
        return MoveOutcome.merged;

      case (
            GeneratorContent(generator: final moving),
            GeneratorContent(generator: final resting),
          )
          when moving.canMergeWith(resting):
        _cells.remove(from);
        _cells[to] = GeneratorContent(moving.upgraded);
        mergeCount++;
        return MoveOutcome.merged;

      case _:
        _cells[from] = target!;
        _cells[to] = source;
        return MoveOutcome.swapped;
    }
  }

  /// [content]를 놓을 때 산출 보너스를 받는 지대 (드래그 중 칸 밝히기용). 없으면 null.
  ///
  /// 보너스는 산출원만 받는다. 다만 최고 레벨 바로 아래 아이템은 머지되는 칸에서
  /// 산출원이 되므로, 그 아이템도 자기 체인 지대를 알려 준다.
  static Zone? bonusZoneOf(CellContent content) => switch (content) {
    ProducerContent(:final producer) => producer.chain.homeZone,
    ItemContent(:final item) when item.level == item.chain.maxLevel - 1 =>
      item.chain.homeZone,
    _ => null,
  };

  /// [pos]의 산출원이 지대 보너스를 받고 있는가.
  bool hasZoneBonus(CellPos pos) => switch (_cells[pos]) {
    ProducerContent(:final producer) => zoneOf(pos) == producer.chain.homeZone,
    _ => false,
  };

  /// 산출원 [producer]가 [pos]에 있을 때 초당 산출량.
  double rateAt(CellPos pos, Producer producer) {
    final base = 1 / theme.secondsPerUnit;
    return zoneOf(pos) == producer.chain.homeZone
        ? base * theme.homeZoneBonus
        : base;
  }

  /// 아직 거두지 않은 산출량 합계 (자원별, 소수 포함).
  Map<Resource, double> get pending {
    final result = <Resource, double>{};
    for (final (_, producer) in producers) {
      result.update(
        producer.chain.resource,
        (v) => v + producer.stock,
        ifAbsent: () => producer.stock,
      );
    }
    return result;
  }

  /// [seconds]만큼 시간을 흘려 산출원에 자원을 쌓는다.
  ///
  /// 자원별로 (창고 빈 공간 [freeSpace] − 이미 쌓인 미수확량)까지만 쌓는다 —
  /// 창고가 가득 차면 방치 산출이 멈춘다 (테마 문서 §7-4). 실시간 틱과
  /// 오프라인 복귀를 같은 함수로 처리한다. [multiplier]는 광고 산출 가속 배율.
  void advance(
    double seconds,
    Map<Resource, int> freeSpace, {
    double multiplier = 1,
  }) {
    if (seconds <= 0) {
      return;
    }
    final room = <Resource, double>{
      for (final r in Resource.values) r: (freeSpace[r] ?? 0).toDouble(),
    };
    pending.forEach((r, v) => room[r] = room[r]! - v);
    for (final (pos, producer) in producers) {
      final r = producer.chain.resource;
      final gain = min(
        rateAt(pos, producer) * multiplier * seconds,
        max(0.0, room[r]!),
      );
      producer.stock += gain;
      room[r] = room[r]! - gain;
    }
  }

  /// 자리를 비운 [seconds] 동안의 산출을 한 번에 반영하고, 그 사이 새로 익은 양을
  /// 자원별 정수로 돌려준다 (복귀 보상 표시용). 오프라인 복귀·백그라운드 복귀 공용.
  Map<Resource, int> advanceAway(
    double seconds,
    Map<Resource, int> freeSpace, {
    double multiplier = 1,
  }) {
    final before = pending;
    advance(seconds, freeSpace, multiplier: multiplier);
    return {
      for (final MapEntry(key: r, value: after) in pending.entries)
        if (after.floor() - (before[r] ?? 0).floor() > 0)
          r: after.floor() - (before[r] ?? 0).floor(),
    };
  }

  /// [pos]의 산출원에서 다 익은 자원을 거둔다. 산출원이 아니거나 0이면 null.
  (Resource, int)? harvest(CellPos pos) {
    if (_cells[pos] case ProducerContent(:final producer)) {
      final amount = producer.ripe;
      if (amount == 0) {
        return null;
      }
      producer.stock -= amount;
      return (producer.chain.resource, amount);
    }
    return null;
  }

  /// 모든 산출원의 쌓인 양을 **소수까지** 거둔다 (복귀 보상 받기). 정수로 내림한다.
  Map<Resource, int> harvestAll() {
    final totals = <Resource, double>{};
    for (final (_, producer) in producers) {
      totals.update(
        producer.chain.resource,
        (v) => v + producer.stock,
        ifAbsent: () => producer.stock,
      );
      producer.stock = 0;
    }
    return {
      for (final MapEntry(:key, :value) in totals.entries)
        if (value.floor() > 0) key: value.floor(),
    };
  }

  /// 오른쪽에 열 하나를 붙인다. 더 넓힐 수 없으면 false.
  bool widen() {
    if (!canWiden) {
      return false;
    }
    columns++;
    return true;
  }

  /// 아래에 동굴 행 하나를 붙인다. 첫 하향 확장(동굴 진입)이면 새 행 가운데에
  /// 동굴 생성기를 놓고 그 칸을 돌려준다. 더 팔 수 없으면 false.
  ({bool dug, CellPos? caveGenerator}) dig() {
    if (!canDig) {
      return (dug: false, caveGenerator: null);
    }
    caveRows++;
    if (caveRows == 1) {
      final pos = (col: columns ~/ 2, row: rows - 1);
      _cells[pos] = GeneratorContent(
        theme.generatorFor(theme.caveGeneratorChain),
      );
      return (dug: true, caveGenerator: pos);
    }
    return (dug: true, caveGenerator: null);
  }

  // ---- 저장 형식 ----

  Map<String, Object?> toJson() => {
    'theme': theme.id,
    'columns': columns,
    'caveRows': caveRows,
    'mergeCount': mergeCount,
    'cells': [
      for (final pos in _sortedPositions)
        {'col': pos.col, 'row': pos.row, ..._contentToJson(_cells[pos]!)},
    ],
  };

  static Map<String, Object?> _contentToJson(CellContent content) =>
      switch (content) {
        ItemContent(:final item) => {
          'kind': 'item',
          'chain': item.chain.id,
          'level': item.level,
        },
        GeneratorContent(:final generator) => {
          'kind': 'generator',
          'chain': generator.spawnChain.id,
          'level': generator.level,
        },
        ProducerContent(:final producer) => {
          'kind': 'producer',
          'chain': producer.chain.id,
          'stock': producer.stock,
        },
      };

  /// [toJson] 결과로 보드를 복원한다. 형식이 깨졌으면 [FormatException].
  static BoardModel fromJson(
    Map<String, Object?> json,
    GroveTheme theme, {
    Random? random,
  }) {
    try {
      final board = BoardModel._restored(
        theme,
        columns: json['columns']! as int,
        caveRows: json['caveRows']! as int,
        mergeCount: json['mergeCount']! as int,
        random: random,
      );
      for (final raw in json['cells']! as List<Object?>) {
        final cell = raw! as Map<String, Object?>;
        final pos = (col: cell['col']! as int, row: cell['row']! as int);
        final chain = theme.chainById(cell['chain']! as String);
        final content = switch (cell['kind']) {
          'item' => ItemContent(Item(chain, cell['level']! as int)),
          'generator' => GeneratorContent(
            theme.generatorFor(chain, level: cell['level']! as int),
          ),
          'producer' => ProducerContent(
            Producer(chain, stock: (cell['stock']! as num).toDouble()),
          ),
          final kind => throw FormatException('unknown cell kind: $kind'),
        };
        board.placeContent(pos, content);
      }
      return board;
    } on TypeError catch (e) {
      throw FormatException('broken board save: $e');
    } on StateError catch (e) {
      throw FormatException('broken board save: $e');
    }
  }
}
