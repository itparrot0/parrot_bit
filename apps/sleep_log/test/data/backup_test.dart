import 'dart:convert';
import 'dart:math';

import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/backup/backup_codec.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/data/settings_repository.dart';
import 'package:sleep_log/domain/domain.dart';

import '../support/fake_check_in_reminder.dart';
import '../support/in_memory_check_in_repository.dart';
import '../support/in_memory_diary_repository.dart';

void main() {
  const fast = 1000; // 테스트용 반복 횟수
  const day = DiaryDate(2026, 11, 5);

  final sample = BackupContents(
    createdAt: DateTime.utc(2026, 11, 5, 9),
    entries: [
      DiaryEntry(
        date: day,
        sleep: SleepSession(
          bedTime: ClockTime(23, 30),
          wakeTime: ClockTime(7, 0),
        ),
        tags: {DefaultMoodTags.calm, DefaultMoodTags.caffeine},
        rested: RestFeeling.soso,
      ),
      DiaryEntry(date: day.previous, tags: {DefaultMoodTags.down}),
    ],
    checkIns: [
      ThoughtCheckIn(
        date: day,
        slot: CheckInSlot.afternoon,
        pace: MindPace.busy,
        senses: SenseShift.none,
        thought: '다 망할 것 같다',
        reframe: '지난번에도 해냈어',
      ),
    ],
    target: SleepTarget(const Duration(hours: 7, minutes: 30)),
    safetyNoticeEnabled: false,
    checkInSettings: CheckInSettings(
      enabled: true,
      morningTime: ClockTime(9, 30),
      afternoonTime: ClockTime(18, 0),
    ),
  );

  group('BackupCodec', () {
    test('같은 비밀번호로 풀면 내용이 그대로다', () async {
      final bytes = await BackupCodec.encode(
        sample,
        'secret-pw',
        iterations: fast,
      );
      final restored = await BackupCodec.decode(bytes, 'secret-pw');

      expect(jsonEncode(restored.toJson()), jsonEncode(sample.toJson()));
      expect(restored.entries.first.rested, RestFeeling.soso);
      expect(restored.checkIns.single.reframe, '지난번에도 해냈어');
      expect(restored.target, sample.target);
    });

    test('파일에는 기록 내용이 평문으로 남지 않는다', () async {
      final bytes = await BackupCodec.encode(
        sample,
        'secret-pw',
        iterations: fast,
      );
      final text = utf8.decode(bytes);

      expect(text, isNot(contains('망할')));
      expect(text, isNot(contains('caffeine')));
      expect(text, contains(BackupCodec.format));
    });

    test('비밀번호가 틀리면 BackupPasswordException', () async {
      final bytes = await BackupCodec.encode(
        sample,
        'secret-pw',
        iterations: fast,
      );

      await expectLater(
        BackupCodec.decode(bytes, 'wrong-pw'),
        throwsA(isA<BackupPasswordException>()),
      );
    });

    test('봉투 머리를 바꿔치기하면 풀리지 않는다', () async {
      final bytes = await BackupCodec.encode(
        sample,
        'secret-pw',
        iterations: fast,
      );
      final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      // 반복 횟수를 줄여 추측을 쉽게 하려는 조작 — AAD 덕분에 실패해야 한다.
      (envelope['kdf']! as Map<String, Object?>)['iterations'] = fast ~/ 2;

      await expectLater(
        BackupCodec.decode(utf8.encode(jsonEncode(envelope)), 'secret-pw'),
        throwsA(isA<BackupPasswordException>()),
      );
    });

    test('백업 파일이 아니거나 새 판이면 BackupFormatException', () async {
      await expectLater(
        BackupCodec.decode(utf8.encode('hello'), 'pw'),
        throwsA(isA<BackupFormatException>()),
      );
      await expectLater(
        BackupCodec.decode(utf8.encode(jsonEncode({'format': 'other'})), 'pw'),
        throwsA(isA<BackupFormatException>()),
      );
      await expectLater(
        BackupCodec.decode(
          utf8.encode(
            jsonEncode({'format': BackupCodec.format, 'version': 99}),
          ),
          'pw',
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains('업데이트'),
          ),
        ),
      );
    });

    test('같은 내용도 만들 때마다 다른 파일이 된다 (소금·nonce)', () async {
      final a = await BackupCodec.encode(
        sample,
        'pw-123456',
        iterations: fast,
        random: Random(1),
      );
      final b = await BackupCodec.encode(
        sample,
        'pw-123456',
        iterations: fast,
        random: Random(2),
      );
      expect(a, isNot(b));
    });

    test('읽을 수 없는 줄과 모르는 태그는 건너뛴다', () {
      final contents = BackupContents.fromJson({
        'entries': [
          {'date': '2026-02-30'},
          {
            'date': '2026-11-05',
            'tags': ['calm', 'custom_9'],
            'bed': 10,
            'wake': 10,
          },
        ],
        'checkIns': [
          {'date': '2026-11-05', 'slot': 'evening'},
        ],
        'settings': {'targetMinutes': 30},
      });

      expect(contents.entries.single.tags, {DefaultMoodTags.calm});
      expect(contents.entries.single.sleep, isNull);
      expect(contents.checkIns, isEmpty);
      expect(contents.target, isNull);
      expect(contents.safetyNoticeEnabled, isTrue);
    });
  });

  group('BackupService', () {
    ProviderContainer device({
      List<DiaryEntry> entries = const [],
      List<ThoughtCheckIn> checkIns = const [],
      SleepTarget? target,
      InMemoryKeyValueStore? store,
      FakeCheckInReminder? reminder,
    }) {
      final container = ProviderContainer(
        overrides: [
          diaryRepositoryProvider.overrideWithValue(
            InMemoryDiaryRepository(entries),
          ),
          checkInRepositoryProvider.overrideWithValue(
            InMemoryCheckInRepository(checkIns),
          ),
          keyValueStoreProvider.overrideWithValue(
            store ?? InMemoryKeyValueStore(),
          ),
          checkInReminderProvider.overrideWithValue(
            reminder ?? FakeCheckInReminder(),
          ),
          initialSleepTargetProvider.overrideWithValue(target),
          backupIterationsProvider.overrideWithValue(fast),
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 5, 9)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('이전 기기에서 만든 백업을 새 기기로 옮긴다', () async {
      final oldPhone = device(
        entries: sample.entries,
        checkIns: sample.checkIns,
        target: sample.target,
        store: InMemoryKeyValueStore({
          SettingsRepository.safetyNoticeKey: false,
          SettingsRepository.checkInEnabledKey: true,
        }),
      );
      final bytes = await oldPhone
          .read(backupServiceProvider)
          .export('pw-123456');

      final reminder = FakeCheckInReminder();
      final newStore = InMemoryKeyValueStore();
      final newPhone = device(store: newStore, reminder: reminder);
      final contents = await BackupCodec.decode(bytes, 'pw-123456');
      final summary = await newPhone
          .read(backupServiceProvider)
          .restore(contents);

      expect(summary, (entries: 2, checkIns: 1));
      expect((await newPhone.read(diaryRepositoryProvider).find(day))!.tags, {
        DefaultMoodTags.calm,
        DefaultMoodTags.caffeine,
      });
      expect(
        await newPhone
            .read(checkInRepositoryProvider)
            .find(day, CheckInSlot.afternoon),
        sample.checkIns.single,
      );
      expect(newPhone.read(savedSleepTargetProvider), sample.target);
      expect(
        await SettingsRepository(newStore).loadSafetyNoticeEnabled(),
        isFalse,
      );
      expect(reminder.calls.single.settings.enabled, isTrue);
      expect(
        reminder.calls.single.askPermission,
        isFalse,
        reason: '가져오기 중에는 권한을 묻지 않는다',
      );
    });

    test('합치기 — 같은 날은 백업으로 바뀌고, 백업에 없는 날은 남는다', () async {
      final newPhone = device(
        target: SleepTarget.defaultTarget,
        entries: [
          DiaryEntry(date: day, tags: {DefaultMoodTags.joyful}),
          DiaryEntry(date: day.addDays(1), tags: {DefaultMoodTags.proud}),
        ],
      );

      await newPhone.read(backupServiceProvider).restore(sample);

      final diary = newPhone.read(diaryRepositoryProvider);
      expect((await diary.find(day))!.tags, contains(DefaultMoodTags.calm));
      expect((await diary.find(day.addDays(1)))!.tags, {DefaultMoodTags.proud});
    });
  });
}
