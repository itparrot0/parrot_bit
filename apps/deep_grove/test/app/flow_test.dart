import 'package:core_storage/core_storage.dart';
import 'package:deep_grove/app.dart';
import 'package:deep_grove/domain/board_model.dart';
import 'package:deep_grove/economy/ad_rewards.dart';
import 'package:deep_grove/economy/economy.dart';
import 'package:deep_grove/economy/hints.dart';
import 'package:deep_grove/economy/providers.dart';
import 'package:deep_grove/game/components/expand_target_component.dart';
import 'package:deep_grove/game/grove_game.dart';
import 'package:deep_grove/economy/products.dart';
import 'package:deep_grove/platform/ads.dart';
import 'package:deep_grove/platform/billing.dart';
import 'package:deep_grove/save/save_repository.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers.dart';

final t0 = DateTime(2026, 11, 5, 9);

/// Flame 게임 루프가 프레임을 계속 요청하므로 pumpAndSettle 은 끝나지 않는다.
/// 시트 애니메이션이 끝날 만큼만 진행한다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 버튼을 누르면 바로 결과를 내는 광고.
class FakeAds implements RewardedAds {
  FakeAds({this.earns = true});

  bool earns;
  int shown = 0;

  @override
  Future<void> init() async {}

  @override
  Future<bool> show() async {
    shown++;
    return earns;
  }
}

/// 정해 둔 대로 답하는 결제.
class FakeBilling implements Billing {
  bool succeeds = true;
  List<String> restorable = const [];
  final List<String> bought = [];

  @override
  Future<Map<String, String>> prices(Set<String> productIds) async => {
    for (final id in productIds) id: '₩3,300',
  };

  @override
  Future<bool> purchase(String productId) async {
    if (succeeds) bought.add(productId);
    return succeeds;
  }

  @override
  Future<List<String>> restore() async => restorable;
}

Future<InMemoryKeyValueStore> pumpApp(
  WidgetTester tester, {
  InMemoryKeyValueStore? store,
  DateTime? now,
  FakeAds? ads,
  FakeBilling? billing,
}) async {
  final s = store ?? InMemoryKeyValueStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(s),
        clockProvider.overrideWithValue(() => now ?? t0),
        rewardedAdsProvider.overrideWithValue(ads ?? FakeAds()),
        billingProvider.overrideWithValue(billing ?? FakeBilling()),
      ],
      child: GroveApp(router: _freshRouter()),
    ),
  );
  await tester.pump();
  await settle(tester);
  return s;
}

GoRouter _freshRouter() => GoRouter(routes: groveRouter.configuration.routes);

GroveGame gameOf(WidgetTester tester) => tester
    .widget<GameWidget<GroveGame>>(find.byType(GameWidget<GroveGame>))
    .game!;

/// 확장 대상(잠긴 칸·완주 막대)을 탭한다.
Future<void> tapExpansion(WidgetTester tester, Expansion expansion) async {
  final game = gameOf(tester);
  final target = game.world.children
      .whereType<ExpandTargetComponent>()
      .firstWhere((t) => t.expansion == expansion);
  final origin = tester.getTopLeft(find.byType(GameWidget<GroveGame>));
  final p = game.camera.localToGlobal(target.position + target.size / 2);
  await tester.tapAt(origin + Offset(p.x, p.y));
  await settle(tester);
}

Future<void> saveWith(
  InMemoryKeyValueStore store,
  BoardModel board,
  Economy economy, {
  AdRewards ads = const AdRewards(),
}) => SaveRepository(
  store,
).write(GroveSave(board: board, economy: economy, ads: ads, savedAt: t0));

/// 숲의 거목 하나 + 빈 창고를 저장해 두고 2분 뒤에 연다 (복귀 보상 +9).
Future<InMemoryKeyValueStore> pumpReturning(
  WidgetTester tester, {
  required FakeAds ads,
  AdRewards adRewards = const AdRewards(),
}) async {
  final store = InMemoryKeyValueStore();
  final board = emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 5));
  await saveWith(
    store,
    board,
    const Economy(theme: forestCaveTheme),
    ads: adRewards,
  );
  await pumpApp(
    tester,
    store: store,
    now: t0.add(const Duration(minutes: 2)),
    ads: ads,
  );
  return store;
}

