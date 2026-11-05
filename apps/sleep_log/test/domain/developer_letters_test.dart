import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/domain/domain.dart';

void main() {
  test('편지는 100문장이고 겹치지 않는다', () {
    expect(DeveloperLetters.all, hasLength(100));
    expect(DeveloperLetters.all.toSet(), hasLength(100));
  });

  test('진단·평가로 읽힐 말을 쓰지 않는다 (PRD §9-2)', () {
    const banned = ['우울증', '진단', '치료', '증상', '병원', '정상', '실패', '문제가 있'];
    for (final letter in DeveloperLetters.all) {
      for (final word in banned) {
        expect(letter.contains(word), isFalse, reason: '"$word" in: $letter');
      }
    }
  });

  test('무작위로 하나를 고른다 — 같은 시드면 같은 문장', () {
    final a = DeveloperLetters.pick(Random(7));
    final b = DeveloperLetters.pick(Random(7));
    expect(a, b);
    expect(DeveloperLetters.all, contains(a));
  });
}
