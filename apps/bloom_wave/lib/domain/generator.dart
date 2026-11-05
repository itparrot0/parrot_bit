// 레벨 생성기: 픽셀 아트 -> (해상도 배율) -> 시작 발아 지점 -> 물방울 순서 -> 여러 줄 대기열.
// 핵심 아이디어: 한 판을 "두어 보면서" 쓰인 물방울을 기록해 순서를 만들고(구성적 생성),
// 그 순서를 여러 줄에 나눠 담는다. 각 줄이 원래 순서의 부분열이므로 원래 순서대로 꺼내면 항상 클리어된다.
// 이후 줄 안에서 앞당기기 / 다른 줄로 옮기기를 할 때마다 솔버로 다시 검증한다.
//
// TS 버전(2026-11-04까지의 apps/bloom_wave/packages/core)과 같은 시드에서 같은 레벨을 만든다 —
// 난수(mulberry32)·반올림(Math.round)·탐색 순서를 그대로 옮겼고 test/domain/ts_parity_test.dart 가 확인한다.

import 'dart:math' as math;

import 'engine.dart';
import 'solver.dart';

/// rows: 팔레트 문자 또는 '.'. palette: "a=#rrggbb"
class PixelArt {
  const PixelArt(this.name, this.palette, this.rows);
  final String name;
  final List<String> palette;
  final List<String> rows;
}

class GenParams {
  const GenParams({
    required this.seed,
    required this.starts,
    required this.dropMin,
    required this.dropMax,
    required this.displacements,
    this.lanes = 3,
    this.scale = 1,
    this.targetPeak,
    this.targetWinRate = 0.3,
    this.options = defaultOptions,
    this.slotCount = 4,
    this.maxSolverNodes = 50000,
    this.trials = 300,
  });
  final int seed;

  /// 시작 발아 지점 수 (8방향으로 이어진 덩어리마다 최소 1개는 자동 보장)
  final int starts;

  /// 물방울 하나의 최소·최대 양
  final int dropMin;
  final int dropMax;

  /// 대기열을 흔드는 시도 횟수
  final int displacements;

  /// 대기열 줄 수
  final int lanes;

  /// 그림 해상도 배율 (2면 한 픽셀이 2×2 칸)
  final int scale;

  /// 목표: 클리어 수순 중 활성 슬롯이 동시에 몇 칸까지 차는가 (기본 slotCount-1)
  final int? targetPeak;

  /// 무작위 클리어율 목표
  final double targetWinRate;
  final Options options;
  final int slotCount;
  final int maxSolverNodes;

  /// 최종 무작위 클리어율 측정 판 수
  final int trials;
}

class GenReport {
  const GenReport({
    required this.level,
    required this.colors,
    required this.cells,
    required this.drops,
    required this.displacementsApplied,
    required this.peakSlots,
    required this.avgSlots,
    required this.randomWinRate,
    required this.solverNodes,
    required this.score,
    required this.difficulty,
  });
  final Level level;
  final int colors;
  final int cells;
  final int drops;
  final int displacementsApplied;

  /// 클리어 수순에서 슬롯 최대 점유
  final int peakSlots;

  /// 탭할 때마다 차 있던 슬롯 수의 평균
  final double avgSlots;
  final double randomWinRate;
  final int solverNodes;

  /// 0~100 대략적 난이도
  final int score;
  final Difficulty difficulty;
}

/// JS 의 Math.imul 과 같은 32비트 곱 (부호 없는 값으로 돌려준다)
int _imul(int a, int b) {
  a &= 0xFFFFFFFF;
  b &= 0xFFFFFFFF;
  final ah = a >> 16, al = a & 0xFFFF;
  return (al * b + (((ah * b) & 0xFFFF) << 16)) & 0xFFFFFFFF;
}

/// 시드 고정 난수 (TS 의 mulberry32 와 같은 수열)
double Function() mulberry32(int seed) {
  var a = seed & 0xFFFFFFFF;
  return () {
    a = (a + 0x6d2b79f5) & 0xFFFFFFFF;
    var t = a;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
  };
}

/// JS 의 Math.round (x.5 는 +∞ 쪽)
int jsRound(num x) => (x + 0.5).floor();

/// 무작위 클리어율 → 난이도 등급. 앱은 hard 이상에서 시작 전에 경고창을 띄운다
Difficulty difficultyOf(double winRate) {
  if (winRate >= 0.3) return Difficulty.normal;
  if (winRate >= 0.15) return Difficulty.hard;
  if (winRate >= 0.08) return Difficulty.superHard;
  return Difficulty.megaHard;
}

PixelArt scaleArt(PixelArt art, int scale) {
  if (scale <= 1) return art;
  final rows = <String>[];
  for (final r in art.rows) {
    final wide = r.split('').map((ch) => ch * scale).join();
    for (var k = 0; k < scale; k++) {
      rows.add(wide);
    }
  }
  return PixelArt(art.name, art.palette, rows);
}

