import 'diary_date.dart';
import 'diary_entry.dart';
import 'sleep_mark.dart';

/// 안전 안내 단계 (docs/prd/sleep_log.md §9-2).
enum SafetyAdvice {
  /// 아무것도 띄우지 않는다.
  none,

  /// 1단계 — 부정 태그가 이어지고 수면도 부족하다. 앱 영역 안의 조언이고
  /// 사용자가 바로 할 수 있는 일이 있다.
  restSuggestion,

  /// 2단계 — 충분히 잤는데도 부정이 이어진다. **이 앱의 설명력 밖**이라는
  /// 뜻이고, 그때 상담 연락처를 내미는 것은 참견이 아니라 정직이다.
  supportContact,
}

/// 안전 안내가 필요한 상태인지 판정한다.
///
/// 판정만 한다 — **언제 띄우고 얼마나 참을지는 여기서 정하지 않는다.**
/// "한 번 띄우면 14일 재노출 금지", "설정에서 끔"은 마지막 노출 시각을 아는
/// 컨트롤러의 몫이다 (PRD §9-2).
///
/// 전제: 한 날짜에 기록은 하나뿐이다 (Repository가 보장).
abstract final class SafetyCheck {
  /// 1단계 조건 (초기값 — PRD §9-2).
  static const int stage1WindowDays = 5;
  static const int stage1NegativeDays = 3;
  static const int stage1ShortSleepDays = 2;

  /// 2단계 조건 (초기값 — PRD §9-2).
  static const int stage2WindowDays = 14;
  static const int stage2NegativeDays = 7;

  static SafetyAdvice evaluate({
    required Iterable<DiaryEntry> entries,
    required SleepTarget target,
    required DiaryDate today,
  }) {
    // 2단계가 성립하면 1단계는 띄우지 않는다 (PRD §9-2).
    if (_needsSupportContact(entries, target, today)) {
      return SafetyAdvice.supportContact;
    }
    if (_needsRestSuggestion(entries, target, today)) {
      return SafetyAdvice.restSuggestion;
    }
    return SafetyAdvice.none;
  }

  /// 부정 태그가 이어지고 **그 날들의 수면도 부족**했다 → 수면을 권한다.
  static bool _needsRestSuggestion(
    Iterable<DiaryEntry> entries,
    SleepTarget target,
    DiaryDate today,
  ) {
    final negativeDays = _negativeDaysWithin(entries, today, stage1WindowDays);
    if (negativeDays.length < stage1NegativeDays) {
      return false;
    }
    final shortSleepDays = negativeDays.where((entry) {
      final mark = entry.markWith(target);
      return mark != null && mark.isShortOfTarget;
    }).length;
    return shortSleepDays >= stage1ShortSleepDays;
  }

  /// 부정 태그가 더 오래 이어지는데 **그 날들의 수면은 대체로 충분**했다
  /// → 수면으로 설명되지 않으므로 상담을 안내한다.
  static bool _needsSupportContact(
    Iterable<DiaryEntry> entries,
    SleepTarget target,
    DiaryDate today,
  ) {
    final negativeDays = _negativeDaysWithin(entries, today, stage2WindowDays);
    if (negativeDays.length < stage2NegativeDays) {
      return false;
    }
    final judged = negativeDays
        .where((entry) => entry.sleepDuration != null)
        .toList();
    // 수면 기록이 없으면 "충분히 잤는데도"를 말할 근거가 없다. 띄우지 않는다.
    if (judged.isEmpty) {
      return false;
    }
    final metTarget = judged
        .where((entry) => entry.markWith(target)!.meetsTarget)
        .length;
    return metTarget * 2 > judged.length; // 과반
  }

  /// [today]를 포함한 최근 [days]일 중 부정 태그가 있는 기록.
  static List<DiaryEntry> _negativeDaysWithin(
    Iterable<DiaryEntry> entries,
    DiaryDate today,
    int days,
  ) {
    final from = today.addDays(-(days - 1));
    return entries
        .where(
          (entry) =>
              !entry.date.isBefore(from) &&
              !entry.date.isAfter(today) &&
              entry.hasNegativeMood,
        )
        .toList();
  }
}
