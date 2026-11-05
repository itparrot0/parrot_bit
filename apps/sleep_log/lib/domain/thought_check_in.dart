import 'diary_date.dart';
import 'sleep_session.dart';

// 생각 돌아보기 — 하루 두 번(오전/오후) 스스로 살펴보는 짧은 체크인
// (docs/prd/sleep_log.md §3-3).
//
// **진단이 아니라 자기 관찰이다.** 질문은 증상 항목이 아니라 "돌아보게 하는"
// 말로 묻고, 앱은 답을 판정하지 않는다. 수면 기록과 나란히 놓아 패턴을
// 사용자가 스스로 발견하게 할 뿐이다.

/// 체크인 시간대.
enum CheckInSlot {
  morning('오전'),
  afternoon('오후');

  const CheckInSlot(this.label);

  final String label;

  /// 이 시각(시)부터 오후로 본다. 오전 알림을 늦게 열어도 점심 전까지는 오전이다.
  static const int afternoonFromHour = 14;

  static CheckInSlot at(DateTime time) =>
      time.hour < afternoonFromHour ? morning : afternoon;

  static CheckInSlot? tryParse(String value) {
    for (final slot in values) {
      if (slot.name == value) {
        return slot;
      }
    }
    return null;
  }
}

/// 머릿속이 돌아가는 속도. 사용자의 체감이고, 앱은 어느 쪽도 나쁘다고 하지 않는다.
enum MindPace {
  slow('느긋했어요'),
  usual('평소 같았어요'),
  busy('바쁘게 돌아갔어요');

  const MindPace(this.label);

  final String label;
}

/// 감각이 평소와 달랐던 정도 (소리·빛·몸의 느낌).
enum SenseShift {
  none('딱히 없었어요'),
  some('한두 번 있었어요'),
  often('여러 번 있었어요');

  const SenseShift(this.label);

  final String label;
}

/// 체크인 한 번. 모든 항목이 선택이다 — 하나만 답해도 저장된다.
final class ThoughtCheckIn {
  ThoughtCheckIn({
    required this.date,
    required this.slot,
    this.pace,
    this.senses,
    String? thought,
    String? reframe,
  }) : thought = _clean(thought),
       reframe = _clean(reframe);

  final DiaryDate date;
  final CheckInSlot slot;
  final MindPace? pace;
  final SenseShift? senses;

  /// 지금 마음을 가장 많이 차지한 생각 (자유 입력).
  final String? thought;

  /// 그 생각을 다른 눈으로 본 말 — "친구가 그렇게 말한다면 뭐라고 해 줄까?"
  /// 확증편향을 지적하지 않고, 다른 가능성을 스스로 떠올리게 하는 자리다.
  final String? reframe;

  bool get isEmpty =>
      pace == null && senses == null && thought == null && reframe == null;

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is ThoughtCheckIn &&
      other.date == date &&
      other.slot == slot &&
      other.pace == pace &&
      other.senses == senses &&
      other.thought == thought &&
      other.reframe == reframe;

  @override
  int get hashCode => Object.hash(date, slot, pace, senses, thought, reframe);

  @override
  String toString() => 'ThoughtCheckIn($date ${slot.name}, $pace, $senses)';
}

/// 생각 돌아보기 설정. **기본 꺼짐** — 하루 1회 기록이 기본인 앱이라(PRD §2),
/// 하루 두 번 묻는 기능은 원하는 사람만 켠다.
final class CheckInSettings {
  CheckInSettings({
    this.enabled = false,
    ClockTime? morningTime,
    ClockTime? afternoonTime,
  }) : morningTime = morningTime ?? defaultMorning,
       afternoonTime = afternoonTime ?? defaultAfternoon;

  static final ClockTime defaultMorning = ClockTime(10, 0);
  static final ClockTime defaultAfternoon = ClockTime(17, 0);

  final bool enabled;

  /// 알림 시각. 오전 알림은 [CheckInSlot.afternoonFromHour] 전이어야 오전
  /// 체크인으로 열린다 — 설정 화면이 고를 수 있는 범위를 나눈다.
  final ClockTime morningTime;
  final ClockTime afternoonTime;

  ClockTime timeOf(CheckInSlot slot) => switch (slot) {
    CheckInSlot.morning => morningTime,
    CheckInSlot.afternoon => afternoonTime,
  };

  CheckInSettings copyWith({
    bool? enabled,
    ClockTime? morningTime,
    ClockTime? afternoonTime,
  }) => CheckInSettings(
    enabled: enabled ?? this.enabled,
    morningTime: morningTime ?? this.morningTime,
    afternoonTime: afternoonTime ?? this.afternoonTime,
  );

  @override
  bool operator ==(Object other) =>
      other is CheckInSettings &&
      other.enabled == enabled &&
      other.morningTime == morningTime &&
      other.afternoonTime == afternoonTime;

  @override
  int get hashCode => Object.hash(enabled, morningTime, afternoonTime);
}
