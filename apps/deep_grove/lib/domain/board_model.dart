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
/// 테마의 최대 보드([GroveTheme.maxColumns] × [GroveTheme.maxRows]) 안에서 **열린 칸**만
/// 쓸 수 있다. 숲이 위, 동굴이 아래. 확장은 열린 칸과 상하좌우로 맞닿은 잠긴 칸
/// ([frontier]) 하나를 연다. 좌표는 최대 보드 기준이라 확장해도 바뀌지 않는다.
///
/// 창고(아웃게임)는 모른다. 산출은 호출자가 넘겨준 창고 빈 공간까지만 쌓고,
/// 거둔 양은 호출자가 창고에 넣는다.
class BoardModel {
  BoardModel(this.theme, {Random? random}) : _random = random ?? Random() {
    for (var row = 0; row < theme.forestRows; row++) {
      for (var col = 0; col < theme.startColumns; col++) {
        _unlocked.add((col: col, row: row));
      }
    }
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
    required Iterable<CellPos> unlocked,
    required this.mergeCount,
    Random? random,
  }) : _random = random ?? Random() {
    _unlocked.addAll(unlocked.where(inGrid));
  }

  final GroveTheme theme;
  final Random _random;

  int mergeCount = 0;

  final Set<CellPos> _unlocked = {};
  final Map<CellPos, CellContent> _cells = {};

  int get forestRows => theme.forestRows;

  /// 열린 칸 (행·열 순서).
  List<CellPos> get unlocked => _sort(_unlocked);

  /// 열린 칸과 상하좌우로 맞닿은 잠긴 칸 — 다음에 열 수 있는 칸 (행·열 순서).
  List<CellPos> get frontier => _sort({
    for (final p in _unlocked)
      for (final n in [
        (col: p.col + 1, row: p.row),
        (col: p.col - 1, row: p.row),
        (col: p.col, row: p.row + 1),
        (col: p.col, row: p.row - 1),
      ])
        if (inGrid(n) && !_unlocked.contains(n)) n,
  });

  bool isFrontier(CellPos pos) =>
      inGrid(pos) &&
      !_unlocked.contains(pos) &&
      [
        (col: pos.col + 1, row: pos.row),
        (col: pos.col - 1, row: pos.row),
        (col: pos.col, row: pos.row + 1),
        (col: pos.col, row: pos.row - 1),
      ].any(_unlocked.contains);

  /// 화면에 그릴 범위: 열린 칸과 다음에 열 칸을 다 담는 열·행 수 (왼쪽 위 0,0부터).
  int get columns => _extent((p) => p.col);
  int get rows => _extent((p) => p.row);

  int _extent(int Function(CellPos) axis) =>
      [..._unlocked, ...frontier].map(axis).fold(0, max) + 1;

  /// 그 지대에서 열린 칸 수 (시작 칸 포함).
  int openedIn(Zone zone) => _unlocked.where((p) => zoneOf(p) == zone).length;

  bool get caveEntered => openedIn(Zone.cave) > 0;

  /// 최대 보드의 모든 칸이 열렸는가 (테마 완주 조건).
  bool get fullyOpen => _unlocked.length == theme.maxColumns * theme.maxRows;

  /// 현재 칸 점유 상태 스냅샷.
  Map<CellPos, CellContent> get cells => Map.unmodifiable(_cells);

  /// 테마의 최대 보드 안인가 (열렸는지와 무관).
  bool inGrid(CellPos pos) =>
      pos.col >= 0 &&
      pos.col < theme.maxColumns &&
      pos.row >= 0 &&
      pos.row < theme.maxRows;

  /// 조각을 놓을 수 있는 열린 칸인가.
  bool isInside(CellPos pos) => _unlocked.contains(pos);

  Zone zoneOf(CellPos pos) => pos.row < forestRows ? Zone.forest : Zone.cave;

  CellContent? contentAt(CellPos pos) => _cells[pos];

  /// 조각을 놓을 수 있는 빈 칸인가 (열린 칸 + 아무 점유물 없음).
  bool isEmptyCell(CellPos pos) => isInside(pos) && !_cells.containsKey(pos);

  List<CellPos> get emptyCells => [
    for (final pos in unlocked)
      if (!_cells.containsKey(pos)) pos,
  ];

  static List<CellPos> _sort(Iterable<CellPos> positions) =>
      positions.toList()
        ..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);

  /// 산출원 목록 (칸 → 산출원). 행·열 순서로 정렬돼 있다.
  List<(CellPos, Producer)> get producers => [
    for (final pos in _sortedPositions)
      if (_cells[pos] case ProducerContent(:final producer)) (pos, producer),
  ];

  Iterable<CellPos> get _sortedPositions => _sort(_cells.keys);

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

  /// [pos] 칸을 연다. 다음에 열 수 있는 칸([frontier])이 아니면 false.
  /// 동굴 칸을 처음 열면(동굴 진입) 그 칸에 동굴 생성기를 놓고 [caveGenerator]로 알려 준다.
  ({bool opened, CellPos? caveGenerator}) unlock(CellPos pos) {
    if (!isFrontier(pos)) {
      return (opened: false, caveGenerator: null);
    }
    final enteringCave = zoneOf(pos) == Zone.cave && !caveEntered;
    _unlocked.add(pos);
    if (enteringCave) {
      _cells[pos] = GeneratorContent(
        theme.generatorFor(theme.caveGeneratorChain),
      );
      return (opened: true, caveGenerator: pos);
    }
    return (opened: true, caveGenerator: null);
  }

  // ---- 저장 형식 ----

  Map<String, Object?> toJson() => {
    'theme': theme.id,
    'unlocked': [
      for (final p in unlocked) [p.col, p.row],
    ],
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

  /// 열린 칸 목록. 한 칸씩 확장 이전 저장(`columns`·`caveRows` 직사각형)도 읽는다.
  static Iterable<CellPos> _unlockedFromJson(
    Map<String, Object?> json,
    GroveTheme theme,
  ) {
    if (json['unlocked'] case final List<Object?> cells) {
      return [
        for (final c in cells)
          if (c case [final int col, final int row]) (col: col, row: row),
      ];
    }
    final columns = json['columns']! as int;
    final rows = theme.forestRows + (json['caveRows']! as int);
    return [
      for (var row = 0; row < rows; row++)
        for (var col = 0; col < columns; col++) (col: col, row: row),
    ];
  }

  /// [toJson] 결과로 보드를 복원한다. 형식이 깨졌으면 [FormatException].
  static BoardModel fromJson(
    Map<String, Object?> json,
    GroveTheme theme, {
    Random? random,
  }) {
    try {
      final board = BoardModel._restored(
        theme,
        unlocked: _unlockedFromJson(json, theme),
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
