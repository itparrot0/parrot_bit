import 'dart:convert';
import 'dart:typed_data';

import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/app/router.dart';
import 'package:sleep_log/data/backup/backup_codec.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/main.dart';

import '../support/fake_backup_file_gateway.dart';
import '../support/fake_check_in_reminder.dart';
import '../support/in_memory_check_in_repository.dart';
import '../support/in_memory_diary_repository.dart';

void main() {
  const today = DiaryDate(2026, 11, 5);
  late FakeBackupFileGateway gateway;
  late InMemoryDiaryRepository diary;

  ProviderContainer app({
    SleepTarget? target,
    List<DiaryEntry> entries = const [],
  }) {
    gateway = FakeBackupFileGateway();
    diary = InMemoryDiaryRepository(entries);
    final container = ProviderContainer(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(diary),
        checkInRepositoryProvider.overrideWithValue(
          InMemoryCheckInRepository(),
        ),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        checkInReminderProvider.overrideWithValue(FakeCheckInReminder()),
        todayProvider.overrideWithValue(today),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 5, 9)),
        initialSleepTargetProvider.overrideWithValue(target),
        backupIterationsProvider.overrideWithValue(1000),
        backupFileGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> openBackup(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    container.read(routerProvider).goNamed(Routes.backup);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SleepLogApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterPassword(
    WidgetTester tester,
    String password, {
    String? again,
  }) async {
    await tester.enterText(find.byKey(const Key('backup.password')), password);
    if (again != null) {
      await tester.enterText(
        find.byKey(const Key('backup.passwordAgain')),
        again,
      );
    }
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
  }

  testWidgets('백업 파일을 만들면 공유 시트로 잠긴 파일이 나간다', (tester) async {
    final container = app(
      target: SleepTarget.defaultTarget,
      entries: [
        DiaryEntry(date: today, tags: {DefaultMoodTags.calm}),
      ],
    );
    await openBackup(tester, container);

    await tester.tap(find.byKey(const Key('backup.export')));
    await tester.pumpAndSettle();
    await enterPassword(tester, 'pw-123456', again: 'pw-123456');

    expect(gateway.sharedName, 'sleeplog-2026-11-05.sleeplog');
    final contents = await BackupCodec.decode(gateway.shared!, 'pw-123456');
    expect(contents.entries.single.tags, {DefaultMoodTags.calm});
    expect(find.textContaining('비밀번호를 꼭 기억'), findsOneWidget);
  });

  testWidgets('비밀번호가 짧거나 두 번이 다르면 만들지 않는다', (tester) async {
    await openBackup(tester, app(target: SleepTarget.defaultTarget));

    await tester.tap(find.byKey(const Key('backup.export')));
    await tester.pumpAndSettle();
    await enterPassword(tester, '123', again: '123');
    expect(find.text('6자 이상으로 정해 주세요.'), findsOneWidget);

    await enterPassword(tester, 'pw-123456', again: 'pw-654321');
    expect(find.text('두 비밀번호가 달라요.'), findsOneWidget);
    expect(gateway.shared, isNull);
  });

  testWidgets('새 폰의 온보딩에서 백업을 가져오면 달력으로 간다', (tester) async {
    final bytes = await BackupCodec.encode(
      BackupContents(
        createdAt: DateTime.utc(2026, 11, 1),
        entries: [
          DiaryEntry(date: today.previous, tags: {DefaultMoodTags.joyful}),
        ],
        checkIns: const [],
        target: SleepTarget(const Duration(hours: 8)),
        safetyNoticeEnabled: true,
        checkInSettings: CheckInSettings(),
      ),
      'pw-123456',
      iterations: 1000,
    );
    final container = app(); // 목표 없음 = 온보딩 상태
    container.read(routerProvider).goNamed(Routes.onboarding);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SleepLogApp(),
      ),
    );
    await tester.pumpAndSettle();
    gateway.toPick = bytes;

    await tester.tap(find.text('이전 기기의 백업 가져오기'));
    await tester.pumpAndSettle();
    expect(find.text('백업과 기기 이전'), findsOneWidget, reason: '목표 없이도 열린다');

    await tester.tap(find.byKey(const Key('backup.import')));
    await tester.pumpAndSettle();
    await enterPassword(tester, 'pw-123456');
    expect(find.text('이 백업을 가져올까요?'), findsOneWidget);
    expect(find.textContaining('기록 1일'), findsOneWidget);

    await tester.tap(find.text('가져오기'));
    await tester.pumpAndSettle();

    expect(container.read(routerProvider).state.matchedLocation, '/');
    expect(
      container.read(sleepTargetProvider),
      SleepTarget(const Duration(hours: 8)),
    );
    expect(await diary.find(today.previous), isNotNull);
  });

  testWidgets('비밀번호가 틀리면 안내하고 아무것도 바꾸지 않는다', (tester) async {
    final container = app(target: SleepTarget.defaultTarget);
    final bytes = await BackupCodec.encode(
      BackupContents(
        createdAt: DateTime.utc(2026, 11, 1),
        entries: [
          DiaryEntry(date: today, tags: {DefaultMoodTags.joyful}),
        ],
        checkIns: const [],
        target: null,
        safetyNoticeEnabled: true,
        checkInSettings: CheckInSettings(),
      ),
      'pw-123456',
      iterations: 1000,
    );
    await openBackup(tester, container);
    gateway.toPick = bytes;

    await tester.tap(find.byKey(const Key('backup.import')));
    await tester.pumpAndSettle();
    await enterPassword(tester, 'wrong-password');

    expect(find.textContaining('비밀번호가 맞지 않아요'), findsOneWidget);
    expect(await diary.find(today), isNull);
  });

  testWidgets('백업 파일이 아니면 그렇다고 알려 준다', (tester) async {
    final container = app(target: SleepTarget.defaultTarget);
    await openBackup(tester, container);
    gateway.toPick = Uint8List.fromList(utf8.encode('not a backup'));

    await tester.tap(find.byKey(const Key('backup.import')));
    await tester.pumpAndSettle();
    await enterPassword(tester, 'whatever');

    expect(find.text('슬립로그 백업 파일이 아니에요.'), findsOneWidget);
  });
}
