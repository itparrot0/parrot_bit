import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../economy/economy.dart';
import '../grove_game.dart';

/// 확장 대상 (화면 흐름 §3.2): 열 수 있는 잠긴 칸 하나, 또는 모든 칸을 연 뒤의 테마 완주 막대.
/// 탭하면 확장 확인 시트를 요청한다.
///
/// 비용 판단은 하지 않는다 — 라벨과 강조 여부는 게임이 브리지에서 받아 넘겨준다.
class ExpandTargetComponent extends RectangleComponent
    with TapCallbacks, HasGameReference<GroveGame> {
  ExpandTargetComponent({
    required this.expansion,
    required String label,
    required bool affordable,
    required Color color,
    required super.position,
    required super.size,
  }) : super(
         paint: Paint()
           ..color = affordable ? color : color.withValues(alpha: 0.35),
       ) {
    add(
      TextComponent(
        text: label,
        anchor: Anchor.center,
        position: size / 2,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: affordable ? Colors.white : Colors.white38,
          ),
        ),
      ),
    );
  }

  final Expansion expansion;

  @override
  void onTapUp(TapUpEvent event) => game.bridge.onExpandRequested(expansion);
}
