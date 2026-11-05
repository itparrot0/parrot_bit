import 'package:deep_grove/domain/board_model.dart';
import 'package:deep_grove/economy/economy.dart';
import 'package:deep_grove/game/components/expand_handle_component.dart';
import 'package:deep_grove/game/components/generator_component.dart';
import 'package:deep_grove/game/components/item_component.dart';
import 'package:deep_grove/game/components/producer_component.dart';
import 'package:deep_grove/game/grove_game.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// 창고를 흉내 내는 브리지. 넣은 양과 확장 요청을 기록한다.
class FakeBridge implements GroveBridge {
  Economy economy = const Economy(theme: forestCaveTheme);
  final List<ExpandDirection> requested = [];
  int changes = 0;
  double multiplier = 1;

  @override
  double rateMultiplier() => multiplier;

  @override
  Map<Resource, int> freeSpace() => economy.freeSpace;

  @override
  int deposit(Resource resource, int amount) {
    final (next, accepted) = economy.add(resource, amount);
    economy = next;
    return accepted;
  }

  @override
  ({Cost cost, bool affordable})? expansionOffer(ExpandDirection direction) =>
      switch (economy.expansionCost(direction, _board!)) {
        null => null,
        final cost => (cost: cost, affordable: economy.canAfford(cost)),
      };

  BoardModel? _board;

  @override
  void onExpandRequested(ExpandDirection direction) => requested.add(direction);

  @override
  void onBoardChanged() => changes++;
}

Future<(GroveGame, FakeBridge)> pumpGame(
  WidgetTester tester, {
  BoardModel? board,
}) async {
  final bridge = FakeBridge();
  final model = board ?? BoardModel(forestCaveTheme);
  bridge._board = model;
  final game = GroveGame(board: model, bridge: bridge);
  await tester.pumpWidget(GameWidget(game: game));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 32));
  return (game, bridge);
}

Offset screenOf(WidgetTester tester, GroveGame game, Vector2 world) {
  final origin = tester.getTopLeft(find.byType(GameWidget<GroveGame>));
  final p = game.camera.localToGlobal(world);
  return origin + Offset(p.x, p.y);
}

Future<void> dragCell(
  WidgetTester tester,
  GroveGame game,
  CellPos from,
  CellPos to,
) async {
  final start = screenOf(tester, game, game.cellCenter(from));
  final end = screenOf(tester, game, game.cellCenter(to));
  await tester.timedDragFrom(
    start,
    end - start,
    const Duration(milliseconds: 300),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// 드래그·탭 판정이 같은 경로를 타므로, 제자리 짧은 드래그로 탭을 낸다.
Future<void> tapCell(WidgetTester tester, GroveGame game, CellPos pos) async {
  final p = screenOf(tester, game, game.cellCenter(pos));
  await tester.timedDragFrom(
    p,
    const Offset(2, 0),
    const Duration(milliseconds: 100),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('시작 보드: 생성기 1, 씨앗 2, 손잡이 2 (넓히기·동굴 진입)', (tester) async {
    final (game, _) = await pumpGame(tester);
    expect(game.world.children.whereType<GeneratorComponent>(), hasLength(1));
    expect(game.world.children.whereType<ItemComponent>(), hasLength(2));
    final handles = game.world.children.whereType<ExpandHandleComponent>();
    expect(handles.map((h) => h.direction).toSet(), {
      ExpandDirection.widen,
      ExpandDirection.dig,
    });
  });

  testWidgets('씨앗 두 개를 드래그드롭으로 머지하면 새싹이 된다', (tester) async {
    final (game, bridge) = await pumpGame(tester);
    await dragCell(tester, game, at(0, 3), at(2, 3));
    expect(game.board.contentAt(at(0, 3)), isNull);
    expect(
      (game.board.contentAt(at(2, 3))! as ItemContent).item,
      const Item(woodChain, 2),
    );
    expect(game.world.children.whereType<ItemComponent>(), hasLength(1));
    expect(bridge.changes, greaterThan(0));
  });

  testWidgets('나무 두 그루를 머지하면 거목 산출원 컴포넌트가 생긴다', (tester) async {
    final board = emptyBoard()
      ..placeItem(at(0, 0), const Item(woodChain, 4))
      ..placeItem(at(1, 0), const Item(woodChain, 4));
    final (game, _) = await pumpGame(tester, board: board);
    await dragCell(tester, game, at(0, 0), at(1, 0));
    expect(game.world.children.whereType<ProducerComponent>(), hasLength(1));
    expect(game.world.children.whereType<ItemComponent>(), isEmpty);
  });

  testWidgets('산출원을 탭하면 다 익은 목재가 창고로 간다', (tester) async {
    final board = emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 5));
    final (game, bridge) = await pumpGame(tester, board: board);
    board.advance(40, plenty); // 숲 보너스 1.5배 → 3
    await tapCell(tester, game, at(0, 0));
    expect(bridge.economy.amountOf(Resource.wood), 3);
  });

  testWidgets('브리지 배율이 2면 게임 틱 산출도 2배다', (tester) async {
    final board = emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 5));
    final (game, bridge) = await pumpGame(tester, board: board);
    bridge.multiplier = 2;
    game.update(10); // 숲 보너스 1.5 × 가속 2 × 10초 / 20초 = 1.5
    expect(board.pending[Resource.wood], closeTo(1.5, 0.05));
  });

  testWidgets('생성기를 탭하면 빈 칸에 씨앗이 생긴다', (tester) async {
    final (game, _) = await pumpGame(tester);
    await tapCell(tester, game, at(1, 3));
    expect(game.world.children.whereType<ItemComponent>(), hasLength(3));
    expect(game.board.cells, hasLength(4));
  });

  testWidgets('동굴 진입: 행이 늘고 자갈 생성기가 등장한다', (tester) async {
    final (game, _) = await pumpGame(tester);
    game.applyExpansion(ExpandDirection.dig);
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.board.rows, 5);
    final generators = game.world.children.whereType<GeneratorComponent>();
    expect(generators.map((g) => g.generator.spawnChain).toSet(), {
      woodChain,
      stoneChain,
    });
  });
}
