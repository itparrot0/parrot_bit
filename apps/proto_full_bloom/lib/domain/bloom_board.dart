import 'bloom_color.dart';
import 'bloom_level.dart';
import 'cell.dart';
import 'cell_pos.dart';
import 'watering_can.dart';

/// 한 수.
///
/// [fromLane]이 true면 레인 [index]의 맨 앞을 꺼내 빈 활성화 슬롯에 올린다
/// (올라가며 바로 재생된다). false면 주차돼 있던 활성화 슬롯 [index]의
/// 물뿌리개를 재개한다.
typedef BloomMove = ({bool fromLane, int index});

/// 되돌리기용 상태 사본.
final class _BoardSnapshot {
  _BoardSnapshot({
    required this.cells,
    required this.depth,
    required this.queue,
    required this.active,
    required this.laneIndices,
    required this.wateredCount,
  });

  final Map<CellPos, Cell> cells;
  final Map<CellPos, int> depth;
  final List<CellPos> queue;
  final List<WateringCan?> active;
  final List<int> laneIndices;
  final int wateredCount;
}

/// Garden Grow 보드의 플레이 상태와 규칙. **Flame 없이 단위 테스트한다.**
///
/// 규칙의 유일한 구현이다 — 솔버와 생성기도 이걸 그대로 쓴다 (기획서 §38·§39).
///
/// 핵심 불변식:
/// - **발아 ⟺ 보드 큐에 들어 있다.** 씨앗은 개화한 이웃이 생길 때 단 한 번
///   발아하며 그때 큐에 들어가고, 개화할 때 큐에서 나온다.
/// - **색깔별 물 횟수 = 색깔별 칸 수** ([BloomLevel]이 검사). 그래서 물이
///   모자라 지는 길은 없고, 지는 길은 교착(둘 수 있는 수가 없음) 하나뿐이다.
///
/// 물뿌리개 선택 구조 (2026-10-10 확정):
/// - **레인 여러 줄** — 각 레인은 맨 앞만 꺼낼 수 있다. 묻힌 물뿌리개를
///   꺼내려면 앞을 먼저 써야 한다 (기획서 §8의 자유 선택 + Colony Flow의
///   줄 세우기).
/// - **활성화 슬롯** — 꺼낸 물뿌리개가 재생되는 자리. 대상이 없어 멈추면
///   **남은 횟수를 든 채 여기 주차**되고, 소진돼야 비워진다. 주차가 슬롯을
///   막는 것이 이 게임의 긴장이다.
class BloomBoard {
  BloomBoard(this.level) {
    _reset();
  }

  final BloomLevel level;

  final Map<CellPos, Cell> _cells = {};

  /// 시작 지점에서 몇 번째 고리인가. 시작 지점이 0, 그 이웃이 1.
  ///
  /// "하·좌·우·상 한 싸이클"이 곧 고리 하나다. 연출이 고리 단위로 묶여
  /// 터지게 하고(원형 확장), 기획서 §13의 Chain Depth 지표도 여기서 나온다.
  final Map<CellPos, int> _depth = {};

  /// 다음에 피울 후보들. **앞에서 꺼내고 뒤에 넣는다** (너비 우선).
  final List<CellPos> _queue = [];

  /// 활성화 슬롯. null은 빈 슬롯.
  final List<WateringCan?> _active = [];

  /// 레인별로 몇 개를 꺼냈나.
  final List<int> _laneIndices = [];

  final List<_BoardSnapshot> _history = [];

  /// 쓴 물의 총 횟수. 통계 표시용.
  int wateredCount = 0;

  // ── 조회: 보드 ────────────────────────────────────────────────────────

  Cell? cellAt(CellPos pos) => _cells[pos];

  /// [pos]의 고리 번호. 아직 깨어나지 않은 씨앗은 null.
  int? depthOf(CellPos pos) => _depth[pos];

  /// 지금까지 개화가 뻗어나간 고리 수 (기획서 §13 Chain Depth).
  int get chainDepth {
    var deepest = 0;
    _cells.forEach((pos, cell) {
      final depth = _depth[pos];
      if (cell.isBloomed && depth != null && depth > deepest) {
        deepest = depth;
      }
    });
    return deepest;
  }

  /// 칸 상태 스냅샷.
  Map<CellPos, Cell> get cells => Map.unmodifiable(_cells);

  /// 발아 큐 (앞이 다음 차례).
  List<CellPos> get queue => List.unmodifiable(_queue);

  // ── 조회: 물뿌리개 ────────────────────────────────────────────────────

