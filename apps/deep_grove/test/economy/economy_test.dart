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

  test('확장 비용은 보드 크기를 따라가고, 끝난 방향은 null', () {
    const economy = Economy(theme: theme);
    final board = emptyBoard();
    expect(economy.expansionCost(ExpandDirection.widen, board), {
      Resource.wood: 5,
    });
    expect(economy.expansionCost(ExpandDirection.dig, board), {
      Resource.wood: 12,
    });
    expect(economy.expansionCost(ExpandDirection.clear, board), isNull);

    board
      ..widen()
      ..dig();
    expect(economy.expansionCost(ExpandDirection.widen, board), {
      Resource.wood: 20,
      Resource.ore: 8,
    });

    board
      ..widen()
      ..widen()
      ..dig()
      ..dig();
    expect(economy.expansionCost(ExpandDirection.widen, board), isNull);
    expect(economy.expansionCost(ExpandDirection.dig, board), isNull);
    expect(
      economy.expansionCost(ExpandDirection.clear, board),
      theme.clearCost,
    );
    expect(
      economy.markCleared().expansionCost(ExpandDirection.clear, board),
      isNull,
    );
  });

  test('테마 완주 비용은 최고 창고 용량 안에 든다 (완주 가능)', () {
    final top = theme.storageCapacities.last;
    final everyCost = [
      ...theme.widenSteps.map((s) => s.cost),
      ...theme.digSteps.map((s) => s.cost),
      ...theme.storageUpgradeCosts,
      theme.clearCost,
    ];
    for (final cost in everyCost) {
      for (final amount in cost.values) {
        expect(amount, lessThanOrEqualTo(top));
      }
    }
  });

  test('광석은 동굴 진입 뒤에만 들어오므로 첫 확장 두 갈래는 목재만 요구한다', () {
    expect(theme.widenSteps.first.cost.keys, [Resource.wood]);
    expect(theme.digSteps.first.cost.keys, [Resource.wood]);
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
