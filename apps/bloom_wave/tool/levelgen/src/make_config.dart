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

int _big(String name) {
  final a = _src(name);
  return [a.rows.length, ...a.rows.map((r) => r.length)].reduce(math.max);
}

const _v3 = PartialOptions(visible: 3);

/// 출시 팩 스테이지 수
const totalStages = 1000;

/// 한 그림을 쓰는 최대 횟수 / 같은 그림 사이 최소 간격 / 같은 유형 사이 최소 간격
const maxUses = 3, minGap = 100, familyGap = 8;

/// 다음 어려움 스테이지까지 거리: 2~4
int _gap(double Function() rng) => 2 + (rng() * 3).floor();

/// 등급별 생성 조건. target·range 는 무작위 클리어율 목표 (등급 경계: 30% / 15% / 8%)
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
    starts: 2,
    lanes: 3,
    dropMin: 3,
    dropMax: 6,
    displacements: 200,
    target: 0.6,
    range: (0.4, 1),
  ),
  Difficulty.normal => (
    starts: rng() < 0.5 ? 1 : 2,
    lanes: 3,
    dropMin: 2,
    dropMax: 5,
    displacements: 200,
    target: 0.5,
    range: (0.3, 1),
  ),
  Difficulty.hard => (
    starts: 1,
    lanes: 3,
    dropMin: 1,
    dropMax: 4,
    displacements: 600,
    target: 0.22,
    range: (0.15, 0.3),
  ),
  Difficulty.superHard => (
    starts: 1,
    lanes: rng() < 0.5 ? 3 : 4,
    dropMin: 1,
    dropMax: 4,
    displacements: 600,
    target: 0.11,
    range: (0.08, 0.15),
  ),
  Difficulty.megaHard => (
    starts: 1,
    lanes: 4,
    dropMin: 1,
    dropMax: 3,
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
    // Mega Hard 는 해상도 2배 그림을 반쯤 섞는다 (칸이 많아져 더 어렵다)
    final scale =
        tier == Difficulty.megaHard && _big(art) * 2 <= 24 && rng() < 0.5
        ? 2
        : null;
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
        dropMax: scale != null ? p.dropMax + 1 : p.dropMax,
        displacements: p.displacements,
        targetWinRate: p.target,
        winRange: p.range,
        options: _v3,
        difficulty: tier.name,
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
