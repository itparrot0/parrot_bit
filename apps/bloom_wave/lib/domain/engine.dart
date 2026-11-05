// Bloom Wave 규칙 엔진 (규칙 v3 — 2026-11-04 대기열 여러 줄)
// 렌더링/입력과 무관한 순수 Dart 로직이며, 앱과 레벨 생성기(tool/levelgen)가 이 파일을 공유한다.
// Flutter 를 import 하지 않는다 — `dart run` 으로 도는 생성기가 그대로 쓴다.
//
// 규칙 요약 (docs/01_게임기획서.md 4장, docs/00_규칙_확인_질문.md)
//  - 대기열은 여러 줄(레인, 출시 레벨은 3줄 이상)이다. 플레이어는 아무 줄이나 그 줄의 맨 앞 물방울을 탭한다.
//    탭한 물방울은 빈 활성 슬롯으로 이동한다(쓸 수 있는지와 무관).
//  - 웨이브가 진행 중일 때도 탭할 수 있다(realtime). 틱 사이 "어느 줄을, 언제" 넣느냐가 플레이어의 선택이다.
//  - 활성 슬롯의 물방울은 자동으로 동작한다. 한 틱에 "한 링"씩 퍼진다.
//    링 = 그 물방울과 같은 색인 발아 칸 전체 (발아한 순서대로). 남은 양만큼만 개화.
//  - 개화한 칸은 8방향(남동>남>남서>서>북서>북>북동>동)의 씨앗을 색과 상관없이 발아시킨다.
//  - 물방울은 발아 칸에만 소모된다. 양이 남으면 슬롯에 남아 다음 틱에 다음 링을 다시 계산한다.
//  - 슬롯의 어떤 물방울도 더 퍼질 수 없으면 "안정" 상태. 이때 슬롯이 모두 차 있으면 실패.

import 'dart:typed_data';

const int empty = -1; // 투명 픽셀 (칸 없음)
const int seed = 0; // 씨앗 (-)
const int sprout = 1; // 발아 (*)
const int bloom = 2; // 개화 (@)

class Drop {
  Drop(this.color, this.amount);
  final int color;
  int amount;

  Drop copy() => Drop(color, amount);

  factory Drop.fromJson(Map<String, dynamic> j) =>
      Drop(j['color'] as int, j['amount'] as int);
  Map<String, dynamic> toJson() => {'color': color, 'amount': amount};

  @override
  bool operator ==(Object other) =>
      other is Drop && other.color == color && other.amount == amount;
  @override
  int get hashCode => Object.hash(color, amount);
  @override
  String toString() => 'Drop($color:$amount)';
}

enum Difficulty {
  normal,
  hard,
  superHard,
  megaHard;

  static Difficulty parse(String s) =>
      Difficulty.values.firstWhere((d) => d.name == s);
}

class Options {
  const Options({this.realtime = true, this.visible = 3});

  /// 웨이브가 진행 중일 때도 탭할 수 있나 (기본 true)
  final bool realtime;

  /// 줄마다 앞에서 몇 개까지 보여 주나 (표시 전용, 규칙에는 영향 없음)
  final int visible;
}

const Options defaultOptions = Options();

/// 비교·튜토리얼용: 웨이브가 멈춘 뒤에만 탭
const Options turnBased = Options(realtime: false, visible: 3);

class LevelName {
  const LevelName(this.ko, this.en);
  final String ko;
  final String en;
  String of(String lang) => lang == 'ko' ? ko : en;
}

/// 생성기가 기록한 난이도 지표 (규칙에는 영향 없음)
class LevelMeta {
  const LevelMeta({
    required this.score,
    required this.difficulty,
    required this.peakSlots,
    required this.avgSlots,
    required this.randomWinRate,
    required this.solverNodes,
    this.art,
    this.scale,
    this.name,
  });
  final int score;
  final Difficulty difficulty;
  final int peakSlots;
  final num avgSlots;
  final num randomWinRate;
  final int solverNodes;
  final String? art;
  final int? scale; // 그림 해상도 배율 (1 = 원본)
  final LevelName? name;

  factory LevelMeta.fromJson(Map<String, dynamic> j) {
    final n = j['name'] as Map<String, dynamic>?;
    return LevelMeta(
      score: j['score'] as int,
      difficulty: Difficulty.parse(j['difficulty'] as String),
      peakSlots: j['peakSlots'] as int,
      avgSlots: j['avgSlots'] as num,
      randomWinRate: j['randomWinRate'] as num,
      solverNodes: j['solverNodes'] as int,
      art: j['art'] as String?,
      scale: j['scale'] as int?,
      name: n == null ? null : LevelName(n['ko'] as String, n['en'] as String),
    );
  }

