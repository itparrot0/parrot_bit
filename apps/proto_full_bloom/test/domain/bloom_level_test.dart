import 'package:flutter_test/flutter_test.dart';
import 'package:proto_full_bloom/domain/domain.dart';
import 'package:proto_full_bloom/levels/handmade_levels.dart';

/// §3.7 불변식을 어긋나게 만드는 레벨 생성자.
BloomLevel buildLevel({
  Map<CellPos, BloomColor>? colors,
  List<CellPos>? startPoints,
  List<CanSpec>? cans,
  int columns = 2,
  int rows = 1,
  int slotCount = 3,
}) => BloomLevel(
  name: '검증용',
  columns: columns,
  rows: rows,
  colors:
      colors ??
      const {
        (col: 0, row: 0): BloomColor.red,
        (col: 1, row: 0): BloomColor.red,
      },
  startPoints: startPoints ?? const [(col: 0, row: 0)],
  cans: cans ?? const [(color: BloomColor.red, count: 2)],
  slotCount: slotCount,
);

void main() {
  group('§3.7 불변식 — 색깔별 물 횟수 = 색깔별 칸 수', () {
    test('맞으면 통과한다', () {
      expect(buildLevel, returnsNormally);
    });

    test('총합이 모자라면 거부한다', () {
      expect(
        () => buildLevel(cans: const [(color: BloomColor.red, count: 1)]),
        throwsArgumentError,
      );
    });

    test('총합이 남으면 거부한다', () {
      expect(
        () => buildLevel(cans: const [(color: BloomColor.red, count: 3)]),
        throwsArgumentError,
      );
    });

    test('총합은 맞아도 색깔별로 어긋나면 거부한다', () {
      // 총합 2 = 칸 2지만, 칸은 빨강 2개인데 물은 빨강 1 + 파랑 1이다.
      expect(
        () => buildLevel(
          cans: const [
            (color: BloomColor.red, count: 1),
            (color: BloomColor.blue, count: 1),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('칸에 없는 색의 물뿌리개를 거부한다', () {
      expect(
        () => buildLevel(
          colors: const {
            (col: 0, row: 0): BloomColor.red,
            (col: 1, row: 0): BloomColor.blue,
          },
          cans: const [(color: BloomColor.red, count: 2)],
        ),
        throwsArgumentError,
      );
    });

    test('세는 기준은 씨앗 수가 아니라 전체 칸 수다', () {
      // 시작 지점도 발아에서 개화로 가야 하므로 물 한 번이 든다.
      // 씨앗(1칸)만 세어 x1을 주면 거부돼야 한다.
      expect(
        () => buildLevel(cans: const [(color: BloomColor.red, count: 1)]),
        throwsArgumentError,
      );
    });
  });

  group('레벨 정의 검증', () {
    test('시작 지점이 없으면 거부한다', () {
      expect(() => buildLevel(startPoints: const []), throwsArgumentError);
    });

    test('시작 지점이 빈칸이면 거부한다', () {
      expect(
        () => buildLevel(startPoints: const [(col: 5, row: 5)]),
        throwsArgumentError,
      );
    });

    test('시작 지점이 중복되면 거부한다', () {
      expect(
        () =>
            buildLevel(startPoints: const [(col: 0, row: 0), (col: 0, row: 0)]),
        throwsArgumentError,
      );
    });

    test('격자 밖의 칸이 있으면 거부한다', () {
      expect(
        () => buildLevel(
          colors: const {
            (col: 0, row: 0): BloomColor.red,
            (col: 9, row: 0): BloomColor.red,
          },
        ),
        throwsArgumentError,
      );
    });

    test('슬롯 수가 0 이하면 거부한다', () {
      expect(() => buildLevel(slotCount: 0), throwsArgumentError);
    });
  });

  group('손으로 만든 레벨', () {
    test('전부 §3.7을 지킨다', () {
      // 생성자가 검사하므로, 목록을 읽는 것만으로 검증된다.
      expect(HandmadeLevels.all, isNotEmpty);
      for (final level in HandmadeLevels.all) {
        expect(
          level.cellCountByColor,
          level.waterCountByColor,
          reason: level.name,
        );
      }
    });

    test('물뿌리개 총 횟수가 전체 칸 수와 같다', () {
      for (final level in HandmadeLevels.all) {
        final totalWater = level.cans.fold(0, (sum, can) => sum + can.count);
        expect(totalWater, level.cellCount, reason: level.name);
      }
    });

    test('이름이 서로 다르다', () {
      final names = HandmadeLevels.all.map((level) => level.name).toSet();

      expect(names, hasLength(HandmadeLevels.all.length));
    });
  });
}
