import 'dart:math';

import 'package:core_storage/core_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proto_idle_visit/data/world_repository.dart';

final t0 = DateTime.utc(2026, 11, 4, 9);

void main() {
  test('저장본이 없으면 새 세계를 만든다', () async {
    final repo = WorldRepository(
      InMemoryKeyValueStore(),
      seedSource: Random(1),
    );
    final loaded = await repo.load(t0);

    expect(loaded.world.now, t0);
    expect(loaded.world.collection, isEmpty);
    expect(loaded.arrivals, isEmpty);
  });

  test('저장 후 다시 열면 꺼져 있던 동안의 방문이 진행된다', () async {
    final store = InMemoryKeyValueStore();
    final repo = WorldRepository(store, seedSource: Random(1));

    final first = await repo.load(t0);
    first.world
      ..placeItem('yard', 0, 'seeds')
      ..placeItem('yard', 1, 'water')
      ..placeItem('window', 0, 'berry');
    await repo.save(first.world);

    final later = t0.add(const Duration(hours: 8));
    final second = await repo.load(later);

    expect(second.world.now, later);
    expect(second.world.seed, first.world.seed);
    expect(second.world.slot('yard', 0).itemId, 'seeds');
    expect(second.arrivals, isNotEmpty);
    expect(second.world.collection, isNotEmpty);
  });

  test('깨진 저장본은 버리고 새로 시작한다', () async {
    final store = InMemoryKeyValueStore({WorldRepository.worldKey: '{oops'});
    final loaded = await WorldRepository(store).load(t0);

    expect(loaded.world.slotsOf('yard').every((s) => s.isEmpty), isTrue);
  });

  test('빨리 감기 오프셋을 저장한다', () async {
    final repo = WorldRepository(InMemoryKeyValueStore());
    expect(await repo.loadClockOffset(), Duration.zero);

    await repo.saveClockOffset(const Duration(minutes: 90));
    expect(await repo.loadClockOffset(), const Duration(minutes: 90));
  });
}
