import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/format.dart';
import '../data/providers.dart';
import '../domain/domain.dart';

/// 일별 기록 — 취침·기상 시각과 감정 태그 (docs/screen-flow/sleep_log.md §5).
///
/// - 자정 넘김을 묻지 않는다. "취침은 전날, 기상은 당일"로 해석한다.
/// - 수면시간과 z 단계를 입력 즉시 보여준다.
/// - 수면만, 태그만으로도 저장된다. 둘 다 없으면 저장할 수 없다.
/// - 이미 기록된 날이면 편집 모드로 열리고, 여기서 삭제한다.
/// - 저장하지 않고 나가면 변경 내용을 버릴지 묻는다.
class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({required this.date, super.key});

  /// 기록 대상 날짜 (ISO-8601 yyyy-MM-dd). 라우트 경로에서 온다.
  final String date;

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  /// 새 기록에서 "수면 시각 넣기"를 누르면 채워지는 값. 지난 기록이 있으면
  /// 가장 최근 기록의 시각을 쓴다 — 보통 매일 비슷한 시각에 잔다.
  static final ClockTime _defaultBedTime = ClockTime(23, 0);
  static final ClockTime _defaultWakeTime = ClockTime(7, 0);

  late final DiaryDate? _date = DiaryDate.tryParseIso(widget.date);

  bool _loading = true;
  DiaryEntry? _saved;

  /// 태그 배치 순서. 화면이 열릴 때 한 번 정한다 — 고르는 중에 칩이 움직이면
  /// 누르려던 자리에 다른 태그가 온다.
  Map<MoodGroup, List<MoodTag>> _tagOrder = {
    for (final group in MoodGroup.values) group: DefaultMoodTags.ofGroup(group),
  };

  ClockTime? _bedTime;
  ClockTime? _wakeTime;
  Set<MoodTag> _tags = {};
  RestFeeling? _rested;

  /// 새 기록에서 수면을 처음 넣을 때 쓸 시각 (가장 최근 수면 기록).
  SleepSession? _lastSleep;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final date = _date;
    if (date == null) {
      setState(() => _loading = false);
      return;
    }
    final repository = ref.read(diaryRepositoryProvider);
    final saved = await repository.find(date);
    final entries = await repository.watchAll().first;
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _saved = saved;
      _bedTime = saved?.sleep?.bedTime;
      _wakeTime = saved?.sleep?.wakeTime;
      _tags = {...?saved?.tags};
      _rested = saved?.rested;
      _tagOrder = {
        for (final group in MoodGroup.values)
          group: TagOrder.forGroup(group, entries),
      };
      _lastSleep = entries.reversed
          .map((entry) => entry.sleep)
          .nonNulls
          .firstOrNull;
    });
  }

  bool get _hasSleep => _bedTime != null && _wakeTime != null;

  bool get _sleepIsValid =>
      !_hasSleep || SleepSession.isValidRange(_bedTime!, _wakeTime!);

  SleepSession? get _sleep => _hasSleep && _sleepIsValid
      ? SleepSession(bedTime: _bedTime!, wakeTime: _wakeTime!)
      : null;

  DiaryEntry? get _draft {
    final date = _date;
    return date == null
        ? null
        : DiaryEntry(date: date, sleep: _sleep, tags: _tags, rested: _rested);
  }

  bool get _canSave {
    final draft = _draft;
    return draft != null && !draft.isEmpty && _sleepIsValid && !_saving;
  }

  bool get _isDirty {
    final saved = _saved;
    final savedSleep = saved?.sleep;
    return _bedTime != savedSleep?.bedTime ||
        _wakeTime != savedSleep?.wakeTime ||
        _rested != saved?.rested ||
        !_sameTags(_tags, saved?.tags ?? const {});
  }

  static bool _sameTags(Set<MoodTag> a, Set<MoodTag> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  Widget build(BuildContext context) {
    final date = _date;
    final today = ref.watch(todayProvider);

    if (date == null || date.isAfter(today)) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(date == null ? '날짜를 읽을 수 없어요.' : '미래 날짜는 기록할 수 없어요.'),
        ),
      );
    }

    return PopScope(
      canPop: _loading || !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_dateLabel(date)),
          actions: [
            if (_saved != null)
              IconButton(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                tooltip: '기록 삭제',
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildForm(context),
        bottomNavigationBar: _loading
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: const Text('저장'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const _SectionTitle('수면'),
        if (_hasSleep) ..._buildSleepInputs(context) else _buildAddSleep(),
        const SizedBox(height: 16),
        const _SectionTitle('일어났을 때'),
        _buildRested(),
        const Divider(height: 32),
        const _SectionTitle('지금 상태'),
        for (final group in MoodGroup.values)
          if (group.isMood) _buildTagGroup(group),
        const Divider(height: 32),
        // 생활은 감정이 아니라 어제 한 일이라 따로 묻는다 (PRD §3-1).
        const _SectionTitle('어제 하루'),
        _buildTagGroup(MoodGroup.lifestyle),
      ],
    );
  }

  /// 개운함 — 하나만 고르고, 다시 누르면 풀린다. 수면 시각 없이도 남길 수 있다.
  Widget _buildRested() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final feeling in RestFeeling.values)
            ChoiceChip(
              label: Text(feeling.label),
              selected: _rested == feeling,
              onSelected: (picked) =>
                  setState(() => _rested = picked ? feeling : null),
            ),
        ],
      ),
    );
  }

  Widget _buildAddSleep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () => setState(() {
          _bedTime = _lastSleep?.bedTime ?? _defaultBedTime;
          _wakeTime = _lastSleep?.wakeTime ?? _defaultWakeTime;
        }),
        icon: const Icon(Icons.bedtime_outlined),
        label: const Text('수면 시각 넣기'),
      ),
    );
  }

  List<Widget> _buildSleepInputs(BuildContext context) {
    final theme = Theme.of(context);
    final target = ref.watch(sleepTargetProvider);
    final sleep = _sleep;

    return [
      ListTile(
        leading: const Icon(Icons.bedtime_outlined),
        title: const Text('잠든 시각'),
        trailing: Text(_bedTime.toString(), style: theme.textTheme.titleMedium),
        onTap: () => _pickTime(isBedTime: true),
      ),
      ListTile(
        leading: const Icon(Icons.wb_sunny_outlined),
        title: const Text('일어난 시각'),
        trailing: Text(
          _wakeTime.toString(),
          style: theme.textTheme.titleMedium,
        ),
        onTap: () => _pickTime(isBedTime: false),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: sleep == null
                  ? Text(
                      '잠든 시각과 일어난 시각이 같아요.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    )
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatDuration(sleep.duration),
                            style: theme.textTheme.titleLarge,
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: target.markFor(sleep.duration).label,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      key: const Key('entry.sleepSummary'),
                    ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _bedTime = null;
                _wakeTime = null;
              }),
              child: const Text('수면 지우기'),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildTagGroup(MoodGroup group) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final tag in _tagOrder[group]!)
            FilterChip(
              label: Text(tag.label),
              selected: _tags.contains(tag),
              onSelected: (selected) => setState(() {
                _tags = selected ? {..._tags, tag} : ({..._tags}..remove(tag));
              }),
            ),
        ],
      ),
    );
  }

  Future<void> _pickTime({required bool isBedTime}) async {
    final current = isBedTime ? _bedTime! : _wakeTime!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: isBedTime ? '잠든 시각' : '일어난 시각',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      final time = ClockTime(picked.hour, picked.minute);
      if (isBedTime) {
        _bedTime = time;
      } else {
        _wakeTime = time;
      }
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(diaryRepositoryProvider).save(draft);
    } on Object {
      _showFailure('저장하지 못했어요. 다시 시도해 주세요.');
      return;
    }
    if (!mounted) {
      return;
    }
    // Navigator.pop은 PopScope.canPop을 보지 않으므로 변경 확인 없이 닫힌다.
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('이 날의 기록을 지울까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(diaryRepositoryProvider).delete(_date!);
    } on Object {
      _showFailure('지우지 못했어요. 다시 시도해 주세요.');
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _showFailure(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('저장하지 않은 내용을 버릴까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 쓰기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('버리기'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  static const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  static String _dateLabel(DiaryDate date) =>
      '${date.month}월 ${date.day}일 (${_weekdays[date.toDateTime().weekday - 1]})';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
