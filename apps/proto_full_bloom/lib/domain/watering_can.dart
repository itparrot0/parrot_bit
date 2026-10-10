import 'bloom_color.dart';

/// 물뿌리개 한 개. 색과 남은 횟수를 갖는다.
///
/// **남은 횟수가 0이 될 때까지 슬롯을 차지한다** (PRD §3.5) — 멈췄을 때 남은
/// 횟수는 버려지지 않는다. 그래서 가변 객체다: 같은 물뿌리개가 여러 턴에
/// 걸쳐 쓰인다.
final class WateringCan {
  WateringCan({required this.color, required int count})
    : _remaining = count,
      initialCount = count {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', '1 이상이어야 한다');
    }
  }

  final BloomColor color;

  /// 처음 받은 횟수. 표시와 되돌리기에 쓴다.
  final int initialCount;

  int _remaining;

  int get remaining => _remaining;

  bool get isEmpty => _remaining == 0;

  /// 물 한 번을 쓴다.
  void spendOne() {
    if (_remaining == 0) {
      throw StateError('남은 횟수가 없는 물뿌리개를 썼다: $this');
    }
    _remaining--;
  }

  WateringCan copy() {
    final clone = WateringCan(color: color, count: initialCount);
    clone._remaining = _remaining;
    return clone;
  }

  @override
  String toString() => '${color.name} x$_remaining/$initialCount';
}
