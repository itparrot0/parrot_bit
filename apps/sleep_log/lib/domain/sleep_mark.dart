/// 달력 날짜 칸에 찍히는 표시 (docs/prd/sleep_log.md §4).
///
/// **표시 길이가 곧 수면량이다 — 판정이 아니라 양을 보여준다.** 빨간 경고나
/// "실패" 같은 낙인 표현을 쓰지 않는 것이 이 앱의 원칙이고, 과다 수면([over])도
/// 나쁘다고 말하지 않고 길이로만 드러낸다.
enum SleepMark {
  /// 부족.
  short('z'),

  /// 적당.
  fair('zZ'),

  /// 충분.
  enough('zzZ'),

  /// 목표 초과. 과다 수면도 의미 있는 신호라 "충분"에 뭉개지 않는다.
  over('zzZZ');

  const SleepMark(this.label);

  final String label;

  /// 수면이 부족한 쪽인가. 안전 안내 1단계 판정에 쓴다.
  bool get isShortOfTarget => this == short || this == fair;

  /// 목표를 채운 쪽인가. 안전 안내 2단계 판정에 쓴다.
  bool get meetsTarget => this == enough || this == over;
}

/// 개인 목표 수면시간. [SleepMark] 판정의 기준이다.
///
/// 남의 기준(8시간)이 아니라 이 값에 **상대적으로** 판정하는 것이 이 앱의
/// 존재 이유다 (PRD §1).
final class SleepTarget {
  SleepTarget(this.duration) {
    if (duration < minDuration || duration > maxDuration) {
      throw ArgumentError.value(
        duration,
        'duration',
        '${minDuration.inHours}~${maxDuration.inHours}시간 사이여야 한다',
      );
    }
  }

  /// 설정 전 기본값.
  static final SleepTarget defaultTarget = SleepTarget(
    const Duration(hours: 7),
  );

  static const Duration minDuration = Duration(hours: 4);
  static const Duration maxDuration = Duration(hours: 12);

  /// 목표 대비 임계값 (PRD §4). 조정 가능한 상수로 둔다.
  static const Duration _shortBelowTarget = Duration(minutes: 90);
  static const Duration _fairBelowTarget = Duration(minutes: 30);
  static const Duration _overAboveTarget = Duration(minutes: 90);

  final Duration duration;

  /// [slept]가 이 목표에 비해 어느 단계인가.
  ///
  /// 목표 7시간이면: `z` <5.5h / `zZ` 5.5~6.5h / `zzZ` 6.5~8.5h / `zzZZ` >8.5h.
  SleepMark markFor(Duration slept) {
    if (slept < duration - _shortBelowTarget) {
      return SleepMark.short;
    }
    if (slept < duration - _fairBelowTarget) {
      return SleepMark.fair;
    }
    if (slept > duration + _overAboveTarget) {
      return SleepMark.over;
    }
    return SleepMark.enough;
  }

  /// 표시가 바뀌는 경계. 사용자에게 설명하는 용도(온보딩 범례)이고, 판정은
  /// [markFor]가 한다 — 둘이 같은 상수를 쓰므로 어긋나지 않는다.
  MarkBounds get bounds => MarkBounds(
    fairFrom: duration - _shortBelowTarget,
    enoughFrom: duration - _fairBelowTarget,
    overAbove: duration + _overAboveTarget,
  );

  @override
  bool operator ==(Object other) =>
      other is SleepTarget && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => 'SleepTarget(${duration.inMinutes}분)';
}

/// [SleepTarget.markFor]의 경계값.
///
/// `z` < [fairFrom] ≤ `zZ` < [enoughFrom] ≤ `zzZ` ≤ [overAbove] < `zzZZ`.
final class MarkBounds {
  const MarkBounds({
    required this.fairFrom,
    required this.enoughFrom,
    required this.overAbove,
  });

  final Duration fairFrom;
  final Duration enoughFrom;
  final Duration overAbove;
}
