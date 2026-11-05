import 'diary_date.dart';
import 'diary_entry.dart';
import 'thought_check_in.dart';

/// 머릿속 속도 하나의 수면 대조 결과.
typedef PaceSleepStat = ({MindPace pace, int dayCount, Duration averageSleep});

/// "머릿속이 바쁘게 돌아갔다고 한 날, 그날 아침까지의 수면 평균" 대조
/// (PRD §3-3). 수면이 줄고 생각이 빨라지는 흐름을 사용자가 스스로 발견하게 한다.
///
/// **대조만 한다** — `TagSleepReport`와 같은 원칙이다.
abstract final class PaceSleepReport {
  /// 이만큼 쌓이기 전에는 보여 주지 않는다. 표본이 적을 때의 대조는 틀린
  /// 인상을 준다.
  static const int minimumDays = 7;

  /// 속도별 평균 수면. 체크인 날짜의 수면 기록(그날 아침 기상)과 짝짓는다.
  /// 하루에 오전·오후가 서로 다르면 그날은 두 속도에 다 들어간다.
  /// 수면 기록이 없는 날은 세지 않는다. [MindPace] 순서대로.
  static List<PaceSleepStat> build(
    Iterable<DiaryEntry> entries,
    Iterable<ThoughtCheckIn> checkIns,
  ) {
    final sleepByDate = <DiaryDate, Duration>{
      for (final entry in entries)
        if (entry.sleepDuration != null) entry.date: entry.sleepDuration!,
    };
    final datesByPace = <MindPace, Set<DiaryDate>>{};
    for (final checkIn in checkIns) {
      final pace = checkIn.pace;
      if (pace != null && sleepByDate.containsKey(checkIn.date)) {
        datesByPace.putIfAbsent(pace, () => {}).add(checkIn.date);
      }
    }
    return [
      for (final pace in MindPace.values)
        if (datesByPace[pace] case final dates?)
          (
            pace: pace,
            dayCount: dates.length,
            averageSleep: Duration(
              minutes:
                  dates.fold(0, (sum, d) => sum + sleepByDate[d]!.inMinutes) ~/
                  dates.length,
            ),
          ),
    ];
  }

  /// 속도를 답하고 수면도 있는 날이 [minimumDays] 이상인가.
  static bool hasEnoughData(List<PaceSleepStat> stats) {
    // 같은 날이 두 속도에 들어갈 수 있어 합계는 약간 넉넉하다 — 기준 판단에는 충분하다.
    final total = stats.fold(0, (sum, s) => sum + s.dayCount);
    return total >= minimumDays;
  }
}
