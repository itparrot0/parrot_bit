// 햇빛(라이프) 화면 흐름 (2026-11-05)
import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/economy/lives.dart';
import 'package:bloom_wave/save/save_store.dart';
import 'package:bloom_wave/screens/game_screen.dart';
import 'package:bloom_wave/ui/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'flow_test.dart' show dismissIntros, finaleMs, playToClear;

GameScreenState game(WidgetTester tester) =>
    tester.state<GameScreenState>(find.byType(GameScreen));

/// 1행 5칸 a a b a a. b 물방울 4개를 먼저 넣으면 진다 (flow_test 와 같은 판)
Level failLevel(String id) => Level(
  id: id,
  width: 5,
  height: 1,
  palette: const ['#e5484d', '#3e9bdb'],
  cells: const [0, 0, 1, 0, 0],
  starts: const [0],
  lanes: [
    [Drop(1, 1), Drop(1, 1)],
    [Drop(1, 1), Drop(1, 1)],
    [Drop(0, 4)],
  ],
);

Future<void> lose(WidgetTester tester) async {
  for (final lane in [0, 0, 1, 1]) {
    await tester.tap(byKey('lane-front-$lane'));
    await tester.pump();
  }
  await advance(tester, 1000);
}

/// 햇빛 n개 저장
SaveData withLives(int n, DateTime now, {int gold = 0}) {
  final d = SaveData(gold: gold);
  for (var i = 0; i < maxLives - n; i++) {
    d.lives.spend(now);
  }
  return d;
}

bool enabled(WidgetTester tester, String key) =>
    tester.widget<PillButton>(byKey(key)).enabled;

