import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'data/check_in_reminder.dart';
import 'data/providers.dart';
import 'data/settings_repository.dart';
import 'domain/domain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 첫 화면(온보딩/달력)을 정하려면 목표 수면시간이 필요하다. 라우터가 동기로
  // 판단하도록 여기서 한 번 읽어 넣는다 (initialSleepTargetProvider).
  final store = SharedPrefsKeyValueStore();
  final settings = SettingsRepository(store);
  SleepTarget? target;
  try {
    target = await settings.loadTarget();
  } on StorageException {
    // 읽지 못하면 온보딩부터 다시 — 기록은 DB에 그대로 남는다.
    target = null;
  }

  final reminder = LocalCheckInReminder();
  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      initialSleepTargetProvider.overrideWithValue(target),
      checkInReminderProvider.overrideWithValue(reminder),
    ],
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const SleepLogApp()),
  );

  // 생각 돌아보기 알림을 누르면 오늘 그 시간대 체크인으로 간다.
  void openCheckIn(CheckInSlot slot) {
    container
        .read(routerProvider)
        .pushNamed(
          Routes.checkIn,
          pathParameters: {
            'date': container.read(todayProvider).toIso(),
            'slot': slot.name,
          },
        );
  }

  reminder.onTap = openCheckIn;
  try {
    // 기기가 재부팅됐거나 앱이 업데이트돼도 일정이 남도록 시작할 때마다 다시 잡는다.
    await reminder.apply(await settings.loadCheckInSettings());
    final launchSlot = await reminder.takeLaunchSlot();
    if (launchSlot != null) {
      openCheckIn(launchSlot);
    }
  } on Object catch (error) {
    // 알림이 안 돼도 앱은 써야 한다.
    debugPrint('sleep_log: 알림을 준비하지 못했다: $error');
  }
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
      // 한국어 앱이다. 날짜·시간 선택기와 기본 버튼 문구도 한국어로.
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
