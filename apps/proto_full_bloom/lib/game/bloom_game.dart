import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'bloom_palette.dart';
import 'components/cell_component.dart';

/// HUD가 구독하는 상태 묶음.
typedef BloomStats = ({
  int watered,
  int total,
  int bloomed,
  bool isWon,
  bool isDeadlocked,
  bool canUndo,
});

/// 만개 보드 게임.
///
/// 판정은 전부 [BloomBoard]에 위임하고, 여기서는 칸 컴포넌트를 모델 상태대로
/// 다시 그리는 일만 한다 (PRD §10).
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

  /// HUD가 슬롯을 눌러보고 있는 색. 미리보기 테두리에만 쓴다.
  BloomColor? previewColor;

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

  /// 슬롯 [index]를 쓴다. 개화한 칸들에 **순서대로 지연을 주어** 연쇄가
  /// 흐르는 것처럼 보이게 한다.
  void useSlot(int index) {
    final bloomed = board.useSlot(index);
    if (bloomed.isEmpty) {
      return;
    }
    _sync(pulse: bloomed);
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

  /// 지금 슬롯에 있는 [color] 물뿌리개의 남은 횟수 합.
  int _remainingFor(BloomColor color) => board.slots
      .whereType<WateringCan>()
      .where((can) => can.color == color)
      .fold(0, (sum, can) => sum + can.remaining);

  void setPreview(BloomColor? color) {
    if (previewColor == color) {
      return;
    }
    previewColor = color;
    _sync();
  }

  /// 모델 상태대로 칸을 다시 만든다. 보드가 작아 전체 재생성이 충분하다.
  void _sync({List<CellPos> pulse = const []}) {
    for (final cell in _cells) {
      cell.removeFromParent();
    }
    _cells.clear();

    // 번호는 "지금 누른 물뿌리개가 몇 번째로 피울 칸인가"다. 누른 것이 없으면
    // 번호를 아예 안 띄운다 — 전체 큐 순번은 색이 섞여 읽히지 않는다.
    final order = <CellPos, int>{};
    final color = previewColor;
    if (color != null) {
      final targets = board.previewTargets(color, _remainingFor(color));
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
