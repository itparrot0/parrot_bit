import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/domain/domain.dart';

void main() {
  const today = DiaryDate(2026, 11, 5);

  SafetyAdvice decide(
    SafetyAdvice advice, {
    int? restDaysAgo,
    int? supportDaysAgo,
  }) => SafetyNoticePolicy.decide(
    advice: advice,
    today: today,
    lastRestShown: restDaysAgo == null ? null : today.addDays(-restDaysAgo),
    lastSupportShown: supportDaysAgo == null
        ? null
        : today.addDays(-supportDaysAgo),
  );

  test('띄운 적이 없으면 판정 그대로 띄운다', () {
    expect(decide(SafetyAdvice.none), SafetyAdvice.none);
    expect(decide(SafetyAdvice.restSuggestion), SafetyAdvice.restSuggestion);
    expect(decide(SafetyAdvice.supportContact), SafetyAdvice.supportContact);
  });

  test('같은 단계는 14일 동안 다시 띄우지 않는다', () {
    expect(
      decide(SafetyAdvice.restSuggestion, restDaysAgo: 13),
      SafetyAdvice.none,
    );
    expect(
      decide(SafetyAdvice.restSuggestion, restDaysAgo: 14),
      SafetyAdvice.restSuggestion,
    );
    expect(
      decide(SafetyAdvice.supportContact, supportDaysAgo: 13),
      SafetyAdvice.none,
    );
    expect(
      decide(SafetyAdvice.supportContact, supportDaysAgo: 14),
      SafetyAdvice.supportContact,
    );
  });

  test('2단계를 띄운 뒤 14일 동안은 1단계도 띄우지 않는다', () {
    expect(
      decide(SafetyAdvice.restSuggestion, supportDaysAgo: 3),
      SafetyAdvice.none,
    );
  });

  test('1단계를 띄운 뒤라도 2단계는 띄운다 — 더 무거워진 신호를 가리지 않는다', () {
    expect(
      decide(SafetyAdvice.supportContact, restDaysAgo: 2),
      SafetyAdvice.supportContact,
    );
  });

  test('시계가 되돌아가 마지막 노출이 미래여도 쉬는 중으로 본다', () {
    expect(
      decide(SafetyAdvice.restSuggestion, restDaysAgo: -3),
      SafetyAdvice.none,
    );
  });

  test('감각 안내는 수면 기반 2단계와 쉬는 기간을 함께 쓴다', () {
    expect(decide(SafetyAdvice.senseSupport), SafetyAdvice.senseSupport);
    expect(
      decide(SafetyAdvice.senseSupport, supportDaysAgo: 5),
      SafetyAdvice.none,
    );
    expect(
      decide(SafetyAdvice.senseSupport, restDaysAgo: 2),
      SafetyAdvice.senseSupport,
    );
  });
}