  /// 키 순서는 TS 버전과 같다 (팩 파일이 바이트 단위로 같아지도록)
  Map<String, dynamic> toJson() => {
    'score': score,
    'difficulty': difficulty.name,
    'peakSlots': peakSlots,
    'avgSlots': avgSlots,
    'randomWinRate': randomWinRate,
    'solverNodes': solverNodes,
    if (art != null) 'art': art,
    if (scale != null) 'scale': scale,
    if (name != null) 'name': {'ko': name!.ko, 'en': name!.en},
  };
}

class Level {
  const Level({
    required this.id,
    required this.width,
    required this.height,
    required this.palette,
    required this.cells,
    required this.starts,
    required this.lanes,
    this.slotCount = 4,
    this.realtime,
    this.visible,
    this.meta,
  });

  final String id;
  final int width;
  final int height;

  /// 색상 인덱스 -> 표시용 HEX
  final List<String> palette;

  /// 칸별 색상 인덱스, 빈 칸은 [empty]
  final List<int> cells;

  /// 시작 발아 칸 인덱스 (이 순서가 첫 발아 순서)
  final List<int> starts;

  /// 대기열 줄들 (각 줄은 앞에서부터)
  final List<List<Drop>> lanes;

  /// 활성 슬롯 수 (기본 4)
  final int slotCount;

  /// 레벨별 규칙 옵션 덮어쓰기 (null 이면 기본값)
  final bool? realtime;
  final int? visible;
  final LevelMeta? meta;

  Options get options => Options(
    realtime: realtime ?? defaultOptions.realtime,
    visible: visible ?? defaultOptions.visible,
  );

  Level copyWith({List<List<Drop>>? lanes, List<int>? starts, String? id}) =>
      Level(
        id: id ?? this.id,
        width: width,
        height: height,
        palette: palette,
        cells: cells,
        starts: starts ?? this.starts,
        lanes: lanes ?? this.lanes,
        slotCount: slotCount,
        realtime: realtime,
        visible: visible,
        meta: meta,
      );

  factory Level.fromJson(Map<String, dynamic> j) {
    final opt = j['options'] as Map<String, dynamic>?;
    return Level(
      id: j['id'] as String,
      width: j['width'] as int,
      height: j['height'] as int,
      palette: (j['palette'] as List).cast<String>(),
      cells: (j['cells'] as List).cast<int>(),
      starts: (j['starts'] as List).cast<int>(),
      lanes: [
        for (final l in j['lanes'] as List)
          [for (final d in l as List) Drop.fromJson(d as Map<String, dynamic>)],
      ],
      slotCount: (j['slotCount'] as int?) ?? 4,
      realtime: opt?['realtime'] as bool?,
      visible: opt?['visible'] as int?,
      meta: j['meta'] == null
          ? null
          : LevelMeta.fromJson(j['meta'] as Map<String, dynamic>),
    );
  }

  /// 키 순서는 TS 버전과 같다
  Map<String, dynamic> toJson() => {
    'id': id,
    'width': width,
    'height': height,
    'palette': palette,
    'cells': cells,
    'starts': starts,
    'lanes': [
      for (final l in lanes) [for (final d in l) d.toJson()],
    ],
    'slotCount': slotCount,
    if (visible != null || realtime != null)
      'options': {'visible': ?visible, 'realtime': ?realtime},
    if (meta != null) 'meta': meta!.toJson(),
  };
}

enum Status { playing, cleared, failed }

sealed class Action {
  const Action();
}

class Deploy extends Action {
  const Deploy(this.lane);
  final int lane;
  @override
  bool operator ==(Object other) => other is Deploy && other.lane == lane;
  @override
  int get hashCode => lane.hashCode;
  @override
  String toString() => 'd$lane';
}

class Tick extends Action {
  const Tick();
  @override
  bool operator ==(Object other) => other is Tick;
  @override
  int get hashCode => 0;
  @override
  String toString() => 't';
}

class State {
  State({
    required this.cell,
    required this.seq,
    required this.bornTick,
    required this.nextSeq,
    required this.tick,
    required this.sproutCount,
    required this.remaining,
    required this.lanes,
    required this.slots,
    required this.status,
  });

