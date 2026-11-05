// 디자이너 스프라이트 원본(검정 배경, 2줄 × 8프레임)을 게임용 칸 시트로 자른다.
//   dart run tool/anim_import.dart tool/anim_src/flower_pink.webp --skin basic
//
// 원본 규칙: 1줄 = 씨앗 → 싹(발아 8프레임, 첫 프레임 = 씨앗), 2줄 = 싹 → 꽃(개화 8프레임).
// 프레임 위치는 검정이 아닌 픽셀 덩어리로 자동으로 찾는다. 모든 프레임을 같은 배율로 줄이고 줄기 밑동을 맞춘다.
// 색 나누기: 분홍(씨앗 꼬투리·꽃잎) → tint 레이어(회색조, 게임이 칸 색을 입힘)
//           나머지(초록 잎·줄기·노란 꽃술·흰 하이라이트) → light 레이어(그대로)
// 칸 바탕 타일은 없다(--tile 이면 깐다). 싹은 밑동에 남긴 껍질로 칸 색을 보인다(--husk, 기본). 만드는 파일: assets/anim/seed.png, sprout(_light).png,
// bloom_<스킨>(_light).png. anim.json 은 손대지 않는다.
import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:image/image.dart' as img;

const out = 128; // 칸 한 변
const content = 120; // 칸 안에 그림이 차지하는 한 변
const bottomPad = 8; // 원본에서 줄기 밑동 아래 여백 (원본 px)

