import 'package:sleep_log/domain/domain.dart';

/// [today]부터 거슬러 올라간 [days]일, 부정 태그 + [hours]시간 수면 기록.
/// 00:00에 자서 [hours]만큼 잔 것으로 만든다.
List<DiaryEntry> negativeDays(
  DiaryDate today, {
  required int days,
  required double hours,
}) {
  final minutes = (hours * 60).round();
  return [
    for (var i = 0; i < days; i++)
      DiaryEntry(
        date: today.addDays(-i),
        sleep: SleepSession(
          bedTime: ClockTime(0, 0),
          wakeTime: ClockTime(minutes ~/ 60, minutes % 60),
        ),
        tags: {DefaultMoodTags.down},
      ),
  ];
}
