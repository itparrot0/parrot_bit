// levels.config.json 의 형태 (TS config.ts 와 같은 키)
import 'package:bloom_wave/domain/engine.dart';

/// `tutorial` | `intro` | `mid` | `hard`
typedef Band = String;

/// 레벨별 규칙 옵션 덮어쓰기 (TS 의 `Partial<Options>`)
class PartialOptions {
  const PartialOptions({this.realtime, this.visible});
  final bool? realtime;
  final int? visible;

  factory PartialOptions.fromJson(Map<String, dynamic>? j) => PartialOptions(
    realtime: j?['realtime'] as bool?,
    visible: j?['visible'] as int?,
  );

  /// {...base, ...this}
  Options over(Options base) => Options(
    realtime: realtime ?? base.realtime,
    visible: visible ?? base.visible,
  );

  Map<String, dynamic> toJson() => {'realtime': ?realtime, 'visible': ?visible};
}

class LevelSpec {
  const LevelSpec({
    required this.art,
    this.variant,
    required this.band,
    this.role,
    this.tutorial,
    required this.seeds,
    required this.starts,
    required this.lanes,
    this.scale,
    required this.dropMin,
    required this.dropMax,
    required this.targetWinRate,
    required this.winRange,
    this.displacements,
    this.options,
    this.difficulty,
    this.mystery = false,
  });

  /// `art/<art>.png`
  final String art;

  /// 같은 그림의 두 번째 레벨이면 2 (id: `<art>-2`)
  final int? variant;
  final Band band;

  /// "breather" | "boss"
  final String? role;

  /// 앱이 보여 줄 튜토리얼 안내 키
  final String? tutorial;

  /// 시드 여러 개를 돌려 목표에 가장 가까운 결과를 고른다
  final List<int> seeds;
  final int starts;

  /// 대기열 줄 수 (3 이상)
  final int lanes;

  /// 그림 해상도 배율 (2 = 한 픽셀이 2×2 칸)
  final int? scale;
  final int dropMin;
  final int dropMax;
  final num targetWinRate;

  /// 이 구간 안의 결과를 우선 고른다
  final (num, num) winRange;
  final int? displacements;
  final PartialOptions? options;

  /// 이 난이도 등급(normal/hard/superHard/megaHard)이 나올 때까지 시드를 바꾸고, 그래도 안 나오면
  /// 물방울 크기·줄 수를 조금씩 조여(풀어) 다시 시도한다 (2026-11-04, 1000 스테이지 팩).
  /// 없으면 예전처럼 winRange 기준으로 고른다.
  final String? difficulty;

  /// "?" 물방울 스테이지 (2026-11-05): 물방울의 3%(최소 1개)를 맨 위에 오기 전까지 숨긴다
  final bool mystery;

  factory LevelSpec.fromJson(Map<String, dynamic> j) {
    final wr = j['winRange'] as List;
    return LevelSpec(
      art: j['art'] as String,
      variant: j['variant'] as int?,
      band: j['band'] as String,
      role: j['role'] as String?,
      tutorial: j['tutorial'] as String?,
      seeds: (j['seeds'] as List).cast<int>(),
      starts: j['starts'] as int,
      lanes: j['lanes'] as int,
      scale: j['scale'] as int?,
      dropMin: j['dropMin'] as int,
      dropMax: j['dropMax'] as int,
      targetWinRate: j['targetWinRate'] as num,
      winRange: (wr[0] as num, wr[1] as num),
      displacements: j['displacements'] as int?,
      options: j['options'] == null
          ? null
          : PartialOptions.fromJson(j['options'] as Map<String, dynamic>),
      difficulty: j['difficulty'] as String?,
      mystery: j['mystery'] == true,
    );
  }

  /// 키 순서는 TS make-config.ts 가 만드는 객체와 같다 (undefined 는 빠진다)
  Map<String, dynamic> toJson() => {
    'art': art,
    'variant': ?variant,
    'scale': ?scale,
    'band': band,
    'role': ?role,
    'tutorial': ?tutorial,
    'seeds': seeds,
    'starts': starts,
    'lanes': lanes,
    'dropMin': dropMin,
    'dropMax': dropMax,
    'displacements': ?displacements,
    'targetWinRate': targetWinRate,
    'winRange': [winRange.$1, winRange.$2],
    if (options != null) 'options': options!.toJson(),
    'difficulty': ?difficulty,
    if (mystery) 'mystery': true,
  };
}

class PackDefaults {
  const PackDefaults({
    required this.slotCount,
    required this.options,
    required this.displacements,
    required this.maxSolverNodes,
    required this.maxColors,
    required this.maxSize,
  });
  final int slotCount;
  final Options options;
  final int displacements;
  final int maxSolverNodes;
  final int maxColors;
  final int maxSize;

  factory PackDefaults.fromJson(Map<String, dynamic> j) => PackDefaults(
    slotCount: j['slotCount'] as int,
    options: PartialOptions.fromJson(
      j['options'] as Map<String, dynamic>?,
    ).over(defaultOptions),
    displacements: j['displacements'] as int,
    maxSolverNodes: j['maxSolverNodes'] as int,
    maxColors: j['maxColors'] as int,
    maxSize: j['maxSize'] as int,
  );

  Map<String, dynamic> toJson() => {
    'slotCount': slotCount,
    'options': {'realtime': options.realtime, 'visible': options.visible},
    'displacements': displacements,
    'maxSolverNodes': maxSolverNodes,
    'maxColors': maxColors,
    'maxSize': maxSize,
  };
}

class PackConfig {
  PackConfig({
    required this.pack,
    this.copyTo,
    required this.defaults,
    required this.levels,
  });
  final String pack;

  /// 설정 파일 기준 상대 경로. 앱이 읽는 위치로 복사
  final List<String>? copyTo;
  final PackDefaults defaults;
  List<LevelSpec> levels;

  factory PackConfig.fromJson(Map<String, dynamic> j) => PackConfig(
    pack: j['pack'] as String,
    copyTo: (j['copyTo'] as List?)?.cast<String>(),
    defaults: PackDefaults.fromJson(j['defaults'] as Map<String, dynamic>),
    levels: [
      for (final l in j['levels'] as List)
        LevelSpec.fromJson(l as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => {
    'pack': pack,
    'copyTo': ?copyTo,
    'defaults': defaults.toJson(),
    'levels': [for (final l in levels) l.toJson()],
  };
}
