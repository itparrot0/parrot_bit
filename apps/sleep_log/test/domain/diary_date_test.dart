import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/domain/domain.dart';

void main() {
  group('DiaryDate', () {
    test('같은 날짜는 같은 값이고 Map 키로 쓸 수 있다', () {
      const a = DiaryDate(2026, 9, 27);
      const b = DiaryDate(2026, 9, 27);

      expect(a, b);
      expect({a: 1}[b], 1);
    });

    test('시각이 있는 DateTime에서 날짜만 가져온다', () {
      final date = DiaryDate.fromDateTime(DateTime(2026, 9, 27, 23, 45));

      expect(date, const DiaryDate(2026, 9, 27));
    });

    test('addDays는 달과 해를 넘어간다', () {
      expect(
        const DiaryDate(2026, 9, 30).addDays(1),
        const DiaryDate(2026, 10, 1),
      );
      expect(
        const DiaryDate(2026, 1, 1).addDays(-1),
        const DiaryDate(2025, 12, 31),
      );
      expect(
        const DiaryDate(2026, 3, 1).addDays(-1),
        const DiaryDate(2026, 2, 28),
      );
    });

    test('윤년 2월을 정확히 넘는다', () {
      expect(
        const DiaryDate(2028, 2, 28).addDays(1),
        const DiaryDate(2028, 2, 29),
      );
      expect(
        const DiaryDate(2028, 3, 1).addDays(-1),
        const DiaryDate(2028, 2, 29),
      );
    });

    test('13일 전으로 이동해도 날짜가 밀리지 않는다', () {
      // 2주 창(window) 계산이 서머타임 전환일에도 정확해야 한다.
      final from = const DiaryDate(2026, 9, 27).addDays(-13);

      expect(from, const DiaryDate(2026, 9, 14));
    });

    test('ISO 문자열로 왕복한다', () {
      const date = DiaryDate(2026, 1, 5);

      expect(date.toIso(), '2026-01-05');
      expect(DiaryDate.tryParseIso('2026-01-05'), date);
    });

    test('형식이 틀리거나 없는 날짜는 파싱하지 않는다', () {
      expect(DiaryDate.tryParseIso('2026-1-5'), isNull);
      expect(DiaryDate.tryParseIso('26-01-05'), isNull);
      expect(DiaryDate.tryParseIso('오늘'), isNull);
      expect(DiaryDate.tryParseIso(''), isNull);
      // DateTime이 3월 2일로 넘겨버리는 값을 그대로 받아들이지 않는다.
      expect(DiaryDate.tryParseIso('2026-02-30'), isNull);
      expect(DiaryDate.tryParseIso('2026-13-01'), isNull);
    });

    test('날짜 순으로 비교·정렬된다', () {
      final dates = [
        const DiaryDate(2026, 9, 27),
        const DiaryDate(2025, 12, 31),
        const DiaryDate(2026, 1, 1),
      ]..sort();

      expect(dates, const [
        DiaryDate(2025, 12, 31),
        DiaryDate(2026, 1, 1),
        DiaryDate(2026, 9, 27),
      ]);
      expect(
        const DiaryDate(2026, 1, 1).isBefore(const DiaryDate(2026, 9, 27)),
        isTrue,
      );
      expect(
        const DiaryDate(2026, 9, 27).isAfter(const DiaryDate(2026, 1, 1)),
        isTrue,
      );
    });
  });
}
