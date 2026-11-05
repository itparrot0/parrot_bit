import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../domain/board_model.dart';
import '../grove_game.dart';
import '../skins/piece_skin.dart';
import '../skins/skin_registry.dart';
import 'board_piece_component.dart';

/// 산출원 (체인 최고 레벨). 탭하면 다 익은 자원을 창고로 보낸다.
///
/// 드래그로 옮기고 자리 교체는 되지만 머지는 되지 않는다 — 판정은 모델이 한다.
/// 쌓인 양 표시는 스킨이 아니라 이 컴포넌트가 매 프레임 갱신한다 (스킨은
/// 상태가 바뀔 때만 다시 만들어진다).
class ProducerComponent extends BoardPieceComponent {
  ProducerComponent({
    required super.cell,
    required this.producer,
    super.entrance,
  });

  final Producer producer;

  late final TextComponent<TextPaint> _stockLabel;
  int _shownRipe = -1;

  @override
  int get restingPriority => 8;

  @override
  PieceSkin get skin => PieceSkins.forProducer(producer);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _stockLabel = TextComponent(
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      anchor: Anchor.topRight,
      position: Vector2(size.x - 4, 2),
    );
    visual.add(_stockLabel);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final ripe = producer.ripe;
    if (ripe != _shownRipe) {
      _shownRipe = ripe;
      _stockLabel.text = ripe > 0 ? '+$ripe' : '';
    }
  }

  @override
  void refreshSkin() {
    super.refreshSkin();
    _shownRipe = -1; // 다음 update 에서 쌓인 양 라벨도 다시 그린다.
  }

  @override
  void onDropped() {
    if (position.distanceTo(game.cellCenter(cell)) < kCellSize * 0.3) {
      settleTo(game.cellCenter(cell));
      if (!game.harvestAt(cell)) {
        shake();
      }
      return;
    }
    super.onDropped();
  }
}
