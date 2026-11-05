// 상점·스킨 뽑기 화면 흐름 (2026-11-04)
import 'package:bloom_wave/economy/gacha.dart';
import 'package:bloom_wave/economy/skins.dart';
import 'package:bloom_wave/save/save_store.dart';
import 'package:bloom_wave/screens/gacha_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

GachaScreenState gacha(WidgetTester tester) =>
    tester.state<GachaScreenState>(find.byType(GachaScreen));

Future<void> openGacha(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(h.app);
  await tester.pump();
  await tester.tap(byKey('btn-gacha'));
  await advance(tester, 500);
}

void main() {
  testWidgets('홈에 시작·상점·스킨 뽑기 버튼', (tester) async {
    await phone(tester);
    await tester.pumpWidget(Harness().app);
    await tester.pump();
    expect(byKey('btn-start'), findsOneWidget);
    expect(byKey('btn-shop'), findsOneWidget);
    expect(byKey('btn-gacha'), findsOneWidget);
  });

  testWidgets('뽑기: 머신 애니메이션 동안 결과를 숨기고, 끝나면 새 조각 패널. 골드는 바로 저장', (
    tester,
  ) async {
    await phone(tester);
    final h = Harness(data: SaveData(gold: 250));
    await openGacha(tester, h);
    expect(find.text('뽑기 · 100 골드'), findsOneWidget);
    await tester.tap(byKey('btn-pull'));
    await tester.pump();
    final g = gacha(tester);
    expect(g.anim.isAnimating, isTrue);
    expect(h.save.data.gold, 150); // 저장은 애니메이션 전에
    expect(find.text('탭하면 건너뛰기'), findsOneWidget);
    expect(byKey('overlay-gacha-newPiece'), findsNothing);
    await advance(tester, 1200);
    expect(byKey('overlay-gacha-newPiece'), findsNothing); // 아직 연출 중
    await advance(tester, 1700);
    expect(byKey('overlay-gacha-newPiece'), findsOneWidget);
    expect(find.text('새 조각!'), findsOneWidget);
    expect(find.text('조각 1/4'), findsOneWidget);
    expect(h.sfx.played, contains('coin'));
    final saved = await SaveStore(h.store).load();
    expect(saved.gold, 150);
    expect(saved.skinPieces.values.single.length, 1);
    await tester.tap(byKey('btn-gacha-ok'));
    await advance(tester, 300);
    expect(byKey('overlay-gacha-newPiece'), findsNothing);
  });

  testWidgets('머신을 탭하면 애니메이션을 건너뛴다', (tester) async {
    await phone(tester);
    final h = Harness(data: SaveData(gold: 100));
    await openGacha(tester, h);
    await tester.tap(byKey('btn-pull'));
    await advance(tester, 200);
    await tester.tap(byKey('gacha-machine'));
    await advance(tester, 300);
    expect(byKey('overlay-gacha-newPiece'), findsOneWidget);
  });

  testWidgets('중복 조각: 10% 반환 표시, 반환 골드는 연출이 끝난 뒤 보인다', (tester) async {
    await phone(tester);
    // 남은 후보가 이미 가진 조각뿐이 되도록: 한 스킨 3/4 보유 + 나머지 해금 → 후보 4개 중 3개가 중복
    final target = gachaSkins.first;
    final data = SaveData(
      gold: 100000,
      skinPieces: {
        for (final s in gachaSkins.skip(1))
          s.id: {for (var i = 0; i < s.pieces; i++) i},
        target.id: {0, 1, 2},
      },
    );
    var seed = 0;
    // 시드를 골라 중복이 나오게 한다 (규칙 함수로 미리 확인)
    while (true) {
      final copy = SaveData(
        gold: 100000,
        skinPieces: {
          for (final e in data.skinPieces.entries) e.key: {...e.value},
        },
      );
      if (pull(copy, Harness(seed: seed).services.rng).outcome ==
          PullOutcome.duplicate) {
        break;
      }
      seed++;
    }
    final h = Harness(data: data, seed: seed);
    await openGacha(tester, h);
    await tester.tap(byKey('btn-pull'));
    await tester.pump();
    expect(h.save.data.gold, 100000 - 100 + 10);
    // 연출 중에는 반환 전 금액
    expect(
      find.descendant(
        of: byKey('gacha-gold'),
        matching: find.text('${100000 - 100}'),
      ),
      findsOneWidget,
    );
    await advance(tester, 2800);
    expect(byKey('overlay-gacha-duplicate'), findsOneWidget);
    expect(find.text('+10 골드 돌려받음'), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('gacha-gold'),
        matching: find.text('${100000 - 90}'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('마지막 조각: 스킨 해금 → 바로 장착, 상점에서 장착 중', (tester) async {
    await phone(tester);
    final target = gachaSkins.first;
    final data = SaveData(
      gold: 100,
      skinPieces: {
        for (final s in gachaSkins.skip(1))
          s.id: {for (var i = 0; i < s.pieces; i++) i},
        target.id: {0, 1, 2},
      },
    );
    var seed = 0;
    while (true) {
      final copy = SaveData(
        gold: 100,
        skinPieces: {
          for (final e in data.skinPieces.entries) e.key: {...e.value},
        },
      );
      if (pull(copy, Harness(seed: seed).services.rng).outcome ==
          PullOutcome.unlocked) {
        break;
      }
      seed++;
    }
    final h = Harness(data: data, seed: seed);
    await openGacha(tester, h);
    await tester.tap(byKey('btn-pull'));
    await advance(tester, 2800);
    expect(byKey('overlay-gacha-unlocked'), findsOneWidget);
    expect(find.text('스킨 해금!'), findsOneWidget);
    await tester.tap(byKey('btn-equip-now'));
    await advance(tester, 300);
    expect(h.save.data.skin.id, target.id);
    // 모든 스킨 해금 → 뽑기 버튼 잠김
    expect(find.text('모든 스킨을 해금했어요!'), findsOneWidget);
    await tester.tap(byKey('btn-back'));
    await advance(tester, 500);
    await tester.tap(byKey('btn-shop'));
    await advance(tester, 500);
    await tester.ensureVisible(byKey('btn-equip-${target.id}'));
    expect(
      find.descendant(
        of: byKey('skin-${target.id}'),
        matching: find.text('장착 중'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('골드가 모자라면 뽑기 안 됨 (안내 문구, 골드 그대로)', (tester) async {
    await phone(tester);
    final h = Harness(data: SaveData(gold: 99));
    await openGacha(tester, h);
    await tester.tap(byKey('btn-pull'));
    await advance(tester, 300);
    expect(find.text('골드가 부족해요'), findsOneWidget);
    expect(h.save.data.gold, 99);
    expect(gacha(tester).anim.isAnimating, isFalse);
  });

  testWidgets('확률 보기: 규칙 함수와 같은 값, 해금된 스킨은 제외 표시', (tester) async {
    await phone(tester);
    final s0 = gachaSkins.first;
    final h = Harness(
      data: SaveData(
        skinPieces: {
          s0.id: {0, 1, 2, 3},
        },
      ),
    );
    await openGacha(tester, h);
    await tester.tap(byKey('btn-odds'));
    await advance(tester, 400);
    expect(byKey('overlay-odds'), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('odds-${s0.id}'),
        matching: find.text('해금됨 · 제외'),
      ),
      findsOneWidget,
    );
    for (final o in gachaOdds(h.save.data)) {
      if (o.chance == 0) continue;
      expect(
        find.descendant(
          of: byKey('odds-${o.skin.id}'),
          matching: find.text('${(o.chance * 100).toStringAsFixed(2)}%'),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('상점: 스킨 카드와 조각 진행도, 잠긴 스킨은 장착 불가, 기본 스킨은 장착 중', (tester) async {
    await phone(tester);
    final s = gachaSkins.elementAt(1);
    final h = Harness(
      data: SaveData(
        skinPieces: {
          s.id: {0, 2},
        },
      ),
    );
    await tester.pumpWidget(h.app);
    await tester.pump();
    await tester.tap(byKey('btn-shop'));
    await advance(tester, 500);
    expect(find.text('꽃 스킨'), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('skin-$defaultSkinId'),
        matching: find.text('장착 중'),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(byKey('skin-${s.id}'));
    expect(
      find.descendant(of: byKey('skin-${s.id}'), matching: find.text('조각 2/4')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: byKey('skin-${s.id}'), matching: find.text('잠김')),
      findsOneWidget,
    );
    await tester.tap(byKey('btn-equip-${s.id}'));
    await advance(tester, 200);
    expect(h.save.data.equippedSkin, defaultSkinId);
  });
}
