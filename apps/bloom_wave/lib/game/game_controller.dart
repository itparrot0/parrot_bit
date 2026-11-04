// 게임 한 판의 진행: 엔진 호출, 고정 간격 틱 타이머, 일시정지. (되돌리기는 2026-11-04 2차 피드백으로 삭제)
// 규칙은 전부 domain/engine.dart 가 정한다. 여기서는 "언제 tick/deploy 를 부르는가"만 다룬다.
import '../domain/engine.dart';
import '../domain/solver.dart';

/// 틱 간격 (ms). 2026-11-04 플레이 피드백: 150ms는 너무 빨라 기본을 300ms로.
/// 규칙(클리어 가능 여부)은 틱 단위라 바뀌지 않는다
const Map<String, int> tickMs = {'normal': 300, 'slow': 450};

enum TapFail { full, wait, over, empty }

class TapResult {
  const TapResult.ok(this.slot, this.drop, this.lane) : fail = null;
  const TapResult.failed(TapFail this.fail) : slot = -1, drop = null, lane = -1;
  final TapFail? fail;
  final int slot;
  final Drop? drop;
  final int lane;
  bool get ok => fail == null;
}

enum HintAction { tap, wait }

class Hint {
  const Hint(this.action, this.lane, this.result);

  /// null = 다음 수를 찾지 못함 (result.solvable 로 이유 구분)
  final HintAction? action;
  final int lane;
  final SolveResult result;
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
      tickMs = tickMs ?? 300,
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

  /// lane 줄의 맨 앞을 지금 탭할 수 있나 (판단은 엔진의 legalActions 로만)
  bool canTap(int lane) =>
      legalActions(state, options).any((a) => a is Deploy && a.lane == lane);

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
      return TapResult.failed(
        s.slots.contains(null) ? TapFail.wait : TapFail.full,
      );
    }
    final drop = s.lanes[lane].first.copy();
    final slot = deploy(level, s, lane);
    if (occupied > peak) peak = occupied;
    _acc = 0; // 탭한 물방울은 다음 틱부터 함께 퍼진다
    _on.onDeploy?.call(slot, drop, lane);
    _afterChange();
    return TapResult.ok(slot, drop, lane);
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

  /// 힌트: 지금 상태에서 솔버가 찾은 다음 수
  Hint hint([int maxNodes = 30000]) {
    final r = solveFrom(level, state, options, maxNodes);
    final a = r.solution.isEmpty ? null : r.solution.first;
    return switch (a) {
      Deploy(:final lane) => Hint(HintAction.tap, lane, r),
      Tick() => Hint(HintAction.wait, -1, r),
      null => Hint(null, -1, r),
    };
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