typedef ArtCells = ({
  int width,
  int height,
  List<int> cells,
  List<String> palette,
});

ArtCells artToCells(PixelArt art) {
  final keys = [for (final p in art.palette) p.split('=')[0]];
  final hex = [for (final p in art.palette) p.split('=')[1]];
  final height = art.rows.length;
  final width = art.rows.map((r) => r.length).reduce(math.max);
  final cells = <int>[];
  for (final row in art.rows) {
    for (final ch in row.padRight(width, '.').split('')) {
      if (ch == '.') {
        cells.add(empty);
      } else {
        final k = keys.indexOf(ch);
        if (k < 0) throw ArgumentError('unknown palette char in ${art.name}');
        cells.add(k);
      }
    }
  }
  return (width: width, height: height, cells: cells, palette: hex);
}

/// 8방향으로 이어진 덩어리. 전염이 8방향이므로 덩어리마다 시작점이 하나는 있어야 한다.
List<List<int>> components(int width, int height, List<int> cells) {
  final seen = List<bool>.filled(cells.length, false);
  final out = <List<int>>[];
  for (var i = 0; i < cells.length; i++) {
    if (cells[i] == empty || seen[i]) continue;
    final comp = <int>[];
    final stack = [i];
    seen[i] = true;
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      comp.add(c);
      final x = c % width, y = c ~/ width;
      for (final (dx, dy) in dir8) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        final j = ny * width + nx;
        if (cells[j] != empty && !seen[j]) {
          seen[j] = true;
          stack.add(j);
        }
      }
    }
    out.add(comp);
  }
  return out;
}

T _pick<T>(List<T> arr, double Function() rng) =>
    arr[(rng() * arr.length).floor()];

class _Measure {
  const _Measure(this.solvable, this.win, this.peak, this.avg, this.nodes);
  final bool? solvable;
  final double win;
  final int peak;
  final double avg;
  final int nodes;
}

({bool cleared, int peak, double avg}) _replayStats(
  Level level,
  List<Action> actions,
  Options opt,
) {
  final s = createState(level);
  var peak = 0, occ = 0, taps = 0;
  for (final a in actions) {
    if (a is Deploy) {
      occ += s.occupied;
      taps++;
    }
    applyAction(level, s, a, opt);
    peak = math.max(peak, s.occupied);
  }
  return (
    cleared: s.status == Status.cleared,
    peak: peak,
    avg: occ / math.max(1, taps),
  );
}

_Measure _measure(
  Level level,
  Options opt,
  double Function() rng,
  int trials,
  int maxNodes, [
  List<Action>? known,
]) {
  final r = solve(level, opt, maxNodes);
  final sol = r.solvable == true ? r.solution : known;
  if (sol == null) return _Measure(r.solvable, 0, 0, 0, r.nodes);
  final st = _replayStats(level, sol, opt);
  return _Measure(
    r.solvable ?? (st.cleared ? true : null),
    randomWinRate(level, opt, trials, rng),
    st.peak,
    st.avg,
    r.nodes,
  );
}

