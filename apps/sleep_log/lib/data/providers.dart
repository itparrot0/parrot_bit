import 'package:core_storage/core_storage.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/domain.dart';
import 'database.dart';
import 'diary_repository.dart';
import 'drift_diary_repository.dart';
import 'settings_repository.dart';

// 저장 계층 Provider. 테스트는 appDatabaseProvider와 keyValueStoreProvider를
// 메모리 구현으로 바꿔 끼운다.

/// 앱 DB. 기기 안의 `sleep_log.sqlite` 파일 하나다.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(driftDatabase(name: 'sleep_log'));
  ref.onDispose(database.close);
  return database;
});

final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SharedPrefsKeyValueStore(),
);

final diaryRepositoryProvider = Provider<DiaryRepository>(
  (ref) => DriftDiaryRepository(ref.watch(appDatabaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(keyValueStoreProvider)),
);

/// 오늘 날짜. 위젯이 시계를 직접 읽지 않게 여기 한 곳에서 읽는다 — 테스트가
/// 날짜를 고정할 수 있어야 한다.
///
/// 앱이 열린 채 자정을 넘기면 갱신되지 않는다. 아침 1회 사용이 기본이라
/// (PRD §2) 지금은 두고, 필요해지면 자정 타이머로 무효화한다.
final todayProvider = Provider<DiaryDate>(
  (ref) => DiaryDate.fromDateTime(DateTime.now()),
);

/// 모든 기록 (날짜 오름차순). 저장·삭제하면 자동으로 새 값이 온다.
final diaryEntriesProvider = StreamProvider<List<DiaryEntry>>(
  (ref) => ref.watch(diaryRepositoryProvider).watchAll(),
);

/// 앱 시작 때 저장소에서 읽은 목표 수면시간. 설정한 적이 없으면 null.
///
/// `main`이 `runApp` 전에 읽어 덮어쓴다 — 라우터가 첫 화면(온보딩/달력)을
/// 동기로 정할 수 있어야 해서다. 비동기로 두면 달력이 잠깐 보였다가 온보딩으로
/// 튄다.
final initialSleepTargetProvider = Provider<SleepTarget?>((ref) => null);

/// 사용자가 정한 목표 수면시간. 아직 정하지 않았으면 null — 라우터가 이걸 보고
/// 온보딩으로 보낸다 (docs/screen-flow/sleep_log.md §2).
final savedSleepTargetProvider =
    NotifierProvider<SavedSleepTarget, SleepTarget?>(SavedSleepTarget.new);

class SavedSleepTarget extends Notifier<SleepTarget?> {
  @override
  SleepTarget? build() => ref.watch(initialSleepTargetProvider);

  /// 저장하고 바로 반영한다. 달력·기록 화면의 z 판정이 따라서 다시 계산된다.
  Future<void> set(SleepTarget target) async {
    await ref.read(settingsRepositoryProvider).saveTarget(target);
    state = target;
  }
}

/// 판정에 쓸 목표 수면시간. 정하기 전이면 기본값(7시간)이다.
final sleepTargetProvider = Provider<SleepTarget>(
  (ref) => ref.watch(savedSleepTargetProvider) ?? SleepTarget.defaultTarget,
);

/// 안전 안내 배너를 띄울지 (PRD §9-2, 기본 켜짐). 설정에서 끌 수 있다.
final safetyNoticeEnabledProvider =
    AsyncNotifierProvider<SafetyNoticeEnabled, bool>(SafetyNoticeEnabled.new);

class SafetyNoticeEnabled extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.watch(settingsRepositoryProvider).loadSafetyNoticeEnabled();

  Future<void> set(bool enabled) async {
    await ref.read(settingsRepositoryProvider).saveSafetyNoticeEnabled(enabled);
    state = AsyncData(enabled);
  }
}

/// 달력 상단에 지금 띄울 안전 안내 (PRD §9-2). 띄울 게 없으면 [SafetyAdvice.none].
///
/// **앱을 열 때 한 번 정한다.** 기록 목록은 watch하지 않고 읽기만 한다 — 기록을
/// 저장한 직후 방금 적은 감정에 앱이 바로 반응하면 참견처럼 느껴진다. 그래서
/// 오늘 저장한 기록은 다음에 앱을 열 때 반영된다. 설정에서 끄면 즉시 사라진다.
///
/// 띄우기로 정한 순간 노출 날짜를 저장한다 — 닫든 말든 14일 쉬는 기간이 시작된다.
final safetyBannerProvider = AsyncNotifierProvider<SafetyBanner, SafetyAdvice>(
  SafetyBanner.new,
);

class SafetyBanner extends AsyncNotifier<SafetyAdvice> {
  @override
  Future<SafetyAdvice> build() async {
    final enabled = await ref.watch(safetyNoticeEnabledProvider.future);
    if (!enabled) {
      return SafetyAdvice.none;
    }
    // 저장소에서 직접 한 번 읽는다. diaryEntriesProvider를 읽으면, 아무도 그걸
    // 보고 있지 않을 때(Riverpod 3는 듣는 이 없는 Provider를 멈춘다) 끝나지 않는다.
    final entries = await ref.read(diaryRepositoryProvider).watchAll().first;
    final today = ref.read(todayProvider);
    final settings = ref.read(settingsRepositoryProvider);

    final advice = SafetyCheck.evaluate(
      entries: entries,
      target: ref.read(sleepTargetProvider),
      today: today,
    );
    final decision = SafetyNoticePolicy.decide(
      advice: advice,
      today: today,
      lastRestShown: await settings.loadLastShown(SafetyAdvice.restSuggestion),
      lastSupportShown: await settings.loadLastShown(
        SafetyAdvice.supportContact,
      ),
    );
    if (decision != SafetyAdvice.none) {
      await settings.saveLastShown(decision, today);
    }
    return decision;
  }

  /// 사용자가 닫았다. 이번 실행 동안 다시 보이지 않는다.
  void dismiss() => state = const AsyncData(SafetyAdvice.none);
}
