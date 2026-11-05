import 'dart:convert';
import 'dart:math' as math;

import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/domain/generator.dart';
import 'package:bloom_wave/domain/solver.dart';
import 'package:bloom_wave/economy/gold.dart';
import 'package:bloom_wave/economy/items.dart';
import 'package:bloom_wave/game/colors.dart';
import 'package:bloom_wave/game/game_controller.dart';
import 'package:bloom_wave/i18n/strings.dart';
import 'package:bloom_wave/save/save_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/sample_arts.dart';
import '../helpers.dart';

Drop d(int c, int a) => Drop(c, a);

/// 1행 5칸: a a b a a, 시작 발아는 0번. 기본: 한 줄 + 빈 줄 둘
Level line(List<Drop> queue, [List<List<Drop>>? extra]) => Level(
  id: 't',
  width: 5,
  height: 1,
  palette: const ['#f00', '#00f'],
  cells: const [0, 0, 1, 0, 0],
  starts: const [0],
  lanes: [
    queue,
    ...(extra ?? [[], []]),
  ],
);

GameController playSolution(Level level) {
  final c = GameController(level, manual: true);
  final sol = solve(level, c.options);
  expect(sol.solvable, isTrue);
  for (final a in sol.solution) {
    switch (a) {
      case Deploy(:final lane):
        expect(c.tap(lane).ok, isTrue);
        if (!c.options.realtime) {
          while (c.step() != null) {}
        }
      case Tick():
        expect(c.step(), isNotNull);
    }
  }
  return c;
}

