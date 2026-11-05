import 'dart:math';

import 'item.dart';

/// 생성기 레벨별 스폰 확률표 (테마 문서 §7-3).
///
/// `odds[g - 1]`이 G[g]의 확률표이고, 그 안의 `i`번째 값이 (i+1)레벨 아이템이
/// 나올 가중치다. G1은 언제나 1레벨만 낸다.
final class SpawnOdds {
  const SpawnOdds(this.odds);

  final List<List<double>> odds;

  int get maxGeneratorLevel => odds.length;

  /// [generatorLevel] 생성기가 낼 아이템 레벨을 뽑는다.
  int roll(int generatorLevel, Random random) {
    final weights = odds[generatorLevel - 1];
    final total = weights.fold<double>(0, (a, b) => a + b);
    var pick = random.nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      pick -= weights[i];
      if (pick < 0) {
        return i + 1;
      }
    }
    return weights.length;
  }
}

/// 보드 위 생성기: 탭하면 자기 체인 아이템을 만든다.
///
/// 아이템처럼 드래그로 이동하고, 같은 체인·같은 레벨끼리 머지해 레벨을 올린다.
/// 레벨이 오를수록 상위 레벨 아이템이 나올 **확률**이 오른다 —
/// 프로토타입의 "생성기 레벨 = 스폰 레벨"은 버렸다 (테마 문서 §7-3).
final class Generator {
  const Generator({
    required this.spawnChain,
    required this.odds,
    this.level = 1,
  });

  final ItemChain spawnChain;
  final SpawnOdds odds;
  final int level;

  int get maxLevel => odds.maxGeneratorLevel;

  bool get isMaxLevel => level >= maxLevel;

  Generator get upgraded =>
      Generator(spawnChain: spawnChain, odds: odds, level: level + 1);

  /// 같은 체인·같은 레벨이고 최고 레벨이 아니면 머지 가능.
  bool canMergeWith(Generator other) =>
      spawnChain == other.spawnChain && level == other.level && !isMaxLevel;

  /// 확률표로 레벨을 뽑아 아이템을 만든다. 체인 최고 레벨 미만으로 자른다 —
  /// 생성기가 산출원을 바로 만들지는 않는다.
  Item produce(Random random) =>
      Item(spawnChain, min(odds.roll(level, random), spawnChain.maxLevel - 1));

  @override
  bool operator ==(Object other) =>
      other is Generator &&
      other.spawnChain == spawnChain &&
      other.level == level;

  @override
  int get hashCode => Object.hash(spawnChain, level);

  @override
  String toString() => 'Generator(${spawnChain.id} G$level)';
}
