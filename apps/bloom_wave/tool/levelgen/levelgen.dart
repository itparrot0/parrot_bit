// Bloom Wave 레벨 생성기 CLI (apps/bloom_wave 에서 실행)
//   dart run tool/levelgen/levelgen.dart build tool/levelgen/levels.config.json [--threads N] [--limit N]
//   dart run tool/levelgen/levelgen.dart verify tool/levelgen/out/pack-01.json
//   dart run tool/levelgen/levelgen.dart art [artDir]          텍스트 아트(src/art_source.dart) → art/*.png, names.json
//   dart run tool/levelgen/levelgen.dart config [configPath]   levels.config.json 다시 만들기
//   dart run tool/levelgen/levelgen.dart icons <outDir>        앱 아이콘 원본 PNG
//   dart run tool/levelgen/levelgen.dart sheet <out.png> [접두어]  그림 콘택트 시트 (검토용)
import 'dart:io';

import 'src/art.dart';
import 'src/build.dart';
import 'src/icon.dart';
import 'src/make_config.dart';
import 'src/sheet.dart';
import 'src/verify.dart';

const _usage =
    'usage: levelgen build <config.json> [--threads N] [--limit N] | levelgen verify <pack.json>\n'
    '       levelgen art [artDir] | levelgen config [config.json] | levelgen icons <outDir>';

String get _here => File.fromUri(Platform.script).parent.path;

Never _fail() {
  stderr.writeln(_usage);
  exit(2);
}

Future<void> main(List<String> argv) async {
  final cmd = argv.isNotEmpty ? argv[0] : null;
  final file = argv.length > 1 ? argv[1] : null;
  final rest = argv.length > 2 ? argv.sublist(2) : const <String>[];
  int? flag(String name) {
    final i = rest.indexOf('--$name');
    if (i < 0) return null;
    final v = i + 1 < rest.length ? int.tryParse(rest[i + 1]) : null;
    return v ?? _fail();
  }

  switch (cmd) {
    case 'build' when file != null:
      await build(file, threads: flag('threads'), limit: flag('limit'));
      exit(0);
    case 'verify' when file != null:
      exit(verify(file) ? 0 : 1);
    case 'sheet' when file != null:
      writeSheet(file, prefix: argv.length > 2 ? argv[2] : '');
    case 'art':
      writeArt(file ?? '$_here/art');
    case 'config':
      writeConfig(file ?? '$_here/levels.config.json');
    case 'icons' when file != null:
      writeIcons(file);
    default:
      _fail();
  }
}
