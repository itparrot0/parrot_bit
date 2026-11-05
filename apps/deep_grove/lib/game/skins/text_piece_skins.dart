import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../domain/board_model.dart';
import 'piece_skin.dart';

/// 체인별 레벨 색 팔레트. 새 체인 추가 시 여기에 항목을 더한다.
const Map<String, List<Color>> _chainColors = {
  'wood': [
    Color(0xFF9CCC65),
    Color(0xFF66BB6A),
    Color(0xFF43A047),
    Color(0xFF2E7D32),
    Color(0xFF1B5E20),
  ],
  'stone': [
    Color(0xFFBCAAA4),
    Color(0xFFA1887F),
    Color(0xFF8D6E63),
    Color(0xFF6D4C41),
    Color(0xFF4E342E),
  ],
};

/// 팔레트에 없는 체인의 대체 색.
const List<Color> _fallbackColors = [Color(0xFF78909C)];

Color _colorOf(ItemChain chain, int level) {
  final palette = _chainColors[chain.id] ?? _fallbackColors;
  return palette[(level - 1) % palette.length];
}

/// 생성기 기본 색 (레벨이 오르면 흰색 쪽으로 보간한다).
const Color _generatorBase = Color(0xFF546E7A);

/// 산출원 테두리 색.
const Color _producerRim = Color(0xFFFFD54F);

/// 원 + 레벨 숫자 + 이름으로 그리는 아이템 스킨 (텍스트 임시 그래픽).
final class TextItemSkin implements PieceSkin {
  const TextItemSkin(this.item);

  final Item item;

  @override
  Component build(PieceVisualState state, Vector2 size) => PositionComponent(
    size: size,
    children: [
      CircleComponent(
        radius: size.x / 2,
        paint: Paint()..color = _colorOf(item.chain, item.level),
      ),
      _PieceLabel(
        text: '${item.level}',
        style: _labelStyle(36, FontWeight.w700),
        blinking: state == PieceVisualState.dragging,
        parentSize: size,
        offsetY: -8,
      ),
      _PieceLabel(
        text: item.chain.nameOf(item.level),
        style: _labelStyle(16, FontWeight.w600),
        blinking: false,
        parentSize: size,
        offsetY: 22,
      ),
    ],
  );
}

/// 사각형 + "G+레벨" + 체인 첫 이름으로 그리는 생성기 스킨.
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
        RectangleComponent(
          size: Vector2(size.x, 8),
          paint: Paint()..color = _colorOf(generator.spawnChain, 1),
        ),
        _PieceLabel(
          text: 'G${generator.level}',
          style: _labelStyle(32, FontWeight.w800),
          blinking: state == PieceVisualState.dragging,
          parentSize: size,
          offsetY: -8,
        ),
        _PieceLabel(
          text: generator.spawnChain.nameOf(1),
          style: _labelStyle(16, FontWeight.w600),
          blinking: false,
          parentSize: size,
          offsetY: 22,
        ),
      ],
    );
  }
}

/// 둥근 사각형 + 금색 테두리 + 이름으로 그리는 산출원 스킨.
/// 쌓인 양(+N)은 [ProducerComponent]가 그 위에 따로 그린다.
final class TextProducerSkin implements PieceSkin {
  const TextProducerSkin(this.producer);

  final Producer producer;

  @override
  Component build(PieceVisualState state, Vector2 size) {
    final chain = producer.chain;
    return PositionComponent(
      size: size,
      children: [
        RectangleComponent(size: size, paint: Paint()..color = _producerRim),
        RectangleComponent(
          position: Vector2.all(5),
          size: size - Vector2.all(10),
          paint: Paint()..color = _colorOf(chain, chain.maxLevel),
        ),
        _PieceLabel(
          text: chain.nameOf(chain.maxLevel),
          style: _labelStyle(18, FontWeight.w800),
          blinking: state == PieceVisualState.dragging,
          parentSize: size,
          offsetY: 4,
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
    double offsetY = 0,
  }) : super(
         textRenderer: TextPaint(style: style),
         anchor: Anchor.center,
         position: parentSize / 2 + Vector2(0, offsetY),
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
