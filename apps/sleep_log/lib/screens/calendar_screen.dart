import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../domain/domain.dart';
import '../widgets/calendar/month_calendar.dart';

/// 홈 — 월간 달력. 날짜 칸에 z 단계를 표시한다 (PRD §4).
///
/// 구현 예정: 기록을 저장 계층에서 받아 [MonthCalendar.records]에 넣기,
/// 안전 배너(PRD §9-2) 노출.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(sleep_log): today와 records를 Provider에서 받는다. 지금은 시계를
    // 직접 읽고 기록이 비어 있어 모든 날이 "기록 없음"으로 그려진다.
    final today = DiaryDate.fromDateTime(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('슬립로그')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // TODO(sleep_log): 오늘 기록이 있으면 숨긴다 (screen-flow §5).
              // 지금은 기록 여부를 알 수 없어 항상 보인다.
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
                today: today,
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
