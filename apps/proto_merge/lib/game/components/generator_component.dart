import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../domain/board_model.dart';
import '../merge_game.dart';
import 'board_piece_component.dart';

const Color _baseColor = Color(0xFF546E7A);

/// 아이템 생성기. 탭하면 무작위 빈 칸에 자기 레벨의 아이템을 만들고,
/// 아이템처럼 드래그로 이동하거나 같은 정의의 생성기와 머지된다.
/// 빈 칸이 없으면 흔들림 피드백만 준다.
class GeneratorComponent extends BoardPieceComponent {
  GeneratorComponent({
    required super.cell,
    required this.generator,
    super.entrance,
  });

  final Generator generator;

  @override
  int get restingPriority => 5;

  @override
  void buildVisual(PositionComponent visual) {
    // 레벨이 오를수록 살짝 밝아져 업그레이드가 눈에 보이게 한다.
    final color = Color.lerp(
      _baseColor,
      Colors.white,
      0.18 * (generator.level - 1),
    )!;
    visual.add(RectangleComponent(size: size, paint: Paint()..color = color));
    visual.add(
      TextComponent(
        text: 'G${generator.level}',
        anchor: Anchor.center,
        position: size / 2,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  void onDropped() {
    // 제자리에서 거의 움직이지 않고 놓으면 탭으로 간주해 스폰한다.
    if (position.distanceTo(game.cellCenter(cell)) < kCellSize * 0.3) {
      settleTo(game.cellCenter(cell));
      final spawned = game.spawnFromGenerator(generator);
      if (!spawned) {
        _shake();
      }
      return;
    }
    super.onDropped();
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
