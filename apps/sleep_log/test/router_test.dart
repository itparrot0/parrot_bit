import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_log/app/router.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/main.dart';

void main() {
  testWidgets('앱을 띄우면 달력 화면으로 진입한다', (tester) async {
    // 실제 DB·설정 저장소는 기기 플러그인이 필요하므로 기록만 비워 끼운다.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryEntriesProvider.overrideWith((ref) => Stream.value(const [])),
          sleepTargetProvider.overrideWith(
            (ref) async => SleepTarget.defaultTarget,
          ),
        ],
        child: const SleepLogApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('슬립로그'), findsOneWidget);
  });

  test('라우트 이름이 화면흐름 문서의 화면 ID와 일치한다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final configuration = container.read(routerProvider).configuration;
    final names = configuration.routes
        .whereType<GoRoute>()
        .map((route) => route.name)
        .toSet();

    expect(names, {
      Routes.calendar,
      Routes.onboarding,
      Routes.entry,
      Routes.report,
      Routes.settings,
    });
  });

  testWidgets('entry 라우트는 경로의 날짜를 화면에 전달한다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    router.goNamed(Routes.entry, pathParameters: {'date': '2026-09-27'});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026-09-27'), findsOneWidget);
  });
}
