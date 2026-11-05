import 'package:core_storage/core_storage.dart';
import 'package:deep_grove/app.dart';
import 'package:deep_grove/domain/board_model.dart';
import 'package:deep_grove/economy/economy.dart';
import 'package:deep_grove/economy/providers.dart';
import 'package:deep_grove/game/components/expand_handle_component.dart';
import 'package:deep_grove/game/grove_game.dart';
import 'package:deep_grove/save/save_repository.dart';
import 'package:flame/game.dart';
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

Future<InMemoryKeyValueStore> pumpApp(
  WidgetTester tester, {
  InMemoryKeyValueStore? store,
  DateTime? now,
}) async {
  final s = store ?? InMemoryKeyValueStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(s),
        clockProvider.overrideWithValue(() => now ?? t0),
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

Future<void> tapHandle(WidgetTester tester, ExpandDirection direction) async {
  final game = gameOf(tester);
  final handle = game.world.children
      .whereType<ExpandHandleComponent>()
      .firstWhere((h) => h.direction == direction);
  final origin = tester.getTopLeft(find.byType(GameWidget<GroveGame>));
  final p = game.camera.localToGlobal(handle.position + handle.size / 2);
  await tester.tapAt(origin + Offset(p.x, p.y));
  await settle(tester);
}

Future<void> saveWith(
  InMemoryKeyValueStore store,
  BoardModel board,
  Economy economy,
) => SaveRepository(
  store,
).write(GroveSave(board: board, economy: economy, savedAt: t0));

void main() {
  testWidgets('처음 실행: 목재 칸만 보이고 복귀 보상은 없다', (tester) async {
    await pumpApp(tester);
    expect(find.text('목재 0/30'), findsOneWidget);
    expect(find.textContaining('광석'), findsNothing);
    expect(find.text('자리를 비운 동안 쌓였어요'), findsNothing);
  });

  testWidgets('자원이 모자라면 확장 버튼이 막혀 있다', (tester) async {
    await pumpApp(tester);
    await tapHandle(tester, ExpandDirection.widen);
    expect(find.text('숲 넓히기'), findsOneWidget);
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
    await tapHandle(tester, ExpandDirection.dig);
    expect(find.text('동굴 진입'), findsWidgets);
    await tester.tap(find.text('확장'));
    await settle(tester);

    expect(find.text('동굴에 들어섰어요'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await settle(tester);
    expect(find.text('목재 3/30'), findsOneWidget);
    expect(find.text('광석 0/30'), findsOneWidget);
    expect(gameOf(tester).board.caveRows, 1);

    // 확장 결과가 저장됐다.
    final reloaded = await SaveRepository(store).load(forestCaveTheme, now: t0);
    expect(reloaded.board.caveRows, 1);
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
  });
}
