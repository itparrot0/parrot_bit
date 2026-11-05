import 'cell_pos.dart';
import 'generator.dart';
import 'item.dart';
import 'zone.dart';

/// 자원 비용 (자원 → 양).
typedef Cost = Map<Resource, int>;

/// 확장 한 단계.
final class ExpansionStep {
  const ExpansionStep(this.cost);

  final Cost cost;
}

/// 테마 하나의 전체 데이터 (테마 문서 §8 "테마 = 데이터").
///
/// **게임 숫자의 단일 출처다.** 문서(§5)의 표는 의도만 남기고, 실제 값은 여기서 고친다.
/// 테마 추가 = 이 클래스의 const 인스턴스를 하나 더 만드는 것.
final class GroveTheme {
  const GroveTheme({
    required this.id,
    required this.chains,
    required this.spawnOdds,
    required this.startColumns,
    required this.forestRows,
    required this.startGenerators,
    required this.startItems,
    required this.widenSteps,
    required this.digSteps,
    required this.caveGeneratorChain,
    required this.clearCost,
    required this.storageCapacities,
    required this.storageUpgradeCosts,
    required this.secondsPerUnit,
    required this.homeZoneBonus,
  });

  final String id;

  /// 이 테마의 체인. 저장 형식이 체인 id로 다시 찾는다.
  final List<ItemChain> chains;

  /// 생성기 레벨별 스폰 확률표. 길이가 생성기 최고 레벨이다.
  final SpawnOdds spawnOdds;

  /// 시작 보드: 열 수 × 숲 행 수. 동굴은 0행에서 시작한다.
  final int startColumns;
  final int forestRows;

  final Map<CellPos, ItemChain> startGenerators;
  final Map<CellPos, (ItemChain, int)> startItems;

  /// 가로 확장(오른쪽 손잡이): 단계마다 열 +1. 숲·동굴이 함께 넓어진다.
  final List<ExpansionStep> widenSteps;

  /// 하향 확장(아래 손잡이): 단계마다 동굴 행 +1. 첫 단계가 동굴 진입이다.
  final List<ExpansionStep> digSteps;

  /// 동굴 진입 때 새 동굴 칸에 놓아 주는 생성기의 체인 (자갈 생성기).
  final ItemChain caveGeneratorChain;

  /// 두 방향 확장을 다 끝낸 뒤 테마 완주에 드는 비용.
  final Cost clearCost;

  /// 창고 단계별 용량 (자원마다 같은 용량). 길이가 창고 최고 단계다.
  final List<int> storageCapacities;

  /// 창고 단계 n → n+1 비용. 길이 = [storageCapacities] 길이 - 1.
  final List<Cost> storageUpgradeCosts;

  /// 산출원 하나가 자원 1을 내는 데 걸리는 초.
  final double secondsPerUnit;

  /// 산출원이 자기 체인의 지대에 있을 때 산출량 배율 (테마 문서 §7-6).
  final double homeZoneBonus;

  int get maxColumns => startColumns + widenSteps.length;
  int get maxCaveRows => digSteps.length;

  ItemChain chainById(String id) => chains.firstWhere((c) => c.id == id);

  Generator generatorFor(ItemChain chain, {int level = 1}) =>
      Generator(spawnChain: chain, odds: spawnOdds, level: level);
}

const ItemChain woodChain = ItemChain(
  id: 'wood',
  levelNames: ['씨앗', '새싹', '묘목', '나무', '거목'],
  resource: Resource.wood,
  homeZone: Zone.forest,
);

const ItemChain stoneChain = ItemChain(
  id: 'stone',
  levelNames: ['자갈', '돌멩이', '바위', '암반', '광석바위'],
  resource: Resource.ore,
  homeZone: Zone.cave,
);

/// 첫 테마 — 동굴이 있는 숲 (테마 문서 §3). 값은 첫 값이다 (PRD §10-3).
const GroveTheme forestCaveTheme = GroveTheme(
  id: 'forest_cave',
  chains: [woodChain, stoneChain],
  spawnOdds: SpawnOdds([
    [1],
    [0.7, 0.3],
    [0.5, 0.35, 0.15],
  ]),
  startColumns: 3,
  forestRows: 4,
  startGenerators: {(col: 1, row: 3): woodChain},
  startItems: {
    (col: 0, row: 3): (woodChain, 1),
    (col: 2, row: 3): (woodChain, 1),
  },
  widenSteps: [
    ExpansionStep({Resource.wood: 5}),
    ExpansionStep({Resource.wood: 20, Resource.ore: 8}),
    ExpansionStep({Resource.wood: 40, Resource.ore: 20}),
  ],
  digSteps: [
    ExpansionStep({Resource.wood: 12}),
    ExpansionStep({Resource.wood: 25, Resource.ore: 10}),
    ExpansionStep({Resource.wood: 40, Resource.ore: 25}),
  ],
  caveGeneratorChain: stoneChain,
  clearCost: {Resource.wood: 80, Resource.ore: 50},
  storageCapacities: [30, 60, 120],
  storageUpgradeCosts: [
    {Resource.wood: 20},
    {Resource.wood: 40, Resource.ore: 25},
  ],
  secondsPerUnit: 20,
  homeZoneBonus: 1.5,
);
