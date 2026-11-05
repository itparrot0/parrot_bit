/// 경제 시뮬레이터: 앱과 같은 규칙 코드(BoardModel·Economy) 위에서 자동 플레이어가 판을 진행한다.
///
/// 목적은 숫자(`lib/domain/theme.dart`)를 직접 플레이 전에 점검하는 것이다 —
/// 첫 칸·동굴 진입·완주까지 걸리는 시간, 기다리는 시간, 보드 막힘 (PRD §10-1~3).
///
/// 자동 플레이어는 "꽤 잘하는 사람"이다: 머지할 수 있으면 하고, 산출원을 자기 지대로 옮기고,
/// 필요한 자원 쪽 생성기를 누른다. 실제 사람보다 빠를 수 있으므로 시간은 하한으로 읽는다.
library;

import 'dart:math';

import 'package:deep_grove/domain/board_model.dart';
import 'package:deep_grove/economy/economy.dart';

/// 조작 하나에 드는 시간(초). 사람 손 기준 대략값.
class ActionTimes {
  const ActionTimes({this.tap = 0.6, this.drag = 1.2, this.decide = 0.3});

  final double tap;
  final double drag;

  /// 확장처럼 시트를 열고 고르는 조작에 더하는 시간.
  final double decide;
}

/// 플레이 방식.
class PlayPattern {
  const PlayPattern.continuous() : sessionMinutes = null, awayMinutes = 0;

  /// [sessionMinutes]분 하고 [awayMinutes]분 쉬는 것을 반복한다 (쉬는 동안 방치 산출).
  const PlayPattern.sessions({
    required int this.sessionMinutes,
    required this.awayMinutes,
  });

  final int? sessionMinutes;
  final int awayMinutes;

  bool get continuous => sessionMinutes == null;

  @override
  String toString() =>
      continuous ? '계속 플레이' : '$sessionMinutes분 플레이 / $awayMinutes분 쉼';
}

/// 한 판의 결과. 시간은 전부 게임 시작부터 흐른 실제 시간(초).
class SimResult {
  double? firstCell;
  double? caveEntered;
  double? allOpen;
  double? cleared;

  /// 플레이 중(세션 안) 할 일이 없어 기다린 시간.
  double waitingWhilePlaying = 0;
  double playing = 0;

  int taps = 0;
  int drags = 0;
  int merges = 0;
  int expansions = 0;

  /// 막힘을 풀려고 버린 조각 수 (아이템, 산출원).
  int discardedItems = 0;
  int discardedProducers = 0;

  /// 영영 진행할 수 없는 상태에 빠졌는가. 산출원이 있어도 막힐 수 있다 —
  /// 예: 보드가 목재 산출원으로 가득 차 돌을 키울 칸이 없는데 다음 칸이 모두 광석을 요구할 때.
  /// 판정: 플레이 중 [Simulator.stuckAfterHours] 동안 확장·완주가 한 번도 없음.
  bool stuck = false;
  double? stuckAt;

  /// 보드가 꽉 차고 머지할 짝도 없어 기다린 횟수 (산출원이 있어 언젠가는 풀림).
  int fullBoardWaits = 0;

  /// 확장한 칸 순서 (지대 이름).
  final List<String> openOrder = [];

  /// 산출로 생겼지만 창고가 가득 차 쌓이지 못했을 양은 모델이 막으므로 따로 없다.
  /// 대신 창고가 가득 찬 채 플레이한 시간을 센다.
  double storageFullWhilePlaying = 0;
}

/// 생성기 에너지 (게임에는 아직 없는 규칙 — 결정을 돕기 위한 가정).
/// 탭마다 1을 쓰고, [regenSeconds]마다 1이 차며 [cap]까지 쌓인다. 쉬는 동안에도 찬다.
class Energy {
  const Energy({required this.cap, required this.regenSeconds});

  final int cap;
  final double regenSeconds;

  @override
  String toString() => '에너지 $cap칸, ${regenSeconds.toStringAsFixed(0)}초에 1';
}

