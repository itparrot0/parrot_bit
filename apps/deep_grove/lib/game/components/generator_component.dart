import '../../domain/board_model.dart';
import '../grove_game.dart';
import '../skins/piece_skin.dart';
import '../skins/skin_registry.dart';
import 'board_piece_component.dart';

/// 아이템 생성기. 탭하면 무작위 빈 칸에 확률표로 뽑은 레벨의 아이템을 만들고,
/// 아이템처럼 드래그로 이동하거나 같은 정의의 생성기와 머지된다.
/// 빈 칸이 없으면 흔들림 피드백만 준다. 생김새는 [PieceSkins]가 정한다.
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
  PieceSkin get skin => PieceSkins.forGenerator(generator);

  @override
  void onDropped() {
    // 제자리에서 거의 움직이지 않고 놓으면 탭으로 간주해 스폰한다.
    if (position.distanceTo(game.cellCenter(cell)) < kCellSize * 0.3) {
      settleTo(game.cellCenter(cell));
      final spawned = game.spawnFromGenerator(generator);
      if (!spawned) {
        shake();
      }
      return;
    }
    super.onDropped();
  }
}
