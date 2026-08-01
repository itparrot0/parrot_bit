import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../domain/board_model.dart';
import '../merge_game.dart';

/// 아이템 생성기. 탭하면 무작위 빈 칸에 [Generator] 정의대로 아이템을 만든다.
/// 이동/머지 불가, 빈 칸이 없으면 흔들림 피드백만 준다.
class GeneratorComponent extends PositionComponent
    with TapCallbacks, HasGameReference<MergeGame> {
  GeneratorComponent({required this.generator});

  final Generator generator;

  @override
  Future<void> onLoad() async {
    size = Vector2.all(kCellSize * 0.86);
    anchor = Anchor.center;
    position = game.cellCenter(generator.cell);
    priority = 5;

    add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = const Color(0xFF546E7A),
      ),
    );
    add(
      TextComponent(
        text: 'G',
        anchor: Anchor.center,
        position: size / 2,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  void onTapUp(TapUpEvent event) {
    final spawned = game.spawnFromGenerator(generator);
    if (!spawned) {
      _shake();
    }
  }

  void _shake() {
    add(
      MoveByEffect(
        Vector2(6, 0),
        EffectController(duration: 0.04, alternate: true, repeatCount: 3),
      ),
    );
  }
}
