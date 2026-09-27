import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/domain/domain.dart';

const _today = DiaryDate(2026, 9, 27);
final _target = SleepTarget(const Duration(hours: 7));

/// 00:00에 자서 [duration]만큼 잔 수면. 테스트에서 시각은 의미가 없다.
SleepSession _slept(Duration duration) => SleepSession(
  bedTime: ClockTime(0, 0),
  wakeTime: ClockTime(duration.inMinutes ~/ 60, duration.inMinutes % 60),
);

DiaryEntry _entry(
  int daysAgo, {
  Duration? slept,
  Set<MoodTag> tags = const {},
}) => DiaryEntry(
  date: _today.addDays(-daysAgo),
  sleep: slept == null ? null : _slept(slept),
  tags: tags,
);

final _negative = {DefaultMoodTags.down};
final _positive = {DefaultMoodTags.calm};
const _shortSleep = Duration(hours: 5);
const _enoughSleep = Duration(hours: 7, minutes: 30);

void main() {
  group('SafetyCheck — 아무것도 띄우지 않는 경우', () {
    test('기록이 없으면 none', () {
      expect(
        SafetyCheck.evaluate(entries: [], target: _target, today: _today),
        SafetyAdvice.none,
      );
    });

    test('부정 태그가 기준일수에 못 미치면 none', () {
      final entries = [
        _entry(0, slept: _shortSleep, tags: _negative),
        _entry(1, slept: _shortSleep, tags: _negative),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.none,
      );
    });

    test('부정 태그가 이어져도 잘 잤다면 1단계는 뜨지 않는다', () {
      final entries = [
        for (var i = 0; i < 3; i++)
          _entry(i, slept: _enoughSleep, tags: _negative),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.none,
      );
    });

    test('긍정 태그는 아무리 많아도 세지 않는다', () {
      final entries = [
        for (var i = 0; i < 14; i++)
          _entry(i, slept: _shortSleep, tags: _positive),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.none,
      );
    });

    test('신체 태그만 이어지는 것은 부정으로 세지 않는다', () {
      // "피곤"이 며칠 이어지는 것은 바빴다는 뜻일 수 있다.
      final entries = [
        for (var i = 0; i < 14; i++)
          _entry(i, slept: _shortSleep, tags: {DefaultMoodTags.tired}),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.none,
      );
    });

    test('창 밖의 오래된 기록은 세지 않는다', () {
      final entries = [
        for (var i = 14; i < 25; i++)
          _entry(i, slept: _enoughSleep, tags: _negative),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.none,
      );
    });
  });

  group('SafetyCheck 1단계 — 수면 권장', () {
    test('부정 태그 3일 + 그중 수면 부족 2일이면 수면을 권한다', () {
      final entries = [
        _entry(0, slept: _enoughSleep, tags: _negative),
        _entry(1, slept: _shortSleep, tags: _negative),
        _entry(2, slept: _shortSleep, tags: _negative),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.restSuggestion,
      );
    });

    test('수면 부족이 1일뿐이면 뜨지 않는다', () {
      final entries = [
        _entry(0, slept: _enoughSleep, tags: _negative),
        _entry(1, slept: _enoughSleep, tags: _negative),
        _entry(2, slept: _shortSleep, tags: _negative),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.none,
      );
    });

    test('zZ(적당)도 부족한 쪽으로 센다', () {
      final entries = [
        for (var i = 0; i < 3; i++)
          _entry(i, slept: const Duration(hours: 6), tags: _negative),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.restSuggestion,
      );
    });

    test('5일 창을 벗어난 부정 태그는 1단계에 넣지 않는다', () {
      final entries = [
        _entry(0, slept: _shortSleep, tags: _negative),
        _entry(1, slept: _shortSleep, tags: _negative),
        _entry(5, slept: _shortSleep, tags: _negative),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.none,
      );
    });
  });

  group('SafetyCheck 2단계 — 상담 안내', () {
    test('부정 태그 7일인데 그 날들의 수면이 대체로 충분하면 상담을 안내한다', () {
      // 충분히 잤는데도 계속 힘들다 = 이 앱의 설명력 밖이다.
      final entries = [
        for (var i = 0; i < 7; i++)
          _entry(i, slept: _enoughSleep, tags: _negative),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.supportContact,
      );
    });

    test('부정 태그가 6일이면 아직 뜨지 않는다', () {
      final entries = [
        for (var i = 0; i < 6; i++)
          _entry(i, slept: _enoughSleep, tags: _negative),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        isNot(SafetyAdvice.supportContact),
      );
    });

    test('수면이 과반 부족이면 2단계가 아니다', () {
      final entries = [
        for (var i = 0; i < 4; i++)
          _entry(i, slept: _shortSleep, tags: _negative),
        for (var i = 4; i < 7; i++)
          _entry(i, slept: _enoughSleep, tags: _negative),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.restSuggestion,
      );
    });

    test('수면 기록이 없으면 "충분히 잤는데도"를 말할 근거가 없어 뜨지 않는다', () {
      final entries = [for (var i = 0; i < 10; i++) _entry(i, tags: _negative)];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.none,
      );
    });

    test('과다 수면(zzZZ)도 목표를 채운 쪽으로 센다', () {
      final entries = [
        for (var i = 0; i < 7; i++)
          _entry(i, slept: const Duration(hours: 11), tags: _negative),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.supportContact,
      );
    });

    test('두 단계 조건이 동시에 성립하면 2단계가 이긴다', () {
      final entries = [
        _entry(0, slept: _shortSleep, tags: _negative),
        _entry(1, slept: _shortSleep, tags: _negative),
        _entry(2, slept: _enoughSleep, tags: _negative),
        for (var i = 3; i < 8; i++)
          _entry(i, slept: _enoughSleep, tags: _negative),
      ];

      expect(
        SafetyCheck.evaluate(entries: entries, target: _target, today: _today),
        SafetyAdvice.supportContact,
      );
    });
  });

  group('TagSleepReport', () {
    test('수면이 기록된 날이 14일 미만이면 리포트를 보여주지 않는다', () {
      final thirteen = [
        for (var i = 0; i < 13; i++) _entry(i, slept: _enoughSleep),
      ];

      expect(TagSleepReport.hasEnoughData(thirteen), isFalse);
      expect(
        TagSleepReport.hasEnoughData([
          ...thirteen,
          _entry(13, slept: _enoughSleep),
        ]),
        isTrue,
      );
    });

    test('수면 없는 날은 표본에 세지 않는다', () {
      final entries = [
        for (var i = 0; i < 13; i++) _entry(i, slept: _enoughSleep),
        for (var i = 13; i < 20; i++) _entry(i, tags: _negative),
      ];

      expect(TagSleepReport.hasEnoughData(entries), isFalse);
    });

    test('태그별 평균 수면시간을 낸다', () {
      final stats = TagSleepReport.build([
        _entry(
          0,
          slept: const Duration(hours: 5),
          tags: {DefaultMoodTags.irritated},
        ),
        _entry(
          1,
          slept: const Duration(hours: 5),
          tags: {DefaultMoodTags.irritated},
        ),
        _entry(
          2,
          slept: const Duration(hours: 5, minutes: 36),
          tags: {DefaultMoodTags.irritated},
        ),
        _entry(
          3,
          slept: const Duration(hours: 7),
          tags: {DefaultMoodTags.calm},
        ),
        _entry(
          4,
          slept: const Duration(hours: 7, minutes: 12),
          tags: {DefaultMoodTags.calm},
        ),
      ]);

      expect(stats, hasLength(2));
      // 짜증 5.2시간 / 평온 7.1시간 — PRD §3의 리포트 예시 그대로.
      expect(stats.first.tag, DefaultMoodTags.irritated);
      expect(stats.first.dayCount, 3);
      expect(stats.first.averageSleep, const Duration(minutes: 312));
      expect(stats.last.tag, DefaultMoodTags.calm);
      expect(stats.last.dayCount, 2);
      expect(stats.last.averageSleep, const Duration(minutes: 426));
    });

    test('평균이 짧은 태그부터 정렬한다', () {
      final stats = TagSleepReport.build([
        _entry(
          0,
          slept: const Duration(hours: 8),
          tags: {DefaultMoodTags.calm},
        ),
        _entry(
          1,
          slept: const Duration(hours: 4),
          tags: {DefaultMoodTags.anxious},
        ),
        _entry(
          2,
          slept: const Duration(hours: 6),
          tags: {DefaultMoodTags.tired},
        ),
      ]);

      expect(stats.map((stat) => stat.tag).toList(), [
        DefaultMoodTags.anxious,
        DefaultMoodTags.tired,
        DefaultMoodTags.calm,
      ]);
    });

    test('한 날의 태그 여러 개가 모두 그 날 수면시간을 받는다', () {
      final stats = TagSleepReport.build([
        _entry(
          0,
          slept: const Duration(hours: 6),
          tags: {DefaultMoodTags.anxious, DefaultMoodTags.tired},
        ),
      ]);

      expect(stats, hasLength(2));
      expect(
        stats.every((stat) => stat.averageSleep == const Duration(hours: 6)),
        isTrue,
      );
    });

    test('평균이 같으면 표본이 많은 태그를 앞에 둔다', () {
      final stats = TagSleepReport.build([
        _entry(
          0,
          slept: const Duration(hours: 6),
          tags: {DefaultMoodTags.anxious},
        ),
        _entry(
          1,
          slept: const Duration(hours: 6),
          tags: {DefaultMoodTags.anxious, DefaultMoodTags.down},
        ),
      ]);

      expect(stats.first.tag, DefaultMoodTags.anxious);
      expect(stats.first.dayCount, 2);
    });

    test('기록이 없으면 빈 목록이다', () {
      expect(TagSleepReport.build([]), isEmpty);
      expect(TagSleepReport.build([_entry(0, tags: _negative)]), isEmpty);
    });
  });
}
