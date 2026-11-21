import 'generator.dart';
import 'item.dart';
import 'producer.dart';

/// 칸 점유물.
///
/// 새 보드 요소 추가 = 하위 타입 추가 후 [BoardModel.tryMove]의 switch에
/// 판정 분기를 추가한다. sealed라서 분기 누락은 컴파일 에러로 잡힌다.
sealed class CellContent {
  const CellContent();
}

final class ItemContent extends CellContent {
  const ItemContent(this.item);

  final Item item;
}

final class GeneratorContent extends CellContent {
  const GeneratorContent(this.generator);

  final Generator generator;
}

final class ProducerContent extends CellContent {
  const ProducerContent(this.producer);

  final Producer producer;
}
