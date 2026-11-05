// 플레이 화면 UI 개편 (2026-11-04): 힌트·하단 재시작·뒤로 버튼 없음, x2(남은 시간), 아이템 칸 3종, 아이템 튜토리얼
import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/economy/items.dart';
import 'package:bloom_wave/game/game_painter.dart' show previewLit;
import 'package:bloom_wave/save/save_store.dart';
import 'package:bloom_wave/screens/game_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

GameScreenState game(WidgetTester tester) =>
    tester.state<GameScreenState>(find.byType(GameScreen));

/// n 스테이지부터 시작하는 저장 (앞 스테이지는 완성)
SaveData at(int n) =>
    SaveData(unlocked: n, cleared: {for (final l in pack.take(n - 1)) l.id});

Future<void> start(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(h.app);
  await tester.pump();
  await tester.tap(byKey('btn-start'));
  await advance(tester, 400);
}

Future<void> closeTutorials(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    final ok = [
      byKey('btn-tutorial-ok'),
      byKey('btn-difficulty-ok'),
    ].where((f) => f.evaluate().isNotEmpty);
    if (ok.isEmpty) return;
    await tester.tap(ok.first);
    await advance(tester, 300);
  }
}

String itemCount(WidgetTester tester, ItemKind k) =>
    (tester.widget<Text>(byKey('item-count-${k.name}'))).data!;

