import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/format.dart';
import '../app/router.dart';
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
      appBar: AppBar(
        title: const Text('리포트'),
        actions: [
          TextButton.icon(
            onPressed: () => context.pushNamed(Routes.review),
            icon: const Icon(Icons.date_range),
            label: const Text('기간 돌아보기'),
          ),
        ],
      ),
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
    final moodStats = [
      for (final stat in stats)
        if (stat.tag.group.isMood) stat,
    ];
    final lifestyleStats = [
      for (final stat in stats)
        if (!stat.tag.group.isMood) stat,
    ];
    final paceStats = PaceSleepReport.build(
      entries,
      ref.watch(checkInsProvider).value ?? const [],
    );
    final restStats = RestSleepReport.build(entries);
    // 습관은 바뀌므로 최근 기록으로 본다.
    final recent = entries.length <= _recentDays
        ? entries
        : entries.sublist(entries.length - _recentDays);
    final bedtime = BedtimeRegularity.of(recent);
    final overall = TagSleepReport.overallAverage(entries)!;
    final days = TagSleepReport.sleepDayCount(entries);

    ListTile row(String title, String count, Duration average) => ListTile(
      title: Text(title),
      subtitle: Text(count),
      trailing: Text(
        formatDuration(average),
        style: theme.textTheme.titleMedium,
      ),
    );

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _Heading(
          '태그를 붙인 날의 평균 수면시간',
          '수면을 기록한 $days일 기준이에요. '
              '함께 기록된 것을 나란히 놓았을 뿐, 원인을 뜻하지는 않아요.',
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
        if (moodStats.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('수면과 함께 기분 태그를 붙인 날이 아직 없어요.'),
          )
        else
          for (final stat in moodStats)
            row(stat.tag.label, '${stat.dayCount}일', stat.averageSleep),
        if (lifestyleStats.isNotEmpty) ...[
          const Divider(height: 32),
          const _Heading(
            '어제 한 일과 그날 밤의 수면',
            '생활 태그를 붙인 날의 평균이에요. 스스로 바꿔 볼 수 있는 것들이에요.',
          ),
          for (final stat in lifestyleStats)
            row(stat.tag.label, '${stat.dayCount}일', stat.averageSleep),
        ],
        if (bedtime != null) ...[
          const Divider(height: 32),
          _Heading('잠든 시각', '최근 ${bedtime.dayCount}일 기준이에요.'),
          ListTile(
            key: const Key('report.bedtime'),
            title: Text(bedtime.level.description),
            subtitle: Text('보통 ${formatDuration(bedtime.spread)} 정도 앞뒤로 움직였어요'),
            trailing: Text(
              '평균 ${bedtime.averageBedtime}',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
        if (RestSleepReport.hasEnoughData(restStats)) ...[
          const Divider(height: 32),
          const _Heading('개운함별 수면시간', '일어났을 때 고른 느낌과 그날의 잠을 나란히 놓았어요.'),
          for (final stat in restStats)
            row(stat.feeling.label, '${stat.dayCount}일', stat.averageSleep),
        ],
        // 생각 돌아보기를 쓰는 사람에게만, 충분히 쌓였을 때만 (PRD §3-3).
        if (PaceSleepReport.hasEnoughData(paceStats)) ...[
          const Divider(height: 32),
          const _Heading(
            '머릿속 속도별 그날의 수면시간',
            '생각 돌아보기에서 고른 속도와 그날 아침까지의 잠을 나란히 놓았어요.',
          ),
          for (final stat in paceStats)
            row(stat.pace.label, '${stat.dayCount}일', stat.averageSleep),
        ],
      ],
    );
  }

  /// 잠든 시각 규칙성을 볼 최근 기록 수.
  static const int _recentDays = 14;
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
