// levelgen build <config> : 설정 → isolate 병렬 생성 → 정렬·배치 → out/<pack>.json, report.csv, previews/*.png
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:bloom_wave/domain/engine.dart';

import 'config.dart';
import 'generate_one.dart';
import 'js_json.dart';
import 'png.dart';

/// 레벨 하나를 한 줄로: diff가 읽기 쉽고 파일이 작다. 같은 입력이면 바이트 단위로 같다 (TS 의 JSON.stringify 와 같은 바이트).
String serializePack(List<Level> levels) =>
    '[\n${levels.map((l) => '  ${jsStringify(l.toJson())}').join(',\n')}\n]\n';

// 클로저가 runPool 의 지역 변수(보낼 수 없는 것 포함)를 잡지 않도록 최상위 함수에서 만든다
Future<JobResult> _runIsolated(Job job) => Isolate.run(() => runJob(job));

String _join(String a, [String? b, String? c]) =>
    [a, ?b, ?c].join(Platform.pathSeparator);

/// 작업을 threads 개의 isolate 에 나눠 돌린다. 결과는 끝난 순서 (arrange 가 index 로 다시 정렬한다)
Future<List<JobResult>> runPool(
  List<Job> jobs,
  int threads,
  void Function(JobResult r, int done) onDone,
) async {
  final results = <JobResult>[];
  if (threads <= 1) {
    for (final j in jobs) {
      results.add(runJob(j));
      onDone(results.last, results.length);
    }
    return results;
  }
  var next = 0;
  Future<void> worker() async {
    while (next < jobs.length) {
      final job = jobs[next++];
      final JobResult r;
      try {
        r = await _runIsolated(job);
      } catch (e, st) {
        throw StateError('level #${job.index + 1}: $e\n$st');
      }
      results.add(r);
      onDone(r, results.length);
    }
  }

  final n = threads < jobs.length ? threads : jobs.length;
  await Future.wait([for (var t = 0; t < n; t++) worker()], eagerError: true);
  return results;
}

/// 구간 안에서: 숨 돌리기/보스는 설정 위치에 고정, 나머지는 score 오름차순으로 채운다. 튜토리얼은 설정 순서 그대로.
List<JobResult> arrange(PackConfig config, List<JobResult> results) {
  final byIndex = {for (final r in results) r.index: r};
  final out = <JobResult>[];
  final bands = config.levels.map((l) => l.band).toSet(); // 등장 순서 유지
  for (final band in bands) {
    final idx = [
      for (var i = 0; i < config.levels.length; i++)
        if (config.levels[i].band == band) i,
    ];
    if (band == 'tutorial') {
      out.addAll(idx.map((i) => byIndex[i]!));
      continue;
    }
    final regular =
        [
          for (final i in idx)
            if (config.levels[i].role == null) byIndex[i]!,
        ]..sort((a, b) {
          final d = a.report.score - b.report.score;
          return d != 0 ? d : a.index - b.index;
        });
    var k = 0;
    for (final i in idx) {
      out.add(config.levels[i].role != null ? byIndex[i]! : regular[k++]);
    }
  }
  return out;
}

String _pad(Object v, int w) => '$v'.padLeft(w);

Future<List<Level>> build(String configPath, {int? threads, int? limit}) async {
  final cfgFile = File(configPath).absolute.path;
  final base = File(cfgFile).parent.path;
  final config = PackConfig.fromJson(
    jsonDecode(File(cfgFile).readAsStringSync()) as Map<String, dynamic>,
  );
  final limited = limit != null && limit != 0;
  if (limited) config.levels = config.levels.take(limit).toList();
  final names =
      jsonDecode(File(_join(base, 'art', 'names.json')).readAsStringSync())
          as Map<String, dynamic>;
  final jobs = [
    for (var index = 0; index < config.levels.length; index++)
      () {
        final spec = config.levels[index];
        final n = names[spec.art] as Map<String, dynamic>?;
        return Job(
          index: index,
          spec: spec,
          defaults: config.defaults,
          artPath: _join(base, 'art', '${spec.art}.png'),
          names: n == null
              ? LevelName(spec.art, spec.art)
              : LevelName(n['ko'] as String, n['en'] as String),
        );
      }(),
  ];
  final nThreads =
      threads ?? (Platform.numberOfProcessors - 1).clamp(1, 1 << 20);
  final sw = Stopwatch()..start();
  stdout.writeln('building ${jobs.length} levels on $nThreads threads…');
  final results = await runPool(jobs, nThreads, (r, done) {
    final ms = r.tried.fold<int>(0, (a, t) => a + t.ms);
    final l = r.level;
    stdout.writeln(
      '[${_pad(done, 3)}/${jobs.length}] #${r.index + 1} ${l.id} seed=${r.seed} '
      '${l.width}x${l.height} lanes=${l.lanes.length} '
      'win=${(r.report.randomWinRate * 100).toStringAsFixed(0)}% '
      '${r.report.difficulty.name} score=${r.report.score} (${ms}ms)',
    );
  });
  final ordered = arrange(config, results);
  final levels = [for (final r in ordered) r.level];

  final out = _join(base, 'out');
  Directory(_join(out, 'previews')).createSync(recursive: true);
  final packFile = _join(out, '${config.pack}.json');
  File(packFile).writeAsStringSync(serializePack(levels));
  final csv = [
    'no,id,band,role,size,lanes,colors,cells,drops,peakSlots,avgSlots,randomWinRate,difficulty,solverNodes,score,seed',
  ];
  for (var i = 0; i < ordered.length; i++) {
    final r = ordered[i];
    final spec = config.levels[r.index];
    final m = r.level.meta!;
    csv.add(
      [
        i + 1,
        r.level.id,
        spec.band,
        spec.role ?? '',
        '${r.level.width}x${r.level.height}',
        r.level.lanes.length,
        r.report.colors,
        r.report.cells,
        r.report.drops,
        m.peakSlots,
        jsNum(m.avgSlots),
        jsNum(m.randomWinRate),
        m.difficulty.name,
        m.solverNodes,
        m.score,
        r.seed,
      ].join(','),
    );
    writePreview(
      _join(out, 'previews', '${'${i + 1}'.padLeft(3, '0')}-${r.level.id}.png'),
      r.level,
      createState(r.level),
    );
  }
  File(_join(out, 'report.csv')).writeAsStringSync('${csv.join('\n')}\n');
  // 경고는 설정 순서로 (스레드 수와 무관하게 같은 출력)
  final warned = <String>{};
  for (final r in [...results]..sort((a, b) => a.index - b.index)) {
    warned.addAll(r.warnings);
  }
  for (final w in warned) {
    stderr.writeln('warn: $w');
  }
  if (!limited) {
    for (final dest in config.copyTo ?? const <String>[]) {
      final d = Directory(base).uri.resolve(dest).toFilePath();
      File(d).parent.createSync(recursive: true);
      File(packFile).copySync(d);
      stdout.writeln('copied → $d');
    }
  }
  stdout.writeln(
    'done: ${levels.length} levels in '
    '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s → $packFile',
  );
  return levels;
}
