import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proto_idle_visit/main.dart';

void main() {
  var now = DateTime.utc(2026, 11, 4, 9);

  Future<void> boot(WidgetTester tester, KeyValueStore store) async {
    // 휴대폰 세로 화면 — 마당의 4자리가 한 화면에 다 보인다.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdleVisitApp(store: store, clock: () => now, tick: null),
    );
    await tester.pumpAndSettle();
  }

  /// 첫 빈 자리에 [itemName]을 놓는다.
  Future<void> placeFirstEmpty(WidgetTester tester, String itemName) async {
    await tester.tap(find.text('놓기').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(itemName),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => now = DateTime.utc(2026, 11, 4, 9));

  testWidgets('장소 칩과 빈 자리가 보인다', (tester) async {
    await boot(tester, InMemoryKeyValueStore());

    expect(find.text('🌳 마당'), findsOneWidget);
    expect(find.text('🪟 창가'), findsOneWidget);
    expect(find.text('놓기'), findsNWidgets(4));
  });

  testWidgets('빈 자리에 아이템을 놓으면 손님을 기다린다', (tester) async {
    await boot(tester, InMemoryKeyValueStore());

    await placeFirstEmpty(tester, '해바라기씨');

    expect(find.text('놓기'), findsNWidgets(3));
    expect(find.text('누가 올까…'), findsOneWidget);
  });

  testWidgets('빨리 감기로 시간이 흐르면 손님이 오고 도감에 오른다', (tester) async {
    await boot(tester, InMemoryKeyValueStore());

    for (var i = 0; i < 4; i++) {
      await placeFirstEmpty(tester, '물그릇');
    }
    // 물그릇은 4종이 좋아한다. 4자리 × 30분이면 사실상 반드시 온다.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('+30분'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('분 더'), findsWidgets);

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    expect(find.textContaining('/ 8마리'), findsOneWidget);
    expect(find.text('0 / 8마리'), findsNothing);
  });

  testWidgets('다시 열면 놓아 둔 아이템이 남아 있다', (tester) async {
    final store = InMemoryKeyValueStore();
    await boot(tester, store);

    await placeFirstEmpty(tester, '딸기');

    await tester.pumpWidget(const SizedBox());
    await boot(tester, store);

    expect(find.text('🍓'), findsOneWidget);
    expect(find.text('놓기'), findsNWidgets(3));
  });

  testWidgets('도감은 처음에 모두 물음표다', (tester) async {
    await boot(tester, InMemoryKeyValueStore());

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();

    expect(find.text('0 / 8마리'), findsOneWidget);
    expect(find.text('???'), findsNWidgets(8));
  });
}
