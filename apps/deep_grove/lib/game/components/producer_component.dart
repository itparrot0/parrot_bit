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
  late final TextComponent<TextPaint> _bonusLabel;
  int _shownRipe = -1;
  bool? _shownBonus;

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
      // 스킨은 상태가 바뀔 때마다 visual 에 다시 붙는다 — 라벨이 그 위에 그려지게 한다.
      priority: 10,
      position: Vector2(size.x - 4, 2),
    );
    visual.add(_stockLabel);
    // 자기 지대에 있으면 왼쪽 아래에 배율 표시 (화면 흐름 §5 지대 보너스 표시).
    _bonusLabel = TextComponent(
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFFFFE082),
        ),
      ),
      anchor: Anchor.bottomLeft,
      priority: 10,
      position: Vector2(8, size.y - 6),
    );
    visual.add(_bonusLabel);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final ripe = producer.ripe;
    if (ripe != _shownRipe) {
      _shownRipe = ripe;
      _stockLabel.text = ripe > 0 ? '+$ripe' : '';
    }
    final bonus = game.board.hasZoneBonus(cell);
    if (bonus != _shownBonus) {
      _shownBonus = bonus;
      _bonusLabel.text = bonus ? '×${_multiplierText()}' : '';
    }
  }

  @override
  void refreshSkin() {
    super.refreshSkin();
    _shownRipe = -1; // 다음 update 에서 쌓인 양·보너스 라벨도 다시 그린다.
    _shownBonus = null;
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

  String _multiplierText() {
    final m = game.board.theme.homeZoneBonus;
    return m == m.roundToDouble() ? m.toStringAsFixed(0) : '$m';
  }
}
