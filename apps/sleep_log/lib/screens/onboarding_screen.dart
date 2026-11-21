import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../data/providers.dart';
import '../domain/domain.dart';
import '../widgets/sleep_target_picker.dart';

/// 최초 실행 — 목표 수면시간 설정.
///
/// 이 값이 없으면 z 표시가 성립하지 않으므로, 설정 전에는 달력으로 보내지 않는다
/// (docs/screen-flow/sleep_log.md §2). 저장하면 라우터가 달력으로 옮긴다.
///
/// 남의 기준(8시간)이 아니라 **자기 기준**이 이 앱의 존재 이유라(PRD §1), 고른
/// 값에 따라 z가 어떻게 찍히는지를 바로 보여 준다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  Duration _target = SleepTarget.defaultTarget.duration;
  bool _saving = false;

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
            TargetStepper(
              value: _target,
              onChanged: (value) => setState(() => _target = value),
            ),
            const SizedBox(height: 40),
            Text('달력에는 이렇게 표시돼요', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            MarkLegend(target: SleepTarget(_target)),
            const SizedBox(height: 32),
            // 새 폰에서는 처음부터 다시 정하지 않고 이전 기기의 기록을 옮겨 온다.
            Center(
              child: TextButton.icon(
                onPressed: () => context.pushNamed(Routes.backup),
                icon: const Icon(Icons.download),
                label: const Text('이전 기기의 백업 가져오기'),
              ),
            ),
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
