import 'dart:math';

import 'item.dart';

/// 보드 위 생성기 정의: 탭하면 자기 레벨과 같은 레벨의 아이템을 만든다.
///
/// 아이템처럼 드래그로 이동하고, 같은 체인·같은 레벨끼리 머지해
/// 레벨을 올릴 수 있다. 위치는 [BoardModel]의 칸 점유 상태가 소유한다.
final class Generator {
  const Generator({
    required this.spawnChain,
    this.level = 1,
    this.maxLevel = 3,
  });

  final ItemChain spawnChain;
  final int level;
  final int maxLevel;

  bool get isMaxLevel => level >= maxLevel;

  Generator get upgraded =>
      Generator(spawnChain: spawnChain, level: level + 1, maxLevel: maxLevel);

  /// 같은 체인·같은 레벨이고 최고 레벨이 아니면 머지 가능.
  bool canMergeWith(Generator other) =>
      spawnChain == other.spawnChain &&
      level == other.level &&
      maxLevel == other.maxLevel &&
      !isMaxLevel;

  /// 생성기 레벨 = 스폰 아이템 레벨 (체인 최고 레벨을 넘지 않게).
  Item produce() => Item(spawnChain, min(level, spawnChain.maxLevel));

  @override
  bool operator ==(Object other) =>
      other is Generator &&
      other.spawnChain == spawnChain &&
      other.level == level &&
      other.maxLevel == maxLevel;

  @override
  int get hashCode => Object.hash(spawnChain, level, maxLevel);

  @override
  String toString() => 'Generator(${spawnChain.id} G$level)';
}
