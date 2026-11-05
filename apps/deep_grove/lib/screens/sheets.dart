import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../domain/board_model.dart';
import '../economy/economy.dart';
import '../game/grove_game.dart';

String costText(Cost cost) =>
    cost.entries.map((e) => '${resourceLabel(e.key)} ${e.value}').join(' · ');

/// 복귀 보상 (화면 흐름 §5 `welcome_back`). 닫는 방법과 상관없이 호출한 쪽이 받는다 —
/// 뒤로가기로 닫아도 쌓인 자원을 잃지 않는다.
///
/// 창고에 들어갈 양과 넘쳐서 버려질 양을 미리 보여 준다.
Future<void> showWelcomeBack(
  BuildContext context, {
  required Map<Resource, int> gain,
  required Map<Resource, int> freeSpace,
}) => showModalBottomSheet<void>(
  context: context,
  builder: (context) => _SheetBody(
    title: '자리를 비운 동안 쌓였어요',
    children: [
      for (final MapEntry(:key, :value) in gain.entries)
        _Row(
          label: resourceLabel(key),
          value: (freeSpace[key] ?? 0) >= value
              ? '+$value'
              : '+${freeSpace[key]} (창고 가득 — ${value - freeSpace[key]!} 버려짐)',
        ),
      const SizedBox(height: AppSpacing.md),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('받기'),
      ),
    ],
  ),
);

/// 확장 확인 (화면 흐름 §5 `expand_confirm`). 확장하기로 하면 true.
Future<bool> showExpandConfirm(
  BuildContext context, {
  required ExpandDirection direction,
  required BoardModel board,
  required Economy economy,
  required Cost cost,
}) async {
  final (title, detail) = switch (direction) {
    ExpandDirection.widen => ('숲 넓히기', '오른쪽에 ${board.rows}칸이 열립니다.'),
    ExpandDirection.dig when !board.caveEntered => (
      '동굴 진입',
      '아래에 동굴 ${board.columns}칸이 열리고 자갈 생성기를 얻습니다.',
    ),
    ExpandDirection.dig => ('동굴 파기', '아래에 동굴 ${board.columns}칸이 열립니다.'),
    ExpandDirection.clear => ('테마 완주', '동굴이 있는 숲을 완성합니다.'),
  };
  final affordable = economy.canAfford(cost);
  final result = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) => _SheetBody(
      title: title,
      children: [
        Text(detail),
        const SizedBox(height: AppSpacing.md),
        for (final MapEntry(:key, :value) in cost.entries)
          _Row(
            label: resourceLabel(key),
            value: '${economy.amountOf(key)} / $value',
            warn: economy.amountOf(key) < value,
          ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: affordable ? () => Navigator.of(context).pop(true) : null,
          child: Text(affordable ? '확장' : '자원이 모자라요'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 창고 (화면 흐름 §5 `storage`).
Future<void> showStorage(
  BuildContext context, {
  required BoardModel board,
  required Economy Function() economy,
  required VoidCallback onUpgrade,
}) => showModalBottomSheet<void>(
  context: context,
  builder: (context) => StatefulBuilder(
    builder: (context, setState) {
      final e = economy();
      final perMinute = <Resource, double>{};
      for (final (pos, producer) in board.producers) {
        perMinute.update(
          producer.chain.resource,
          (v) => v + board.rateAt(pos, producer) * 60,
          ifAbsent: () => board.rateAt(pos, producer) * 60,
        );
      }
      final upgradeCost = e.storageUpgradeCost;
      return _SheetBody(
        title: '창고',
        children: [
          for (final r in Resource.values)
            if (r == Resource.wood || board.caveEntered)
              _Row(
                label: resourceLabel(r),
                value:
                    '${e.amountOf(r)} / ${e.capacity}'
                    '   분당 +${(perMinute[r] ?? 0).toStringAsFixed(1)}',
                warn: e.isFull(r),
              ),
          const SizedBox(height: AppSpacing.sm),
          const Text('창고가 가득 차면 산출이 멈춰요.'),
          const SizedBox(height: AppSpacing.md),
          if (upgradeCost != null)
            FilledButton(
              onPressed: e.canAfford(upgradeCost)
                  ? () {
                      onUpgrade();
                      setState(() {});
                    }
                  : null,
              child: Text('창고 확장 (${costText(upgradeCost)})'),
            )
          else
            const Text('창고가 최대 크기예요.'),
        ],
      );
    },
  ),
);

Future<void> showNotice(
  BuildContext context, {
  required String title,
  required String body,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text(body),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('확인'),
      ),
    ],
  ),
);

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? Theme.of(context).colorScheme.error : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(value, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