  List<WateringCan?> get activeSlots => List.unmodifiable(_active);

  int get laneCount => level.lanes.length;

  /// 레인 [lane]에 남은 물뿌리개 (앞이 다음 차례).
  List<CanSpec> remainingLane(int lane) =>
      List.unmodifiable(level.lanes[lane].sublist(_laneIndices[lane]));

  CanSpec? laneFront(int lane) {
    final remaining = level.lanes[lane];
    final index = _laneIndices[lane];
    return index < remaining.length ? remaining[index] : null;
  }

  /// 레인 [lane]에서 **보이는** 앞부분 (laneRevealCount개까지).
  List<CanSpec> visibleLane(int lane) =>
      remainingLane(lane).take(level.laneRevealCount).toList();

  /// 레인 [lane]에서 가려진 물뿌리개 수.
  int hiddenLaneCount(int lane) {
    final hidden = remainingLane(lane).length - level.laneRevealCount;
    return hidden > 0 ? hidden : 0;
  }

  bool get hasFreeActiveSlot => _active.contains(null);

  /// 레인 [lane]의 앞을 꺼낼 수 있는가 — 레인이 비지 않았고 빈 슬롯이 있다.
  ///
  /// **색이 당장 쓸 수 없어도 꺼낼 수 있다.** 꺼내면 주차되고 레인이
  /// 전진하므로, 묻힌 물뿌리개를 파내는 수가 된다.
  bool canTakeFromLane(int lane) =>
      lane >= 0 &&
      lane < laneCount &&
      laneFront(lane) != null &&
      hasFreeActiveSlot;

  /// 활성화 슬롯 [slot]의 물뿌리개를 재개할 수 있는가 — 큐에 같은 색 발아가 있다.
  bool canUseActive(int slot) {
    if (slot < 0 || slot >= _active.length) {
      return false;
    }
    final can = _active[slot];
    return can != null && nextTargetFor(can.color) != null;
  }

  /// 지금 둘 수 있는 모든 수.
  List<BloomMove> get availableMoves => [
    for (var slot = 0; slot < _active.length; slot++)
      if (canUseActive(slot)) (fromLane: false, index: slot),
    for (var lane = 0; lane < laneCount; lane++)
      if (canTakeFromLane(lane)) (fromLane: true, index: lane),
  ];

  bool get canUndo => _history.isNotEmpty;

  bool get isWon => _cells.values.every((cell) => cell.isBloomed);

  /// 교착 — 둘 수 있는 수가 하나도 없다.
  ///
  /// 색깔별 정확 일치 덕에 물이 모자라 지는 길은 없다. 주차된 물뿌리개가
  /// 전부 대상이 없고, 빈 슬롯이 없거나 레인이 다 비어 레인도 못 꺼내는
  /// 상태 — **지는 길은 이것 하나뿐이다.**
  bool get isDeadlocked => !isWon && availableMoves.isEmpty;

  /// 솔버의 메모이제이션 키.
  ///
  /// 색 배치는 레벨이 고정하므로 변하는 것만 담는다 — 개화한 칸, 큐 **순서**,
  /// 활성화 슬롯 내용(슬롯끼리는 대칭이라 정렬해 동치를 묶는다), 레인 진행도.
  String get stateKey {
    final bloomed =
        (_cells.entries
                .where((entry) => entry.value.isBloomed)
                .map((entry) => '${entry.key.col},${entry.key.row}')
                .toList()
              ..sort())
            .join(';');
    final queued = _queue.map((pos) => '${pos.col},${pos.row}').join(';');
    final parked =
        (_active
                .map(
                  (can) =>
                      can == null ? '-' : '${can.color.index}x${can.remaining}',
                )
                .toList()
              ..sort())
            .join(';');
    return '$bloomed|$queued|$parked|${_laneIndices.join(',')}';
  }

  /// [color] 물뿌리개가 다음에 피울 칸. 없으면 null.
  ///
  /// **큐를 앞에서 훑어 처음 만나는 같은 색**을 고른다 — 색이 안 맞는 칸은
  /// 건너뛰므로 색마다 자기 순서가 따로 보인다.
  CellPos? nextTargetFor(BloomColor color) {
    for (final pos in _queue) {
      if (_cells[pos]?.color == color) {
        return pos;
      }
    }
    return null;
  }

  /// [color]가 피울 칸들을 큐 순서대로 (최대 [limit]개). UI 미리보기용.
  List<CellPos> previewTargets(BloomColor color, int limit) => [
    for (final pos in _queue)
      if (_cells[pos]?.color == color) pos,
  ].take(limit).toList();

