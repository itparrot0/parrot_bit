// 스킨 뽑기 규칙 (2026-11-04). 화면과 분리된 순수 로직 — 상점의 "확률 보기"도 여기 값을 그대로 읽는다.
//
//  - 한 번 뽑는 데 [GachaConfig.pullCost] 골드.
//  - 아직 해금하지 않은 스킨의 퍼즐 조각 전체가 후보이고, 조각 하나하나가 같은 확률이다.
//    (그래서 이미 가진 조각도 다시 나올 수 있다 = 중복)
//  - 중복 조각이면 뽑기 골드의 10% 를 돌려준다 ([GachaConfig.refund]).
//  - 한 스킨의 조각을 모두 모으면 해금되고, 그 뒤로는 그 스킨의 조각이 후보에서 빠진다.
//  - 모든 스킨을 해금하면 뽑기를 할 수 없다.
//  - 무료 뽑기 (2026-11-05): 보상형 광고를 끝까지 보면 하루 1번 골드 없이 뽑는다 (햇빛 광고 충전과 같은 아침 6시 초기화).
//    중복 조각이면 일반 뽑기와 같이 [GachaConfig.refund] 골드를 돌려준다.
import 'dart:math' as math;

import '../save/save_store.dart';
import 'skins.dart';

class GachaConfig {
  /// 한 번 뽑는 데 드는 골드 — 조절 지점
  static const int pullCost = 100;

  /// 중복 조각일 때 돌려주는 비율
  static const double refundRate = 0.10;

  /// 중복 조각일 때 돌려주는 골드 (소수점 아래 버림)
  static int get refund => (pullCost * refundRate).floor();
}

/// 후보 조각 하나
typedef Piece = ({SkinDef skin, int index});

/// 지금 뽑기 후보 (해금하지 않은 스킨의 모든 조각)
List<Piece> gachaPool(SaveData d) => [
  for (final s in gachaSkins)
    if (!d.isUnlocked(s))
      for (var i = 0; i < s.pieces; i++) (skin: s, index: i),
];

class SkinOdds {
  const SkinOdds(this.skin, this.chance, this.perPiece);
  final SkinDef skin;

  /// 이 스킨의 조각 중 하나가 나올 확률 (0~1). 해금된 스킨은 0
  final double chance;

  /// 조각 하나의 확률
  final double perPiece;
}

/// 확률 공개용: 스킨별 확률. 합은 (후보가 있으면) 1
List<SkinOdds> gachaOdds(SaveData d) {
  final n = gachaPool(d).length;
  return [
    for (final s in gachaSkins)
      if (d.isUnlocked(s) || n == 0)
        SkinOdds(s, 0, 0)
      else
        SkinOdds(s, s.pieces / n, 1 / n),
  ];
}

enum PullBlock { notEnoughGold, allUnlocked }

/// 지금 뽑을 수 없는 이유 (뽑을 수 있으면 null). free 면 골드는 보지 않는다
PullBlock? pullBlock(SaveData d, {bool free = false}) {
  if (gachaPool(d).isEmpty) return PullBlock.allUnlocked;
  if (!free && d.gold < GachaConfig.pullCost) return PullBlock.notEnoughGold;
  return null;
}

enum PullOutcome {
  /// 처음 얻은 조각
  newPiece,

  /// 이미 가진 조각 → 골드 일부 반환
  duplicate,

  /// 이 조각으로 스킨의 조각을 모두 모음 → 해금
  unlocked,
}

class PullResult {
  const PullResult({
    required this.skin,
    required this.piece,
    required this.outcome,
    required this.cost,
    required this.refund,
  });
  final SkinDef skin;
  final int piece;
  final PullOutcome outcome;
  final int cost;
  final int refund;
}

/// 한 번 뽑는다. d 를 바로 바꾼다 (골드 차감·조각 추가·반환). 뽑을 수 없으면 StateError.
/// free = 무료 뽑기(광고): 골드를 내지 않는다. 중복 반환은 일반 뽑기와 같다
PullResult pull(SaveData d, math.Random rng, {bool free = false}) {
  final block = pullBlock(d, free: free);
  if (block != null) throw StateError('cannot pull: ${block.name}');
  final pool = gachaPool(d);
  final p = pool[rng.nextInt(pool.length)];
  final cost = free ? 0 : GachaConfig.pullCost;
  d.gold -= cost;
  final owned = d.skinPieces.putIfAbsent(p.skin.id, () => <int>{});
  if (!owned.add(p.index)) {
    final refund = GachaConfig.refund;
    d.gold += refund;
    return PullResult(
      skin: p.skin,
      piece: p.index,
      outcome: PullOutcome.duplicate,
      cost: cost,
      refund: refund,
    );
  }
  return PullResult(
    skin: p.skin,
    piece: p.index,
    outcome: d.isUnlocked(p.skin) ? PullOutcome.unlocked : PullOutcome.newPiece,
    cost: cost,
    refund: 0,
  );
}
