import 'package:deep_grove/domain/board_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/sim/sim.dart';

/// 경제 시뮬레이터로 지금 테마 수치가 "끝까지 갈 수 있다"를 고정한다.
/// 속도(몇 분·몇 시간)는 조절 대상이라 고정하지 않는다 — tool/economy_sim.dart 로 본다.
void main() {
  test('계속 플레이: 자동 플레이어가 막히지 않고 테마를 완주한다', () {
    for (var seed = 1; seed <= 3; seed++) {
      final r = Simulator(theme: forestCaveTheme, seed: seed).run();
      expect(r.stuck, isFalse, reason: 'seed $seed');
      expect(r.cleared, isNotNull, reason: 'seed $seed');
      expect(r.expansions, 30);
      // 동굴 진입 전에는 목재만 드는 칸이 있어 동굴 진입 전에 막히지 않는다.
      expect(r.caveEntered, lessThan(r.allOpen!));
    }
  });

  test('세션 플레이(5분 / 60분 쉼)도 완주한다', () {
    final r = Simulator(
      theme: forestCaveTheme,
      seed: 1,
      pattern: const PlayPattern.sessions(sessionMinutes: 5, awayMinutes: 60),
    ).run();
    expect(r.stuck, isFalse);
    expect(r.cleared, isNotNull);
  });
}
