import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:proto_merge/domain/board_model.dart';

void main() {
  group('초기 상태', () {
    test('레벨 1 아이템 2개가 배치되고 생성기 칸은 비어있지 않다', () {
      final board = BoardModel();

      expect(board.items.length, 2);
      expect(board.items.values, everyElement(1));
      expect(board.isEmptyCell(board.generatorCell), isFalse);
      expect(board.levelAt(board.generatorCell), isNull);
      expect(board.highestLevel, 1);
      expect(board.mergeCount, 0);
    });

    test('reset은 진행 상태를 초기 배치로 되돌린다', () {
      final board = BoardModel();
      board.tryMove((col: 1, row: 2), (col: 3, row: 2));

      board.reset();

      expect(board.items.length, 2);
      expect(board.mergeCount, 0);
      expect(board.highestLevel, 1);
    });
  });

  group('tryMove', () {
    test('빈 칸으로는 이동한다', () {
      final board = BoardModel();

      final outcome = board.tryMove((col: 1, row: 2), (col: 0, row: 0));

      expect(outcome, MoveOutcome.moved);
      expect(board.levelAt((col: 0, row: 0)), 1);
      expect(board.levelAt((col: 1, row: 2)), isNull);
    });

    test('같은 레벨에 드롭하면 레벨+1로 머지된다', () {
      final board = BoardModel();

      final outcome = board.tryMove((col: 1, row: 2), (col: 3, row: 2));

      expect(outcome, MoveOutcome.merged);
      expect(board.levelAt((col: 3, row: 2)), 2);
      expect(board.items.length, 1);
      expect(board.mergeCount, 1);
      expect(board.highestLevel, 2);
    });

    test('다른 레벨에 드롭하면 거부된다', () {
      final board = BoardModel();
      board.placeItem((col: 0, row: 0), 2);

      final outcome = board.tryMove((col: 1, row: 2), (col: 0, row: 0));

      expect(outcome, MoveOutcome.rejected);
      expect(board.levelAt((col: 1, row: 2)), 1);
      expect(board.levelAt((col: 0, row: 0)), 2);
    });

    test('생성기 칸·보드 밖·제자리 드롭은 거부된다', () {
      final board = BoardModel();
      const from = (col: 1, row: 2);

      expect(board.tryMove(from, board.generatorCell), MoveOutcome.rejected);
      expect(board.tryMove(from, (col: -1, row: 0)), MoveOutcome.rejected);
      expect(board.tryMove(from, (col: 0, row: 99)), MoveOutcome.rejected);
      expect(board.tryMove(from, from), MoveOutcome.rejected);
      expect(board.levelAt(from), 1);
    });

    test('최고 레벨끼리는 머지되지 않는다', () {
      final board = BoardModel();
      board.placeItem((col: 0, row: 0), 5);
      board.placeItem((col: 1, row: 0), 5);

      final outcome = board.tryMove((col: 0, row: 0), (col: 1, row: 0));

      expect(outcome, MoveOutcome.rejected);
      expect(board.levelAt((col: 0, row: 0)), 5);
      expect(board.levelAt((col: 1, row: 0)), 5);
    });

    test('아이템 없는 칸에서 출발하면 거부된다', () {
      final board = BoardModel();

      expect(board.tryMove((col: 0, row: 0), (col: 2, row: 0)), MoveOutcome.rejected);
    });
  });

  group('spawn', () {
    test('무작위 빈 칸에 레벨 1 아이템을 생성한다', () {
      final board = BoardModel(random: Random(42));

      final pos = board.spawn();

      expect(pos, isNotNull);
      expect(board.levelAt(pos!), 1);
      expect(board.items.length, 3);
    });

    test('보드가 가득 차면 null을 반환한다', () {
      final board = BoardModel();
      for (final pos in board.emptyCells) {
        board.placeItem(pos, 1);
      }

      expect(board.emptyCells, isEmpty);
      expect(board.spawn(), isNull);
    });
  });

  test('placeItem은 점유된 칸과 범위 밖 레벨을 무시한다', () {
    final board = BoardModel();

    board.placeItem((col: 1, row: 2), 3); // 이미 아이템 있음
    board.placeItem(board.generatorCell, 1);
    board.placeItem((col: 0, row: 0), 0);
    board.placeItem((col: 0, row: 0), 6);

    expect(board.levelAt((col: 1, row: 2)), 1);
    expect(board.levelAt(board.generatorCell), isNull);
    expect(board.levelAt((col: 0, row: 0)), isNull);
  });
}
