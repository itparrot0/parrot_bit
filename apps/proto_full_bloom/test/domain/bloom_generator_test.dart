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

    test('그림 실루엣대로 칸을 만들고 빈칸은 비워둔다', () {
      final generated = BloomGenerator.generate(
        seed: 3,
        shape: '''
.##.
####
.##.''',
        colorCount: 2,
        laneCount: 2,
      );
      final level = generated.level;

      expect(level.columns, 4);
      expect(level.rows, 3);
      expect(level.cellCount, 8); // # 개수
      expect(level.colors.containsKey((col: 0, row: 0)), isFalse); // 빈칸
      expect(level.colors.containsKey((col: 1, row: 0)), isTrue);
      expect(level.lanes, hasLength(2));
      expect(level.activeSlotCount, 4); // 기본값
    });

    test('내장 그림은 전부 4방향으로 연결돼 생성에 쓸 수 있다', () {
      for (var index = 0; index < BloomGenerator.shapes.length; index++) {
        // 연결이 끊긴 그림이면 색칠 단계에서 ArgumentError가 난다.
        expect(
          () => BloomGenerator.generate(
            seed: 100 + index,
            shape: BloomGenerator.shapes[index],
          ),
          returnsNormally,
          reason: 'shape $index',
        );
      }
    });

    test('연결이 끊긴 그림은 거부한다', () {
      expect(
        () => BloomGenerator.generate(
          seed: 1,
          shape: '''
##..
....
..##''',
        ),
        throwsArgumentError,
      );
    });

    test('물뿌리개 횟수가 지정한 범위 안에서 나온다', () {
      // 5x5 단색 25칸을 3..6으로 쪼갠다 — 모든 조각이 범위 안이고 합이 25다.
      final generated = BloomGenerator.generate(
        seed: 5,
        shape: '''
#####
#####
#####
#####
#####''',
        colorCount: 1,
        minCanSize: 3,
        maxCanSize: 6,
      );
      final cans = generated.level.allCans.toList();

      expect(cans.fold(0, (sum, can) => sum + can.count), 25);
      for (final can in cans) {
        expect(can.count, inInclusiveRange(3, 6));
      }
    });

    test('색의 총량이 최소 크기보다 작으면 그 색만 한 조각으로 담는다', () {
      // 1x3 줄에서 색 2개면 한 색은 1~2칸뿐 — min 3을 지킬 수 없어도
      // 정확 일치가 우선이라 전부 한 조각으로 나온다.
      final generated = BloomGenerator.generate(
        seed: 2,
        shape: '###',
        colorCount: 2,
        laneCount: 2,
        minCanSize: 3,
        maxCanSize: 6,
      );

      final totals = generated.level.waterCountByColor;
      expect(totals, generated.level.cellCountByColor); // 정확 일치 유지
    });

    test('잘못된 횟수 범위는 거부한다', () {
      expect(
        () => BloomGenerator.generate(seed: 1, minCanSize: 0),
        throwsArgumentError,
      );
      expect(
        () => BloomGenerator.generate(seed: 1, minCanSize: 5, maxCanSize: 4),
        throwsArgumentError,
      );
    });

    test('모든 색이 보드에 실제로 쓰인다', () {
      final generated = BloomGenerator.generate(seed: 11, colorCount: 4);

      expect(generated.level.colors.values.toSet(), hasLength(4));
    });
  });
}