/// [theme]의 모든 확장·창고·완주 비용에 [factor]를 곱한 테마 (창고 용량도 같이 늘린다).
/// [secondsPerUnit]을 주면 산출원 속도도 바꾼다.
GroveTheme scaledCosts(
  GroveTheme theme,
  double factor, {
  double? secondsPerUnit,
}) {
  Cost scale(Cost c) => {
    for (final e in c.entries) e.key: (e.value * factor).ceil(),
  };
  return GroveTheme(
    id: theme.id,
    chains: theme.chains,
    spawnOdds: theme.spawnOdds,
    startColumns: theme.startColumns,
    forestRows: theme.forestRows,
    startGenerators: theme.startGenerators,
    startItems: theme.startItems,
    maxColumns: theme.maxColumns,
    caveRows: theme.caveRows,
    forestCellCosts: theme.forestCellCosts.map(scale).toList(),
    caveCellCosts: theme.caveCellCosts.map(scale).toList(),
    caveGeneratorChain: theme.caveGeneratorChain,
    clearCost: scale(theme.clearCost),
    storageCapacities: [
      for (final c in theme.storageCapacities) (c * factor).ceil(),
    ],
    storageUpgradeCosts: theme.storageUpgradeCosts.map(scale).toList(),
    secondsPerUnit: secondsPerUnit ?? theme.secondsPerUnit,
    homeZoneBonus: theme.homeZoneBonus,
  );
}

class Simulator {
  Simulator({
    required this.theme,
    required this.seed,
    this.pattern = const PlayPattern.continuous(),
    this.times = const ActionTimes(),
    this.limitHours = 24 * 14,
    this.energy,
    this.stuckAfterHours = 12,
  }) : _energy = energy?.cap.toDouble() ?? 0;

  /// 이만큼 플레이(세션 안 시간)하는 동안 확장이 없으면 막힌 것으로 본다.
  final double stuckAfterHours;
  double _playAtLastProgress = 0;

  final Energy? energy;
  double _energy;

  final GroveTheme theme;
  final int seed;
  final PlayPattern pattern;
  final ActionTimes times;
  final double limitHours;

  late final BoardModel board = BoardModel(theme, random: Random(seed));
  late Economy economy = Economy(theme: theme);
  final SimResult result = SimResult();

  double _now = 0;
  double _sessionLeft = 0;

  SimResult run() {
    _sessionLeft = (pattern.sessionMinutes ?? 0) * 60.0;
    final limit = limitHours * 3600;
    while (_now < limit && result.cleared == null) {
      if (!pattern.continuous && _sessionLeft <= 0) {
        _away(pattern.awayMinutes * 60.0);
        _sessionLeft = pattern.sessionMinutes! * 60.0;
        continue;
      }
      if (!_step()) {
        final noProgress =
            result.playing - _playAtLastProgress > stuckAfterHours * 3600;
        final dead =
            board.producers.isEmpty && energy == null && !_canDoAnything();
        if (noProgress || dead) {
          result
            ..stuck = true
            ..stuckAt = _now;
          break;
        }
        _wait(_idleSkip());
      }
    }
    return result;
  }

  // ---- 시간 ----

  void _regen(double seconds) {
    final e = energy;
    if (e != null) {
      _energy = min(e.cap.toDouble(), _energy + seconds / e.regenSeconds);
    }
  }

  void _spend(double seconds) {
    _regen(seconds);
    board.advance(seconds, economy.freeSpace);
    _now += seconds;
    result.playing += seconds;
    if (Resource.values.any(
      (r) => economy.isFull(r) && (r == Resource.wood || board.caveEntered),
    )) {
      result.storageFullWhilePlaying += seconds;
    }
    _sessionLeft -= seconds;
  }

  /// 할 일이 없을 때 얼마나 건너뛸지: 다음 산출원이 1 익거나 에너지가 1 찰 때까지
  /// (최소 1초, 최대 5분, 세션 끝을 넘지 않게). 5초씩 기다리면 느린 수치에서 너무 오래 걸린다.
  double _idleSkip() {
    var next = 300.0;
    for (final (pos, producer) in board.producers) {
      if (economy.isFull(producer.chain.resource)) continue;
      final rate = board.rateAt(pos, producer);
      final toRipe = (producer.ripe + 1 - producer.stock) / rate;
      next = min(next, toRipe);
    }
    final e = energy;
    if (e != null && _energy < 1) {
      next = min(next, (1 - _energy) * e.regenSeconds);
    }
    if (!pattern.continuous) next = min(next, _sessionLeft);
    return max(1, next);
  }

