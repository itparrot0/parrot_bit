import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/data/settings_repository.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/screens/settings_screen.dart';

import '../support/in_memory_diary_repository.dart';

void main() {
  const today = DiaryDate(2026, 11, 5);

  late ProviderContainer container;
  late InMemoryKeyValueStore store;
  late InMemoryDiaryRepository diary;

  Future<void> pumpScreen(
    WidgetTester tester, {
    Map<String, Object>? stored,
  }) async {
    store = InMemoryKeyValueStore(stored);
    diary = InMemoryDiaryRepository([
      DiaryEntry(date: today, tags: {DefaultMoodTags.calm}),
      DiaryEntry(date: today.previous, tags: {DefaultMoodTags.down}),
    ]);
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        diaryRepositoryProvider.overrideWithValue(diary),
        initialSleepTargetProvider.overrideWithValue(
          SleepTarget(const Duration(hours: 7)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('목표 수면시간', () {
    testWidgets('현재 목표를 보여 준다', (tester) async {
      await pumpScreen(tester);

      expect(find.text('7시간'), findsOneWidget);
    });

    testWidgets('바꾸기 전에 지난 z가 다시 계산된다고 알리고, 저장하면 반영된다', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('목표 수면시간'));
      await tester.pumpAndSettle();
      expect(find.textContaining('다시 계산돼요'), findsOneWidget);

      await tester.tap(find.byTooltip('30분 늘리기'));
      await tester.pump();
      await tester.tap(find.byTooltip('30분 늘리기'));
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      final expected = SleepTarget(const Duration(hours: 8));
      expect(container.read(sleepTargetProvider), expected);
      expect(await SettingsRepository(store).loadTarget(), expected);
      expect(find.text('8시간'), findsOneWidget);
    });

    testWidgets('취소하면 바뀌지 않는다', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('목표 수면시간'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('30분 줄이기'));
      await tester.pump();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(
        container.read(sleepTargetProvider),
        SleepTarget(const Duration(hours: 7)),
      );
      expect(await SettingsRepository(store).loadTarget(), isNull);
    });
  });

  group('마음 돌봄 안내', () {
    SwitchListTile toggle(WidgetTester tester) =>
        tester.widget(find.byType(SwitchListTile));

    testWidgets('기본은 켜짐', (tester) async {
      await pumpScreen(tester);

      expect(toggle(tester).value, isTrue);
    });

    testWidgets('끄면 저장되고, 다시 열어도 꺼져 있다', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(toggle(tester).value, isFalse);
      expect(
        await SettingsRepository(store).loadSafetyNoticeEnabled(),
        isFalse,
      );
    });

    testWidgets('저장된 값이 꺼짐이면 꺼진 채로 열린다', (tester) async {
      await pumpScreen(
        tester,
        stored: {SettingsRepository.safetyNoticeKey: false},
      );

      expect(toggle(tester).value, isFalse);
    });
  });

  group('모든 기록 지우기', () {
    testWidgets('확인하면 기록이 모두 지워지고 목표는 남는다', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('모든 기록 지우기'));
      await tester.pumpAndSettle();
      expect(find.text('모든 기록을 지울까요?'), findsOneWidget);

      await tester.tap(find.text('모두 지우기'));
      await tester.pumpAndSettle();

      expect(await diary.find(today), isNull);
      expect(await diary.find(today.previous), isNull);
      expect(find.text('모든 기록을 지웠어요.'), findsOneWidget);
      expect(
        container.read(sleepTargetProvider),
        SleepTarget(const Duration(hours: 7)),
      );
    });

    testWidgets('취소하면 아무것도 지우지 않는다', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('모든 기록 지우기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(await diary.find(today), isNotNull);
    });
  });
}
