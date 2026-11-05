import 'package:deep_grove/domain/board_model.dart';
import 'package:deep_grove/economy/economy.dart';
import 'package:deep_grove/game/components/expand_target_component.dart';
import 'package:deep_grove/game/components/generator_component.dart';
import 'package:deep_grove/game/components/item_component.dart';
import 'package:deep_grove/game/components/producer_component.dart';
import 'package:deep_grove/game/grove_game.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// 창고를 흉내 내는 브리지. 넣은 양과 확장 요청을 기록한다.
class FakeBridge implements GroveBridge {
  Economy economy = const Economy(theme: forestCaveTheme);
  final List<Expansion> requested = [];
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
  ({Cost cost, bool affordable})? expansionOffer(Expansion expansion) =>
      switch (economy.expansionCost(expansion, _board!)) {
        null => null,
        final cost => (cost: cost, affordable: economy.canAfford(cost)),
      };

  BoardModel? _board;

  @override
  void onExpandRequested(Expansion expansion) => requested.add(expansion);

  @override
  void onBoardChanged() => changes++;

  int spawns = 0;

  @override
  void onSpawned() => spawns++;
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
  testWidgets('시작 보드: 생성기 1, 씨앗 2, 열 수 있는 잠긴 칸 7', (tester) async {
    final (game, _) = await pumpGame(tester);
    expect(game.world.children.whereType<GeneratorComponent>(), hasLength(1));
    expect(game.world.children.whereType<ItemComponent>(), hasLength(2));
    final targets = game.world.children.whereType<ExpandTargetComponent>();
    expect(
      targets.map((t) => (t.expansion as UnlockCell).pos).toSet(),
      game.board.frontier.toSet(),
    );
  });

  testWidgets('잠긴 칸을 탭하면 그 칸을 여는 확장을 요청한다', (tester) async {
    final (game, bridge) = await pumpGame(tester);
    final p = screenOf(tester, game, game.cellCenter(at(3, 2)));
    await tester.tapAt(p);
    await tester.pump(const Duration(milliseconds: 100));
    expect(bridge.requested, [const UnlockCell((col: 3, row: 2))]);
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

  testWidgets('동굴 진입: 칸이 열리고 그 칸에 자갈 생성기가 등장한다', (tester) async {
    final (game, _) = await pumpGame(tester);
    game.applyExpansion(const UnlockCell((col: 2, row: 4)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.board.isInside(at(2, 4)), isTrue);
    expect(game.board.rows, 6); // 열린 칸 아래 잠긴 칸까지 그린다
    final generators = game.world.children.whereType<GeneratorComponent>();
    expect(generators.map((g) => g.generator.spawnChain).toSet(), {
      woodChain,
      stoneChain,
    });
    expect(game.pieceAt(at(2, 4)), isA<GeneratorComponent>());
  });

  group('드래그 중 지대 밝히기', () {
    Future<TestGesture> hold(
      WidgetTester tester,
      GroveGame game,
      CellPos pos,
    ) async {
      final start = screenOf(tester, game, game.cellCenter(pos));
      final gesture = await tester.startGesture(start);
      for (var i = 1; i <= 5; i++) {
        await gesture.moveTo(start + Offset(8.0 * i, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      return gesture;
    }

    BoardModel caveBoard() => emptyBoard()
      ..openCaveRow()
      ..placeItem(at(0, 0), const Item(stoneChain, 5))
      ..placeItem(at(1, 0), const Item(woodChain, 3));

    testWidgets('광석바위를 들면 동굴 칸만 밝아지고, 놓으면 꺼진다', (tester) async {
      final (game, _) = await pumpGame(tester, board: caveBoard());
      final gesture = await hold(tester, game, at(0, 0));
      expect(game.isLit(at(0, 4)), isTrue);
      expect(game.isLit(at(2, 4)), isTrue);
      expect(game.isLit(at(2, 2)), isFalse);
      await gesture.moveTo(screenOf(tester, game, game.cellCenter(at(2, 4))));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(game.isLit(at(0, 4)), isFalse);
      expect(game.board.hasZoneBonus(at(2, 4)), isTrue);
    });

    testWidgets('보너스와 상관없는 조각을 들면 아무 칸도 밝아지지 않는다', (tester) async {
      final (game, _) = await pumpGame(tester, board: caveBoard());
      final gesture = await hold(tester, game, at(1, 0));
      for (final pos in [at(0, 0), at(0, 4)]) {
        expect(game.isLit(pos), isFalse);
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('자기 지대의 산출원에만 배율 표시가 붙는다', (tester) async {
      final board = emptyBoard()
        ..openCaveRow()
        ..placeItem(at(0, 0), const Item(woodChain, 5))
        ..placeItem(at(0, 4), const Item(woodChain, 5));
      final (game, _) = await pumpGame(tester, board: board);
      await tester.pump(const Duration(milliseconds: 50));
      String labelsOf(CellPos pos) => game
          .pieceAt(pos)!
          .descendants()
          .whereType<TextComponent>()
          .map((t) => t.text)
          .join('|');
      expect(labelsOf(at(0, 0)), contains('×1.5'));
      // 스킨이 나중에 붙어도 라벨이 가려지지 않게 위에 그린다.
      final bonus = game
          .pieceAt(at(0, 0))!
          .descendants()
          .whereType<TextComponent>()
          .firstWhere((t) => t.text == '×1.5');
      expect(bonus.priority, greaterThan(0));
      expect(labelsOf(at(0, 4)), isNot(contains('×1.5')));
    });
  });
}
