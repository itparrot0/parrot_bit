import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// 첫 실행 안내 손가락 (화면 흐름 §5). 가리키는 곳에 맥박 치는 고리 + 까딱이는 손가락.
///
/// 입력을 받지 않는다 — 탭·드래그는 아래 조각과 손잡이로 그대로 간다.
class FingerHintComponent extends PositionComponent {
  FingerHintComponent({required Vector2 target})
    : super(position: target, anchor: Anchor.center, priority: 200);

  static const IconData _icon = Icons.touch_app;

  @override
  Future<void> onLoad() async {
    final ring = CircleComponent(
      radius: 34,
      anchor: Anchor.center,
      paint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xCCFFE082),
    );
    ring.add(
      ScaleEffect.to(
        Vector2.all(1.25),
        EffectController(duration: 0.6, alternate: true, infinite: true),
      ),
    );
    add(ring);

    final finger = TextComponent(
      text: String.fromCharCode(_icon.codePoint),
      anchor: Anchor.topLeft,
      position: Vector2(4, 8),
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: _icon.fontFamily,
          package: _icon.fontPackage,
          fontSize: 64,
          color: Colors.white,
          shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
        ),
      ),
    );
    finger.add(
      MoveByEffect(
        Vector2(-6, -10),
        EffectController(
          duration: 0.6,
          alternate: true,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );
    add(finger);
  }
}
