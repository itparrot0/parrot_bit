import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../screens/calendar_screen.dart';
import '../screens/check_in_screen.dart';
import '../screens/entry_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/report_screen.dart';
import '../screens/settings_screen.dart';

/// 라우트 이름. **docs/screen-flow/sleep_log.md의 화면 ID와 1:1로 대응시킨다.**
/// 한쪽만 바꾸지 않는다.
abstract final class Routes {
  static const onboarding = 'onboarding';
  static const calendar = 'calendar';
  static const entry = 'entry';
  static const report = 'report';
  static const settings = 'settings';
  static const checkIn = 'check_in';
}

/// 앱 라우터.
///
/// Provider로 두는 이유: `onboarding` 리다이렉트가 "목표 수면시간이 설정됐는가"
/// ([savedSleepTargetProvider])를 읽어야 한다 (docs/screen-flow/sleep_log.md §2).
final routerProvider = Provider<GoRouter>((ref) {
  // 라우터를 다시 만들면 내비게이션 스택이 날아가므로, 목표 설정 여부는
  // watch하지 않고 바뀔 때 redirect만 다시 돌게 한다.
  final hasTarget = ValueNotifier(ref.read(savedSleepTargetProvider) != null);
  ref
    ..listen(
      savedSleepTargetProvider,
      (_, next) => hasTarget.value = next != null,
    )
    ..onDispose(hasTarget.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: hasTarget,
    // 목표가 없으면 z 판정이 성립하지 않으므로 어디로 가든 온보딩으로 보낸다.
    // 리마인더 알림으로 entry에 직행해도 마찬가지다 (screen-flow §2, §4).
    // 정한 뒤에는 온보딩으로 돌아갈 수 없다 — 바꾸는 곳은 settings다.
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!hasTarget.value) {
        return atOnboarding ? null : '/onboarding';
      }
      return atOnboarding ? '/' : null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: Routes.calendar,
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      // 기록 대상 날짜를 경로에 담는다 (ISO-8601 yyyy-MM-dd).
      GoRoute(
        path: '/entry/:date',
        name: Routes.entry,
        builder: (context, state) =>
            EntryScreen(date: state.pathParameters['date']!),
      ),
      // 생각 돌아보기. 알림을 누르면 그 날짜·시간대로 바로 온다 (PRD §3-3).
      GoRoute(
        path: '/check-in/:date/:slot',
        name: Routes.checkIn,
        builder: (context, state) => CheckInScreen(
          date: state.pathParameters['date']!,
          slot: state.pathParameters['slot']!,
        ),
      ),
      GoRoute(
        path: '/report',
        name: Routes.report,
        builder: (context, state) => const ReportScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      // TODO(sleep_log): /settings/tags (tag_palette) — 커스텀 태그, v1.x 범위.
    ],
  );
});
