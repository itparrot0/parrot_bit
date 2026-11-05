import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import 'calendar_month.dart';
import 'month_grid.dart';

/// 좌우로 넘기는 월간 달력.
///
/// **항상 이번 달로 열린다** — 마지막으로 보던 월을 기억하지 않는다. 일상
/// 사용에서 보고 싶은 것은 늘 이번 달이다 (docs/screen-flow/sleep_log.md §5).
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    required this.today,
    this.records = const {},
    this.onDateTap,
    this.monthsBack = 24,
    this.firstWeekday = DateTime.sunday,
    super.key,
  });

  /// 오늘. 시계를 위젯이 읽지 않고 받는다 — 테스트가 날짜를 고정할 수 있어야 한다.
  final DiaryDate today;

  /// [MonthGrid.records]와 같은 규칙.
  final Map<DiaryDate, SleepMark?> records;

  final ValueChanged<DiaryDate>? onDateTap;

  /// 과거로 넘길 수 있는 개월 수. 미래로는 넘어갈 수 없다 (기록할 수 없는
  /// 날들이다).
  ///
  /// 앱에서는 가장 오래된 기록의 달에서 구한다(`CalendarView.monthsBack`).
  /// 생성 후 바뀌어도 페이저에 반영되지 않으므로, 값이 바뀌면 key를 바꿔
  /// 새로 만든다.
  final int monthsBack;

  final int firstWeekday;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late final CalendarMonth _currentMonth = CalendarMonth.of(widget.today);
  late final PageController _controller = PageController(
    initialPage: widget.monthsBack,
  );

  /// 이번 달이 마지막 페이지다.
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.monthsBack;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CalendarMonth _monthAt(int index) =>
      _currentMonth.addMonths(index - widget.monthsBack);

  bool get _isAtCurrentMonth => _pageIndex == widget.monthsBack;

  void _goTo(int index) {
    if (index < 0 || index > widget.monthsBack) {
      return;
    }
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        // 6행 고정이라 달마다 높이가 튀지 않는다 (CalendarMonth.rowCount).
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: MonthGrid.heightFor(constraints.maxWidth),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.monthsBack + 1,
                onPageChanged: (index) => setState(() => _pageIndex = index),
                itemBuilder: (context, index) => MonthGrid(
                  month: _monthAt(index),
                  today: widget.today,
                  records: widget.records,
                  onDateTap: widget.onDateTap,
                  firstWeekday: widget.firstWeekday,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: _pageIndex > 0 ? () => _goTo(_pageIndex - 1) : null,
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전 달',
        ),
        Expanded(
          child: Text(
            _monthAt(_pageIndex).label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        // 이번 달이 마지막이다 — 미래로는 넘어가지 않는다.
        if (_isAtCurrentMonth)
          const SizedBox(width: 48)
        else
          IconButton(
            onPressed: () => _goTo(_pageIndex + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: '다음 달',
          ),
        // 다른 달을 보고 있을 때만 돌아오는 길을 준다.
        if (_isAtCurrentMonth)
          const SizedBox(width: 48)
        else
          IconButton(
            onPressed: () => _goTo(widget.monthsBack),
            icon: const Icon(Icons.today),
            tooltip: '오늘',
          ),
      ],
    );
  }
}
