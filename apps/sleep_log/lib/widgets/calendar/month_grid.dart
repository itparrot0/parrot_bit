import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import 'calendar_month.dart';

/// 한 달의 날짜 그리드. 날짜 칸에 z 표시를 찍는다 (docs/prd/sleep_log.md §4).
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    required this.month,
    required this.today,
    this.records = const {},
    this.onDateTap,
    this.firstWeekday = DateTime.sunday,
    super.key,
  });

  final CalendarMonth month;

  /// 오늘. 미래 날짜를 막고 오늘 칸을 표시하는 기준이다. 시계를 위젯이 읽지
  /// 않고 받는다 — 그래야 테스트가 날짜를 고정할 수 있다.
  final DiaryDate today;

  /// 날짜별 표시.
  ///
  /// **키가 있으면 기록이 있는 날이다.** 값이 null이면 태그만 남겨 수면 기록이
  /// 없는 날이고, 이때 z 표시 대신 점을 찍는다. 키가 없으면 기록이 없는 날이다.
  final Map<DiaryDate, SleepMark?> records;

  final ValueChanged<DiaryDate>? onDateTap;

  final int firstWeekday;

  /// 요일 라벨 행의 높이. 페이저가 전체 높이를 잡을 때 같은 값을 써야 하므로
  /// 여기 한 곳에 둔다 — 두 곳에 적으면 어긋나 그리드가 넘친다.
  static const double weekdayRowHeight = 32;

  /// [width]일 때 이 그리드가 차지하는 높이.
  static double heightFor(double width) =>
      width / CalendarMonth.columnCount * CalendarMonth.rowCount +
      weekdayRowHeight;

  @override
  Widget build(BuildContext context) {
    final dates = month.gridDates(firstWeekday: firstWeekday);
    final labels = CalendarMonth.weekdayLabels(firstWeekday: firstWeekday);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth / CalendarMonth.columnCount;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (final label in labels)
                  SizedBox(
                    width: cellSize,
                    height: weekdayRowHeight,
                    child: _WeekdayLabel(label: label),
                  ),
              ],
            ),
            for (var row = 0; row < CalendarMonth.rowCount; row++)
              Row(
                children: [
                  for (
                    var column = 0;
                    column < CalendarMonth.columnCount;
                    column++
                  )
                    SizedBox(
                      width: cellSize,
                      height: cellSize,
                      child: _buildCell(
                        dates[row * CalendarMonth.columnCount + column],
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildCell(DiaryDate date) {
    final isCurrentMonth = month.contains(date);
    // 미래는 기록할 수 없으므로 선택 자체를 막는다
    // (docs/screen-flow/sleep_log.md §5).
    final isFuture = date.isAfter(today);
    final isEnabled = isCurrentMonth && !isFuture;

    return _DayCell(
      date: date,
      isCurrentMonth: isCurrentMonth,
      isToday: date == today,
      isFuture: isFuture,
      hasRecord: isCurrentMonth && records.containsKey(date),
      mark: isCurrentMonth ? records[date] : null,
      onTap: isEnabled && onDateTap != null ? () => onDateTap!(date) : null,
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 달력 한 칸.
///
/// **모든 z 표시가 같은 색이다.** 수면량은 색이 아니라 **표시 길이**로 드러난다
/// (PRD §4) — 부족을 빨강으로 칠하면 앱이 판정을 내리는 것이 되고, 그건 이
/// 앱에서 하지 않기로 한 일이다.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isFuture,
    required this.hasRecord,
    required this.mark,
    this.onTap,
  });

  final DiaryDate date;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isFuture;
  final bool hasRecord;
  final SleepMark? mark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final dayColor = switch ((isCurrentMonth, isFuture)) {
      (false, _) => colors.onSurface.withValues(alpha: 0.22),
      (true, true) => colors.onSurface.withValues(alpha: 0.32),
      (true, false) => colors.onSurface,
    };

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.primary, width: 1.5),
                  )
                : null,
            child: Text(
              '${date.day}',
              style: textTheme.bodySmall?.copyWith(color: dayColor),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(height: 16, child: _buildMark(context)),
        ],
      ),
    );
  }

  Widget _buildMark(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // 앞뒤 달과 미래는 표시하지 않는다 — 달 단위로 패턴을 읽는 데 방해가 된다.
    if (!isCurrentMonth || isFuture) {
      return const SizedBox.shrink();
    }

    final sleepMark = mark;
    if (sleepMark != null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          sleepMark.label,
          style: TextStyle(
            fontSize: 13,
            height: 1,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      );
    }

    // 기록 없는 날과 "태그만 남긴 날"을 점의 진하기로 구분한다.
    // 둘을 같게 그리면 적어둔 날이 안 적은 날처럼 보인다 (PRD §4).
    return Center(
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasRecord
              ? colors.onSurfaceVariant
              : colors.onSurfaceVariant.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