  void _wait(double seconds) {
    result.waitingWhilePlaying += seconds;
    _spend(seconds);
  }

  /// 앱을 닫고 쉰다: 방치 산출만 쌓이고, 돌아오면 복귀 보상으로 한 번에 받는다.
  void _away(double seconds) {
    _regen(seconds);
    board.advance(seconds, economy.freeSpace);
    _now += seconds;
    final (next, _) = economy.addAll(board.harvestAll());
    economy = next;
  }

  void _tap() {
    result.taps++;
    _spend(times.tap);
  }

  void _drag() {
    result.drags++;
    _spend(times.drag);
  }

  // ---- 한 걸음: 할 수 있는 가장 좋은 일 하나. 아무것도 못 하면 false ----

  bool _step() =>
      _clearIfPossible() ||
      _expandIfPossible() ||
      _harvest() ||
      _merge() ||
      _relocateProducer() ||
      _spawn() ||
      _unjam();

  bool _canDoAnything() =>
      board.emptyCells.isNotEmpty || _mergePair() != null || _goal() != null;

  bool _clearIfPossible() {
    final cost = economy.expansionCost(const ClearTheme(), board);
    if (cost == null || !economy.canAfford(cost)) return false;
    economy = economy.pay(cost).markCleared();
    _spend(times.tap + times.decide);
    result.cleared = _now;
    return true;
  }

  /// 다음 목표: 가장 싼 열 칸, 또는 그 칸을 살 수 없을 만큼 창고가 작으면 창고 확장.
  ({Cost cost, Expansion? expansion})? _goal() {
    final cells = [
      for (final pos in board.frontier)
        (pos: pos, cost: economy.expansionCost(UnlockCell(pos), board)!),
    ];
    if (cells.isEmpty) {
      if (board.fullyOpen && !economy.cleared) {
        final clear = theme.clearCost;
        if (clear.values.any((v) => v > economy.capacity) &&
            economy.canUpgradeStorage) {
          return (cost: economy.storageUpgradeCost!, expansion: null);
        }
        return (cost: clear, expansion: const ClearTheme());
      }
      return null;
    }
    // 광석이 없는데 광석을 요구하는 칸은 뒤로 (동굴부터 가야 한다).
    int weight(Cost c) =>
        c.values.fold(0, (a, b) => a + b) +
        (board.caveEntered || !c.containsKey(Resource.ore) ? 0 : 1000);
    cells.sort((a, b) => weight(a.cost).compareTo(weight(b.cost)));
    final best = cells.first;
    if (best.cost.values.any((v) => v > economy.capacity) &&
        economy.canUpgradeStorage) {
      return (cost: economy.storageUpgradeCost!, expansion: null);
    }
    // 창고가 가득 찼고 창고 확장을 살 수 있으면 창고부터 (산출이 멈춰 있으므로).
    if (economy.isFull(Resource.wood) &&
        economy.canUpgradeStorage &&
        economy.canAfford(economy.storageUpgradeCost!) &&
        !economy.canAfford(best.cost)) {
      return (cost: economy.storageUpgradeCost!, expansion: null);
    }
    return (cost: best.cost, expansion: UnlockCell(best.pos));
  }

  bool _expandIfPossible() {
    final goal = _goal();
    if (goal == null || !economy.canAfford(goal.cost)) return false;
    switch (goal.expansion) {
      case null:
        economy = economy.upgradeStorage(); // 비용은 upgradeStorage 가 낸다
        _playAtLastProgress = result.playing;
      case UnlockCell(:final pos):
        economy = economy.pay(goal.cost);
        final zone = board.zoneOf(pos);
        board.unlock(pos);
        result.expansions++;
        _playAtLastProgress = result.playing;
        result.openOrder.add(zone.name);
        result.firstCell ??= _now;
        if (zone == Zone.cave) result.caveEntered ??= _now;
        if (board.fullyOpen) result.allOpen ??= _now;
      case ClearTheme():
        return false;
    }
    _spend(times.tap * 2 + times.decide);
    return true;
  }

