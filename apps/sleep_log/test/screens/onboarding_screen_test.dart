import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/screens/onboarding_screen.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpScreen(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
  }

  String shownTarget(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('targetStepper.value'))).data!;

  IconButton button(WidgetTester tester, String tooltip) => tester.widget(
    find.ancestor(
      of: find.byTooltip(tooltip),
      matching: find.byType(IconButton),
    ),
  );

  testWidgets('기본값 7시간으로 열리고 30분씩 바뀐다', (tester) async {
    await pumpScreen(tester);
    expect(shownTarget(tester), '7시간');

    await tester.tap(find.byTooltip('30분 늘리기'));
    await tester.pump();
    expect(shownTarget(tester), '7시간 30분');

    await tester.tap(find.byTooltip('30분 줄이기'));
    await tester.pump();
    await tester.tap(find.byTooltip('30분 줄이기'));
    await tester.pump();
    expect(shownTarget(tester), '6시간 30분');
  });

  testWidgets('허용 범위(4~12시간) 끝에서 버튼이 꺼진다', (tester) async {
    await pumpScreen(tester);

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('30분 줄이기'));
      await tester.pump();
    }
    expect(shownTarget(tester), '4시간');
    expect(button(tester, '30분 줄이기').onPressed, isNull);

    for (var i = 0; i < 16; i++) {
      await tester.tap(find.byTooltip('30분 늘리기'));
      await tester.pump();
    }
    expect(shownTarget(tester), '12시간');
    expect(button(tester, '30분 늘리기').onPressed, isNull);
  });

  testWidgets('범례가 고른 목표의 경계를 보여 준다', (tester) async {
    await pumpScreen(tester);

    // 목표 7시간: z <5.5h / zZ 5.5~6.5h / zzZ 6.5~8.5h / zzZZ >8.5h (PRD §4)
    expect(find.text('5시간 30분 미만'), findsOneWidget);
    expect(find.text('5시간 30분 ~ 6시간 30분'), findsOneWidget);
    expect(find.text('6시간 30분 ~ 8시간 30분'), findsOneWidget);
    expect(find.text('8시간 30분 초과'), findsOneWidget);

    await tester.tap(find.byTooltip('30분 늘리기'));
    await tester.pump();
    expect(find.text('6시간 미만'), findsOneWidget);
  });

  testWidgets('시작하기를 누르면 목표가 저장된다', (tester) async {
    await pumpScreen(tester);
    expect(container.read(savedSleepTargetProvider), isNull);

    await tester.tap(find.byTooltip('30분 줄이기'));
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    await tester.pump();

    final expected = SleepTarget(const Duration(hours: 6, minutes: 30));
    expect(container.read(savedSleepTargetProvider), expected);
    expect(container.read(sleepTargetProvider), expected);
  });
}
