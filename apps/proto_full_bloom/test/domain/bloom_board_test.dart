import 'package:flutter_test/flutter_test.dart';
import 'package:proto_full_bloom/domain/domain.dart';
import 'package:proto_full_bloom/levels/handmade_levels.dart';

import 'test_levels.dart';

void main() {
  group('초기 상태', () {
    test('시작 지점만 꽃송이이고 나머지는 씨앗이다', () {
      final board = BloomBoard(
        monoLevel(start: (col: 2, row: 2), canCounts: const [25]),
      );

      expect(board.cellAt((col: 2, row: 2))!.isBud, isTrue);
      expect(board.cellAt((col: 0, row: 0))!.isSeed, isTrue);
      expect(board.cells.values.where((cell) => cell.isBud), hasLength(1));
    });

    test('큐의 초기 내용은 시작 지점이다', () {
      final board = BloomBoard(
        monoLevel(start: (col: 2, row: 2), canCounts: const [25]),
      );

      expect(board.queue, [(col: 2, row: 2)]);
    });

    test('시작 지점이 여러 개면 정의된 순서로 큐에 들어간다', () {
      final board = BloomBoard(TestLevels.twoStarts);

      expect(board.queue, [(col: 0, row: 0), (col: 2, row: 0)]);
    });

    test('슬롯이 대기열 앞에서 채워지고 나머지는 대기한다', () {
      final board = BloomBoard(
        monoLevel(start: (col: 2, row: 2), canCounts: const [1, 2, 3, 19]),
      );

      expect(board.slots.map((can) => can?.remaining), [1, 2, 3]);
      expect(board.pendingCans, hasLength(1));
    });
  });

  group('큐 순서 — 하 → 좌 → 우 → 상', () {
    test('첫 수는 시작 지점을 피우고 이웃 넷을 하좌우상으로 큐에 넣는다', () {
      final board = BloomBoard(
        monoLevel(start: (col: 2, row: 2), canCounts: const [1, 24]),
      );

      final bloomed = board.useSlot(0);

      expect(bloomed, [(col: 2, row: 2)]);
      expect(board.queue, [
        (col: 2, row: 3), // 하
        (col: 1, row: 2), // 좌
        (col: 3, row: 2), // 우
        (col: 2, row: 1), // 상
      ]);
    });

    test('6번째 물이 하2다', () {
      // 기획 확인 사항 — 시작 지점이 꽃송이이므로 물 1번이 거기 들어가고,
      // 첫 고리가 물 2~5번, 다음 고리(하2)가 물 6번이다 (PRD §3.3).
      final board = BloomBoard(
        monoLevel(start: (col: 2, row: 2), canCounts: const [6, 19]),
      );

      final bloomed = board.useSlot(0);

      expect(bloomed, [
        (col: 2, row: 2), // 1  시작 지점
        (col: 2, row: 3), // 2  하
        (col: 1, row: 2), // 3  좌
        (col: 3, row: 2), // 4  우
        (col: 2, row: 1), // 5  상
        (col: 2, row: 4), // 6  하2 — 하의 하
      ]);
    });

    test('같은 이웃을 두 칸이 깨워도 큐에 한 번만 들어간다', () {
      final board = BloomBoard(
        monoLevel(start: (col: 2, row: 2), canCounts: const [25]),
      );

      board.useSlot(0);

      expect(board.queue, isEmpty);
      expect(board.isWon, isTrue);
      // 중복 삽입이 있었다면 물 25번으로 25칸을 다 피우지 못한다.
      expect(board.wateredCount, 25);
    });

    test('보드 밖과 빈칸은 큐에 들어가지 않는다', () {
      final board = BloomBoard(
        monoLevel(
          columns: 3,
          rows: 3,
          start: (col: 0, row: 0),
          canCounts: const [1, 8],
        ),
      );

      board.useSlot(0);

      expect(board.queue, [
        (col: 0, row: 1), // 하
        (col: 1, row: 0), // 우
      ]);
    });
  });

  group('색 매칭', () {
    test('큐에 같은 색이 없는 물뿌리개는 쓸 수 없다', () {
      // 십자 레벨의 시작 지점은 빨강이라 파랑은 첫 수에 쓸 수 없다.
      final board = BloomBoard(HandmadeLevels.cross);

      expect(board.slots[1]!.color, BloomColor.blue);
      expect(board.canUseSlot(1), isFalse);
      expect(board.useSlot(1), isEmpty);
    });

    test('색이 안 맞는 칸은 건너뛰고 뒤에 있는 같은 색을 집는다', () {
      final board = BloomBoard(HandmadeLevels.cross);

      board.useSlot(0); // 빨강 x2 — 중앙과 하를 피운다

      // 큐 앞은 파랑인데 빨강 물뿌리개는 그 뒤의 빨강을 집는다.
      expect(board.queue.first, (col: 1, row: 2));
      expect(board.cellAt((col: 1, row: 2))!.color, BloomColor.blue);
      expect(board.nextTargetFor(BloomColor.red), (col: 2, row: 1));
      expect(board.nextTargetFor(BloomColor.blue), (col: 1, row: 2));
    });

    test('previewTargets는 그 색이 피울 칸을 큐 순서대로 낸다', () {
      final board = BloomBoard(HandmadeLevels.cross);

      board.useSlot(0);

      expect(board.previewTargets(BloomColor.blue, 2), [
        (col: 1, row: 2),
        (col: 3, row: 2),
      ]);
    });
  });

  group('남은 횟수와 슬롯 (PRD §3.5)', () {
    test('쓸 대상이 없어 멈추면 남은 횟수가 슬롯에 남는다', () {
      final board = BloomBoard(TestLevels.stalls);

      // 빨강 x3이지만 닿을 수 있는 빨강이 2칸뿐이라 1이 남는다.
      final bloomed = board.useSlot(0);

      expect(bloomed, hasLength(2));
      expect(board.slots[0], isNotNull);
      expect(board.slots[0]!.remaining, 1);
    });

    test('소진될 때만 슬롯이 비고 대기열이 충원된다', () {
      final board = BloomBoard(
        monoLevel(start: (col: 2, row: 2), canCounts: const [1, 2, 3, 19]),
      );

      expect(board.pendingCans, hasLength(1));
      board.useSlot(0); // x1 소진

      expect(board.slots[0]!.remaining, 19);
      expect(board.pendingCans, isEmpty);
    });

    test('대기열이 비면 소진된 슬롯은 빈 채로 남는다', () {
      final board = BloomBoard(
        monoLevel(
          columns: 3,
          rows: 3,
          start: (col: 1, row: 1),
          canCounts: const [1, 8],
        ),
      );

      board.useSlot(0);

      expect(board.slots[0], isNull);
      expect(board.slots[1]!.remaining, 8);
      expect(board.slots[2], isNull);
    });
  });

  group('승리와 교착 (PRD §3.8)', () {
    test('모든 칸이 개화하면 승리고 교착이 아니다', () {
      final board = BloomBoard(
        monoLevel(
          columns: 3,
          rows: 3,
          start: (col: 1, row: 1),
          canCounts: const [9],
        ),
      );

      board.useSlot(0);

      expect(board.isWon, isTrue);
      expect(board.isDeadlocked, isFalse);
    });

    test('쓸 수 있는 슬롯이 없으면 교착이다', () {
      final board = BloomBoard(TestLevels.deadlockable);

      // 빨강을 먼저 다 쓰면 파랑 칸에 닿지 못한 채 파랑만 남는다.
      board.useSlot(0);

      expect(board.isWon, isFalse);
      expect(board.isDeadlocked, isTrue);
    });
  });

  group('되돌리기', () {
    test('한 수를 되돌리면 칸·큐·슬롯이 모두 돌아온다', () {
      final board = BloomBoard(HandmadeLevels.cross);
      final queueBefore = board.queue;
      final remainingBefore = board.slots[0]!.remaining;

      board.useSlot(0);
      expect(board.canUndo, isTrue);
      expect(board.undo(), isTrue);

      expect(board.queue, queueBefore);
      expect(board.slots[0]!.remaining, remainingBefore);
      expect(board.cellAt((col: 2, row: 2))!.isBud, isTrue);
      expect(board.wateredCount, 0);
    });

    test('끝까지 되돌릴 수 있고 더 되돌릴 것이 없으면 false다', () {
      final board = BloomBoard(HandmadeLevels.cross);

      board.useSlot(0);
      board.useSlot(1);
      while (board.undo()) {}

      expect(board.canUndo, isFalse);
      expect(board.undo(), isFalse);
      expect(board.wateredCount, 0);
    });

    test('재시작은 처음 상태로 돌린다', () {
      final board = BloomBoard(HandmadeLevels.cross);

      board.useSlot(0);
      board.restart();

      expect(board.wateredCount, 0);
      expect(board.canUndo, isFalse);
      expect(board.queue, [(col: 2, row: 2)]);
    });
  });
}
