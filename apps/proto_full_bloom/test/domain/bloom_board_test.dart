import 'package:flutter_test/flutter_test.dart';
import 'package:proto_full_bloom/domain/domain.dart';
import 'package:proto_full_bloom/levels/handmade_levels.dart';

import 'test_levels.dart';

void main() {
  group('초기 상태', () {
    test('시작 지점만 발아이고 나머지는 씨앗이다', () {
      final board = BloomBoard(
        monoLevel(start: (col: 2, row: 2), canCounts: const [25]),
      );

      expect(board.cellAt((col: 2, row: 2))!.isSprout, isTrue);
      expect(board.cellAt((col: 0, row: 0))!.isSeed, isTrue);
      expect(board.cells.values.where((cell) => cell.isSprout), hasLength(1));
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

    test('활성화 슬롯은 비어서 시작하고 레인은 손대지 않은 상태다', () {
      final board = BloomBoard(HandmadeLevels.cross);

      expect(board.activeSlots, [null, null]);
      expect(board.laneFront(0), (color: BloomColor.red, count: 2));
      expect(board.laneFront(1), (color: BloomColor.red, count: 3));
    });
  });

  group('레인 공개 범위', () {
    test('앞에서 laneRevealCount개까지만 보인다', () {
      final level = lineLevel(
        name: '공개',
        cells: const [
          BloomColor.red,
          BloomColor.red,
          BloomColor.red,
          BloomColor.red,
        ],
        lanes: const [
          [
            (color: BloomColor.red, count: 1),
            (color: BloomColor.red, count: 1),
            (color: BloomColor.red, count: 1),
            (color: BloomColor.red, count: 1),
          ],
        ],
      );
      final board = BloomBoard(level);

      expect(board.visibleLane(0), hasLength(2));
      expect(board.hiddenLaneCount(0), 2);
    });

    test('꺼낼수록 가려진 것이 드러난다', () {
      final board = BloomBoard(
        monoLevel(start: (col: 2, row: 2), canCounts: const [25]),
      );

      expect(board.hiddenLaneCount(0), 0);
      board.takeFromLane(0);
      expect(board.visibleLane(0), isEmpty);
    });
  });

  group('큐 순서 — 하 → 좌 → 우 → 상', () {
    test('첫 수는 시작 지점을 피우고 이웃 넷을 하좌우상으로 큐에 넣는다', () {
      final board = BloomBoard(
        monoLevel(start: (col: 2, row: 2), canCounts: const [1, 24]),
      );

      final bloomed = board.takeFromLane(0);

      expect(bloomed, [(col: 2, row: 2)]);
      expect(board.queue, [
        (col: 2, row: 3), // 하
        (col: 1, row: 2), // 좌
        (col: 3, row: 2), // 우
        (col: 2, row: 1), // 상
      ]);
    });

    test('6번째 물이 하2다', () {
      // 기획 확인 사항 — 시작 지점이 발아이므로 물 1번이 거기 들어가고,
      // 첫 고리가 물 2~5번, 다음 고리(하2)가 물 6번이다.
      final board = BloomBoard(
        monoLevel(start: (col: 2, row: 2), canCounts: const [6, 19]),
      );

      final bloomed = board.takeFromLane(0);

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

      board.takeFromLane(0);

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

      board.takeFromLane(0);

      expect(board.queue, [
        (col: 0, row: 1), // 하
        (col: 1, row: 0), // 우
      ]);
    });
  });

  group('고착 재정렬 — 바깥 고리 우선', () {
    test('물뿌리개가 멈추면 큐가 바깥 고리 우선으로 재정렬된다', () {
      // 기획 확인 예시 그대로: 3x3, x4가 중앙·하·좌·우를 피운 뒤
      // 다음 수는 (오래 기다린) 상이 아니라 하좌에서 이어져야 한다.
      final board = BloomBoard(
        monoLevel(
          columns: 3,
          rows: 3,
          start: (col: 1, row: 1),
          canCounts: const [4, 5],
        ),
      );

      final first = board.takeFromLane(0);
      expect(first, [
        (col: 1, row: 1), // 중앙
        (col: 1, row: 2), // 하
        (col: 0, row: 1), // 좌
        (col: 2, row: 1), // 우
      ]);

      // 재정렬: 고리 2(가장자리)가 앞으로, 고리 1의 상이 맨 뒤로.
      // 같은 고리 안에서는 발아 순서가 유지된다.
      expect(board.queue, [
        (col: 0, row: 2), // 하좌 (d2)
        (col: 2, row: 2), // 하우 (d2)
        (col: 0, row: 0), // 좌상 (d2)
        (col: 2, row: 0), // 우상 (d2)
        (col: 1, row: 0), // 상   (d1) — 맨 뒤
      ]);
    });

    test('다음 물뿌리개는 꽃무리 가장자리에서 이어서 피운다', () {
      final board = BloomBoard(
        monoLevel(
          columns: 3,
          rows: 3,
          start: (col: 1, row: 1),
          canCounts: const [4, 5],
        ),
      );

      board.takeFromLane(0);
      final second = board.takeFromLane(1);

      expect(second.first, (col: 0, row: 2)); // 하좌부터
      expect(second.last, (col: 1, row: 0)); // 상이 맨 마지막
      expect(board.isWon, isTrue);
    });

    test('재생 중에는 재정렬하지 않는다 — 한 물뿌리개 안에서는 안쪽 고리부터', () {
      // x6 한 번이면 재정렬 없이 하2가 6번째다 (기존 확정과 동일).
      final board = BloomBoard(
        monoLevel(start: (col: 2, row: 2), canCounts: const [6, 19]),
      );

      final bloomed = board.takeFromLane(0);

      expect(bloomed[4], (col: 2, row: 1)); // 5번째 = 상 (고리 1 마무리)
      expect(bloomed[5], (col: 2, row: 4)); // 6번째 = 하2 (고리 2 진입)
    });
  });

  group('레인에서 꺼내기', () {
    test('꺼낸 물뿌리개는 바로 재생되고 소진되면 슬롯이 빈다', () {
      final board = BloomBoard(HandmadeLevels.cross);

      final bloomed = board.takeFromLane(0); // 빨강 x2

      expect(bloomed, hasLength(2));
      expect(board.activeSlots, [null, null]); // 소진 → 즉시 비움
      expect(board.laneFront(0), (color: BloomColor.blue, count: 4));
    });

    test('대상이 없는 색을 꺼내면 주차되고 레인은 전진한다', () {
      // 교착 가능 레벨 — 파랑을 먼저 꺼내면 큐에 파랑이 없어 주차된다.
      final board = BloomBoard(TestLevels.deadlockable);

      final bloomed = board.takeFromLane(0);

      expect(bloomed, isEmpty);
      expect(board.activeSlots[0]!.color, BloomColor.blue);
      expect(board.activeSlots[0]!.remaining, 1);
      expect(board.laneFront(0), isNull); // 레인은 전진했다
    });

    test('빈 활성화 슬롯이 없으면 레인에서 꺼낼 수 없다', () {
      final board = BloomBoard(TestLevels.deadlockable); // 슬롯 1개

      board.takeFromLane(0); // 파랑 주차 → 슬롯 참

      expect(board.hasFreeActiveSlot, isFalse);
      expect(board.canTakeFromLane(1), isFalse);
      expect(board.takeFromLane(1), isEmpty);
      expect(board.laneFront(1), isNotNull); // 레인이 움직이지 않았다
    });

    test('빈 레인에서는 꺼낼 수 없다', () {
      final board = BloomBoard(
        monoLevel(
          columns: 3,
          rows: 3,
          start: (col: 1, row: 1),
          canCounts: const [9],
        ),
      );

      board.takeFromLane(0);

      expect(board.canTakeFromLane(0), isFalse);
    });
  });

  group('주차와 재개', () {
    test('멈춘 물뿌리개는 남은 횟수를 든 채 주차되고 나중에 재개된다', () {
      final board = BloomBoard(TestLevels.stalls);

      // 빨강 x3 — 닿을 수 있는 빨강이 2칸뿐이라 x1을 든 채 주차된다.
      expect(board.takeFromLane(0), hasLength(2));
      expect(board.activeSlots[0]!.remaining, 1);
      expect(board.canUseActive(0), isFalse);

      // 파랑이 피면 세 번째 빨강이 깨어나고, 주차된 것을 재개할 수 있다.
      expect(board.takeFromLane(1), hasLength(1));
      expect(board.canUseActive(0), isTrue);
      expect(board.useActive(0), hasLength(1));

      expect(board.isWon, isTrue);
      expect(board.activeSlots, [null, null]);
    });

    test('대상이 없는 주차 물뿌리개는 재개할 수 없다', () {
      final board = BloomBoard(TestLevels.deadlockable);

      board.takeFromLane(0); // 파랑 주차

      expect(board.canUseActive(0), isFalse);
      expect(board.useActive(0), isEmpty);
    });
  });

  group('승리와 교착', () {
    test('모든 칸이 개화하면 승리고 교착이 아니다', () {
      final board = BloomBoard(
        monoLevel(
          columns: 3,
          rows: 3,
          start: (col: 1, row: 1),
          canCounts: const [9],
        ),
      );

      board.takeFromLane(0);

      expect(board.isWon, isTrue);
      expect(board.isDeadlocked, isFalse);
    });

    test('둘 수 있는 수가 없으면 교착이다', () {
      final board = BloomBoard(TestLevels.deadlockable);

      // 파랑을 먼저 꺼내면 슬롯 1개가 주차로 막힌다 —
      // 재개 불가 + 빈 슬롯 없음 = 수가 없다.
      board.takeFromLane(0);

      expect(board.isWon, isFalse);
      expect(board.availableMoves, isEmpty);
      expect(board.isDeadlocked, isTrue);
    });

    test('빈 슬롯이 있고 레인이 남았으면 교착이 아니다 (파내기가 가능하다)', () {
      final board = BloomBoard(TestLevels.unsolvable); // 희망은 없지만

      expect(board.isDeadlocked, isFalse); // 첫 수는 둘 수 있다
    });
  });

  group('availableMoves', () {
    test('재개 가능한 슬롯과 꺼낼 수 있는 레인을 전부 나열한다', () {
      final board = BloomBoard(TestLevels.stalls);
      board.takeFromLane(0); // 빨강 주차(재개 불가), 슬롯 1개 빔

      final moves = board.availableMoves;

      // 주차된 빨강은 재개 불가 → 레인 둘 중 레인 1(파랑)만... 레인 0은 비었다.
      expect(moves, [(fromLane: true, index: 1)]);
    });
  });

  group('되돌리기', () {
    test('한 수를 되돌리면 칸·큐·슬롯·레인이 모두 돌아온다', () {
      final board = BloomBoard(HandmadeLevels.cross);
      final queueBefore = board.queue;

      board.takeFromLane(0);
      expect(board.canUndo, isTrue);
      expect(board.undo(), isTrue);

      expect(board.queue, queueBefore);
      expect(board.laneFront(0), (color: BloomColor.red, count: 2));
      expect(board.activeSlots, [null, null]);
      expect(board.cellAt((col: 2, row: 2))!.isSprout, isTrue);
      expect(board.wateredCount, 0);
    });

    test('주차도 한 수이고 되돌릴 수 있다', () {
      final board = BloomBoard(TestLevels.deadlockable);

      board.takeFromLane(0); // 주차 → 교착
      expect(board.isDeadlocked, isTrue);

      expect(board.undo(), isTrue);
      expect(board.isDeadlocked, isFalse);
      expect(board.laneFront(0), isNotNull);
      expect(board.activeSlots, [null]);
    });

    test('끝까지 되돌릴 수 있고 더 되돌릴 것이 없으면 false다', () {
      final board = BloomBoard(HandmadeLevels.cross);

      board.takeFromLane(0);
      board.takeFromLane(1);
      while (board.undo()) {}

      expect(board.canUndo, isFalse);
      expect(board.undo(), isFalse);
      expect(board.wateredCount, 0);
    });

    test('재시작은 처음 상태로 돌린다', () {
      final board = BloomBoard(HandmadeLevels.cross);

      board.takeFromLane(0);
      board.restart();

      expect(board.wateredCount, 0);
      expect(board.canUndo, isFalse);
      expect(board.queue, [(col: 2, row: 2)]);
      expect(board.laneFront(0), (color: BloomColor.red, count: 2));
    });
  });
}
