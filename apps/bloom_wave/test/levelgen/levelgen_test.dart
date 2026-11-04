// 레벨 생성기(tool/levelgen) 테스트. flutter test test/levelgen
import 'dart:convert';
import 'dart:io';

import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/domain/generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/levelgen/src/art_gen.dart';
import '../../tool/levelgen/src/art_source.dart';
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
    // 예전 120 스테이지 배치처럼: 튜토리얼 1 + 입문 25 (마지막은 보스)
    LevelSpec as(LevelSpec s, String band, [String? role]) =>
        LevelSpec.fromJson({...s.toJson(), 'band': band, 'role': ?role});
    final cfg = PackConfig(
      pack: 't',
      defaults: config.defaults,
      levels: [
        config.levels[0],
        for (var i = 0; i < 25; i++)
          as(config.levels[5 + i], 'intro', i == 24 ? 'boss' : null),
      ],
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

    // 1000 스테이지 팩의 stage 구간은 점수와 상관없이 설정 순서 그대로 (등급 배치가 설정에 있다)
    final stageCfg = PackConfig(
      pack: 't',
      defaults: config.defaults,
      levels: [
        for (var i = 0; i < 26; i++)
          as(config.levels[i], i == 0 ? 'tutorial' : 'stage'),
      ],
    );
    expect(arrange(stageCfg, results).map((r) => r.index).toList(), [
      for (var i = 0; i < 26; i++) i,
    ]);
  });

  test('출시 팩: 1000 스테이지, 모두 3줄 이상, 튜토리얼 1~2는 realtime false, id 중복 없음', () {
    final pack = jsonDecode(packText) as List;
    Map<String, dynamic>? opt(int i) =>
        (pack[i] as Map<String, dynamic>)['options'] as Map<String, dynamic>?;
    expect(pack.length, 1000);
    expect(opt(0)?['realtime'], false);
    expect(opt(1)?['realtime'], false);
    expect(opt(2)?['realtime'], isNull);
    expect(
      pack.every((l) => ((l as Map)['lanes'] as List).length >= 3),
      isTrue,
    );
    expect(pack.map((l) => (l as Map)['id']).toSet().length, 1000);
  });

  test('출시 팩 난이도 배치: 6스테이지부터 2~4스테이지마다 어려움(Hard·Super·Mega), 사이는 노말', () {
    final pack = jsonDecode(packText) as List;
    final diff = [
      for (final l in pack) ((l as Map)['meta'] as Map)['difficulty'] as String,
    ];
    expect(diff.take(5).every((d) => d == 'normal'), isTrue); // 튜토리얼
    final hard = [
      for (var i = 5; i < diff.length; i++)
        if (diff[i] != 'normal') i + 1,
    ];
    expect(hard.first - 5, inInclusiveRange(2, 4));
    for (var k = 1; k < hard.length; k++) {
      expect(
        hard[k] - hard[k - 1],
        inInclusiveRange(2, 4),
        reason: '${hard[k - 1]} → ${hard[k]}',
      );
    }
    expect(1000 - hard.last, lessThanOrEqualTo(3));
    // 입문(~30)은 Hard 만, 그 뒤로 세 등급이 모두 나온다
    expect(
      hard.where((n) => n <= 30).every((n) => diff[n - 1] == 'hard'),
      isTrue,
    );
    final later = {for (final n in hard.where((n) => n > 30)) diff[n - 1]};
    expect(later, {'hard', 'superHard', 'megaHard'});
    // 설정과 같은 등급이 나왔다
    final cfg =
        jsonDecode(File('$_dir/levels.config.json').readAsStringSync()) as Map;
    final want = [
      for (final l in cfg['levels'] as List)
        ((l as Map)['difficulty'] as String?) ?? 'normal',
    ];
    expect(diff, want);
  });

  test('같은 그림의 n 번째 레벨은 로마 숫자', () {
    expect(
      [
        for (final n in [2, 3, 4, 9, 12, 14]) roman(n),
      ],
      ['II', 'III', 'IV', 'IX', 'XII', 'XIV'],
    );
  });

  test('그림 배정: 한 그림은 3번까지, 같은 그림은 100스테이지 이상 떨어져서', () {
    final pack = jsonDecode(packText) as List;
    final arts = [
      for (final l in pack) (((l as Map)['meta'] as Map)['art'] as String),
    ];
    final uses = <String, int>{}, last = <String, int>{};
    for (var i = 0; i < arts.length; i++) {
      final a = arts[i];
      uses[a] = (uses[a] ?? 0) + 1;
      if (last.containsKey(a)) {
        expect(
          i - last[a]!,
          greaterThanOrEqualTo(100),
          reason: '$a: ${last[a]! + 1} → ${i + 1}',
        );
      }
      last[a] = i;
    }
    expect(uses.values.every((n) => n <= 3), isTrue);
    // 같은 유형(산 풍경끼리, 친구 캐릭터끼리 …)은 8스테이지 안에 겹치지 않는다
    final lastFam = <String, int>{};
    for (var i = 5; i < arts.length; i++) {
      final f = familyOf(arts[i]);
      if (lastFam.containsKey(f)) {
        expect(i - lastFam[f]!, greaterThanOrEqualTo(8), reason: f);
      }
      lastFam[f] = i;
    }
  });

  test('코드로 그린 그림: 이름이 겹치지 않고, 크기 16칸·색 6개 이하, 언제 돌려도 같다', () {
    final gen = generatedArts();
    final all = [...artSources, ...gen];
    expect(all.map((a) => a.name).toSet().length, all.length);
    expect(
      all.map((a) => a.ko).toSet().length,
      all.length,
      reason: '한국어 이름 중복',
    );
    expect(gen.length, greaterThanOrEqualTo(250));
    for (final a in gen) {
      expect(a.rows.length, lessThanOrEqualTo(16), reason: a.name);
      expect(a.rows.every((r) => r.length <= 16), isTrue, reason: a.name);
      expect(a.palette.length, inInclusiveRange(2, 6), reason: a.name);
      final keys = a.palette.map((p) => p[0]).toSet();
      expect(
        a.rows.join().split('').where((c) => c != '.').every(keys.contains),
        isTrue,
        reason: a.name,
      );
    }
    final again = generatedArts();
    for (var i = 0; i < gen.length; i++) {
      expect(again[i].rows, gen[i].rows);
    }
    // 풍경화 · 캐릭터 · 일러스트가 모두 있다
    bool has(String p) => gen.any((a) => a.name.startsWith(p));
    for (final p in [
      'g_mountain_',
      'g_city_',
      'g_friend_',
      'g_robot_',
      'g_pal_',
      'g_balloon_',
      'g_tile',
      'g_food_',
    ]) {
      expect(has(p), isTrue, reason: p);
    }
  });
}
