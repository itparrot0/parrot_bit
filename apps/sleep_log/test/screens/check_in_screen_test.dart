import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/screens/check_in_screen.dart';

import '../support/in_memory_check_in_repository.dart';

void main() {
  const today = DiaryDate(2026, 11, 5);
  late InMemoryCheckInRepository repository;

  setUp(() => repository = InMemoryCheckInRepository());

  Future<void> open(
    WidgetTester tester, {
    DiaryDate date = today,
    CheckInSlot slot = CheckInSlot.morning,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          checkInRepositoryProvider.overrideWithValue(repository),
          todayProvider.overrideWithValue(today),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CheckInScreen(date: date.toIso(), slot: slot.name),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  testWidgets('시간대가 제목에 보이고, 다른 눈으로 보기는 생각을 적어야 나온다', (tester) async {
    await open(tester, slot: CheckInSlot.afternoon);

    expect(find.text('오후의 생각 돌아보기'), findsOneWidget);
    expect(find.byKey(const Key('checkIn.reframe')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('checkIn.thought')),
      '다 망할 것 같다',
    );
    await tester.pump();

    expect(find.byKey(const Key('checkIn.reframe')), findsOneWidget);
  });

  testWidgets('고른 답과 적은 생각이 저장되고 화면이 닫힌다', (tester) async {
    await open(tester);

    await tester.tap(find.text(MindPace.busy.label));
    await tester.tap(find.text(SenseShift.some.label));
    await tester.enterText(
      find.byKey(const Key('checkIn.thought')),
      '다 망할 것 같다',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('checkIn.reframe')),
      '지난번에도 괜찮았잖아',
    );
    await tester.tap(find.text('남겨 두기'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(
      await repository.find(today, CheckInSlot.morning),
      ThoughtCheckIn(
        date: today,
        slot: CheckInSlot.morning,
        pace: MindPace.busy,
        senses: SenseShift.some,
        thought: '다 망할 것 같다',
        reframe: '지난번에도 괜찮았잖아',
      ),
    );
  });

  testWidgets('고른 칩을 다시 누르면 답하지 않은 것으로 돌아간다', (tester) async {
    await open(tester);

    await tester.tap(find.text(MindPace.slow.label));
    await tester.pump();
    await tester.tap(find.text(MindPace.slow.label));
    await tester.pump();
    await tester.tap(find.text(SenseShift.none.label));
    await tester.tap(find.text('남겨 두기'));
    await tester.pumpAndSettle();

    final saved = await repository.find(today, CheckInSlot.morning);
    expect(saved!.pace, isNull);
    expect(saved.senses, SenseShift.none);
  });

  testWidgets('이미 남긴 체크인은 그 내용으로 열린다', (tester) async {
    await repository.save(
      ThoughtCheckIn(
        date: today,
        slot: CheckInSlot.morning,
        pace: MindPace.usual,
        thought: '괜찮은 하루',
      ),
    );
    await open(tester);

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, MindPace.usual.label),
    );
    expect(chip.selected, isTrue);
    expect(find.text('괜찮은 하루'), findsOneWidget);
  });

  testWidgets('미래 날짜·모르는 시간대는 열지 않는다', (tester) async {
    await open(tester, date: today.addDays(1));

    expect(find.text('이 날은 돌아볼 수 없어요.'), findsOneWidget);
  });
}
