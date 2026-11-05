// 게임 한 판의 진행: 엔진 호출, 고정 간격 틱 타이머, 일시정지. (되돌리기는 2026-11-04 2차 피드백으로 삭제)
// 규칙은 전부 domain/engine.dart 가 정한다. 여기서는 "언제 tick/deploy 를 부르는가"만 다룬다.
import '../domain/engine.dart';
import '../domain/solver.dart';
import '../economy/items.dart';

// 틱 간격은 economy/items.dart: 기본 450ms(느림), x2 300ms. 규칙(클리어 가능 여부)은 틱 단위라 바뀌지 않는다.
// 힌트 기능은 2026-11-04 삭제.

/// full: 빈 슬롯이 모자람 / wait: 웨이브가 끝나야 함(턴제) / over: 끝난 판 / empty: 빈 줄 /
/// set: 묶인 물방울이 아직 모두 맨 앞이 아님 (2026-11-05)
enum TapFail { full, wait, over, empty, set }

class TapResult {
  const TapResult.ok(this.slot, this.drop, this.lane) : fail = null;
  const TapResult.failed(TapFail this.fail) : slot = -1, drop = null, lane = -1;
  final TapFail? fail;
  final int slot;
  final Drop? drop;
  final int lane;
  bool get ok => fail == null;
}

/// 화면이 듣는 이벤트. 모두 선택
class ControllerEvents {
  const ControllerEvents({
    this.onTick,
    this.onDeploy,
    this.onStatus,
    this.onReset,
    this.onIdle,
  });
  final void Function(TickEvent ev)? onTick;
  final void Function(int slot, Drop drop, int lane)? onDeploy;
  final void Function(Status status)? onStatus;

  /// 재시작으로 상태가 통째로 바뀜
  final void Function()? onReset;

  /// 웨이브가 멈춤 (이제 넣어야 함)
  final void Function()? onIdle;
}

class GameController {
  GameController(this.level, {int? tickMs, this.manual = false})
    : options = level.options,
      tickMs = tickMs ?? baseTickMs,
      state = createState(level);

  final Level level;
  final Options options;
  State state;
  int tickMs;
  bool paused = false;

  /// true면 타이머로 틱을 돌리지 않는다 (테스트용). step()으로만 진행
  bool manual;

  /// 이번 판 동안 활성 슬롯이 동시에 찬 최대 칸 수 (기록용)
  int peak = 0;
  int ticks = 0;
  double _acc = 0;
  bool _wasActive = false;
  ControllerEvents _on = const ControllerEvents();

  void listen(ControllerEvents on) => _on = on;

  Status get status => state.status;
  bool get active => isActive(state);
  int get occupied => state.occupied;
  int get queueLeft => queueLength(state.lanes);

  /// lane 줄의 맨 앞 물방울
  Drop? front(int lane) =>
      lane >= 0 && lane < state.lanes.length && state.lanes[lane].isNotEmpty
      ? state.lanes[lane].first
      : null;

  /// lane 줄의 맨 앞을 지금 탭할 수 있나 (판단은 엔진으로만: set 준비·빈 슬롯·턴제 대기)
  bool canTap(int lane) =>
      state.status == Status.playing &&
      (options.realtime || !isActive(state)) &&
      canDeploy(state, lane);

  /// lane 줄 맨 앞이 set 이라 아직 넣을 수 없나 (짝이 맨 앞에 오지 않음)
  bool setWaiting(int lane) =>
      front(lane) != null && frontGroup(state, lane) == null;

  /// lane 줄의 맨 앞 물방울과 같은 색 발아 칸이 있나
  bool usable(int lane) {
    final f = front(lane);
    return f != null && state.sproutCount[f.color] > 0;
  }

