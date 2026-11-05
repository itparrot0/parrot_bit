import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../domain/board_model.dart';
import '../grove_game.dart';
import '../skins/piece_skin.dart';

/// 등장 연출 종류.
enum PieceEntrance { none, spawn, merge }

/// 드래그로 옮길 수 있는 보드 조각(아이템·생성기)의 공통 동작.
///
/// 드래그 이동과 드롭 요청만 담당하고 판정은 [GroveGame.resolveDrop]에
/// 위임한다. 생김새는 하위 클래스가 지정한 [skin]이 상태별로 만들고,
/// 이 클래스는 상태가 바뀌는 시점(집었다/놓았다)만 알려준다.
abstract class BoardPieceComponent extends PositionComponent
    with DragCallbacks, HasGameReference<GroveGame> {
  BoardPieceComponent({required this.cell, this.entrance = PieceEntrance.none});

  CellPos cell;
  final PieceEntrance entrance;

  /// 드래그 확대·펄스 연출용 내부 컨테이너.
  /// 컴포넌트 자체를 scale하면 드래그 delta 좌표계가 틀어지므로 분리한다.
  late final PositionComponent visual;

  bool _dragging = false;

  /// 현재 그려져 있는 시각 상태와 그 생김새.
  PieceVisualState _visualState = PieceVisualState.resting;
  Component? _skinPart;

  /// 정지 상태 렌더 우선순위.
  int get restingPriority;

  /// 이 조각의 생김새 정의. 상태가 바뀔 때마다 여기서 새 생김새를 받는다.
  PieceSkin get skin;

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
    add(visual);
    _showState(PieceVisualState.resting);

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
    game.showBonusZone(this);
    priority = 100;
    visual.scale = Vector2.all(1.1);
    _showState(PieceVisualState.dragging);
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
    game.clearBonusZone();
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
    game.clearBonusZone();
    settleTo(game.cellCenter(cell));
  }

  /// [target] 좌표로 정착 애니메이션 후 드래그 상태를 정리한다.
  ///
  /// 이동·교체·스냅백·탭이 전부 여기를 지나므로, 손에서 놓였을 때의
  /// 생김새 복구는 이 한 곳에서만 한다. (머지는 컴포넌트 자체가 사라진다)
  void settleTo(Vector2 target) {
    priority = restingPriority;
    visual.scale = Vector2.all(1);
    _showState(PieceVisualState.resting);
    add(
      MoveToEffect(
        target,
        EffectController(duration: 0.12, curve: Curves.easeOut),
      ),
    );
  }

  /// 생김새를 지금 상태 그대로 다시 만든다 (폰트가 늦게 로드됐을 때).
  void refreshSkin() {
    _skinPart?.removeFromParent();
    _skinPart = skin.build(_visualState, size);
    visual.add(_skinPart!);
  }

  /// 거부 피드백 (빈 칸 없음, 창고 가득, 거둘 것 없음).
  void shake() {
    add(
      MoveByEffect(
        Vector2(6, 0),
        EffectController(duration: 0.04, alternate: true, repeatCount: 3),
      ),
    );
  }

  /// 시각 상태를 [state]로 바꾸고 생김새를 스킨이 만든 것으로 교체한다.
  ///
  /// 등장·펄스 효과는 [visual]에 직접 붙어 있고 스킨이 만든 부분만
  /// 갈아끼우므로, 상태 전환이 연출을 지우지 않는다.
  void _showState(PieceVisualState state) {
    if (state == _visualState && _skinPart != null) {
      return;
    }
    _visualState = state;
    _skinPart?.removeFromParent();
    _skinPart = skin.build(state, size);
    visual.add(_skinPart!);
  }
}
