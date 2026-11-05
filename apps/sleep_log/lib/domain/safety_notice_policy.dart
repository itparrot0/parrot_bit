import 'diary_date.dart';
import 'safety_check.dart';

/// 안전 안내를 **지금 띄울지** 정한다 (docs/prd/sleep_log.md §9-2 노출 규칙).
///
/// [SafetyCheck]는 "안내가 필요한 상태인가"만 판정한다. 여기서는 그 결과에
/// 반복 노출 규칙을 더한다 — 반복 노출은 낙인이 되고 결국 무시하게 된다.
///
/// - 한 번 띄운 단계는 [cooldownDays]일 동안 다시 띄우지 않는다.
/// - 2단계를 띄운 뒤 [cooldownDays]일 동안은 1단계도 띄우지 않는다
///   ("2단계가 떠 있는 동안 1단계는 띄우지 않는다").
/// - 반대로 **1단계를 띄운 뒤라도 2단계는 띄운다.** 상태가 더 무거워졌다는
///   신호라서, 1단계의 쉬는 기간이 상담 연락처를 가리면 안 된다.
abstract final class SafetyNoticePolicy {
  static const int cooldownDays = 14;

  /// [advice]를 오늘 띄울지. 띄우지 않으면 [SafetyAdvice.none].
  ///
  /// [lastRestShown]·[lastSupportShown]은 각 단계를 마지막으로 띄운 날.
  /// 기기 시계가 되돌아가 마지막 노출이 오늘보다 미래여도 쉬는 중으로 본다.
  static SafetyAdvice decide({
    required SafetyAdvice advice,
    required DiaryDate today,
    required DiaryDate? lastRestShown,
    required DiaryDate? lastSupportShown,
  }) {
    final supportResting = _isResting(lastSupportShown, today);
    switch (advice) {
      case SafetyAdvice.none:
        return SafetyAdvice.none;
      case SafetyAdvice.supportContact:
        return supportResting ? SafetyAdvice.none : SafetyAdvice.supportContact;
      case SafetyAdvice.restSuggestion:
        if (supportResting || _isResting(lastRestShown, today)) {
          return SafetyAdvice.none;
        }
        return SafetyAdvice.restSuggestion;
    }
  }

  static bool _isResting(DiaryDate? lastShown, DiaryDate today) =>
      lastShown != null && lastShown.addDays(cooldownDays).isAfter(today);
}
