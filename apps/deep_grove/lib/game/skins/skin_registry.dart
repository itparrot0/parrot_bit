import '../../domain/board_model.dart';
import 'piece_skin.dart';
import 'text_piece_skins.dart';

/// 도메인 조각 → 스킨 해석표.
///
/// **그래픽을 바꿀 때 고쳐야 하는 유일한 곳이다.** 보드 모델도 컴포넌트도
/// 어떤 스킨이 쓰이는지 모르므로, 아래 메서드의 본문만 바꾸면
/// 보드 전체 그림이 한 번에 교체된다:
///
/// ```dart
/// static PieceSkin forItem(Item item) => SpritePieceSkin(
///       resting: 'items/${item.chain.id}_${item.level}.png',
///       dragging: 'items/${item.chain.id}_${item.level}_held.png',
///     );
/// ```
///
/// 머지 결과는 레벨이 오른 새 조각으로 컴포넌트를 다시 만들기 때문에,
/// "머지 → 다음 레벨 그림"(최고 레벨이면 산출원 그림)은 여기 해석표를 타고
/// 자동으로 따라온다.
abstract final class PieceSkins {
  static PieceSkin forItem(Item item) => TextItemSkin(item);

  static PieceSkin forGenerator(Generator generator) =>
      TextGeneratorSkin(generator);

  static PieceSkin forProducer(Producer producer) => TextProducerSkin(producer);
}
