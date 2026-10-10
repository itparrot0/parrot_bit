import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proto_full_bloom/domain/domain.dart';
import 'package:proto_full_bloom/game/bloom_game.dart';
import 'package:proto_full_bloom/game/components/cell_component.dart';
import 'package:proto_full_bloom/levels/handmade_levels.dart';

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

  testWidgets('시작 지점만 꽃송이로 그려지고 큐 순번을 갖는다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);

    final buds = cellsOf(game).where((cell) => cell.cell.isBud).toList();

    expect(buds, hasLength(1));
    expect(buds.single.queueIndex, 1);
  });

  testWidgets('슬롯을 쓰면 보드가 피고 화면이 따라간다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);

    game.useSlot(0); // 빨강 x2
    await tester.pump();

    expect(game.board.wateredCount, 2);
    expect(cellsOf(game).where((cell) => cell.cell.isBloomed), hasLength(2));
    // 큐 순번은 1부터 빈틈없이 다시 매겨진다.
    final indexes =
        cellsOf(game)
            .where((cell) => cell.cell.isBud)
            .map((cell) => cell.queueIndex!)
            .toList()
          ..sort();
    expect(indexes, [1, 2, 3, 4]);
  });

  testWidgets('쓸 수 없는 슬롯을 눌러도 아무 일이 없다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);

    game.useSlot(1); // 파랑 — 큐에 파랑이 없다
    await tester.pump();

    expect(game.board.wateredCount, 0);
  });

  testWidgets('되돌리기가 화면까지 되돌린다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);

    game.useSlot(0);
    await tester.pump();
    game.undo();
    await tester.pump();

    expect(game.board.wateredCount, 0);
    expect(cellsOf(game).where((cell) => cell.cell.isBloomed), isEmpty);
  });

  testWidgets('미리보기를 켜면 다음에 피울 칸이 집힌다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.cross);

    game.setPreview(BloomColor.red);
    await tester.pump();

    final highlighted = cellsOf(game).where((cell) => cell.isNextTarget);
    expect(highlighted, hasLength(1));
    expect(highlighted.single.cell.color, BloomColor.red);
  });

  testWidgets('통계가 승리까지 따라온다', (tester) async {
    final game = await pumpGame(tester, HandmadeLevels.tutorial);
    final report = BloomSolver.solve(HandmadeLevels.tutorial);

    for (final slotIndex in report.solution!) {
      game.useSlot(slotIndex);
      await tester.pump();
    }

    expect(game.stats.value.isWon, isTrue);
    expect(game.stats.value.bloomed, HandmadeLevels.tutorial.cellCount);
    expect(game.stats.value.isDeadlocked, isFalse);
  });
}
