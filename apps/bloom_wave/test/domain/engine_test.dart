import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/domain/generator.dart';
import 'package:bloom_wave/domain/solver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sample_arts.dart';

Drop d(int c, int a) => Drop(c, a);

/// 1행 5칸: a a b a a, 시작 발아는 0번
Level line(
  List<List<Drop>> lanes, {
  int slotCount = 4,
  List<int> starts = const [0],
}) => Level(
  id: 't',
  width: 5,
  height: 1,
  palette: const ['#f00', '#00f'],
  cells: const [0, 0, 1, 0, 0],
  starts: starts,
  lanes: lanes,
  slotCount: slotCount,
);

void main() {
  test('줄마다 맨 앞을 탭할 수 있고, 웨이브 중에는 기다리기(틱)도 선택지', () {
    final lv = line([
      [d(0, 2), d(0, 2)],
      [d(1, 1)],
      [],
    ]);
    final s = createState(lv);
    expect(legalActions(s), [const Deploy(0), const Deploy(1)]); // 빈 줄은 제외
    applyAction(lv, s, const Deploy(0));
    expect(legalActions(s), [const Deploy(0), const Deploy(1), const Tick()]);
    expect(legalActions(s, turnBased), [const Tick()]);
  });

  test('쓸 수 있는지와 무관하게 슬롯으로 이동', () {
    final lv = line([
      [d(1, 1)],
      [d(0, 2), d(0, 2)],
    ]);
    final s = createState(lv);
    applyAction(lv, s, const Deploy(0));
    expect(s.slots, [d(1, 1), null, null, null]);
    expect(queueLength(s.lanes), 2);
    expect(s.status, Status.playing);
  });

  test('한 틱에 한 링씩: 같은 색 발아 칸 전체가 링, 개화는 8방향 씨앗을 색 무관 발아', () {
    final lv = line([
      [d(0, 2), d(1, 1), d(0, 2)],
    ]);
    final s = createState(lv);
    deploy(lv, s, 0);
    final t0 = tick(lv, s);
    expect(t0.blooms.single.slot, 0);
    expect(t0.blooms.single.cells, [0]);
    expect(t0.sprouted, [1]);
    expect(s.slots[0], d(0, 1));
    final t1 = tick(lv, s);
    expect(t1.blooms[0].cells, [1]);
    expect(s.cell[2], sprout);
    expect(s.cell[3], seed);
    expect(s.slots[0], isNull);
  });

  test('물방울은 발아 칸에만 소모되고, 퍼질 곳이 없으면 슬롯에 남는다', () {
    final lv = line([
      [d(0, 4)],
      [d(1, 1)],
    ]);
    final s = createState(lv);
    applyAction(lv, s, const Deploy(0), turnBased);
    expect(s.slots[0], d(0, 2));
    applyAction(lv, s, const Deploy(1), turnBased);
    expect(s.status, Status.cleared);
    expect(s.cell.every((c) => c == bloom), isTrue);
  });

  test('8방향 순서: 남동 > 남 > 남서 > 서 > 북서 > 북 > 북동 > 동', () {
    final lv = Level(
      id: 'o',
      width: 3,
      height: 3,
      palette: const ['#f00'],
      cells: List.filled(9, 0),
      starts: const [4],
      lanes: [
        [d(0, 1), d(0, 8)],
      ],
    );
    final s = createState(lv);
    applyAction(lv, s, const Deploy(0), turnBased);
    final second = applyAction(lv, s, const Deploy(0), turnBased);
    expect(second[0].blooms[0].cells, [8, 7, 6, 3, 0, 1, 2, 5]);
  });

  test('안정 상태에서 슬롯 4칸이 모두 차면 실패', () {
    final lv = line([
      [d(1, 1), d(1, 1)],
      [d(1, 1), d(1, 1)],
      [d(0, 4)],
    ]);
    final s = createState(lv);
    for (final lane in [0, 0, 1]) {
      applyAction(lv, s, Deploy(lane), turnBased);
    }
    expect(s.status, Status.playing);
    applyAction(lv, s, const Deploy(1), turnBased);
    expect(s.status, Status.failed);
  });

  test('해상도 배율: 한 픽셀이 scale×scale 칸', () {
    const art = PixelArt('x', ['a=#f00', 'b=#00f'], ['a.', '.b']);
    final c = artToCells(scaleArt(art, 2));
    expect(c.width, 4);
    expect(c.height, 4);
    expect(c.cells, [0, 0, -1, -1, 0, 0, -1, -1, -1, -1, 1, 1, -1, -1, 1, 1]);
  });

  test('난이도 등급', () {
    expect(difficultyOf(0.8), Difficulty.normal);
    expect(difficultyOf(0.2), Difficulty.hard);
    expect(difficultyOf(0.1), Difficulty.superHard);
    expect(difficultyOf(0.05), Difficulty.megaHard);
  });

  for (final lanes in [1, 3, 4]) {
    test('생성기 (대기열 $lanes줄): 물방울 총량 = 칸 수, 솔버 해법 재생 시 클리어', () {
      for (final art in sampleArts) {
        for (var sd = 1; sd <= 2; sd++) {
          final r = generate(
            art,
            GenParams(
              seed: sd,
              starts: 1,
              dropMin: 1,
              dropMax: 4,
              displacements: 30,
              lanes: lanes,
              trials: 40,
            ),
          );
          expect(r.level.lanes.length, lanes);
          expect(r.level.lanes.every((l) => l.isNotEmpty), isTrue);
          expect(
            r.level.lanes.expand((l) => l).fold<int>(0, (a, x) => a + x.amount),
            r.cells,
          );
          final sol = solve(r.level);
          expect(sol.solvable, isTrue);
          expect(replay(r.level, sol.solution), isTrue);
        }
      }
    });
  }

  test('확대한 그림도 클리어 보장', () {
    final r = generate(
      sampleArts[0],
      const GenParams(
        seed: 1,
        starts: 1,
        dropMin: 2,
        dropMax: 5,
        displacements: 20,
        lanes: 3,
        scale: 2,
        trials: 30,
      ),
    );
    expect(r.level.width, 18);
    expect(r.cells, 31 * 4);
    final sol = solve(r.level);
    expect(sol.solvable, isTrue);
    expect(replay(r.level, sol.solution), isTrue);
  });

  test('solveFrom: 진행 중 상태에서도 해법을 찾는다', () {
    final r = generate(
      sampleArts[1],
      const GenParams(
        seed: 3,
        starts: 1,
        dropMin: 1,
        dropMax: 4,
        displacements: 30,
        lanes: 3,
        trials: 30,
      ),
    );
    final s = createState(r.level);
    applyAction(r.level, s, solve(r.level).solution[0]);
    expect(solveFrom(r.level, s).solvable, isTrue);
  });
}