void main() {
  group('GameController', () {
    test('고정 간격 타이머: x2 속도 300ms마다 한 틱, 일시정지 중에는 멈춤 (기본은 450ms)', () {
      expect(GameController(line([d(0, 2)])).tickMs, baseTickMs);
      expect((baseTickMs, x2TickMs), (450, 300));
      final c = GameController(
        line([d(0, 2), d(1, 1), d(0, 2)]),
        tickMs: x2TickMs,
      );
      final ticks = <int>[];
      c.listen(ControllerEvents(onTick: (ev) => ticks.add(ev.tick)));
      c.tap(0);
      c.update(250);
      expect(ticks, isEmpty);
      c.update(60);
      expect(ticks, [0]);
      c.pause();
      c.update(1000);
      expect(ticks, [0]);
      c.resume();
      c.update(300);
      expect(ticks, [0, 1]);
    });

    test('아무 줄이나 맨 앞을 탭, 빈 줄은 empty, 쓸 수 없는 물방울로 슬롯이 꽉 차면 실패', () {
      final c = GameController(
        line(
          [d(1, 1), d(1, 1)],
          [
            [d(1, 1), d(1, 1)],
            [],
            [d(0, 4)],
          ],
        ),
      );
      expect(c.usable(0), isFalse);
      expect(c.usable(3), isTrue);
      expect(c.canTap(2), isFalse);
      expect(c.tap(2).fail, TapFail.empty);
      final r = c.tap(1);
      expect((r.ok, r.slot, r.lane), (true, 0, 1));
      expect(c.front(1), d(1, 1));
      expect(c.tap(0).ok, isTrue);
      expect(c.tap(0).ok, isTrue);
      expect(c.tap(1).ok, isTrue);
      expect(c.status, Status.failed);
      expect(c.tap(3).fail, TapFail.over);
    });

    test('realtime=false 레벨은 웨이브 중 탭을 거절한다', () {
      final base = line([d(0, 2), d(1, 1), d(0, 2)]);
      final lv = Level(
        id: base.id,
        width: 5,
        height: 1,
        palette: base.palette,
        cells: base.cells,
        starts: base.starts,
        lanes: base.lanes,
        realtime: false,
      );
      final c = GameController(lv, manual: true);
      expect(c.tap(0).ok, isTrue);
      expect(c.active, isTrue);
      expect(c.tap(0).fail, TapFail.wait);
    });

    test('솔버 해법대로 두면 클리어된다 (3줄 대기열)', () {
      for (final art in sampleArts) {
        final r = generate(
          art,
          const GenParams(
            seed: 2,
            starts: 1,
            dropMin: 1,
            dropMax: 4,
            displacements: 30,
            lanes: 3,
            trials: 20,
          ),
        );
        final c = playSolution(r.level);
        expect(c.status, Status.cleared);
        expect(c.state.cell.every((x) => x == bloom || x == empty), isTrue);
      }
    });

    test('출시 팩 앞 20 레벨: 솔버 해법대로 두면 클리어', () {
      for (final l in pack.take(20)) {
        expect(playSolution(l).status, Status.cleared, reason: l.id);
      }
    });

    test('재시작하면 처음 상태', () {
      final c = GameController(line([d(0, 2), d(1, 1), d(0, 2)]), manual: true);
      c.tap(0);
      c.step();
      c.restart();
      expect(c.queueLeft, 3);
      expect(c.peak, 0);
    });

    test('아이템: 슬롯 추가(최대 6), 섞기(완성 가능), 즉시 개화', () {
      final rng = math.Random(4);
      final c = GameController(pack[20], manual: true);
      expect(c.addSlotItem(), isTrue);
      expect(c.state.slots.length, 5);
      expect(c.addSlotItem(), isTrue);
      expect(c.canAddSlot, isFalse);
      expect(c.addSlotItem(), isFalse);

      final before = [for (final l in c.state.lanes) ...l]
        ..sort((a, b) => a.color * 100 + a.amount - b.color * 100 - b.amount);
      final lens = [for (final l in c.state.lanes) l.length];
      expect(c.shuffleItem(rng.nextInt), isTrue);
      final after = [for (final l in c.state.lanes) ...l]
        ..sort((a, b) => a.color * 100 + a.amount - b.color * 100 - b.amount);
      expect(after, before);
      expect([for (final l in c.state.lanes) l.length], lens);
      expect(
        solveFrom(c.level, c.state, c.options, 50000).solvable,
        isNot(false),
      );

      // 퍼질 곳 없는 맨 앞 물방울을 넣고 즉시 개화
      final s = c.state;
      final lane = [for (var i = 0; i < s.lanes.length; i++) i].firstWhere(
        (i) =>
            s.lanes[i].isNotEmpty && s.sproutCount[s.lanes[i].first.color] == 0,
      );
      final drop = s.lanes[lane].first.copy();
      final slot = c.tap(lane).slot;
      expect(c.stuck, contains(slot));
      final bloomBefore = s.cell.where((x) => x == bloom).length;
      final ev = c.bloomItem(slot, rng.nextInt)!;
      expect(ev.blooms.single.cells.length, drop.amount);
      expect(
        ev.blooms.single.cells.every((i) => c.level.cells[i] == drop.color),
        isTrue,
      );
      expect(s.cell.where((x) => x == bloom).length, bloomBefore + drop.amount);
      expect(s.slots[slot], isNull);
      expect(c.bloomItem(slot, rng.nextInt), isNull);
    });
  });

  group('SaveStore', () {
    test('저장 → 불러오기 왕복: 완성 여부·다음 스테이지·광고 제거·골드·설정', () async {
      final kv = MemoryStore();
      final a = SaveStore(kv);
      await a.load();
      expect(await a.recordClear('tulip', 1, 120, gold: 17), 17);
      // 같은 레벨을 두 번 기록해도 골드는 한 번만
      expect(await a.recordClear('tulip', 1, 120, gold: 25), 0);
      await a.setNoAds(true);
      await a.updateSettings(const Settings(lang: 'en'));
      await a.setX2(ms: 1234, on: true);
      expect(await a.unlockItem(ItemKind.slot), isTrue);
      expect(await a.unlockItem(ItemKind.slot), isFalse); // 한 번만 지급
      expect(await a.useItem(ItemKind.slot, tutorial: true), isTrue);
      final d = await SaveStore(kv).load();
      expect(jsonDecode(kv.map[saveKey]!)['schema'], saveSchema);
      expect(d.cleared, {'tulip'});
      expect(d.unlocked, 2);
      expect(d.noAds, isTrue);
      expect(d.gold, 17);
      expect(d.settings.lang, 'en');
      expect((d.x2Ms, d.x2On), (1234, true));
      expect(d.itemCount(ItemKind.slot), 2);
      expect(d.itemsUnlocked, {ItemKind.slot});
      expect(d.itemTutorialDone, {ItemKind.slot});
    });

    test('schema 4 → 5: x2 10분, 해금 스테이지를 지난 저장은 아이템 2개씩', () async {
      final fresh = await SaveStore(
        MemoryStore({
          saveKey: jsonEncode({'schema': 4, 'unlocked': 3}),
        }),
      ).load();
      expect(fresh.x2Ms, x2InitialMs);
      expect(fresh.x2On, isFalse);
      expect(fresh.itemsUnlocked, isEmpty);
      final mid = await SaveStore(
        MemoryStore({
          saveKey: jsonEncode({'schema': 4, 'unlocked': 13}),
        }),
      ).load();
      expect(mid.itemsUnlocked, {ItemKind.slot, ItemKind.shuffle});
      expect(mid.itemCount(ItemKind.slot), 2);
      expect(mid.itemCount(ItemKind.bloom), 0);
      final empty = await SaveStore(
        MemoryStore({
          saveKey: jsonEncode({
            'x2': {'ms': 0, 'on': true},
          }),
        }),
      ).load();
      expect(empty.x2On, isFalse); // 남은 시간이 없으면 켜질 수 없다
    });

    test('마지막 스테이지를 완성하면 다음 스테이지는 total+1 (모두 완성)', () async {
      final s = SaveStore(MemoryStore());
      await s.load();
      await s.recordClear('b', 2, 2, gold: 5);
      expect(s.data.unlocked, 3);
    });

    test('schema 1(별점)·2 저장을 옮긴다: 골드는 0에서 시작', () async {
      final s1 = SaveStore(
        MemoryStore({
          saveKey: jsonEncode({
            'schema': 1,
            'unlocked': 4,
            'stars': {'a': 3, 'b': 1, 'c': 0},
          }),
        }),
      );
      final d1 = await s1.load();
      expect(d1.cleared, {'a', 'b'});
      expect(d1.unlocked, 4);
      expect(d1.gold, 0);
      final s2 = SaveStore(
        MemoryStore({
          saveKey: jsonEncode({
            'schema': 2,
            'unlocked': 3,
            'cleared': {'a': true},
            'noAds': true,
            'settings': {'lang': 'en', 'tickSpeed': 'slow'},
          }),
        }),
      );
      final d2 = await s2.load();
      expect(d2.noAds, isTrue);
      expect(d2.gold, 0);
      expect(d2.settings.lang, 'en');
    });

    test('깨진 저장은 기본값으로', () async {
      final d = await SaveStore(
        MemoryStore({saveKey: '{not json'}),
      ).load(lang: 'en');
      expect(d.unlocked, 1);
      expect(d.gold, 0);
      expect(d.settings.lang, 'en');
      final d2 = await SaveStore(
        MemoryStore({
          saveKey: jsonEncode({'gold': -5, 'unlocked': 'x'}),
        }),
      ).load();
      expect(d2.gold, 0);
      expect(d2.unlocked, 1);
    });
  });

  test('골드 보상은 범위 안에서 무작위, 양 끝도 나온다', () {
    const r = GoldReward(min: 3, max: 6);
    final rng = math.Random(42);
    final seen = {for (var i = 0; i < 500; i++) r.roll(rng)};
    expect(seen, {3, 4, 5, 6});
    expect(goldReward.min, lessThanOrEqualTo(goldReward.max));
  });

  test('비슷한 색: 출시 팩에서 처음 나오는 스테이지', () {
    expect(colorDistance('#ff0000', '#ff0000'), 0);
    expect(similarPair(pack[firstSimilarLevel(pack) - 1]), isNotNull);
    expect(firstSimilarLevel(pack), greaterThan(1));
  });

  test('문구: 한국어와 영어 키가 같다', () {
    expect(ko.keys.toSet(), en.keys.toSet());
    expect(const Strings('ko').t('startStage', {'n': 3}), '스테이지 3 시작');
  });
}
