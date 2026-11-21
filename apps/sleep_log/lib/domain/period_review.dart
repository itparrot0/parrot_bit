import 'diary_date.dart';
import 'diary_entry.dart';
import 'mood_tag.dart';
import 'sleep_habits.dart';
import 'sleep_mark.dart';
import 'thought_check_in.dart';

/// 처음과 끝을 포함하는 날짜 구간.
final class DateRange {
  DateRange(this.from, this.to) {
    if (from.isAfter(to)) {
      throw ArgumentError('구간의 시작($from)이 끝($to)보다 늦다');
    }
  }

  /// [to]까지 [days]일 (끝 날 포함).
  factory DateRange.lastDays(DiaryDate to, int days) =>
      DateRange(to.addDays(-(days - 1)), to);

  final DiaryDate from;
  final DiaryDate to;

  bool contains(DiaryDate date) => !date.isBefore(from) && !date.isAfter(to);

  /// UTC로 세야 서머타임 전환일(23·25시간)에도 하루가 하루로 세진다.
  int get dayCount =>
      DateTime.utc(
        to.year,
        to.month,
        to.day,
      ).difference(DateTime.utc(from.year, from.month, from.day)).inDays +
      1;

  Iterable<DiaryDate> get days sync* {
    for (var day = from; !day.isAfter(to); day = day.addDays(1)) {
      yield day;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'DateRange($from ~ $to)';
}

/// 며칠 이어지면 알려 줄 만한 흐름.
///
/// **판정이 아니라 묘사다.** "이런 날이 이어졌어요"까지만 말하고 원인이나 평가를
/// 붙이지 않는다 (PRD §9-2). 좋은 흐름도 같이 알려 준다 — 힘든 구간만 골라
/// 보여 주면 돌아보기가 반성문이 된다.
enum PatternKind {
  /// 수면이 짧고 마음도 힘든 날이 겹쳤다. 겹침이 더 의미 있으므로 먼저 보인다.
  shortSleepWithLowMood('잠이 짧았고 마음도 힘들었던 날이 겹쳤어요', tone: Tone.heavy),

  /// 수면이 짧고 머릿속도 바빴다.
  shortSleepWithBusyMind('잠이 짧았고 머릿속도 바쁘게 돌아간 날이 겹쳤어요', tone: Tone.heavy),

  shortSleep('목표보다 적게 잔 날이 이어졌어요', tone: Tone.heavy),
  lateBedtime('새벽 1시가 넘어 잠든 날이 이어졌어요', tone: Tone.heavy),
  overSleep('목표보다 훨씬 오래 잔 날이 이어졌어요', tone: Tone.heavy),
  lowMood('힘든 기분을 기록한 날이 이어졌어요', tone: Tone.heavy),
  busyMind('머릿속이 바쁘게 돌아간 날이 이어졌어요', tone: Tone.heavy),
  senseShift('주변이나 몸의 느낌이 평소와 다르게 다가온 날이 이어졌어요', tone: Tone.heavy),

  /// 잠은 목표만큼 잤는데 일어났을 때 덜 풀렸다고 고른 날.
  restedMismatch('잠은 충분했는데 덜 풀린 날이 이어졌어요', tone: Tone.heavy),

  /// 잠든 시각이 전날보다 [PeriodReview.bedtimeSwing] 넘게 달라진 날.
  bedtimeSwing('잠든 시각이 하루하루 크게 오르내린 날이 이어졌어요', tone: Tone.heavy),

  enoughSleep('목표만큼 푹 잔 날이 이어졌어요', tone: Tone.light),
  goodMood('좋은 기분을 기록한 날이 이어졌어요', tone: Tone.light);

  const PatternKind(this.description, {required this.tone});

  final String description;
  final Tone tone;
}

/// 흐름의 결. 화면이 아이콘·색을 고를 때만 쓴다 — 경고색은 쓰지 않는다.
enum Tone { heavy, light }

/// 한 흐름이 이어진 구간.
typedef PatternRun = ({PatternKind kind, DateRange range});

/// 같은 기간에 함께 이어진 흐름들. 화면은 이 단위로 한 줄씩 보여 준다.
typedef PatternGroup = ({DateRange range, List<PatternKind> kinds});

/// "마음을 차지했던 생각"과 그때 스스로 건넨 말.
typedef ThoughtPair = ({DiaryDate date, String thought, String? reframe});

/// 기간 돌아보기 분석 (PRD §3-4).
final class PeriodReview {
  PeriodReview._({
    required this.range,
    required this.recordedDays,
    required this.averageSleep,
    required this.checkInCount,
    required this.runs,
    required this.thoughts,
    required this.bedtime,
  });

  /// [range] 안의 기록·체크인을 분석한다.
  factory PeriodReview.of({
    required DateRange range,
    required Iterable<DiaryEntry> entries,
    required Iterable<ThoughtCheckIn> checkIns,
    required SleepTarget target,
  }) {
    final byDate = {
      for (final entry in entries)
        if (range.contains(entry.date)) entry.date: entry,
    };
    final checkInsByDate = <DiaryDate, List<ThoughtCheckIn>>{};
    for (final checkIn in checkIns) {
      if (range.contains(checkIn.date)) {
        checkInsByDate.putIfAbsent(checkIn.date, () => []).add(checkIn);
      }
    }

    final sleeps = byDate.values.map((e) => e.sleepDuration).nonNulls.toList();
    final averageSleep = sleeps.isEmpty
        ? null
        : Duration(
            minutes:
                sleeps.fold(0, (sum, d) => sum + d.inMinutes) ~/ sleeps.length,
          );

    bool matches(PatternKind kind, DiaryDate date) {
      final entry = byDate[date];
      final mark = entry?.markWith(target);
      final dayCheckIns = checkInsByDate[date] ?? const [];
      final shortSleep = mark != null && mark.isShortOfTarget;
      final busy = dayCheckIns.any((c) => c.pace == MindPace.busy);
      return switch (kind) {
        PatternKind.shortSleepWithLowMood =>
          shortSleep && (entry?.hasNegativeMood ?? false),
        PatternKind.shortSleepWithBusyMind => shortSleep && busy,
        PatternKind.shortSleep => shortSleep,
        PatternKind.lateBedtime => _isLateBedtime(entry),
        PatternKind.overSleep => mark == SleepMark.over,
        PatternKind.lowMood => entry?.hasNegativeMood ?? false,
        PatternKind.busyMind => busy,
        PatternKind.senseShift => dayCheckIns.any(
          (c) => c.senses == SenseShift.some || c.senses == SenseShift.often,
        ),
        PatternKind.restedMismatch =>
          (mark?.meetsTarget ?? false) && entry?.rested == RestFeeling.unrested,
        PatternKind.bedtimeSwing => _swungFromPreviousDay(byDate, date),
        PatternKind.enoughSleep => mark?.meetsTarget ?? false,
        PatternKind.goodMood =>
          entry?.tags.any((t) => t.group == MoodGroup.positive) ?? false,
      };
    }

    final runs = <PatternRun>[];
    for (final kind in PatternKind.values) {
      DiaryDate? start;
      DiaryDate? last;
      void close() {
        // 클로저가 잡은 지역 변수라 null 승격이 안 된다 — 한 번 꺼내 쓴다.
        final (runStart, runEnd) = (start, last);
        if (runStart != null && runEnd != null) {
          final run = DateRange(runStart, runEnd);
          if (run.dayCount >= minimumRunDays) {
            runs.add((kind: kind, range: run));
          }
        }
        start = null;
        last = null;
      }

      for (final day in range.days) {
        if (matches(kind, day)) {
          start ??= day;
          last = day;
        } else {
          // 기록이 없는 날도 흐름을 끊는다 — 모르는 날을 이어졌다고 말하지 않는다.
          close();
        }
      }
      close();
    }
    // 최근 구간부터, 같은 날 끝나면 긴 것부터, 그다음 PatternKind 순서(겹침 먼저).
    runs.sort((a, b) {
      final byEnd = b.range.to.compareTo(a.range.to);
      if (byEnd != 0) {
        return byEnd;
      }
      final byLength = b.range.dayCount.compareTo(a.range.dayCount);
      return byLength != 0 ? byLength : a.kind.index.compareTo(b.kind.index);
    });

    final thoughts = [
      for (final checkIn in checkIns)
        if (range.contains(checkIn.date) && checkIn.thought != null)
          (
            date: checkIn.date,
            thought: checkIn.thought!,
            reframe: checkIn.reframe,
          ),
    ];

    return PeriodReview._(
      range: range,
      recordedDays: byDate.length,
      averageSleep: averageSleep,
      checkInCount: checkInsByDate.values.fold(0, (sum, l) => sum + l.length),
      runs: runs,
      thoughts: thoughts,
      bedtime: BedtimeRegularity.of(byDate.values),
    );
  }

  /// 이만큼 이어져야 "흐름"이라고 부른다. 이틀은 우연일 수 있다.
  static const int minimumRunDays = 3;

  final DateRange range;
  final int recordedDays;

  /// 수면을 기록한 날의 평균. 없으면 null.
  final Duration? averageSleep;
  final int checkInCount;

  /// 이어진 흐름들 (최근 것부터).
  final List<PatternRun> runs;

  /// 겹침 흐름이 이미 말해 주는 개별 흐름. 같은 구간 안에 겹침이 있으면 따로
  /// 말하지 않는다 — "잠이 짧았고 마음도 힘들었다" 다음에 "잠이 짧았다"를 또
  /// 말하면 같은 이야기를 되풀이하게 된다.
  static const Map<PatternKind, Set<PatternKind>> _covers = {
    PatternKind.shortSleepWithLowMood: {
      PatternKind.shortSleep,
      PatternKind.lowMood,
    },
    PatternKind.shortSleepWithBusyMind: {
      PatternKind.shortSleep,
      PatternKind.busyMind,
    },
  };

  /// [runs]를 화면에 보일 단위로 묶는다. 겹침이 덮는 개별 흐름은 빼고, 시작과
  /// 끝이 같은 흐름은 한 묶음으로 만든다. 순서는 [runs]를 따른다.
  List<PatternGroup> get groups {
    bool covered(PatternRun run) => runs.any(
      (other) =>
          (_covers[other.kind]?.contains(run.kind) ?? false) &&
          !run.range.from.isBefore(other.range.from) &&
          !run.range.to.isAfter(other.range.to),
    );

    final byRange = <DateRange, List<PatternKind>>{};
    for (final run in runs) {
      if (!covered(run)) {
        byRange.putIfAbsent(run.range, () => []).add(run.kind);
      }
    }
    return [
      for (final MapEntry(key: range, value: kinds) in byRange.entries)
        (
          range: range,
          kinds: kinds..sort((a, b) => a.index.compareTo(b.index)),
        ),
    ];
  }

  /// 기간 안에 적은 생각들 (화면이 섞어서 보여 준다).
  final List<ThoughtPair> thoughts;

  /// 기간 안 잠든 시각의 규칙성. 수면 기록이 적으면 null.
  final BedtimeRegularity? bedtime;

  bool get isEmpty => recordedDays == 0 && checkInCount == 0;

  /// 전날과 잠든 시각이 이만큼 넘게 다르면 "크게 오르내렸다"고 본다.
  static const Duration bedtimeSwing = Duration(minutes: 90);

  /// [date]와 전날 모두 수면이 있고, 잠든 시각이 [bedtimeSwing] 넘게 달랐다.
  /// 전날 기록이 없으면 비교할 수 없으므로 아니다.
  static bool _swungFromPreviousDay(
    Map<DiaryDate, DiaryEntry> byDate,
    DiaryDate date,
  ) {
    final today = byDate[date]?.sleep?.bedTime;
    final yesterday = byDate[date.previous]?.sleep?.bedTime;
    if (today == null || yesterday == null) {
      return false;
    }
    final difference =
        (BedtimeRegularity.nightMinutes(today) -
                BedtimeRegularity.nightMinutes(yesterday))
            .abs();
    return difference > bedtimeSwing.inMinutes;
  }

  /// 새벽 1시~6시 사이에 잠들었다. 그 전날 밤 23시 취침과 구분한다.
  static bool _isLateBedtime(DiaryEntry? entry) {
    final bed = entry?.sleep?.bedTime;
    return bed != null && bed.hour >= 1 && bed.hour < 6;
  }
}
