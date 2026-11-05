// set 화면 흐름 (2026-11-05): 처음 나오는 스테이지에서 안내, 짝이 맨 앞이 아니면 안내만, 준비되면 한꺼번에 슬롯으로
import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/screens/game_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'flow_test.dart' show dismissIntros;

GameScreenState game(WidgetTester tester) =>
    tester.state<GameScreenState>(find.byType(GameScreen));

void main() {
  testWidgets('set: 첫 스테이지 안내 → 짝이 아직이면 못 넣고 안내, 준비되면 둘이 함께 들어간다', (
    tester,
  ) async {
    await phone(tester);
    final l = Level(
      id: 'set-ui',
      width: 6,
      height: 1,
      palette: const ['#e5484d', '#3e9bdb'],
      cells: const [0, 0, 0, 1, 1, 1],
      starts: const [0],
      lanes: [
        [Drop(0, 1), Drop(0, 2, set: 0)],
        [Drop(1, 3, set: 0)],
        [Drop(1, 1)],
      ],
    );
    final h = Harness(
      levels: [
        l,
        l.copyWith(id: 'set-ui-2'),
      ],
    );
    await tester.pumpWidget(h.app);
    await tester.pump();
    expect(h.services.firstSet, 1);
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    // 시작 안내 중에 set 안내가 있다
    var sawSets = false;
    for (var i = 0; i < 6; i++) {
      if (byKey('overlay-tutorial-sets').evaluate().isNotEmpty) {
        sawSets = true;
        expect(byKey('tutorial-sets-icon'), findsOneWidget);
      }
      if (byKey('btn-tutorial-ok').evaluate().isEmpty) break;
      await tester.tap(byKey('btn-tutorial-ok'));
      await advance(tester, 400);
    }
    expect(sawSets, isTrue);
    await dismissIntros(tester);
    final c = game(tester).controller;
    // 줄 1 맨 앞(set)은 짝(줄 0 두 번째)이 아직 맨 앞이 아니다
    await tester.tap(byKey('lane-front-1'));
    await tester.pump();
    expect(c.occupied, 0);
    await advance(tester, 100);
    expect(find.text('묶인 물방울이 모두 맨 위에 와야 해요'), findsNothing); // 캔버스 글자라 위젯이 아님
    expect(game(tester).fx.msg, '묶인 물방울이 모두 맨 위에 와야 해요');
    // 줄 0 을 하나 넣으면 짝이 맨 앞 → 줄 1 을 누르면 둘 다 들어간다
    await tester.tap(byKey('lane-front-0'));
    await tester.pump();
    expect(c.occupied, 1);
    await tester.tap(byKey('lane-front-1'));
    await tester.pump();
    expect(c.occupied, 3);
    expect(c.state.lanes[0], isEmpty);
    expect(c.state.lanes[1], isEmpty);
  });
}
