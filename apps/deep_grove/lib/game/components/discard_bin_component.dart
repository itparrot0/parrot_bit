import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 보드 아래 버리기 칸 (보드 막힘 해소 장치). 조각을 여기에 끌어다 놓으면 버린다.
/// 판정은 게임이 드롭 좌표로 한다 — 이 컴포넌트는 그리기만 한다.
class DiscardBinComponent extends RectangleComponent {
  DiscardBinComponent({required super.position, required super.size})
    : super(paint: Paint()..color = _idle, priority: -5);

  static const Color _idle = Color(0xFF2A2F36);
  static const Color _lit = Color(0xFF7A3B3B);

  late final TextComponent<TextPaint> _label;

  bool _active = false;

  bool get active => _active;

  /// 버릴 수 있는 조각을 들고 있는 동안 밝힌다.
  set active(bool value) {
    _active = value;
    paint.color = value ? _lit : _idle;
    if (isLoaded) {
      _label.text = value ? '여기에 놓으면 버려요' : '버리기';
    }
  }

  @override
  Future<void> onLoad() async {
    _label = TextComponent(
      text: _active ? '여기에 놓으면 버려요' : '버리기',
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white70,
        ),
      ),
    );
    add(_label);
  }
}
