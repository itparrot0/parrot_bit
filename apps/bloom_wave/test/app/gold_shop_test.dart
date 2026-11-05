// 골드 구매 (2026-11-05): 상점에 소모성 상품 4개, 최소 500 골드
import 'package:bloom_wave/economy/gold_packs.dart';
import 'package:bloom_wave/platform/billing.dart';
import 'package:bloom_wave/save/save_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<void> openShop(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(h.app);
  await tester.pump();
  await tester.tap(byKey('btn-shop'));
  await advance(tester, 600);
}

void main() {
  test('상품 4개: 최소 500, 클수록 양과 보너스가 늘고 id 가 겹치지 않는다', () {
    expect(goldPacks, hasLength(4));
    expect(goldPacks.first.total, 500);
    expect(goldPacks.first.bonus, 0);
    for (var i = 1; i < goldPacks.length; i++) {
      expect(goldPacks[i].total, greaterThan(goldPacks[i - 1].total));
      expect(
        goldPacks[i].bonusPercent,
        greaterThan(goldPacks[i - 1].bonusPercent),
      );
    }
    expect(goldPacks.map((p) => p.total), [500, 1100, 3000, 6500]);
    expect({for (final p in goldPacks) p.id}, hasLength(4));
    expect(Products.consumables, isNot(contains(Products.removeAds)));
    expect(goldPackById('gold_3000')!.total, 3000);
    expect(goldPackById('nope'), isNull);
    expect(withCommas(6500), '6,500');
    expect(withCommas(1234567), '1,234,567');
    expect(withCommas(500), '500');
  });

  test('같은 주문은 한 번만 지급하고, 주문 기록은 저장되며 최근 것만 남는다', () async {
    final kv = MemoryStore();
    final s = SaveStore(kv);
    await s.load();
    expect(await s.grantPurchasedGold('o1', 500), 500);
    expect(await s.grantPurchasedGold('o1', 500), 0);
    expect(s.data.gold, 500);
    final s2 = SaveStore(kv);
    await s2.load();
    expect(s2.data.orders, ['o1']);
    expect(await s2.grantPurchasedGold('o1', 500), 0);
    for (var i = 0; i < maxOrders + 5; i++) {
      await s2.grantPurchasedGold('x$i', 1);
    }
    expect(s2.data.orders, hasLength(maxOrders));
    expect(s2.data.orders.last, 'x${maxOrders + 4}');
    expect(migrate({'schema': 6}).orders, isEmpty);
  });

  testWidgets('상점 맨 위에 골드 상품 4개, 사면 골드가 바로 들어온다', (tester) async {
    await phone(tester);
    final h = Harness(data: SaveData(gold: 40));
    await openShop(tester, h);
    for (final p in goldPacks) {
      expect(byKey('gold-pack-${p.id}'), findsOneWidget);
    }
    expect(find.text('500'), findsWidgets);
    expect(find.text('6,500'), findsOneWidget);
    expect(find.text('+30% 보너스'), findsOneWidget);
    // 스토어 가격을 못 받으면 "구매"
    expect(find.text('구매'), findsNWidgets(4));
    await tester.tap(byKey('btn-buy-gold_1100'));
    await advance(tester, 600);
    expect(h.save.data.gold, 40 + 1100);
    expect(find.text('1,100 골드를 받았어요!'), findsOneWidget);
    expect(find.text('${40 + 1100}'), findsOneWidget); // 상단 골드 배지
  });

  testWidgets('대기·취소·실패는 지급하지 않고 안내만', (tester) async {
    await phone(tester);
    final h = Harness();
    await openShop(tester, h);
    for (final (r, text) in [
      (BuyResult.pending, '결제가 진행 중이에요.\n끝나면 골드가 들어와요'),
      (BuyResult.canceled, '결제를 취소했어요'),
      (BuyResult.failed, '결제를 완료하지 못했어요'),
    ]) {
      h.billing.next = r;
      await tester.tap(byKey('btn-buy-gold_500'));
      await advance(tester, 600);
      expect(find.text(text), findsOneWidget);
      expect(h.save.data.gold, 0);
      await tester.tap(find.text('확인'));
      await advance(tester, 400);
    }
  });

  testWidgets('결제가 나중에 끝나도(대기 결제) 지급 함수로 골드가 들어온다', (tester) async {
    await phone(tester);
    final h = Harness();
    await openShop(tester, h);
    await h.services.billing.onConsumable!('gold_3000', 'late-order');
    await advance(tester, 200);
    expect(h.save.data.gold, 3000);
    // 같은 결제가 다시 와도 한 번만
    await h.services.billing.onConsumable!('gold_3000', 'late-order');
    expect(h.save.data.gold, 3000);
    // 모르는 상품은 무시
    await h.services.billing.onConsumable!('remove_ads', 'x');
    expect(h.save.data.gold, 3000);
  });
}
