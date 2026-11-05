import 'package:deep_grove/domain/board_model.dart';
import 'package:deep_grove/economy/ad_rewards.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final morning = DateTime(2026, 11, 5, 9);

  test('하루 상한 6회, 날짜가 바뀌면 다시 센다', () {
    var ads = const AdRewards();
    for (var i = 0; i < 6; i++) {
      expect(ads.canWatch(morning), isTrue);
      ads = ads.recordWatch(morning);
    }
    expect(ads.remainingToday(morning), 0);
    expect(ads.canWatch(morning.add(const Duration(hours: 14))), isFalse);
    expect(ads.remainingToday(DateTime(2026, 11, 6, 0, 1)), 6);
  });

  test('산출 가속: 30분 2배, 가속 중에 또 보면 끝 시각이 늘어난다', () {
    var ads = const AdRewards().startBoost(morning);
    expect(ads.rateMultiplier(morning), 2);
    expect(ads.boostRemaining(morning), const Duration(minutes: 30));
    ads = ads.startBoost(morning.add(const Duration(minutes: 10)));
    expect(
      ads.boostRemaining(morning.add(const Duration(minutes: 10))),
      const Duration(minutes: 50),
    );
    expect(ads.remainingToday(morning), 4);
    expect(ads.rateMultiplier(morning.add(const Duration(hours: 1))), 1);
  });

  test('자리를 비운 동안 가속이 걸린 앞부분만 2배로 쌓는다', () {
    final board = emptyBoard()
      ..dig()
      ..placeItem(at(0, 4), const Item(woodChain, 5)); // 동굴 = 보너스 없음
    final ads = const AdRewards().startBoost(morning);
    // 1시간: 앞 30분 2배(180) + 뒤 30분 1배(90) = 270 → 창고 빈 공간 1000
    final gain = ads.advanceAway(
      board,
      morning,
      morning.add(const Duration(hours: 1)),
      plenty,
    );
    expect(gain, {Resource.wood: 270});
  });

  test('가속이 저장 전에 끝났으면 배율 없음', () {
    final board = emptyBoard()
      ..dig()
      ..placeItem(at(0, 4), const Item(woodChain, 5));
    final ads = const AdRewards().startBoost(morning);
    final later = morning.add(const Duration(hours: 2));
    final gain = ads.advanceAway(
      board,
      later,
      later.add(const Duration(minutes: 10)),
      plenty,
    );
    expect(gain, {Resource.wood: 30});
  });

  test('저장 형식 왕복, 없거나 깨지면 빈 기록', () {
    final ads = const AdRewards().startBoost(morning).recordWatch(morning);
    final restored = AdRewards.fromJson(ads.toJson());
    expect(restored.toJson(), ads.toJson());
    expect(AdRewards.fromJson(null).toJson(), const AdRewards().toJson());
    expect(AdRewards.fromJson({'day': 3}).watchedOnDay, 0);
  });
}
