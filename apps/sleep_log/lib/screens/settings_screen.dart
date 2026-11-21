import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/format.dart';
import '../app/router.dart';
import '../data/providers.dart';
import '../domain/domain.dart';
import '../widgets/sleep_target_picker.dart';
import '../widgets/support_contacts.dart';

/// 설정 — 목표 수면시간, 안전 안내 on/off, 생각 돌아보기, 기록 전체 삭제
/// (docs/screen-flow/sleep_log.md §5).
///
/// v1에 없는 것: 기록 리마인더 알림, 데이터 내보내기 — PRD §3의 Could 항목이라
/// 기능이 생길 때 여기에 더한다. 동작하지 않는 항목을 미리 두지 않는다.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(sleepTargetProvider);
    final safetyNotice = ref.watch(safetyNoticeEnabledProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('목표 수면시간'),
            subtitle: const Text('달력의 z 표시가 이 시간을 기준으로 정해져요.'),
            trailing: Text(
              formatDuration(target.duration),
              style: theme.textTheme.titleMedium,
            ),
            onTap: () => _changeTarget(context, ref, target),
          ),
          SwitchListTile(
            key: const Key('settings.safetyNotice'),
            secondary: const Icon(Icons.favorite_border),
            title: const Text('마음 돌봄 안내'),
            subtitle: const Text('힘든 기분이 이어지면 달력 위에 조용히 알려 드려요.'),
            // 읽는 동안에는 기본값(켜짐)으로 보이되 누를 수 없게 둔다.
            value: safetyNotice.value ?? true,
            onChanged: safetyNotice.hasValue
                ? (enabled) => ref
                      .read(safetyNoticeEnabledProvider.notifier)
                      .set(enabled)
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('도움받을 수 있는 곳'),
            subtitle: const Text('누르면 전화 앱이 그 번호로 열려요.'),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 60, right: 16),
            child: SupportContactButtons(),
          ),
          const Divider(height: 32),
          ..._buildCheckIn(context, ref),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('백업과 기기 이전'),
            subtitle: const Text('폰을 바꾸기 전에 기록을 파일로 옮겨 두세요.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed(Routes.backup),
          ),
          const Divider(height: 32),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: theme.colorScheme.error,
            ),
            title: Text(
              '모든 기록 지우기',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('이 기기에 저장된 수면·기분 기록과 생각 돌아보기를 전부 지워요.'),
            onTap: () => _deleteAll(context, ref),
          ),
        ],
      ),
    );
  }

  /// 생각 돌아보기 (PRD §3-3) — 켜기·끄기와 오전·오후 알림 시각.
  List<Widget> _buildCheckIn(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(checkInSettingsProvider);
    final value = settings.value ?? CheckInSettings();
    final theme = Theme.of(context);

    return [
      SwitchListTile(
        key: const Key('settings.checkIn'),
        secondary: const Icon(Icons.self_improvement),
        title: const Text('생각 돌아보기'),
        subtitle: const Text('오전·오후에 잠깐 머릿속 속도와 마음을 살펴보자고 알려 드려요.'),
        value: value.enabled,
        onChanged: settings.hasValue
            ? (enabled) =>
                  _saveCheckIn(context, ref, value.copyWith(enabled: enabled))
            : null,
      ),
      if (value.enabled)
        for (final slot in CheckInSlot.values)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 72, right: 16),
            title: Text('${slot.label} 알림'),
            trailing: Text(
              value.timeOf(slot).toString(),
              style: theme.textTheme.titleMedium,
            ),
            onTap: () => _pickCheckInTime(context, ref, value, slot),
          ),
    ];
  }

  Future<void> _pickCheckInTime(
    BuildContext context,
    WidgetRef ref,
    CheckInSettings current,
    CheckInSlot slot,
  ) async {
    final time = current.timeOf(slot);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
      helpText: '${slot.label} 알림 시각',
    );
    if (picked == null || !context.mounted) {
      return;
    }
    // 알림으로 연 체크인이 그 시간대로 저장되려면 오전은 14시 전, 오후는 그 뒤여야 한다.
    final isMorningHour = picked.hour < CheckInSlot.afternoonFromHour;
    if (isMorningHour != (slot == CheckInSlot.morning)) {
      _showMessage(
        context,
        slot == CheckInSlot.morning
            ? '오전 알림은 ${CheckInSlot.afternoonFromHour}시 전으로 골라 주세요.'
            : '오후 알림은 ${CheckInSlot.afternoonFromHour}시 이후로 골라 주세요.',
      );
      return;
    }
    final chosen = ClockTime(picked.hour, picked.minute);
    await _saveCheckIn(
      context,
      ref,
      slot == CheckInSlot.morning
          ? current.copyWith(morningTime: chosen)
          : current.copyWith(afternoonTime: chosen),
    );
  }

  Future<void> _saveCheckIn(
    BuildContext context,
    WidgetRef ref,
    CheckInSettings settings,
  ) async {
    try {
      final canNotify = await ref
          .read(checkInSettingsProvider.notifier)
          .set(settings);
      if (!canNotify && context.mounted) {
        _showMessage(
          context,
          '알림이 허용되지 않았어요. 기기 설정에서 허용하면 받을 수 있어요. '
          '달력의 버튼으로는 언제든 할 수 있어요.',
        );
      }
    } on Object {
      if (context.mounted) {
        _showMessage(context, '저장하지 못했어요. 다시 시도해 주세요.');
      }
    }
  }

  Future<void> _changeTarget(
    BuildContext context,
    WidgetRef ref,
    SleepTarget current,
  ) async {
    final picked = await showDialog<Duration>(
      context: context,
      builder: (context) => _TargetDialog(initial: current.duration),
    );
    if (picked == null || picked == current.duration) {
      return;
    }
    try {
      await ref
          .read(savedSleepTargetProvider.notifier)
          .set(SleepTarget(picked));
    } on Object {
      if (context.mounted) {
        _showMessage(context, '저장하지 못했어요. 다시 시도해 주세요.');
      }
    }
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모든 기록을 지울까요?'),
        content: const Text('지운 기록은 되돌릴 수 없어요. 목표 수면시간 같은 설정은 그대로 남아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('모두 지우기'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(diaryRepositoryProvider).deleteAll();
      await ref.read(checkInRepositoryProvider).deleteAll();
      if (context.mounted) {
        _showMessage(context, '모든 기록을 지웠어요.');
      }
    } on Object {
      if (context.mounted) {
        _showMessage(context, '지우지 못했어요. 다시 시도해 주세요.');
      }
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 목표 수면시간 변경 대화상자.
///
/// **바꾸면 지난 달력의 z가 전부 다시 계산된다는 것을 미리 알린다** — 저장된
/// 것은 수면시간이고 z는 목표 대비 판정이라서, 안내 없이 지난 달력이 달라지면
/// 버그로 보인다 (screen-flow §5).
class _TargetDialog extends StatefulWidget {
  const _TargetDialog({required this.initial});

  final Duration initial;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late Duration _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('목표 수면시간'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TargetStepper(
            value: _value,
            onChanged: (value) => setState(() => _value = value),
          ),
          const SizedBox(height: 16),
          Text(
            '바꾸면 지난 기록의 z 표시도 새 목표에 맞춰 다시 계산돼요. '
            '기록한 수면시간은 그대로예요.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
