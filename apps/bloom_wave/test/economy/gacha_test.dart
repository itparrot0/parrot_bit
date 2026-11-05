import 'dart:convert';
import 'dart:math' as math;

import 'package:bloom_wave/economy/gacha.dart';
import 'package:bloom_wave/economy/skins.dart';
import 'package:bloom_wave/save/save_store.dart';
import 'package:flutter_test/flutter_test.dart';

SaveData rich([int gold = 100000]) => SaveData(gold: gold);

void main() {
  test('설정: 뽑기 100골드, 중복 반환 10% = 10골드', () {
    expect(GachaConfig.pullCost, 100);
    expect(GachaConfig.refund, (GachaConfig.pullCost * 0.1).floor());
  });

  test('후보는 해금 안 된 스킨의 모든 조각 (기본 스킨 제외), 조각마다 같은 확률', () {
    final d = rich();
    final pool = gachaPool(d);
    expect(pool.length, gachaSkins.fold<int>(0, (n, s) => n + s.pieces));
    expect(pool.any((p) => p.skin.isDefault), isFalse);
    final odds = gachaOdds(d);
    expect(odds.fold<double>(0, (a, o) => a + o.chance), closeTo(1, 1e-9));
    for (final o in odds) {
      expect(o.perPiece, closeTo(1 / pool.length, 1e-12));
    }
  });

  test('새 조각: 골드 차감, 조각 기록', () {
    final d = rich(250);
    final r = pull(d, math.Random(1));
    expect(r.outcome, PullOutcome.newPiece);
    expect(d.gold, 150);
    expect(d.skinPieces[r.skin.id], {r.piece});
    expect(r.refund, 0);
  });

  test('중복 조각: 뽑기 골드의 10% 반환', () {
    // 한 스킨만 남기고 나머지는 해금, 남은 스킨의 조각 하나만 빼고 모두 보유
    final d = rich(10000);
    final target = gachaSkins.first;
    for (final s in gachaSkins.skip(1)) {
      d.skinPieces[s.id] = {for (var i = 0; i < s.pieces; i++) i};
    }
    d.skinPieces[target.id] = {0, 1, 2};
    var dup = 0, gold = d.gold;
    final rng = math.Random(1);
    for (var k = 0; k < 40 && !d.isUnlocked(target); k++) {
      final r = pull(d, rng);
      expect(r.skin.id, target.id);
      if (r.outcome == PullOutcome.duplicate) {
        dup++;
        expect(r.refund, GachaConfig.refund);
        expect(d.gold, gold - GachaConfig.pullCost + GachaConfig.refund);
      } else {
        expect(r.outcome, PullOutcome.unlocked);
        expect(r.piece, 3);
        expect(d.gold, gold - GachaConfig.pullCost);
      }
      gold = d.gold;
    }
    expect(d.isUnlocked(target), isTrue);
    expect(dup, greaterThan(0));
  });

  test('조각을 모두 모으면 해금되고, 그 뒤로는 그 스킨 조각이 나오지 않는다', () {
    final d = rich();
    final rng = math.Random(3);
    final unlockedAt = <String, int>{};
    for (var k = 0; k < 2000 && gachaPool(d).isNotEmpty; k++) {
      final r = pull(d, rng);
      expect(
        unlockedAt.containsKey(r.skin.id),
        isFalse,
        reason: '${r.skin.id} 는 해금 뒤에 나오면 안 된다',
      );
      if (r.outcome == PullOutcome.unlocked) unlockedAt[r.skin.id] = k;
    }
    expect(unlockedAt.keys.toSet(), {for (final s in gachaSkins) s.id});
    expect(pullBlock(d), PullBlock.allUnlocked);
    expect(() => pull(d, rng), throwsStateError);
    // 해금된 스킨은 확률 0
    expect(gachaOdds(d).every((o) => o.chance == 0), isTrue);
  });

  test('해금된 스킨을 빼면 남은 스킨끼리 확률을 나눈다', () {
    final d = rich();
    final s0 = gachaSkins.first;
    d.skinPieces[s0.id] = {for (var i = 0; i < s0.pieces; i++) i};
    final odds = {for (final o in gachaOdds(d)) o.skin.id: o.chance};
    expect(odds[s0.id], 0);
    final rest = gachaSkins.skip(1).fold<int>(0, (n, s) => n + s.pieces);
    for (final s in gachaSkins.skip(1)) {
      expect(odds[s.id], closeTo(s.pieces / rest, 1e-12));
    }
    expect(odds.values.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-9));
  });

  test('골드가 모자라면 뽑을 수 없고 아무것도 바뀌지 않는다', () {
    final d = rich(GachaConfig.pullCost - 1);
    expect(pullBlock(d), PullBlock.notEnoughGold);
    expect(() => pull(d, math.Random(1)), throwsStateError);
    expect(d.gold, GachaConfig.pullCost - 1);
    expect(d.skinPieces, isEmpty);
  });

  test('많이 뽑으면 스킨별 빈도가 공개 확률과 비슷하다', () {
    // 해금이 일어나지 않게 조각을 저장하지 않는 사본으로 반복
    final rng = math.Random(11);
    final counts = <String, int>{};
    const n = 20000;
    for (var k = 0; k < n; k++) {
      final r = pull(rich(), rng);
      counts[r.skin.id] = (counts[r.skin.id] ?? 0) + 1;
    }
    for (final o in gachaOdds(rich())) {
      expect(counts[o.skin.id]! / n, closeTo(o.chance, 0.015));
    }
  });

  group('저장 (스킨)', () {
    test('뽑기 결과·장착이 저장되고 다시 읽힌다', () async {
      final kv = MemoryStore();
      final a = SaveStore(kv);
      await a.load();
      a.data.gold = 1000;
      final r = await a.pullSkin(math.Random(5));
      expect(await a.equipSkin(r.skin.id), isFalse); // 조각 하나로는 해금 안 됨
      final s = gachaSkins.first;
      a.data.skinPieces[s.id] = {0, 1, 2, 3};
      expect(await a.equipSkin(s.id), isTrue);
      final b = await SaveStore(kv).load();
      expect(jsonDecode(kv.map[saveKey]!)['schema'], saveSchema);
      expect(b.gold, a.data.gold);
      expect(b.skinPieces[r.skin.id], contains(r.piece));
      expect(b.equippedSkin, s.id);
      expect(b.skin.id, s.id);
    });

    test('schema 3 저장은 기본 스킨, 모르는 스킨·범위 밖 조각은 버린다', () async {
      final d3 = await SaveStore(
        MemoryStore({
          saveKey: jsonEncode({'schema': 3, 'gold': 40}),
        }),
      ).load();
      expect(d3.gold, 40);
      expect(d3.skinPieces, isEmpty);
      expect(d3.skin.id, defaultSkinId);
      final bad = await SaveStore(
        MemoryStore({
          saveKey: jsonEncode({
            'skins': {
              'pieces': {
                'daisy': [0, 9, -1, 'x', 2],
                'nope': [0],
                'basic': [0],
              },
              'equipped': 'tulip',
            },
          }),
        }),
      ).load();
      expect(bad.skinPieces, {
        'daisy': {0, 2},
      });
      // 해금 안 된 스킨이 장착돼 있으면 기본 스킨으로 그린다
      expect(bad.equippedSkin, 'tulip');
      expect(bad.skin.id, defaultSkinId);
    });
  });
}
