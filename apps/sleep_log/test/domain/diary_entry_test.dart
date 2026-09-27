import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/domain/domain.dart';

void main() {
  group('DefaultMoodTags 팔레트', () {
    test('15개이고 묶음마다 5개다', () {
      expect(DefaultMoodTags.all, hasLength(15));
      expect(DefaultMoodTags.ofGroup(MoodGroup.negative), hasLength(5));
      expect(DefaultMoodTags.ofGroup(MoodGroup.positive), hasLength(5));
      expect(DefaultMoodTags.ofGroup(MoodGroup.physical), hasLength(5));
    });

    test('12~16개 범위를 지킨다', () {
      // 길어지면 매일 훑는 비용이 누적돼 기록을 포기하게 된다 (PRD §3-1).
      expect(DefaultMoodTags.all.length, inInclusiveRange(12, 16));
    });

    test('id가 중복되지 않는다', () {
      final ids = DefaultMoodTags.all.map((tag) => tag.id).toSet();

      expect(ids, hasLength(DefaultMoodTags.all.length));
    });

    test('id로 찾을 수 있고 없는 id는 null이다', () {
      expect(DefaultMoodTags.byId('anxious'), DefaultMoodTags.anxious);
      expect(DefaultMoodTags.byId('없는태그'), isNull);
    });

    test('태그 동일성은 id로만 판단한다', () {
      // 표시 문구를 고쳐도 기존 기록이 고아가 되지 않아야 한다.
      const renamed = MoodTag(
        id: 'anxious',
        label: '불안함',
        group: MoodGroup.negative,
      );

      expect(renamed, DefaultMoodTags.anxious);
      expect({DefaultMoodTags.anxious}.contains(renamed), isTrue);
    });
  });

  group('DiaryEntry', () {
    final date = const DiaryDate(2026, 9, 27);
    final target = SleepTarget(const Duration(hours: 7));

    test('수면만 기록해도 기록이다', () {
      final entry = DiaryEntry(
        date: date,
        sleep: SleepSession(
          bedTime: ClockTime(23, 0),
          wakeTime: ClockTime(7, 0),
        ),
      );

      expect(entry.isEmpty, isFalse);
      expect(entry.sleepDuration, const Duration(hours: 8));
    });

    test('태그만 기록해도 기록이다', () {
      final entry = DiaryEntry(date: date, tags: {DefaultMoodTags.calm});

      expect(entry.isEmpty, isFalse);
      expect(entry.sleepDuration, isNull);
    });

    test('둘 다 없으면 저장할 내용이 없다', () {
      expect(DiaryEntry(date: date).isEmpty, isTrue);
    });

    test('수면 기록이 없으면 z 표시가 없다', () {
      // 달력은 이걸 빈칸으로 그려 수면 부족과 구분해야 한다 (PRD §4).
      final entry = DiaryEntry(date: date, tags: {DefaultMoodTags.tired});

      expect(entry.markWith(target), isNull);
    });

    test('수면 기록이 있으면 목표 대비 단계를 낸다', () {
      final entry = DiaryEntry(
        date: date,
        sleep: SleepSession(
          bedTime: ClockTime(1, 0),
          wakeTime: ClockTime(5, 0),
        ),
      );

      expect(entry.markWith(target), SleepMark.short);
    });

    test('감정적 부정만 부정으로 센다', () {
      DiaryEntry withTags(Set<MoodTag> tags) =>
          DiaryEntry(date: date, tags: tags);

      expect(withTags({DefaultMoodTags.down}).hasNegativeMood, isTrue);
      // 피곤은 바빴다는 뜻일 수도 있어 안전 판정에서 부정으로 세지 않는다.
      expect(withTags({DefaultMoodTags.tired}).hasNegativeMood, isFalse);
      expect(withTags({DefaultMoodTags.headache}).hasNegativeMood, isFalse);
      expect(withTags({DefaultMoodTags.calm}).hasNegativeMood, isFalse);
      expect(
        withTags({
          DefaultMoodTags.tired,
          DefaultMoodTags.anxious,
        }).hasNegativeMood,
        isTrue,
      );
    });

    test('태그 집합은 밖에서 바꿀 수 없다', () {
      final tags = {DefaultMoodTags.calm};
      final entry = DiaryEntry(date: date, tags: tags);
      tags.add(DefaultMoodTags.joyful);

      expect(entry.tags, hasLength(1));
      expect(
        () => entry.tags.add(DefaultMoodTags.joyful),
        throwsUnsupportedError,
      );
    });

    test('copyWith는 날짜를 유지하고 withoutSleep은 수면만 지운다', () {
      final entry = DiaryEntry(
        date: date,
        sleep: SleepSession(
          bedTime: ClockTime(23, 0),
          wakeTime: ClockTime(7, 0),
        ),
        tags: {DefaultMoodTags.calm},
      );

      final retagged = entry.copyWith(tags: {DefaultMoodTags.anxious});
      expect(retagged.date, date);
      expect(retagged.sleep, entry.sleep);
      expect(retagged.tags, {DefaultMoodTags.anxious});

      final cleared = entry.withoutSleep();
      expect(cleared.sleep, isNull);
      expect(cleared.tags, {DefaultMoodTags.calm});
    });
  });
}
