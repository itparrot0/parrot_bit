import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../domain/board_model.dart';
import 'components/generator_component.dart';
import 'components/item_component.dart';

/// HUD 표시용 게임 통계.
typedef BoardStats = ({int highestLevel, int mergeCount});

/// 고정 해상도 디자인 공간에서 셀 한 변 크기.
const double kCellSize = 100;

/// 머지 보드 게임. 규칙 판정은 전부 [BoardModel]에 위임하고,
/// 여기서는 컴포넌트 생성/제거와 좌표 변환만 담당한다.
class MergeGame extends FlameGame {
  MergeGame({BoardModel? model})
      : model = model ?? BoardModel(),
        super(
          camera: CameraComponent.withFixedResolution(width: 540, height: 700),
        );

  final BoardModel model;

  /// HUD가 구독하는 통계. 머지/생성/리셋 시 갱신된다.
  final ValueNotifier<BoardStats> stats =
      ValueNotifier((highestLevel: 1, mergeCount: 0));

  final Map<CellPos, ItemComponent> _itemComponents = {};

  Vector2 get _boardOrigin => Vector2(
        -model.columns * kCellSize / 2,
        -model.rows * kCellSize / 2,
      );

  @override
  Color backgroundColor() => const Color(0xFF171B21);

  @override
  Future<void> onLoad() async {
    _buildTiles();
    for (final generator in model.generators) {
      world.add(GeneratorComponent(generator: generator));
    }
    _syncItems();
  }

  /// 칸의 중심 월드 좌표.
  Vector2 cellCenter(CellPos pos) =>
      _boardOrigin +
      Vector2((pos.col + 0.5) * kCellSize, (pos.row + 0.5) * kCellSize);

  /// 월드 좌표가 속한 칸. 보드 밖이면 null.
  CellPos? cellAt(Vector2 point) {
    final local = point - _boardOrigin;
    final pos = (
      col: (local.x / kCellSize).floor(),
      row: (local.y / kCellSize).floor(),
    );
    return model.isInside(pos) ? pos : null;
  }

  /// [generator] 탭 처리. 생성에 성공하면 true.
  bool spawnFromGenerator(Generator generator) {
    final pos = model.spawnFrom(generator);
    if (pos == null) {
      return false;
    }
    _addItem(pos, model.itemAt(pos)!, entrance: ItemEntrance.spawn);
    _publishStats();
    return true;
  }

  /// 드래그 종료 판정: 모델 결과에 따라 머지/이동/스냅백을 적용한다.
  void resolveDrop(ItemComponent item) {
    final target = cellAt(item.position);
    final outcome =
        target == null ? MoveOutcome.rejected : model.tryMove(item.cell, target);

    switch (outcome) {
      case MoveOutcome.moved:
        _itemComponents.remove(item.cell);
        item.cell = target!;
        _itemComponents[target] = item;
        item.settleTo(cellCenter(target));
      case MoveOutcome.merged:
        final consumed = _itemComponents.remove(target!);
        _itemComponents.remove(item.cell);
        consumed?.removeFromParent();
        item.removeFromParent();
        _addItem(target, model.itemAt(target)!, entrance: ItemEntrance.merge);
        _publishStats();
      case MoveOutcome.rejected:
        item.settleTo(cellCenter(item.cell));
    }
  }

  /// 보드를 초기 배치로 되돌린다 (HUD Reset 버튼).
  void resetGame() {
    model.reset();
    _syncItems();
  }

  void _buildTiles() {
    for (var row = 0; row < model.rows; row++) {
      for (var col = 0; col < model.columns; col++) {
        world.add(
          RectangleComponent(
            position: cellCenter((col: col, row: row)),
            size: Vector2.all(kCellSize * 0.94),
            anchor: Anchor.center,
            paint: Paint()..color = const Color(0xFF232A33),
          ),
        );
      }
    }
  }

  /// 모델의 아이템 상태대로 컴포넌트를 다시 만든다 (초기 로드/리셋).
  void _syncItems() {
    for (final component in _itemComponents.values) {
      component.removeFromParent();
    }
    _itemComponents.clear();
    model.items.forEach(_addItem);
    _publishStats();
  }

  void _addItem(
    CellPos pos,
    Item item, {
    ItemEntrance entrance = ItemEntrance.none,
  }) {
    final component = ItemComponent(cell: pos, item: item, entrance: entrance);
    _itemComponents[pos] = component;
    world.add(component);
  }

  void _publishStats() {
    stats.value = (
      highestLevel: model.highestLevel,
      mergeCount: model.mergeCount,
    );
  }
}