  /// 칸별 상태 (empty/seed/sprout/bloom)
  final Int8List cell;

  /// 발아한 순서 (링 안의 개화 순서를 정함)
  final Int32List seq;

  /// 발아한 틱. 이번 틱에 막 발아한 칸은 다음 틱 링부터 포함
  final Int32List bornTick;
  int nextSeq;
  int tick;

  /// 색상별 발아 칸 수
  final Int32List sproutCount;

  /// 아직 개화하지 않은 칸 수
  int remaining;

  /// 남은 대기열 줄들
  List<List<Drop>> lanes;
  final List<Drop?> slots;
  Status status;

  State clone() => State(
    cell: Int8List.fromList(cell),
    seq: Int32List.fromList(seq),
    bornTick: Int32List.fromList(bornTick),
    nextSeq: nextSeq,
    tick: tick,
    sproutCount: Int32List.fromList(sproutCount),
    remaining: remaining,
    lanes: [
      for (final l in lanes) [for (final d in l) d.copy()],
    ],
    slots: [for (final d in slots) d?.copy()],
    status: status,
  );

  int get occupied => slots.where((d) => d != null).length;
}

/// 한 슬롯이 이번 링에서 피운 칸들
class SlotBloom {
  const SlotBloom(this.slot, this.color, this.cells);
  final int slot;
  final int color;
  final List<int> cells;
}

/// 한 틱의 애니메이션 프레임: 슬롯별로 이번 링에서 개화한 칸들, 그리고 새로 발아한 칸들
class TickEvent {
  TickEvent(this.tick);
  final int tick;
  final List<SlotBloom> blooms = [];
  final List<int> sprouted = [];

  /// 이번 틱에 다 써서 비워진 슬롯
  final List<int> emptied = [];
}

/// "8방향 사이클": 남동에서 시작해 시계 방향으로 한 바퀴
const List<(int, int)> dir8 = [
  (1, 1),
  (0, 1),
  (-1, 1),
  (-1, 0),
  (-1, -1),
  (0, -1),
  (1, -1),
  (1, 0),
];

int queueLength(List<List<Drop>> lanes) =>
    lanes.fold(0, (n, l) => n + l.length);

State createState(Level level) {
  final n = level.width * level.height;
  final cell = Int8List(n);
  final seq = Int32List(n)..fillRange(0, n, -1);
  final bornTick = Int32List(n)..fillRange(0, n, -1);
  final sproutCount = Int32List(level.palette.length);
  var remaining = 0;
  for (var i = 0; i < n; i++) {
    if (level.cells[i] == empty) {
      cell[i] = empty;
    } else {
      cell[i] = seed;
      remaining++;
    }
  }
  var nextSeq = 0;
  for (final s in level.starts) {
    if (cell[s] == seed) {
      cell[s] = sprout;
      seq[s] = nextSeq++;
      sproutCount[level.cells[s]]++;
    }
  }
  final s = State(
    cell: cell,
    seq: seq,
    bornTick: bornTick,
    nextSeq: nextSeq,
    tick: 0,
    sproutCount: sproutCount,
    remaining: remaining,
    lanes: [
      for (final l in level.lanes) [for (final d in l) d.copy()],
    ],
    slots: List<Drop?>.filled(
      level.slotCount,
      null,
      growable: true,
    ), // 아이템으로 늘어날 수 있다
    status: Status.playing,
  );
  _judge(s);
  return s;
}

/// 슬롯 물방울 중 하나라도 퍼질 칸이 있으면 웨이브 진행 중
bool isActive(State s) {
  for (final d in s.slots) {
    if (d != null && d.amount > 0 && s.sproutCount[d.color] > 0) return true;
  }
  return false;
}

void _judge(State s) {
  if (s.remaining == 0) {
    s.status = Status.cleared;
    return;
  }
  if (isActive(s)) {
    s.status = Status.playing;
    return;
  }
  final hasEmpty = s.slots.contains(null);
  // 안정 상태에서 슬롯이 꽉 찼거나, 더 넣을 물방울이 없으면 실패
  s.status = !hasEmpty || queueLength(s.lanes) == 0
      ? Status.failed
      : Status.playing;
}

List<Action> legalActions(State s, [Options opt = defaultOptions]) {
  if (s.status != Status.playing) return const [];
  final out = <Action>[];
  final active = isActive(s);
  if (s.slots.contains(null) && (!active || opt.realtime)) {
    for (var i = 0; i < s.lanes.length; i++) {
      if (s.lanes[i].isNotEmpty) out.add(Deploy(i));
    }
  }
  if (active) out.add(const Tick());
  return out;
}

