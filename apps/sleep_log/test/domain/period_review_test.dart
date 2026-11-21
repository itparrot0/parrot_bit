import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/domain/domain.dart';

void main() {
  const end = DiaryDate(2026, 11, 14);
  final range = DateRange.lastDays(end, 14); // 11/1 ~ 11/14
  final target = SleepTarget(const Duration(hours: 7));

  /// [day]일(11월), [hours]시간 수면. 취침은 [bedHour]시.
  DiaryEntry entry(
    int day, {
    double? hours,
    int bedHour = 23,
    Set<MoodTag> tags = const {},
  }) {
    SleepSession? sleep;
    if (hours != null) {
      final bed = bedHour * 60;
      final wake = (bed + (hours * 60).round()) % (24 * 60);
      sleep = SleepSession(
        bedTime: ClockTime(bedHour, 0),
        wakeTime: ClockTime(wake ~/ 60, wake % 60),
      );
    }
    return DiaryEntry(date: DiaryDate(2026, 11, day), sleep: sleep, tags: tags);
  }

  ThoughtCheckIn checkIn(
    int day, {
    MindPace? pace,
    SenseShift? senses,
    String? thought,
    String? reframe,
    CheckInSlot slot = CheckInSlot.morning,
  }) => ThoughtCheckIn(
    date: DiaryDate(2026, 11, day),
    slot: slot,
    pace: pace,
    senses: senses,
    thought: thought,
    reframe: reframe,
  );

  PeriodReview review(
    List<DiaryEntry> entries, [
    List<ThoughtCheckIn> checkIns = const [],
  ]) => PeriodReview.of(
    range: range,
    entries: entries,
    checkIns: checkIns,
    target: target,
  );

  List<(PatternKind, DiaryDate, DiaryDate)> runsOf(PeriodReview r) => [
    for (final run in r.runs) (run.kind, run.range.from, run.range.to),
  ];

  group('DateRange', () {
    test('끝 날을 포함해 센다', () {
      expect(range.from, const DiaryDate(2026, 11, 1));
      expect(range.dayCount, 14);
      expect(range.days.length, 14);
    });

    test('시작이 끝보다 늦으면 만들 수 없다', () {
      expect(
        () => DateRange(
          const DiaryDate(2026, 11, 2),
          const DiaryDate(2026, 11, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('이어진 흐름', () {
    test('3일 이상 이어지면 구간을 알려 주고, 2일은 흐름이 아니다', () {
      final r = review([
        entry(2, hours: 5),
        entry(3, hours: 5),
        entry(4, hours: 5),
        entry(8, hours: 5),
        entry(9, hours: 5),
      ]);

      expect(runsOf(r), [
        (
          PatternKind.shortSleep,
          const DiaryDate(2026, 11, 2),
          const DiaryDate(2026, 11, 4),
        ),
      ]);
    });

    test('기록이 없는 날은 흐름을 끊는다', () {
      final r = review([
        entry(2, hours: 5),
        entry(3, hours: 5),
        entry(5, hours: 5),
        entry(6, hours: 5),
      ]);

      expect(r.runs, isEmpty);
    });

    test('잠이 짧고 마음도 힘든 날이 겹치면 겹침을 따로 알려 준다', () {
      final r = review([
        for (var d = 1; d <= 4; d++)
          entry(d, hours: 5, tags: {DefaultMoodTags.down}),
      ]);

      expect(
        r.runs.map((run) => run.kind),
        containsAll([
          PatternKind.shortSleepWithLowMood,
          PatternKind.shortSleep,
          PatternKind.lowMood,
        ]),
      );
      expect(
        r.runs.first.kind,
        PatternKind.shortSleepWithLowMood,
        reason: '같은 구간이면 겹침이 먼저 보인다',
      );
    });

    test('좋은 흐름도 알려 준다', () {
      final r = review([
        for (var d = 10; d <= 13; d++)
          entry(d, hours: 7.5, tags: {DefaultMoodTags.calm}),
      ]);

      expect(r.runs.map((run) => run.kind).toSet(), {
        PatternKind.enoughSleep,
        PatternKind.goodMood,
      });
      expect(r.runs.every((run) => run.kind.tone == Tone.light), isTrue);
    });

    test('새벽 1시 넘어 잠든 날 — 23시 취침은 세지 않는다', () {
      final r = review([
        entry(1, hours: 6, bedHour: 2),
        entry(2, hours: 6, bedHour: 1),
        entry(3, hours: 6, bedHour: 3),
        entry(4, hours: 6, bedHour: 23),
      ]);

      expect(
        r.runs.where((run) => run.kind == PatternKind.lateBedtime).single.range,
        DateRange(const DiaryDate(2026, 11, 1), const DiaryDate(2026, 11, 3)),
      );
    });

    test('생각 돌아보기의 머릿속 속도·감각도 흐름으로 본다', () {
      final r = review(const [], [
        for (var d = 5; d <= 7; d++) checkIn(d, pace: MindPace.busy),
        checkIn(10, senses: SenseShift.some),
        checkIn(11, senses: SenseShift.often, slot: CheckInSlot.afternoon),
        checkIn(12, senses: SenseShift.some),
      ]);

      expect(r.runs.map((run) => run.kind).toSet(), {
        PatternKind.busyMind,
        PatternKind.senseShift,
      });
    });

    test('구간 밖의 기록은 보지 않는다', () {
      final r = PeriodReview.of(
        range: DateRange.lastDays(end, 3),
        entries: [
          for (var d = 1; d <= 11; d++) entry(d, hours: 5),
          entry(12, hours: 7.5),
        ],
        checkIns: const [],
        target: target,
      );

      expect(r.runs, isEmpty);
      expect(r.recordedDays, 1);
    });

    test('최근 구간이 먼저 온다', () {
      final r = review([
        for (var d = 1; d <= 3; d++) entry(d, hours: 5),
        for (var d = 10; d <= 12; d++) entry(d, hours: 7.5),
      ]);

      expect(r.runs.first.kind, PatternKind.enoughSleep);
      expect(r.runs.last.kind, PatternKind.shortSleep);
    });
  });

  group('습관 흐름', () {
    test('잠은 충분했는데 덜 풀린 날이 이어지면 알려 준다', () {
      final r = review([
        for (var d = 1; d <= 3; d++)
          DiaryEntry(
            date: DiaryDate(2026, 11, d),
            sleep: SleepSession(
              bedTime: ClockTime(23, 0),
              wakeTime: ClockTime(7, 0),
            ),
            rested: RestFeeling.unrested,
          ),
      ]);

      expect(
        r.runs.map((run) => run.kind),
        contains(PatternKind.restedMismatch),
      );
    });

    test('잠든 시각이 전날보다 90분 넘게 달라진 날이 3일 이어지면 알려 준다', () {
      // 23시 → 1시(+120) → 22시30분(-150) → 1시(+150)
      final r = review([
        entry(1, hours: 7, bedHour: 23),
        entry(2, hours: 7, bedHour: 1),
        entry(3, hours: 7, bedHour: 22),
        entry(4, hours: 7, bedHour: 1),
      ]);

      final swing = r.runs.where((run) => run.kind == PatternKind.bedtimeSwing);
      expect(swing.single.range.from, const DiaryDate(2026, 11, 2));
      expect(swing.single.range.to, const DiaryDate(2026, 11, 4));
    });

    test('기간의 잠든 시각 규칙성을 낸다', () {
      final r = review([for (var d = 1; d <= 5; d++) entry(d, hours: 7)]);
      expect(r.bedtime!.averageBedtime, ClockTime(23, 0));
      expect(r.bedtime!.level, BedtimeSpread.steady);
    });
  });

  group('묶음', () {
    test('겹침이 덮는 개별 흐름은 빼고, 같은 구간은 한 묶음으로', () {
      final r = review(
        [
          for (var d = 2; d <= 4; d++)
            entry(d, hours: 5, bedHour: 1, tags: {DefaultMoodTags.down}),
          for (var d = 8; d <= 11; d++)
            entry(d, hours: 7.5, tags: {DefaultMoodTags.calm}),
        ],
        [for (var d = 2; d <= 4; d++) checkIn(d, pace: MindPace.busy)],
      );

      // 리스트가 든 레코드는 == 로 비교되지 않아 칸별로 본다.
      expect(r.groups.map((g) => (g.range.from.day, g.range.to.day)), [
        (8, 11),
        (2, 4),
      ]);
      expect(r.groups[0].kinds, [
        PatternKind.enoughSleep,
        PatternKind.goodMood,
      ]);
      expect(r.groups[1].kinds, [
        PatternKind.shortSleepWithLowMood,
        PatternKind.shortSleepWithBusyMind,
        PatternKind.lateBedtime,
      ]);
    });

    test('겹침보다 길게 이어진 개별 흐름은 따로 남는다', () {
      final r = review([
        for (var d = 1; d <= 5; d++)
          entry(d, hours: 5, tags: d >= 3 ? {DefaultMoodTags.down} : const {}),
      ]);

      expect(r.groups.map((g) => g.range.dayCount), [5, 3]);
      expect(r.groups[0].kinds, [PatternKind.shortSleep]);
      expect(r.groups[1].kinds, [PatternKind.shortSleepWithLowMood]);
    });
  });

  group('요약과 생각', () {
    test('기록한 날, 평균 수면, 체크인 수', () {
      final r = review(
        [
          entry(1, hours: 6),
          entry(2, hours: 8),
          entry(3, tags: {DefaultMoodTags.calm}),
        ],
        [
          checkIn(1, pace: MindPace.usual),
          checkIn(1, pace: MindPace.busy, slot: CheckInSlot.afternoon),
        ],
      );

      expect(r.recordedDays, 3);
      expect(r.averageSleep, const Duration(hours: 7));
      expect(r.checkInCount, 2);
      expect(r.isEmpty, isFalse);
    });

    test('생각을 적은 체크인만 모은다 — 건넨 말은 없을 수도 있다', () {
      final r = review(const [], [
        checkIn(1, thought: '다 망할 것 같다', reframe: '지난번에도 해냈어'),
        checkIn(2, thought: '아무도 신경 안 쓴다'),
        checkIn(3, pace: MindPace.slow),
      ]);

      expect(r.thoughts, [
        (
          date: const DiaryDate(2026, 11, 1),
          thought: '다 망할 것 같다',
          reframe: '지난번에도 해냈어',
        ),
        (
          date: const DiaryDate(2026, 11, 2),
          thought: '아무도 신경 안 쓴다',
          reframe: null,
        ),
      ]);
    });

    test('아무 기록도 없으면 비어 있다', () {
      final r = review(const []);
      expect(r.isEmpty, isTrue);
      expect(r.averageSleep, isNull);
    });
  });
}
