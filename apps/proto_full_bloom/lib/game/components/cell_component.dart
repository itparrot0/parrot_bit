import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../bloom_palette.dart';

/// 칸 한 변 크기 (고정 해상도 디자인 공간).
const double kCellSize = 100;

/// 보드 한 칸.
///
/// 3단계를 **크기와 밝기**로 구분한다 — 씨앗은 작고 어둡게, 꽃송이는 중간에
/// 흰 테두리(물을 받을 수 있다는 표시), 개화는 크고 밝게.
///
/// 꽃송이에는 **큐 순번을 숫자로 적는다.** 이것이 "큐를 화면에 보여주기"의
/// 실현이고, 이 게임의 예측 가능성이 전부 여기서 나온다 (PRD §5-3).
class CellComponent extends PositionComponent {
  CellComponent({
    required this.cell,
    required this.queueIndex,
    required this.isNextTarget,
    required super.position,
  }) : super(size: Vector2.all(kCellSize), anchor: Anchor.center);

  final Cell cell;

  /// 큐에서 몇 번째인가 (1부터). 꽃송이가 아니면 null.
  final int? queueIndex;

  /// 지금 고른 색이 바로 다음에 피울 칸인가.
  final bool isNextTarget;

  @override
  Future<void> onLoad() async {
    final color = BloomPalette.of(cell.color);

    add(
      RectangleComponent(
        size: Vector2.all(kCellSize * 0.94),
        position: size / 2,
        anchor: Anchor.center,
        paint: Paint()..color = BloomPalette.tile,
      ),
    );

    switch (cell.stage) {
      case CellStage.seed:
        _addDisc(kCellSize * 0.17, color.withValues(alpha: 0.35));
      case CellStage.bud:
        _addDisc(kCellSize * 0.30, color);
        _addRing(kCellSize * 0.30, Colors.white.withValues(alpha: 0.85), 2.5);
        _addQueueLabel();
      case CellStage.bloomed:
        _addDisc(kCellSize * 0.42, color);
        _addRing(kCellSize * 0.42, color.withValues(alpha: 0.45), 6);
    }

    if (isNextTarget) {
      // 다음에 피울 칸을 흰 사각 테두리로 집어준다.
      add(
        RectangleComponent(
          size: Vector2.all(kCellSize * 0.9),
          position: size / 2,
          anchor: Anchor.center,
          paint: Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        ),
      );
    }
  }

  void _addDisc(double radius, Color color) {
    add(
      CircleComponent(
        radius: radius,
        position: size / 2,
        anchor: Anchor.center,
        paint: Paint()..color = color,
      ),
    );
  }

  void _addRing(double radius, Color color, double width) {
    add(
      CircleComponent(
        radius: radius + width / 2,
        position: size / 2,
        anchor: Anchor.center,
        paint: Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      ),
    );
  }

  void _addQueueLabel() {
    final index = queueIndex;
    if (index == null) {
      return;
    }
    add(
      TextComponent(
        text: '$index',
        position: size / 2,
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
