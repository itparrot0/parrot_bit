/// 시각 없는 날짜.
///
/// [DateTime]을 날짜로 쓰면 시·분이 섞여 들어와 Map 키와 비교가 조용히 깨진다.
/// 기록은 "며칠"에 붙는 것이지 "몇 시"에 붙는 것이 아니므로 타입으로 분리한다.
final class DiaryDate implements Comparable<DiaryDate> {
  const DiaryDate(this.year, this.month, this.day);

  DiaryDate.fromDateTime(DateTime dateTime)
    : year = dateTime.year,
      month = dateTime.month,
      day = dateTime.day;

  final int year;
  final int month;
  final int day;

  DateTime toDateTime() => DateTime(year, month, day);

  /// [days]만큼 이동한 날짜. 음수면 과거로 간다.
  ///
  /// `DateTime.add(Duration(days:))`를 쓰지 않는다 — 로컬 타임존의 서머타임
  /// 전환일에 23시간/25시간이 되어 날짜가 밀린다. 달 넘김은 DateTime 생성자가
  /// 정규화해준다.
  DiaryDate addDays(int days) =>
      DiaryDate.fromDateTime(DateTime(year, month, day + days));

  DiaryDate get previous => addDays(-1);

  bool isBefore(DiaryDate other) => compareTo(other) < 0;

  bool isAfter(DiaryDate other) => compareTo(other) > 0;

  /// ISO-8601 `yyyy-MM-dd`. 라우트 파라미터와 저장 키에 쓴다.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// [toIso] 형식만 받는다. 형식이 아니거나 없는 날짜(2월 30일 등)면 null.
  static DiaryDate? tryParseIso(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      return null;
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    // DateTime은 2026-02-30을 3월 2일로 넘겨버리므로, 되돌려 비교해 걸러낸다.
    final normalized = DateTime(year, month, day);
    if (normalized.month != month || normalized.day != day) {
      return null;
    }
    return DiaryDate(year, month, day);
  }

  @override
  int compareTo(DiaryDate other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    if (month != other.month) {
      return month.compareTo(other.month);
    }
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
