// 광고 보고 무료 뽑기 (2026-11-05): 하루 1번, 햇빛 광고 충전과 같은 아침 6시 초기화
import 'dart:math' as math;

import 'package:bloom_wave/economy/gacha.dart';
import 'package:bloom_wave/economy/skins.dart';
import 'package:bloom_wave/save/save_store.dart';
import 'package:bloom_wave/ui/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'shop_gacha_test.dart' show openGacha;

bool enabled(WidgetTester tester, String key) =>
    tester.widget<PillButton>(byKey(key)).enabled;

void main() {
  test('무료 뽑기: 골드를 내지 않고, 골드가 없어도 뽑으며, 중복이어도 돌려받지 않는다', () {
    final d = SaveData(gold: 0);
    expect(pullBlock(d), PullBlock.notEnoughGold);
    expect(pullBlock(d, free: true), isNull);
    final r = pull(d, math.Random(1), free: true);
    expect(r.cost, 0);
    expect(d.gold, 0);
    // 한 스킨만 남기고 그 조각 하나만 빼고 다 가진 상태에서 중복 만들기
    final skin = gachaSkins.first;
    final full = SaveData(
      gold: 0,
      skinPieces: {
        for (final s in gachaSkins)
          s.id: {for (var i = 0; i < s.pieces; i++) i},
      },
    );
    full.skinPieces[skin.id] = {0, 1, 2};
    var dup = false;
    for (var k = 0; k < 40 && !dup; k++) {
      final c = SaveData(
        gold: 0,
        skinPieces: {
          for (final e in full.skinPieces.entries) e.key: {...e.value},
        },
      );
      final rr = pull(c, math.Random(k), free: true);
      if (rr.outcome == PullOutcome.duplicate) {
        dup = true;
        expect(rr.refund, 0);
        expect(c.gold, 0);
      }
    }
    expect(dup, isTrue);
  });

  test('저장: 하루 1번, 아침 6시에 다시, schema 7 저장은 쓴 적 없음', () async {
    final s = SaveStore(MemoryStore());
    final day = DateTime(2026, 11, 5, 12);
    expect(s.data.adPullAvailable(day), isTrue);
    await s.pullSkinWithAd(math.Random(1), day);
    expect(s.data.adPullAvailable(day), isFalse);
    expect(
      () => s.pullSkinWithAd(math.Random(2), DateTime(2026, 11, 6, 5, 59)),
      throwsStateError,
    );
    expect(s.data.adPullAvailable(DateTime(2026, 11, 6, 6)), isTrue);
    expect(migrate({'schema': 7}).adPullDay, '');
    expect(migrate(s.data.toJson()).adPullDay, '2026-11-05');
  });

  testWidgets('뽑기 화면: 광고를 보면 골드 없이 뽑고, 오늘은 다시 못 하고, 6시에 다시 열린다', (
    tester,
  ) async {
    await phone(tester);
    final h = Harness(data: SaveData(gold: 30), now: DateTime(2026, 11, 5, 23));
    await openGacha(tester, h);
    expect(find.text('광고 보고 무료 뽑기 · 하루 1번'), findsOneWidget);
    expect(enabled(tester, 'btn-pull-ad'), isTrue);
    // 광고를 끝까지 안 보면 안내만
    h.ads.rewardOk = false;
    await tester.tap(byKey('btn-pull-ad'));
    await advance(tester, 300);
    expect(find.text('광고를 끝까지 봐야 뽑을 수 있어요'), findsOneWidget);
    expect(h.save.data.skinPieces, isEmpty);
    // 끝까지 보면 골드 그대로 뽑기 연출 → 새 조각
    h.ads.rewardOk = true;
    await tester.tap(byKey('btn-pull-ad'));
    await tester.pump();
    expect(h.ads.rewardedShown, 2);
    expect(h.save.data.gold, 30);
    expect(h.save.data.skinPieces.values.single.length, 1);
    await advance(tester, 3000);
    expect(byKey('overlay-gacha-newPiece'), findsOneWidget);
    await tester.tap(byKey('btn-gacha-ok'));
    await advance(tester, 300);
    expect(enabled(tester, 'btn-pull-ad'), isFalse);
    expect(find.text('무료 뽑기는 아침 6시에 다시'), findsOneWidget);
    // 6시 전에는 그대로, 6시가 지나면 다시 (화면을 다시 그리면)
    h.now = DateTime(2026, 11, 6, 5, 59);
    h.services.changed();
    await advance(tester, 100);
    expect(enabled(tester, 'btn-pull-ad'), isFalse);
    h.now = DateTime(2026, 11, 6, 6);
    h.services.changed();
    await advance(tester, 100);
    expect(enabled(tester, 'btn-pull-ad'), isTrue);
  });

  testWidgets('모든 스킨을 해금하면 무료 뽑기 버튼도 없다', (tester) async {
    await phone(tester);
    final h = Harness(
      data: SaveData(
        skinPieces: {
          for (final s in gachaSkins)
            s.id: {for (var i = 0; i < s.pieces; i++) i},
        },
      ),
    );
    await openGacha(tester, h);
    expect(byKey('btn-pull-ad'), findsNothing);
  });
}
