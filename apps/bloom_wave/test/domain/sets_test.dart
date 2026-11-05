// set (2026-11-05): 서로 다른 줄의 물방울 2~3개 묶음. 모두 줄 맨 앞일 때만 탭, 탭하면 한꺼번에 슬롯으로
import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/domain/solver.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1행 6칸: 빨강 3 · 파랑 3. 시작은 0번 칸
Level lv(List<List<Drop>> lanes, {int slots = 4}) => Level(
  id: 'sets',
  width: 6,
  height: 1,
  palette: const ['#e5484d', '#3e9bdb'],
  cells: const [0, 0, 0, 1, 1, 1],
  starts: const [0],
  lanes: lanes,
  slotCount: slots,
);

void main() {
  test('짝이 맨 앞이 아니면 못 누르고, 모두 맨 앞이면 한꺼번에 줄 번호 순으로 들어간다', () {
    final l = lv([
      [Drop(0, 1), Drop(0, 2, set: 0)],
      [Drop(1, 3, set: 0)],
      [Drop(1, 1)],
    ]);
    final s = createState(l);
    expect(frontGroup(s, 1), isNull); // 줄 0 의 짝이 아직 두 번째
    expect(canDeploy(s, 1), isFalse);
    expect(legalActions(s).whereType<Deploy>().map((d) => d.lane), [0, 2]);
    expect(() => deploy(l, s, 1), throwsStateError);
    deploy(l, s, 0); // 빨강 1 → 줄 0 맨 앞이 set
    expect(frontGroup(s, 1), [0, 1]);
    expect(frontGroup(s, 0), [0, 1]);
    // set 은 가장 작은 줄 번호로 한 번만
    expect(legalActions(s).whereType<Deploy>().map((d) => d.lane), [0, 2]);
    final placed = deployGroup(l, s, 1);
    expect(placed, [(1, 0), (2, 1)]);
    expect(s.slots[1], Drop(0, 2, set: 0));
    expect(s.slots[2], Drop(1, 3, set: 0));
    expect(s.lanes[0], isEmpty);
    expect(s.lanes[1], isEmpty);
  });

  test('빈 슬롯이 set 크기보다 적으면 넣을 수 없고, 넣을 게 없으면 실패', () {
    // 슬롯 2칸, 파랑 2개(퍼질 곳 없음)를 먼저 넣으면 빈 슬롯 0 → 실패 (예전 규칙과 같음)
    // 슬롯 3칸: 파랑 하나 넣으면 빈 슬롯 2. set 3개는 못 넣고 다른 줄도 없으면 실패
    final l = lv([
      [Drop(1, 1)],
      [Drop(0, 1, set: 0)],
      [Drop(0, 1, set: 0)],
      [Drop(0, 1, set: 0)],
    ], slots: 3);
    final s = createState(l);
    expect(canDeploy(s, 1), isTrue);
    deploy(l, s, 0);
    expect(freeSlots(s), 2);
    expect(canDeploy(s, 1), isFalse);
    expect(s.status, Status.failed);
  });

  test('set 끼리 서로 막으면(교착) 슬롯이 비어 있어도 실패', () {
    final l = lv([
      [Drop(1, 1, set: 0), Drop(0, 1, set: 1)],
      [Drop(1, 1, set: 1), Drop(0, 1, set: 0)],
    ]);
    final s = createState(l);
    expect(s.slots.contains(null), isTrue);
    expect(s.status, Status.failed);
    expect(legalActions(s), isEmpty);
  });

  test('섞기 확인용: set 짝이 한 줄에 겹치면 setsSplit 이 false', () {
    final ok = createState(
      lv([
        [Drop(0, 1, set: 0)],
        [Drop(1, 1, set: 0)],
      ]),
    );
    expect(setsSplit(ok), isTrue);
    final bad = createState(
      lv([
        [Drop(0, 1, set: 0), Drop(1, 1, set: 0)],
        [Drop(1, 1)],
      ]),
    );
    expect(setsSplit(bad), isFalse);
  });

  test('set 이 없으면 예전과 같다, JSON 왕복에 set 이 남는다', () {
    final plain = lv([
      [Drop(0, 3)],
      [Drop(1, 3)],
    ]);
    expect(solve(plain).solvable, isTrue);
    final linked = lv([
      [Drop(0, 3, set: 0)],
      [Drop(1, 3, set: 0)],
    ]);
    final back = Level.fromJson(linked.toJson());
    expect(back.lanes[0][0].set, 0);
    expect(back.lanes[1][0], Drop(1, 3, set: 0));
    expect(plain.toJson()['lanes'][0][0], {'color': 0, 'amount': 3});
    // 같이 넣어도 빨강부터 퍼지고 파랑이 이어서 → 클리어
    final r = solve(linked);
    expect(r.solvable, isTrue);
    expect(r.solution.whereType<Deploy>(), hasLength(1));
  });
}
