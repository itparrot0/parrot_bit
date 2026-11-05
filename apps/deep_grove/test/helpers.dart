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
  maxColumns: forestCaveTheme.maxColumns,
  caveRows: forestCaveTheme.caveRows,
  forestCellCosts: forestCaveTheme.forestCellCosts,
  caveCellCosts: forestCaveTheme.caveCellCosts,
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

extension BoardTestOpen on BoardModel {
  /// 지금 열린 열 폭만큼 첫 동굴 행을 연다. 가운데 칸을 먼저 열어서 자갈 생성기가
  /// 가운데(시작 보드면 (1,4))에 놓인다.
  void openCaveRow() {
    final width = unlocked
        .where((p) => p.row == forestRows - 1)
        .map((p) => p.col)
        .reduce((a, b) => a > b ? a : b);
    final row = forestRows;
    final middle = (width + 1) ~/ 2;
    unlock((col: middle, row: row));
    for (var col = 0; col <= width; col++) {
      unlock((col: col, row: row));
    }
  }

  /// 최대 보드를 모두 연다.
  void openAll() {
    while (frontier.isNotEmpty) {
      unlock(frontier.first);
    }
  }
}
