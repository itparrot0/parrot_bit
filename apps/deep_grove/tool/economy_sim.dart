// 경제 시뮬레이션 CLI — 수치 후보를 나란히 비교한다.
// CLI 라서 출력에 print 를 쓴다.
// ignore_for_file: avoid_print
//
//   dart run tool/economy_sim.dart            # 후보마다 20판
//   dart run tool/economy_sim.dart --runs 50
//
// 결과 해석과 결론은 docs/design/deep_grove-economy-sim.md.
// 후보를 바꾸려면 아래 variants 목록을 고친다 (scaledCosts·Energy 는 tool/sim/sim.dart).
import 'package:deep_grove/domain/board_model.dart';

import 'sim/sim.dart';

void main(List<String> args) {
  final runsAt = args.indexOf('--runs');
  final n = runsAt >= 0 ? int.parse(args[runsAt + 1]) : 20;
  final variants = <(String, GroveTheme, Energy?)>[
    ('현재 수치', forestCaveTheme, null),
    ('비용 ×5', scaledCosts(forestCaveTheme, 5), null),
    ('산출 120초', scaledCosts(forestCaveTheme, 1, secondsPerUnit: 120), null),
    (
      '산출 120초 + 비용 ×3',
      scaledCosts(forestCaveTheme, 3, secondsPerUnit: 120),
      null,
    ),
    ('에너지 30·30초', forestCaveTheme, const Energy(cap: 30, regenSeconds: 30)),
    (
      '에너지 30·30초 + 비용 ×2',
      scaledCosts(forestCaveTheme, 2),
      const Energy(cap: 30, regenSeconds: 30),
    ),
  ];
  const patterns = [
    PlayPattern.continuous(),
    PlayPattern.sessions(sessionMinutes: 5, awayMinutes: 60),
  ];
  for (final (name, theme, energy) in variants) {
    for (final p in patterns) {
      final rs = [
        for (var s = 1; s <= n; s++)
          Simulator(theme: theme, seed: s, pattern: p, energy: energy).run(),
      ];
      final m = SimSummary('', rs);
      print(
        '$name | $p | 첫 칸 ${m.stat((r) => r.firstCell)} | 동굴 ${m.stat((r) => r.caveEntered)} | 완주 ${m.stat((r) => r.cleared)} (${m.cleared}/$n) | 막힘 ${m.stuck}/$n | 기다림 ${m.waitingShare()} | 버림 아이템 ${(rs.fold<int>(0, (a, r) => a + r.discardedItems) / n).toStringAsFixed(1)} · 산출원 ${(rs.fold<int>(0, (a, r) => a + r.discardedProducers) / n).toStringAsFixed(1)}',
      );
    }
  }
}
