// 그림 목록을 한 장의 PNG(콘택트 시트)로 — 새 그림을 눈으로 검토할 때 쓴다.
//   dart run tool/levelgen/levelgen.dart sheet <out.png> [이름 접두어]
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'art_gen.dart';
import 'art_source.dart';

void writeSheet(String out, {String prefix = ''}) {
  final arts = [
    for (final a in [...artSources, ...generatedArts()])
      if (a.name.startsWith(prefix)) a,
  ];
  const cell = 7, tile = 17 * cell, label = 18, cols = 8;
  final rows = (arts.length / cols).ceil();
  final sheet = img.Image(
    width: cols * (tile + 10),
    height: rows * (tile + label + 10),
  );
  img.fill(sheet, color: img.ColorRgb8(243, 239, 230));
  for (var i = 0; i < arts.length; i++) {
    final a = arts[i];
    final ox = (i % cols) * (tile + 10) + 5,
        oy = (i ~/ cols) * (tile + label + 10) + 5;
    final pal = {
      for (final p in a.palette)
        p.split('=')[0]: int.parse(p.split('=')[1].substring(1), radix: 16),
    };
    final w = a.rows.map((r) => r.length).reduce(math.max);
    final dx = (17 - w) * cell ~/ 2, dy = (17 - a.rows.length) * cell ~/ 2;
    for (var y = 0; y < a.rows.length; y++) {
      for (var x = 0; x < a.rows[y].length; x++) {
        final c = pal[a.rows[y][x]];
        if (c == null) continue;
        img.fillRect(
          sheet,
          x1: ox + dx + x * cell,
          y1: oy + dy + y * cell,
          x2: ox + dx + x * cell + cell - 2,
          y2: oy + dy + y * cell + cell - 2,
          color: img.ColorRgb8(c >> 16, (c >> 8) & 255, c & 255),
        );
      }
    }
    img.drawString(
      sheet,
      a.name
          .replaceFirst('g_', '')
          .substring(0, math.min(18, a.name.replaceFirst('g_', '').length)),
      font: img.arial14,
      x: ox,
      y: oy + tile + 2,
      color: img.ColorRgb8(60, 60, 60),
    );
  }
  File(out).writeAsBytesSync(img.encodePng(sheet));
  stdout.writeln('sheet: ${arts.length} arts → $out');
}
