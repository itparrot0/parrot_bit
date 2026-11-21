import 'package:deep_grove/domain/board_model.dart';
import 'package:deep_grove/economy/ad_rewards.dart';
import 'package:deep_grove/economy/economy.dart';
import 'package:deep_grove/economy/products.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  const theme = forestCaveTheme;

  test('창고 확장팩: 모든 창고 단계의 용량이 1.5배 (내림)', () {
    for (var level = 0; level < theme.storageCapacities.length; level++) {
      final plain = Economy(theme: theme, storageLevel: level);
      final packed = plain.grant([Product.storagePack]);
      expect(packed.capacity, (plain.capacity * 1.5).floor());
    }
    expect(const Economy(theme: theme).grant([Product.storagePack]).freeSpace, {
      Resource.wood: 45,
      Resource.ore: 45,
    });
  });

  test('영구 산출 가속: 배율 1.5, 없으면 1', () {
    const plain = Economy(theme: theme);
    expect(plain.outputMultiplier, 1);
    expect(plain.grant([Product.outputBoost]).outputMultiplier, 1.5);
  });

  test('grant는 중복 지급해도 한 번만 갖는다', () {
    final e = const Economy(theme: theme).grant([Product.storagePack]).grant([
      Product.storagePack,
      Product.outputBoost,
    ]);
    expect(e.owned, {Product.storagePack, Product.outputBoost});
  });

  test('산 상품은 저장되고, 상품 칸이 없는 옛 저장·모르는 id도 읽는다', () {
    final e = const Economy(theme: theme).grant([Product.outputBoost]);
    expect(Economy.fromJson(e.toJson(), theme).owned, {Product.outputBoost});

    final old = e.toJson()..remove('owned');
    expect(Economy.fromJson(old, theme).owned, isEmpty);

    final unknown = e.toJson()..['owned'] = ['output_boost', 'gone_product'];
    expect(Economy.fromJson(unknown, theme).owned, {Product.outputBoost});
  });

  test('영구 가속은 광고 가속과 곱해져 오프라인 산출에 걸린다', () {
    final morning = DateTime(2026, 11, 5, 9);
    final board = emptyBoard()
      ..openCaveRow()
      ..placeItem(at(0, 4), const Item(woodChain, 5)); // 동굴: 20초에 1
    final ads = const AdRewards().startBoost(morning);
    // 1시간: 앞 30분 2×1.5(270) + 뒤 30분 1.5(135) = 405
    final gain = ads.advanceAway(
      board,
      morning,
      morning.add(const Duration(hours: 1)),
      plenty,
      baseMultiplier: 1.5,
    );
    expect(gain, {Resource.wood: 405});
  });
}
