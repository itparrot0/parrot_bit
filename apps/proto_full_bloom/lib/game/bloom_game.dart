import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'bloom_palette.dart';
import 'components/cell_component.dart';

/// HUD가 구독하는 상태 묶음.
typedef BloomStats = ({
  /// 둔 수의 번호. 주차만 되고 아무것도 피지 않는 수(통계가 하나도 안
  /// 변하는 수)도 레코드를 다르게 만들어 **HUD 알림이 반드시 가게** 한다 —
  /// 레코드는 구조적 동치라 이 필드가 없으면 그런 수에서 트레이가 멈춘다.
  int moves,
  int watered,
  int total,
  int bloomed,
  bool isWon,
  bool isDeadlocked,
  bool canUndo,
});

/// HUD가 눌러보고 있는 물뿌리개 (미리보기용). 레인 앞이든 주차된 것이든
/// 색과 남은 횟수만 있으면 어디까지 피울지 계산할 수 있다.
typedef PreviewCan = ({BloomColor color, int remaining});

/// Garden Grow 보드 게임.
///
/// 판정은 전부 [BloomBoard]에 위임하고, 여기서는 칸 컴포넌트를 모델 상태대로
/// 다시 그리는 일만 한다 (기획서 §38).
class BloomGame extends FlameGame {
  BloomGame({required BloomLevel level})
    : board = BloomBoard(level),
      super(
        camera: CameraComponent.withFixedResolution(
          width: level.columns * kCellSize,
          height: level.rows * kCellSize,
        ),
      );

  final BloomBoard board;

  /// HUD가 구독하는 통계.
  ///
  /// **초기값을 보드에서 바로 계산한다.** 0으로 두면 [onLoad]의 첫 발행이
  /// 값을 바꿔 알림이 가고, 그 시점이 위젯 빌드 중이라
  /// `setState() called during build`가 난다. 레코드는 구조적 동치라
  /// 같은 값을 다시 넣으면 알림이 가지 않는다.
  late final ValueNotifier<BloomStats> stats = ValueNotifier(_currentStats());

  /// 눌러보고 있는 물뿌리개. null이면 번호를 띄우지 않는다.
  PreviewCan? preview;

  final List<CellComponent> _cells = [];

  @override
  Color backgroundColor() => BloomPalette.background;

  @override
  Future<void> onLoad() async {
    _sync();
  }

  Vector2 get _origin => Vector2(
    -board.level.columns * kCellSize / 2,
    -board.level.rows * kCellSize / 2,
  );

  Vector2 cellCenter(CellPos pos) =>
      _origin +
      Vector2((pos.col + 0.5) * kCellSize, (pos.row + 0.5) * kCellSize);

  /// 레인 [lane]의 맨 앞을 꺼내 재생한다.
  void takeFromLane(int lane) {
    _animate(board.takeFromLane(lane));
  }

  /// 주차된 활성화 슬롯 [slot]을 재개한다.
  void useActive(int slot) {
    _animate(board.useActive(slot));
  }

  void undo() {
    if (board.undo()) {
      _sync();
    }
  }

  void restart() {
    board.restart();
    _sync();
  }

  void setPreview(PreviewCan? can) {
    if (preview == can) {
      return;
    }
    preview = can;
    _sync();
  }

  void _animate(List<CellPos> bloomed) {
    // 주차만 되고 아무것도 안 폈어도 레인·슬롯 상태는 바뀌었다 — 항상 동기화.
    _sync(pulse: bloomed);
  }

  /// 모델 상태대로 칸을 다시 만든다. 보드가 작아 전체 재생성이 충분하다.
  void _sync({List<CellPos> pulse = const []}) {
    for (final cell in _cells) {
      cell.removeFromParent();
    }
    _cells.clear();

    // 번호는 "지금 누른 물뿌리개가 몇 번째로 피울 칸인가"다. 누른 것이 없으면
    // 번호를 아예 안 띄운다 — 전체 큐 순번은 색이 섞여 읽히지 않는다.
    //
    // **그 물뿌리개의 남은 횟수만큼만** 번호를 붙인다. 그래서 x1을 누르면 1칸,
    // x4를 누르면 4칸이 보이고 "이 한 수가 어디까지 가나"가 그대로 읽힌다.
    final order = <CellPos, int>{};
    final pressed = preview;
    if (pressed != null) {
      final targets = board.previewTargets(pressed.color, pressed.remaining);
      for (var index = 0; index < targets.length; index++) {
        order[targets[index]] = index + 1;
      }
    }

    // 연출은 **고리 단위**로 묶어 터뜨린다 — 하·좌·우·상 한 싸이클이 한 고리다.
    final pulseDepths = {for (final pos in pulse) pos: board.depthOf(pos) ?? 0};
    final firstDepth = pulseDepths.values.isEmpty
        ? 0
        : pulseDepths.values.reduce((a, b) => a < b ? a : b);

    board.cells.forEach((pos, cell) {
      final component = CellComponent(
        cell: cell,
        waterOrder: order[pos],
        isNextTarget: order[pos] == 1,
        position: cellCenter(pos),
      );
      _cells.add(component);
      world.add(component);

      final depth = pulseDepths[pos];
      if (depth != null) {
        component.scale = Vector2.all(0.55);
        component.add(
          ScaleEffect.to(
            Vector2.all(1),
            DelayedEffectController(
              EffectController(duration: 0.16, curve: Curves.easeOutBack),
              delay: (depth - firstDepth) * 0.13,
            ),
          ),
        );
      }
    });

    _publishStats();
  }

  BloomStats _currentStats() => (
    moves: board.movesPlayed,
    watered: board.wateredCount,
    total: board.level.cellCount,
    bloomed: board.cells.values.where((cell) => cell.isBloomed).length,
    isWon: board.isWon,
    isDeadlocked: board.isDeadlocked,
    canUndo: board.canUndo,
  );

  void _publishStats() {
    stats.value = _currentStats();
  }
}
