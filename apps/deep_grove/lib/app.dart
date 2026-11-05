import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/board_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shop_screen.dart';

/// 화면 3개 (화면 흐름 §1). 나머지는 보드 위 시트다.
final GoRouter groveRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'board',
      builder: (context, state) => const BoardScreen(),
      routes: [
        GoRoute(
          path: 'shop',
          name: 'shop',
          builder: (context, state) => const ShopScreen(),
        ),
        GoRoute(
          path: 'settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

class GroveApp extends StatelessWidget {
  const GroveApp({super.key, this.router});

  /// 테스트에서 새 라우터를 넣는다 (전역 라우터는 테스트 사이에 상태가 남는다).
  final GoRouter? router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Deep Grove',
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ThemeMode.dark,
    routerConfig: router ?? groveRouter,
  );
}
