import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proto_merge/game/components/generator_component.dart';
import 'package:proto_merge/game/components/item_component.dart';
import 'package:proto_merge/game/merge_game.dart';

/// 고정 해상도(540x700) 월드 좌표 → 레터박스된 스크린 좌표.
Offset worldToScreen(Vector2 world, Size screen) {
  const resolution = Size(540, 700);
  final scale = math.min(
    screen.width / resolution.width,
    screen.height / resolution.height,
  );
  final letterbox = Offset(
    (screen.width - resolution.width * scale) / 2,
    (screen.height - resolution.height * scale) / 2,
  );
  return letterbox +
      Offset(
        (world.x + resolution.width / 2) * scale,
        (world.y + resolution.height / 2) * scale,
      );
}

Future<MergeGame> pumpGame(WidgetTester tester) async {
  final game = MergeGame();
  await tester.pumpWidget(GameWidget(game: game));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 32));
  return game;
}

void main() {
  testWidgets('로드 시 생성기 1개와 초기 아이템 2개가 배치된다', (tester) async {
    final game = await pumpGame(tester);

    expect(game.world.children.whereType<GeneratorComponent>().length, 1);
    expect(game.world.children.whereType<ItemComponent>().length, 2);
  });

  testWidgets('생성기를 탭하면 레벨 1 아이템이 생성된다', (tester) async {
    final game = await pumpGame(tester);
    final screen = tester.getSize(find.byType(GameWidget<MergeGame>));

    await tester.tapAt(
      worldToScreen(game.cellCenter(game.model.generatorCell), screen),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(game.model.items.length, 3);
    expect(game.world.children.whereType<ItemComponent>().length, 3);
  });

  testWidgets('드래그드롭으로 같은 레벨을 합치면 레벨 2가 된다', (tester) async {
    final game = await pumpGame(tester);
    final screen = tester.getSize(find.byType(GameWidget<MergeGame>));
    const from = (col: 1, row: 2);
    const to = (col: 3, row: 2);

    final start = worldToScreen(game.cellCenter(from), screen);
    final end = worldToScreen(game.cellCenter(to), screen);
    await tester.timedDragFrom(
      start,
      end - start,
      const Duration(milliseconds: 300),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(game.model.mergeCount, 1);
    expect(game.model.levelAt(to), 2);
    expect(game.world.children.whereType<ItemComponent>().length, 1);
  });

  testWidgets('다른 레벨 위에 드롭하면 원래 칸으로 돌아온다', (tester) async {
    final game = await pumpGame(tester);
    final screen = tester.getSize(find.byType(GameWidget<MergeGame>));
    const other = (col: 0, row: 0);
    game.model.placeItem(other, 2); // 모델에만 있어도 판정 검증에는 충분
    const from = (col: 1, row: 2);

    final start = worldToScreen(game.cellCenter(from), screen);
    final end = worldToScreen(game.cellCenter(other), screen);
    await tester.timedDragFrom(
      start,
      end - start,
      const Duration(milliseconds: 300),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(game.model.mergeCount, 0);
    expect(game.model.levelAt(from), 1, reason: '스냅백으로 원래 칸 유지');
    expect(game.model.levelAt(other), 2);
  });
}
