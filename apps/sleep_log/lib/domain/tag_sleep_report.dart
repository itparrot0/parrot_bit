import 'diary_entry.dart';
import 'mood_tag.dart';

/// 태그 하나의 수면 대조 결과.
typedef TagSleepStat = ({MoodTag tag, int dayCount, Duration averageSleep});

/// 태그별 평균 수면시간 집계 — "짜증을 붙인 날 평균 5.2시간 / 평온한 날 7.1시간".
///
/// **대조만 한다.** 인과를 말하지 않고 해석은 사용자에게 맡긴다 (PRD §9-2).
abstract final class TagSleepReport {
  /// 리포트를 보여주기 위한 최소 기록 일수.
  ///
  /// 표본이 적을 때 나오는 상관은 틀리고, **틀린 인상을 한 번 주면 신뢰를
  /// 잃는다** (docs/screen-flow/sleep_log.md §5).
  static const int minimumDays = 14;

  /// 수면이 기록된 날이 [minimumDays] 이상인가.
  static bool hasEnoughData(Iterable<DiaryEntry> entries) =>
      sleepDayCount(entries) >= minimumDays;

  /// 수면이 기록된 날의 수.
  static int sleepDayCount(Iterable<DiaryEntry> entries) =>
      entries.where((entry) => entry.sleepDuration != null).length;

  /// 수면이 기록된 모든 날의 평균. 태그별 평균을 읽을 기준선이다 — "짜증 5.2시간"
  /// 만으로는 그게 평소보다 짧은지 알 수 없다. 수면 기록이 없으면 null.
  static Duration? overallAverage(Iterable<DiaryEntry> entries) {
    final durations = entries.map((entry) => entry.sleepDuration).nonNulls;
    if (durations.isEmpty) {
      return null;
    }
    final total = durations.fold(0, (sum, d) => sum + d.inMinutes);
    return Duration(minutes: total ~/ durations.length);
  }

  /// 태그별 평균 수면시간. **수면이 기록된 날만** 센다.
  ///
  /// 평균이 짧은 태그부터 정렬한다 — 수면 부족과 함께 오는 감정이 먼저 보여야
  /// 사용자가 찾는 패턴에 닿는다.
  static List<TagSleepStat> build(Iterable<DiaryEntry> entries) {
    final totals = <MoodTag, ({int days, int minutes})>{};

    for (final entry in entries) {
      final duration = entry.sleepDuration;
      if (duration == null) {
        continue;
      }
      for (final tag in entry.tags) {
        final previous = totals[tag] ?? (days: 0, minutes: 0);
        totals[tag] = (
          days: previous.days + 1,
          minutes: previous.minutes + duration.inMinutes,
        );
      }
    }

    final stats = <TagSleepStat>[];
    totals.forEach((tag, total) {
      stats.add((
        tag: tag,
        dayCount: total.days,
        averageSleep: Duration(minutes: total.minutes ~/ total.days),
      ));
    });

    stats.sort((a, b) {
      final byAverage = a.averageSleep.compareTo(b.averageSleep);
      // 평균이 같으면 표본이 많은 쪽을 앞에 둔다.
      return byAverage != 0 ? byAverage : b.dayCount.compareTo(a.dayCount);
    });
    return stats;
  }
}
