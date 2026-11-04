// Flutter 전환(2026-11-04) 검증: Dart 엔진·솔버·생성기가 TS 버전과 같은 결과를 내는가.
// test/fixtures/ts_reference.json 은 전환 직전 TS 코드(packages/core)로 만든 기준값이다.
import 'dart:convert';
import 'dart:io';

import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/domain/generator.dart';
import 'package:bloom_wave/domain/solver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sample_arts.dart';

String enc(List<Action> as) => as.map((a) => a.toString()).join(' ');

void main() {
  final ref =
      jsonDecode(File('test/fixtures/ts_reference.json').readAsStringSync())
          as Map<String, dynamic>;
  final pack = [
    for (final j
        in jsonDecode(File('assets/levels/pack-01.json').readAsStringSync())
            as List)
      Level.fromJson(j as Map<String, dynamic>),
  ];

  test('mulberry32 수열이 같다', () {
    final rng = mulberry32(12345);
    final got = List.generate(20, (_) => rng());
    expect(got, (ref['rngSeq'] as List).cast<num>());
  });

  test('출시 팩 120 레벨: 솔버 결과(해법·노드 수)가 TS 와 같다', () {
    final solves = ref['solves'] as List;
    expect(pack.length, solves.length);
    for (var i = 0; i < pack.length; i++) {
      final want = solves[i] as Map<String, dynamic>;
      final r = solve(pack[i], pack[i].options);
      expect(pack[i].id, want['id']);
      expect(r.solvable, want['solvable'], reason: pack[i].id);
      expect(r.nodes, want['nodes'], reason: pack[i].id);
      expect(enc(r.solution), want['solution'], reason: pack[i].id);
    }
  });

  test('무작위 클리어율·플레이아웃이 TS 와 같다', () {
    for (final w in (ref['wins'] as List).cast<Map<String, dynamic>>()) {
      final l = pack.firstWhere((l) => l.id == w['id']);
      expect(randomWinRate(l, l.options, 50, mulberry32(7)), w['win']);
    }
    final plays = (ref['play'] as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < plays.length; i++) {
      final p = playout(pack[i], pack[i].options, mulberry32(99));
      expect(p.cleared, plays[i]['cleared']);
      expect(p.peakSlots, plays[i]['peakSlots']);
      expect(p.ticks, plays[i]['ticks']);
    }
  });

  test('생성기: 같은 그림·시드에서 TS 와 같은 레벨과 지표', () {
    for (final g in (ref['gens'] as List).cast<Map<String, dynamic>>()) {
      final art = sampleArts.firstWhere((a) => a.name == g['art']);
      final r = generate(
        art,
        GenParams(
          seed: g['seed'] as int,
          starts: 1,
          dropMin: 1,
          dropMax: 4,
          displacements: 40,
          lanes: g['lanes'] as int,
          trials: 80,
        ),
      );
      final want = g['report'] as Map<String, dynamic>;
      final tag = '${g['art']} seed=${g['seed']} lanes=${g['lanes']}';
      expect(
        jsonEncode(r.level.toJson()),
        jsonEncode(want['level']),
        reason: tag,
      );
      expect(r.score, want['score'], reason: tag);
      expect(r.randomWinRate, want['randomWinRate'], reason: tag);
      expect(r.avgSlots, want['avgSlots'], reason: tag);
      expect(r.peakSlots, want['peakSlots'], reason: tag);
      expect(r.solverNodes, want['solverNodes'], reason: tag);
      expect(r.displacementsApplied, want['displacementsApplied'], reason: tag);
      expect(r.difficulty.name, want['difficulty'], reason: tag);
    }
  });

  test('팩 JSON 왕복: 읽고 다시 쓰면 같은 값', () {
    final raw =
        jsonDecode(File('assets/levels/pack-01.json').readAsStringSync())
            as List;
    for (var i = 0; i < raw.length; i++) {
      expect(jsonEncode(pack[i].toJson()), jsonEncode(raw[i]));
    }
  });
}
