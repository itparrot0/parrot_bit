// 논리 해상도 1080×2340 (9:19.5) 기준 레이아웃 상수와 색. 화면 크기에 맞춰 통째로 확대·축소한다.
import 'dart:ui';

const double kW = 1080;
const double kH = 2340;

class C {
  static const bg = Color(0xFFF3EFE6);
  static const bgDeep = Color(0xFFE7E0D2);
  static const panel = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2D2A26);
  static const inkSoft = Color(0xFF7A736A);
  static const accent = Color(0xFF46A758);
  static const accentDark = Color(0xFF2A7E3B);
  static const warn = Color(0xFFE5484D);
  static const slot = Color(0xFFFBF8F2);
  static const slotEdge = Color(0xFFD9CFBF);
  static const gold = Color(0xFFF5B301);
  static const goldDark = Color(0xFFB07D00);
  static const locked = Color(0xFFC9C1B4);
  static const water = Color(0xFF3E9BDB);
  static const boardBg = Color(0xFF2F2A25);
  static const dim = Color(0x8C1D1A16);
}

Color hexColor(String hex) =>
    Color(0xFF000000 | int.parse(hex.replaceFirst('#', ''), radix: 16));

/// a 와 b 를 t 만큼 섞는다 (TS 의 mix 와 같은 반올림)
Color mix(Color a, Color b, double t) {
  int ch(double x, double y) => ((x + (y - x) * t) * 255).round();
  return Color.fromARGB(255, ch(a.r, b.r), ch(a.g, b.g), ch(a.b, b.b));
}

/// 밝은 색 위에서는 어두운 글자
bool isLight(Color c) =>
    (c.r * 255) * 0.3 + (c.g * 255) * 0.59 + (c.b * 255) * 0.11 > 200;
