// 앱 아이콘 원본(1024×1024) 생성: <outDir>/icon-only.png, icon-foreground.png, icon-background.png, splash.png
// 디자이너 아이콘이 오면 이 파일들만 교체한다 (Flutter 에서는 flutter_launcher_icons 등이 이 원본을 읽는다).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

typedef Rgb = (int, int, int);

Uint8List drawIcon(int size, Rgb? bg, double scale) {
  final png = img.Image(width: size, height: size, numChannels: 4);
  final c = size / 2;
  const Rgb petal = (0xe5, 0x48, 0x4d), center = (0xf5, 0xd9, 0x0a);
  // 픽셀 아트 느낌: 32칸 격자로 양자화
  final g = size / 32;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var col = bg;
      final qx = ((x / g).floor() + 0.5) * g - c;
      final qy = ((y / g).floor() + 0.5) * g - c;
      final r = math.sqrt(qx * qx + qy * qy) / (size * scale);
      final a = math.atan2(qy, qx);
      final petalR = 0.42 * (0.72 + 0.28 * math.cos(5 * (a + math.pi / 2)));
      if (r < 0.13) {
        col = center;
      } else if (r < petalR) {
        col = petal;
      }
      if (col != null) {
        png.setPixelRgba(x, y, col.$1, col.$2, col.$3, 255);
      }
    }
  }
  return img.encodePng(png);
}

Uint8List solidIcon(int size, Rgb bg) {
  final png = img.Image(width: size, height: size, numChannels: 4);
  img.fill(png, color: img.ColorRgba8(bg.$1, bg.$2, bg.$3, 255));
  return img.encodePng(png);
}

void writeIcons(String out) {
  Directory(out).createSync(recursive: true);
  const Rgb bg = (0x46, 0xa7, 0x58);
  File('$out/icon-only.png').writeAsBytesSync(drawIcon(1024, bg, 1));
  // 적응형 아이콘 안전 영역 안에
  File('$out/icon-foreground.png').writeAsBytesSync(drawIcon(1024, null, 0.62));
  File('$out/icon-background.png').writeAsBytesSync(solidIcon(1024, bg));
  File(
    '$out/splash.png',
  ).writeAsBytesSync(drawIcon(2732, (0xf3, 0xef, 0xe6), 0.18));
  stdout.writeln('icons written to $out');
}
