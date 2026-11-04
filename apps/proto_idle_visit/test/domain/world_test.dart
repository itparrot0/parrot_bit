import 'package:flutter_test/flutter_test.dart';
import 'package:proto_idle_visit/domain/domain.dart';

final t0 = DateTime.utc(2026, 11, 4, 9);

DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

/// 자리 2개짜리 장소 하나, 아이템 2개, 캐릭터 2마리 — 결과를 손으로 따라갈
/// 수 있는 크기.
final tiny = Catalog(
  places: const [PlaceDef(id: 'p', name: '마당', emoji: '🌳', slotCount: 2)],
  items: const [
    ItemDef(id: 'a', name: 'A', emoji: 'A'),
    ItemDef(id: 'b', name: 'B', emoji: 'B'),
  ],
  characters: const [
    CharacterDef(
      id: 'x',
      name: 'X',
      emoji: 'X',
      rarity: Rarity.common,
      likes: {'a'},
      stay: Duration(minutes: 20),
    ),
    CharacterDef(
      id: 'y',
      name: 'Y',
      emoji: 'Y',
      rarity: Rarity.rare,
      likes: {'a', 'b'},
      stay: Duration(minutes: 30),
    ),
  ],
);

/// 추첨하면 반드시 누군가 온다.
const always = VisitRules(visitChance: 1);

World tinyWorld({int seed = 1, VisitRules rules = always}) =>
    World(catalog: tiny, seed: seed, now: t0, rules: rules);