GenReport generate(PixelArt art, GenParams p) {
  final rng = mulberry32(p.seed);
  final scaled = scaleArt(art, p.scale);
  final ac = artToCells(scaled);
  final width = ac.width, height = ac.height, cells = ac.cells;
  final slotCount = p.slotCount;
  final laneCount = math.max(1, p.lanes);
  final opt = p.options;
  final maxNodes = p.maxSolverNodes;
  final trials = p.trials;

  // 1) 시작 발아 지점
  final comps = components(width, height, cells);
  final starts = <int>{for (final c in comps) _pick(c, rng)};
  final all = [
    for (var i = 0; i < cells.length; i++)
      if (cells[i] != empty) i,
  ];
  while (starts.length < math.max(p.starts, comps.length)) {
    starts.add(_pick(all, rng));
  }

  // 2) 구성적 순서: 슬롯이 빈 안정 상태마다 "지금 퍼질 수 있는 색" 물방울을 하나 넣어 보고 기록.
  //    물방울을 혼자 무한한 양으로 퍼뜨렸을 때 닿는 칸 수(max) 이하로만 양을 정하므로 항상 다 쓰인다.
  final base = Level(
    id: '${art.name}-${p.seed}',
    width: width,
    height: height,
    palette: ac.palette,
    cells: cells,
    starts: starts.toList(),
    lanes: const [],
    slotCount: slotCount,
  );
  final s = createState(
    base.copyWith(
      lanes: [
        [Drop(0, 0)],
      ],
    ),
  );
  s.lanes = [[]];
  final order = <Drop>[];
  while (s.remaining > 0) {
    final colors = [
      for (var c = 0; c < s.sproutCount.length; c++)
        if (s.sproutCount[c] > 0) c,
    ];
    if (colors.isEmpty) {
      // 덩어리별 시작점이 있으면 일어나지 않음
      throw StateError('dead end during construction');
    }
    final color = _pick(colors, rng);
    final probe = s.clone();
    probe.lanes = [
      [Drop(color, 9007199254740991)],
    ];
    deploy(base, probe, 0);
    final before = probe.remaining;
    runUntilStable(base, probe);
    final max = before - probe.remaining;
    final want = p.dropMin + (rng() * (p.dropMax - p.dropMin + 1)).floor();
    final amount = math.min(max, want);
    s.lanes = [
      [Drop(color, amount)],
    ];
    s.status = Status.playing;
    deploy(base, s, 0);
    runUntilStable(base, s);
    order.add(Drop(color, amount));
  }

  // 3) 줄에 나눠 담기: 각 줄은 원래 순서의 부분열. 원래 순서대로 꺼내고 매번 안정될 때까지 기다리면 클리어.
  final lanes = List.generate(laneCount, (_) => <Drop>[]);
  final known = <Action>[];
  final level0 = base.copyWith(lanes: lanes);
  {
    final sim = createState(
      base.copyWith(
        lanes: [
          [for (final d in order) d.copy()],
        ],
      ),
    );
    for (var k = 0; k < order.length; k++) {
      final d = order[k];
      final lane = k < laneCount ? k : (rng() * laneCount).floor(); // 줄마다 최소 하나
      lanes[lane].add(d);
      known.add(Deploy(lane));
      deploy(base, sim, 0);
      while (sim.status == Status.playing &&
          sim.slots.any((x) => x != null && sim.sproutCount[x.color] > 0)) {
        applyAction(base, sim, const Tick(), opt);
        if (opt.realtime) known.add(const Tick());
      }
    }
  }

  var level = level0;
  var m = _measure(level, opt, rng, 60, maxNodes, known);
  if (m.solvable != true) {
    throw StateError('constructed level not solvable (bug)');
  }

  // 4) 난이도: 물방울을 줄 안에서 앞당기거나 다른 줄로 옮긴다. 솔버가 클리어 가능을 확인할 때만 받아들이고,
  //    슬롯 압박(최대 점유, 평균 점유)과 무작위 실패율이 나빠지지 않는 쪽으로만 움직인다.
  final targetPeak = p.targetPeak ?? slotCount - 1;
  final targetWin = p.targetWinRate;
  double objective(_Measure x) => (1 - x.win) * 100 + x.peak * 10 + x.avg;
  var applied = 0;
  for (
    var tries = 0;
    tries < p.displacements && !(m.peak >= targetPeak && m.win <= targetWin);
    tries++
  ) {
    final ls = [for (final l in level.lanes) List.of(l)];
    final from = (rng() * ls.length).floor();
    if (ls[from].isEmpty) continue;
    final idx = (rng() * ls[from].length).floor();
    final d = ls[from].removeAt(idx);
    final toLane = laneCount > 1 && rng() < 0.5
        ? (rng() * laneCount).floor()
        : from;
    final pos = (rng() * ((toLane == from ? idx : ls[toLane].length) + 1))
        .floor();
    ls[toLane].insert(pos, d);
    if (ls.any((l) => l.isEmpty)) continue; // 빈 줄은 만들지 않는다
    final cand = level.copyWith(lanes: ls);
    final cm = _measure(cand, opt, rng, 60, maxNodes);
    if (cm.solvable != true || objective(cm) < objective(m)) continue;
    level = cand;
    m = cm;
    applied++;
  }

  m = _measure(level, opt, rng, trials, maxNodes, applied > 0 ? null : known);
  final colors = cells.where((c) => c != empty).toSet().length;
  final drops = queueLength(level.lanes);
  final score = jsRound(
    math.min(
      100,
      (1 - m.win) * 50 +
          (m.peak / slotCount) * 25 +
          math.min(15, colors * 3) +
          math.min(10, drops / 4),
    ),
  );
  return GenReport(
    level: level,
    colors: colors,
    cells: all.length,
    drops: drops,
    displacementsApplied: applied,
    peakSlots: m.peak,
    avgSlots: jsRound(m.avg * 100) / 100,
    randomWinRate: m.win,
    solverNodes: m.nodes,
    score: score,
    difficulty: difficultyOf(m.win),
  );
}

/// 수순을 재생해 클리어되는지 확인
bool replay(Level level, List<Action> actions, [Options opt = defaultOptions]) {
  final s = createState(level);
  for (final a in actions) {
    applyAction(level, s, a, opt);
  }
  return s.status == Status.cleared;
}