void main() {
  testWidgets('처음 실행: 목재 칸만 보이고 복귀 보상은 없다', (tester) async {
    await pumpApp(tester);
    expect(find.text('목재 0/30'), findsOneWidget);
    expect(find.textContaining('광석'), findsNothing);
    expect(find.text('자리를 비운 동안 쌓였어요'), findsNothing);
  });

  testWidgets('자원이 모자라면 확장 버튼이 막혀 있다', (tester) async {
    await pumpApp(tester);
    await tapExpansion(tester, const UnlockCell((col: 3, row: 0)));
    expect(find.text('숲 칸 열기'), findsOneWidget);
    expect(find.text('자원이 모자라요'), findsOneWidget);
  });

  testWidgets('동굴 진입: 비용을 내고 광석 칸·자갈 생성기·안내가 나타난다', (tester) async {
    final store = InMemoryKeyValueStore();
    await saveWith(
      store,
      BoardModel(forestCaveTheme),
      const Economy(theme: forestCaveTheme, amounts: {Resource.wood: 15}),
    );
    await pumpApp(tester, store: store);
    // 자원이 충분하면 확인 시트 없이 탭 한 번에 열린다.
    await tapExpansion(tester, const UnlockCell((col: 0, row: 4)));
    expect(find.text('확장'), findsNothing);

    expect(find.text('동굴에 들어섰어요'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await settle(tester);
    expect(find.text('목재 3/30'), findsOneWidget);
    expect(find.text('광석 0/30'), findsOneWidget);
    expect(gameOf(tester).board.isInside((col: 0, row: 4)), isTrue);
    expect(gameOf(tester).pieceAt((col: 0, row: 4)), isNotNull); // 자갈 생성기

    // 확장 결과가 저장됐다.
    final reloaded = await SaveRepository(store).load(forestCaveTheme, now: t0);
    expect(reloaded.board.caveEntered, isTrue);
    expect(reloaded.board.unlocked, hasLength(13));
    expect(reloaded.economy.amountOf(Resource.wood), 3);
  });

  testWidgets('복귀 보상: 쌓인 양을 보여 주고, 받으면 창고에 들어간다', (tester) async {
    final store = InMemoryKeyValueStore();
    final board = emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 5));
    await saveWith(store, board, const Economy(theme: forestCaveTheme));
    // 숲의 거목: 20초에 1.5 → 2분이면 9.
    await pumpApp(
      tester,
      store: store,
      now: t0.add(const Duration(minutes: 2)),
    );
    await settle(tester);
    expect(find.text('자리를 비운 동안 쌓였어요'), findsOneWidget);
    expect(find.text('+9'), findsOneWidget);
    await tester.tap(find.text('받기'));
    await settle(tester);
    expect(find.text('목재 9/30'), findsOneWidget);
  });

  testWidgets('창고가 거의 차 있으면 빈 공간만큼만 쌓인다', (tester) async {
    final store = InMemoryKeyValueStore();
    final board = emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 5));
    await saveWith(
      store,
      board,
      const Economy(theme: forestCaveTheme, amounts: {Resource.wood: 28}),
    );
    await pumpApp(tester, store: store, now: t0.add(const Duration(hours: 1)));
    await settle(tester);
    // 산출 자체가 빈 공간(2)에서 멈추므로 버려지는 양은 없다.
    expect(find.text('+2'), findsOneWidget);
    await tester.tap(find.text('받기'));
    await settle(tester);
    expect(find.text('목재 30/30 가득'), findsOneWidget);
  });

  testWidgets('창고 시트에서 자원으로 창고를 넓힌다', (tester) async {
    final store = InMemoryKeyValueStore();
    await saveWith(
      store,
      BoardModel(forestCaveTheme),
      const Economy(theme: forestCaveTheme, amounts: {Resource.wood: 25}),
    );
    await pumpApp(tester, store: store);
    await tester.tap(find.text('목재 25/30'));
    await settle(tester);
    await tester.tap(find.text('창고 확장 (목재 20)'));
    await settle(tester);
    expect(find.textContaining('5 / 60'), findsOneWidget);
  });

  testWidgets('상점·설정으로 갔다가 돌아온다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('상점'));
    await settle(tester);
    expect(find.text('창고 확장팩'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.byTooltip('설정'));
    await settle(tester);
    expect(find.text('구매 복원'), findsOneWidget);
    expect(find.text('복원'), findsOneWidget);
  });

  group('보상형 광고', () {
    testWidgets('복귀 보상: 광고를 끝까지 보면 2배로 받고 시청이 기록된다', (tester) async {
      final ads = FakeAds();
      final store = await pumpReturning(tester, ads: ads);
      expect(find.text('광고 보고 2배 (+9)'), findsOneWidget);
      await tester.tap(find.text('광고 보고 2배 (+9)'));
      await settle(tester);
      expect(ads.shown, 1);
      expect(find.text('목재 18/30'), findsOneWidget);
      final saved = await SaveRepository(store).load(forestCaveTheme, now: t0);
      expect(saved.ads.remainingToday(t0), 5);
    });

    testWidgets('복귀 보상: 광고를 중간에 닫으면 1배로 받는다', (tester) async {
      final ads = FakeAds(earns: false);
      await pumpReturning(tester, ads: ads);
      await tester.tap(find.text('광고 보고 2배 (+9)'));
      await settle(tester);
      expect(ads.shown, 1);
      expect(find.text('목재 9/30'), findsOneWidget);
    });

    testWidgets('오늘 광고를 다 봤으면 2배 버튼이 막힌다', (tester) async {
      var used = const AdRewards();
      for (var i = 0; i < 6; i++) {
        used = used.recordWatch(t0);
      }
      final ads = FakeAds();
      await pumpReturning(tester, ads: ads, adRewards: used);
      expect(find.text('오늘 광고를 다 봤어요'), findsOneWidget);
      await tester.tap(find.text('오늘 광고를 다 봤어요'));
      await settle(tester);
      expect(ads.shown, 0);
    });

    testWidgets('창고에서 광고를 보면 산출 2배 30분, 상단에 남은 시간이 뜬다', (tester) async {
      final ads = FakeAds();
      await pumpApp(tester, ads: ads);
      await tester.tap(find.text('목재 0/30'));
      await settle(tester);
      await tester.tap(find.text('광고 보고 산출 2배 30분 (오늘 6회 남음)'));
      await settle(tester);
      expect(ads.shown, 1);
      expect(find.text('산출 2배 — 남은 30분'), findsOneWidget);
      expect(find.text('광고 보고 산출 2배 30분 연장 (오늘 5회 남음)'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10)); // 시트 닫기
      await settle(tester);
      expect(find.text('2배 30분'), findsOneWidget);
    });
  });

  group('결제', () {
    Future<void> openShop(WidgetTester tester) async {
      await tester.tap(find.byTooltip('상점'));
      await settle(tester);
    }

    testWidgets('창고 확장팩을 사면 용량이 45가 되고 구매함으로 바뀐다, 저장된다', (tester) async {
      final billing = FakeBilling();
      final store = await pumpApp(tester, billing: billing);
      await openShop(tester);
      expect(find.text('₩3,300'), findsNWidgets(2));
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('product-storage_pack')),
          matching: find.text('₩3,300'),
        ),
      );
      await settle(tester);
      expect(billing.bought, ['storage_pack']);
      expect(find.text('구매함'), findsOneWidget);
      expect(find.text('창고 확장팩을 받았어요'), findsOneWidget);
      await tester.pageBack();
      await settle(tester);
      expect(find.text('목재 0/45'), findsOneWidget);
      final saved = await SaveRepository(store).load(forestCaveTheme, now: t0);
      expect(saved.economy.owned, {Product.storagePack});
    });

    testWidgets('결제를 취소하면 아무것도 받지 않는다', (tester) async {
      final billing = FakeBilling()..succeeds = false;
      await pumpApp(tester, billing: billing);
      await openShop(tester);
      await tester.tap(find.text('₩3,300').first);
      await settle(tester);
      expect(find.text('구매하지 않았어요'), findsOneWidget);
      expect(find.text('구매함'), findsNothing);
    });

    testWidgets('구매 복원: 스토어에 있는 상품을 다시 받는다', (tester) async {
      final billing = FakeBilling()..restorable = ['output_boost'];
      await pumpApp(tester, billing: billing);
      await openShop(tester);
      await tester.tap(find.text('복원'));
      await settle(tester);
      expect(find.text('복원했어요: 영구 산출 가속'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('product-output_boost')),
          matching: find.text('구매함'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('설정에서도 복원, 복원할 게 없으면 그렇게 알려 준다', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('설정'));
      await settle(tester);
      await tester.tap(find.text('복원'));
      await settle(tester);
      expect(find.text('복원할 구매가 없어요'), findsOneWidget);
    });

    testWidgets('영구 산출 가속이 있으면 창고 시트의 분당 산출이 1.5배', (tester) async {
      final store = InMemoryKeyValueStore();
      await saveWith(
        store,
        emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 5)),
        const Economy(theme: forestCaveTheme).grant([Product.outputBoost]),
      );
      await pumpApp(tester, store: store);
      await tester.tap(find.textContaining('목재 0/30'));
      await settle(tester);
      // 숲 거목: 분당 3 × 지대 1.5 × 상품 1.5 = 6.75
      expect(find.textContaining('분당 +6.8'), findsOneWidget);
    });
  });

  group('첫 실행 안내', () {
    testWidgets('처음 열면 손가락이 생성기를 가리키고, 누르면 사라진다 (저장됨)', (tester) async {
      final store = await pumpApp(tester);
      final game = gameOf(tester);
      expect(
        game.visibleHint,
        const CellHint(Hint.tapGenerator, (col: 1, row: 3)),
      );
      final origin = tester.getTopLeft(find.byType(GameWidget<GroveGame>));
      final p = game.camera.localToGlobal(game.cellCenter((col: 1, row: 3)));
      await tester.timedDragFrom(
        origin + Offset(p.x, p.y),
        const Offset(2, 0),
        const Duration(milliseconds: 100),
      );
      await settle(tester);
      expect(game.visibleHint, isNull);
      final saved = await SaveRepository(store).load(forestCaveTheme, now: t0);
      expect(saved.hints.isDone(Hint.tapGenerator), isTrue);
    });

    testWidgets('첫 확장 자원이 모이면 가장 싼 잠긴 칸을 가리키고, 열면 끝난다', (tester) async {
      final store = InMemoryKeyValueStore();
      await SaveRepository(store).write(
        GroveSave(
          board: BoardModel(forestCaveTheme),
          economy: const Economy(
            theme: forestCaveTheme,
            amounts: {Resource.wood: 1},
          ),
          hints: const Hints().complete(Hint.tapGenerator),
          savedAt: t0,
        ),
      );
      await pumpApp(tester, store: store);
      final game = gameOf(tester);
      expect(game.visibleHint, isNull); // 목재 1 < 숲 첫 칸 2

      // 목재 1을 더 받으면 숲 첫 칸을 열 수 있다.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GameWidget<GroveGame>)),
      );
      container.read(economyProvider.notifier).deposit(Resource.wood, 1);
      await settle(tester);
      expect(
        game.visibleHint,
        const UnlockHint(Hint.firstExpand, (col: 3, row: 0)),
      );

      await tapExpansion(tester, const UnlockCell((col: 3, row: 0)));
      expect(game.visibleHint, isNull);
      expect(container.read(hintsProvider).isDone(Hint.firstExpand), isTrue);
    });

    testWidgets('이미 놀던 옛 저장에는 안내를 띄우지 않는다', (tester) async {
      final store = InMemoryKeyValueStore();
      await saveWith(
        store,
        BoardModel(forestCaveTheme)..unlock((col: 3, row: 0)),
        const Economy(theme: forestCaveTheme, amounts: {Resource.wood: 30}),
      );
      // saveWith 는 hints 를 기본값(빈 목록)으로 쓰므로, 옛 저장처럼 칸을 지운다.
      final raw = (await store.getString(SaveRepository.key))!;
      await store.setString(
        SaveRepository.key,
        raw.replaceFirst(RegExp(r',"hints":\[[^\]]*\]'), ''),
      );
      await pumpApp(tester, store: store);
      expect(gameOf(tester).visibleHint, isNull);
    });
  });

  testWidgets('산출원을 버리기 칸에 놓으면 확인 창이 뜨고, 버리면 저장된다', (tester) async {
    final store = InMemoryKeyValueStore();
    await saveWith(
      store,
      emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 5)),
      const Economy(theme: forestCaveTheme),
    );
    await pumpApp(tester, store: store);
    final game = gameOf(tester);
    final origin = tester.getTopLeft(find.byType(GameWidget<GroveGame>));
    Offset screen(Vector2 w) {
      final p = game.camera.localToGlobal(w);
      return origin + Offset(p.x, p.y);
    }

    final start = screen(game.cellCenter(at(0, 0)));
    final bin = screen(
      Vector2(
        game.board.columns * kCellSize / 2,
        game.board.rows * kCellSize + 40,
      ),
    );
    await tester.timedDragFrom(
      start,
      bin - start,
      const Duration(milliseconds: 300),
    );
    await settle(tester);
    expect(find.text('거목을 버릴까요?'), findsOneWidget);
    await tester.tap(find.text('버리기').last);
    await settle(tester);
    expect(game.board.producers, isEmpty);
    final saved = await SaveRepository(store).load(forestCaveTheme, now: t0);
    expect(saved.board.producers, isEmpty);
  });

  group('확인 시트 생략', () {
    testWidgets('자원이 충분한 잠긴 칸은 탭 한 번에 열리고 비용이 빠진다', (tester) async {
      final store = InMemoryKeyValueStore();
      await saveWith(
        store,
        BoardModel(forestCaveTheme),
        const Economy(theme: forestCaveTheme, amounts: {Resource.wood: 5}),
      );
      await pumpApp(tester, store: store);
      await tapExpansion(tester, const UnlockCell((col: 3, row: 1)));
      expect(find.text('숲 칸 열기'), findsNothing);
      expect(gameOf(tester).board.isInside((col: 3, row: 1)), isTrue);
      expect(find.text('목재 3/30'), findsOneWidget);
      // 바로 다음 칸(숲 2번째, 목재 3)도 한 번에
      await tapExpansion(tester, const UnlockCell((col: 3, row: 2)));
      expect(find.text('목재 0/30'), findsOneWidget);
    });

    testWidgets('모자라면 시트로 무엇이 모자란지 보여 주고 열지 않는다', (tester) async {
      await pumpApp(tester);
      await tapExpansion(tester, const UnlockCell((col: 3, row: 1)));
      expect(find.text('숲 칸 열기'), findsOneWidget);
      expect(find.text('0 / 2'), findsOneWidget);
      expect(find.text('자원이 모자라요'), findsOneWidget);
      expect(gameOf(tester).board.isInside((col: 3, row: 1)), isFalse);
    });

    testWidgets('테마 완주는 자원이 있어도 확인을 받는다', (tester) async {
      final store = InMemoryKeyValueStore();
      await saveWith(
        store,
        emptyBoard()..openAll(),
        const Economy(
          theme: forestCaveTheme,
          amounts: {Resource.wood: 100, Resource.ore: 100},
          storageLevel: 2,
        ),
      );
      await pumpApp(tester, store: store);
      await tapExpansion(tester, const ClearTheme());
      expect(find.text('테마 완주'), findsWidgets);
      expect(find.text('확장'), findsOneWidget);
      await tester.tap(find.text('확장'));
      await settle(tester);
      expect(find.text('동굴이 있는 숲을 완성했어요'), findsOneWidget);
    });
  });
}
