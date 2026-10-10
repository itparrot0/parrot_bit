import 'package:flutter_test/flutter_test.dart';
import 'package:proto_full_bloom/domain/domain.dart';

void main() {
  group('BloomGenerator', () {
    test('같은 시드는 같은 레벨을 만든다', () {
      final a = BloomGenerator.generate(seed: 42);
      final b = BloomGenerator.generate(seed: 42);

      expect(a.level.name, b.level.name);
      expect(a.level.colors, b.level.colors);
      expect(a.level.startPoints, b.level.startPoints);
      expect(a.level.lanes, b.level.lanes);
    });

    test('여러 시드에서 풀리는 레벨이 나온다', () {
      // 정확 일치는 역산이 구조적으로 보장하고(BloomLevel 생성자가 검사),
      // 풀림은 생성기가 솔버로 걸러서 보장한다.
      for (var seed = 1; seed <= 6; seed++) {
        final generated = BloomGenerator.generate(seed: seed);

        expect(generated.report.solution, isNotNull, reason: 'seed $seed');
        expect(generated.report.exhausted, isFalse, reason: 'seed $seed');
      }
    });

    test('찾은 수순을 그대로 두면 실제로 이긴다', () {
      final generated = BloomGenerator.generate(seed: 7);
      final board = BloomBoard(generated.level);

      for (final move in generated.report.solution!) {
        board.applyMove(move);
      }

      expect(board.isWon, isTrue);
    });

    test('요청한 파라미터대로 만든다', () {
      final generated = BloomGenerator.generate(
        seed: 3,
        columns: 4,
        rows: 4,
        colorCount: 2,
        laneCount: 2,
      );
      final level = generated.level;

      expect(level.columns, 4);
      expect(level.rows, 4);
      expect(level.cellCount, 16); // 빈칸 없는 꽉 찬 직사각형
      expect(level.colors.values.toSet(), hasLength(2));
      expect(level.lanes, hasLength(2));
      expect(level.startPoints, hasLength(1));
    });

    test('모든 색이 보드에 실제로 쓰인다', () {
      final generated = BloomGenerator.generate(seed: 11, colorCount: 4);

      expect(generated.level.colors.values.toSet(), hasLength(4));
    });
  });
}
