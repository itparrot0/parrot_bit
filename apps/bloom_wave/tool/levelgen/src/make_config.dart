// levels.config.json 을 만든다 (한 번 만들고 커밋한 뒤 사람이 손으로 고쳐도 된다).
// 1000 스테이지 (2026-11-04): 튜토리얼 1~5, 그 뒤로 2~4스테이지마다 무작위 등급의 어려움 스테이지 + 사이사이 노말.
// 2000 스테이지 (2026-11-05): 1~1000 은 그대로(같은 시드·같은 그림 목록으로 같은 결과), 1001~2000 은 별도 시드로 이어 붙이고
// 고해상도 그림(art_hires.dart, h_)을 먼저 쓴다.
// (그전 120 스테이지 구간 배치는 git 기록 d3ab45e 의 이 파일)
import 'dart:io';
import 'dart:math' as math;

import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/domain/generator.dart';

import 'art_gen.dart';
import 'art_source.dart';
import 'config.dart';
import 'js_json.dart';

final List<ArtSource> _allArts = [...artSources, ...generatedArts()];
ArtSource _src(String name) => _allArts.firstWhere((x) => x.name == name);

double _complexity(String name) {
  final a = _src(name);
  final cells = a.rows.join().replaceAll('.', '').length;
  return cells * (1 + 0.25 * a.palette.length);
}

int _cells(String name) => _src(name).rows.join().replaceAll('.', '').length;

int _big(String name) {
  final a = _src(name);
  return [a.rows.length, ...a.rows.map((r) => r.length)].reduce(math.max);
}

const _v3 = PartialOptions(visible: 3);

/// 출시 팩 스테이지 수
const totalStages = 2000;

/// 1차 구간 (이 안은 2026-11-05 이전 팩과 똑같이 나온다)
const firstPart = 1000;

/// 2차 구간 (1001~2000, 고해상도 그림). 2001~3000 은 국기·장난감 그림 (2026-11-05)
const secondPart = 2000;

/// "?" 물방울 스테이지: [mysteryFrom] 부터 [mysteryEvery] 스테이지마다 (노말이면 가장 가까운 어려움 스테이지)
const mysteryFrom = 100, mysteryEvery = 18;

/// set 스테이지 (2026-11-05): [setsFrom] 부터 [setsEvery] 스테이지마다 하나 (노말이면 가장 가까운 어려움 스테이지,
/// "?" 스테이지와는 겹치지 않게)
const setsFrom = 150, setsEvery = 12;

/// 한 그림을 쓰는 최대 횟수 / 같은 그림 사이 최소 간격 / 같은 유형 사이 최소 간격
const maxUses = 3, minGap = 100, familyGap = 8;

/// 다음 어려움 스테이지까지 거리: 2~4
int _gap(double Function() rng) => 2 + (rng() * 3).floor();

/// 해상도 (2026-11-05): 그림을 정수 배율로 키워 칸 수를 늘린다. 한 변 [boardMaxSide] 칸, 전체 [boardMaxCells] 칸 안에서
/// 가장 큰 배율(1~3). 칸이 많아지는 만큼 물방울을 크게(두 자리 수) 나눠 탭 수는 오히려 줄인다.
const boardMaxSide = 32, boardMaxCells = 800;

/// 물방울 크기 기준 칸 수 (1~1000 스테이지 칸 수 중앙값, 2026-11-05)
const dropRefCells = 400;

int _scaleFor(String art) {
  final big = _big(art), cells = _cells(art);
  for (var s = 3; s > 1; s--) {
    if (big * s <= boardMaxSide && cells * s * s <= boardMaxCells) return s;
  }
  return 1;
}

