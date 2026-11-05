import 'dart:math';

import '../domain/board_model.dart';

/// 확장 방향. 보드 가장자리 손잡이 하나가 하나씩 맡는다 (화면 흐름 §3.2).
enum ExpandDirection {
  /// 오른쪽 손잡이: 열 +1 (숲 넓히기).
  widen,

  /// 아래 손잡이: 동굴 행 +1 (첫 단계 = 동굴 진입).
  dig,

  /// 두 방향을 다 끝낸 뒤 테마 완주.
  clear,
}

/// 아웃게임 상태: 창고와 테마 완주 여부. 불변 값 — 바꾸는 메서드는 새 값을 돌려준다.
///
/// 확장 단계는 따로 들고 있지 않는다. 보드 크기([BoardModel.columns]·
/// [BoardModel.caveRows])가 곧 확장 단계라서, 두 곳에 두면 어긋날 수 있다.
final class Economy {
  const Economy({
    required this.theme,
    this.amounts = const {},
    this.storageLevel = 0,
    this.cleared = false,
  });

  final GroveTheme theme;

  /// 창고 보유량.
  final Map<Resource, int> amounts;

  /// 창고 단계 (0부터). 용량은 [GroveTheme.storageCapacities].
  final int storageLevel;

  /// 테마 완주 확장을 샀는가.
  final bool cleared;

  int amountOf(Resource r) => amounts[r] ?? 0;

  /// 자원별 창고 용량 (모든 자원 같음).
  int get capacity => theme.storageCapacities[storageLevel];

  bool isFull(Resource r) => amountOf(r) >= capacity;

  Map<Resource, int> get freeSpace => {
    for (final r in Resource.values) r: max(0, capacity - amountOf(r)),
  };

  bool canAfford(Cost cost) =>
      cost.entries.every((e) => amountOf(e.key) >= e.value);

  /// [amount]를 창고에 넣는다. 용량을 넘는 몫은 버려진다. (새 값, 실제로 들어간 양)
  (Economy, int) add(Resource r, int amount) {
    final accepted = min(amount, max(0, capacity - amountOf(r)));
    return (_copy(amounts: {...amounts, r: amountOf(r) + accepted}), accepted);
  }

  /// 여러 자원을 한 번에 넣는다. 반환하는 맵은 실제로 들어간 양.
  (Economy, Map<Resource, int>) addAll(Map<Resource, int> gains) {
    var next = this;
    final accepted = <Resource, int>{};
    gains.forEach((r, amount) {
      final (e, a) = next.add(r, amount);
      next = e;
      accepted[r] = a;
    });
    return (next, accepted);
  }

  /// 비용을 낸다. 모자라면 [StateError].
  Economy pay(Cost cost) {
    if (!canAfford(cost)) {
      throw StateError('cannot afford $cost');
    }
    return _copy(
      amounts: {
        ...amounts,
        for (final MapEntry(:key, :value) in cost.entries)
          key: amountOf(key) - value,
      },
    );
  }

  // ---- 창고 확장 (진행 목표, 테마 문서 §7-4) ----

  bool get canUpgradeStorage =>
      storageLevel < theme.storageCapacities.length - 1;

  Cost? get storageUpgradeCost =>
      canUpgradeStorage ? theme.storageUpgradeCosts[storageLevel] : null;

  Economy upgradeStorage() {
    final cost = storageUpgradeCost;
    if (cost == null) {
      throw StateError('storage already at max');
    }
    return pay(cost)._copy(storageLevel: storageLevel + 1);
  }

  // ---- 보드 확장 비용 ----

  /// [board] 상태에서 [direction] 확장의 다음 비용. 그 방향이 끝났으면 null.
  Cost? expansionCost(ExpandDirection direction, BoardModel board) =>
      switch (direction) {
        ExpandDirection.widen when board.canWiden =>
          theme.widenSteps[board.columns - theme.startColumns].cost,
        ExpandDirection.dig when board.canDig =>
          theme.digSteps[board.caveRows].cost,
        ExpandDirection.clear
            when !cleared && !board.canWiden && !board.canDig =>
          theme.clearCost,
        _ => null,
      };

  Economy markCleared() => _copy(cleared: true);

  Economy _copy({
    Map<Resource, int>? amounts,
    int? storageLevel,
    bool? cleared,
  }) => Economy(
    theme: theme,
    amounts: amounts ?? this.amounts,
    storageLevel: storageLevel ?? this.storageLevel,
    cleared: cleared ?? this.cleared,
  );

  // ---- 저장 형식 ----

  Map<String, Object?> toJson() => {
    'amounts': {for (final e in amounts.entries) e.key.name: e.value},
    'storageLevel': storageLevel,
    'cleared': cleared,
  };

  static Economy fromJson(Map<String, Object?> json, GroveTheme theme) {
    try {
      final raw = json['amounts']! as Map<String, Object?>;
      return Economy(
        theme: theme,
        amounts: {
          for (final r in Resource.values)
            if (raw[r.name] case final int v) r: v,
        },
        storageLevel: json['storageLevel']! as int,
        cleared: json['cleared']! as bool,
      );
    } on TypeError catch (e) {
      throw FormatException('broken economy save: $e');
    }
  }
}
