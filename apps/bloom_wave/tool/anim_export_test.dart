// 임시 칸 애니메이션 프레임을 PNG 로 내보낸다 (디자이너 견본 겸 앱 기본 에셋).
//   flutter test tool/anim_export_test.dart
// 만드는 것:
//   assets/anim/{seed,sprout,bloom_<스킨>}.png, *_light.png, anim.json
//   docs/anim/cell_anim_preview.gif — 색을 입혀 재생한 미리보기 (씨앗 → 발아 → 개화)
// 주의: 디자이너 PNG 로 바꾼 뒤에 다시 돌리면 덮어쓴다. --dart-define=ONLY_PREVIEW=true 면 PNG 는 그대로 두고
// assets/anim 의 PNG 로 미리보기만 다시 만든다.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bloom_wave/economy/skins.dart';
import 'package:bloom_wave/ui/cell_sprites.dart';
import 'package:bloom_wave/ui/cell_sprites_gen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const onlyPreview = bool.fromEnvironment('ONLY_PREVIEW');

Future<Uint8List> _png(ui.Image im) async =>
    (await im.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

/// 미리보기 칸 색 (스킨마다 하나)
const _sample = [0x46A758, 0xF5D90A, 0xE5484D, 0xF19CBB, 0xF76B15, 0x3E9BDB];

void main() {
  test('칸 애니메이션 견본 PNG · 미리보기 GIF', () async {
    final dir = Directory('assets/anim')..createSync(recursive: true);
    final sheets = [
      'seed',
      'sprout',
      for (final s in skins) 'bloom_${s.id}',
      for (final s in skins) 'full_${s.id}',
    ];
    if (!onlyPreview) {
      for (final sh in sheets) {
        final n = defaultFrames(sh);
        for (final light in [false, true]) {
          if (sh == 'seed' && light) continue; // 씨앗은 light 레이어 없음
          final im = await renderSheet(sh, n, light: light);
          File(
            '${dir.path}/$sh${light ? '_light' : ''}.png',
          ).writeAsBytesSync(await _png(im));
        }
      }
      File('${dir.path}/anim.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({
          'seed': {'frameMs': 0},
          'sprout': {'frameMs': defaultFrameMs},
          'bloom': {'frameMs': defaultFrameMs},
          'full': {'frameMs': 40},
        })}\n',
      );
    }

    // ---- 미리보기 GIF: 실제 앱과 같은 방식(tint × 색 + light)으로 합성 ----
    Future<img.Image?> load(String name) async {
      final f = File('${dir.path}/$name.png');
      if (!f.existsSync()) return null;
      return img.decodePng(f.readAsBytesSync());
    }

    final manifest =
        jsonDecode(File('${dir.path}/anim.json').readAsStringSync())
            as Map<String, dynamic>;
    final seed = (await load('seed'))!;
    final sprout = (await load('sprout'))!,
        sproutL = await load('sprout_light');
    const cell = 128, pad = 16;
    final w = skins.length * (cell + pad) + pad, h = cell + pad * 2;
    // 타임라인 (40ms 단위): 씨앗 6 → 발아 → 멈춤 6 → 개화 → 멈춤 12
    const step = 40.0;
    final sproutMs = frameMsFor(manifest, 'sprout');
    final sproutN = sprout.width ~/ sprout.height;
    final blooms = <(img.Image, img.Image?, int, double)>[];
    for (final s in skins) {
      final t = (await load('bloom_${s.id}'))!;
      blooms.add((
        t,
        await load('bloom_${s.id}_light'),
        t.width ~/ t.height,
        frameMsFor(manifest, 'bloom_${s.id}'),
      ));
    }
    final sproutDur = sproutN * sproutMs;
    final bloomDur = blooms
        .map((b) => b.$3 * b.$4)
        .reduce((a, b) => a > b ? a : b);
    final total = 6 * step + sproutDur + 6 * step + bloomDur + 12 * step;
    img.Image? anim;
    for (var ms = 0.0; ms < total; ms += step) {
      final frame = img.Image(width: w, height: h);
      img.fill(frame, color: img.ColorRgb8(0x2F, 0x2A, 0x25));
      for (var k = 0; k < skins.length; k++) {
        final col = _sample[k % _sample.length];
        final ox = pad + k * (cell + pad), oy = pad;
        img.Image tint;
        img.Image? light;
        int f;
        var t = ms - 6 * step;
        if (t < 0) {
          (tint, light, f) = (seed, null, 0);
        } else if (t < sproutDur + 6 * step) {
          (tint, light) = (sprout, sproutL);
          f = spriteFrameAt(t, sproutN, sproutMs);
        } else {
          t -= sproutDur + 6 * step;
          final b = blooms[k];
          (tint, light) = (b.$1, b.$2);
          f = spriteFrameAt(t, b.$3, b.$4);
        }
        _blit(frame, tint, f, ox, oy, col);
        if (light != null) _blit(frame, light, f, ox, oy, null);
      }
      frame.frameDuration = (step / 10).round();
      if (anim == null) {
        anim = frame;
      } else {
        anim.addFrame(frame);
      }
    }
    Directory('docs/anim').createSync(recursive: true);
    File(
      'docs/anim/cell_anim_preview.gif',
    ).writeAsBytesSync(img.encodeGif(anim!, repeat: 0));
  });
}

/// 시트 [src] 의 [f]번째 프레임을 (ox, oy) 에 얹는다. tint 가 있으면 픽셀 색 × tint
void _blit(img.Image dst, img.Image src, int f, int ox, int oy, int? tint) {
  final n = src.height;
  final tr = tint == null ? 255 : (tint >> 16) & 255;
  final tg = tint == null ? 255 : (tint >> 8) & 255;
  final tb = tint == null ? 255 : tint & 255;
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final p = src.getPixel(f * n + x, y);
      final a = p.a / 255;
      if (a <= 0) continue;
      final r = p.r * tr / 255, g = p.g * tg / 255, b = p.b * tb / 255;
      final d = dst.getPixel(ox + x, oy + y);
      dst.setPixelRgb(
        ox + x,
        oy + y,
        (d.r * (1 - a) + r * a).round(),
        (d.g * (1 - a) + g * a).round(),
        (d.b * (1 - a) + b * a).round(),
      );
    }
  }
}
