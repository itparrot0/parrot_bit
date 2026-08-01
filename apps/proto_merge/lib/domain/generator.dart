import 'cell_pos.dart';
import 'item.dart';

/// 보드 위 생성기: 자기 칸에 고정되고, 탭하면 정의된 아이템을 만든다.
///
/// 생성기 추가 = [BoardModel] 생성 시 generators 목록에 인스턴스 추가.
/// 체인별 생성기, 상위 레벨 생성기 모두 이 정의만으로 표현된다.
final class Generator {
  const Generator({
    required this.cell,
    required this.spawnChain,
    this.spawnLevel = 1,
  });

  final CellPos cell;
  final ItemChain spawnChain;
  final int spawnLevel;

  Item produce() => Item(spawnChain, spawnLevel);
}
