import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/domain/domain.dart';

void main() {
  DiaryEntry night(
    int day,
    int bedHour,
    int bedMinute, {
    double hours = 7,
    RestFeeling? rested,
  }) {
    final bed = bedHour * 60 + bedMinute;
    final wake = (bed + (hours * 60).round()) % (24 * 60);
    return DiaryEntry(
      date: DiaryDate(2026, 11, day),
      sleep: SleepSession(
        bedTime: ClockTime(bedHour, bedMinute),
        wakeTime: ClockTime(wake ~/ 60, wake % 60),
      ),
      rested: rested,
    );
  }

  group('BedtimeRegularity', () {
    test('5일 미만이면 계산하지 않는다', () {
      expect(
        BedtimeRegularity.of([for (var d = 1; d <= 4; d++) night(d, 23, 0)]),
        isNull,
      );
    });

    test('자정을 넘나들어도 시각 차이로 계산한다 — 23시와 1시의 평균은 0시', () {
      final r = BedtimeRegularity.of([
        night(1, 23, 0),
        night(2, 1, 0),
        night(3, 23, 0),
        night(4, 1, 0),
        night(5, 0, 0),
        night(6, 0, 0),
      ])!;

      expect(r.averageBedtime, ClockTime(0, 0));
      expect(r.spread.inMinutes, inInclusiveRange(48, 50)); // √(4×3600/6)≈49
      expect(r.level, BedtimeSpread.varied);
    });

    test('매일 비슷하면 고른 편, 크게 다르면 크게 오르내림', () {
      expect(
        BedtimeRegularity.of([
          for (var d = 1; d <= 7; d++) night(d, 23, d.isEven ? 10 : 40),
        ])!.level,
        BedtimeSpread.steady,
      );
      expect(
        BedtimeRegularity.of([
          for (var d = 1; d <= 6; d++) night(d, d.isEven ? 22 : 3, 0),
        ])!.level,
        BedtimeSpread.wide,
      );
    });
  });

  group('RestSleepReport', () {
    test('개운함별 평균 수면 — 수면이나 개운함이 없는 날은 세지 않는다', () {
      final stats = RestSleepReport.build([
        night(1, 23, 0, hours: 8, rested: RestFeeling.rested),
        night(2, 23, 0, hours: 7, rested: RestFeeling.rested),
        night(3, 1, 0, hours: 5, rested: RestFeeling.unrested),
        night(4, 23, 0, hours: 7),
        DiaryEntry(
          date: const DiaryDate(2026, 11, 5),
          rested: RestFeeling.soso,
        ),
      ]);

      expect(
        stats.map((s) => (s.feeling, s.dayCount, s.averageSleep.inMinutes)),
        [(RestFeeling.rested, 2, 450), (RestFeeling.unrested, 1, 300)],
      );
      expect(RestSleepReport.hasEnoughData(stats), isFalse);
    });
  });
}
