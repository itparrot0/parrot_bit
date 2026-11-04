// levels.config.json 을 만든다 (한 번 만들고 커밋한 뒤 사람이 손으로 고쳐도 된다).
// 01_게임기획서.md 7.3 난이도 곡선: 튜토리얼 1~5 / 입문 6~30 / 중급 31~80 / 상급 81~120.
import 'dart:io';
import 'dart:math' as math;

import 'package:bloom_wave/domain/engine.dart';

import 'art_source.dart';
import 'config.dart';
import 'js_json.dart';

ArtSource _src(String name) => artSources.firstWhere((x) => x.name == name);

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
    for (final a in artSources)
      if (!used.contains(a.name)) a.name,
  ];
  // JS 의 Array.sort 처럼 안정 정렬 (복잡도가 같으면 원래 순서)
  final pos = {for (var i = 0; i < names.length; i++) names[i]: i};
  final pool = [...names]
    ..sort((a, b) {
      final d = _complexity(a).compareTo(_complexity(b));
      return d != 0 ? d : pos[a]! - pos[b]!;
    });

  // 구간별 그림 배정
  final intro = pool.sublist(0, 25); // 6~30
  final mid = pool.sublist(25, 75); // 31~80
  final hardUnique = pool.sublist(75); // 81~ (가장 큰 그림)
  // 중급 그림을 해상도 2배로 키워 한 번 더 ("II"). 확대 후 24칸을 넘지 않는 그림만
  final hardRepeat = pool
      .sublist(0, 75)
      .where((n) => _big(n) * 2 <= 24)
      .toList()
      .reversed
      .take(30)
      .toList();

  final levels = <LevelSpec>[...tutorial];
  const seeds = [1, 2, 3, 4, 5, 6];

  // 입문: 큰 물방울, 시작 지점 여러 곳, 3개씩 미리 보임. 마지막(30)은 보스.
  for (var i = 0; i < intro.length; i++) {
    levels.add(
      LevelSpec(
        art: intro[i],
        band: 'intro',
        role: i == intro.length - 1 ? 'boss' : null,
        seeds: seeds.sublist(0, 4),
        starts: 2,
        lanes: 3,
        dropMin: 3,
        dropMax: 6,
        displacements: 200,
        targetWinRate: 0.6,
        winRange: (0.4, 1),
        options: _v3,
      ),
    );
  }
  // 중급: 시작 지점 1곳, 물방울 1~4. 10레벨마다 숨 돌리기, 마지막(80) 보스.
  for (var i = 0; i < mid.length; i++) {
    final art = mid[i];
    final breather = i % 10 == 4;
    final boss = i == mid.length - 1;
    levels.add(
      breather
          ? LevelSpec(
              art: art,
              band: 'mid',
              role: 'breather',
              seeds: seeds.sublist(0, 4),
              starts: 2,
              lanes: 3,
              dropMin: 3,
              dropMax: 6,
              displacements: 100,
              targetWinRate: 0.6,
              winRange: (0.4, 1),
              options: _v3,
            )
          : LevelSpec(
              art: art,
              band: 'mid',
              role: boss ? 'boss' : null,
              seeds: seeds,
              starts: 1,
              lanes: 3,
              dropMin: 1,
              dropMax: 4,
              targetWinRate: 0.3,
              winRange: (0.2, 0.45),
              options: _v3,
            ),
    );
  }
  // 상급: 해상도 2배 그림 + 가장 큰 그림, 대기열 3~4줄. 마지막(120)은 가장 큰 그림.
  final hard = <({String art, int? variant, int scale})>[
    for (final art in hardRepeat) (art: art, variant: 2, scale: 2),
    for (final art in hardUnique) (art: art, variant: null, scale: 1),
  ];
  final last = hard.removeAt(hard.indexWhere((h) => h.art == hardUnique.last));
  hard.add(last);
  for (var i = 0; i < hard.length; i++) {
    final (:art, :variant, :scale) = hard[i];
    final breather = i % 10 == 4;
    final lanes = i % 3 == 2 ? 4 : 3;
    levels.add(
      breather
          ? LevelSpec(
              art: art,
              variant: variant,
              scale: scale,
              band: 'hard',
              role: 'breather',
              seeds: seeds.sublist(0, 4),
              starts: 2,
              lanes: 3,
              dropMin: 3,
              dropMax: 6,
              displacements: 100,
              targetWinRate: 0.5,
              winRange: (0.3, 1),
              options: _v3,
            )
          : LevelSpec(
              art: art,
              variant: variant,
              scale: scale,
              band: 'hard',
              role: i == hard.length - 1 ? 'boss' : null,
              seeds: seeds,
              starts: 1,
              lanes: lanes,
              dropMin: 1,
              dropMax: scale > 1 ? 4 : 3,
              targetWinRate: 0.08,
              winRange: (0.02, 0.16),
              options: _v3,
            ),
    );
  }

  stdout.writeln(
    'levels: ${levels.length} (tutorial ${tutorial.length}, intro ${intro.length}, '
    'mid ${mid.length}, hard ${hard.length})',
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
