import 'dart:math' as math;

import 'diary_entry.dart';
import 'sleep_session.dart';

/// 개운함 하나의 수면 대조 결과.
typedef RestSleepStat = ({
  RestFeeling feeling,
  int dayCount,
  Duration averageSleep,
});

/// "개운했던 날 평균 몇 시간 / 덜 풀린 날 몇 시간" 대조 (PRD §3-5).
abstract final class RestSleepReport {
  /// 개운함과 수면을 둘 다 남긴 날이 이만큼 쌓이기 전에는 보여 주지 않는다.
  static const int minimumDays = 7;

  /// [RestFeeling] 순서대로. 개운함이나 수면이 없는 날은 세지 않는다.
  static List<RestSleepStat> build(Iterable<DiaryEntry> entries) {
    final minutes = <RestFeeling, List<int>>{};
    for (final entry in entries) {
      final feeling = entry.rested;
      final duration = entry.sleepDuration;
      if (feeling != null && duration != null) {
        minutes.putIfAbsent(feeling, () => []).add(duration.inMinutes);
      }
    }
    return [
      for (final feeling in RestFeeling.values)
        if (minutes[feeling] case final list?)
          (
            feeling: feeling,
            dayCount: list.length,
            averageSleep: Duration(
              minutes: list.reduce((a, b) => a + b) ~/ list.length,
            ),
          ),
    ];
  }

  static bool hasEnoughData(List<RestSleepStat> stats) =>
      stats.fold(0, (sum, s) => sum + s.dayCount) >= minimumDays;
}

/// 잠든 시각이 얼마나 고른가.
enum BedtimeSpread {
  steady('대체로 고른 편이에요'),
  varied('조금씩 오르내렸어요'),
  wide('크게 오르내렸어요');

  const BedtimeSpread(this.description);

  /// 판정이 아니라 묘사다 — "불규칙해서 나쁘다"고 말하지 않는다.
  final String description;
}

/// 잠든 시각의 규칙성 (PRD §3-5). 수면시간이 같아도 잠드는 시각이 들쭉날쭉하면
/// 다음 날이 다르게 느껴질 수 있다 — 그 흐름을 볼 수 있게 한다.
final class BedtimeRegularity {
  const BedtimeRegularity._({
    required this.averageBedtime,
    required this.spread,
    required this.dayCount,
  });

  /// 이만큼 있어야 계산한다. 서너 날로는 "고르다"를 말할 수 없다.
  static const int minimumDays = 5;

  /// 표준편차가 이보다 작으면 고른 편, [wideFrom] 이상이면 크게 오르내림.
  static const Duration steadyBelow = Duration(minutes: 45);
  static const Duration wideFrom = Duration(minutes: 90);

  /// 잠든 시각을 밤 기준 분으로 편다. 정오 전(새벽)은 다음 날로 본다 —
  /// 23:00과 01:00의 차이가 22시간이 아니라 2시간이 되도록.
  static int nightMinutes(ClockTime time) =>
      time.hour < 12 ? time.totalMinutes + 24 * 60 : time.totalMinutes;

  /// [entries] 중 수면이 있는 날로 계산한다. 부족하면 null.
  static BedtimeRegularity? of(Iterable<DiaryEntry> entries) {
    final minutes = [
      for (final entry in entries)
        if (entry.sleep case final sleep?) nightMinutes(sleep.bedTime),
    ];
    if (minutes.length < minimumDays) {
      return null;
    }
    final mean = minutes.reduce((a, b) => a + b) / minutes.length;
    final variance =
        minutes.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) /
        minutes.length;
    final stdDev = Duration(minutes: math.sqrt(variance).round());
    final average = mean.round() % (24 * 60);
    return BedtimeRegularity._(
      averageBedtime: ClockTime(average ~/ 60, average % 60),
      spread: stdDev,
      dayCount: minutes.length,
    );
  }

  /// 평균 잠든 시각.
  final ClockTime averageBedtime;

  /// 잠든 시각의 표준편차 — "보통 이 정도 앞뒤로 움직였다".
  final Duration spread;

  final int dayCount;

  BedtimeSpread get level => spread < steadyBelow
      ? BedtimeSpread.steady
      : spread < wideFrom
      ? BedtimeSpread.varied
      : BedtimeSpread.wide;
}
