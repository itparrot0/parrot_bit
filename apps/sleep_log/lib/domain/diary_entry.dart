import 'diary_date.dart';
import 'mood_tag.dart';
import 'sleep_mark.dart';
import 'sleep_session.dart';

/// 하루의 기록.
///
/// **수면과 태그 중 하나만 있어도 기록이다** (docs/screen-flow/sleep_log.md §5).
/// 매일 완전한 입력을 요구하면 빈 날이 생기고 그게 포기로 이어진다.
final class DiaryEntry {
  DiaryEntry({required this.date, this.sleep, Set<MoodTag> tags = const {}})
    : tags = Set.unmodifiable(tags);

  final DiaryDate date;
  final SleepSession? sleep;
  final Set<MoodTag> tags;

  /// 저장할 내용이 없다. 입력 화면이 저장을 막는 조건이다.
  bool get isEmpty => sleep == null && tags.isEmpty;

  Duration? get sleepDuration => sleep?.duration;

  /// 이 날의 z 표시. 수면 기록이 없으면 null — 달력은 이걸 **빈칸**으로 그려
  /// 수면 부족(`z`)과 구분해야 한다 (PRD §4).
  SleepMark? markWith(SleepTarget target) {
    final duration = sleepDuration;
    return duration == null ? null : target.markFor(duration);
  }

  /// 감정적 부정 태그가 하나라도 있는가. 신체 태그는 세지 않는다
  /// ([MoodGroup.physical] 주석 참고).
  bool get hasNegativeMood =>
      tags.any((tag) => tag.group == MoodGroup.negative);

  DiaryEntry copyWith({SleepSession? sleep, Set<MoodTag>? tags}) => DiaryEntry(
    date: date,
    sleep: sleep ?? this.sleep,
    tags: tags ?? this.tags,
  );

  /// 수면 기록만 지운다. [copyWith]로는 null을 넣을 수 없어 따로 둔다.
  DiaryEntry withoutSleep() => DiaryEntry(date: date, tags: tags);

  @override
  String toString() =>
      'DiaryEntry($date, sleep: $sleep, tags: ${tags.map((t) => t.id).toList()})';
}
