import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/data/settings_repository.dart';
import 'package:sleep_log/domain/domain.dart';

import '../support/in_memory_diary_repository.dart';
import '../support/safety_fixtures.dart';

void main() {
  const today = DiaryDate(2026, 11, 5);

  ProviderContainer containerWith({
    required InMemoryKeyValueStore store,
    required List<DiaryEntry> entries,
  }) {
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        diaryRepositoryProvider.overrideWithValue(
          InMemoryDiaryRepository(entries),
        ),
        todayProvider.overrideWithValue(today),
        initialSleepTargetProvider.overrideWithValue(
          SleepTarget(const Duration(hours: 7)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // 2주 동안 8일, 잘 자고도(7.5h) 부정 태그 → 2단계.
  final supportCase = negativeDays(today, days: 8, hours: 7.5);
  // 최근 3일, 짧게 자고(5h) 부정 태그 → 1단계.
  final restCase = negativeDays(today, days: 3, hours: 5);

  test('조건이 맞으면 띄우고, 띄운 날을 저장한다', () async {
    final store = InMemoryKeyValueStore();
    final container = containerWith(store: store, entries: supportCase);

    expect(
      await container.read(safetyBannerProvider.future),
      SafetyAdvice.supportContact,
    );
    expect(
      await SettingsRepository(
        store,
      ).loadLastShown(SafetyAdvice.supportContact),
      today,
    );
  });

  test('1단계도 같은 방식으로 뜬다', () async {
    final container = containerWith(
      store: InMemoryKeyValueStore(),
      entries: restCase,
    );

    expect(
      await container.read(safetyBannerProvider.future),
      SafetyAdvice.restSuggestion,
    );
  });

  test('다음에 앱을 다시 열어도 14일 안에는 띄우지 않는다', () async {
    final store = InMemoryKeyValueStore();
    final first = containerWith(store: store, entries: supportCase);
    await first.read(safetyBannerProvider.future);

    final reopened = containerWith(store: store, entries: supportCase);
    expect(await reopened.read(safetyBannerProvider.future), SafetyAdvice.none);
  });

  test('설정에서 꺼져 있으면 띄우지 않고, 노출로 세지도 않는다', () async {
    final store = InMemoryKeyValueStore({
      SettingsRepository.safetyNoticeKey: false,
    });
    final container = containerWith(store: store, entries: supportCase);

    expect(
      await container.read(safetyBannerProvider.future),
      SafetyAdvice.none,
    );
    expect(
      await SettingsRepository(
        store,
      ).loadLastShown(SafetyAdvice.supportContact),
      isNull,
    );
  });

  test('켜져 있다가 끄면 바로 사라진다', () async {
    final container = containerWith(
      store: InMemoryKeyValueStore(),
      entries: supportCase,
    );
    expect(
      await container.read(safetyBannerProvider.future),
      SafetyAdvice.supportContact,
    );

    await container.read(safetyNoticeEnabledProvider.notifier).set(false);

    expect(
      await container.read(safetyBannerProvider.future),
      SafetyAdvice.none,
    );
  });

  test('닫으면 이번 실행 동안 사라진다', () async {
    final container = containerWith(
      store: InMemoryKeyValueStore(),
      entries: supportCase,
    );
    await container.read(safetyBannerProvider.future);

    container.read(safetyBannerProvider.notifier).dismiss();

    expect(container.read(safetyBannerProvider).value, SafetyAdvice.none);
  });

  test('앱이 열린 뒤 저장한 기록에는 바로 반응하지 않는다', () async {
    final repository = InMemoryDiaryRepository();
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        diaryRepositoryProvider.overrideWithValue(repository),
        todayProvider.overrideWithValue(today),
      ],
    );
    addTearDown(container.dispose);
    // 달력이 기록을 계속 보고 있는 상태를 흉내 낸다.
    container.listen(diaryEntriesProvider, (_, _) {});
    expect(
      await container.read(safetyBannerProvider.future),
      SafetyAdvice.none,
    );

    for (final entry in supportCase) {
      await repository.save(entry);
    }
    await Future<void>.delayed(Duration.zero);

    expect(container.read(diaryEntriesProvider).value, hasLength(8));
    expect(
      await container.read(safetyBannerProvider.future),
      SafetyAdvice.none,
      reason: '방금 적은 감정에 앱이 즉각 반응하면 참견처럼 느껴진다 (PRD §9-2)',
    );
  });
}
