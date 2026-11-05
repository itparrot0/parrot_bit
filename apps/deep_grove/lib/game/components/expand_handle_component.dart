import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../economy/economy.dart';
import '../grove_game.dart';

/// 보드 가장자리 확장 손잡이 (화면 흐름 §3.2). 탭하면 확장 확인 시트를 요청한다.
///
/// 비용 판단은 하지 않는다 — 라벨과 강조 여부는 게임이 브리지에서 받아 넘겨준다.
class ExpandHandleComponent extends RectangleComponent
    with TapCallbacks, HasGameReference<GroveGame> {
  ExpandHandleComponent({
    required this.direction,
    required String label,
    required bool affordable,
    required super.position,
    required super.size,
  }) : super(
         paint: Paint()
           ..color = affordable
               ? const Color(0xFF3E7D4A)
               : const Color(0xFF2B3138),
       ) {
    add(
      TextComponent(
        text: label,
        anchor: Anchor.center,
        position: size / 2,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: affordable ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }

  final ExpandDirection direction;

  @override
  void onTapUp(TapUpEvent event) => game.bridge.onExpandRequested(direction);
}
