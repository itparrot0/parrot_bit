import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../domain/board_model.dart';
import 'piece_skin.dart';

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

/// 생성기 기본 색 (레벨이 오르면 흰색 쪽으로 보간한다).
const Color _generatorBase = Color(0xFF546E7A);

/// 원 + 레벨 숫자로 그리는 아이템 스킨 (프로토타입 기본 그래픽).
final class TextItemSkin implements PieceSkin {
  const TextItemSkin(this.item);

  final Item item;

  Color get _color {
    final palette = _chainColors[item.chain.id] ?? _fallbackColors;
    return palette[(item.level - 1) % palette.length];
  }

  @override
  Component build(PieceVisualState state, Vector2 size) => PositionComponent(
    size: size,
    children: [
      CircleComponent(radius: size.x / 2, paint: Paint()..color = _color),
      _PieceLabel(
        text: '${item.level}',
        style: _labelStyle(40, FontWeight.w700),
        blinking: state == PieceVisualState.dragging,
        parentSize: size,
      ),
    ],
  );
}

/// 사각형 + "G+레벨"로 그리는 생성기 스킨 (프로토타입 기본 그래픽).
final class TextGeneratorSkin implements PieceSkin {
  const TextGeneratorSkin(this.generator);

  final Generator generator;

  @override
  Component build(PieceVisualState state, Vector2 size) {
    // 레벨이 오를수록 살짝 밝아져 업그레이드가 눈에 보이게 한다.
    final color = Color.lerp(
      _generatorBase,
      Colors.white,
      0.18 * (generator.level - 1),
    )!;
    return PositionComponent(
      size: size,
      children: [
        RectangleComponent(size: size, paint: Paint()..color = color),
        _PieceLabel(
          text: 'G${generator.level}',
          style: _labelStyle(34, FontWeight.w800),
          blinking: state == PieceVisualState.dragging,
          parentSize: size,
        ),
      ],
    );
  }
}

TextStyle _labelStyle(double fontSize, FontWeight weight) =>
    TextStyle(fontSize: fontSize, fontWeight: weight, color: Colors.white);

/// 조각 중앙 라벨. [blinking]이면 깜빡여 "잡고 있다"를 알린다.
///
/// 깜빡임에 [OpacityEffect]를 쓰지 않는다: paint만 바뀌면 Flame이
/// `onChanged`에서 글자 element만 다시 만들고 baseline 보정을 건너뛰어
/// 글자가 위로 튄다. renderer를 갈아끼우면 setter가 `updateBounds()`를
/// 호출하므로 가운데 정렬이 유지된다.
///
/// 텍스트 스킨 전용 임시 연출이다 — 이미지 스킨은 깜빡이는 대신
/// 전용 "들린 상태" 이미지로 교체한다.
final class _PieceLabel extends TextComponent<TextPaint> {
  _PieceLabel({
    required super.text,
    required this.style,
    required this.blinking,
    required Vector2 parentSize,
  }) : super(
         textRenderer: TextPaint(style: style),
         anchor: Anchor.center,
         position: parentSize / 2,
       );

  /// 깜빡임 한 주기(초).
  static const double _period = 0.44;

  /// 가장 흐릴 때의 불투명도.
  static const double _minOpacity = 0.2;

  final TextStyle style;
  final bool blinking;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (!blinking) {
      return;
    }
    _elapsed = (_elapsed + dt) % _period;
    // 삼각파로 1 → _minOpacity → 1 을 왕복한다.
    final phase = (_elapsed / _period * 2 - 1).abs();
    final opacity = _minOpacity + (1 - _minOpacity) * phase;
    textRenderer = TextPaint(
      style: style.copyWith(color: style.color?.withValues(alpha: opacity)),
    );
  }
}