/// lane 번째 줄의 맨 앞 물방울을 첫 빈 슬롯으로 옮긴다 (쓸 수 있는지와 무관). 들어간 슬롯 번호를 돌려준다
int deploy(Level level, State s, [int lane = 0]) {
  final slot = s.slots.indexOf(null);
  if (slot < 0) throw StateError('no empty slot');
  if (lane < 0 || lane >= s.lanes.length || s.lanes[lane].isEmpty) {
    throw StateError('no drop in lane');
  }
  s.slots[slot] = s.lanes[lane].removeAt(0);
  _judge(s);
  return slot;
}

/// 한 틱: 슬롯 순서대로 각 물방울이 한 링씩 퍼진다
TickEvent tick(Level level, State s) {
  final w = level.width, h = level.height, cells = level.cells;
  final t = s.tick;
  final ev = TickEvent(t);
  for (var si = 0; si < s.slots.length; si++) {
    final d = s.slots[si];
    if (d == null || d.amount <= 0 || s.sproutCount[d.color] == 0) continue;
    // 링: 같은 색 발아 칸 중 이번 틱 이전에 발아한 칸, 발아 순서대로
    final ring = <int>[];
    for (var i = 0; i < s.cell.length; i++) {
      if (s.cell[i] == sprout && cells[i] == d.color && s.bornTick[i] < t) {
        ring.add(i);
      }
    }
    ring.sort((a, b) => s.seq[a] - s.seq[b]);
    final bloomed = ring.length > d.amount ? ring.sublist(0, d.amount) : ring;
    for (final i in bloomed) {
      s.cell[i] = bloom;
      s.sproutCount[d.color]--;
      s.remaining--;
      final x = i % w, y = i ~/ w;
      for (final (dx, dy) in dir8) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final j = ny * w + nx;
        if (s.cell[j] == seed) {
          s.cell[j] = sprout;
          s.seq[j] = s.nextSeq++;
          s.bornTick[j] = t;
          s.sproutCount[cells[j]]++;
          ev.sprouted.add(j);
        }
      }
    }
    d.amount -= bloomed.length;
    if (bloomed.isNotEmpty) ev.blooms.add(SlotBloom(si, d.color, bloomed));
    if (d.amount == 0) {
      s.slots[si] = null;
      ev.emptied.add(si);
    }
  }
  s.tick++;
  _judge(s);
  return ev;
}

/// 안정될 때까지 틱을 돌린다. 이번 틱에 막 발아한 칸은 다음 틱 링에 들어가므로 항상 진행이 있다.
List<TickEvent> runUntilStable(Level level, State s) {
  final evs = <TickEvent>[];
  while (s.status == Status.playing && isActive(s)) {
    evs.add(tick(level, s));
  }
  return evs;
}

List<TickEvent> applyAction(
  Level level,
  State s,
  Action a, [
  Options opt = defaultOptions,
]) {
  if (s.status != Status.playing) throw StateError('game is over');
  switch (a) {
    case Tick():
      if (!isActive(s)) throw StateError('nothing to tick');
      return [tick(level, s)];
    case Deploy(:final lane):
      if (isActive(s) && !opt.realtime) {
        throw StateError('wait for the wave to finish');
      }
      deploy(level, s, lane);
      return opt.realtime ? const [] : runUntilStable(level, s);
  }
}

// ───────── 아이템 효과 (2026-11-04) ─────────
// 규칙을 바꾸는 효과는 여기(엔진)에 둔다. 화면은 결과만 그린다.

/// 활성 슬롯 1칸 추가 (이번 판만). 실패 판정을 다시 한다
void addSlot(State s) {
  s.slots.add(null);
  _judge(s);
}

/// 대기열의 남은 물방울을 줄과 상관없이 모두 섞어 다시 나눠 담는다 (줄마다 개수는 그대로, 맨 앞 포함)
void shuffleLanes(State s, int Function(int max) nextInt) {
  final all = [for (final l in s.lanes) ...l];
  for (var i = all.length - 1; i > 0; i--) {
    final j = nextInt(i + 1);
    final t = all[i];
    all[i] = all[j];
    all[j] = t;
  }
  var k = 0;
  s.lanes = [
    for (final l in s.lanes) [for (var n = 0; n < l.length; n++) all[k++]],
  ];
  _judge(s);
}

