import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/format.dart';
import '../data/providers.dart';
import '../domain/domain.dart';

/// 최초 실행 — 목표 수면시간 설정.
///
/// 이 값이 없으면 z 표시가 성립하지 않으므로, 설정 전에는 달력으로 보내지 않는다
/// (docs/screen-flow/sleep_log.md §2). 저장하면 라우터가 달력으로 옮긴다.
///
/// 남의 기준(8시간)이 아니라 **자기 기준**이 이 앱의 존재 이유라(PRD §1), 고른
/// 값에 따라 z가 어떻게 찍히는지를 바로 보여 준다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  /// 한 번 누를 때 바뀌는 양.
  static const Duration step = Duration(minutes: 30);

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  Duration _target = SleepTarget.defaultTarget.duration;
  bool _saving = false;

  bool get _canDecrease =>
      _target - OnboardingScreen.step >= SleepTarget.minDuration;

  bool get _canIncrease =>
      _target + OnboardingScreen.step <= SleepTarget.maxDuration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Text('나에게 맞는 수면시간', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              '적당한 수면시간은 사람마다 달라요.\n'
              '평소에 개운했던 날을 떠올려 정해 주세요. '
              '나중에 설정에서 바꿀 수 있어요.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  onPressed: _canDecrease
                      ? () => setState(() => _target -= OnboardingScreen.step)
                      : null,
                  icon: const Icon(Icons.remove),
                  tooltip: '30분 줄이기',
                ),
                SizedBox(
                  width: 180,
                  child: Text(
                    formatDuration(_target),
                    key: const Key('onboarding.target'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                IconButton.outlined(
                  onPressed: _canIncrease
                      ? () => setState(() => _target += OnboardingScreen.step)
                      : null,
                  icon: const Icon(Icons.add),
                  tooltip: '30분 늘리기',
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text('달력에는 이렇게 표시돼요', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _MarkLegend(target: SleepTarget(_target)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: FilledButton(
            onPressed: _saving ? null : _start,
            child: const Text('시작하기'),
          ),
        ),
      ),
    );
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    try {
      // 저장되면 라우터가 달력으로 옮긴다 (redirect).
      await ref
          .read(savedSleepTargetProvider.notifier)
          .set(SleepTarget(_target));
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 시도해 주세요.')));
    }
  }
}

/// 고른 목표로 z 네 단계의 경계를 보여 준다.
///
/// 판정이 아니라 양을 보여 주는 표시라서(PRD §4) "부족/충분" 같은 평가 말 대신
/// 시간 범위만 적는다.
class _MarkLegend extends StatelessWidget {
  const _MarkLegend({required this.target});

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