/// 등급별 생성 조건 (2026-11-05: 큰 판 + 두 자리 수 물방울). target·range 는 무작위 클리어율 목표
/// (등급 경계: 30% / 15% / 8%). 물방울 크기는 "칠할 칸 수"라서, 큰 물방울일수록 탭이 줄고 쉬워진다.
({
  int starts,
  int lanes,
  int dropMin,
  int dropMax,
  int displacements,
  num target,
  (num, num) range,
})
_preset(Difficulty tier, int n, double Function() rng) => switch (tier) {
  Difficulty.normal when n <= 30 => (
    starts: 3,
    lanes: 3,
    dropMin: 10,
    dropMax: 24,
    displacements: 200,
    target: 0.6,
    range: (0.4, 1),
  ),
  Difficulty.normal => (
    starts: rng() < 0.5 ? 2 : 3,
    lanes: 3,
    dropMin: 12,
    dropMax: 30,
    displacements: 200,
    target: 0.5,
    range: (0.3, 1),
  ),
  Difficulty.hard => (
    starts: 2,
    lanes: 3,
    dropMin: 8,
    dropMax: 20,
    displacements: 600,
    target: 0.22,
    range: (0.15, 0.3),
  ),
  Difficulty.superHard => (
    starts: rng() < 0.5 ? 1 : 2,
    lanes: rng() < 0.5 ? 3 : 4,
    dropMin: 6,
    dropMax: 16,
    displacements: 600,
    target: 0.11,
    range: (0.08, 0.15),
  ),
  Difficulty.megaHard => (
    starts: 1,
    lanes: 4,
    dropMin: 5,
    dropMax: 14,
    displacements: 600,
    target: 0.04,
    range: (0, 0.08),
  ),
};

