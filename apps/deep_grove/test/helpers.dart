import 'dart:math';

import 'package:deep_grove/domain/board_model.dart';

/// 첫 테마와 숫자는 같고 시작 배치만 빈 테마 — 칸을 직접 놓고 시험한다.
final GroveTheme emptyStartTheme = GroveTheme(
  id: forestCaveTheme.id,
  chains: forestCaveTheme.chains,
  spawnOdds: forestCaveTheme.spawnOdds,
  startColumns: forestCaveTheme.startColumns,
  forestRows: forestCaveTheme.forestRows,
  startGenerators: const {},
  startItems: const {},
  widenSteps: forestCaveTheme.widenSteps,
  digSteps: forestCaveTheme.digSteps,
  caveGeneratorChain: forestCaveTheme.caveGeneratorChain,
  clearCost: forestCaveTheme.clearCost,
  storageCapacities: forestCaveTheme.storageCapacities,
  storageUpgradeCosts: forestCaveTheme.storageUpgradeCosts,
  secondsPerUnit: forestCaveTheme.secondsPerUnit,
  homeZoneBonus: forestCaveTheme.homeZoneBonus,
);

BoardModel emptyBoard({int seed = 1}) =>
    BoardModel(emptyStartTheme, random: Random(seed));

Generator gen(ItemChain chain, [int level = 1]) =>
    forestCaveTheme.generatorFor(chain, level: level);

CellPos at(int col, int row) => (col: col, row: row);

/// 모든 자원에 넉넉한 창고 빈 공간.
const Map<Resource, int> plenty = {Resource.wood: 1000, Resource.ore: 1000};
