// 화면 흐름 (2026-11-04 요청):
//  - 홈에는 스테이지 시작 버튼만 있다 (지난 스테이지 메뉴 없음)
//  - 완성하면 골드를 무작위로 받고, 완성 화면에는 [홈] [다음 스테이지]만 있다
import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/domain/solver.dart';
import 'package:bloom_wave/economy/gold.dart';
import 'package:bloom_wave/save/save_store.dart';
import 'package:bloom_wave/screens/game_screen.dart';
import 'package:bloom_wave/ui/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

GameScreenState game(WidgetTester tester) =>
    tester.state<GameScreenState>(find.byType(GameScreen));

/// 시작 안내(튜토리얼·난이도 경고)를 모두 닫는다
Future<void> dismissIntros(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    final ok = [
      byKey('btn-tutorial-ok'),
      byKey('btn-difficulty-ok'),
    ].where((f) => f.evaluate().isNotEmpty);
    if (ok.isEmpty) return;
    await tester.tap(ok.first);
    await advance(tester, 400);
  }
}

/// 솔버 해법대로 끝까지 둔다 (맨 앞 물방울 동그라미를 실제로 탭)
Future<void> playToClear(WidgetTester tester) async {
  final g = game(tester);
  final c = g.controller;
  final sol = solve(c.level, c.options);
  expect(sol.solvable, isTrue);
  for (final a in sol.solution) {
    switch (a) {
      case Deploy(:final lane):
        await tester.tap(byKey('lane-front-$lane'));
        await tester.pump();
        if (!c.options.realtime) {
          while (c.step() != null) {}
        }
      case Tick():
        expect(c.step(), isNotNull);
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(c.status, Status.cleared);
}

void main() {
  testWidgets('홈: 스테이지 시작 버튼 하나와 골드만 보인다', (tester) async {
    await phone(tester);
    final h = Harness();
    await tester.pumpWidget(h.app);
    await tester.pump();
    expect(find.byType(PillButton), findsOneWidget);
    expect(byKey('btn-start'), findsOneWidget);
    expect(find.text('스테이지 1 시작'), findsOneWidget);
    expect(
      find.descendant(of: byKey('home-gold'), matching: find.text('0')),
      findsOneWidget,
    );
    for (final gone in ['스테이지', '정원', '설정', '이어하기']) {
      expect(find.text(gone), findsNothing);
    }
  });

  testWidgets('1스테이지 완성: 골드 지급, 완성 화면은 [홈] [다음 스테이지]만, 다음으로 가면 광고 후 2스테이지', (
    tester,
  ) async {
    await phone(tester);
    final h = Harness();
    await tester.pumpWidget(h.app);
    await tester.pump();
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    // 1스테이지 시작 안내: 튜토리얼 → 길게 누르기
    expect(byKey('overlay-tutorial-wave'), findsOneWidget);
    await dismissIntros(tester);
    await playToClear(tester);
    await advance(tester, 2200);
    await advance(tester, 400);

    expect(byKey('overlay-clear'), findsOneWidget);
    expect(byKey('full-bloom'), findsOneWidget);
    final buttons = find.descendant(
      of: byKey('overlay-clear'),
      matching: find.byType(PillButton),
    );
    expect(buttons, findsNWidgets(2));
    expect(byKey('btn-clear-home'), findsOneWidget);
    expect(byKey('btn-next'), findsOneWidget);
    expect(find.text('다시 하기'), findsNothing);

    final gold = h.save.data.gold;
    expect(gold, inInclusiveRange(goldReward.min, goldReward.max));
    expect(find.text('+$gold'), findsOneWidget);
    expect(h.save.data.cleared, contains(pack[0].id));
    expect(h.save.data.unlocked, 2);
    expect(h.sfx.played, contains('coin'));

    await tester.tap(byKey('btn-next'));
    await advance(tester, 400);
    expect(h.ads.shown, 1);
    expect(find.text('스테이지 2'), findsOneWidget);
    // 저장도 남았다
    final again = SaveStore(h.store);
    expect((await again.load()).gold, gold);
  });

  testWidgets('완성 후 [홈]: 광고 후 홈, 버튼은 다음 스테이지를 시작하고 골드가 늘어 있다', (tester) async {
    await phone(tester);
    final h = Harness();
    await tester.pumpWidget(h.app);
    await tester.pump();
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    await dismissIntros(tester);
    await playToClear(tester);
    await advance(tester, 2200);
    await advance(tester, 400);
    await tester.tap(byKey('btn-clear-home'));
    await advance(tester, 400);
    expect(h.ads.shown, 1);
    expect(find.text('스테이지 2 시작'), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('home-gold'),
        matching: find.text('${h.save.data.gold}'),
      ),
      findsOneWidget,
    );
    expect(h.save.data.gold, greaterThan(0));
  });

  testWidgets('광고 제거 구매자는 완성 후 광고 없이 이동', (tester) async {
    await phone(tester);
    final h = Harness(data: SaveData(noAds: true));
    await tester.pumpWidget(h.app);
    await tester.pump();
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    await dismissIntros(tester);
    await playToClear(tester);
    await advance(tester, 2200);
    await advance(tester, 400);
    await tester.tap(byKey('btn-next'));
    await advance(tester, 400);
    expect(h.ads.shown, 0);
    expect(find.text('스테이지 2'), findsOneWidget);
  });

  testWidgets('마지막 스테이지 완성 화면은 [홈]만, 홈은 "모든 스테이지 완성"', (tester) async {
    await phone(tester);
    final levels = pack.sublist(0, 2);
    final h = Harness(
      levels: levels,
      data: SaveData(unlocked: 2, cleared: {levels[0].id}),
    );
    await tester.pumpWidget(h.app);
    await tester.pump();
    expect(find.text('스테이지 2 시작'), findsOneWidget);
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    await dismissIntros(tester);
    await playToClear(tester);
    await advance(tester, 2200);
    await advance(tester, 400);
    expect(byKey('btn-next'), findsNothing);
    expect(byKey('btn-clear-home'), findsOneWidget);
    await tester.tap(byKey('btn-clear-home'));
    await advance(tester, 400);
    expect(byKey('all-cleared'), findsOneWidget);
    expect(byKey('btn-start'), findsNothing);
  });

  testWidgets('실패: [다시 하기] [홈], 골드 없음, 다시 하기는 처음 상태', (tester) async {
    await phone(tester);
    // 1행 5칸 a a b a a. b 물방울 4개를 먼저 넣으면 슬롯이 모두 쓸 수 없는 물방울로 찬다
    Drop d(int c, int a) => Drop(c, a);
    final lv = Level(
      id: 'fail',
      width: 5,
      height: 1,
      palette: const ['#e5484d', '#3e9bdb'],
      cells: const [0, 0, 1, 0, 0],
      starts: const [0],
      lanes: [
        [d(1, 1), d(1, 1)],
        [d(1, 1), d(1, 1)],
        [d(0, 4)],
      ],
    );
    final h = Harness(
      levels: [
        lv,
        lv.copyWith(id: 'fail-2'),
      ],
    );
    await tester.pumpWidget(h.app);
    await tester.pump();
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    await dismissIntros(tester);
    final g = game(tester);
    for (final lane in [0, 0, 1, 1]) {
      await tester.tap(byKey('lane-front-$lane'));
      await tester.pump();
    }
    expect(g.controller.status, Status.failed);
    await advance(tester, 1000);
    expect(byKey('overlay-fail'), findsOneWidget);
    expect(byKey('btn-retry'), findsOneWidget);
    expect(byKey('btn-fail-home'), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('overlay-fail'),
        matching: find.byType(PillButton),
      ),
      findsNWidgets(2),
    );
    expect(h.save.data.gold, 0);
    expect(h.ads.shown, 0);
    await tester.tap(byKey('btn-retry'));
    await advance(tester, 400);
    expect(byKey('overlay-fail'), findsNothing);
    expect(g.controller.status, Status.playing);
    expect(g.controller.queueLeft, 5);
    // 실패 후 홈: 같은 스테이지가 그대로 남아 있다
    for (final lane in [0, 0, 1, 1]) {
      await tester.tap(byKey('lane-front-$lane'));
      await tester.pump();
    }
    await advance(tester, 1000);
    await tester.tap(byKey('btn-fail-home'));
    await advance(tester, 400);
    expect(find.text('스테이지 1 시작'), findsOneWidget);
  });

  testWidgets('일시정지 → 설정: 언어를 바꾸면 화면 문구가 바뀐다, 닫으면 일시정지로', (tester) async {
    await phone(tester);
    final h = Harness();
    await tester.pumpWidget(h.app);
    await tester.pump();
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    await dismissIntros(tester);
    await tester.tap(byKey('btn-pause'));
    await advance(tester, 400);
    expect(byKey('overlay-pause'), findsOneWidget);
    await tester.tap(byKey('btn-settings'));
    await advance(tester, 400);
    expect(byKey('overlay-settings'), findsOneWidget);
    await tester.tap(byKey('seg-en'));
    await advance(tester, 400);
    expect(h.save.data.settings.lang, 'en');
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(byKey('toggle-sound'));
    await advance(tester, 400);
    expect(h.save.data.settings.sound, isFalse);
    await tester.tap(byKey('btn-settings-close'));
    await advance(tester, 400);
    expect(byKey('overlay-pause'), findsOneWidget);
    await tester.tap(byKey('btn-pause-home'));
    await advance(tester, 400);
    expect(find.text('Start Stage 1'), findsOneWidget);
  });

  testWidgets('물방울을 누르고 있으면 그 색 미리보기, 밖으로 빼면 취소(넣지 않음), 안에서 떼면 넣기', (
    tester,
  ) async {
    await phone(tester);
    final h = Harness();
    await tester.pumpWidget(h.app);
    await tester.pump();
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    await dismissIntros(tester);
    final g = game(tester);
    final front = g.controller.front(0)!;
    final center = tester.getCenter(byKey('lane-front-0'));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    expect(g.fxForTest.previewColor, front.color);
    await gesture.moveBy(const Offset(0, -300));
    await tester.pump();
    expect(g.fxForTest.previewColor, isNull);
    await gesture.up();
    await tester.pump();
    expect(g.controller.occupied, 0);

    await tester.tap(byKey('lane-front-0'));
    await tester.pump();
    expect(g.controller.occupied, 1);
  });

  testWidgets('어려운 스테이지는 시작 전에 난이도 경고창', (tester) async {
    await phone(tester);
    final n = pack.indexWhere((l) => l.meta?.difficulty == Difficulty.hard) + 1;
    expect(n, greaterThan(0));
    final h = Harness(
      data: SaveData(
        unlocked: n,
        cleared: {for (final l in pack.take(n - 1)) l.id},
      ),
    );
    await tester.pumpWidget(h.app);
    await tester.pump();
    expect(find.text('스테이지 $n 시작'), findsOneWidget);
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    expect(byKey('overlay-difficulty-hard'), findsOneWidget);
  });
}
