import 'cell_pos.dart';
import 'generator.dart';
import 'item.dart';
import 'zone.dart';

/// 자원 비용 (자원 → 양).
typedef Cost = Map<Resource, int>;

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
    required this.maxColumns,
    required this.caveRows,
    required this.forestCellCosts,
    required this.caveCellCosts,
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

  /// 시작 때 열린 칸: 왼쪽 위 [startColumns]열 × 숲 [forestRows]행.
  final int startColumns;
  final int forestRows;

  /// 테마의 최대 보드: [maxColumns]열 × (숲 [forestRows] + 동굴 [caveRows])행.
  /// 숲이 위, 동굴이 아래. 확장은 이 안에서 **한 칸씩** 연다 (테마 문서 §7-1).
  final int maxColumns;
  final int caveRows;

  final Map<CellPos, ItemChain> startGenerators;
  final Map<CellPos, (ItemChain, int)> startItems;

  /// 숲 칸을 n번째로 열 때의 비용 (`[n - 1]`). 길이 = 시작 뒤 열 수 있는 숲 칸 수.
  final List<Cost> forestCellCosts;

  /// 동굴 칸을 n번째로 열 때의 비용. 첫 칸이 동굴 진입이다. 길이 = 동굴 칸 수.
  final List<Cost> caveCellCosts;

  /// 동굴 진입 때 새 동굴 칸에 놓아 주는 생성기의 체인 (자갈 생성기).
  final ItemChain caveGeneratorChain;

  /// 모든 칸을 연 뒤 테마 완주에 드는 비용.
  final Cost clearCost;

  /// 창고 단계별 용량 (자원마다 같은 용량). 길이가 창고 최고 단계다.
  final List<int> storageCapacities;

  /// 창고 단계 n → n+1 비용. 길이 = [storageCapacities] 길이 - 1.
  final List<Cost> storageUpgradeCosts;

  /// 산출원 하나가 자원 1을 내는 데 걸리는 초.
  final double secondsPerUnit;

  /// 산출원이 자기 체인의 지대에 있을 때 산출량 배율 (테마 문서 §7-6).
  final double homeZoneBonus;

  int get maxRows => forestRows + caveRows;

  int get startCellCount => startColumns * forestRows;

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
  maxColumns: 6,
  caveRows: 3,
  // 숲 12칸: 광석이 없는 동안(동굴 진입 전)에도 열 수 있게 앞 6칸은 목재만.
  forestCellCosts: [
    {Resource.wood: 2},
    {Resource.wood: 3},
    {Resource.wood: 4},
    {Resource.wood: 5},
    {Resource.wood: 6},
    {Resource.wood: 8},
    {Resource.wood: 10, Resource.ore: 3},
    {Resource.wood: 12, Resource.ore: 4},
    {Resource.wood: 14, Resource.ore: 5},
    {Resource.wood: 16, Resource.ore: 6},
    {Resource.wood: 18, Resource.ore: 8},
    {Resource.wood: 20, Resource.ore: 10},
  ],
  // 동굴 18칸: 첫 칸 = 동굴 진입(자갈 생성기). 광석이 나오기 전 몇 칸은 목재만.
  caveCellCosts: [
    {Resource.wood: 12},
    {Resource.wood: 5},
    {Resource.wood: 6},
    {Resource.wood: 8},
    {Resource.wood: 10, Resource.ore: 2},
    {Resource.wood: 12, Resource.ore: 3},
    {Resource.wood: 14, Resource.ore: 4},
    {Resource.wood: 16, Resource.ore: 5},
    {Resource.wood: 18, Resource.ore: 6},
    {Resource.wood: 20, Resource.ore: 7},
    {Resource.wood: 22, Resource.ore: 8},
    {Resource.wood: 24, Resource.ore: 9},
    {Resource.wood: 26, Resource.ore: 10},
    {Resource.wood: 28, Resource.ore: 12},
    {Resource.wood: 30, Resource.ore: 14},
    {Resource.wood: 32, Resource.ore: 16},
    {Resource.wood: 34, Resource.ore: 18},
    {Resource.wood: 36, Resource.ore: 20},
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
