import '../../domain/domain.dart';

/// 달력이 한 번에 보여주는 한 달과, 그 달의 그리드 배치.
///
/// 순수 Dart다 — 앞뒤 달이 몇 칸 걸치는지 같은 계산은 위젯을 띄우지 않고
/// 테스트한다. 달력 패키지를 쓰지 않는 이유가 여기 있다: z 표시 때문에 칸을
/// 직접 그려야 하고, 그러면 배치 계산도 우리 것이라 테스트할 수 있다.
final class CalendarMonth implements Comparable<CalendarMonth> {
  const CalendarMonth(this.year, this.month);

  CalendarMonth.of(DiaryDate date) : year = date.year, month = date.month;

  final int year;

  /// 1~12.
  final int month;

  /// 그리드의 행 수. **달마다 5행·6행으로 바뀌지 않게 6행으로 고정한다** —
  /// 스와이프로 달을 넘길 때 높이가 튀면 눈이 따라가지 못한다.
  static const int rowCount = 6;

  static const int columnCount = 7;

  static const int cellCount = rowCount * columnCount;

  DiaryDate get firstDay => DiaryDate(year, month, 1);

  /// 이 달의 마지막 날. `day: 0`은 전달의 마지막 날이 된다.
  DiaryDate get lastDay => DiaryDate.fromDateTime(DateTime(year, month + 1, 0));

  int get dayCount => lastDay.day;

  bool contains(DiaryDate date) => date.year == year && date.month == month;

  CalendarMonth addMonths(int months) {
    final moved = DateTime(year, month + months, 1);
    return CalendarMonth(moved.year, moved.month);
  }

  CalendarMonth get next => addMonths(1);

  CalendarMonth get previous => addMonths(-1);

  /// [other]에서 이 달까지 몇 달인가. 페이저 인덱스 계산에 쓴다.
  int monthsSince(CalendarMonth other) =>
      (year - other.year) * 12 + (month - other.month);

  /// 그리드에 놓일 [cellCount]칸의 날짜. 앞뒤 달의 날짜가 섞여 들어온다.
  ///
  /// [firstWeekday]는 `DateTime.sunday`처럼 `DateTime`의 요일 상수를 받는다.
  List<DiaryDate> gridDates({int firstWeekday = DateTime.sunday}) {
    final leading = leadingBlankCount(firstWeekday: firstWeekday);
    return [
      for (var index = 0; index < cellCount; index++)
        firstDay.addDays(index - leading),
    ];
  }

  /// 1일 앞에 놓이는 전달 날짜의 개수 (0~6).
  int leadingBlankCount({int firstWeekday = DateTime.sunday}) =>
      (firstDay.toDateTime().weekday - firstWeekday + 7) % 7;

  String get label => '$year년 $month월';

  /// 요일 라벨을 [firstWeekday]부터 순서대로 낸다.
  static List<String> weekdayLabels({int firstWeekday = DateTime.sunday}) => [
    for (var offset = 0; offset < columnCount; offset++)
      _weekdayNames[(firstWeekday - 1 + offset) % columnCount],
  ];

  /// `DateTime.monday`(1)부터 `DateTime.sunday`(7) 순서.
  static const List<String> _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  int compareTo(CalendarMonth other) => monthsSince(other);

  @override
  bool operator ==(Object other) =>
      other is CalendarMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => label;
}