  // ── 조작 ──────────────────────────────────────────────────────────────

  /// 레인 [lane]의 맨 앞을 꺼내 빈 활성화 슬롯에 올리고 바로 재생한다.
  /// **개화한 칸을 순서대로** 반환한다 (대상이 없어 바로 주차되면 빈 목록).
  List<CellPos> takeFromLane(int lane) {
    if (!canTakeFromLane(lane)) {
      return const [];
    }
    _pushHistory();

    final spec = laneFront(lane)!;
    _laneIndices[lane]++;
    final slot = _active.indexOf(null);
    _active[slot] = WateringCan(color: spec.color, count: spec.count);
    return _play(slot);
  }

  /// 주차된 활성화 슬롯 [slot]의 물뿌리개를 재개한다.
  List<CellPos> useActive(int slot) {
    if (!canUseActive(slot)) {
      return const [];
    }
    _pushHistory();
    return _play(slot);
  }

  List<CellPos> applyMove(BloomMove move) =>
      move.fromLane ? takeFromLane(move.index) : useActive(move.index);

  /// 한 수 되돌리기 (프로토타입은 무제한).
  bool undo() {
    if (_history.isEmpty) {
      return false;
    }
    _applySnapshot(_history.removeLast());
    return true;
  }

  void restart() {
    _reset();
  }

  // ── 내부 ──────────────────────────────────────────────────────────────

  /// 슬롯 [slot]의 물뿌리개를 쓸 수 있는 동안 계속 쓴다.
  ///
  /// 남은 횟수가 0이 되면 슬롯을 비우고, 대상이 없어 멈추면 **남은 횟수를
  /// 든 채 주차**시킨다 — 버려지는 물은 없다.
  List<CellPos> _play(int slot) {
    final can = _active[slot]!;
    final bloomed = <CellPos>[];
    while (!can.isEmpty) {
      final target = nextTargetFor(can.color);
      if (target == null) {
        break;
      }
      _bloom(target);
      can.spendOne();
      wateredCount++;
      bloomed.add(target);
    }
    if (can.isEmpty) {
      _active[slot] = null;
    }
    return bloomed;
  }

  /// [pos]를 개화시키고 이웃 씨앗을 깨워 큐에 넣는다.
  void _bloom(CellPos pos) {
    _queue.remove(pos);
    _cells[pos] = _cells[pos]!.bloomedCell;

    for (final neighbor in neighborsInOrder(pos)) {
      final cell = _cells[neighbor];
      // 빈칸·발아·개화는 건너뛴다. 씨앗만 깨어나며, 그 전이가 한 번뿐이라
      // 큐 중복 삽입이 구조적으로 막힌다.
      if (cell == null || !cell.isSeed) {
        continue;
      }
      _cells[neighbor] = cell.sprouted;
      _depth[neighbor] = (_depth[pos] ?? 0) + 1;
      _queue.add(neighbor);
    }
  }

  void _reset() {
    _cells
      ..clear()
      ..addAll({
        for (final entry in level.colors.entries)
          entry.key: Cell.seed(entry.value),
      });
    _depth.clear();
    _queue.clear();
    _history.clear();
    wateredCount = 0;
    _laneIndices
      ..clear()
      ..addAll(List.filled(level.lanes.length, 0));
    _active
      ..clear()
      ..addAll(List.filled(level.activeSlotCount, null));

    // 시작 지점만 발아로 시작하고, 그 순서가 큐의 초기 내용이 된다.
    for (final start in level.startPoints) {
      _cells[start] = Cell.sprout(level.colors[start]!);
      _depth[start] = 0;
      _queue.add(start);
    }
  }

  void _pushHistory() {
    _history.add(
      _BoardSnapshot(
        cells: Map.of(_cells),
        depth: Map.of(_depth),
        queue: List.of(_queue),
        active: [for (final can in _active) can?.copy()],
        laneIndices: List.of(_laneIndices),
        wateredCount: wateredCount,
      ),
    );
  }

  void _applySnapshot(_BoardSnapshot snapshot) {
    _cells
      ..clear()
      ..addAll(snapshot.cells);
    _depth
      ..clear()
      ..addAll(snapshot.depth);
    _queue
      ..clear()
      ..addAll(snapshot.queue);
    _active
      ..clear()
      ..addAll(snapshot.active);
    _laneIndices
      ..clear()
      ..addAll(snapshot.laneIndices);
    wateredCount = snapshot.wateredCount;
  }
}
