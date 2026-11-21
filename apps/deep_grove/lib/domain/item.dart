import 'zone.dart';

/// 아이템 체인(머지 계보 하나) 정의.
///
/// 최고 레벨에 닿은 조각은 [resource]를 내는 산출원이 되고,
/// [homeZone]에 놓이면 산출량 보너스를 받는다 (테마 문서 §4, §7-6).
final class ItemChain {
  const ItemChain({
    required this.id,
    required this.levelNames,
    required this.resource,
    required this.homeZone,
  });

  /// 체인 식별자. 렌더링·저장에서 키로 쓴다.
  final String id;

  /// 레벨별 이름 (1레벨부터). 길이가 곧 최고 레벨이다.
  final List<String> levelNames;

  /// 최고 레벨 산출원이 내는 자원.
  final Resource resource;

  /// 산출 보너스를 받는 지대.
  final Zone homeZone;

  int get maxLevel => levelNames.length;

  String nameOf(int level) => levelNames[level - 1];

  @override
  String toString() => 'ItemChain($id, max:$maxLevel)';
}

/// 보드 위 아이템 값 객체: 어떤 체인의 몇 레벨인가.
///
/// 최고 레벨 아이템은 보드에 남지 않는다 — 만들어지는 순간 산출원이 된다.
final class Item {
  const Item(this.chain, this.level);

  final ItemChain chain;
  final int level;

  bool get isMaxLevel => level >= chain.maxLevel;

  Item get upgraded => Item(chain, level + 1);

  /// 같은 체인·같은 레벨이고 최고 레벨이 아니면 머지 가능.
  bool canMergeWith(Item other) =>
      chain == other.chain && level == other.level && !isMaxLevel;

  @override
  bool operator ==(Object other) =>
      other is Item && other.chain == chain && other.level == level;

  @override
  int get hashCode => Object.hash(chain, level);

  @override
  String toString() => 'Item(${chain.id} L$level)';
}
