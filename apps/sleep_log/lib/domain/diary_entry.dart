import 'diary_date.dart';
import 'mood_tag.dart';
import 'sleep_mark.dart';
import 'sleep_session.dart';

/// 하루의 기록.
///
/// **수면과 태그 중 하나만 있어도 기록이다** (docs/screen-flow/sleep_log.md §5).
/// 매일 완전한 입력을 요구하면 빈 날이 생기고 그게 포기로 이어진다.
final class DiaryEntry {
  DiaryEntry({
    required this.date,
    this.sleep,
    Set<MoodTag> tags = const {},
    this.rested,
  }) : tags = Set.unmodifiable(tags);

  final DiaryDate date;
  final SleepSession? sleep;
  final Set<MoodTag> tags;

  /// 일어났을 때 개운했는가 — 수면시간과 따로 묻는다. 7시간을 자도 덜 풀린
  /// 날이 있고, 그 차이가 보여야 한다 (PRD §3-1).
  final RestFeeling? rested;

  /// 저장할 내용이 없다. 입력 화면이 저장을 막는 조건이다.
  bool get isEmpty => sleep == null && tags.isEmpty && rested == null;

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

  DiaryEntry copyWith({
    SleepSession? sleep,
    Set<MoodTag>? tags,
    RestFeeling? rested,
  }) => DiaryEntry(
    date: date,
    sleep: sleep ?? this.sleep,
    tags: tags ?? this.tags,
    rested: rested ?? this.rested,
  );

  /// 수면 기록만 지운다. [copyWith]로는 null을 넣을 수 없어 따로 둔다.
  DiaryEntry withoutSleep() =>
      DiaryEntry(date: date, tags: tags, rested: rested);

  @override
  String toString() =>
      'DiaryEntry($date, sleep: $sleep, tags: ${tags.map((t) => t.id).toList()}, '
      'rested: ${rested?.name})';
}

/// 일어났을 때의 개운함 (3단계). 판정이 아니라 체감이다.
enum RestFeeling {
  rested('개운했어요'),
  soso('그저 그랬어요'),
  unrested('덜 풀렸어요');

  const RestFeeling(this.label);

  final String label;

  static RestFeeling? tryParse(String? name) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}