void main() {
  testWidgets('홈에 햇빛 배지(개수·가득), 시작하면 1개를 쓰고 완성하면 돌려받는다', (tester) async {
    await phone(tester);
    final h = Harness();
    await tester.pumpWidget(h.app);
    await tester.pump();
    expect(byKey('home-lives'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.text('가득'), findsOneWidget);
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    expect(h.save.data.lives.count, 4);
    await dismissIntros(tester);
    await playToClear(tester);
    await advance(tester, finaleMs);
    expect(byKey('overlay-clear'), findsOneWidget);
    expect(h.save.data.lives.count, 5);
  });

  testWidgets('실패하면 1개가 줄고, 다시 하기는 1개를 더 쓴다. 다 쓰면 햇빛 패널', (tester) async {
    await phone(tester);
    final h = Harness(
      levels: [failLevel('f1'), failLevel('f2')],
      data: withLives(2, DateTime(2026, 11, 5, 12)),
    );
    await tester.pumpWidget(h.app);
    await tester.pump();
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    await dismissIntros(tester);
    expect(h.save.data.lives.count, 1);
    await lose(tester);
    expect(byKey('overlay-fail'), findsOneWidget);
    expect(find.text('남은 햇빛 1개'), findsOneWidget);
    await tester.tap(byKey('btn-retry'));
    await advance(tester, 400);
    expect(h.save.data.lives.count, 0);
    expect(game(tester).controller.status, Status.playing);
    await lose(tester);
    await tester.tap(byKey('btn-retry'));
    await advance(tester, 400);
    // 햇빛이 없어 다시 하지 못한다 → 햇빛 패널, 닫으면 실패 화면으로
    expect(byKey('overlay-lives'), findsOneWidget);
    expect(find.text('햇빛이 없어요'), findsOneWidget);
    expect(game(tester).controller.status, Status.failed);
    await tester.tap(byKey('btn-lives-close'));
    await advance(tester, 400);
    expect(byKey('overlay-fail'), findsOneWidget);
    // 광고 보고 채운 뒤 다시 하기
    await tester.tap(byKey('btn-retry'));
    await advance(tester, 400);
    await tester.tap(byKey('btn-lives-ad'));
    await advance(tester, 400);
    expect(h.ads.rewardedShown, 1);
    expect(h.save.data.lives.count, maxLives);
    await tester.tap(byKey('btn-lives-close'));
    await advance(tester, 400);
    await tester.tap(byKey('btn-retry'));
    await advance(tester, 400);
    expect(h.save.data.lives.count, maxLives - 1);
    expect(game(tester).controller.status, Status.playing);
  });

  testWidgets('햇빛 0개면 시작하지 않고 패널: 20분 남은 시간, 골드로 채우면 시작할 수 있다', (tester) async {
    await phone(tester);
    final now = DateTime(2026, 11, 5, 12);
    final h = Harness(data: withLives(0, now, gold: 150), now: now);
    await tester.pumpWidget(h.app);
    await tester.pump();
    expect(find.text('20:00 뒤 +1'), findsOneWidget);
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    expect(find.byType(GameScreen), findsNothing);
    expect(byKey('overlay-lives'), findsOneWidget);
    expect(find.text('햇빛이 없어요'), findsOneWidget);
    // 시간이 지나면 남은 시간이 줄어든다
    h.now = now.add(const Duration(minutes: 5));
    await advance(tester, 1100);
    expect(find.text('15:00 뒤 +1'), findsWidgets);
    await tester.tap(byKey('btn-lives-gold'));
    await advance(tester, 400);
    expect(h.save.data.lives.count, maxLives);
    expect(h.save.data.gold, 150 - refillGoldCost);
    expect(find.text('햇빛이 가득 찼어요!'), findsOneWidget);
    // 가득이면 두 버튼 모두 꺼진다
    expect(enabled(tester, 'btn-lives-gold'), isFalse);
    expect(enabled(tester, 'btn-lives-ad'), isFalse);
    await tester.tap(byKey('btn-lives-close'));
    await advance(tester, 400);
    await tester.tap(byKey('btn-start'));
    await advance(tester, 400);
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('골드가 모자라면 안내만, 광고는 하루 1번이고 아침 6시에 다시', (tester) async {
    await phone(tester);
    final now = DateTime(2026, 11, 5, 23);
    final h = Harness(data: withLives(1, now, gold: 10), now: now);
    await tester.pumpWidget(h.app);
    await tester.pump();
    await tester.tap(byKey('home-lives'));
    await advance(tester, 400);
    expect(byKey('overlay-lives'), findsOneWidget);
    expect(find.text('햇빛'), findsWidgets);
    await tester.tap(byKey('btn-lives-gold'));
    await advance(tester, 400);
    expect(find.text('골드가 모자라요'), findsOneWidget);
    expect(h.save.data.lives.count, 1);
    // 광고를 끝까지 보지 않으면 채워지지 않고, 기회도 남는다
    h.ads.rewardOk = false;
    await tester.tap(byKey('btn-lives-ad'));
    await advance(tester, 400);
    expect(find.text('광고를 끝까지 봐야 채워져요'), findsOneWidget);
    expect(h.save.data.lives.count, 1);
    h.ads.rewardOk = true;
    await tester.tap(byKey('btn-lives-ad'));
    await advance(tester, 400);
    expect(h.save.data.lives.count, maxLives);
    // 다시 쓰고 나서: 오늘은 광고 충전 불가
    for (var i = 0; i < 3; i++) {
      h.save.spendLife(h.now);
    }
    await advance(tester, 1100);
    expect(enabled(tester, 'btn-lives-ad'), isFalse);
    expect(find.text('오늘 광고 충전을 썼어요 · 아침 6시에 다시'), findsOneWidget);
    // 밤새 햇빛은 가득 찼다 (버튼은 가득이라 꺼짐) — 안내 문구로 광고 기회 확인
    h.now = DateTime(2026, 11, 6, 5, 59);
    await advance(tester, 1100);
    expect(find.text('오늘 광고 충전을 썼어요 · 아침 6시에 다시'), findsOneWidget);
    h.now = DateTime(2026, 11, 6, 6);
    await advance(tester, 1100);
    expect(find.text('광고 충전 하루 1번 (아침 6시 초기화)'), findsOneWidget);
    h.save.spendLife(h.now);
    await advance(tester, 1100);
    expect(enabled(tester, 'btn-lives-ad'), isTrue);
  });
}
