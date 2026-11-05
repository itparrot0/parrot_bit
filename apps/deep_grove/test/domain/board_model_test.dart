import 'dart:math';

import 'package:deep_grove/domain/board_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('시작 보드', () {
    test('숲 3×4, 동굴 없음, 씨앗 생성기 1개 + 씨앗 2개', () {
      final board = BoardModel(forestCaveTheme, random: Random(1));
      expect(board.unlocked, hasLength(12));
      expect(board.caveEntered, isFalse);
      // 화면 범위 = 열린 3×4 + 오른쪽·아래 잠긴 칸 한 줄씩
      expect((board.columns, board.rows), (4, 5));
      expect(board.cells.length, 3);
      final kinds = board.cells.values.map((c) => c.runtimeType).toList();
      expect(
        kinds.whereType<Type>().where((t) => t == GeneratorContent),
        hasLength(1),
      );
      expect(
        board.cells.values.whereType<ItemContent>().map((c) => c.item),
        everyElement(const Item(woodChain, 1)),
      );
    });

    test('모든 칸이 숲이다', () {
      final board = emptyBoard();
      for (final pos in board.emptyCells) {
        expect(board.zoneOf(pos), Zone.forest);
      }
    });
  });

  // 드롭 판정 4종 — 프로토타입에서 검증한 규칙 그대로 (proto_merge.md §4).
  group('아이템 tryMove', () {
    test('빈 칸으로는 이동한다', () {
      final board = emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 1));
      expect(board.tryMove(at(0, 0), at(1, 0)), MoveOutcome.moved);
      expect(board.contentAt(at(0, 0)), isNull);
      expect(
        (board.contentAt(at(1, 0))! as ItemContent).item,
        const Item(woodChain, 1),
      );
    });

    test('같은 체인·같은 레벨에 드롭하면 레벨+1로 머지된다', () {
      final board = emptyBoard()
        ..placeItem(at(0, 0), const Item(woodChain, 2))
        ..placeItem(at(1, 0), const Item(woodChain, 2));
      expect(board.tryMove(at(0, 0), at(1, 0)), MoveOutcome.merged);
      expect(board.contentAt(at(0, 0)), isNull);
      expect(
        (board.contentAt(at(1, 0))! as ItemContent).item,
        const Item(woodChain, 3),
      );
      expect(board.mergeCount, 1);
    });

    test('레벨이 다르면 자리를 교체한다', () {
      final board = emptyBoard()
        ..placeItem(at(0, 0), const Item(woodChain, 1))
        ..placeItem(at(1, 0), const Item(woodChain, 2));
      expect(board.tryMove(at(0, 0), at(1, 0)), MoveOutcome.swapped);
      expect((board.contentAt(at(0, 0))! as ItemContent).item.level, 2);
      expect((board.contentAt(at(1, 0))! as ItemContent).item.level, 1);
    });

    test('레벨이 같아도 체인이 다르면 자리를 교체한다', () {
      final board = emptyBoard()
        ..placeItem(at(0, 0), const Item(woodChain, 1))
        ..placeItem(at(1, 0), const Item(stoneChain, 1));
      expect(board.tryMove(at(0, 0), at(1, 0)), MoveOutcome.swapped);
    });

    test('아이템을 생성기 위에 드롭하면 자리를 교체한다', () {
      final board = emptyBoard()
        ..placeItem(at(0, 0), const Item(woodChain, 1))
        ..placeContent(at(1, 0), GeneratorContent(gen(woodChain)));
      expect(board.tryMove(at(0, 0), at(1, 0)), MoveOutcome.swapped);
      expect(board.contentAt(at(0, 0)), isA<GeneratorContent>());
    });

    test('보드 밖·제자리·빈 칸 출발 드롭은 거부된다', () {
      final board = emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 1));
      expect(board.tryMove(at(0, 0), at(3, 0)), MoveOutcome.rejected);
      expect(board.tryMove(at(0, 0), at(0, 4)), MoveOutcome.rejected);
      expect(board.tryMove(at(0, 0), at(0, 0)), MoveOutcome.rejected);
      expect(board.tryMove(at(2, 2), at(0, 0)), MoveOutcome.rejected);
    });
  });

  group('산출원 (최고 레벨 변신)', () {
    test('4레벨끼리 머지하면 5레벨 아이템 대신 산출원이 된다', () {
      final board = emptyBoard()
        ..placeItem(at(0, 0), const Item(woodChain, 4))
        ..placeItem(at(1, 0), const Item(woodChain, 4));
      expect(board.tryMove(at(0, 0), at(1, 0)), MoveOutcome.merged);
      final content = board.contentAt(at(1, 0));
      expect(content, isA<ProducerContent>());
      expect((content! as ProducerContent).producer.chain, woodChain);
    });

    test('산출원끼리는 머지되지 않고 자리를 교체한다', () {
      final board = emptyBoard()
        ..placeItem(at(0, 0), const Item(woodChain, 5))
        ..placeItem(at(1, 0), const Item(woodChain, 5));
      expect(board.tryMove(at(0, 0), at(1, 0)), MoveOutcome.swapped);
      expect(board.producers, hasLength(2));
    });

    test('산출원은 빈 칸으로 옮겨지고 쌓인 양을 들고 간다', () {
      final board = emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 5));
      board.advance(40, plenty);
      expect(board.tryMove(at(0, 0), at(2, 3)), MoveOutcome.moved);
      expect(board.harvest(at(2, 3)), (Resource.wood, 3));
    });
  });

  group('생성기', () {
    test('같은 체인·같은 레벨 생성기끼리 머지하면 레벨+1이 된다', () {
      final board = emptyBoard()
        ..placeContent(at(0, 0), GeneratorContent(gen(woodChain)))
        ..placeContent(at(1, 0), GeneratorContent(gen(woodChain)));
      expect(board.tryMove(at(0, 0), at(1, 0)), MoveOutcome.merged);
      expect(
        (board.contentAt(at(1, 0))! as GeneratorContent).generator.level,
        2,
      );
    });

    test('최고 레벨(G3) 생성기끼리는 자리를 교체한다', () {
      final board = emptyBoard()
        ..placeContent(at(0, 0), GeneratorContent(gen(woodChain, 3)))
        ..placeContent(at(1, 0), GeneratorContent(gen(woodChain, 3)));
      expect(board.tryMove(at(0, 0), at(1, 0)), MoveOutcome.swapped);
    });

    test('체인이 다른 생성기끼리는 자리를 교체한다', () {
      final board = emptyBoard()
        ..placeContent(at(0, 0), GeneratorContent(gen(woodChain)))
        ..placeContent(at(1, 0), GeneratorContent(gen(stoneChain)));
      expect(board.tryMove(at(0, 0), at(1, 0)), MoveOutcome.swapped);
    });

    test('spawnFrom은 빈 칸에 아이템을 놓고, 가득 차면 null', () {
      final board = emptyBoard();
      final g = gen(woodChain);
      for (var i = 0; i < 12; i++) {
        expect(board.spawnFrom(g), isNotNull);
      }
      expect(board.emptyCells, isEmpty);
      expect(board.spawnFrom(g), isNull);
    });

    test('G1은 언제나 1레벨을 낸다', () {
      final random = Random(7);
      for (var i = 0; i < 200; i++) {
        expect(gen(woodChain).produce(random), const Item(woodChain, 1));
      }
    });

    test('G3은 확률표대로 1~3레벨을 내고 산출원을 바로 만들지 않는다', () {
      final random = Random(3);
      final counts = <int, int>{};
      for (var i = 0; i < 4000; i++) {
        final level = gen(woodChain, 3).produce(random).level;
        counts.update(level, (v) => v + 1, ifAbsent: () => 1);
      }
      expect(counts.keys.toSet(), {1, 2, 3});
      // 0.5 / 0.35 / 0.15 — 넉넉한 허용 오차.
      expect(counts[1]! / 4000, closeTo(0.5, 0.04));
      expect(counts[2]! / 4000, closeTo(0.35, 0.04));
      expect(counts[3]! / 4000, closeTo(0.15, 0.04));
    });

    test('확률표가 최고 레벨까지 닿아도 최고 레벨 - 1로 자른다', () {
      const shortChain = ItemChain(
        id: 'short',
        levelNames: ['a', 'b'],
        resource: Resource.wood,
        homeZone: Zone.forest,
      );
      const g = Generator(
        spawnChain: shortChain,
        odds: SpawnOdds([
          [0, 0, 1],
        ]),
      );
      expect(g.produce(Random(1)).level, 1);
    });
  });

  group('산출', () {
    test('숲의 거목은 보너스 1.5배, 동굴의 거목은 기본 속도', () {
      final board = emptyBoard()
        ..openCaveRow()
        ..placeItem(at(0, 0), const Item(woodChain, 5))
        ..placeItem(at(0, 4), const Item(woodChain, 5));
      board.advance(20, plenty); // 기본 속도 = 20초에 1
      expect(board.harvest(at(0, 0)), (Resource.wood, 1)); // 1.5 → 1, 0.5 남음
      expect(board.harvest(at(0, 4)), (Resource.wood, 1));
      board.advance(20, plenty);
      expect(board.harvest(at(0, 0)), (Resource.wood, 2)); // 0.5 + 1.5
      expect(board.harvest(at(0, 4)), (Resource.wood, 1));
    });

    test('창고 빈 공간까지만 쌓이고 그 뒤로는 멈춘다', () {
      final board = emptyBoard()
        ..placeItem(at(0, 0), const Item(woodChain, 5))
        ..placeItem(at(1, 0), const Item(woodChain, 5));
      board.advance(100000, {Resource.wood: 7, Resource.ore: 0});
      expect(board.pending[Resource.wood], closeTo(7, 1e-9));
      board.advance(100000, {Resource.wood: 7, Resource.ore: 0});
      expect(board.pending[Resource.wood], closeTo(7, 1e-9));
    });

    test('다 익지 않았으면 harvest는 null', () {
      final board = emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 5));
      board.advance(5, plenty);
      expect(board.harvest(at(0, 0)), isNull);
      expect(board.harvest(at(1, 1)), isNull);
    });

    test('harvestAll은 모든 산출원을 비우고 자원별로 합친다', () {
      final board = emptyBoard()
        ..openCaveRow()
        ..placeItem(at(0, 0), const Item(woodChain, 5))
        ..placeItem(at(0, 4), const Item(stoneChain, 5));
      board.advance(40, plenty);
      expect(board.harvestAll(), {Resource.wood: 3, Resource.ore: 3});
      expect(board.pending.values, everyElement(0));
    });
  });

  group('확장 (한 칸씩)', () {
    test('다음에 열 수 있는 칸은 열린 칸과 상하좌우로 맞닿은 잠긴 칸이다', () {
      final board = emptyBoard();
      expect(board.frontier, [
        at(3, 0), at(3, 1), at(3, 2), at(3, 3), //
        at(0, 4), at(1, 4), at(2, 4),
      ]);
      expect(board.isFrontier(at(4, 0)), isFalse); // 한 칸 건너
      expect(board.isFrontier(at(3, 4)), isFalse); // 대각선
      expect(board.isFrontier(at(1, 1)), isFalse); // 이미 열림
    });

    test('unlock은 한 칸만 열고, 기존 좌표를 지킨다', () {
      final board = emptyBoard()..placeItem(at(2, 3), const Item(woodChain, 1));
      expect(board.unlock(at(3, 1)).opened, isTrue);
      expect(board.unlocked, hasLength(13));
      expect(board.isEmptyCell(at(3, 1)), isTrue);
      expect(board.isInside(at(3, 0)), isFalse);
      expect(board.contentAt(at(2, 3)), isA<ItemContent>());
      // 새로 열린 칸 옆이 다음 후보가 된다
      expect(board.isFrontier(at(4, 1)), isTrue);
    });

    test('잠긴 칸에는 조각을 옮길 수 없다', () {
      final board = emptyBoard()..placeItem(at(2, 0), const Item(woodChain, 1));
      expect(board.tryMove(at(2, 0), at(3, 0)), MoveOutcome.rejected);
    });

    test('맞닿지 않은 칸·최대 보드 밖은 열 수 없다', () {
      final board = emptyBoard();
      expect(board.unlock(at(5, 0)).opened, isFalse);
      expect(board.unlock(at(-1, 0)).opened, isFalse);
      expect(board.unlock(at(0, 7)).opened, isFalse);
    });

    test('첫 동굴 칸이 동굴 진입 — 그 칸에 자갈 생성기, 두 번째부터는 없다', () {
      final board = emptyBoard();
      final first = board.unlock(at(0, 4));
      expect(first.caveGenerator, at(0, 4));
      expect(board.caveEntered, isTrue);
      final g = (board.contentAt(at(0, 4))! as GeneratorContent).generator;
      expect(g.spawnChain, stoneChain);
      expect(board.unlock(at(1, 4)).caveGenerator, isNull);
    });

    test('최대 보드 6×7 = 42칸을 다 열면 fullyOpen', () {
      final board = emptyBoard()..openAll();
      expect(board.unlocked, hasLength(42));
      expect(board.fullyOpen, isTrue);
      expect(board.frontier, isEmpty);
      expect((board.columns, board.rows), (6, 7));
      expect(board.openedIn(Zone.forest), 24);
      expect(board.openedIn(Zone.cave), 18);
    });
  });

  test('저장 형식 왕복', () {
    final board = emptyBoard()
      ..unlock(at(3, 0))
      ..openCaveRow()
      ..placeItem(at(0, 0), const Item(woodChain, 3))
      ..placeContent(at(1, 0), GeneratorContent(gen(woodChain, 2)))
      ..placeItem(at(3, 4), const Item(stoneChain, 5));
    board.advance(30, plenty);
    final restored = BoardModel.fromJson(board.toJson(), forestCaveTheme);
    expect(restored.toJson(), board.toJson());
    expect(restored.unlocked, board.unlocked);
    expect(restored.caveEntered, isTrue);
  });

  test('한 칸씩 확장 이전 저장(columns·caveRows)은 직사각형으로 열어 읽는다', () {
    final board = BoardModel.fromJson({
      'columns': 4,
      'caveRows': 1,
      'mergeCount': 0,
      'cells': [
        {'col': 3, 'row': 4, 'kind': 'item', 'chain': 'stone', 'level': 2},
      ],
    }, forestCaveTheme);
    expect(board.unlocked, hasLength(4 * 5));
    expect(board.isInside(at(3, 4)), isTrue);
    expect(board.isInside(at(4, 0)), isFalse);
    expect(board.contentAt(at(3, 4)), isA<ItemContent>());
  });

  test('깨진 저장 형식은 FormatException', () {
    expect(
      () => BoardModel.fromJson({'columns': 'x'}, forestCaveTheme),
      throwsFormatException,
    );
    expect(
      () => BoardModel.fromJson({
        'columns': 3,
        'caveRows': 0,
        'mergeCount': 0,
        'cells': [
          {'col': 0, 'row': 0, 'kind': 'item', 'chain': 'nope', 'level': 1},
        ],
      }, forestCaveTheme),
      throwsFormatException,
    );
  });

  group('지대 보너스 표시', () {
    test('산출원은 자기 체인 지대를, 최고 레벨 바로 아래 아이템도 같은 지대를 알려 준다', () {
      expect(
        BoardModel.bonusZoneOf(ProducerContent(Producer(woodChain))),
        Zone.forest,
      );
      expect(
        BoardModel.bonusZoneOf(ProducerContent(Producer(stoneChain))),
        Zone.cave,
      );
      expect(
        BoardModel.bonusZoneOf(const ItemContent(Item(stoneChain, 4))),
        Zone.cave,
      );
    });

    test('그 밖의 아이템·생성기는 보너스 지대가 없다', () {
      expect(
        BoardModel.bonusZoneOf(const ItemContent(Item(woodChain, 3))),
        isNull,
      );
      expect(BoardModel.bonusZoneOf(GeneratorContent(gen(woodChain))), isNull);
    });

    test('hasZoneBonus는 산출원이 자기 지대에 있을 때만 true', () {
      final board = emptyBoard()
        ..openCaveRow()
        ..placeItem(at(0, 0), const Item(woodChain, 5))
        ..placeItem(at(0, 4), const Item(woodChain, 5))
        ..placeItem(at(2, 4), const Item(stoneChain, 5)) // (1,4)는 자갈 생성기 자리
        ..placeItem(at(2, 0), const Item(woodChain, 4));
      expect(board.hasZoneBonus(at(0, 0)), isTrue);
      expect(board.hasZoneBonus(at(0, 4)), isFalse);
      expect(board.hasZoneBonus(at(2, 4)), isTrue);
      expect(board.hasZoneBonus(at(2, 0)), isFalse);
    });
  });
}
