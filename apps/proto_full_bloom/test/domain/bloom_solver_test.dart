import 'package:flutter_test/flutter_test.dart';
import 'package:proto_full_bloom/domain/domain.dart';
import 'package:proto_full_bloom/levels/handmade_levels.dart';

import 'test_levels.dart';

void main() {
  group('솔버', () {
    test('풀리는 레벨에서 수순을 찾는다', () {
      final report = BloomSolver.solve(HandmadeLevels.cross);

      expect(report.solution, isNotNull);
      expect(report.exhausted, isFalse);
    });

    test('찾은 수순을 그대로 두면 실제로 이긴다', () {
      // 솔버와 보드가 같은 모델을 쓰는지 확인한다 (기획서 §38).
      for (final level in HandmadeLevels.all) {
        final report = BloomSolver.solve(level);
        expect(report.solution, isNotNull, reason: level.name);

        final board = BloomBoard(level);
        for (final move in report.solution!) {
          expect(
            board.availableMoves,
            contains(move),
            reason: '${level.name}: $move',
          );
          board.applyMove(move);
        }
        expect(board.isWon, isTrue, reason: level.name);
      }
    });

    test('교착 분기가 있어도 해를 찾고 교착 수를 센다', () {
      final report = BloomSolver.solve(TestLevels.deadlockable);

      expect(report.solution, isNotNull);
      expect(report.deadlockCount, greaterThan(0));
    });

    test('절대 풀리지 않는 레벨에서는 해를 못 찾는다', () {
      // 정확 일치를 지켜도 레인 순서가 막으면 못 푼다 —
      // 생성기가 솔버 검증을 거쳐야 하는 이유다.
      final report = BloomSolver.solve(TestLevels.unsolvable);

      expect(report.solution, isNull);
      expect(report.exhausted, isFalse);
      expect(report.deadlockCount, greaterThan(0));
    });

    test('isSolvable이 해 존재 여부를 그대로 돌려준다', () {
      expect(BloomSolver.isSolvable(HandmadeLevels.tutorial), isTrue);
      expect(BloomSolver.isSolvable(TestLevels.unsolvable), isFalse);
    });

    test('탐색 상한에 걸리면 exhausted로 알린다', () {
      // 상한을 1로 두면 거의 즉시 포기한다 — null이 "해가 없다"가 아니라
      // "모르겠다"라는 것을 호출자가 구분할 수 있어야 한다.
      final report = BloomSolver.solve(HandmadeLevels.flower, maxStates: 1);

      expect(report.solution, isNull);
      expect(report.exhausted, isTrue);
    });

    test('난이도 지표를 낸다', () {
      final easy = BloomSolver.solve(HandmadeLevels.tutorial);
      final hard = BloomSolver.solve(HandmadeLevels.flower);

      // 색이 하나뿐인 튜토리얼은 고를 것이 적어 탐색이 작다.
      expect(easy.statesVisited, lessThan(hard.statesVisited));
    });
  });

  group('손으로 만든 레벨은 전부 풀린다', () {
    for (final level in HandmadeLevels.all) {
      test(level.name, () {
        final report = BloomSolver.solve(level);

        expect(report.solution, isNotNull);
        expect(report.exhausted, isFalse);
      });
    }
  });
}
