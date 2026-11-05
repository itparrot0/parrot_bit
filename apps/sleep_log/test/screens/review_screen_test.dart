import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/screens/review_screen.dart';

void main() {
  const today = DiaryDate(2026, 11, 14);

  DiaryEntry entry(int day, double hours, {Set<MoodTag> tags = const {}}) {
    final minutes = (hours * 60).round();
    return DiaryEntry(
      date: DiaryDate(2026, 11, day),
      sleep: SleepSession(
        bedTime: ClockTime(0, 0),
        wakeTime: ClockTime(minutes ~/ 60, minutes % 60),
      ),
      tags: tags,
    );
  }

  ThoughtCheckIn thought(int day, String text, [String? reframe]) =>
      ThoughtCheckIn(
        date: DiaryDate(2026, 11, day),
        slot: CheckInSlot.morning,
        thought: text,
        reframe: reframe,
      );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<DiaryEntry> entries = const [],
    List<ThoughtCheckIn> checkIns = const [],
    int seed = 1,
  }) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayProvider.overrideWithValue(today),
          diaryEntriesProvider.overrideWith((ref) => Stream.value(entries)),
          checkInsProvider.overrideWith((ref) => Stream.value(checkIns)),
          sleepTargetProvider.overrideWithValue(
            SleepTarget(const Duration(hours: 7)),
          ),
          randomProvider.overrideWithValue(Random(seed)),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          supportedLocales: [Locale('ko')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ReviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('기본은 최근 14일', (tester) async {
    await pumpScreen(tester);

    expect(find.text('11월 1일 ~ 11월 14일 · 14일'), findsOneWidget);
  });

  testWidgets('프리셋을 바꾸면 기간과 분석이 바뀐다', (tester) async {
    await pumpScreen(
      tester,
      entries: [for (var d = 2; d <= 4; d++) entry(d, 5)],
    );
    expect(find.text('목표보다 적게 잔 날이 이어졌어요'), findsOneWidget);
    expect(find.text('11월 2일 ~ 11월 4일 · 3일'), findsOneWidget);

    await tester.tap(find.text('최근 7일'));
    await tester.pumpAndSettle();

    expect(find.text('11월 8일 ~ 11월 14일 · 7일'), findsOneWidget);
    expect(find.text('이 기간에는 남긴 기록이 없어요.\n다른 기간을 골라 보세요.'), findsOneWidget);
  });

  testWidgets('요약: 기록한 날·평균 수면·생각 돌아보기 수', (tester) async {
    await pumpScreen(
      tester,
      entries: [entry(10, 6), entry(11, 8)],
      checkIns: [thought(11, '괜찮을까')],
    );

    expect(find.text('2일'), findsOneWidget);
    expect(find.text('7시간'), findsOneWidget);
    expect(find.text('1번'), findsOneWidget);
    expect(find.text('3일 넘게 이어진 흐름은 없었어요.'), findsOneWidget);
  });

  testWidgets('생각과 건넨 말을 짝지어 보여 주고, 건넨 말이 없으면 권한다', (tester) async {
    await pumpScreen(
      tester,
      checkIns: [
        thought(3, '다 망할 것 같다', '지난번에도 해냈잖아'),
        thought(5, '아무도 신경 안 쓴다'),
      ],
    );

    expect(find.text('“다 망할 것 같다”'), findsOneWidget);
    expect(find.text('지난번에도 해냈잖아'), findsOneWidget);
    expect(find.text('“아무도 신경 안 쓴다”'), findsOneWidget);
    expect(find.textContaining('건네고 싶은 말은 적지 않았어요'), findsOneWidget);
  });

  testWidgets('생각은 최대 5개, 다시 섞으면 다른 조합이 나올 수 있다', (tester) async {
    await pumpScreen(
      tester,
      checkIns: [for (var d = 1; d <= 9; d++) thought(d, '생각 $d')],
    );

    Set<String> shown() => {
      for (var d = 1; d <= 9; d++)
        if (find.text('“생각 $d”').evaluate().isNotEmpty) '생각 $d',
    };
    final first = shown();
    expect(first, hasLength(5));

    final seen = {...first};
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.text('다시 섞기'));
      await tester.pumpAndSettle();
      expect(shown(), hasLength(5));
      seen.addAll(shown());
    }
    expect(seen.length, greaterThan(5), reason: '섞으면 다른 생각도 보여야 한다');
  });

  testWidgets('개발자가 보내는 편지 한 문장이 보인다 — 같은 시드면 같은 문장', (tester) async {
    String shownLetter() {
      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('review.letter')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .whereType<String>();
      return texts.firstWhere(DeveloperLetters.all.contains);
    }

    await pumpScreen(tester, seed: 42);
    expect(find.text(DeveloperLetters.title), findsOneWidget);
    final first = shownLetter();

    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester, seed: 42);
    expect(shownLetter(), first);
  });

  testWidgets('직접 고르기는 한국어 기간 선택기를 연다', (tester) async {
    await pumpScreen(tester, entries: [entry(1, 7)]);

    await tester.tap(find.text('직접 고르기'));
    await tester.pumpAndSettle();

    expect(find.text('돌아볼 기간'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
  });
}
