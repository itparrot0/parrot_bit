import 'bloom_color.dart';
import 'bloom_level.dart';
import 'cell.dart';
import 'cell_pos.dart';
import 'watering_can.dart';

/// 되돌리기용 상태 사본.
final class _BoardSnapshot {
  _BoardSnapshot({
    required this.cells,
    required this.queue,
    required this.slots,
    required this.pendingIndex,
    required int watered,
  }) {
    wateredCount = watered;
  }

  final Map<CellPos, Cell> cells;
  final List<CellPos> queue;
  final List<WateringCan?> slots;
  final int pendingIndex;
  late final int wateredCount;
}

/// 만개 보드의 플레이 상태와 규칙. **Flame 없이 단위 테스트한다.**
///
/// 규칙의 출처는 docs/prd/full_bloom.md §3이고, 이 클래스가 그 유일한 구현이다
/// — 솔버와 생성기도 이걸 그대로 쓴다 (PRD §10).
///
/// 핵심 불변식 둘:
/// - **꽃송이 ⟺ 큐에 들어 있다.** 씨앗은 개화한 이웃이 생길 때 단 한 번
///   꽃송이가 되며 그때 큐에 들어가고, 개화할 때 큐에서 나온다.
/// - **색깔별 물 횟수 = 색깔별 칸 수** (PRD §3.7, [BloomLevel]이 검사).
class BloomBoard {
  BloomBoard(this.level) {
    _reset();
  }

  final BloomLevel level;

  final Map<CellPos, Cell> _cells = {};

  /// 다음에 피울 후보들. **앞에서 꺼내고 뒤에 넣는다** (너비 우선).
  final List<CellPos> _queue = [];

  /// 활성화 슬롯. null은 빈 슬롯.
  final List<WateringCan?> _slots = [];

  /// 대기열에서 다음에 올라올 물뿌리개의 인덱스.
  int _pendingIndex = 0;

  final List<_BoardSnapshot> _history = [];

  /// 쓴 물의 총 횟수. 통계 표시용.
  int wateredCount = 0;

  // ── 조회 ──────────────────────────────────────────────────────────────

  Cell? cellAt(CellPos pos) => _cells[pos];

  /// 칸 상태 스냅샷.
  Map<CellPos, Cell> get cells => Map.unmodifiable(_cells);

  /// 큐 내용 (앞이 다음 차례). **화면에 그대로 보여준다** — 예측 가능성이
  /// 이 게임의 전부다 (PRD §5-3).
  List<CellPos> get queue => List.unmodifiable(_queue);

  List<WateringCan?> get slots => List.unmodifiable(_slots);

  /// 아직 슬롯에 올라오지 않은 대기열.
  List<CanSpec> get pendingCans =>
      List.unmodifiable(level.cans.sublist(_pendingIndex));

  bool get canUndo => _history.isNotEmpty;

  /// 솔버의 메모이제이션 키 (PRD §4.3).
  ///
  /// 색 배치는 레벨이 고정하므로 변하는 것만 담는다 — 개화한 칸, 큐 **순서**,
  /// 슬롯 내용, 대기열 포인터. 큐는 순서가 다르면 다른 상태다.
  String get stateKey {
    final bloomed =
        (_cells.entries
                .where((entry) => entry.value.isBloomed)
                .map((entry) => '${entry.key.col},${entry.key.row}')
                .toList()
              ..sort())
            .join(';');
    final queued = _queue.map((pos) => '${pos.col},${pos.row}').join(';');
    final slotted = _slots
        .map((can) => can == null ? '-' : '${can.color.index}x${can.remaining}')
        .join(';');
    return '$bloomed|$queued|$slotted|$_pendingIndex';
  }

  bool get isWon => _cells.values.every((cell) => cell.isBloomed);

  /// 교착 — 쓸 수 있는 슬롯이 하나도 없다.
  ///
  /// 슬롯은 물뿌리개가 소진될 때만 비므로(§3.5), 쓸 수 있는 슬롯이 없으면
  /// 대기열도 영원히 나아가지 못한다. §3.7 덕에 "물 부족"으로 지는 길은 없고
  /// **지는 길은 이것 하나뿐이다** (PRD §3.8).
  bool get isDeadlocked {
    if (isWon) {
      return false;
    }
    for (var index = 0; index < _slots.length; index++) {
      if (canUseSlot(index)) {
        return false;
      }
    }
    return true;
  }

