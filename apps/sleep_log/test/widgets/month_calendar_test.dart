import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/widgets/calendar/month_calendar.dart';

const _today = DiaryDate(2026, 9, 15);

Future<void> _pumpCalendar(
  WidgetTester tester, {
  ValueChanged<DiaryDate>? onDateTap,
  int monthsBack = 24,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 350,
            child: MonthCalendar(
              today: _today,
              onDateTap: onDateTap,
              monthsBack: monthsBack,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('항상 이번 달로 열린다', (tester) async {
    await _pumpCalendar(tester);

    expect(find.text('2026년 9월'), findsOneWidget);
  });

  testWidgets('이번 달에서는 다음 달로 갈 수 없다', (tester) async {
    // 미래는 기록할 수 없는 날들이다.
    await _pumpCalendar(tester);

    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('이번 달에서는 오늘 버튼이 없다', (tester) async {
    await _pumpCalendar(tester);

    expect(find.byIcon(Icons.today), findsNothing);
  });

  testWidgets('이전 달로 넘어가면 제목이 바뀐다', (tester) async {
    await _pumpCalendar(tester);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 8월'), findsOneWidget);
    expect(find.text('2026년 9월'), findsNothing);
  });

  testWidgets('이전 달에서는 다음 달·오늘 버튼이 나타난다', (tester) async {
    await _pumpCalendar(tester);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.today), findsOneWidget);
  });

  testWidgets('오늘 버튼은 이번 달로 되돌린다', (tester) async {
    await _pumpCalendar(tester);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.today));
    await tester.pumpAndSettle();

    expect(find.text('2026년 9월'), findsOneWidget);
  });

  testWidgets('연도를 넘어 과거로 갈 수 있다', (tester) async {
    await _pumpCalendar(tester);

    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
    }

    expect(find.text('2025년 12월'), findsOneWidget);
  });

  testWidgets('상한까지 가면 이전 달 버튼이 꺼진다', (tester) async {
    await _pumpCalendar(tester, monthsBack: 1);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 8월'), findsOneWidget);
    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_left),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('달을 넘긴 뒤에도 날짜 탭이 그 달의 날짜를 넘긴다', (tester) async {
    DiaryDate? tapped;
    await _pumpCalendar(tester, onDateTap: (date) => tapped = date);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12'));

    expect(tapped, const DiaryDate(2026, 8, 12));
  });
}
