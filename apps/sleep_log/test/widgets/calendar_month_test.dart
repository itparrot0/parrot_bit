import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/widgets/calendar/calendar_month.dart';

void main() {
  group('CalendarMonth 기본', () {
    test('날짜에서 그 달을 만든다', () {
      expect(
        CalendarMonth.of(const DiaryDate(2026, 9, 27)),
        const CalendarMonth(2026, 9),
      );
    });

    test('달의 첫날과 마지막날을 낸다', () {
      expect(
        const CalendarMonth(2026, 9).firstDay,
        const DiaryDate(2026, 9, 1),
      );
      expect(
        const CalendarMonth(2026, 9).lastDay,
        const DiaryDate(2026, 9, 30),
      );
      expect(
        const CalendarMonth(2026, 2).lastDay,
        const DiaryDate(2026, 2, 28),
      );
      // 12월은 연도를 넘어 계산된다.
      expect(
        const CalendarMonth(2026, 12).lastDay,
        const DiaryDate(2026, 12, 31),
      );
    });

    test('윤년 2월은 29일이다', () {
      expect(const CalendarMonth(2028, 2).dayCount, 29);
      expect(const CalendarMonth(2026, 2).dayCount, 28);
    });

    test('달 이동은 연도를 넘어간다', () {
      expect(const CalendarMonth(2026, 12).next, const CalendarMonth(2027, 1));
      expect(
        const CalendarMonth(2026, 1).previous,
        const CalendarMonth(2025, 12),
      );
      expect(
        const CalendarMonth(2026, 9).addMonths(-24),
        const CalendarMonth(2024, 9),
      );
    });

    test('두 달 사이의 개월 수를 센다', () {
      expect(
        const CalendarMonth(2026, 9).monthsSince(const CalendarMonth(2026, 9)),
        0,
      );
      expect(
        const CalendarMonth(2026, 9).monthsSince(const CalendarMonth(2024, 9)),
        24,
      );
      expect(
        const CalendarMonth(2025, 12).monthsSince(const CalendarMonth(2026, 1)),
        -1,
      );
    });

    test('그 달의 날짜인지 판단한다', () {
      const september = CalendarMonth(2026, 9);

      expect(september.contains(const DiaryDate(2026, 9, 1)), isTrue);
      expect(september.contains(const DiaryDate(2026, 9, 30)), isTrue);
      expect(september.contains(const DiaryDate(2026, 10, 1)), isFalse);
      expect(september.contains(const DiaryDate(2025, 9, 15)), isFalse);
    });
  });

  group('CalendarMonth 그리드 배치', () {
    test('항상 42칸이다', () {
      // 달마다 행 수가 바뀌면 스와이프할 때 높이가 튄다.
      for (var month = 1; month <= 12; month++) {
        expect(CalendarMonth(2026, month).gridDates(), hasLength(42));
      }
    });

    test('1일이 일요일이면 앞에 빈칸이 없다', () {
      // 2026-02-01은 일요일.
      expect(
        const CalendarMonth(2026, 2).firstDay.toDateTime().weekday,
        DateTime.sunday,
      );
      expect(const CalendarMonth(2026, 2).leadingBlankCount(), 0);
      expect(
        const CalendarMonth(2026, 2).gridDates().first,
        const DiaryDate(2026, 2, 1),
      );
    });

    test('1일이 화요일이면 앞에 2칸이 전달 날짜다', () {
      // 2026-09-01은 화요일.
      expect(
        const CalendarMonth(2026, 9).firstDay.toDateTime().weekday,
        DateTime.tuesday,
      );
      final dates = const CalendarMonth(2026, 9).gridDates();

      expect(const CalendarMonth(2026, 9).leadingBlankCount(), 2);
      expect(dates[0], const DiaryDate(2026, 8, 30));
      expect(dates[1], const DiaryDate(2026, 8, 31));
      expect(dates[2], const DiaryDate(2026, 9, 1));
    });

    test('그리드는 하루씩 빈틈없이 이어진다', () {
      final dates = const CalendarMonth(2026, 9).gridDates();

      for (var index = 1; index < dates.length; index++) {
        expect(dates[index], dates[index - 1].addDays(1));
      }
    });

    test('그 달의 모든 날이 그리드에 들어 있다', () {
      const month = CalendarMonth(2026, 5);
      final dates = month.gridDates().toSet();

      for (var day = 1; day <= month.dayCount; day++) {
        expect(dates, contains(DiaryDate(2026, 5, day)));
      }
    });

    test('월요일 시작으로 바꾸면 앞 빈칸이 달라진다', () {
      // 2026-09-01 화요일 → 일요일 시작이면 2칸, 월요일 시작이면 1칸.
      const september = CalendarMonth(2026, 9);

      expect(september.leadingBlankCount(firstWeekday: DateTime.monday), 1);
      expect(
        september.gridDates(firstWeekday: DateTime.monday).first,
        const DiaryDate(2026, 8, 31),
      );
    });
  });

  group('요일 라벨', () {
    test('일요일 시작이 기본이다', () {
      expect(CalendarMonth.weekdayLabels(), [
        '일',
        '월',
        '화',
        '수',
        '목',
        '금',
        '토',
      ]);
    });

    test('월요일 시작도 순서가 맞다', () {
      expect(CalendarMonth.weekdayLabels(firstWeekday: DateTime.monday), [
        '월',
        '화',
        '수',
        '목',
        '금',
        '토',
        '일',
      ]);
    });
  });
}