/// 지금 퍼질 수 없는(같은 색 발아 칸이 없는) 물방울이 든 슬롯 번호들
List<int> stuckSlots(State s) => [
  for (var i = 0; i < s.slots.length; i++)
    if (s.slots[i] != null &&
        s.slots[i]!.amount > 0 &&
        s.sproutCount[s.slots[i]!.color] == 0)
      i,
];

/// slot 의 물방울이 바닥날 때까지 같은 색의 아직 피지 않은 칸을 무작위로 골라 즉시 개화시킨다.
/// 개화한 칸은 보통 규칙대로 8방향 씨앗을 발아시킨다. 물방울 총량 = 칸 수라 늘 칸이 충분하다.
/// 반환: 개화한 칸 순서와 새로 발아한 칸 (연출용)
TickEvent forceBloom(
  Level level,
  State s,
  int slot,
  int Function(int max) nextInt,
) {
  final d = s.slots[slot];
  if (d == null) throw StateError('empty slot');
  final ev = TickEvent(s.tick);
  final w = level.width, h = level.height, cells = level.cells;
  final bloomed = <int>[];
  while (d.amount > 0) {
    final cand = [
      for (var i = 0; i < s.cell.length; i++)
        if (cells[i] == d.color && (s.cell[i] == seed || s.cell[i] == sprout))
          i,
    ];
    if (cand.isEmpty) break;
    final i = cand[nextInt(cand.length)];
    if (s.cell[i] == sprout) s.sproutCount[d.color]--;
    s.cell[i] = bloom;
    s.remaining--;
    d.amount--;
    bloomed.add(i);
    final x = i % w, y = i ~/ w;
    for (final (dx, dy) in dir8) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final j = ny * w + nx;
      if (s.cell[j] == seed) {
        s.cell[j] = sprout;
        s.seq[j] = s.nextSeq++;
        s.bornTick[j] = s.tick - 1; // 다음 틱 링부터 바로 들어간다
        s.sproutCount[cells[j]]++;
        ev.sprouted.add(j);
      }
    }
  }
  if (bloomed.isNotEmpty) ev.blooms.add(SlotBloom(slot, d.color, bloomed));
  if (d.amount == 0) {
    s.slots[slot] = null;
    ev.emptied.add(slot);
  }
  _judge(s);
  return ev;
}

/// 실패 상태 메모용 키. 발아 칸의 상대 순서와 "막 발아함" 여부가 이후 결과를 바꾸므로 키에 포함
String stateKey(State s) {
  final sprouts = <int>[];
  for (var i = 0; i < s.cell.length; i++) {
    if (s.cell[i] == sprout) sprouts.add(i);
  }
  sprouts.sort((a, b) => s.seq[a] - s.seq[b]);
  final b = StringBuffer();
  for (var i = 0; i < s.cell.length; i++) {
    b.writeCharCode(s.cell[i] + 66);
  }
  b.write('|');
  for (var k = 0; k < sprouts.length; k++) {
    final i = sprouts[k];
    if (k > 0) b.write(',');
    b.write(i);
    if (s.bornTick[i] == s.tick - 1) b.write("'");
  }
  b.write('|');
  for (var k = 0; k < s.lanes.length; k++) {
    if (k > 0) b.write('.');
    b.write(s.lanes[k].length);
  }
  b.write('|');
  for (var k = 0; k < s.slots.length; k++) {
    if (k > 0) b.write(',');
    final d = s.slots[k];
    b.write(d == null ? '_' : '${d.color}:${d.amount}');
  }
  return b.toString();
}

/// 디버그용 텍스트 렌더: 색상은 a,b,c..., 상태는 - * @
String render(Level level, State s) {
  final rows = <String>[];
  for (var y = 0; y < level.height; y++) {
    final row = StringBuffer();
    for (var x = 0; x < level.width; x++) {
      final i = y * level.width + x;
      final c = s.cell[i];
      row.write(
        c == empty
            ? ' . '
            : '${String.fromCharCode(97 + level.cells[i])}${'-*@'[c]} ',
      );
    }
    rows.add(row.toString());
  }
  String fmt(Drop? d) =>
      d == null ? '__' : '${String.fromCharCode(97 + d.color)}${d.amount}';
  rows.add(
    'slots[${s.slots.map(fmt).join(' ')}]  lanes: '
    '${s.lanes.map((l) => l.isEmpty ? '-' : l.map(fmt).join(' ')).join(' | ')}  status=${s.status.name}',
  );
  return rows.join('\n');
}
