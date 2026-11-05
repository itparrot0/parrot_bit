import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/format.dart';
import '../data/providers.dart';
import '../domain/domain.dart';

/// 리포트 — 태그별 평균 수면시간 대조 (PRD §3-5, screen-flow §5).
///
/// - 수면을 기록한 날이 2주([TagSleepReport.minimumDays]) 미만이면 리포트 대신
///   "며칠 더" 안내만 한다. 표본이 적을 때 나오는 상관은 틀리고, 틀린 인상을
///   한 번 주면 신뢰를 잃는다.
/// - **대조만 한다.** 전체 평균을 기준선으로 두고 태그별 평균을 나란히 놓을 뿐,
///   인과나 진단으로 읽히는 문장을 쓰지 않는다 (PRD §9-2).
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(diaryEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('리포트')),
      body: SafeArea(
        child: switch (entries) {
          AsyncData(:final value) =>
            TagSleepReport.hasEnoughData(value)
                ? _Report(entries: value)
                : _NotYet(sleepDays: TagSleepReport.sleepDayCount(value)),
          AsyncError() => const Center(child: Text('기록을 읽지 못했어요.')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _NotYet extends StatelessWidget {
  const _NotYet({required this.sleepDays});

  final int sleepDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const needed = TagSleepReport.minimumDays;
    final remaining = needed - sleepDays;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '수면을 $remaining일 더 기록하면 보여 드려요',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '어떤 기분일 때 얼마나 잤는지 나란히 보려면\n'
              '적어도 $needed일은 쌓여야 해요.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(value: sleepDays / needed),
            ),
            const SizedBox(height: 8),
            Text('$sleepDays / $needed일', style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _Report extends ConsumerWidget {
  const _Report({required this.entries});

  final List<DiaryEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = TagSleepReport.build(entries);
    final paceStats = PaceSleepReport.build(
      entries,
      ref.watch(checkInsProvider).value ?? const [],
    );
    final overall = TagSleepReport.overallAverage(entries)!;
    final days = TagSleepReport.sleepDayCount(entries);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('태그를 붙인 날의 평균 수면시간', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '수면을 기록한 $days일 기준이에요. '
            '함께 기록된 것을 나란히 놓았을 뿐, 원인을 뜻하지는 않아요.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          key: const Key('report.overall'),
          title: const Text('전체 평균'),
          trailing: Text(
            formatDuration(overall),
            style: theme.textTheme.titleMedium,
          ),
        ),
        const Divider(),
        if (stats.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('수면과 함께 태그를 붙인 날이 아직 없어요.'),
          )
        else
          for (final stat in stats)
            ListTile(
              title: Text(stat.tag.label),
              subtitle: Text('${stat.dayCount}일'),
              trailing: Text(
                formatDuration(stat.averageSleep),
                style: theme.textTheme.titleMedium,
              ),
            ),
        // 생각 돌아보기를 쓰는 사람에게만, 충분히 쌓였을 때만 (PRD §3-3).
        if (PaceSleepReport.hasEnoughData(paceStats)) ...[
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('머릿속 속도별 그날의 수면시간', style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '생각 돌아보기에서 고른 속도와 그날 아침까지의 잠을 나란히 놓았어요.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final stat in paceStats)
            ListTile(
              title: Text(stat.pace.label),
              subtitle: Text('${stat.dayCount}일'),
              trailing: Text(
                formatDuration(stat.averageSleep),
                style: theme.textTheme.titleMedium,
              ),
            ),
        ],
      ],
    );
  }
}
