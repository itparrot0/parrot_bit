import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/domain.dart';

/// 생각 돌아보기 — 오전·오후 짧은 체크인 (PRD §3-3).
///
/// **묻지 않고 권한다.** 증상을 확인하는 문장이 아니라 "잠깐 돌아볼까요" 하는
/// 제안으로 쓰고, 모든 항목을 건너뛸 수 있다. 답에 앱이 반응하지 않는다 —
/// 판정하지 않고, 저장 후 칭찬·경고도 하지 않는다.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({required this.date, required this.slot, super.key});

  /// 라우트 경로에서 온 날짜(ISO)와 시간대 이름.
  final String date;
  final String slot;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  late final DiaryDate? _date = DiaryDate.tryParseIso(widget.date);
  late final CheckInSlot? _slot = CheckInSlot.tryParse(widget.slot);

  final _thought = TextEditingController();
  final _reframe = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  MindPace? _pace;
  SenseShift? _senses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _thought.dispose();
    _reframe.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final date = _date;
    final slot = _slot;
    final saved = date == null || slot == null
        ? null
        : await ref.read(checkInRepositoryProvider).find(date, slot);
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _pace = saved?.pace;
      _senses = saved?.senses;
      _thought.text = saved?.thought ?? '';
      _reframe.text = saved?.reframe ?? '';
    });
  }

  ThoughtCheckIn get _draft => ThoughtCheckIn(
    date: _date!,
    slot: _slot!,
    pace: _pace,
    senses: _senses,
    thought: _thought.text,
    reframe: _reframe.text,
  );

  @override
  Widget build(BuildContext context) {
    final date = _date;
    final slot = _slot;
    final today = ref.watch(todayProvider);

    if (date == null || slot == null || date.isAfter(today)) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('이 날은 돌아볼 수 없어요.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${slot.label}의 생각 돌아보기')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    '잠깐 멈춰서 지금의 나를 살펴봐요. '
                    '답하고 싶은 것만 골라도 괜찮아요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  _Question(
                    title: '오늘 머릿속은 어떤 속도였나요?',
                    child: _Choices<MindPace>(
                      values: MindPace.values,
                      selected: _pace,
                      label: (pace) => pace.label,
                      onChanged: (pace) => setState(() => _pace = pace),
                    ),
                  ),
                  _Question(
                    title:
                        '주변의 소리나 빛, 몸의 느낌이 평소와 조금 다르게 '
                        '다가온 순간이 있었나요?',
                    child: _Choices<SenseShift>(
                      values: SenseShift.values,
                      selected: _senses,
                      label: (senses) => senses.label,
                      onChanged: (senses) => setState(() => _senses = senses),
                    ),
                  ),
                  _Question(
                    title:
                        '지금 마음을 가장 많이 차지한 생각이 있다면, '
                        '한 줄로 적어 볼까요?',
                    child: TextField(
                      key: const Key('checkIn.thought'),
                      controller: _thought,
                      maxLines: null,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        hintText: '예) 오늘 발표를 망칠 것 같다',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  // 생각을 적었을 때만 다음 질문을 보여 준다 — 비어 있는 생각에
                  // "다른 눈으로 보기"를 권하면 어색하다.
                  if (_thought.text.trim().isNotEmpty)
                    _Question(
                      title:
                          '같은 생각을 친한 친구가 털어놓는다면, '
                          '어떤 말을 건네주고 싶나요?',
                      hint: '그 생각과 다른 이야기를 하는 일이 있었는지 떠올려 봐도 좋아요.',
                      child: TextField(
                        key: const Key('checkIn.reframe'),
                        controller: _reframe,
                        maxLines: null,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('남겨 두기'),
                ),
              ),
            ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(checkInRepositoryProvider).save(_draft);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 시도해 주세요.')));
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// 하나만 고르는 칩. 고른 것을 다시 누르면 선택이 풀린다(건너뛰기).
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(label(value)),
            selected: value == selected,
            onSelected: (picked) => onChanged(picked ? value : null),
          ),
      ],
    );
  }
}