PackConfig makeConfig() {
  // 대기열은 항상 3줄 이상 (2026-11-04 결정). visible = 줄마다 미리 보이는 물방울 수 (2026-11-04 2차: 모든 레벨 3 = 탭할 1개 + 다음 2개)
  LevelSpec tut(
    String art,
    String key,
    List<int> seeds,
    int starts,
    int dropMin,
    int dropMax,
    num target,
    num lo,
    bool turn,
  ) => LevelSpec(
    art: art,
    band: 'tutorial',
    tutorial: key,
    seeds: seeds,
    starts: starts,
    lanes: 3,
    dropMin: dropMin,
    dropMax: dropMax,
    displacements: 0,
    targetWinRate: target,
    winRange: (lo, 1),
    options: turn ? const PartialOptions(realtime: false, visible: 3) : _v3,
  );
  final tutorial = [
    tut('dewdrop', 'wave', [1], 1, 6, 9, 1, 0.9, true),
    tut('sprout', 'lanes', [1, 2, 3], 1, 5, 8, 1, 0.8, true),
    tut('heart', 'realtime', [1, 2, 3, 4], 2, 4, 8, 1, 0.7, false),
    tut('sun', 'waiting', [1, 2, 3, 4], 1, 3, 6, 0.9, 0.6, false),
    tut('snowflake', 'slots', [1, 2, 3, 4], 2, 3, 6, 0.9, 0.6, false),
  ];
  final used = tutorial.map((t) => t.art).toSet();
  final names = [
    for (final a in _allArts)
      if (!used.contains(a.name) &&
          !a.name.startsWith('h_') &&
          !a.name.startsWith('f_') &&
          !a.name.startsWith('t_'))
        a.name,
  ];
  final worldNames = [
    for (final a in _allArts)
      if (a.name.startsWith('f_') || a.name.startsWith('t_')) a.name,
  ];
  final hiresNames = [
    for (final a in _allArts)
      if (a.name.startsWith('h_')) a.name,
  ];
  // JS 의 Array.sort 처럼 안정 정렬 (복잡도가 같으면 원래 순서)
  final pos = {for (var i = 0; i < names.length; i++) names[i]: i};
  final pool = [...names]
    ..sort((a, b) {
      final d = _complexity(a).compareTo(_complexity(b));
      return d != 0 ? d : pos[a]! - pos[b]!;
    });

  // ---- 1000 스테이지 (2026-11-04) ----
  // 6스테이지부터 2~4스테이지마다 "어려움" 스테이지가 하나씩 끼고, 그 사이는 노말.
  // 어려움의 등급(Hard / Super Hard / Mega Hard)은 무작위. 단 입문 구간(~30)은 Hard 만.
  // 같은 설정이면 언제나 같은 배치가 나온다 (시드 고정).
  final rng = mulberry32(20261104);
  final tiers = <int, Difficulty>{};
  var lastHard = 0;
  for (var p = tutorial.length + _gap(rng); p <= firstPart; p += _gap(rng)) {
    lastHard = p;
    tiers[p] = p <= 30
        ? Difficulty.hard
        : const [
            Difficulty.hard,
            Difficulty.superHard,
            Difficulty.megaHard,
          ][(rng() * 3).floor()];
  }
  // 1001~2000: 따로 정한 시드로 같은 규칙 (1~1000 의 난수 흐름을 건드리지 않는다)
  final rng2 = mulberry32(20261105);
  var start2 = lastHard + _gap(rng2);
  while (start2 <= firstPart) {
    start2 += _gap(rng2);
  }
  var lastHard2 = 0;
  for (var p = start2; p <= secondPart; p += _gap(rng2)) {
    lastHard2 = p;
    tiers[p] = const [
      Difficulty.hard,
      Difficulty.superHard,
      Difficulty.megaHard,
    ][(rng2() * 3).floor()];
  }
  // 2001~3000: 또 따로 정한 시드
  final rng3 = mulberry32(20261106);
  var start3 = lastHard2 + _gap(rng3);
  while (start3 <= secondPart) {
    start3 += _gap(rng3);
  }
  for (var p = start3; p <= totalStages; p += _gap(rng3)) {
    tiers[p] = const [
      Difficulty.hard,
      Difficulty.superHard,
      Difficulty.megaHard,
    ][(rng3() * 3).floor()];
  }

  // 그림 배정 규칙 (2026-11-04):
  //  - 한 그림은 많아야 [maxUses] 번
  //  - 같은 그림이 다시 나오려면 [minGap] 스테이지 이상 지나야 한다
  //  - 같은 유형(art_gen.familyOf: 산 풍경끼리, 친구 캐릭터끼리 …)은 [familyGap] 스테이지 안에 겹치지 않게 (안 되면 이것만 완화)
  //  - 초반 노말은 단순한 그림부터, Super/Mega Hard 는 복잡한 2/3 에서 (안 되면 이것도 완화)
  //  - 그 안에서 가장 적게 쓴 그림, 같으면 무작위
  // "?" 물방울 스테이지 (2026-11-05): 100스테이지부터 18스테이지마다 하나. 목표 스테이지가 노말이면
  // 가장 가까운 노말 아닌 스테이지로(같은 거리면 앞쪽). 그래서 간격이 정확히 18은 아니다
  // 구간별로 따로 고른다 (1~1000 은 예전과 같게): 목표 수열은 이어지고, 고르는 범위만 구간 안
  Set<int> every(int from, int step, int lo, int hi, Set<int> taken) {
    final out = <int>{};
    for (var target = from; target <= hi; target += step) {
      if (target < lo - step) continue;
      for (var d = 0; d <= step; d++) {
        final cands = [target - d, if (d > 0) target + d];
        final hit = cands.where(
          (n) =>
              n >= math.max(from, lo) &&
              n <= hi &&
              tiers.containsKey(n) &&
              !taken.contains(n) &&
              !out.contains(n),
        );
        if (hit.isNotEmpty) {
          out.add(hit.first);
          break;
        }
      }
    }
    return out;
  }

  final mystery = {...every(mysteryFrom, mysteryEvery, 1, firstPart, const {})};
  mystery.addAll(
    every(mysteryFrom, mysteryEvery, firstPart + 1, secondPart, mystery),
  );
  mystery.addAll(
    every(mysteryFrom, mysteryEvery, secondPart + 1, totalStages, mystery),
  );
  final sets = {...every(setsFrom, setsEvery, 1, firstPart, mystery)};
  sets.addAll(
    every(setsFrom, setsEvery, firstPart + 1, secondPart, {
      ...mystery,
      ...sets,
    }),
  );
  sets.addAll(
    every(setsFrom, setsEvery, secondPart + 1, totalStages, {
      ...mystery,
      ...sets,
    }),
  );

  final uses = <String, int>{}; // 그림별 사용 횟수 → variant 번호 (id: <그림>-<n>)
  final lastUse = <String, int>{};
  final lastFamily = <String, int>{};
  final levels = <LevelSpec>[...tutorial];
  final hiresPool = [...hiresNames]
    ..sort((a, b) => _complexity(a).compareTo(_complexity(b)));
  final allPool = [...pool, ...hiresPool];
  final worldPool = [...worldNames]
    ..sort((a, b) => _complexity(a).compareTo(_complexity(b)));
  final allPool3 = [...allPool, ...worldPool];
  for (var n = tutorial.length + 1; n <= totalStages; n++) {
    final third = n > secondPart;
    final second = n > firstPart && !third;
    final r = third
        ? rng3
        : second
        ? rng2
        : rng;
    final from = third
        ? allPool3
        : second
        ? allPool
        : pool;
    final tier = tiers[n] ?? Difficulty.normal;
    final List<String> preferred = third
        ? worldPool
        : second
        ? hiresPool
        : switch (tier) {
            Difficulty.normal when n <= 30 => pool.sublist(0, 60),
            Difficulty.normal when n <= 100 => pool.sublist(
              0,
              pool.length ~/ 2,
            ),
            Difficulty.superHard ||
            Difficulty.megaHard => pool.sublist(pool.length ~/ 3),
            _ => pool,
          };
    bool free(String a) =>
        (uses[a] ?? 0) < maxUses && n - (lastUse[a] ?? -minGap) >= minGap;
    bool spaced(String a) =>
        n - (lastFamily[familyOf(a)] ?? -familyGap) >= familyGap;
    var cands = [
      for (final a in preferred)
        if (free(a) && spaced(a)) a,
    ];
    if (cands.isEmpty) {
      cands = [
        for (final a in from)
          if (free(a) && spaced(a)) a,
      ];
    }
    if (cands.isEmpty) {
      cands = [
        for (final a in from)
          if (free(a)) a,
      ];
    }
    if (cands.isEmpty) {
      throw StateError(
        'stage $n: 쓸 수 있는 그림이 없다 (그림 ${from.length}장, 최대 $maxUses번, 간격 $minGap)',
      );
    }
    final least = cands.map((a) => uses[a] ?? 0).reduce(math.min);
    final pick = cands.where((a) => (uses[a] ?? 0) == least).toList();
    final art = pick[(r() * pick.length).floor()];
    lastUse[art] = n;
    lastFamily[familyOf(art)] = n;
    final variant = (uses[art] = (uses[art] ?? 0) + 1);
    final sc = _scaleFor(art);
    final scale = sc > 1 ? sc : null;
    final p = _preset(tier, n, r);
    // 1001 스테이지부터는 큰 판(원본 해상도가 큰 그림)이 많다 → 칸 수에 비례해 물방울을 키워 탭 수를 1~1000 수준으로 맞춘다.
    // 기준은 1~1000 의 칸 수 중앙값 [dropRefCells]. 1~1000 은 손대지 않는다
    final k = n > firstPart
        ? (_cells(art) * sc * sc / dropRefCells).clamp(1.0, 2.2)
        : 1.0;
    levels.add(
      LevelSpec(
        art: art,
        variant: variant > 1 ? variant : null,
        scale: scale,
        band: 'stage',
        seeds: const [1, 2, 3, 4, 5, 6],
        starts: p.starts,
        lanes: p.lanes,
        dropMin: (p.dropMin * k).round(),
        dropMax: (p.dropMax * k).round(),
        displacements: p.displacements,
        targetWinRate: p.target,
        winRange: p.range,
        options: _v3,
        difficulty: tier.name,
        mystery: mystery.contains(n),
        sets: sets.contains(n),
      ),
    );
  }

  final count = {for (final t in Difficulty.values) t: 0};
  for (var n = tutorial.length + 1; n <= totalStages; n++) {
    count[tiers[n] ?? Difficulty.normal] =
        count[tiers[n] ?? Difficulty.normal]! + 1;
  }
  stdout.writeln(
    'levels: ${levels.length} (tutorial ${tutorial.length}, '
    '${[for (final t in Difficulty.values) '${t.name} ${count[t]}'].join(', ')})',
  );
  return PackConfig(
    pack: 'pack-01',
    copyTo: ['../../assets/levels/pack-01.json'],
    defaults: const PackDefaults(
      slotCount: 4,
      options: Options(realtime: true, visible: 3),
      displacements: 600,
      maxSolverNodes: 50000,
      maxColors: 6,
      maxSize: 24,
    ),
    levels: levels,
  );
}

void writeConfig(String path) {
  File(path).writeAsStringSync('${jsStringifyPretty(makeConfig().toJson())}\n');
}
