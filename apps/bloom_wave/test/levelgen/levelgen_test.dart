// 레벨 생성기(tool/levelgen) 테스트. flutter test test/levelgen
import 'dart:convert';
import 'dart:io';

import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/domain/generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/levelgen/src/build.dart';
import '../../tool/levelgen/src/config.dart';
import '../../tool/levelgen/src/generate_one.dart';
import '../../tool/levelgen/src/js_json.dart';
import '../../tool/levelgen/src/png.dart';
import '../../tool/levelgen/src/verify.dart';

const _dir = 'tool/levelgen';

void main() {
  final config = PackConfig.fromJson(
    jsonDecode(File('$_dir/levels.config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final names =
      jsonDecode(File('$_dir/art/names.json').readAsStringSync())
          as Map<String, dynamic>;
  Job job(int i, {bool realNames = false}) {
    final art = config.levels[i].art;
    final n = names[art] as Map<String, dynamic>;
    return Job(
      index: i,
      spec: config.levels[i],
      defaults: config.defaults,
      artPath: '$_dir/art/$art.png',
      names: realNames
          ? LevelName(n['ko'] as String, n['en'] as String)
          : const LevelName('x', 'x'),
    );
  }

  final packText = File('$_dir/out/pack-01.json').readAsStringSync();

  test('PNG 왕복: 텍스트 아트 → PNG → 같은 칸 배열', () {
    const art = PixelArt(
      't',
      ['r=#E5484D', 'g=#46A758'],
      ['r.g', 'rrg', '.g.'],
    );
    final (art: back, :warnings) = decodePng(encodeArt(art), 't');
    expect(back.rows, ['a.b', 'aab', '.b.']);
    expect(back.palette, ['a=#E5484D', 'b=#46A758']);
    expect(warnings, isEmpty); // 두 색 모두 3칸 → 경고 없음
    final small = decodePng(
      encodeArt(PixelArt('t', art.palette, ['r.g', 'rgg', '.g.'])),
      't',
    ).warnings;
    expect(small.any((w) => w.contains('칸뿐')), isTrue); // r 2칸 → 경고
  });

  test('색이 maxColors 보다 많으면 가장 가까운 색끼리 병합', () {
    const art = PixelArt(
      'm',
      ['a=#FF0000', 'b=#FE0101', 'c=#0000FF'],
      ['aaab', 'cccc'],
    );
    final (art: back, :warnings) = decodePng(encodeArt(art), 'm', 2);
    expect(back.palette.length, 2);
    expect(back.rows, ['aaaa', 'bbbb']);
    expect(warnings.any((w) => w.contains('병합')), isTrue);
  });

  test('JS 와 같은 숫자 표기 (정수 값 double 은 소수점 없이)', () {
    expect(jsNum(1.0), '1');
    expect(jsNum(0.0), '0');
    expect(jsNum(1.43), '1.43');
    expect(jsNum(7), '7');
    expect(
      jsStringify({
        'a': 1.0,
        'b': [0.5, 2.0],
        'c': '이슬',
      }),
      '{"a":1,"b":[0.5,2],"c":"이슬"}',
    );
  });

  test('같은 설정·시드면 결과가 바이트 단위로 같다 (결정성)', () {
    for (final i in [0, 3, 6]) {
      final a = serializePack([runJob(job(i)).level]);
      final b = serializePack([runJob(job(i)).level]);
      expect(a, b);
    }
  });

  test('튜토리얼 1~5: 커밋된 팩의 줄과 바이트 단위로 같다 (TS 생성기와 같은 결과)', () {
    final lines = const LineSplitter().convert(packText);
    for (var i = 0; i < 5; i++) {
      final line = serializePack([
        runJob(job(i, realNames: true)).level,
      ]).split('\n')[1];
      final want = lines[i + 1];
      expect(
        line,
        want.endsWith(',') ? want.substring(0, want.length - 1) : want,
      );
    }
  });

  test('생성 레벨은 verify 를 통과한다', () {
    for (final i in [1, 4, 8]) {
      expect(checkLevel(runJob(job(i)).level), isEmpty);
    }
  });

  test('verify 는 총량 불일치·시작점 없는 덩어리를 잡는다', () {
    final lv = runJob(job(0)).level;
    expect(
      checkLevel(
        lv.copyWith(lanes: [lv.lanes[0].sublist(1), ...lv.lanes.sublist(1)]),
      ).any((e) => e.contains('drop total')),
      isTrue,
    );
    expect(
      checkLevel(lv.copyWith(starts: [])).any((e) => e.contains('no start')),
      isTrue,
    );
  });

  test('verify 는 대기열이 3줄 미만이면 잡는다', () {
    final lv = runJob(job(0)).level;
    expect(
      checkLevel(
        lv.copyWith(lanes: [lv.lanes.expand((l) => l).toList()]),
      ).any((e) => e.contains('lanes')),
      isTrue,
    );
  });

  test('arrange: 튜토리얼은 설정 순서, 역할 레벨은 제자리, 나머지는 score 오름차순', () {
    final cfg = PackConfig(
      pack: 't',
      defaults: config.defaults,
      levels: [config.levels[0], ...config.levels.sublist(5, 30)],
    );
    final base = runJob(job(0)).report;
    JobResult fake(int index, int score) => JobResult(
      index: index,
      level: base.level,
      report: GenReport(
        level: base.level,
        colors: 1,
        cells: 1,
        drops: 1,
        displacementsApplied: 0,
        peakSlots: 0,
        avgSlots: 0,
        randomWinRate: 1,
        solverNodes: 0,
        score: score,
        difficulty: Difficulty.normal,
      ),
      seed: 1,
      tried: const [],
      warnings: const [],
    );
    // 점수: index 가 클수록 낮게, 단 1·2 는 가장 낮은 같은 점수 (index 로 순서 고정)
    final results = [
      for (var i = cfg.levels.length - 1; i >= 0; i--)
        fake(i, i == 1 || i == 2 ? 50 : 100 - i),
    ];
    final out = arrange(cfg, results).map((r) => r.index).toList();
    expect(out.first, 0);
    expect(out.last, 25); // 입문 보스는 마지막 그대로
    final regular = out.sublist(1, 25);
    expect(regular.sublist(0, 3), [1, 2, 24]); // 같은 점수는 index 순, 그다음 낮은 점수
  });

  test('출시 팩: 120 레벨, 모두 3줄 이상, 튜토리얼 1~2는 realtime false', () {
    final pack = jsonDecode(packText) as List;
    Map<String, dynamic>? opt(int i) =>
        (pack[i] as Map<String, dynamic>)['options'] as Map<String, dynamic>?;
    expect(pack.length, 120);
    expect(opt(0)?['realtime'], false);
    expect(opt(1)?['realtime'], false);
    expect(opt(2)?['realtime'], isNull);
    expect(
      pack.every((l) => ((l as Map)['lanes'] as List).length >= 3),
      isTrue,
    );
    expect(pack.map((l) => (l as Map)['id']).toSet().length, 120);
  });
}
