import 'dart:math';

import '../domain/board_model.dart';

/// 보상형 광고 수치 (PRD §6). 숫자를 바꿀 때는 여기만 고친다.
final class AdRewardConfig {
  const AdRewardConfig({
    required this.dailyLimit,
    required this.boostDuration,
    required this.boostMultiplier,
    required this.welcomeMultiplier,
  });

  /// 하루에 볼 수 있는 보상형 광고 수 (복귀 보상·산출 가속 합쳐서). 날짜는 기기 시각 기준.
  final int dailyLimit;

  /// 광고 한 번으로 얻는 산출 가속 시간. 가속 중에 또 보면 끝 시각이 그만큼 늘어난다.
  final Duration boostDuration;

  /// 가속 중 산출 배율.
  final double boostMultiplier;

  /// 복귀 보상 광고 배율.
  final int welcomeMultiplier;
}

/// 첫 값 (PRD §10-3 경제 수치와 함께 조절).
const AdRewardConfig adRewardConfig = AdRewardConfig(
  dailyLimit: 6,
  boostDuration: Duration(minutes: 30),
  boostMultiplier: 2,
  welcomeMultiplier: 2,
);

/// 보상형 광고 시청 기록과 산출 가속 상태. 불변 값.
final class AdRewards {
  const AdRewards({
    this.config = adRewardConfig,
    this.day = '',
    this.watchedOnDay = 0,
    this.boostUntil,
  });

  final AdRewardConfig config;

  /// [watchedOnDay]를 센 날 (`yyyy-mm-dd`, 기기 현지 날짜).
  final String day;
  final int watchedOnDay;

  /// 산출 가속이 끝나는 시각. 지났거나 null이면 가속 없음.
  final DateTime? boostUntil;

  static String dayOf(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  int remainingToday(DateTime now) =>
      max(0, config.dailyLimit - (day == dayOf(now) ? watchedOnDay : 0));

  bool canWatch(DateTime now) => remainingToday(now) > 0;

  /// 광고 한 편을 끝까지 봤다.
  AdRewards recordWatch(DateTime now) => _copy(
    day: dayOf(now),
    watchedOnDay: (day == dayOf(now) ? watchedOnDay : 0) + 1,
  );

  bool boostActive(DateTime now) => boostUntil?.isAfter(now) ?? false;

  Duration boostRemaining(DateTime now) =>
      boostActive(now) ? boostUntil!.difference(now) : Duration.zero;

  /// 산출 가속 광고를 봤다: 시청 1회 + 가속 시간 연장.
  AdRewards startBoost(DateTime now) {
    final base = boostActive(now) ? boostUntil! : now;
    return recordWatch(now)._copy(boostUntil: base.add(config.boostDuration));
  }

  /// 지금 산출 배율.
  double rateMultiplier(DateTime now) =>
      boostActive(now) ? config.boostMultiplier : 1;

  /// [from]~[to] 동안 [board]의 시간을 흘린다. 그중 가속이 걸린 앞부분은 배율을 곱한다.
  /// [baseMultiplier]는 상품(영구 산출 가속) 배율로, 전 구간에 곱한다.
  /// 새로 익은 양을 돌려준다 (복귀 보상 표시용).
  Map<Resource, int> advanceAway(
    BoardModel board,
    DateTime from,
    DateTime to,
    Map<Resource, int> freeSpace, {
    double baseMultiplier = 1,
  }) {
    final total = max(0, to.difference(from).inMilliseconds) / 1000;
    final until = boostUntil;
    final boosted = until == null
        ? 0.0
        : min(total, max(0, until.difference(from).inMilliseconds) / 1000);
    final first = board.advanceAway(
      boosted,
      freeSpace,
      multiplier: config.boostMultiplier * baseMultiplier,
    );
    final second = board.advanceAway(
      total - boosted,
      freeSpace,
      multiplier: baseMultiplier,
    );
    return {
      for (final r in Resource.values)
        if ((first[r] ?? 0) + (second[r] ?? 0) > 0)
          r: (first[r] ?? 0) + (second[r] ?? 0),
    };
  }

  AdRewards _copy({String? day, int? watchedOnDay, DateTime? boostUntil}) =>
      AdRewards(
        config: config,
        day: day ?? this.day,
        watchedOnDay: watchedOnDay ?? this.watchedOnDay,
        boostUntil: boostUntil ?? this.boostUntil,
      );

  Map<String, Object?> toJson() => {
    'day': day,
    'watchedOnDay': watchedOnDay,
    'boostUntil': boostUntil?.millisecondsSinceEpoch,
  };

  /// 저장에 없거나 깨졌으면 빈 기록 (광고 기록은 잃어도 진행에 지장이 없다).
  static AdRewards fromJson(Object? json) {
    if (json case {
      'day': final String day,
      'watchedOnDay': final int watched,
      'boostUntil': final int? until,
    }) {
      return AdRewards(
        day: day,
        watchedOnDay: watched,
        boostUntil: until == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(until),
      );
    }
    return const AdRewards();
  }
}
