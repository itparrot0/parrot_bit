import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/calendar_screen.dart';
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
}

/// 앱 라우터.
///
/// Provider로 두는 이유: `onboarding` 리다이렉트가 "목표 수면시간이 설정됐는가"를
/// 읽어야 하고(docs/screen-flow/sleep_log.md §2), 그 값은 core_storage를 감싼
/// Provider가 갖게 된다. 라우터가 그 Provider를 읽을 수 있어야 한다.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
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
