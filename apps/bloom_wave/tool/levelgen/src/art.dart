// art_source.dart 의 텍스트 픽셀 아트를 art/<name>.png 와 art/names.json 으로 내보낸다.
import 'dart:io';
import 'dart:math' as math;

import 'package:bloom_wave/domain/generator.dart';

import 'art_source.dart';
import 'js_json.dart';
import 'png.dart';

void writeArt(String dir) {
  Directory(dir).createSync(recursive: true);
  final names = <String, Map<String, String>>{};
  for (final a in artSources) {
    final w = a.rows.map((r) => r.length).reduce(math.max);
    File('$dir/${a.name}.png').writeAsBytesSync(
      encodeArt(
        PixelArt(a.name, a.palette, [
          for (final r in a.rows) r.padRight(w, '.'),
        ]),
      ),
    );
    names[a.name] = {'ko': a.ko, 'en': a.en};
  }
  File('$dir/names.json').writeAsStringSync('${jsStringifyPretty(names)}\n');
  stdout.writeln('wrote ${artSources.length} PNGs to $dir');
}
