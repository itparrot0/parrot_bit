import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/domain/domain.dart';

void main() {
  group('ClockTime', () {
    test('범위를 벗어난 시·분은 거부한다', () {
      expect(() => ClockTime(24, 0), throwsArgumentError);
      expect(() => ClockTime(-1, 0), throwsArgumentError);
      expect(() => ClockTime(0, 60), throwsArgumentError);
      expect(() => ClockTime(0, -1), throwsArgumentError);
    });

    test('두 자리로 표기한다', () {
      expect(ClockTime(7, 5).toString(), '07:05');
      expect(ClockTime(23, 30).toString(), '23:30');
    });
  });

  group('SleepSession 자정 넘김', () {
    test('자정을 넘긴 수면을 사용자에게 묻지 않고 계산한다', () {
      final session = SleepSession(
        bedTime: ClockTime(23, 30),
        wakeTime: ClockTime(7, 0),
      );

      expect(session.duration, const Duration(hours: 7, minutes: 30));
      expect(session.startedPreviousDay, isTrue);
    });

    test('자정 이후 취침도 같은 규칙으로 잡힌다', () {
      final session = SleepSession(
        bedTime: ClockTime(1, 30),
        wakeTime: ClockTime(9, 0),
      );

      expect(session.duration, const Duration(hours: 7, minutes: 30));
      expect(session.startedPreviousDay, isFalse);
    });

    test('14시간 같은 긴 수면도 그대로 받는다', () {
      // 과다 수면은 봐야 할 신호이므로 상한으로 잘라내지 않는다.
      final session = SleepSession(
        bedTime: ClockTime(20, 0),
        wakeTime: ClockTime(10, 0),
      );

      expect(session.duration, const Duration(hours: 14));
    });

    test('취침과 기상이 같으면 거부한다', () {
      // 0시간인지 24시간인지 정할 수 없다.
      expect(
        () =>
            SleepSession(bedTime: ClockTime(23, 0), wakeTime: ClockTime(23, 0)),
        throwsArgumentError,
      );
      expect(
        SleepSession.isValidRange(ClockTime(23, 0), ClockTime(23, 0)),
        isFalse,
      );
      expect(
        SleepSession.isValidRange(ClockTime(23, 0), ClockTime(7, 0)),
        isTrue,
      );
    });
  });

  group('SleepTarget', () {
    test('허용 범위를 벗어난 목표는 거부한다', () {
      expect(() => SleepTarget(const Duration(hours: 3)), throwsArgumentError);
      expect(() => SleepTarget(const Duration(hours: 13)), throwsArgumentError);
      expect(() => SleepTarget(Duration.zero), throwsArgumentError);
    });

    test('기본 목표는 7시간이다', () {
      expect(SleepTarget.defaultTarget.duration, const Duration(hours: 7));
    });
  });

  group('SleepMark 판정 (목표 7시간)', () {
    final target = SleepTarget(const Duration(hours: 7));

    test('5.5시간 미만은 z', () {
      expect(target.markFor(const Duration(hours: 4)), SleepMark.short);
      expect(
        target.markFor(const Duration(hours: 5, minutes: 29)),
        SleepMark.short,
      );
    });

    test('5.5~6.5시간은 zZ', () {
      expect(
        target.markFor(const Duration(hours: 5, minutes: 30)),
        SleepMark.fair,
      );
      expect(
        target.markFor(const Duration(hours: 6, minutes: 29)),
        SleepMark.fair,
      );
    });

    test('6.5~8.5시간은 zzZ', () {
      expect(
        target.markFor(const Duration(hours: 6, minutes: 30)),
        SleepMark.enough,
      );
      expect(target.markFor(const Duration(hours: 7)), SleepMark.enough);
      expect(
        target.markFor(const Duration(hours: 8, minutes: 30)),
        SleepMark.enough,
      );
    });

    test('8.5시간 초과는 zzZZ', () {
      expect(
        target.markFor(const Duration(hours: 8, minutes: 31)),
        SleepMark.over,
      );
      expect(target.markFor(const Duration(hours: 11)), SleepMark.over);
    });

    test('목표가 다르면 같은 수면시간도 다르게 판정된다', () {
      // 이 앱의 존재 이유 — 남의 기준이 아니라 자기 기준으로 본다.
      final shortSleeper = SleepTarget(const Duration(hours: 5));
      final longSleeper = SleepTarget(const Duration(hours: 9));
      const slept = Duration(hours: 6);

      expect(shortSleeper.markFor(slept), SleepMark.enough);
      expect(longSleeper.markFor(slept), SleepMark.short);
    });

    test('표시 문자열은 길이가 곧 수면량이다', () {
      expect(SleepMark.short.label, 'z');
      expect(SleepMark.fair.label, 'zZ');
      expect(SleepMark.enough.label, 'zzZ');
      expect(SleepMark.over.label, 'zzZZ');
    });

    test('부족한 쪽과 목표를 채운 쪽이 갈린다', () {
      expect(SleepMark.short.isShortOfTarget, isTrue);
      expect(SleepMark.fair.isShortOfTarget, isTrue);
      expect(SleepMark.enough.isShortOfTarget, isFalse);
      expect(SleepMark.over.isShortOfTarget, isFalse);

      expect(SleepMark.enough.meetsTarget, isTrue);
      expect(SleepMark.over.meetsTarget, isTrue);
      expect(SleepMark.short.meetsTarget, isFalse);
      expect(SleepMark.fair.meetsTarget, isFalse);
    });
  });
}
