// 햇빛(라이프) 규칙 (2026-11-05): 최대 5, 20분마다 1개, 시작할 때 1개·완성하면 돌려받음,
// 가득 채우기는 골드 또는 광고(하루 1번, 아침 6시 초기화)
import 'package:bloom_wave/economy/lives.dart';
import 'package:bloom_wave/save/save_store.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 11, 5, 12);
DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

void main() {
  test('가득일 때 쓰면 그때부터 20분마다 1개씩, 최대 5개에서 멈춘다', () {
    final l = Lives();
    expect(l.spend(t0), isTrue);
    expect(l.spend(t0), isTrue);
    expect(l.count, 3);
    expect(l.untilNext(at(5)), const Duration(minutes: 15));
    l.settle(at(19));
    expect(l.count, 3);
    l.settle(at(20));
    expect(l.count, 4);
    expect(l.untilNext(at(25)), const Duration(minutes: 15));
    l.settle(at(39));
    expect(l.count, 4);
    l.settle(at(40));
    expect(l.count, 5);
    expect(l.full, isTrue);
    expect(l.untilNext(at(500)), isNull);
    l.settle(at(1000));
    expect(l.count, 5);
  });

  test('회복 도중에 써도 회복 시계는 그대로 간다 (가득에서 쓸 때만 새로 시작)', () {
    final l = Lives();
    l.spend(t0); // 4, 기준 0분
    l.spend(at(10)); // 3, 기준은 그대로 0분
    l.settle(at(20));
    expect(l.count, 4);
    expect(l.untilNext(at(20)), const Duration(minutes: 20));
  });

  test('0개면 쓸 수 없고, 앱이 꺼져 있던 시간만큼 한꺼번에 찬다', () {
    final l = Lives();
    for (var i = 0; i < 5; i++) {
      expect(l.spend(t0), isTrue);
    }
    expect(l.spend(t0), isFalse);
    expect(l.count, 0);
    l.settle(at(65)); // 3개 + 5분
    expect(l.count, 3);
    expect(l.untilNext(at(65)), const Duration(minutes: 15));
  });

  test('완성하면 돌려받는다 (최대를 넘지 않음)', () {
    final l = Lives();
    l.spend(t0);
    l.refund(at(1));
    expect(l.count, 5);
    expect(l.full, isTrue);
    expect(l.anchorMs, isNull);
  });

  test('시계를 뒤로 돌려도 몰아 받지 못하고 회복이 멈추지도 않는다', () {
    final l = Lives();
    l.spend(t0);
    l.spend(t0);
    l.settle(t0.subtract(const Duration(hours: 5)));
    expect(l.count, 3);
    // 기준이 당겨진 시각부터 20분
    l.settle(t0.subtract(const Duration(hours: 5)).add(lifeRegen));
    expect(l.count, 4);
  });

  test('광고 충전 하루 경계는 아침 6시', () {
    expect(adDayKey(DateTime(2026, 11, 6, 5, 59)), '2026-11-05');
    expect(adDayKey(DateTime(2026, 11, 6, 6)), '2026-11-06');
    expect(adDayKey(DateTime(2026, 1, 1, 3)), '2025-12-31');
    final l = Lives()..adDay = adDayKey(DateTime(2026, 11, 5, 23));
    expect(l.adAvailable(DateTime(2026, 11, 6, 5, 59)), isFalse);
    expect(l.adAvailable(DateTime(2026, 11, 6, 6)), isTrue);
  });

  test('남은 시간 표시', () {
    expect(formatLeft(const Duration(minutes: 19, seconds: 59)), '19:59');
    expect(formatLeft(const Duration(milliseconds: 1500)), '00:02');
    expect(
      formatLeft(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  group('저장', () {
    test('옛 저장(schema 5)은 햇빛 가득, 깨진 값도 범위 안으로', () {
      expect(migrate({'schema': 5, 'unlocked': 30}).lives.count, maxLives);
      final d = migrate({
        'lives': {'count': 99, 'anchor': 'x', 'adDay': 3},
      });
      expect(d.lives.count, maxLives);
      expect(d.lives.adDay, '');
      final e = migrate({
        'lives': {'count': 2, 'anchor': 1000, 'adDay': '2026-11-05'},
      });
      expect(e.lives.count, 2);
      expect(e.lives.anchorMs, 1000);
      expect(e.lives.adAvailable(DateTime(2026, 11, 5, 12)), isFalse);
    });

    test('저장했다 다시 읽어도 같다', () async {
      final kv = MemoryStore();
      final s = SaveStore(kv);
      await s.load();
      s.spendLife(t0);
      s.spendLife(t0);
      await s.save();
      final s2 = SaveStore(kv);
      await s2.load();
      expect(s2.data.lives.count, 3);
      expect(s2.data.lives.anchorMs, t0.millisecondsSinceEpoch);
    });

    test('골드로 채우기: 골드가 모자라거나 이미 가득이면 안 된다', () async {
      final s = SaveStore(MemoryStore());
      s.data.gold = refillGoldCost - 1;
      s.spendLife(t0);
      expect(await s.refillLivesWithGold(t0), isFalse);
      expect(s.data.gold, refillGoldCost - 1);
      s.data.gold = refillGoldCost + 5;
      expect(await s.refillLivesWithGold(t0), isTrue);
      expect(s.data.lives.count, maxLives);
      expect(s.data.gold, 5);
      s.data.gold = 1000;
      expect(await s.refillLivesWithGold(t0), isFalse); // 가득
      expect(s.data.gold, 1000);
    });

    test('광고로 채우기는 하루 1번, 아침 6시에 다시', () async {
      final s = SaveStore(MemoryStore());
      for (var i = 0; i < 5; i++) {
        s.spendLife(t0);
      }
      expect(await s.refillLivesWithAd(t0), isTrue);
      expect(s.data.lives.count, maxLives);
      for (var i = 0; i < 5; i++) {
        s.spendLife(at(1));
      }
      expect(await s.refillLivesWithAd(DateTime(2026, 11, 6, 5, 59)), isFalse);
      expect(s.data.lives.count, 0);
      expect(await s.refillLivesWithAd(DateTime(2026, 11, 6, 6)), isTrue);
      expect(s.data.lives.count, maxLives);
    });
  });
}
