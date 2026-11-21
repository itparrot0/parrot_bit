import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/format.dart';
import '../data/providers.dart';
import '../domain/domain.dart';

/// 기간 돌아보기 (PRD §3-4).
///
/// 고른 기간의 기록을 열 때 분석해서 (1) 며칠 이어진 흐름, (2) 마음을 차지했던
/// 생각과 그때 스스로 건넨 말(섞어서), (3) 개발자가 보내는 편지 한 문장을 보여 준다.
/// 리포트와 같은 원칙 — 묘사만 하고 판정하지 않는다.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  /// 빠르게 고르는 기간 (일).
  static const List<int> presets = [7, 14, 30];
  static const int defaultDays = 14;

  /// 한 번에 보여 줄 생각 수. 많으면 다시 섞어 다른 생각을 본다.
  static const int thoughtsShown = 5;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late DateRange _range = DateRange.lastDays(
    ref.read(todayProvider),
    ReviewScreen.defaultDays,
  );

  /// 고른 프리셋(일). 직접 고른 기간이면 null.
  int? _preset = ReviewScreen.defaultDays;

  /// 생각을 섞는 순서. 섞을 때마다 새로 정한다.
  late int _shuffleSeed = ref.read(randomProvider).nextInt(1 << 31);

  /// 편지는 화면을 열 때 한 번 고른다 — 기간을 바꿀 때마다 바뀌면 산만하다.
  late final String _letter = DeveloperLetters.pick(ref.read(randomProvider));

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(diaryEntriesProvider);
    final checkIns = ref.watch(checkInsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('기간 돌아보기')),
      body: SafeArea(
        child: entries.hasValue && checkIns.hasValue
            ? _buildBody(
                context,
                PeriodReview.of(
                  range: _range,
                  entries: entries.value!,
                  checkIns: checkIns.value!,
                  target: ref.watch(sleepTargetProvider),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PeriodReview review) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _buildRangePicker(context),
        const SizedBox(height: 16),
        if (review.isEmpty)
          const _Empty()
        else ...[
          _Summary(review: review),
          if (review.bedtime case final bedtime?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '잠든 시각은 평균 ${bedtime.averageBedtime}, '
                '${bedtime.level.description}',
                key: const Key('review.bedtime'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 24),
          _Runs(groups: review.groups),
          const SizedBox(height: 24),
          _Thoughts(
            thoughts: _shuffled(review.thoughts),
            total: review.thoughts.length,
            onShuffle: () => setState(
              () => _shuffleSeed = ref.read(randomProvider).nextInt(1 << 31),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _Letter(text: _letter),
      ],
    );
  }

  List<ThoughtPair> _shuffled(List<ThoughtPair> thoughts) {
    // 같은 시드면 같은 순서 — 다른 이유로 다시 그려도 카드가 뒤섞이지 않는다.
    final list = [...thoughts]..shuffle(Random(_shuffleSeed));
    return list.take(ReviewScreen.thoughtsShown).toList();
  }

  Widget _buildRangePicker(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final days in ReviewScreen.presets)
              ChoiceChip(
                label: Text('최근 $days일'),
                selected: _preset == days,
                onSelected: (_) => setState(() {
                  _preset = days;
                  _range = DateRange.lastDays(ref.read(todayProvider), days);
                }),
              ),
            ActionChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: const Text('직접 고르기'),
              onPressed: () => _pickRange(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${_dateLabel(_range.from)} ~ ${_dateLabel(_range.to)} · '
          '${_range.dayCount}일',
          key: const Key('review.range'),
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final today = ref.read(todayProvider);
    final entries = ref.read(diaryEntriesProvider).value ?? const [];
    final earliest = entries.isEmpty ? today.addDays(-365) : entries.first.date;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: earliest.isBefore(_range.from)
          ? earliest.toDateTime()
          : _range.from.toDateTime(),
      lastDate: today.toDateTime(),
      initialDateRange: DateTimeRange(
        start: _range.from.toDateTime(),
        end: _range.to.toDateTime(),
      ),
      helpText: '돌아볼 기간',
      saveText: '확인',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _preset = null;
      _range = DateRange(
        DiaryDate.fromDateTime(picked.start),
        DiaryDate.fromDateTime(picked.end),
      );
    });
  }
}

String _dateLabel(DiaryDate date) => '${date.month}월 ${date.day}일';

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        '이 기간에는 남긴 기록이 없어요.\n다른 기간을 골라 보세요.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.review});

  final PeriodReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = review.averageSleep;
    final items = [
      ('기록한 날', '${review.recordedDays}일'),
      ('평균 수면', average == null ? '-' : formatDuration(average)),
      ('생각 돌아보기', '${review.checkInCount}번'),
    ];
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            for (final (label, value) in items)
              Expanded(
                child: Column(
                  children: [
                    Text(value, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(label, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Runs extends StatelessWidget {
  const _Runs({required this.groups});

  final List<PatternGroup> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          '이어진 흐름',
          subtitle: '${PeriodReview.minimumRunDays}일 이상 이어진 날들을 모았어요.',
        ),
        if (groups.isEmpty)
          Text(
            '${PeriodReview.minimumRunDays}일 넘게 이어진 흐름은 없었어요.',
            style: theme.textTheme.bodyMedium,
          )
        else
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    group.kinds.every((kind) => kind.tone == Tone.light)
                        ? Icons.wb_sunny_outlined
                        : Icons.cloud_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_dateLabel(group.range.from)} ~ '
                          '${_dateLabel(group.range.to)} · '
                          '${group.range.dayCount}일',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        for (final kind in group.kinds)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              kind.description,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _Thoughts extends StatelessWidget {
  const _Thoughts({
    required this.thoughts,
    required this.total,
    required this.onShuffle,
  });

  final List<ThoughtPair> thoughts;
  final int total;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionTitle(
                '마음을 차지했던 생각들',
                subtitle: '그때 적은 생각과, 스스로에게 건넨 말이에요.',
              ),
            ),
            if (total > 1)
              TextButton.icon(
                onPressed: onShuffle,
                icon: const Icon(Icons.shuffle, size: 18),
                label: const Text('다시 섞기'),
              ),
          ],
        ),
        if (thoughts.isEmpty)
          Text(
            '이 기간에 적은 생각이 없어요. 생각 돌아보기에서 한 줄 적어 두면 여기에 모여요.',
            style: theme.textTheme.bodyMedium,
          )
        else
          for (final pair in thoughts)
            Card(
              key: ValueKey('thought.${pair.date}.${pair.thought}'),
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('“${pair.thought}”', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    if (pair.reframe case final reframe?)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.subdirectory_arrow_right,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              reframe,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        '이 생각에 건네고 싶은 말은 적지 않았어요. '
                        '지금이라면 어떤 말을 건네고 싶나요?',
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _dateLabel(pair.date),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('review.letter'),
      elevation: 0,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mail_outline,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  DeveloperLetters.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '— 슬립로그를 만든 사람',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
