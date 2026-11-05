import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/data/settings_repository.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/screens/settings_screen.dart';

import '../support/fake_check_in_reminder.dart';
import '../support/fake_phone_dialer.dart';
import '../support/in_memory_check_in_repository.dart';
import '../support/in_memory_diary_repository.dart';

void main() {
  const today = DiaryDate(2026, 11, 5);

  late ProviderContainer container;
  late InMemoryKeyValueStore store;
  late InMemoryDiaryRepository diary;
  late InMemoryCheckInRepository checkIns;
  late FakeCheckInReminder reminder;
  late FakePhoneDialer dialer;

  Future<void> pumpScreen(
    WidgetTester tester, {
    Map<String, Object>? stored,
    bool permissionGranted = true,
  }) async {
    // 항목이 많아 기본 800x600에서는 아래쪽이 화면 밖이다.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    reminder = FakeCheckInReminder(permissionGranted: permissionGranted);
    dialer = FakePhoneDialer();
    store = InMemoryKeyValueStore(stored);
    diary = InMemoryDiaryRepository([
      DiaryEntry(date: today, tags: {DefaultMoodTags.calm}),
      DiaryEntry(date: today.previous, tags: {DefaultMoodTags.down}),
    ]);
    checkIns = InMemoryCheckInRepository([
      ThoughtCheckIn(
        date: today,
        slot: CheckInSlot.morning,
        pace: MindPace.busy,
      ),
    ]);
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        diaryRepositoryProvider.overrideWithValue(diary),
        checkInRepositoryProvider.overrideWithValue(checkIns),
        checkInReminderProvider.overrideWithValue(reminder),
        phoneDialerProvider.overrideWithValue(dialer),
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
        tester.widget(find.byKey(const Key('settings.safetyNotice')));

    testWidgets('기본은 켜짐', (tester) async {
      await pumpScreen(tester);

      expect(toggle(tester).value, isTrue);
    });

    testWidgets('끄면 저장되고, 다시 열어도 꺼져 있다', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('settings.safetyNotice')));
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
      expect(await checkIns.find(today, CheckInSlot.morning), isNull);
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

  group('생각 돌아보기', () {
    SwitchListTile toggle(WidgetTester tester) =>
        tester.widget(find.byKey(const Key('settings.checkIn')));

    testWidgets('기본은 꺼짐이고 알림 시각은 숨겨져 있다', (tester) async {
      await pumpScreen(tester);

      expect(toggle(tester).value, isFalse);
      expect(find.text('오전 알림'), findsNothing);
    });

    testWidgets('켜면 저장되고, 권한을 물으며 알림이 잡힌다', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('settings.checkIn')));
      await tester.pumpAndSettle();

      expect(toggle(tester).value, isTrue);
      expect(find.text('오전 알림'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('17:00'), findsOneWidget);
      expect(reminder.calls.single.askPermission, isTrue);
      expect(reminder.calls.single.settings.enabled, isTrue);
      expect(
        (await SettingsRepository(store).loadCheckInSettings()).enabled,
        isTrue,
      );
    });

    testWidgets('알림 권한을 거절하면 안내하고 기능은 켜 둔다', (tester) async {
      await pumpScreen(tester, permissionGranted: false);

      await tester.tap(find.byKey(const Key('settings.checkIn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('알림이 허용되지 않았어요'), findsOneWidget);
      expect(toggle(tester).value, isTrue);
    });

    testWidgets('끄면 알림을 지운다 — 권한은 묻지 않는다', (tester) async {
      await pumpScreen(
        tester,
        stored: {SettingsRepository.checkInEnabledKey: true},
      );

      await tester.tap(find.byKey(const Key('settings.checkIn')));
      await tester.pumpAndSettle();

      expect(reminder.calls.single.settings.enabled, isFalse);
      expect(reminder.calls.single.askPermission, isFalse);
    });
  });

  testWidgets('설정에서 언제든 상담 번호로 전화를 열 수 있다', (tester) async {
    await pumpScreen(tester);

    expect(find.text('도움받을 수 있는 곳'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call.1577-0199')));
    await tester.pump();

    expect(dialer.dialed, ['1577-0199']);
  });
}