  bool _harvest() {
    final goal = _goal();
    for (final (pos, producer) in board.producers) {
      final r = producer.chain.resource;
      final needed = goal == null || (goal.cost[r] ?? 0) > economy.amountOf(r);
      // 필요한 자원이면 1부터, 아니면 3개 모였을 때 (탭을 아낀다).
      if (producer.ripe >= (needed ? 1 : 3) && !economy.isFull(r)) {
        final (res, amount) = board.harvest(pos)!;
        final (next, accepted) = economy.add(res, amount);
        economy = next;
        if (accepted < amount) producer.stock += amount - accepted;
        _tap();
        return true;
      }
    }
    return false;
  }

  /// 머지할 짝: 높은 레벨 먼저. 최고 레벨 - 1 짝은 자기 지대 칸을 도착점으로.
  (CellPos from, CellPos to)? _mergePair() {
    final groups = <(ItemChain, int), List<CellPos>>{};
    board.cells.forEach((pos, c) {
      if (c case ItemContent(:final item) when !item.isMaxLevel) {
        groups.putIfAbsent((item.chain, item.level), () => []).add(pos);
      }
    });
    final pairs = groups.entries.where((e) => e.value.length >= 2).toList()
      ..sort((a, b) => b.key.$2.compareTo(a.key.$2));
    if (pairs.isEmpty) return null;
    final (chain, level) = pairs.first.key;
    final cells = pairs.first.value;
    if (level == chain.maxLevel - 1) {
      final home = cells.where((p) => board.zoneOf(p) == chain.homeZone);
      if (home.isNotEmpty) {
        final to = home.first;
        return (cells.firstWhere((p) => p != to), to);
      }
    }
    return (cells[0], cells[1]);
  }

  bool _merge() {
    final pair = _mergePair();
    if (pair == null) return false;
    board.tryMove(pair.$1, pair.$2);
    result.merges++;
    _drag();
    return true;
  }

  /// 자기 지대 밖의 산출원을 자기 지대 빈 칸으로 옮긴다 (보너스 1.5배).
  bool _relocateProducer() {
    for (final (pos, producer) in board.producers) {
      final home = producer.chain.homeZone;
      if (board.zoneOf(pos) == home) continue;
      final target = board.emptyCells.where((p) => board.zoneOf(p) == home);
      if (target.isEmpty) continue;
      board.tryMove(pos, target.first);
      _drag();
      return true;
    }
    return false;
  }

  bool _spawn() {
    if (energy != null && _energy < 1) return false;
    if (board.emptyCells.isEmpty) {
      if (_mergePair() == null) result.fullBoardWaits++;
      return false;
    }
    final generators = <ItemChain, (CellPos, Generator)>{};
    board.cells.forEach((pos, c) {
      if (c case GeneratorContent(:final generator)) {
        generators[generator.spawnChain] = (pos, generator);
      }
    });
    if (generators.isEmpty) return false;
    final goal = _goal();
    final producersOf = <Resource, int>{};
    for (final (_, p) in board.producers) {
      producersOf.update(p.chain.resource, (v) => v + 1, ifAbsent: () => 1);
    }
    // 광석이 모자라고 돌 산출원이 목재 산출원보다 적으면 돌, 아니면 나무.
    final oreShort =
        goal != null &&
        (goal.cost[Resource.ore] ?? 0) > economy.amountOf(Resource.ore);
    final wantStone =
        oreShort &&
        (producersOf[Resource.ore] ?? 0) <= (producersOf[Resource.wood] ?? 0);
    final pick = wantStone && generators.containsKey(_stone)
        ? generators[_stone]!
        : generators[_wood] ?? generators.values.first;
    // 창고가 가득 찬 자원의 산출원만 늘리는 건 의미가 없지만, 보드 성장 자체가 목적이므로 계속 누른다.
    board.spawnFrom(pick.$2);
    if (energy != null) _energy -= 1;
    _tap();
    return true;
  }

