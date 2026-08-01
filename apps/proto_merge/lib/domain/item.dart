/// 아이템 체인(아이템셋) 정의.
///
/// 새 아이템셋 추가 = const 인스턴스를 하나 더 선언하고
/// 렌더링 쪽(item_component)의 색 테이블에 항목을 추가하면 끝.
final class ItemChain {
  const ItemChain({required this.id, required this.maxLevel});

  /// 체인 식별자. 렌더링·저장에서 키로 쓴다.
  final String id;

  /// 이 체인의 최고 레벨. 최고 레벨끼리는 머지되지 않는다.
  final int maxLevel;

  @override
  String toString() => 'ItemChain($id, max:$maxLevel)';
}

/// 프로토타입 기본 체인 (원형 + 숫자 1~5).
const ItemChain basicChain = ItemChain(id: 'basic', maxLevel: 5);

/// 보드 위 아이템 값 객체: 어떤 체인의 몇 레벨인가.
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
