import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../domain/board_model.dart';
import '../merge_game.dart';

/// 등장 연출 종류.
enum PieceEntrance { none, spawn, merge }

/// 드래그로 옮길 수 있는 보드 조각(아이템·생성기)의 공통 동작.
///
/// 드래그 이동과 드롭 요청만 담당하고 판정은 [MergeGame.resolveDrop]에
/// 위임한다. 하위 클래스는 [buildVisual]로 생김새만 정의한다.
abstract class BoardPieceComponent extends PositionComponent
    with DragCallbacks, HasGameReference<MergeGame> {
  BoardPieceComponent({required this.cell, this.entrance = PieceEntrance.none});

  CellPos cell;
  final PieceEntrance entrance;

  /// 드래그 확대·펄스 연출용 내부 컨테이너.
  /// 컴포넌트 자체를 scale하면 드래그 delta 좌표계가 틀어지므로 분리한다.
  late final PositionComponent visual;

  bool _dragging = false;

  /// 정지 상태 렌더 우선순위.
  int get restingPriority;

  /// [visual] 안에 이 조각의 생김새를 구성한다.
  void buildVisual(PositionComponent visual);

  @override
  Future<void> onLoad() async {
    size = Vector2.all(kCellSize * 0.86);
    anchor = Anchor.center;
    position = game.cellCenter(cell);
    priority = restingPriority;

    visual = PositionComponent(
      size: size,
      position: size / 2,
      anchor: Anchor.center,
    );
    buildVisual(visual);
    add(visual);

    switch (entrance) {
      case PieceEntrance.spawn:
        visual.scale = Vector2.all(0.3);
        visual.add(
          ScaleEffect.to(
            Vector2.all(1),
            EffectController(duration: 0.15, curve: Curves.easeOutBack),
          ),
        );
      case PieceEntrance.merge:
        visual.add(
          ScaleEffect.by(
            Vector2.all(1.18),
            EffectController(duration: 0.09, alternate: true),
          ),
        );
      case PieceEntrance.none:
        break;
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragging = true;
    priority = 100;
    visual.scale = Vector2.all(1.1);
    // 스냅백 애니메이션 도중 다시 집으면 이전 이동 효과를 끊는다.
    children.whereType<MoveToEffect>().toList().forEach(
          (effect) => effect.removeFromParent(),
        );
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_dragging) {
      return;
    }
    position += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!_dragging) {
      return;
    }
    _dragging = false;
    onDropped();
  }

  /// 드롭 처리 훅. 기본은 게임에 판정을 요청한다.
  ///
  /// 드래그와 탭을 함께 쓰면 드래그 제스처 인식기가 탭을 가로채므로,
  /// 탭 반응이 필요한 조각은 TapCallbacks 대신 이 훅에서
  /// "이동량이 거의 없는 드롭"을 탭으로 해석한다.
  void onDropped() => game.resolveDrop(this);

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragging = false;
    settleTo(game.cellCenter(cell));
  }

  /// [target] 좌표로 정착 애니메이션 후 드래그 상태를 정리한다.
  void settleTo(Vector2 target) {
    priority = restingPriority;
    visual.scale = Vector2.all(1);
    add(
      MoveToEffect(
        target,
        EffectController(duration: 0.12, curve: Curves.easeOut),
      ),
    );
  }
}
