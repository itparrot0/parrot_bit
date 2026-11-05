// 깊이 우선 탐색 솔버 + 실패 상태 메모이제이션.
// 선택지: 줄마다 "맨 앞 넣기" + "기다리기(틱)". 탐색 순서만 휴리스틱으로 정하고 규칙은 engine.dart 그대로.

import 'engine.dart';

class SolveResult {
  const SolveResult(this.solvable, this.solution, this.nodes);

  /// null = 노드 한도 초과로 판정 불가
  final bool? solvable;
  final List<Action> solution;
  final int nodes;
}

/// 지금 바로 퍼질 수 있는 물방울 넣기 → 기다리기 → 못 쓰는 물방울 넣기 순으로 시도하면 해를 빨리 찾는다
List<Action> _ordered(State s, Options opt) {
  final as = legalActions(s, opt);
  int rank(Action a) => switch (a) {
    Tick() => 1,
    Deploy(:final lane) => s.sproutCount[s.lanes[lane][0].color] > 0 ? 0 : 2,
  };
  final keyed = [
    for (var i = 0; i < as.length; i++) (a: as[i], r: rank(as[i]) * 100 + i),
  ]..sort((x, y) => x.r - y.r);
  return [for (final k in keyed) k.a];
}

/// 임의의 상태에서 출발하는 솔버. peakLimit 를 주면 활성 슬롯 점유가 그 값을 넘는 수는 두지 않는다.
SolveResult solveFrom(
  Level level,
  State start, [
  Options opt = defaultOptions,
  int maxNodes = 200000,
  int? peakLimit,
]) {
  final dead = <String>{};
  final path = <Action>[];
  var nodes = 0;
  var aborted = false;

  bool dfs(State s) {
    if (s.status == Status.cleared) return true;
    if (s.status == Status.failed) return false;
    if (++nodes > maxNodes) {
      aborted = true;
      return false;
    }
    final key = stateKey(s);
    if (dead.contains(key)) return false;
    for (final a in _ordered(s, opt)) {
      if (a is Deploy && peakLimit != null && s.occupied + 1 > peakLimit) {
        continue;
      }
      final c = s.clone();
      applyAction(level, c, a, opt);
      path.add(a);
      if (dfs(c)) return true;
      path.removeLast();
      if (aborted) return false;
    }
    dead.add(key);
    return false;
  }

  final ok = dfs(start.clone());
  return SolveResult(
    ok
        ? true
        : aborted
        ? null
        : false,
    ok ? List.of(path) : const [],
    nodes,
  );
}

SolveResult solve(
  Level level, [
  Options opt = defaultOptions,
  int maxNodes = 200000,
]) => solveFrom(level, createState(level), opt, maxNodes);

class PlayStats {
  const PlayStats(this.cleared, this.peakSlots, this.ticks);
  final bool cleared;
  final int peakSlots;
  final int ticks;
}

/// 무작위 플레이어(사람 흉내): 지금 퍼질 수 있는 물방울 넣기 3, 기다리기 2, 못 쓰는 물방울 넣기 1의 비율로 고른다.
/// 완전 무작위는 줄이 많을수록 지나치게 못 두어 난이도 지표가 왜곡된다.
PlayStats playout(Level level, Options opt, double Function() rng) {
  final s = createState(level);
  var peak = 0;
  while (s.status == Status.playing) {
    final as = legalActions(s, opt);
    final w = [
      for (final a in as)
        switch (a) {
          Tick() => 2,
          Deploy(:final lane) =>
            s.sproutCount[s.lanes[lane][0].color] > 0 ? 3 : 1,
        },
    ];
    var r = rng() * w.fold<int>(0, (x, y) => x + y);
    var k = 0;
    while (k < as.length - 1 && (r -= w[k]) >= 0) {
      k++;
    }
    applyAction(level, s, as[k], opt);
    final occ = s.occupied;
    if (occ > peak) peak = occ;
  }
  return PlayStats(s.status == Status.cleared, peak, s.tick);
}

double randomWinRate(
  Level level,
  Options opt,
  int trials,
  double Function() rng,
) {
  var wins = 0;
  for (var t = 0; t < trials; t++) {
    if (playout(level, opt, rng).cleared) wins++;
  }
  return wins / trials;
}
