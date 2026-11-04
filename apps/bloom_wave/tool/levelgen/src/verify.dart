// levelgen verify <pack.json>
// ①물방울 총량 = 칸 수 ②8방향 덩어리마다 시작 지점 ③솔버 클리어 가능 ④해법 재생 시 클리어. 하나라도 실패하면 종료 코드 1.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/domain/generator.dart';
import 'package:bloom_wave/domain/solver.dart';

List<String> checkLevel(
  Level level, {
  int maxNodes = 200000,
  int minLanes = 3,
}) {
  final errs = <String>[];
  final n = level.width * level.height;
  if (level.cells.length != n) {
    errs.add('cells length ${level.cells.length} != $n');
  }
  final cellCount = level.cells.where((c) => c != empty).length;
  final drops = level.lanes.expand((l) => l).toList();
  final total = drops.fold<int>(0, (a, d) => a + d.amount);
  if (total != cellCount) errs.add('drop total $total != cells $cellCount');
  if (drops.any(
    (d) => d.amount <= 0 || d.color < 0 || d.color >= level.palette.length,
  )) {
    errs.add('bad drop in queue');
  }
  if (level.lanes.length < minLanes) {
    errs.add('only ${level.lanes.length} queue lanes (min $minLanes)');
  }
  if (level.lanes.any((l) => l.isEmpty)) errs.add('empty queue lane');
  // 칸 배열 길이가 틀리면 덩어리 검사는 건너뛴다 (범위 밖 접근 방지)
  if (level.cells.length == n) {
    final seen = Uint8List(n);
    final starts = level.starts.toSet();
    for (var i = 0; i < n; i++) {
      if (level.cells[i] == empty || seen[i] != 0) continue;
      final stack = [i];
      seen[i] = 1;
      var has = false;
      while (stack.isNotEmpty) {
        final c = stack.removeLast();
        if (starts.contains(c)) has = true;
        final x = c % level.width, y = c ~/ level.width;
        for (final (dx, dy) in dir8) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= level.width || ny >= level.height) {
            continue;
          }
          final j = ny * level.width + nx;
          if (level.cells[j] != empty && seen[j] == 0) {
            seen[j] = 1;
            stack.add(j);
          }
        }
      }
      if (!has) errs.add('component at cell $i has no start');
    }
  }
  if (errs.isNotEmpty) return errs;
  final opt = level.options;
  final r = solve(level, opt, maxNodes);
  if (r.solvable != true) {
    errs.add(
      'solver: ${r.solvable == null ? "node limit" : "unsolvable"} (${r.nodes} nodes)',
    );
  } else if (!replay(level, r.solution, opt)) {
    errs.add('solution replay did not clear');
  }
  return errs;
}

bool verify(String packPath) {
  final List raw;
  try {
    raw = jsonDecode(File(packPath).readAsStringSync()) as List;
  } catch (e) {
    stderr.writeln('x $packPath: $e');
    stdout.writeln('verify FAILED');
    return false;
  }
  var ok = true;
  final ids = <String>{};
  for (var i = 0; i < raw.length; i++) {
    final Level l;
    try {
      l = Level.fromJson(raw[i] as Map<String, dynamic>);
    } catch (e) {
      ok = false;
      stderr.writeln('x #${i + 1}: malformed level ($e)');
      continue;
    }
    final errs = checkLevel(l);
    if (ids.contains(l.id)) errs.add('duplicate id');
    ids.add(l.id);
    if (errs.isNotEmpty) {
      ok = false;
      stderr.writeln('x #${i + 1} ${l.id}: ${errs.join('; ')}');
    }
  }
  stdout.writeln(ok ? 'ok: ${raw.length} levels verified' : 'verify FAILED');
  return ok;
}
