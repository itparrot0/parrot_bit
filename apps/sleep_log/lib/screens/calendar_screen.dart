import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../data/providers.dart';
import '../domain/domain.dart';
import '../widgets/calendar/month_calendar.dart';

/// 홈 — 월간 달력. 날짜 칸에 z 단계를 표시한다 (PRD §4).
///
/// 구현 예정: 안전 배너(PRD §9-2) 노출.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final entries = ref.watch(diaryEntriesProvider);
    final target = ref.watch(sleepTargetProvider);
    final view = CalendarView.from(
      entries: entries.value ?? const [],
      target: target,
      today: today,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('슬립로그')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 오늘 기록이 없을 때만 (screen-flow §5). 기록을 읽기 전에는
              // 띄우지 않는다 — 떴다가 사라지면 깜박인다.
              if (entries.hasValue && !view.hasTodayEntry)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openEntry(context, today),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('오늘 기록'),
                    ),
                  ),
                ),
              MonthCalendar(
                // 넘길 수 있는 범위가 바뀌면 페이저를 새로 만든다. 가장 오래된
                // 기록이 바뀔 때만 일어나고, 달력은 원래 이번 달로 열린다.
                key: ValueKey(view.monthsBack),
                today: today,
                records: view.records,
                monthsBack: view.monthsBack,
                onDateTap: (date) => _openEntry(context, date),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEntry(BuildContext context, DiaryDate date) {
    context.pushNamed(Routes.entry, pathParameters: {'date': date.toIso()});
  }
}

/// 기록 목록을 달력이 그릴 값으로 바꾼 것. 위젯 없이 테스트할 수 있게 분리했다.
@immutable
final class CalendarView {
  const CalendarView({
    required this.records,
    required this.hasTodayEntry,
    required this.monthsBack,
  });

  factory CalendarView.from({
    required List<DiaryEntry> entries,
    required SleepTarget target,
    required DiaryDate today,
  }) {
    final records = {
      for (final entry in entries) entry.date: entry.markWith(target),
    };
    final earliest = entries.isEmpty ? null : entries.first.date;
    return CalendarView(
      records: records,
      hasTodayEntry: records.containsKey(today),
      monthsBack: monthsBackFor(earliest: earliest, today: today),
    );
  }

  /// 기록이 없어도 지난달까지는 넘길 수 있다. 1일 아침에 전날(지난달 말일)
  /// 기록을 빠뜨렸다면 그 달로 가서 적을 수 있어야 한다.
  static const int minimumMonthsBack = 1;

  /// [MonthCalendar.records]에 그대로 넣는다.
  final Map<DiaryDate, SleepMark?> records;

  final bool hasTodayEntry;

  /// 가장 오래된 기록이 있는 달까지의 개월 수.
  final int monthsBack;

  /// [earliest]가 속한 달부터 [today]의 달까지 몇 달인가. 최소
  /// [minimumMonthsBack]. 기기 시계가 되돌아가 기록이 오늘보다 미래여도
  /// 최소값으로 둔다.
  static int monthsBackFor({
    required DiaryDate? earliest,
    required DiaryDate today,
  }) {
    if (earliest == null) {
      return minimumMonthsBack;
    }
    final months =
        (today.year - earliest.year) * 12 + (today.month - earliest.month);
    return months < minimumMonthsBack ? minimumMonthsBack : months;
  }
}
