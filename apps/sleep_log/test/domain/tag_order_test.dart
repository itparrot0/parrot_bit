import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/domain/domain.dart';

void main() {
  test('기록이 없으면 기본 팔레트 순서', () {
    expect(
      TagOrder.forGroup(MoodGroup.positive, const []),
      DefaultMoodTags.ofGroup(MoodGroup.positive),
    );
  });

  test('최근에 쓴 태그가 앞에, 쓴 적 없는 태그는 기본 순서로 뒤에', () {
    final entries = [
      DiaryEntry(
        date: const DiaryDate(2026, 11, 1),
        tags: {DefaultMoodTags.grateful},
      ),
      DiaryEntry(
        date: const DiaryDate(2026, 11, 3),
        tags: {DefaultMoodTags.proud},
      ),
    ];

    expect(TagOrder.forGroup(MoodGroup.positive, entries), [
      DefaultMoodTags.proud,
      DefaultMoodTags.grateful,
      DefaultMoodTags.calm,
      DefaultMoodTags.joyful,
      DefaultMoodTags.excited,
    ]);
  });

  test('같은 태그를 여러 날 썼으면 가장 최근 날짜로 센다 — 목록 순서와 무관', () {
    final entries = [
      DiaryEntry(
        date: const DiaryDate(2026, 11, 4),
        tags: {DefaultMoodTags.calm},
      ),
      DiaryEntry(
        date: const DiaryDate(2026, 11, 2),
        tags: {DefaultMoodTags.calm, DefaultMoodTags.joyful},
      ),
      DiaryEntry(
        date: const DiaryDate(2026, 11, 3),
        tags: {DefaultMoodTags.joyful},
      ),
    ];

    expect(TagOrder.forGroup(MoodGroup.positive, entries).take(2), [
      DefaultMoodTags.calm,
      DefaultMoodTags.joyful,
    ]);
  });

  test('다른 묶음의 태그는 섞이지 않는다', () {
    final entries = [
      DiaryEntry(
        date: const DiaryDate(2026, 11, 4),
        tags: {DefaultMoodTags.tired, DefaultMoodTags.down},
      ),
    ];

    final physical = TagOrder.forGroup(MoodGroup.physical, entries);
    expect(physical.first, DefaultMoodTags.tired);
    expect(physical.every((tag) => tag.group == MoodGroup.physical), isTrue);
    expect(
      physical,
      hasLength(DefaultMoodTags.ofGroup(MoodGroup.physical).length),
    );
  });
}