  TapResult tap(int lane) {
    final s = state;
    if (s.status != Status.playing) return const TapResult.failed(TapFail.over);
    if (front(lane) == null) return const TapResult.failed(TapFail.empty);
    if (!canTap(lane)) {
      if (setWaiting(lane)) return const TapResult.failed(TapFail.set);
      final g = frontGroup(s, lane)!;
      return TapResult.failed(
        freeSlots(s) >= g.length ? TapFail.wait : TapFail.full,
      );
    }
    final drop = s.lanes[lane].first.copy();
    final group = [
      for (final l in frontGroup(s, lane)!) (l, s.lanes[l].first.copy()),
    ];
    final placed = deployGroup(level, s, lane);
    if (occupied > peak) peak = occupied;
    _acc = 0; // 탭한 물방울은 다음 틱부터 함께 퍼진다
    for (var k = 0; k < placed.length; k++) {
      _on.onDeploy?.call(placed[k].$1, group[k].$2, placed[k].$2);
    }
    _afterChange();
    final mine = placed.firstWhere((p) => p.$2 == lane);
    return TapResult.ok(mine.$1, drop, lane);
  }

  /// 틱 하나 진행 (웨이브가 없으면 아무것도 안 함)
  TickEvent? step() {
    if (state.status != Status.playing || !isActive(state)) return null;
    final ev = tick(level, state);
    ticks++;
    _on.onTick?.call(ev);
    _afterChange();
    return ev;
  }

  /// 프레임마다 호출. 누적 시간으로 고정 간격 틱
  void update(double dtMs) {
    if (paused || manual || state.status != Status.playing) return;
    if (!isActive(state)) {
      _acc = 0;
      return;
    }
    _acc += dtMs;
    var guard = 0;
    while (_acc >= tickMs && guard++ < 4) {
      _acc -= tickMs;
      if (step() == null) {
        _acc = 0;
        break;
      }
    }
  }

  void restart() {
    state = createState(level);
    peak = 0;
    ticks = 0;
    _acc = 0;
    paused = false;
    _wasActive = false;
    _on.onReset?.call();
    _on.onStatus?.call(state.status);
  }

  void pause() => paused = true;
  void resume() {
    paused = false;
    _acc = 0;
  }

  // ───────── 아이템 (규칙은 엔진, 여기서는 호출과 이벤트) ─────────

  bool get _playing => state.status == Status.playing;

  /// 슬롯 추가를 지금 쓸 수 있나
  bool get canAddSlot => _playing && state.slots.length < maxSlots;

  /// 활성 슬롯 1칸 추가
  bool addSlotItem() {
    if (!canAddSlot) return false;
    addSlot(state);
    _afterChange();
    return true;
  }

  /// 섞기를 지금 쓸 수 있나 (남은 물방울이 2개 이상)
  bool get canShuffle => _playing && queueLength(state.lanes) >= 2;

  /// 대기열 섞기. 섞은 뒤에도 완성할 수 있는 배치를 [tries]번 안에서 찾는다
  /// (솔버가 판정 못 하면(노드 한도) 받아들인다). 못 찾으면 아무것도 바꾸지 않고 false
  bool shuffleItem(
    int Function(int max) nextInt, {
    int tries = 12,
    int maxNodes = 20000,
  }) {
    if (!canShuffle) return false;
    State? fallback;
    for (var k = 0; k < tries; k++) {
      final c = state.clone();
      shuffleLanes(c, nextInt);
      if (!setsSplit(c)) continue; // set 짝이 한 줄에 겹치면 영영 못 넣는다
      final r = solveFrom(level, c, options, maxNodes);
      if (r.solvable == true) {
        state.lanes = c.lanes;
        _afterChange();
        return true;
      }
      if (r.solvable == null) fallback ??= c;
    }
    if (fallback == null) return false;
    state.lanes = fallback.lanes;
    _afterChange();
    return true;
  }

  /// 즉시 개화를 쓸 수 있는 슬롯들 (퍼질 곳이 없어 묶인 물방울)
  List<int> get stuck => _playing ? stuckSlots(state) : const [];

  /// slot 의 물방울을 즉시 개화. 연출용 이벤트를 돌려준다 (못 쓰면 null)
  TickEvent? bloomItem(int slot, int Function(int max) nextInt) {
    if (!stuck.contains(slot)) return null;
    final ev = forceBloom(level, state, slot, nextInt);
    _acc = 0;
    _afterChange();
    return ev;
  }

  void _afterChange() {
    final act = isActive(state);
    if (_wasActive && !act && state.status == Status.playing) {
      _on.onIdle?.call();
    }
    _wasActive = act;
    if (state.status != Status.playing) _on.onStatus?.call(state.status);
  }
}