void main() {
  group('카탈로그', () {
    test('기본 카탈로그는 무결성 검사를 통과한다', () {
      expect(Catalog.standard.characters, hasLength(8));
      expect(Catalog.standard.places, isNotEmpty);
    });

    test('없는 아이템을 좋아하는 캐릭터는 거부한다', () {
      expect(
        () => Catalog(
          places: const [PlaceDef(id: 'p', name: 'p', emoji: '', slotCount: 1)],
          items: const [ItemDef(id: 'a', name: 'a', emoji: '')],
          characters: const [
            CharacterDef(
              id: 'x',
              name: 'x',
              emoji: '',
              rarity: Rarity.common,
              likes: {'a', 'ghost'},
              stay: Duration(minutes: 1),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('아무도 찾아오지 않는 아이템은 거부한다', () {
      expect(
        () => Catalog(
          places: const [PlaceDef(id: 'p', name: 'p', emoji: '', slotCount: 1)],
          items: const [
            ItemDef(id: 'a', name: 'a', emoji: ''),
            ItemDef(id: 'lonely', name: 'l', emoji: ''),
          ],
          characters: const [
            CharacterDef(
              id: 'x',
              name: 'x',
              emoji: '',
              rarity: Rarity.common,
              likes: {'a'},
              stay: Duration(minutes: 1),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('id가 겹치면 거부한다', () {
      expect(
        () => Catalog(
          places: const [
            PlaceDef(id: 'p', name: 'p', emoji: '', slotCount: 1),
            PlaceDef(id: 'p', name: 'q', emoji: '', slotCount: 1),
          ],
          items: tiny.items,
          characters: tiny.characters,
        ),
        throwsArgumentError,
      );
    });
  });

  group('배치', () {
    test('처음에는 모든 자리가 비어 있고 도감도 비어 있다', () {
      final world = tinyWorld();
      expect(world.slotsOf('p').every((s) => s.isEmpty), isTrue);
      expect(world.collection, isEmpty);
    });

    test('놓은 아이템의 첫 추첨은 추첨 간격 뒤다', () {
      final world = tinyWorld()..placeItem('p', 0, 'a');
      expect(world.slot('p', 0).itemId, 'a');
      expect(world.slot('p', 0).nextRollAt, at(5));
    });

    test('추첨 간격 전에는 아무도 오지 않는다', () {
      final world = tinyWorld()..placeItem('p', 0, 'a');
      expect(world.advance(at(4)), isEmpty);
      expect(world.slot('p', 0).visit, isNull);
    });

    test('없는 아이템은 놓을 수 없다', () {
      expect(() => tinyWorld().placeItem('p', 0, 'nope'), throwsArgumentError);
    });

    test('치우면 머물던 손님도 떠나고 추첨이 멈춘다', () {
      final world = tinyWorld()..placeItem('p', 0, 'a');
      world.advance(at(5));
      expect(world.slot('p', 0).visit, isNotNull);

      world.removeItem('p', 0);
      expect(world.slot('p', 0).visit, isNull);
      expect(world.advance(at(600)), isEmpty);
    });

    test('바꿔 놓으면 손님이 떠나고 다시 기다린다', () {
      final world = tinyWorld()..placeItem('p', 0, 'a');
      world.advance(at(5));

      world.placeItem('p', 0, 'b');
      expect(world.slot('p', 0).visit, isNull);
      expect(world.slot('p', 0).nextRollAt, at(10));
    });
  });

  group('방문', () {
    test('추첨 시각에 좋아하는 캐릭터가 찾아와 도감에 오른다', () {
      final world = tinyWorld()..placeItem('p', 0, 'b');
      final arrivals = world.advance(at(5));

      // b를 좋아하는 건 y뿐이다.
      expect(arrivals, hasLength(1));
      expect(arrivals.single.characterId, 'y');
      expect(arrivals.single.at, at(5));
      expect(arrivals.single.isFirstVisit, isTrue);
      expect(world.slot('p', 0).visit!.leavesAt, at(35));
      expect(world.isCollected('y'), isTrue);
      expect(world.collection['y']!.visitCount, 1);
    });

    test('머무는 시간이 지나면 떠나고, 간격 뒤에 다시 추첨한다', () {
      final world = tinyWorld()..placeItem('p', 0, 'b');
      world.advance(at(5)); // y 도착, 35분에 떠남

      world.advance(at(35));
      expect(world.slot('p', 0).visit, isNull);
      expect(world.slot('p', 0).nextRollAt, at(40));

      final again = world.advance(at(40));
      expect(again.single.characterId, 'y');
      expect(again.single.isFirstVisit, isFalse);
      expect(world.collection['y']!.visitCount, 2);
      expect(world.collection['y']!.firstSeenAt, at(5));
    });

    test('한 캐릭터는 한 번에 한 곳에만 있다', () {
      // 두 자리 모두 b — 후보는 y뿐이므로 두 번째 자리는 비어 있어야 한다.
      final world = tinyWorld()
        ..placeItem('p', 0, 'b')
        ..placeItem('p', 1, 'b');
      final arrivals = world.advance(at(5));

      expect(arrivals, hasLength(1));
      expect(world.visitingCharacters, {'y'});
      expect(world.slot('p', 1).visit, isNull);
      expect(world.slot('p', 1).nextRollAt, at(10));
    });

    test('떠난 캐릭터는 같은 순간 다른 자리의 후보가 된다', () {
      final world = tinyWorld()..placeItem('p', 0, 'b');
      world.advance(at(5)); // y가 0번에, 35분에 떠남
      world.placeItem('p', 1, 'b'); // 5분에 놓음 → 10, 15, …, 35분에 추첨

      final arrivals = world.advance(at(35));
      // 35분: 0번에서 y가 떠난 직후 1번 추첨에서 y가 온다.
      expect(arrivals.single.characterId, 'y');
      expect(arrivals.single.slotIndex, 1);
      expect(arrivals.single.at, at(35));
    });

    test('방문 확률 0이면 아무도 오지 않는다', () {
      final world = tinyWorld(rules: const VisitRules(visitChance: 0))
        ..placeItem('p', 0, 'a');
      expect(world.advance(at(24 * 60)), isEmpty);
      expect(world.rollCount, 24 * 60 ~/ 5);
    });

    test('희귀도 가중치대로 뽑힌다 (흔함 60 : 드묾 30)', () {
      var x = 0;
      var y = 0;
      for (var seed = 0; seed < 600; seed++) {
        final world = tinyWorld(seed: seed)..placeItem('p', 0, 'a');
        final first = world.advance(at(5)).single.characterId;
        if (first == 'x') x++;
        if (first == 'y') y++;
      }
      expect(x + y, 600);
      // 기대값 400 : 200. 넉넉한 허용 범위로 시드 편향만 잡는다.
      expect(x, inInclusiveRange(340, 460));
    });

    test('확률 0.5면 대략 절반의 추첨에서 손님이 온다', () {
      var hits = 0;
      for (var seed = 0; seed < 400; seed++) {
        final world = tinyWorld(seed: seed, rules: VisitRules.standard)
          ..placeItem('p', 0, 'a');
        if (world.advance(at(5)).isNotEmpty) hits++;
      }
      expect(hits, inInclusiveRange(150, 250));
    });
  });

  group('시간 흐름', () {
    test('잘게 나눠 진행해도 한 번에 진행해도 결과가 같다 (오프라인 진행)', () {
      World build() => World(catalog: Catalog.standard, seed: 42, now: t0)
        ..placeItem('yard', 0, 'seeds')
        ..placeItem('yard', 1, 'water')
        ..placeItem('yard', 2, 'berry')
        ..placeItem('window', 0, 'bell')
        ..placeItem('window', 1, 'perch');

      final live = build();
      final liveArrivals = <Arrival>[];
      for (var m = 1; m <= 6 * 60; m++) {
        liveArrivals.addAll(live.advance(at(m)));
      }

      final offline = build();
      final offlineArrivals = offline.advance(at(6 * 60));

      String describe(Arrival a) =>
          '${a.at.toIso8601String()} ${a.placeId}#${a.slotIndex} ${a.characterId}';
      expect(
        offlineArrivals.map(describe).toList(),
        liveArrivals.map(describe).toList(),
      );
      expect(offlineArrivals, isNotEmpty);
      expect(offline.rollCount, live.rollCount);
      expect(offline.collection.keys.toSet(), live.collection.keys.toSet());
    });

    test('도착은 시각 순서대로 돌려준다', () {
      final world = World(catalog: Catalog.standard, seed: 7, now: t0)
        ..placeItem('yard', 0, 'seeds')
        ..placeItem('yard', 1, 'water')
        ..placeItem('window', 0, 'bell');
      final arrivals = world.advance(at(24 * 60));
      for (var i = 1; i < arrivals.length; i++) {
        expect(arrivals[i].at.isBefore(arrivals[i - 1].at), isFalse);
      }
    });

    test('시계를 되돌리면 아무 일도 일어나지 않는다', () {
      final world = tinyWorld()..placeItem('p', 0, 'a');
      world.advance(at(3));
      expect(world.advance(at(-60)), isEmpty);
      expect(world.now, at(3));
    });

    test('같은 시드·같은 조작이면 같은 손님이 온다', () {
      List<String> run(int seed) {
        final world = World(catalog: Catalog.standard, seed: seed, now: t0)
          ..placeItem('yard', 0, 'water')
          ..placeItem('yard', 1, 'berry');
        return world.advance(at(12 * 60)).map((a) => a.characterId).toList();
      }

      expect(run(3), run(3));
    });

    test('하루 방치하면 기본 카탈로그에서 여러 친구를 만난다', () {
      final world = World(catalog: Catalog.standard, seed: 11, now: t0);
      for (final (i, item) in ['seeds', 'water', 'berry', 'perch'].indexed) {
        world.placeItem('yard', i, item);
      }
      for (final (i, item) in ['nest', 'bell', 'water'].indexed) {
        world.placeItem('window', i, item);
      }
      world.advance(at(24 * 60));
      expect(world.collection.length, greaterThanOrEqualTo(5));
    });
  });

  group('저장', () {
    test('저장본에서 되살린 세계는 이어서 똑같이 진행한다', () {
      World build() => World(catalog: Catalog.standard, seed: 99, now: t0)
        ..placeItem('yard', 0, 'seeds')
        ..placeItem('yard', 3, 'water')
        ..placeItem('window', 2, 'bell');

      final original = build()..advance(at(90));
      final restored = World.fromJson(
        original.toJson(),
        catalog: Catalog.standard,
      );

      expect(restored.now, original.now);
      expect(restored.rollCount, original.rollCount);
      expect(restored.collection.keys, original.collection.keys);
      for (final place in Catalog.standard.places) {
        for (final (i, slot) in original.slotsOf(place.id).indexed) {
          final other = restored.slot(place.id, i);
          expect(other.itemId, slot.itemId);
          expect(other.nextRollAt, slot.nextRollAt);
          expect(other.visit?.characterId, slot.visit?.characterId);
          expect(other.visit?.leavesAt, slot.visit?.leavesAt);
        }
      }

      List<String> rest(World w) => w
          .advance(at(24 * 60))
          .map((a) => '${a.at} ${a.characterId}')
          .toList();
      expect(rest(restored), rest(original));
    });

    test('카탈로그에서 사라진 아이템·캐릭터는 조용히 버린다', () {
      final world = tinyWorld()
        ..placeItem('p', 0, 'a')
        ..placeItem('p', 1, 'b');
      world.advance(at(5));
      final json = world.toJson();

      final shrunk = Catalog(
        places: const [PlaceDef(id: 'p', name: 'p', emoji: '', slotCount: 2)],
        items: const [ItemDef(id: 'b', name: 'B', emoji: 'B')],
        characters: const [
          CharacterDef(
            id: 'y',
            name: 'Y',
            emoji: 'Y',
            rarity: Rarity.rare,
            likes: {'b'},
            stay: Duration(minutes: 30),
          ),
        ],
      );
      final restored = World.fromJson(json, catalog: shrunk, rules: always);

      expect(restored.slot('p', 0).isEmpty, isTrue);
      expect(restored.slot('p', 1).itemId, 'b');
      expect(restored.collection.keys.every(shrunk.hasCharacter), isTrue);
    });

    test('모르는 저장 버전은 거부한다', () {
      final json = tinyWorld().toJson()..['version'] = 999;
      expect(() => World.fromJson(json, catalog: tiny), throwsFormatException);
    });
  });
}
