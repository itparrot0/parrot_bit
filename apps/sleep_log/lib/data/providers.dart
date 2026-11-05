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

/// 판정에 쓸 목표 수면시간. 설정 전이면 기본값(7시간)이다.
///
/// 목표를 바꾸는 화면(settings)은 저장 후 이 Provider를 무효화해야 한다 —
/// 그래야 지난 달력의 z 표시가 다시 계산된다.
final sleepTargetProvider = FutureProvider<SleepTarget>((ref) async {
  final target = await ref.watch(settingsRepositoryProvider).loadTarget();
  return target ?? SleepTarget.defaultTarget;
});
