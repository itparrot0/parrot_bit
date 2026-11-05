import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/screens/report_screen.dart';

void main() {
  const today = DiaryDate(2026, 11, 5);

  /// [daysAgo]일 전, 00:00에 자서 [hours]시간 잔 기록.
  DiaryEntry entry(int daysAgo, {double? hours, Set<MoodTag> tags = const {}}) {
    final minutes = hours == null ? null : (hours * 60).round();
    return DiaryEntry(
      date: today.addDays(-daysAgo),
      sleep: minutes == null
          ? null
          : SleepSession(
              bedTime: ClockTime(0, 0),
              wakeTime: ClockTime(minutes ~/ 60, minutes % 60),
            ),
      tags: tags,
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Stream<List<DiaryEntry>> entries,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [diaryEntriesProvider.overrideWith((ref) => entries)],
        child: const MaterialApp(home: ReportScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('수면 기록이 2주 미만이면 남은 일수만 안내한다', (tester) async {
    await pumpScreen(
      tester,
      Stream.value([
        for (var i = 0; i < 10; i++)
          entry(i, hours: 7, tags: {DefaultMoodTags.calm}),
        // 수면 없이 태그만 남긴 날은 세지 않는다.
        for (var i = 10; i < 20; i++) entry(i, tags: {DefaultMoodTags.down}),
      ]),
    );

    expect(find.text('수면을 4일 더 기록하면 보여 드려요'), findsOneWidget);
    expect(find.text('10 / 14일'), findsOneWidget);
    expect(find.text('평온'), findsNothing, reason: '표본이 적을 때는 대조를 보여주지 않는다');
  });

  testWidgets('2주가 쌓이면 전체 평균과 태그별 평균을 짧은 순으로 보여준다', (tester) async {
    await pumpScreen(
      tester,
      Stream.value([
        for (var i = 0; i < 4; i++)
          entry(i, hours: 5, tags: {DefaultMoodTags.irritated}),
        for (var i = 4; i < 14; i++)
          entry(i, hours: 7.5, tags: {DefaultMoodTags.calm}),
      ]),
    );

    expect(
      find.text(
        '수면을 기록한 14일 기준이에요. '
        '함께 기록된 것을 나란히 놓았을 뿐, 원인을 뜻하지는 않아요.',
      ),
      findsOneWidget,
    );
    // (4×5h + 10×7.5h) / 14 = 6h47m
    expect(
      find.descendant(
        of: find.byKey(const Key('report.overall')),
        matching: find.text('6시간 47분'),
      ),
      findsOneWidget,
    );

    final irritated = tester.getTopLeft(find.text('짜증'));
    final calm = tester.getTopLeft(find.text('평온'));
    expect(irritated.dy, lessThan(calm.dy), reason: '평균이 짧은 태그가 위');
    expect(find.text('5시간'), findsOneWidget);
    expect(find.text('7시간 30분'), findsOneWidget);
    expect(find.text('4일'), findsOneWidget);
    expect(find.text('10일'), findsOneWidget);
  });

  testWidgets('기록을 읽는 동안에는 로딩 표시', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryEntriesProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(home: ReportScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
