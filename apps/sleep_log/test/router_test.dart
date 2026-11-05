import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_log/app/router.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/main.dart';

import 'support/in_memory_diary_repository.dart';

void main() {
  const today = DiaryDate(2026, 11, 5);

  /// 기기 플러그인(DB 파일·shared_preferences) 대신 메모리 구현을 끼운 앱.
  ProviderContainer appContainer({SleepTarget? savedTarget}) {
    final container = ProviderContainer(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(InMemoryDiaryRepository()),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        todayProvider.overrideWithValue(today),
        initialSleepTargetProvider.overrideWithValue(savedTarget),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpApp(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SleepLogApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String location(ProviderContainer container) =>
      container.read(routerProvider).state.matchedLocation;

  test('라우트 이름이 화면흐름 문서의 화면 ID와 일치한다', () {
    final container = appContainer();

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

  group('온보딩 리다이렉트 (screen-flow §2)', () {
    testWidgets('목표를 정하지 않았으면 온보딩으로 시작한다', (tester) async {
      final container = appContainer();
      await pumpApp(tester, container);

      expect(location(container), '/onboarding');
      expect(find.text('나에게 맞는 수면시간'), findsOneWidget);
    });

    testWidgets('목표가 있으면 달력으로 시작한다', (tester) async {
      final container = appContainer(savedTarget: SleepTarget.defaultTarget);
      await pumpApp(tester, container);

      expect(location(container), '/');
      expect(find.text('슬립로그'), findsOneWidget);
    });

    testWidgets('온보딩에서 시작하면 저장되고 달력으로 간다', (tester) async {
      final container = appContainer();
      await pumpApp(tester, container);

      await tester.tap(find.byTooltip('30분 늘리기'));
      await tester.pump();
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();

      expect(location(container), '/');
      final saved = SleepTarget(const Duration(hours: 7, minutes: 30));
      expect(container.read(savedSleepTargetProvider), saved);
      expect(
        await container.read(settingsRepositoryProvider).loadTarget(),
        saved,
        reason: '다음 실행에도 남아야 한다',
      );
    });

    testWidgets('목표 없이 entry로 직행해도 온보딩으로 보낸다', (tester) async {
      final container = appContainer();
      container
          .read(routerProvider)
          .goNamed(Routes.entry, pathParameters: {'date': today.toIso()});
      await pumpApp(tester, container);

      expect(location(container), '/onboarding');
    });

    testWidgets('목표를 정한 뒤에는 온보딩으로 돌아가지 않는다', (tester) async {
      final container = appContainer(savedTarget: SleepTarget.defaultTarget);
      await pumpApp(tester, container);

      container.read(routerProvider).goNamed(Routes.onboarding);
      await tester.pumpAndSettle();

      expect(location(container), '/');
    });
  });

  testWidgets('entry 라우트는 경로의 날짜를 화면에 전달한다', (tester) async {
    final container = appContainer(savedTarget: SleepTarget.defaultTarget);
    container
        .read(routerProvider)
        .goNamed(Routes.entry, pathParameters: {'date': '2026-09-27'});
    await pumpApp(tester, container);

    expect(find.text('9월 27일 (일)'), findsOneWidget);
  });
}