double _clamp(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _smooth(double a, double b, double x) {
  final t = _clamp((x - a) / (b - a));
  return t * t * (3 - 2 * t);
}

List<(int, int)> _runs(List<bool> on, int gap) {
  final r = <(int, int)>[];
  int? s;
  var last = -1000;
  for (var i = 0; i < on.length; i++) {
    if (!on[i]) continue;
    if (s == null) {
      s = i;
    } else if (i > last + gap) {
      r.add((s, last));
      s = i;
    }
    last = i;
  }
  if (s != null) r.add((s, last));
  return r;
}

void main(List<String> argv) {
  final args =
      (ArgParser()
            ..addOption('skin', defaultsTo: 'basic')
            ..addOption('out', defaultsTo: 'assets/anim')
            ..addFlag('no-seed', help: '씨앗·발아 시트는 그대로 두고 개화만')
            ..addFlag('tile', help: '칸 바탕 타일(칸 색)을 깐다')
            ..addFlag('husk', defaultsTo: true, help: '싹 밑동에 꼬투리 껍질(칸 색)을 남긴다'))
          .parse(argv);
  final src = img.decodeImage(File(args.rest.single).readAsBytesSync())!;
  final w = src.width, h = src.height;
  bool ink(int x, int y) {
    final p = src.getPixel(x, y);
    return math.max(p.r, math.max(p.g, p.b)) > 25;
  }

  // 줄(띠) → 프레임
  final rowOn = [
    for (var y = 0; y < h; y++)
      () {
        for (var x = 0; x < w; x++) {
          if (ink(x, y)) return true;
        }
        return false;
      }(),
  ];
  final bands = _runs(rowOn, 5);
  if (bands.length != 2) {
    stderr.writeln('줄이 2개가 아니다: $bands');
    exit(1);
  }
  final rows = <List<(int, int, int, int)>>[];
  for (final (y0, y1) in bands) {
    final colOn = [
      for (var x = 0; x < w; x++)
        () {
          for (var y = y0; y <= y1; y++) {
            if (ink(x, y)) return true;
          }
          return false;
        }(),
    ];
    rows.add([for (final (x0, x1) in _runs(colOn, 3)) (x0, y0, x1, y1)]);
  }
  // 창 크기: 가장 큰 프레임 + 여백 (모든 프레임 같은 배율)
  var side = 0;
  for (final row in rows) {
    for (final (x0, y0, x1, y1) in row) {
      side = math.max(side, math.max(x1 - x0, y1 - y0) + bottomPad * 2);
    }
  }
  stdout.writeln('프레임 ${rows.map((r) => r.length).toList()}, 창 $side px');

  /// 한 프레임 → (tint, light) 그림 부분만 content×content
  (img.Image, img.Image) cut((int, int, int, int) f) {
    final (x0, _, x1, y1) = f;
    final cx = (x0 + x1) ~/ 2;
    final left = cx - side ~/ 2, top = y1 + bottomPad - side;
    final tint = img.Image(width: side, height: side, numChannels: 4);
    final light = img.Image(width: side, height: side, numChannels: 4);
    for (var y = 0; y < side; y++) {
      for (var x = 0; x < side; x++) {
        final sx = left + x, sy = top + y;
        if (sx < 0 || sy < 0 || sx >= w || sy >= h) continue;
        // 옆 프레임이 창에 걸리지 않게 이 프레임 덩어리 범위만
        if (sx < x0 - 2 || sx > x1 + 2) continue;
        final p = src.getPixel(sx, sy);
        final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
        final v = math.max(r, math.max(g, b));
        final a = _clamp((v - 10) / 36); // 검정 배경 → 투명
        if (a <= 0) continue;
        // 검정 위에 섞인 가장자리 색을 되돌린다
        double un(double c) => math.min(255, c / a);
        final ur = un(r), ug = un(g), ub = un(b);
        // 분홍스러움: 빨강이 초록보다 확실히 크고, 파랑이 너무 낮지 않다(노랑·주황 제외)
        final pink =
            _smooth(0.12, 0.28, (ur - ug) / math.max(1, ur)) *
            _smooth(0.55, 0.8, ub / math.max(1, ug));
        if (pink > 0) {
          final grey = (_clamp(math.max(ur, math.max(ug, ub)) / 235) * 255)
              .round();
          tint.setPixelRgba(x, y, grey, grey, grey, (a * pink * 255).round());
        }
        if (pink < 1) {
          light.setPixelRgba(
            x,
            y,
            ur.round(),
            ug.round(),
            ub.round(),
            (a * (1 - pink) * 255).round(),
          );
        }
      }
    }
    img.Image shrink(img.Image im) => img.copyResize(
      im,
      width: content,
      height: content,
      interpolation: img.Interpolation.average,
    );
    return (shrink(tint), shrink(light));
  }

  double inkSum(img.Image im) {
    var t = 0.0;
    for (final p in im) {
      t += p.a / 255;
    }
    return t;
  }

  /// 128 칸 한 프레임: (바탕 타일) + 껍질(tint, 아래) + 그림 tint / 그림 light
  (img.Image, img.Image) compose(
    (img.Image, img.Image) c, {
    double? tileGrey,
    img.Image? husk,
    double huskAlpha = 0,
  }) {
    const o = (out - content) ~/ 2;
    final t = img.Image(width: out, height: out, numChannels: 4);
    if (tileGrey != null) {
      final tg = (tileGrey * 255).round();
      img.fillRect(
        t,
        x1: 4,
        y1: 4,
        x2: out - 5,
        y2: out - 5,
        radius: 22,
        color: img.ColorRgba8(tg, tg, tg, 255),
      );
    }
    if (husk != null && huskAlpha > 0) {
      final hk = husk.clone();
      if (huskAlpha < 1) {
        for (final p in hk) {
          p.a = p.a * huskAlpha;
        }
      }
      img.compositeImage(
        t,
        hk,
        dstX: (out - hk.width) ~/ 2,
        dstY: o + content - hk.height,
      );
    }
    img.compositeImage(t, c.$1, dstX: o, dstY: o);
    final l = img.Image(width: out, height: out, numChannels: 4);
    img.compositeImage(l, c.$2, dstX: o, dstY: o);
    return (t, l);
  }

  img.Image strip(List<img.Image> frames) {
    final s = img.Image(
      width: out * frames.length,
      height: out,
      numChannels: 4,
    );
    for (var i = 0; i < frames.length; i++) {
      img.compositeImage(s, frames[i], dstX: i * out, dstY: 0);
    }
    return s;
  }

  void save(String name, img.Image im) {
    File('${args['out']}/$name.png').writeAsBytesSync(img.encodePng(im));
    stdout.writeln('  $name.png  ${im.width}×${im.height}');
  }

  final rawSprout = [for (final f in rows[0]) cut(f)];
  final rawBloom = [for (final f in rows[1]) cut(f)];
  final tile = args['tile'] as bool;

  // 칸 색 표시용 껍질 (임시, 2026-11-05): 바탕 타일 없이도 싹이 무슨 색 칸인지 보이도록,
  // 꼬투리가 아직 남아 있는 마지막 발아 프레임의 분홍(=칸 색) 부분을 줄여 이후 싹 밑동에 남긴다.
  // 개화하며 봉오리(칸 색)가 나오면 사라진다. 디자이너 원본에 껍질이 그려져 오면 --no-husk.
  img.Image? husk;
  var huskFrom = rawSprout.length;
  if (args['husk'] as bool) {
    final first = inkSum(rawSprout.first.$1);
    for (var i = rawSprout.length - 1; i >= 0; i--) {
      if (inkSum(rawSprout[i].$1) > first * 0.3) {
        huskFrom = i;
        break;
      }
    }
    final h0 = rawSprout[huskFrom].$1;
    husk = img.copyResize(
      h0,
      width: (h0.width * 0.8).round(),
      height: (h0.height * 0.8).round(),
      interpolation: img.Interpolation.average,
    );
    stdout.writeln('껍질: 발아 ${huskFrom + 1}번 프레임의 꼬투리');
  }
  const bloomHusk = [1.0, 1.0, 0.6, 0.3]; // 개화 프레임별 껍질 진하기

  // 바탕(--tile): 씨앗 0.30 → 싹 0.40 → 꽃 0.50
  final sprout = [
    for (var i = 0; i < rawSprout.length; i++)
      compose(
        rawSprout[i],
        tileGrey: tile ? 0.30 + 0.10 * i / (rawSprout.length - 1) : null,
        husk: husk,
        huskAlpha: i > huskFrom ? 1 : 0,
      ),
  ];
  final bloom = [
    for (var i = 0; i < rawBloom.length; i++)
      compose(
        rawBloom[i],
        tileGrey: tile ? 0.40 + 0.10 * i / (rawBloom.length - 1) : null,
        husk: husk,
        huskAlpha: i < bloomHusk.length ? bloomHusk[i] : 0,
      ),
  ];
  if (!(args['no-seed'] as bool)) {
    save('seed', sprout.first.$1);
    save('seed_light', sprout.first.$2);
    save('sprout', strip([for (final f in sprout) f.$1]));
    save('sprout_light', strip([for (final f in sprout) f.$2]));
  }
  final skin = args['skin'];
  save('bloom_$skin', strip([for (final f in bloom) f.$1]));
  save('bloom_${skin}_light', strip([for (final f in bloom) f.$2]));
}
