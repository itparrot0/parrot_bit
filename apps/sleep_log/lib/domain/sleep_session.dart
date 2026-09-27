/// 하루 중의 시각 (분 단위). Flutter의 `TimeOfDay`에 의존하지 않기 위한 값 객체.
final class ClockTime implements Comparable<ClockTime> {
  ClockTime(this.hour, this.minute) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', '0~23이어야 한다');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', '0~59이어야 한다');
    }
  }

  final int hour;
  final int minute;

  int get totalMinutes => hour * 60 + minute;

  @override
  int compareTo(ClockTime other) => totalMinutes.compareTo(other.totalMinutes);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.totalMinutes == totalMinutes;

  @override
  int get hashCode => totalMinutes;

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// 하룻밤의 수면.
///
/// 취침·기상은 **시각만** 갖고 날짜 경계는 규칙으로 해석한다 — 사용자에게
/// "몇 일에 잤나요"를 묻지 않는다(docs/screen-flow/sleep_log.md §5).
/// 규칙: 취침 시각이 기상 시각보다 늦으면 취침은 전날이다.
/// 23:30→07:00은 7시간 30분, 01:30→09:00도 7시간 30분으로 같은 규칙에 잡힌다.
final class SleepSession {
  SleepSession({required this.bedTime, required this.wakeTime}) {
    if (!isValidRange(bedTime, wakeTime)) {
      throw ArgumentError('취침과 기상 시각이 같으면 수면시간이 0인지 24시간인지 정할 수 없다: $bedTime');
    }
  }

  final ClockTime bedTime;
  final ClockTime wakeTime;

  /// 두 시각으로 수면시간을 정할 수 있는가. 입력 화면이 저장 전에 확인한다.
  static bool isValidRange(ClockTime bedTime, ClockTime wakeTime) =>
      bedTime != wakeTime;

  Duration get duration {
    final minutes = wakeTime.totalMinutes - bedTime.totalMinutes;
    // 음수면 자정을 넘긴 것이다. 같은 값은 생성자가 이미 막았다.
    return Duration(minutes: minutes > 0 ? minutes : minutes + 24 * 60);
  }

  /// 취침이 기록 날짜의 전날인가 (23:30 취침 → true, 01:30 취침 → false).
  bool get startedPreviousDay => bedTime.compareTo(wakeTime) > 0;

  @override
  bool operator ==(Object other) =>
      other is SleepSession &&
      other.bedTime == bedTime &&
      other.wakeTime == wakeTime;

  @override
  int get hashCode => Object.hash(bedTime, wakeTime);

  @override
  String toString() =>
      'SleepSession($bedTime→$wakeTime, ${duration.inMinutes}분)';
}
