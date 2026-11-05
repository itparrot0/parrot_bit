import 'diary_entry.dart';
import 'mood_tag.dart';

/// 입력 화면의 태그 배치 순서 (PRD §3-1).
///
/// **최근에 쓴 태그를 묶음 안에서 앞으로 올린다.** 설정 없이 개인화가 생기고,
/// 매일 같은 몇 개를 고르는 사용자가 팔레트 전체를 훑지 않아도 된다.
/// 묶음(부정/긍정/신체) 사이 순서는 바꾸지 않는다 — 시선 위치가 매일 같아야
/// 찾기 쉽다.
abstract final class TagOrder {
  /// [group]의 태그를 마지막으로 쓴 날짜가 최근인 순으로. 쓴 적 없는 태그는
  /// 그 뒤에 기본 팔레트 순서대로 온다.
  ///
  /// "자주"가 아니라 "최근"으로 세는 이유: 기분이 바뀌는 시기(시험 기간 등)에
  /// 빈도는 몇 주 늦게 따라온다. 최근 사용이 지금의 팔레트에 더 가깝다.
  static List<MoodTag> forGroup(MoodGroup group, Iterable<DiaryEntry> entries) {
    final lastUsed = <MoodTag, DiaryEntry>{};
    for (final entry in entries) {
      for (final tag in entry.tags) {
        final previous = lastUsed[tag];
        if (previous == null || entry.date.isAfter(previous.date)) {
          lastUsed[tag] = entry;
        }
      }
    }

    final defaults = DefaultMoodTags.ofGroup(group);
    final used = defaults.where(lastUsed.containsKey).toList()
      ..sort((a, b) => lastUsed[b]!.date.compareTo(lastUsed[a]!.date));
    final unused = defaults.where((tag) => !lastUsed.containsKey(tag));
    return [...used, ...unused];
  }
}
