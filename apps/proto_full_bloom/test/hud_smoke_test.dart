import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proto_full_bloom/levels/handmade_levels.dart';
import 'package:proto_full_bloom/main.dart';

void main() {
  testWidgets('앱이 뜨고 레벨 칩·활성화 슬롯·레인이 보인다', (tester) async {
    await tester.pumpWidget(const GardenGrowApp());
    await tester.pump(const Duration(milliseconds: 32));

    for (final level in HandmadeLevels.all) {
      expect(find.text(level.name), findsOneWidget);
    }
    expect(find.text('활성화'), findsOneWidget);
    // 튜토리얼 레인: [x1, x4] / [x4] — 공개 2라서 전부 보인다.
    expect(find.text('×1'), findsOneWidget);
    expect(find.text('×4'), findsNWidgets(2));
  });

  testWidgets('진행 상황이 칸 수로 표시된다', (tester) async {
    await tester.pumpWidget(const GardenGrowApp());
    await tester.pump(const Duration(milliseconds: 32));

    expect(find.text('0 / 9칸'), findsOneWidget);
  });

  testWidgets('레인 앞을 누르면 보드가 피고 표시가 바뀐다', (tester) async {
    await tester.pumpWidget(const GardenGrowApp());
    await tester.pump(const Duration(milliseconds: 32));

    await tester.tap(find.text('×1'));
    await tester.pump(const Duration(milliseconds: 32));

    expect(find.text('1 / 9칸'), findsOneWidget);
  });

  testWidgets('되돌리기는 수를 둔 뒤에만 켜진다', (tester) async {
    await tester.pumpWidget(const GardenGrowApp());
    await tester.pump(const Duration(milliseconds: 32));

    IconButton undoButton() => tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.undo),
        matching: find.byType(IconButton),
      ),
    );

    expect(undoButton().onPressed, isNull);

    await tester.tap(find.text('×1'));
    await tester.pump(const Duration(milliseconds: 32));

    expect(undoButton().onPressed, isNotNull);
  });

  testWidgets('레벨을 바꾸면 그 레벨의 레인이 보인다', (tester) async {
    await tester.pumpWidget(const GardenGrowApp());
    await tester.pump(const Duration(milliseconds: 32));

    await tester.tap(find.text('십자'));
    await tester.pump(const Duration(milliseconds: 32));

    // 십자 레인: [x2, x4] / [x3].
    expect(find.text('0 / 9칸'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('×4'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
  });
}
