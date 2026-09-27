import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/widgets/calendar/calendar_month.dart';
import 'package:sleep_log/widgets/calendar/month_grid.dart';

/// 2026년 9월. 1일이 화요일이라 앞에 8/30·8/31이 걸치고 뒤로 10/1~10/10이 온다.
/// 11~29일과 31일은 그리드에서 유일한 숫자라 탭 대상으로 쓸 수 있다.
const _september = CalendarMonth(2026, 9);
const _today = DiaryDate(2026, 9, 15);

Future<void> _pumpGrid(
  WidgetTester tester, {
  Map<DiaryDate, SleepMark?> records = const {},
  ValueChanged<DiaryDate>? onDateTap,
  DiaryDate today = _today,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 350,
            child: MonthGrid(
              month: _september,
              today: today,
              records: records,
              onDateTap: onDateTap,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('MonthGrid 표시', () {
    testWidgets('요일 라벨이 일요일부터 놓인다', (tester) async {
      await _pumpGrid(tester);

      expect(find.text('일'), findsOneWidget);
      expect(find.text('토'), findsOneWidget);
    });

    testWidgets('기록된 z 단계가 그대로 찍힌다', (tester) async {
      await _pumpGrid(
        tester,
        records: {
          const DiaryDate(2026, 9, 11): SleepMark.short,
          const DiaryDate(2026, 9, 12): SleepMark.fair,
          const DiaryDate(2026, 9, 13): SleepMark.enough,
          const DiaryDate(2026, 9, 14): SleepMark.over,
        },
      );

      expect(find.text('z'), findsOneWidget);
      expect(find.text('zZ'), findsOneWidget);
      expect(find.text('zzZ'), findsOneWidget);
      expect(find.text('zzZZ'), findsOneWidget);
    });

    testWidgets('태그만 남긴 날은 z 표시가 없다', (tester) async {
      // 수면 기록이 없으면 판정할 수 없으므로 점으로만 남는다 (PRD §4).
      await _pumpGrid(tester, records: {const DiaryDate(2026, 9, 12): null});

      for (final mark in SleepMark.values) {
        expect(find.text(mark.label), findsNothing);
      }
    });

    testWidgets('미래 날짜에는 표시를 찍지 않는다', (tester) async {
      // 기록될 수 없는 날이므로 점도 찍지 않는다.
      await _pumpGrid(
        tester,
        records: {const DiaryDate(2026, 9, 20): SleepMark.enough},
      );

      expect(find.text('zzZ'), findsNothing);
    });

    testWidgets('그 달의 모든 날과 걸친 앞뒤 날짜가 그려진다', (tester) async {
      await _pumpGrid(tester);

      // 8/31은 이 그리드에서 유일한 '31'이다.
      expect(find.text('31'), findsOneWidget);
      // 9/30과 8/30이 함께 있어 '30'은 둘이다.
      expect(find.text('30'), findsNWidgets(2));
    });
  });

  group('MonthGrid 탭', () {
    testWidgets('지난 날짜를 탭하면 그 날짜를 넘긴다', (tester) async {
      DiaryDate? tapped;
      await _pumpGrid(tester, onDateTap: (date) => tapped = date);

      await tester.tap(find.text('12'));

      expect(tapped, const DiaryDate(2026, 9, 12));
    });

    testWidgets('오늘은 탭할 수 있다', (tester) async {
      DiaryDate? tapped;
      await _pumpGrid(tester, onDateTap: (date) => tapped = date);

      await tester.tap(find.text('15'));

      expect(tapped, _today);
    });

    testWidgets('미래 날짜는 탭해도 반응하지 않는다', (tester) async {
      // 달력에서 선택 자체를 막는다 (docs/screen-flow/sleep_log.md §5).
      DiaryDate? tapped;
      await _pumpGrid(tester, onDateTap: (date) => tapped = date);

      await tester.tap(find.text('20'));

      expect(tapped, isNull);
    });

    testWidgets('앞뒤 달 날짜는 탭해도 반응하지 않는다', (tester) async {
      DiaryDate? tapped;
      await _pumpGrid(tester, onDateTap: (date) => tapped = date);

      await tester.tap(find.text('31')); // 8/31

      expect(tapped, isNull);
    });

    testWidgets('오늘이 달 마지막 날이면 그 달 전체를 탭할 수 있다', (tester) async {
      DiaryDate? tapped;
      await _pumpGrid(
        tester,
        today: const DiaryDate(2026, 9, 30),
        onDateTap: (date) => tapped = date,
      );

      await tester.tap(find.text('29'));

      expect(tapped, const DiaryDate(2026, 9, 29));
    });
  });
}