  /// 슬롯 [index]의 물뿌리개를 쓸 수 있는가 — 큐에 같은 색 꽃송이가 있는가.
  bool canUseSlot(int index) {
    if (index < 0 || index >= _slots.length) {
      return false;
    }
    final can = _slots[index];
    return can != null && !can.isEmpty && nextTargetFor(can.color) != null;
  }

  /// [color] 물뿌리개가 다음에 피울 칸. 없으면 null.
  ///
  /// **큐를 앞에서 훑어 처음 만나는 같은 색**을 고른다 — 색이 안 맞는 칸은
  /// 건너뛰므로 색마다 자기 순서가 따로 보인다 (PRD §3.4).
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

  /// 슬롯 [index]의 물뿌리개를 쓴다. **개화한 칸을 순서대로** 반환한다
  /// (연출이 순차 애니메이션을 하려면 순서가 필요하다).
  ///
  /// 남은 횟수가 0이 되거나 큐에 같은 색이 없어지면 멈춘다. 멈췄을 때 남은
  /// 횟수는 **버려지지 않고 슬롯에 남는다** (PRD §3.5).
  List<CellPos> useSlot(int index) {
    if (!canUseSlot(index)) {
      return const [];
    }
    _pushHistory();

    final can = _slots[index]!;
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

    // 소진된 물뿌리개만 슬롯을 비운다.
    if (can.isEmpty) {
      _slots[index] = _drawPending();
    }
    return bloomed;
  }

  /// 한 수 되돌리기 (PRD §3.8).
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

  /// [pos]를 개화시키고 이웃 씨앗을 깨워 큐에 넣는다.
  void _bloom(CellPos pos) {
    _queue.remove(pos);
    _cells[pos] = _cells[pos]!.bloomedCell;

    for (final neighbor in neighborsInOrder(pos)) {
      final cell = _cells[neighbor];
      // 빈칸·꽃송이·개화는 건너뛴다. 씨앗만 깨어나며, 그 전이가 한 번뿐이라
      // 큐 중복 삽입이 구조적으로 막힌다.
      if (cell == null || !cell.isSeed) {
        continue;
      }
      _cells[neighbor] = cell.awakened;
      _queue.add(neighbor);
    }
  }

  WateringCan? _drawPending() {
    if (_pendingIndex >= level.cans.length) {
      return null;
    }
    final spec = level.cans[_pendingIndex++];
    return WateringCan(color: spec.color, count: spec.count);
  }

  void _reset() {
    _cells
      ..clear()
      ..addAll({
        for (final entry in level.colors.entries)
          entry.key: Cell.seed(entry.value),
      });
    _queue.clear();
    _slots.clear();
    _history.clear();
    _pendingIndex = 0;
    wateredCount = 0;

    // 시작 지점만 꽃송이로 시작하고, 그 순서가 큐의 초기 내용이 된다.
    for (final start in level.startPoints) {
      _cells[start] = Cell.bud(level.colors[start]!);
      _queue.add(start);
    }
    for (var index = 0; index < level.slotCount; index++) {
      _slots.add(_drawPending());
    }
  }

  void _pushHistory() {
    _history.add(
      _BoardSnapshot(
        cells: Map.of(_cells),
        queue: List.of(_queue),
        slots: [for (final can in _slots) can?.copy()],
        pendingIndex: _pendingIndex,
        watered: wateredCount,
      ),
    );
  }

  void _applySnapshot(_BoardSnapshot snapshot) {
    _cells
      ..clear()
      ..addAll(snapshot.cells);
    _queue
      ..clear()
      ..addAll(snapshot.queue);
    _slots
      ..clear()
      ..addAll(snapshot.slots);
    _pendingIndex = snapshot.pendingIndex;
    wateredCount = snapshot.wateredCount;
  }
}
