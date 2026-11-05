import 'dart:math';

import 'package:core_storage/core_storage.dart';
import 'package:deep_grove/domain/board_model.dart';
import 'package:deep_grove/economy/ad_rewards.dart';
import 'package:deep_grove/economy/economy.dart';
import 'package:deep_grove/save/save_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final t0 = DateTime(2026, 11, 5, 12);

  test('저장이 없으면 시작 보드로 새로 시작한다', () async {
    final repo = SaveRepository(InMemoryKeyValueStore());
    final loaded = await repo.load(forestCaveTheme, now: t0);
    expect(loaded.isNew, isTrue);
    expect(loaded.board.cells, hasLength(3));
    expect(loaded.idleGain, isEmpty);
  });

  test('저장 → 불러오기 왕복, 자리를 비운 동안의 산출이 쌓인다', () async {
    final store = InMemoryKeyValueStore();
    final repo = SaveRepository(store);
    final board = emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 5));
    const economy = Economy(
      theme: forestCaveTheme,
      amounts: {Resource.wood: 4},
    );
    await repo.write(GroveSave(board: board, economy: economy, savedAt: t0));

    // 숲의 거목: 20초에 1.5 → 10분이면 45, 창고 빈 공간 26에서 멈춘다.
    final loaded = await repo.load(
      forestCaveTheme,
      now: t0.add(const Duration(minutes: 10)),
      random: Random(1),
    );
    expect(loaded.isNew, isFalse);
    expect(loaded.economy.amountOf(Resource.wood), 4);
    expect(loaded.idleGain, {Resource.wood: 26});
    expect(loaded.board.harvestAll(), {Resource.wood: 26});
  });

  test('시계를 되돌렸으면 경과 시간을 0으로 본다', () async {
    final repo = SaveRepository(InMemoryKeyValueStore());
    final board = emptyBoard()..placeItem(at(0, 0), const Item(woodChain, 5));
    await repo.write(
      GroveSave(
        board: board,
        economy: const Economy(theme: forestCaveTheme),
        savedAt: t0,
      ),
    );
    final loaded = await repo.load(
      forestCaveTheme,
      now: t0.subtract(const Duration(hours: 3)),
    );
    expect(loaded.idleGain, isEmpty);
  });

  test('깨진 저장은 새로 시작한다', () async {
    final store = InMemoryKeyValueStore({
      SaveRepository.key: '{"schema":1,"board":3}',
    });
    final loaded = await SaveRepository(store).load(forestCaveTheme, now: t0);
    expect(loaded.isNew, isTrue);
  });

  test('광고 산출 가속이 걸린 채 저장했으면 오프라인 산출에도 남은 가속을 반영한다', () async {
    final store = InMemoryKeyValueStore();
    final board = emptyBoard()
      ..openCaveRow()
      ..placeItem(at(0, 4), const Item(woodChain, 5)); // 동굴: 20초에 1
    await SaveRepository(store).write(
      GroveSave(
        board: board,
        economy: const Economy(theme: forestCaveTheme, storageLevel: 2),
        ads: const AdRewards().startBoost(
          t0.subtract(const Duration(minutes: 20)),
        ),
        savedAt: t0,
      ),
    );
    // 가속 10분 남음: 10분 2배(60) + 10분 1배(30) = 90, 창고 120
    final loaded = await SaveRepository(
      store,
    ).load(forestCaveTheme, now: t0.add(const Duration(minutes: 20)));
    expect(loaded.idleGain, {Resource.wood: 90});
    expect(loaded.ads.remainingToday(t0), 5);
  });

  test('광고 기록이 없는 옛 저장도 읽는다', () async {
    final store = InMemoryKeyValueStore();
    final repo = SaveRepository(store);
    await repo.write(
      GroveSave(
        board: emptyBoard(),
        economy: const Economy(theme: forestCaveTheme),
        savedAt: t0,
      ),
    );
    final raw = (await store.getString(
      SaveRepository.key,
    ))!.replaceFirst(RegExp(r',"ads":\{[^}]*\}'), '');
    expect(raw.contains('"ads"'), isFalse);
    await store.setString(SaveRepository.key, raw);
    final loaded = await repo.load(forestCaveTheme, now: t0);
    expect(loaded.isNew, isFalse);
    expect(loaded.ads.remainingToday(t0), 6);
  });
}
