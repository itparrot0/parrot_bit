// levels.config.json 을 만든다 (한 번 만들고 커밋한 뒤 사람이 손으로 고쳐도 된다).
// 1000 스테이지 (2026-11-04): 튜토리얼 1~5, 그 뒤로 2~4스테이지마다 무작위 등급의 어려움 스테이지 + 사이사이 노말.
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
const totalStages = 1000;

/// "?" 물방울 스테이지: [mysteryFrom] 부터 [mysteryEvery] 스테이지마다 (노말이면 가장 가까운 어려움 스테이지)
const mysteryFrom = 100, mysteryEvery = 18;

/// 한 그림을 쓰는 최대 횟수 / 같은 그림 사이 최소 간격 / 같은 유형 사이 최소 간격
const maxUses = 3, minGap = 100, familyGap = 8;

/// 다음 어려움 스테이지까지 거리: 2~4
int _gap(double Function() rng) => 2 + (rng() * 3).floor();

/// 해상도 (2026-11-05): 그림을 정수 배율로 키워 칸 수를 늘린다. 한 변 [boardMaxSide] 칸, 전체 [boardMaxCells] 칸 안에서
/// 가장 큰 배율(1~3). 칸이 많아지는 만큼 물방울을 크게(두 자리 수) 나눠 탭 수는 오히려 줄인다.
const boardMaxSide = 32, boardMaxCells = 800;

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
      if (!used.contains(a.name)) a.name,
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
  for (var p = tutorial.length + _gap(rng); p <= totalStages; p += _gap(rng)) {
    tiers[p] = p <= 30
        ? Difficulty.hard
        : const [
            Difficulty.hard,
            Difficulty.superHard,
            Difficulty.megaHard,
          ][(rng() * 3).floor()];
  }

  // 그림 배정 규칙 (2026-11-04):
  //  - 한 그림은 많아야 [maxUses] 번
  //  - 같은 그림이 다시 나오려면 [minGap] 스테이지 이상 지나야 한다
  //  - 같은 유형(art_gen.familyOf: 산 풍경끼리, 친구 캐릭터끼리 …)은 [familyGap] 스테이지 안에 겹치지 않게 (안 되면 이것만 완화)
  //  - 초반 노말은 단순한 그림부터, Super/Mega Hard 는 복잡한 2/3 에서 (안 되면 이것도 완화)
  //  - 그 안에서 가장 적게 쓴 그림, 같으면 무작위
  // "?" 물방울 스테이지 (2026-11-05): 100스테이지부터 18스테이지마다 하나. 목표 스테이지가 노말이면
  // 가장 가까운 노말 아닌 스테이지로(같은 거리면 앞쪽). 그래서 간격이 정확히 18은 아니다
  final mystery = <int>{};
  for (
    var target = mysteryFrom;
    target <= totalStages;
    target += mysteryEvery
  ) {
    for (var d = 0; d <= mysteryEvery; d++) {
      final cands = [target - d, if (d > 0) target + d];
      final hit = cands.where(
        (n) =>
            n >= mysteryFrom &&
            n <= totalStages &&
            tiers.containsKey(n) &&
            !mystery.contains(n),
      );
      if (hit.isNotEmpty) {
        mystery.add(hit.first);
        break;
      }
    }
  }

  final uses = <String, int>{}; // 그림별 사용 횟수 → variant 번호 (id: <그림>-<n>)
  final lastUse = <String, int>{};
  final lastFamily = <String, int>{};
  final levels = <LevelSpec>[...tutorial];
  for (var n = tutorial.length + 1; n <= totalStages; n++) {
    final tier = tiers[n] ?? Difficulty.normal;
    final List<String> preferred = switch (tier) {
      Difficulty.normal when n <= 30 => pool.sublist(0, 60),
      Difficulty.normal when n <= 100 => pool.sublist(0, pool.length ~/ 2),
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
        for (final a in pool)
          if (free(a) && spaced(a)) a,
      ];
    }
    if (cands.isEmpty) {
      cands = [
        for (final a in pool)
          if (free(a)) a,
      ];
    }
    if (cands.isEmpty) {
      throw StateError(
        'stage $n: 쓸 수 있는 그림이 없다 (그림 ${pool.length}장, 최대 $maxUses번, 간격 $minGap)',
      );
    }
    final least = cands.map((a) => uses[a] ?? 0).reduce(math.min);
    final pick = cands.where((a) => (uses[a] ?? 0) == least).toList();
    final art = pick[(rng() * pick.length).floor()];
    lastUse[art] = n;
    lastFamily[familyOf(art)] = n;
    final variant = (uses[art] = (uses[art] ?? 0) + 1);
    final sc = _scaleFor(art);
    final scale = sc > 1 ? sc : null;
    final p = _preset(tier, n, rng);
    levels.add(
      LevelSpec(
        art: art,
        variant: variant > 1 ? variant : null,
        scale: scale,
        band: 'stage',
        seeds: const [1, 2, 3, 4, 5, 6],
        starts: p.starts,
        lanes: p.lanes,
        dropMin: p.dropMin,
        dropMax: p.dropMax,
        displacements: p.displacements,
        targetWinRate: p.target,
        winRange: p.range,
        options: _v3,
        difficulty: tier.name,
        mystery: mystery.contains(n),
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
