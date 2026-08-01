import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../domain/board_model.dart';
import 'board_piece_component.dart';

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

/// 원형 + 숫자 아이템.
class ItemComponent extends BoardPieceComponent {
  ItemComponent({required super.cell, required this.item, super.entrance});

  final Item item;

  @override
  int get restingPriority => 10;

  Color get _color {
    final palette = _chainColors[item.chain.id] ?? _fallbackColors;
    return palette[(item.level - 1) % palette.length];
  }

  @override
  void buildVisual(PositionComponent visual) {
    visual.add(
      CircleComponent(radius: size.x / 2, paint: Paint()..color = _color),
    );
    visual.add(
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
  }
}
