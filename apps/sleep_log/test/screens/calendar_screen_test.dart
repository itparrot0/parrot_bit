import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/screens/calendar_screen.dart';

void main() {
  const today = DiaryDate(2026, 11, 5);
  final target = SleepTarget(const Duration(hours: 7));
  final overnight = SleepSession(
    bedTime: ClockTime(23, 0),
    wakeTime: ClockTime(6, 0),
  );

  group('CalendarView.from', () {
    test('수면이 있으면 z 표시, 태그만 있으면 null 값으로 키가 있다', () {
      final view = CalendarView.from(
        entries: [
          DiaryEntry(date: today.previous, sleep: overnight),
          DiaryEntry(date: today, tags: {DefaultMoodTags.calm}),
        ],
        target: target,
        today: today,
      );

      expect(view.records, {today.previous: SleepMark.enough, today: null});
      expect(view.hasTodayEntry, isTrue);
    });

    test('목표가 바뀌면 같은 수면도 다르게 판정된다', () {
      final entries = [DiaryEntry(date: today, sleep: overnight)];

      final view = CalendarView.from(
        entries: entries,
        target: SleepTarget(const Duration(hours: 9)),
        today: today,
      );

      expect(view.records[today], SleepMark.short);
    });

    test('오늘 기록이 없으면 hasTodayEntry는 false', () {
      final view = CalendarView.from(
        entries: [DiaryEntry(date: today.previous, sleep: overnight)],
        target: target,
        today: today,
      );

      expect(view.hasTodayEntry, isFalse);
    });
  });

  group('CalendarView.monthsBackFor', () {
    test('기록이 없어도 지난달까지는 갈 수 있다', () {
      expect(CalendarView.monthsBackFor(earliest: null, today: today), 1);
    });

    test('이번 달 기록만 있어도 최소 1', () {
      expect(
        CalendarView.monthsBackFor(
          earliest: const DiaryDate(2026, 11, 1),
          today: today,
        ),
        1,
      );
    });

    test('가장 오래된 기록의 달까지 — 연도를 넘어서도', () {
      expect(
        CalendarView.monthsBackFor(
          earliest: const DiaryDate(2025, 9, 30),
          today: today,
        ),
        14,
      );
    });

    test('기록이 오늘보다 미래여도(시계 되돌림) 최소값', () {
      expect(
        CalendarView.monthsBackFor(
          earliest: const DiaryDate(2027, 1, 1),
          today: today,
        ),
        1,
      );
    });
  });

  group('CalendarScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required Stream<List<DiaryEntry>> entries,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayProvider.overrideWithValue(today),
            diaryEntriesProvider.overrideWith((ref) => entries),
            sleepTargetProvider.overrideWithValue(target),
          ],
          child: const MaterialApp(home: CalendarScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('오늘 기록이 없으면 "오늘 기록" 버튼이 보인다', (tester) async {
      await pumpScreen(tester, entries: Stream.value(const []));

      expect(find.text('오늘 기록'), findsOneWidget);
    });

    testWidgets('오늘 기록이 있으면 버튼을 숨긴다', (tester) async {
      await pumpScreen(
        tester,
        entries: Stream.value([DiaryEntry(date: today, sleep: overnight)]),
      );

      expect(find.text('오늘 기록'), findsNothing);
    });

    testWidgets('기록을 읽기 전에는 버튼을 띄우지 않는다', (tester) async {
      await pumpScreen(tester, entries: const Stream.empty());

      expect(find.text('오늘 기록'), findsNothing);
    });

    testWidgets('저장된 수면이 달력에 z 표시로 그려진다', (tester) async {
      await pumpScreen(
        tester,
        entries: Stream.value([
          DiaryEntry(date: today.previous, sleep: overnight),
        ]),
      );

      expect(find.text(SleepMark.enough.label), findsOneWidget);
    });

    testWidgets('앱바의 리포트 버튼이 보인다', (tester) async {
      await pumpScreen(tester, entries: Stream.value(const []));

      expect(find.byTooltip('리포트'), findsOneWidget);
    });
  });
}
