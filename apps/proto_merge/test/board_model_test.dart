import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:proto_merge/domain/board_model.dart';

/// 테스트용 별도 체인 (아이템셋 확장 시나리오 검증).
const ItemChain otherChain = ItemChain(id: 'other', maxLevel: 3);

void main() {
  group('초기 상태', () {
    test('기본 생성기 1개와 레벨 1 아이템 2개가 배치된다', () {
      final board = BoardModel();

      expect(board.generators, hasLength(1));
      expect(board.generators.first.cell, (col: 2, row: 5));
      expect(
        board.contentAt(board.generators.first.cell),
        isA<GeneratorContent>(),
      );
      expect(board.items.length, 2);
      expect(board.items.values, everyElement(const Item(basicChain, 1)));
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
      expect(
        board.contentAt(board.generators.first.cell),
        isA<GeneratorContent>(),
      );
    });
  });

  group('tryMove', () {
    test('빈 칸으로는 이동한다', () {
      final board = BoardModel();

      final outcome = board.tryMove((col: 1, row: 2), (col: 0, row: 0));

      expect(outcome, MoveOutcome.moved);
      expect(board.itemAt((col: 0, row: 0)), const Item(basicChain, 1));
      expect(board.itemAt((col: 1, row: 2)), isNull);
    });

    test('같은 체인·같은 레벨에 드롭하면 레벨+1로 머지된다', () {
      final board = BoardModel();

      final outcome = board.tryMove((col: 1, row: 2), (col: 3, row: 2));

      expect(outcome, MoveOutcome.merged);
      expect(board.itemAt((col: 3, row: 2)), const Item(basicChain, 2));
      expect(board.items.length, 1);
      expect(board.mergeCount, 1);
      expect(board.highestLevel, 2);
    });

    test('같은 체인이라도 레벨이 다르면 거부된다', () {
      final board = BoardModel();
      board.placeItem((col: 0, row: 0), const Item(basicChain, 2));

      final outcome = board.tryMove((col: 1, row: 2), (col: 0, row: 0));

      expect(outcome, MoveOutcome.rejected);
      expect(board.itemAt((col: 1, row: 2)), const Item(basicChain, 1));
      expect(board.itemAt((col: 0, row: 0)), const Item(basicChain, 2));
    });

    test('레벨이 같아도 체인이 다르면 거부된다', () {
      final board = BoardModel();
      board.placeItem((col: 0, row: 0), const Item(otherChain, 1));

      final outcome = board.tryMove((col: 1, row: 2), (col: 0, row: 0));

      expect(outcome, MoveOutcome.rejected);
      expect(board.itemAt((col: 0, row: 0)), const Item(otherChain, 1));
    });

    test('생성기 칸·보드 밖·제자리 드롭은 거부된다', () {
      final board = BoardModel();
      const from = (col: 1, row: 2);

      expect(
        board.tryMove(from, board.generators.first.cell),
        MoveOutcome.rejected,
      );
      expect(board.tryMove(from, (col: -1, row: 0)), MoveOutcome.rejected);
      expect(board.tryMove(from, (col: 0, row: 99)), MoveOutcome.rejected);
      expect(board.tryMove(from, from), MoveOutcome.rejected);
      expect(board.itemAt(from), const Item(basicChain, 1));
    });

    test('체인별 최고 레벨끼리는 머지되지 않는다', () {
      final board = BoardModel();
      board.placeItem((col: 0, row: 0), const Item(otherChain, 3));
      board.placeItem((col: 1, row: 0), const Item(otherChain, 3));

      final outcome = board.tryMove((col: 0, row: 0), (col: 1, row: 0));

      expect(outcome, MoveOutcome.rejected, reason: 'otherChain의 maxLevel은 3');
      expect(board.itemAt((col: 0, row: 0)), const Item(otherChain, 3));
    });

    test('아이템 없는 칸에서 출발하면 거부된다', () {
      final board = BoardModel();

      expect(
        board.tryMove((col: 0, row: 0), (col: 2, row: 0)),
        MoveOutcome.rejected,
      );
    });
  });

  group('생성기', () {
    test('spawnFrom은 무작위 빈 칸에 생성기의 아이템을 놓는다', () {
      final board = BoardModel(random: Random(42));

      final pos = board.spawnFrom(board.generators.first);

      expect(pos, isNotNull);
      expect(board.itemAt(pos!), const Item(basicChain, 1));
      expect(board.items.length, 3);
    });

    test('보드가 가득 차면 null을 반환한다', () {
      final board = BoardModel();
      for (final pos in board.emptyCells) {
        board.placeItem(pos, const Item(basicChain, 1));
      }

      expect(board.emptyCells, isEmpty);
      expect(board.spawnFrom(board.generators.first), isNull);
    });

    test('생성기 여러 개를 각자의 스폰 정의로 둘 수 있다', () {
      const left = Generator(cell: (col: 0, row: 5), spawnChain: basicChain);
      const right =
          Generator(cell: (col: 4, row: 5), spawnChain: otherChain, spawnLevel: 2);
      final board = BoardModel(
        generators: const [left, right],
        random: Random(7),
      );

      expect(board.contentAt((col: 0, row: 5)), isA<GeneratorContent>());
      expect(board.contentAt((col: 4, row: 5)), isA<GeneratorContent>());

      final pos = board.spawnFrom(right);

      expect(board.itemAt(pos!), const Item(otherChain, 2));
    });
  });

  test('placeItem은 점유된 칸과 체인 범위 밖 레벨을 무시한다', () {
    final board = BoardModel();

    board.placeItem((col: 1, row: 2), const Item(basicChain, 3)); // 이미 아이템 있음
    board.placeItem(board.generators.first.cell, const Item(basicChain, 1));
    board.placeItem((col: 0, row: 0), const Item(basicChain, 0));
    board.placeItem((col: 0, row: 0), const Item(basicChain, 6));
    board.placeItem((col: 0, row: 0), const Item(otherChain, 4)); // maxLevel 3 초과

    expect(board.itemAt((col: 1, row: 2)), const Item(basicChain, 1));
    expect(board.itemAt(board.generators.first.cell), isNull);
    expect(board.itemAt((col: 0, row: 0)), isNull);
  });

  test('Item.canMergeWith는 체인·레벨 일치와 최고 레벨을 함께 본다', () {
    const a = Item(basicChain, 2);

    expect(a.canMergeWith(const Item(basicChain, 2)), isTrue);
    expect(a.canMergeWith(const Item(basicChain, 3)), isFalse);
    expect(a.canMergeWith(const Item(otherChain, 2)), isFalse);
    expect(
      const Item(basicChain, 5).canMergeWith(const Item(basicChain, 5)),
      isFalse,
    );
    expect(a.upgraded, const Item(basicChain, 3));
  });
}
