import '../../domain/board_model.dart';
import '../skins/piece_skin.dart';
import '../skins/skin_registry.dart';
import 'board_piece_component.dart';

/// 보드 위 아이템. 생김새는 [PieceSkins]가 정한다.
class ItemComponent extends BoardPieceComponent {
  ItemComponent({required super.cell, required this.item, super.entrance});

  final Item item;

  @override
  int get restingPriority => 10;

  @override
  PieceSkin get skin => PieceSkins.forItem(item);
}
