import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/phone_dialer.dart';
import 'package:sleep_log/data/providers.dart';
import 'package:sleep_log/domain/domain.dart';
import 'package:sleep_log/screens/calendar_screen.dart';

import '../support/fake_phone_dialer.dart';

void main() {
  const today = DiaryDate(2026, 11, 5);
  final target = SleepTarget(const Duration(hours: 7));
  final overnight = SleepSession(
    bedTime: ClockTime(23, 0),
    wakeTime: ClockTime(6, 0),
  );

  group('CalendarView.from', () {
    test('수면이 있으면 z 표시, 태그만 있으면 null 값으로 키가 있다', () {
      final view = CalendarView.from(
        entries: [
          DiaryEntry(date: today.previous, sleep: overnight),
          DiaryEntry(date: today, tags: {DefaultMoodTags.calm}),
        ],
        target: target,
        today: today,
      );

      expect(view.records, {today.previous: SleepMark.enough, today: null});
      expect(view.hasTodayEntry, isTrue);
    });

    test('목표가 바뀌면 같은 수면도 다르게 판정된다', () {
      final entries = [DiaryEntry(date: today, sleep: overnight)];

      final view = CalendarView.from(
        entries: entries,
        target: SleepTarget(const Duration(hours: 9)),
        today: today,
      );

      expect(view.records[today], SleepMark.short);
    });

    test('오늘 기록이 없으면 hasTodayEntry는 false', () {
      final view = CalendarView.from(
        entries: [DiaryEntry(date: today.previous, sleep: overnight)],
        target: target,
        today: today,
      );

      expect(view.hasTodayEntry, isFalse);
    });
  });

  group('CalendarView.monthsBackFor', () {
    test('기록이 없어도 지난달까지는 갈 수 있다', () {
      expect(CalendarView.monthsBackFor(earliest: null, today: today), 1);
    });

    test('이번 달 기록만 있어도 최소 1', () {
      expect(
        CalendarView.monthsBackFor(
          earliest: const DiaryDate(2026, 11, 1),
          today: today,
        ),
        1,
      );
    });

    test('가장 오래된 기록의 달까지 — 연도를 넘어서도', () {
      expect(
        CalendarView.monthsBackFor(
          earliest: const DiaryDate(2025, 9, 30),
          today: today,
        ),
        14,
      );
    });

    test('기록이 오늘보다 미래여도(시계 되돌림) 최소값', () {
      expect(
        CalendarView.monthsBackFor(
          earliest: const DiaryDate(2027, 1, 1),
          today: today,
        ),
        1,
      );
    });
  });

  group('CalendarScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required Stream<List<DiaryEntry>> entries,
      SafetyAdvice banner = SafetyAdvice.none,
      bool checkInEnabled = false,
      List<ThoughtCheckIn> checkIns = const [],
      PhoneDialer? dialer,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayProvider.overrideWithValue(today),
            diaryEntriesProvider.overrideWith((ref) => entries),
            sleepTargetProvider.overrideWithValue(target),
            safetyBannerProvider.overrideWith(() => _FixedBanner(banner)),
            checkInSettingsProvider.overrideWith(
              () => _FixedCheckInSettings(
                CheckInSettings(enabled: checkInEnabled),
              ),
            ),
            checkInsProvider.overrideWith((ref) => Stream.value(checkIns)),
            clockProvider.overrideWithValue(() => DateTime(2026, 11, 5, 9)),
            phoneDialerProvider.overrideWithValue(dialer ?? FakePhoneDialer()),
          ],
          child: const MaterialApp(home: CalendarScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('오늘 기록이 없으면 "오늘 기록" 버튼이 보인다', (tester) async {
      await pumpScreen(tester, entries: Stream.value(const []));

      expect(find.text('오늘 기록'), findsOneWidget);
    });

    testWidgets('오늘 기록이 있으면 버튼을 숨긴다', (tester) async {
      await pumpScreen(
        tester,
        entries: Stream.value([DiaryEntry(date: today, sleep: overnight)]),
      );

      expect(find.text('오늘 기록'), findsNothing);
    });

    testWidgets('기록을 읽기 전에는 버튼을 띄우지 않는다', (tester) async {
      await pumpScreen(tester, entries: const Stream.empty());

      expect(find.text('오늘 기록'), findsNothing);
    });

    testWidgets('저장된 수면이 달력에 z 표시로 그려진다', (tester) async {
      await pumpScreen(
        tester,
        entries: Stream.value([
          DiaryEntry(date: today.previous, sleep: overnight),
        ]),
      );

      expect(find.text(SleepMark.enough.label), findsOneWidget);
    });

    testWidgets('앱바에 리포트·설정 버튼이 있다', (tester) async {
      await pumpScreen(tester, entries: Stream.value(const []));

      expect(find.byTooltip('리포트'), findsOneWidget);
      expect(find.byTooltip('설정'), findsOneWidget);
    });

    testWidgets('띄울 안내가 없으면 배너가 없다', (tester) async {
      await pumpScreen(tester, entries: Stream.value(const []));

      expect(find.byKey(const Key('safetyBanner')), findsNothing);
    });

    testWidgets('1단계는 수면을 권하고 연락처는 보이지 않는다', (tester) async {
      await pumpScreen(
        tester,
        entries: Stream.value(const []),
        banner: SafetyAdvice.restSuggestion,
      );

      expect(find.byKey(const Key('safetyBanner')), findsOneWidget);
      expect(find.textContaining('일찍 잠자리에'), findsOneWidget);
      expect(find.text('109'), findsNothing);
    });

    testWidgets('2단계는 상담 연락처를 보여 준다', (tester) async {
      await pumpScreen(
        tester,
        entries: Stream.value(const []),
        banner: SafetyAdvice.supportContact,
      );

      expect(find.text('혹시 도움이 필요하다면'), findsOneWidget);
      expect(find.textContaining('109'), findsOneWidget);
      expect(find.textContaining('1577-0199'), findsOneWidget);
    });

    testWidgets('감각 안내는 그 이유에 맞는 문구와 연락처를 보여 준다', (tester) async {
      await pumpScreen(
        tester,
        entries: Stream.value(const []),
        banner: SafetyAdvice.senseSupport,
      );

      expect(find.textContaining('평소와 다르게 다가온 순간'), findsOneWidget);
      expect(find.textContaining('109'), findsOneWidget);
    });

    testWidgets('상담 번호를 누르면 전화 앱을 그 번호로 연다', (tester) async {
      final dialer = FakePhoneDialer();
      await pumpScreen(
        tester,
        entries: Stream.value(const []),
        banner: SafetyAdvice.supportContact,
        dialer: dialer,
      );

      await tester.tap(find.byKey(const Key('call.109')));
      await tester.tap(find.byKey(const Key('call.1577-0199')));
      await tester.pump();

      expect(dialer.dialed, ['109', '1577-0199']);
    });

    testWidgets('전화가 안 되는 기기면 번호를 안내한다', (tester) async {
      await pumpScreen(
        tester,
        entries: Stream.value(const []),
        banner: SafetyAdvice.supportContact,
        dialer: FakePhoneDialer(canDial: false),
      );

      await tester.tap(find.byKey(const Key('call.109')));
      await tester.pump();

      expect(find.textContaining('다른 전화로 109'), findsOneWidget);
    });

    testWidgets('닫으면 사라지고 달력은 그대로다', (tester) async {
      await pumpScreen(
        tester,
        entries: Stream.value(const []),
        banner: SafetyAdvice.supportContact,
      );

      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('safetyBanner')), findsNothing);
      expect(find.text('오늘 기록'), findsOneWidget);
    });

    testWidgets('생각 돌아보기를 켜지 않았으면 버튼이 없다', (tester) async {
      await pumpScreen(tester, entries: Stream.value(const []));

      expect(find.textContaining('생각 돌아보기'), findsNothing);
    });

    testWidgets('켰으면 지금 시간대(오전) 버튼이 보인다', (tester) async {
      await pumpScreen(
        tester,
        entries: Stream.value(const []),
        checkInEnabled: true,
      );

      expect(find.text('오전의 생각 돌아보기'), findsOneWidget);
    });

    testWidgets('이미 남긴 시간대면 남겼다고 표시한다', (tester) async {
      await pumpScreen(
        tester,
        entries: Stream.value(const []),
        checkInEnabled: true,
        checkIns: [
          ThoughtCheckIn(
            date: today,
            slot: CheckInSlot.morning,
            pace: MindPace.usual,
          ),
        ],
      );

      expect(find.text('오전의 생각 돌아보기 · 남겼어요'), findsOneWidget);
    });
  });
}

/// 저장소를 거치지 않고 정해진 안내를 내놓는 배너.
class _FixedBanner extends SafetyBanner {
  _FixedBanner(this.advice);

  final SafetyAdvice advice;

  @override
  Future<SafetyAdvice> build() async => advice;
}

class _FixedCheckInSettings extends CheckInSettingsNotifier {
  _FixedCheckInSettings(this.settings);

  final CheckInSettings settings;

  @override
  Future<CheckInSettings> build() async => settings;
}
