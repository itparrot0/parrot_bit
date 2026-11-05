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