void main() {
  test('색 미리보기는 그 색의 발아 칸만 (씨앗·개화·다른 색은 흐리게)', () {
    expect(previewLit(2, 2, sprout), isTrue);
    expect(previewLit(2, 2, seed), isFalse);
    expect(previewLit(2, 2, bloom), isFalse);
    expect(previewLit(2, 1, sprout), isFalse);
    expect(previewLit(null, 2, sprout), isFalse);
  });

  testWidgets('플레이 화면: 힌트·하단 재시작·뒤로 버튼 없음, x2 와 아이템 칸 3개, 잠긴 아이템은 해금 스테이지 표시', (
    tester,
  ) async {
    await phone(tester);
    final h = Harness();
    await start(tester, h);
    await closeTutorials(tester);
    expect(byKey('btn-hint'), findsNothing);
    expect(byKey('btn-restart'), findsNothing);
    expect(byKey('btn-back'), findsNothing);
    expect(byKey('btn-x2'), findsOneWidget);
    for (final k in ItemKind.values) {
      expect(byKey('item-${k.name}'), findsOneWidget);
    }
    expect(find.text('8스테이지'), findsOneWidget);
    expect(find.text('12스테이지'), findsOneWidget);
    expect(find.text('17스테이지'), findsOneWidget);
    // 잠긴 아이템은 눌러도 아무 일 없음
    await tester.tap(byKey('item-slot'));
    await advance(tester, 100);
    expect(game(tester).controller.state.slots.length, 4);
    // 재시작은 일시정지 메뉴에
    await tester.tap(byKey('btn-pause'));
    await advance(tester, 300);
    expect(byKey('btn-pause-restart'), findsOneWidget);
  });

  testWidgets('x2: 기본은 느린 속도, 켜면 빠르게, 웨이브가 진행될 때만 남은 시간이 준다', (tester) async {
    await phone(tester);
    final h = Harness(data: at(3));
    await start(tester, h);
    await closeTutorials(tester);
    final g = game(tester);
    expect(g.controller.tickMs, baseTickMs);
    expect(find.text('10:00'), findsOneWidget);
    await tester.tap(byKey('btn-x2'));
    await advance(tester, 100);
    expect(h.save.data.x2On, isTrue);
    expect(g.controller.tickMs, x2TickMs);
    // 웨이브가 없으면 줄지 않는다
    await advance(tester, 1000);
    expect(h.save.data.x2Ms, x2InitialMs);
    // 퍼질 수 있는 물방울을 넣어 웨이브를 시작 (수동 틱이라 웨이브가 계속 진행 중)
    final s = g.controller.state;
    final lane = [
      for (var i = 0; i < s.lanes.length; i++) i,
    ].firstWhere((i) => g.controller.usable(i));
    g.tap(lane);
    await advance(tester, 1000);
    expect(
      h.save.data.x2Ms,
      inInclusiveRange(x2InitialMs - 1100, x2InitialMs - 900),
    );
    expect(find.text('9:59'), findsOneWidget);
    // 일시정지 중에는 줄지 않는다
    final paused = h.save.data.x2Ms;
    await tester.tap(byKey('btn-pause'));
    await advance(tester, 1000);
    expect(h.save.data.x2Ms, paused);
    await tester.tap(byKey('btn-resume'));
    await advance(tester, 100);
    // 끄면 느린 속도
    await tester.tap(byKey('btn-x2'));
    await advance(tester, 100);
    expect(h.save.data.x2On, isFalse);
    expect(g.controller.tickMs, baseTickMs);
    // 시간이 다 되면 저절로 꺼지고 다시 켤 수 없다
    h.save.data.x2Ms = 300;
    await tester.tap(byKey('btn-x2'));
    await advance(tester, 600);
    expect(h.save.data.x2Ms, 0);
    expect(h.save.data.x2On, isFalse);
    expect(g.controller.tickMs, baseTickMs);
    await tester.tap(byKey('btn-x2'));
    await advance(tester, 100);
    expect(h.save.data.x2On, isFalse);
  });

  testWidgets('8스테이지: 슬롯 추가 해금(3개) → 한 번 써야 진행 → 2개 남음', (tester) async {
    await phone(tester);
    final h = Harness(data: at(8));
    await start(tester, h);
    expect(byKey('overlay-item-slot'), findsOneWidget);
    expect(h.save.data.itemCount(ItemKind.slot), itemStartCount);
    await tester.tap(byKey('btn-item-tutorial-ok'));
    await advance(tester, 300);
    final g = game(tester);
    expect(byKey('item-prompt'), findsOneWidget);
    // 아이템을 쓰기 전에는 대기열이 잠겨 있다
    await tester.tap(byKey('lane-front-0'));
    await advance(tester, 100);
    expect(g.controller.occupied, 0);
    await tester.tap(byKey('item-slot'));
    await advance(tester, 300);
    expect(g.controller.state.slots.length, 5);
    expect(h.save.data.itemCount(ItemKind.slot), 2);
    expect(itemCount(tester, ItemKind.slot), '2');
    expect(h.save.data.itemTutorialDone, contains(ItemKind.slot));
    expect(byKey('item-prompt'), findsNothing);
    await tester.tap(byKey('lane-front-0'));
    await advance(tester, 100);
    expect(g.controller.occupied, 1);
    // 다시 들어와도 다시 주지 않고 튜토리얼도 없다
    await tester.pumpWidget(const SizedBox());
    final again = Harness(data: h.save.data);
    await start(tester, again);
    expect(byKey('overlay-item-slot'), findsNothing);
    expect(again.save.data.itemCount(ItemKind.slot), 2);
  });

  testWidgets('12스테이지: 섞기 해금 → 한 번 써야 진행 → 2개 남음, 물방울 구성은 그대로', (tester) async {
    await phone(tester);
    final h = Harness(data: at(12));
    await start(tester, h);
    expect(byKey('overlay-item-shuffle'), findsOneWidget);
    await tester.tap(byKey('btn-item-tutorial-ok'));
    await advance(tester, 300);
    final g = game(tester);
    String key(List<List<Drop>> ls) => ([
      for (final l in ls) ...l,
    ].map((d) => '${d.color}:${d.amount}').toList()..sort()).join(',');
    final before = key(g.controller.state.lanes);
    await tester.tap(byKey('item-shuffle'));
    await advance(tester, 300);
    expect(key(g.controller.state.lanes), before);
    expect(h.save.data.itemCount(ItemKind.shuffle), 2);
    expect(h.save.data.itemTutorialDone, contains(ItemKind.shuffle));
    expect(byKey('item-prompt'), findsNothing);
  });

  testWidgets('17스테이지: 즉시 개화 해금 → 묶인 물방울을 넣어 주고 → 슬롯을 골라 개화 → 2개 남음', (
    tester,
  ) async {
    await phone(tester);
    final h = Harness(data: at(17));
    await start(tester, h);
    expect(byKey('overlay-item-bloom'), findsOneWidget);
    await tester.tap(byKey('btn-item-tutorial-ok'));
    await advance(tester, 500);
    final g = game(tester);
    final stuck = g.controller.stuck;
    expect(stuck, hasLength(1)); // 튜토리얼이 퍼질 수 없는 물방울을 슬롯에 넣어 줬다
    final slot = stuck.single;
    expect(byKey('item-prompt'), findsOneWidget);
    await tester.tap(byKey('item-bloom'));
    await advance(tester, 100);
    expect(g.picking, isTrue);
    expect(find.text('쓸 수 없는 물방울이 든 슬롯을 고르세요'), findsOneWidget);
    await tester.tap(byKey('slot-$slot'));
    await advance(tester, 300);
    expect(g.controller.state.slots[slot], isNull);
    expect(h.save.data.itemCount(ItemKind.bloom), 2);
    expect(h.save.data.itemTutorialDone, contains(ItemKind.bloom));
    expect(g.picking, isFalse);
  });

  testWidgets('아이템이 없으면 쓸 수 없다 (개수 0)', (tester) async {
    await phone(tester);
    final data = at(20)
      ..itemsUnlocked.addAll(ItemKind.values)
      ..itemTutorialDone.addAll(ItemKind.values);
    final h = Harness(data: data);
    await start(tester, h);
    await closeTutorials(tester);
    await tester.tap(byKey('item-slot'));
    await advance(tester, 100);
    expect(game(tester).controller.state.slots.length, 4);
    expect(game(tester).fxForTest.msg, '남은 아이템이 없어요');
  });

  testWidgets('시스템 뒤로 가기는 일시정지 메뉴 (홈은 거기서)', (tester) async {
    await phone(tester);
    final h = Harness(data: at(6));
    await start(tester, h);
    await closeTutorials(tester);
    await tester.binding.handlePopRoute();
    await advance(tester, 300);
    expect(byKey('overlay-pause'), findsOneWidget);
    await tester.tap(byKey('btn-pause-home'));
    await advance(tester, 400);
    expect(byKey('btn-start'), findsOneWidget);
  });

  testWidgets('다 쓴 줄은 영역째 사라지고 남은 줄이 가운데 정렬된다', (tester) async {
    await phone(tester);
    Drop d(int c, int a) => Drop(c, a);
    // 1행 5칸 a a b a a. 0번 줄은 물방울 1개뿐
    final lv = Level(
      id: 'lanes',
      width: 5,
      height: 1,
      palette: const ['#e5484d', '#3e9bdb'],
      cells: const [0, 0, 1, 0, 0],
      starts: const [0],
      lanes: [
        [d(0, 2)],
        [d(1, 1), d(0, 1)],
        [d(0, 1)],
      ],
    );
    final h = Harness(
      levels: [
        lv,
        lv.copyWith(id: 'lanes-2'),
      ],
    );
    await start(tester, h);
    await closeTutorials(tester);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    double cx(int li) => tester.getCenter(byKey('lane-front-$li')).dx;
    expect([0, 1, 2].map((i) => byKey('lane-front-$i').evaluate().length), [
      1,
      1,
      1,
    ]);
    expect(cx(1), closeTo(screen.width / 2, 1)); // 3줄일 때 가운데는 1번
    await tester.tap(byKey('lane-front-0'));
    await advance(tester, 500);
    expect(byKey('lane-front-0'), findsNothing); // 다 쓴 줄은 없어졌다
    expect((cx(1) + cx(2)) / 2, closeTo(screen.width / 2, 1)); // 남은 2줄이 가운데
    final g = game(tester);
    expect(
      g.fxForTest.laneX(1),
      closeTo(g.fxForTest.layout.laneXs[1], 1),
    ); // 그리는 자리도 따라왔다
  });
}
