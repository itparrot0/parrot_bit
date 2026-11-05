import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/screens/entry_screen.dart';

import '../support/in_memory_diary_repository.dart';

void main() {
  const today = DiaryDate(2026, 11, 5);

  late InMemoryDiaryRepository repository;

  setUp(() => repository = InMemoryDiaryRepository());

  /// 홈에서 기록 화면을 push한 상태로 띄운다 — 저장·삭제·뒤로가기가 화면을
  /// 닫는지 보려면 돌아갈 화면이 있어야 한다.
  Future<void> openEntry(WidgetTester tester, DiaryDate date) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryRepositoryProvider.overrideWithValue(repository),
          todayProvider.overrideWithValue(today),
          sleepTargetProvider.overrideWithValue(
            SleepTarget(const Duration(hours: 7)),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EntryScreen(date: date.toIso()),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, '저장'));

  Future<DiaryEntry?> stored(DiaryDate date) => repository.find(date);

  testWidgets('새 기록: 아무것도 없으면 저장할 수 없다', (tester) async {
    await openEntry(tester, today);

    expect(find.text('11월 5일 (목)'), findsOneWidget);
    expect(find.text('수면 시각 넣기'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('태그만 골라도 저장되고 화면이 닫힌다', (tester) async {
    await openEntry(tester, today);

    await tester.tap(find.text('평온'));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget, reason: '저장하면 닫혀야 한다');
    final entry = await stored(today);
    expect(entry!.tags, {DefaultMoodTags.calm});
    expect(entry.sleep, isNull);
  });

  testWidgets('수면 시각을 넣으면 수면시간과 z 단계가 바로 보인다', (tester) async {
    await openEntry(tester, today);

    await tester.tap(find.text('수면 시각 넣기'));
    await tester.pump();

    expect(find.text('23:00'), findsOneWidget);
    expect(find.text('07:00'), findsOneWidget);
    final summary = tester.widget<Text>(
      find.byKey(const Key('entry.sleepSummary')),
    );
    expect(summary.textSpan!.toPlainText(), '8시간  ${SleepMark.enough.label}');
  });

  testWidgets('새 기록의 기본 수면 시각은 가장 최근 수면 기록을 따른다', (tester) async {
    await repository.save(
      DiaryEntry(
        date: today.previous,
        sleep: SleepSession(
          bedTime: ClockTime(1, 30),
          wakeTime: ClockTime(9, 15),
        ),
      ),
    );
    await openEntry(tester, today);

    await tester.tap(find.text('수면 시각 넣기'));
    await tester.pump();

    expect(find.text('01:30'), findsOneWidget);
    expect(find.text('09:15'), findsOneWidget);
  });

  testWidgets('기록된 날은 편집 모드 — 저장된 값이 채워지고 삭제할 수 있다', (tester) async {
    await repository.save(
      DiaryEntry(
        date: today,
        sleep: SleepSession(
          bedTime: ClockTime(0, 0),
          wakeTime: ClockTime(6, 0),
        ),
        tags: {DefaultMoodTags.tired},
      ),
    );
    await openEntry(tester, today);

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);
    final tiredChip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '피곤'),
    );
    expect(tiredChip.selected, isTrue);

    await tester.tap(find.byTooltip('기록 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(await stored(today), isNull);
  });

  testWidgets('저장하지 않고 뒤로 가면 버릴지 묻는다', (tester) async {
    await openEntry(tester, today);
    await tester.tap(find.text('평온'));
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('저장하지 않은 내용을 버릴까요?'), findsOneWidget);

    await tester.tap(find.text('계속 쓰기'));
    await tester.pumpAndSettle();
    expect(find.text('평온'), findsOneWidget, reason: '계속 쓰면 화면에 남는다');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('버리기'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(await stored(today), isNull);
  });

  testWidgets('바꾼 게 없으면 묻지 않고 닫힌다', (tester) async {
    await openEntry(tester, today);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('미래 날짜는 기록할 수 없다', (tester) async {
    await openEntry(tester, today.addDays(1));

    expect(find.text('미래 날짜는 기록할 수 없어요.'), findsOneWidget);
    expect(find.text('저장'), findsNothing);
  });
}
