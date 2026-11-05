import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'data/providers.dart';
import 'data/settings_repository.dart';
import 'domain/domain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 첫 화면(온보딩/달력)을 정하려면 목표 수면시간이 필요하다. 라우터가 동기로
  // 판단하도록 여기서 한 번 읽어 넣는다 (initialSleepTargetProvider).
  final store = SharedPrefsKeyValueStore();
  SleepTarget? target;
  try {
    target = await SettingsRepository(store).loadTarget();
  } on StorageException {
    // 읽지 못하면 온보딩부터 다시 — 기록은 DB에 그대로 남는다.
    target = null;
  }

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        initialSleepTargetProvider.overrideWithValue(target),
      ],
      child: const SleepLogApp(),
    ),
  );
}

/// 슬립로그 앱 루트.
///
/// 게임이 아니므로 상태는 전부 Riverpod가 들고, 화면 전환은 go_router가
/// 담당한다 (docs/03-architecture.md §3).
class SleepLogApp extends ConsumerWidget {
  const SleepLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '슬립로그',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
