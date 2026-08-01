import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../domain/board_model.dart';
import '../merge_game.dart';

/// 체인별 레벨 색 팔레트. 새 체인 추가 시 여기에 항목을 더한다.
const Map<String, List<Color>> _chainColors = {
  'basic': [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFFFF9800),
    Color(0xFFF44336),
  ],
};

/// 팔레트에 없는 체인의 대체 색.
const List<Color> _fallbackColors = [Color(0xFF78909C)];

/// 등장 연출 종류.
enum ItemEntrance { none, spawn, merge }

/// 원형 + 숫자 아이템. 드래그 이동과 드롭 요청만 담당하고
/// 판정은 [MergeGame.resolveDrop]에 위임한다.
class ItemComponent extends PositionComponent
    with DragCallbacks, HasGameReference<MergeGame> {
  ItemComponent({
    required this.cell,
    required this.item,
    this.entrance = ItemEntrance.none,
  });

  CellPos cell;
  final Item item;
  final ItemEntrance entrance;

  /// 드래그 확대·펄스 연출용 내부 컨테이너.
  /// 컴포넌트 자체를 scale하면 드래그 delta 좌표계가 틀어지므로 분리한다.
  late final PositionComponent _visual;

  bool _dragging = false;

  Color get _color {
    final palette = _chainColors[item.chain.id] ?? _fallbackColors;
    return palette[(item.level - 1) % palette.length];
  }

  @override
  Future<void> onLoad() async {
    size = Vector2.all(kCellSize * 0.86);
    anchor = Anchor.center;
    position = game.cellCenter(cell);
    priority = 10;

    _visual = PositionComponent(
      size: size,
      position: size / 2,
      anchor: Anchor.center,
    );
    _visual.add(
      CircleComponent(radius: size.x / 2, paint: Paint()..color = _color),
    );
    _visual.add(
      TextComponent(
        text: '${item.level}',
        anchor: Anchor.center,
        position: size / 2,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
    add(_visual);

    switch (entrance) {
      case ItemEntrance.spawn:
        _visual.scale = Vector2.all(0.3);
        _visual.add(
          ScaleEffect.to(
            Vector2.all(1),
            EffectController(duration: 0.15, curve: Curves.easeOutBack),
          ),
        );
      case ItemEntrance.merge:
        _visual.add(
          ScaleEffect.by(
            Vector2.all(1.18),
            EffectController(duration: 0.09, alternate: true),
          ),
        );
      case ItemEntrance.none:
        break;
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragging = true;
    priority = 100;
    _visual.scale = Vector2.all(1.1);
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
    game.resolveDrop(this);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragging = false;
    settleTo(game.cellCenter(cell));
  }

  /// [target] 좌표로 정착 애니메이션 후 드래그 상태를 정리한다.
  void settleTo(Vector2 target) {
    priority = 10;
    _visual.scale = Vector2.all(1);
    add(
      MoveToEffect(
        target,
        EffectController(duration: 0.12, curve: Curves.easeOut),
      ),
    );
  }
}