  /// 막힘 풀기: 보드가 꽉 찼고 머지할 짝도 없는데, 다음 목표에 모자란 자원을 낼
  /// 산출원이 하나도 없으면 — 기다려도 영원히 안 풀린다 — 하나를 버린다.
  /// 필요 없는 체인의 낮은 아이템 → 아무 낮은 아이템 → 필요 없는 자원의 산출원 순.
  bool _unjam() {
    if (board.emptyCells.isNotEmpty || _mergePair() != null) return false;
    final goal = _goal();
    if (goal == null || economy.canAfford(goal.cost)) return false;
    final producing = {for (final (_, p) in board.producers) p.chain.resource};
    final missing = [
      for (final e in goal.cost.entries)
        if (e.value > economy.amountOf(e.key) && !producing.contains(e.key))
          e.key,
    ];
    if (missing.isEmpty) return false;
    final items = [
      for (final e in board.cells.entries)
        if (e.value case ItemContent(:final item)) (e.key, item),
    ]..sort((a, b) => a.$2.level.compareTo(b.$2.level));
    final useless = items.where((e) => !missing.contains(e.$2.chain.resource));
    final victim = useless.isNotEmpty
        ? useless.first.$1
        : items.isNotEmpty
        ? items.first.$1
        : null;
    if (victim != null) {
      board.discard(victim);
      result.discardedItems++;
      _drag();
      return true;
    }
    for (final (pos, producer) in board.producers) {
      if (missing.contains(producer.chain.resource)) continue;
      final r = board.discard(pos)!;
      if (r.harvested case (final res, final amount)) {
        economy = economy.add(res, amount).$1;
      }
      result.discardedProducers++;
      _drag();
      _spend(times.decide);
      return true;
    }
    return false;
  }

  ItemChain get _wood => theme.chains.firstWhere((c) => c.id == 'wood');
  ItemChain get _stone => theme.chains.firstWhere((c) => c.id == 'stone');
}

/// 여러 판을 돌려 요약한다.
class SimSummary {
  SimSummary(this.label, this.results);

  final String label;
  final List<SimResult> results;

  int get stuck => results.where((r) => r.stuck).length;
  int get cleared => results.where((r) => r.cleared != null).length;

  List<double> _values(double? Function(SimResult) f) =>
      results.map(f).whereType<double>().toList()..sort();

  static String _fmt(double? seconds) {
    if (seconds == null) return '—';
    if (seconds < 120) return '${seconds.toStringAsFixed(0)}초';
    if (seconds < 7200) return '${(seconds / 60).toStringAsFixed(1)}분';
    return '${(seconds / 3600).toStringAsFixed(1)}시간';
  }

  String stat(double? Function(SimResult) f) {
    final v = _values(f);
    if (v.isEmpty) return '—';
    double q(double p) => v[((v.length - 1) * p).round()];
    return '${_fmt(q(0.5))} (${_fmt(q(0.1))}~${_fmt(q(0.9))})';
  }

  String waitingShare() {
    final w = results.fold<double>(0, (a, r) => a + r.waitingWhilePlaying);
    final p = results.fold<double>(0, (a, r) => a + r.playing);
    return p == 0 ? '—' : '${(w / p * 100).toStringAsFixed(0)}%';
  }

  String fullShare() {
    final w = results.fold<double>(0, (a, r) => a + r.storageFullWhilePlaying);
    final p = results.fold<double>(0, (a, r) => a + r.playing);
    return p == 0 ? '—' : '${(w / p * 100).toStringAsFixed(0)}%';
  }

  double get avgTaps =>
      results.fold<int>(0, (a, r) => a + r.taps) / results.length;
  double get avgDrags =>
      results.fold<int>(0, (a, r) => a + r.drags) / results.length;
}

/// 첫 확장 6칸 안에 동굴을 연 판의 비율 등, 열린 순서 요약.
String openOrderSummary(List<SimResult> results) {
  final firstCave = [
    for (final r in results)
      if (r.openOrder.contains('cave')) r.openOrder.indexOf('cave') + 1,
  ]..sort();
  if (firstCave.isEmpty) return '동굴 진입 없음';
  return '동굴 진입은 평균 ${(firstCave.reduce((a, b) => a + b) / firstCave.length).toStringAsFixed(1)}번째 확장';
}
