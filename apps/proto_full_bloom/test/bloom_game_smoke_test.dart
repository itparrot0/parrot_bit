import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proto_full_bloom/domain/domain.dart';
import 'package:proto_full_bloom/game/bloom_game.dart';
import 'package:proto_full_bloom/game/components/cell_component.dart';
import 'package:proto_full_bloom/levels/handmade_levels.dart';

import 'domain/test_levels.dart';

Future<BloomGame> pumpGame(WidgetTester tester, BloomLevel level) async {
  final game = BloomGame(level: level);
  await tester.pumpWidget(GameWidget(game: game));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 32));
  return game;
}

List<CellComponent> cellsOf(BloomGame game) =>
    game.world.children.whereType<CellComponent>().toList();

void main() {
  testWidgets('로드하면 칸마다 컴포넌트가 하나씩 생긴다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);

    expect(cellsOf(game), hasLength(HandmadeLevels.cross.cellCount));
  });

  testWidgets('시작 지점만 발아로 그려진다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);

    final sprouts = cellsOf(game).where((cell) => cell.cell.isSprout).toList();

    expect(sprouts, hasLength(1));
  });

  testWidgets('물뿌리개를 누르지 않으면 번호가 없다', (tester) async {
    // 전체 큐 순번은 색이 섞여 읽히지 않으므로 아예 띄우지 않는다.
    final game = await pumpGame(tester, HandmadeLevels.cross);

    expect(cellsOf(game).where((cell) => cell.waterOrder != null), isEmpty);
  });

  testWidgets('누른 물뿌리개가 피울 순서대로 1부터 번호가 붙는다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);
    game.takeFromLane(0); // 빨강 x2 — 중앙과 하를 피운다
    await tester.pump();

    // 레인 0의 다음 앞 = 파랑 x4. 큐에 파랑이 둘뿐이다.
    game.setPreview((color: BloomColor.blue, remaining: 4));
    await tester.pump();

    final numbered = {
      for (final cell in cellsOf(game))
        if (cell.waterOrder != null) cell.waterOrder!: cell.cell.color,
    };
    expect(numbered.keys.toList()..sort(), [1, 2]);
    expect(numbered.values.every((color) => color == BloomColor.blue), isTrue);
  });

  testWidgets('번호는 물뿌리개의 남은 횟수까지만 붙는다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);
    game.takeFromLane(0); // 빨강 x2 소진
    await tester.pump();

    // 빨강 x1을 누른 셈 치면, 큐에 빨강이 둘(상·하2) 있어도 번호는 1개다.
    game.setPreview((color: BloomColor.red, remaining: 1));
    await tester.pump();

    final orders = cellsOf(game)
        .where((cell) => cell.waterOrder != null)
        .map((cell) => cell.waterOrder!)
        .toList();
    expect(orders, [1]);
  });

  testWidgets('레인에서 꺼내면 보드가 피고 화면이 따라간다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);

    game.takeFromLane(0); // 빨강 x2
    await tester.pump();

    expect(game.board.wateredCount, 2);
    expect(cellsOf(game).where((cell) => cell.cell.isBloomed), hasLength(2));
    expect(cellsOf(game).where((cell) => cell.cell.isSprout), hasLength(4));
  });

  testWidgets('고리 번호가 시작 지점에서 하나씩 늘어난다', (tester) async {
    // 하·좌·우·상 한 싸이클이 한 고리다 — 연출이 이 단위로 묶여 터진다.
    final game = await pumpGame(tester, HandmadeLevels.cross);

    game.takeFromLane(0);
    await tester.pump();

    expect(game.board.depthOf((col: 2, row: 2)), 0); // 시작 지점
    expect(game.board.depthOf((col: 2, row: 3)), 1); // 하
    expect(game.board.depthOf((col: 1, row: 2)), 1); // 좌
    expect(game.board.depthOf((col: 2, row: 4)), 2); // 하2
    expect(game.board.chainDepth, 1); // 개화는 아직 고리 1까지
  });

  testWidgets('없는 레인을 눌러도 아무 일이 없다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);

    game.takeFromLane(5);

    expect(game.board.wateredCount, 0);
  });

  testWidgets('되돌리기가 화면까지 되돌린다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);

    game.takeFromLane(0);
    await tester.pump();
    game.undo();
    await tester.pump();

    expect(game.board.wateredCount, 0);
    expect(cellsOf(game).where((cell) => cell.cell.isBloomed), isEmpty);
  });

  testWidgets('미리보기를 켜면 다음에 피울 칸이 집힌다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);

    game.setPreview((color: BloomColor.red, remaining: 2));
    await tester.pump();

    final highlighted = cellsOf(game).where((cell) => cell.isNextTarget);
    expect(highlighted, hasLength(1));
    expect(highlighted.single.cell.color, BloomColor.red);
  });

  testWidgets('주차만 되는 수에도 통계 알림이 간다', (tester) async {
    // 회귀 버그: 아무것도 피지 않는 수(꺼내자마자 주차)는 기존 통계가 전부
    // 그대로라 레코드가 동일했고, ValueNotifier가 알림을 보내지 않아
    // 트레이(슬롯·레인)가 갱신되지 않았다. moves 필드가 이를 막는다.
    final game = await pumpGame(tester, TestLevels.deadlockable);
    final before = game.stats.value;

    game.takeFromLane(0); // 파랑 꺼냄 — 0칸 피우고 즉시 주차
    await tester.pump();

    expect(game.board.activeSlots[0], isNotNull); // 모델은 바뀌었고
    expect(game.stats.value, isNot(before)); // 통계도 반드시 바뀐다
    expect(game.stats.value.moves, before.moves + 1);
  });

  testWidgets('통계가 승리까지 따라온다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.tutorial);
    final report = BloomSolver.solve(HandmadeLevels.tutorial);

    for (final move in report.solution!) {
      if (move.fromLane) {
        game.takeFromLane(move.index);
      } else {
        game.useActive(move.index);
      }
      await tester.pump();
    }

    expect(game.stats.value.isWon, isTrue);
    expect(game.stats.value.bloomed, HandmadeLevels.tutorial.cellCount);
    expect(game.stats.value.isDeadlocked, isFalse);
  });
}
