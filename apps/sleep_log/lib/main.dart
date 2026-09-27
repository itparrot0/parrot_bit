import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';

void main() {
  runApp(const ProviderScope(child: SleepLogApp()));
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
