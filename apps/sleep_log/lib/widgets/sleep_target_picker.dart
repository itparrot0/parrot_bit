import 'package:flutter/material.dart';

import '../app/format.dart';
import '../domain/domain.dart';

/// 목표 수면시간을 고르는 −/+ 조절기. 온보딩과 설정이 같이 쓴다.
class TargetStepper extends StatelessWidget {
  const TargetStepper({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 한 번 누를 때 바뀌는 양.
  static const Duration step = Duration(minutes: 30);

  final Duration value;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrease = value - step >= SleepTarget.minDuration;
    final canIncrease = value + step <= SleepTarget.maxDuration;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.outlined(
          onPressed: canDecrease ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove),
          tooltip: '30분 줄이기',
        ),
        SizedBox(
          width: 160,
          child: Text(
            formatDuration(value),
            key: const Key('targetStepper.value'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
        ),
        IconButton.outlined(
          onPressed: canIncrease ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add),
          tooltip: '30분 늘리기',
        ),
      ],
    );
  }
}

/// 고른 목표로 z 네 단계의 경계를 보여 준다.
///
/// 판정이 아니라 양을 보여 주는 표시라서(PRD §4) "부족/충분" 같은 평가 말 대신
/// 시간 범위만 적는다.
class MarkLegend extends StatelessWidget {
  const MarkLegend({required this.target, super.key});

  final SleepTarget target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bounds = target.bounds;
    final rows = [
      (SleepMark.short, '${formatDuration(bounds.fairFrom)} 미만'),
      (
        SleepMark.fair,
        '${formatDuration(bounds.fairFrom)} ~ ${formatDuration(bounds.enoughFrom)}',
      ),
      (
        SleepMark.enough,
        '${formatDuration(bounds.enoughFrom)} ~ ${formatDuration(bounds.overAbove)}',
      ),
      (SleepMark.over, '${formatDuration(bounds.overAbove)} 초과'),
    ];

    return Column(
      children: [
        for (final (mark, range) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    mark.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Text(range, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}
