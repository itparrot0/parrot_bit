import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proto_full_bloom/levels/handmade_levels.dart';
import 'package:proto_full_bloom/main.dart';

void main() {
  testWidgets('앱이 뜨고 레벨 칩과 슬롯이 보인다', (tester) async {
    await tester.pumpWidget(const ProtoFullBloomApp());
    await tester.pump(const Duration(milliseconds: 32));

    for (final level in HandmadeLevels.all) {
      expect(find.text(level.name), findsOneWidget);
    }
    // 첫 레벨(튜토리얼)의 대기열은 x1, x4, x4 — 슬롯 3개에 다 올라간다.
    expect(find.text('×1'), findsOneWidget);
    expect(find.text('×4'), findsNWidgets(2));
    expect(find.text('대기열 비어 있음'), findsOneWidget);
  });

  testWidgets('진행 상황이 칸 수로 표시된다', (tester) async {
    await tester.pumpWidget(const ProtoFullBloomApp());
    await tester.pump(const Duration(milliseconds: 32));

    expect(find.text('0 / 9칸'), findsOneWidget);
  });

  testWidgets('슬롯을 누르면 보드가 피고 표시가 바뀐다', (tester) async {
    await tester.pumpWidget(const ProtoFullBloomApp());
    await tester.pump(const Duration(milliseconds: 32));

    await tester.tap(find.text('×1'));
    await tester.pump(const Duration(milliseconds: 32));

    expect(find.text('1 / 9칸'), findsOneWidget);
  });

  testWidgets('되돌리기는 수를 쓴 뒤에만 켜진다', (tester) async {
    await tester.pumpWidget(const ProtoFullBloomApp());
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

  testWidgets('레벨을 바꾸면 그 레벨로 다시 시작한다', (tester) async {
    await tester.pumpWidget(const ProtoFullBloomApp());
    await tester.pump(const Duration(milliseconds: 32));

    await tester.tap(find.text('십자'));
    await tester.pump(const Duration(milliseconds: 32));

    // 십자는 9칸이지만 대기열이 x2, x4, x3이다.
    expect(find.text('0 / 9칸'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
  });

  testWidgets('쓸 수 없는 슬롯에 안내가 붙는다', (tester) async {
    await tester.pumpWidget(const ProtoFullBloomApp());
    await tester.pump(const Duration(milliseconds: 32));

    await tester.tap(find.text('십자'));
    await tester.pump(const Duration(milliseconds: 32));

    // 시작 지점이 빨강이라 파랑 x4는 첫 수에 쓸 수 없다 (PRD §3.4).
    expect(find.text('쓸 곳 없음'), findsOneWidget);
  });
}
