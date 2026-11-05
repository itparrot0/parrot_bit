// PNG ↔ 칸 배열. 알파 < 128 → 빈 칸, 같은 RGB → 같은 색, maxColors를 넘으면 가까운 색끼리 병합.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/domain/generator.dart';
import 'package:image/image.dart' as img;

typedef ImportResult = ({PixelArt art, List<String> warnings});

String _hex(int r, int g, int b) =>
    '#${[r, g, b].map((v) => v.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

List<int> _rgb(String h) => [
  for (final i in [1, 3, 5]) int.parse(h.substring(i, i + 2), radix: 16),
];

int _dist(String a, String b) {
  final x = _rgb(a), y = _rgb(b);
  final d0 = x[0] - y[0], d1 = x[1] - y[1], d2 = x[2] - y[2];
  return d0 * d0 + d1 * d1 + d2 * d2;
}

/// 픽셀을 8비트 RGBA 로 (pngjs 와 같게: 8비트가 아니면 round(v*255/max), 회색조는 r=g=b)
List<int> _rgba(img.Image im, img.Pixel p) {
  final max = im.maxChannelValue;
  int s(num v) => max == 255 ? v.toInt() : (v * 255 / max + 0.5).floor();
  if (!im.hasPalette && im.numChannels <= 2) {
    final gray = s(p.r);
    final a = im.numChannels == 2 ? s(p.a) : 255;
    return [gray, gray, gray, a];
  }
  final a = im.hasPalette || im.numChannels == 4 ? s(p.a) : 255;
  return [s(p.r), s(p.g), s(p.b), a];
}

ImportResult decodePng(Uint8List buf, String name, [int maxColors = 6]) {
  final png = img.decodePng(buf);
  if (png == null) throw FormatException('$name: PNG 를 읽을 수 없습니다');
  final width = png.width, height = png.height;
  final warnings = <String>[];
  if (width > 16 || height > 16) {
    warnings.add('$name: ${width}x$height — 16x16을 넘으면 모바일에서 칸이 너무 작아집니다');
  }
  final px = <String?>[];
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final c = _rgba(png, png.getPixel(x, y));
      px.add(c[3] < 128 ? null : _hex(c[0], c[1], c[2]));
    }
  }
  // 색별 칸 수 (등장 순서 유지 → 결정적)
  final counts = <String, int>{};
  for (final p in px) {
    if (p != null) counts[p] = (counts[p] ?? 0) + 1;
  }
  final remap = {for (final c in counts.keys) c: c};
  // 가장 가까운 두 색을 합치기를 반복 (적은 쪽을 많은 쪽으로)
  var colors = counts.keys.toList();
  while (colors.length > maxColors) {
    var best = (colors[0], colors[1]);
    num bd = double.infinity;
    for (var i = 0; i < colors.length; i++) {
      for (var j = i + 1; j < colors.length; j++) {
        final d = _dist(colors[i], colors[j]);
        if (d < bd) {
          bd = d;
          best = (colors[i], colors[j]);
        }
      }
    }
    final (a, b) = best;
    final (keep, drop) = counts[a]! >= counts[b]! ? (a, b) : (b, a);
    counts[keep] = counts[keep]! + counts[drop]!;
    counts.remove(drop);
    for (final k in remap.keys) {
      if (remap[k] == drop) remap[k] = keep;
    }
    colors = colors.where((c) => c != drop).toList();
    warnings.add('$name: 색 $drop → $keep 병합 (최대 $maxColors색)');
  }
  for (final c in colors) {
    if (counts[c]! < 3) {
      warnings.add('$name: 색 $c이 ${counts[c]}칸뿐입니다 — 이웃 색으로 합칠지 검토하세요');
    }
  }
  const keys = 'abcdefghijklmnopqrstuvwxyz';
  final palette = [
    for (var i = 0; i < colors.length; i++) '${keys[i]}=${colors[i]}',
  ];
  final rows = <String>[];
  for (var y = 0; y < height; y++) {
    final row = StringBuffer();
    for (var x = 0; x < width; x++) {
      final p = px[y * width + x];
      row.write(p != null ? keys[colors.indexOf(remap[p]!)] : '.');
    }
    rows.add(row.toString());
  }
  return (art: PixelArt(name, palette, rows), warnings: warnings);
}

ImportResult readPngArt(String path, String name, [int maxColors = 6]) =>
    decodePng(File(path).readAsBytesSync(), name, maxColors);

img.Image _rgbaImage(int width, int height) =>
    img.Image(width: width, height: height, numChannels: 4);

/// 1칸 = 1픽셀 PNG
Uint8List encodeArt(PixelArt art) {
  final width = art.rows.map((r) => r.length).reduce(math.max);
  final height = art.rows.length;
  final png = _rgbaImage(width, height);
  final map = {
    for (final p in art.palette) p.split('=')[0]: _rgb(p.split('=')[1]),
  };
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final row = art.rows[y];
      final c = map[x < row.length ? row[x] : '.'];
      if (c != null) {
        png.setPixelRgba(x, y, c[0], c[1], c[2], 255);
      } else {
        png.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
  return img.encodePng(png);
}

/// 미리보기: 시작 상태(씨앗 = 어두운 색, 발아 = 밝은 색 + 테두리)를 칸당 scale 픽셀로
void writePreview(String path, Level level, State s, [int scale = 12]) {
  final w = level.width * scale, h = level.height * scale;
  final png = _rgbaImage(w, h);
  for (var i = 0; i < level.cells.length; i++) {
    final st = s.cell[i];
    if (st == empty) continue;
    final c = _rgb(level.palette[level.cells[i]]);
    final k = st == seed
        ? 0.35
        : st == sprout
        ? 0.8
        : st == bloom
        ? 1.0
        : 0.0;
    final x0 = (i % level.width) * scale, y0 = (i ~/ level.width) * scale;
    for (var y = 0; y < scale; y++) {
      for (var x = 0; x < scale; x++) {
        final edge = x == 0 || y == 0 || x == scale - 1 || y == scale - 1;
        final ring =
            st == sprout &&
            (x < 2 || y < 2 || x >= scale - 2 || y >= scale - 2);
        final f = ring
            ? 1.25
            : edge
            ? k * 0.8
            : k;
        // Uint8Array 대입처럼 소수점 아래를 버린다
        int ch(int v) => math.min(255, v * f).truncate();
        png.setPixelRgba(x0 + x, y0 + y, ch(c[0]), ch(c[1]), ch(c[2]), 255);
      }
    }
  }
  File(path).writeAsBytesSync(img.encodePng(png));
}
