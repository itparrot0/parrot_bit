import 'package:deep_grove/domain/board_model.dart';
import 'package:deep_grove/economy/economy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  const theme = forestCaveTheme;

  test('창고는 용량을 넘는 몫을 버린다', () {
    const economy = Economy(theme: theme);
    expect(economy.capacity, 30);
    final (next, accepted) = economy.add(Resource.wood, 45);
    expect(accepted, 30);
    expect(next.amountOf(Resource.wood), 30);
    expect(next.isFull(Resource.wood), isTrue);
    expect(next.freeSpace, {Resource.wood: 0, Resource.ore: 30});
  });

  test('비용을 낼 수 있을 때만 pay', () {
    const economy = Economy(theme: theme, amounts: {Resource.wood: 10});
    expect(economy.canAfford({Resource.wood: 10}), isTrue);
    expect(economy.canAfford({Resource.wood: 5, Resource.ore: 1}), isFalse);
    expect(economy.pay({Resource.wood: 4}).amountOf(Resource.wood), 6);
    expect(() => economy.pay({Resource.ore: 1}), throwsStateError);
  });

  test('창고 확장은 비용을 내고 용량을 올린다, 최고 단계에서 멈춘다', () {
    var economy = const Economy(
      theme: theme,
      amounts: {Resource.wood: 60, Resource.ore: 25},
    );
    economy = economy.upgradeStorage();
    expect((economy.capacity, economy.amountOf(Resource.wood)), (60, 40));
    economy = economy.upgradeStorage();
    expect(economy.capacity, 120);
    expect(economy.amounts, {Resource.wood: 0, Resource.ore: 0});
    expect(economy.canUpgradeStorage, isFalse);
    expect(economy.storageUpgradeCost, isNull);
  });

  test('칸 비용은 지대별로 "몇 번째로 여는 칸인가"로 정한다', () {
    const economy = Economy(theme: theme);
    final board = emptyBoard();
    // 숲 첫 칸은 어느 칸이든 같은 값
    expect(economy.expansionCost(const UnlockCell((col: 3, row: 0)), board), {
      Resource.wood: 2,
    });
    expect(economy.expansionCost(const UnlockCell((col: 3, row: 3)), board), {
      Resource.wood: 2,
    });
    // 동굴 첫 칸 = 동굴 진입
    expect(economy.expansionCost(const UnlockCell((col: 0, row: 4)), board), {
      Resource.wood: 12,
    });
    board.unlock((col: 3, row: 0));
    expect(economy.expansionCost(const UnlockCell((col: 3, row: 1)), board), {
      Resource.wood: 3,
    });
    // 동굴 비용은 숲을 열어도 그대로
    expect(economy.expansionCost(const UnlockCell((col: 0, row: 4)), board), {
      Resource.wood: 12,
    });
  });

  test('열 수 없는 칸·이미 열린 칸은 null', () {
    const economy = Economy(theme: theme);
    final board = emptyBoard();
    expect(
      economy.expansionCost(const UnlockCell((col: 5, row: 0)), board),
      isNull,
    );
    expect(
      economy.expansionCost(const UnlockCell((col: 0, row: 0)), board),
      isNull,
    );
  });

  test('테마 완주는 모든 칸을 연 뒤에만, 한 번만', () {
    const economy = Economy(theme: theme);
    final board = emptyBoard();
    expect(economy.expansionCost(const ClearTheme(), board), isNull);
    board.openAll();
    expect(economy.expansionCost(const ClearTheme(), board), theme.clearCost);
    expect(
      economy.markCleared().expansionCost(const ClearTheme(), board),
      isNull,
    );
  });

  test('비용표 길이 = 열 수 있는 칸 수 (숲 12, 동굴 18)', () {
    expect(
      theme.forestCellCosts,
      hasLength(theme.maxColumns * theme.forestRows - theme.startCellCount),
    );
    expect(theme.caveCellCosts, hasLength(theme.maxColumns * theme.caveRows));
  });

  test('모든 비용은 최고 창고 용량 안에 든다 (완주 가능)', () {
    final top = theme.storageCapacities.last;
    final everyCost = [
      ...theme.forestCellCosts,
      ...theme.caveCellCosts,
      ...theme.storageUpgradeCosts,
      theme.clearCost,
    ];
    for (final cost in everyCost) {
      for (final amount in cost.values) {
        expect(amount, lessThanOrEqualTo(top));
      }
    }
  });

  test('광석이 들어오기 전 선택지는 목재만 요구한다', () {
    // 동굴 진입 전에 열 수 있는 숲 칸(앞 6칸)·동굴 진입·첫 창고 확장
    for (final cost in theme.forestCellCosts.take(6)) {
      expect(cost.keys, [Resource.wood]);
    }
    expect(theme.caveCellCosts.first.keys, [Resource.wood]);
    expect(theme.storageUpgradeCosts.first.keys, [Resource.wood]);
  });

  test('저장 형식 왕복', () {
    const economy = Economy(
      theme: theme,
      amounts: {Resource.wood: 3, Resource.ore: 9},
      storageLevel: 1,
      cleared: true,
    );
    final restored = Economy.fromJson(economy.toJson(), theme);
    expect(restored.toJson(), economy.toJson());
  });
}
