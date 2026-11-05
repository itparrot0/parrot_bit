// 고해상도 · 고복잡도 그림 (2026-11-05, 2000 스테이지 확장용). 이름은 h_ 로 시작한다.
// 원본 해상도 자체가 크다 (한 변 24~32칸, 칸 640~780개) — 배율로 키운 블록 그림이 아니라 디테일이 그대로 칸이 된다.
//  - 큰 풍경 80 (32×22): 장면 16가지 × 시간대 5
//  - 만다라 40 (31×31): 색 테마 8 × 무늬 5
//  - 퀼트 30 (30×24): 색 테마 6 × 배치 5
//  - 스테인드글라스 30 (24×32): 무늬 6 × 색 테마 5
//  - 초상화 40 (26×30)
//  - 큰 동물 24 (30×24): 동물 12 × 배경 2
//  - 정물 20 (28×24): 주제 4 × 색 5
//  - 탈것 20 (32×20): 탈것 4 × 시간대 5
//  - 정원 20 (30×22)
// 색은 6개 이하(생성기 maxColors), 모두 시드 고정이라 언제 돌려도 같다.
import 'dart:math' as math;

import 'package:bloom_wave/domain/generator.dart';

import 'art_gen.dart';
import 'art_source.dart';

// ───────── 도구 ─────────

/// 네 귀퉁이를 반지름 r 로 둥글게 깎는다
void _round(Grid g, double r) {
  for (var y = 0; y < g.h; y++) {
    for (var x = 0; x < g.w; x++) {
      final cx = x + 0.5, cy = y + 0.5;
      final dx = cx < r ? r - cx : (cx > g.w - r ? cx - (g.w - r) : 0.0);
      final dy = cy < r ? r - cy : (cy > g.h - r ? cy - (g.h - r) : 0.0);
      if (dx > 0 && dy > 0 && dx * dx + dy * dy > r * r) g.set(x, y, '.');
    }
  }
}

/// 굵은 선분
void _line(
  Grid g,
  double x0,
  double y0,
  double x1,
  double y1,
  double w,
  String ch,
) {
  final dx = x1 - x0, dy = y1 - y0;
  final len2 = dx * dx + dy * dy;
  g.each((x, y) {
    final t = len2 == 0
        ? 0.0
        : (((x - x0) * dx + (y - y0) * dy) / len2).clamp(0.0, 1.0);
    final px = x0 + t * dx - x, py = y0 + t * dy - y;
    return px * px + py * py <= w * w / 4;
  }, ch);
}

/// 뾰족한 나무 (밑변 가운데 x, 밑 y, 높이 h)
void _pine(
  Grid g,
  double x,
  double base,
  double h,
  String ch, [
  String? trunk,
]) {
  g.poly([
    (x, base - h),
    (x - h * 0.42, base - 0.6),
    (x + h * 0.42, base - 0.6),
  ], ch);
  if (trunk != null) {
    g.rect(x.floor(), (base - 0.6).floor(), x.floor(), base.floor(), trunk);
  }
}

/// 지붕 있는 집
void _home(
  Grid g,
  int x,
  int base,
  int w,
  int h,
  String wall,
  String roof,
  String win,
) {
  g.rect(x, base - h + 1, x + w - 1, base, wall);
  g.poly([
    (x - 0.6, base - h + 1.0),
    (x + w / 2, base - h - w * 0.45),
    (x + w + 0.6, base - h + 1.0),
  ], roof);
  if (w >= 3 && h >= 2) g.set(x + w ~/ 2, base - 1, win);
}

String _hex(int r, int gr, int b) =>
    '#${[r, gr, b].map((v) => v.clamp(0, 255).toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

/// 색 섞기 (t = 0 이면 a, 1 이면 b)
String _mix(String a, String b, double t) {
  int c(String h, int i) =>
      int.parse(h.substring(1 + i * 2, 3 + i * 2), radix: 16);
  int m(int i) => (c(a, i) + (c(b, i) - c(a, i)) * t).round();
  return _hex(m(0), m(1), m(2));
}

class _Tm {
  const _Tm(this.id, this.ko, this.en, this.sky, this.sun, this.night);
  final String id, ko, en, sky, sun;
  final bool night;

  /// 밤에는 땅 색을 어둡게, 노을·저녁은 살짝 물들인다
  String tint(String c) => night
      ? _mix(c, '#1E2A55', 0.45)
      : id == 'sunset'
      ? _mix(c, '#F59E61', 0.15)
      : id == 'dusk'
      ? _mix(c, '#7C6FD6', 0.15)
      : c;
}

const _times = [
  _Tm('dawn', '새벽', 'Dawn', '#F9C6D3', '#FFF4C2', false),
  _Tm('day', '한낮', 'Midday', '#8ECDF5', '#F5D90A', false),
  _Tm('sunset', '노을', 'Sunset', '#F59E61', '#FDE047', false),
  _Tm('night', '달밤', 'Moonlit', '#1E3A8A', '#FEF3C7', true),
  _Tm('dusk', '보랏빛 저녁', 'Violet Dusk', '#7C6FD6', '#FBD38D', false),
];

/// 하늘 's' + 해/달 'u' (밤에는 초승달과 별)
Grid _sky(int w, int h, _Tm t, double sx, double sy, double r) {
  final g = Grid(w, h)..rect(0, 0, w - 1, h - 1, 's');
  g.ell(sx, sy, r, r, 'u');
  if (t.night) {
    g.ell(sx + r * 0.6, sy - r * 0.35, r * 0.85, r * 0.85, 's');
    final rng = mulberry32(w * 131 + h);
    for (var k = 0; k < 14; k++) {
      final x = (rng() * w).floor(), y = (rng() * h * 0.45).floor();
      if (g.at(x, y) == 's') g.set(x, y, 'u');
    }
  }
  return g;
}

// ───────── 큰 풍경 (32×22) ─────────
// 장면마다 'a'~'d' 네 색을 쓴다 (하늘 s, 해 u 와 합쳐 6색).

typedef _Scene = (
  String id,
  String ko,
  String en,
  Map<String, String> pal,
  void Function(Grid g, _Tm t, double Function() rng) draw,
);

List<_Scene> _scenes() => [
  (
    'lake',
    '설산 호수',
    'Alpine Lake',
    {'a': '#5C6B8A', 'b': '#F4F6FA', 'c': '#3E86C9', 'd': '#2E6B45'},
    (g, t, rng) {
      final peaks = [
        (4.0 + rng() * 3, 4.0),
        (13.0 + rng() * 3, 2.5),
        (24.0 + rng() * 3, 4.5),
      ];
      double ridge(double x) {
        var y = 13.0;
        for (final (px, py) in peaks) {
          y = math.min(y, py + (x - px).abs() * 0.95);
        }
        return y;
      }

      g.each((x, y) => y < 13 && y > ridge(x), 'a');
      g.each(
        (x, y) =>
            y < 13 && y > ridge(x) && y < ridge(x) + 2.2 && ridge(x) < 7.5,
        'b',
      );
      g.rect(0, 13, 31, 21, 'c');
      // 물에 비친 산 (한 줄 건너 반짝임)
      g.each(
        (x, y) => y > 13 && y < 21 && (y.floor()).isEven && 26 - y > ridge(x),
        'a',
      );
      for (var k = 0; k < 9; k++) {
        final x = k < 5 ? 1 + k * 2.2 : 21 + (k - 5) * 2.6;
        _pine(g, x, 13.4, 3.5 + rng() * 2.5, 'd');
      }
    },
  ),
  (
    'harbor',
    '항구 마을',
    'Harbor Town',
    {'a': '#2F7FB8', 'b': '#F3E9D2', 'c': '#D2553B', 'd': '#4A3B33'},
    (g, t, rng) {
      g.rect(0, 13, 31, 21, 'a');
      var x = 1;
      while (x < 30) {
        final w = 3 + (rng() * 2).floor(), h = 3 + (rng() * 4).floor();
        _home(g, x, 12, w, h, 'b', 'c', 'd');
        x += w + 1;
      }
      g.rect(2, 13, 13, 13, 'd');
      for (final px in [3, 7, 11]) {
        g.rect(px, 14, px, 15, 'd');
      }
      for (final (bx, by) in [(18.0 + rng() * 3, 17.0), (26.0, 15.5)]) {
        g.ell(bx, by, 2.6, 1.0, 'd');
        g.rect(bx.floor(), (by - 5).floor(), bx.floor(), (by - 1).floor(), 'd');
        g.poly([
          (bx + 0.5, by - 5),
          (bx + 0.5, by - 1.2),
          (bx + 3, by - 1.2),
        ], 'b');
      }
      for (var k = 0; k < 10; k++) {
        final wx = (rng() * 32).floor(), wy = 18 + (rng() * 4).floor();
        if (g.at(wx, wy) == 'a') g.set(wx, wy, 'b');
      }
    },
  ),
  (
    'windmill',
    '밀밭 풍차',
    'Windmill in the Wheat',
    {'a': '#E7B53C', 'b': '#C98F22', 'c': '#F4EFE6', 'd': '#5B4636'},
    (g, t, rng) {
      g.each((x, y) => y > 11 + 1.5 * math.sin(x * 0.25 + rng() * 0), 'a');
      g.each((x, y) => y > 12 && ((x * 0.6 + y * 1.4).floor() % 3 == 0), 'b');
      g.poly([(20.5, 5.5), (26.5, 5.5), (27.5, 16), (19.5, 16)], 'c');
      g.ell(23.5, 5.5, 3.2, 1.6, 'd');
      g.rect(22, 13, 24, 15, 'd');
      final a0 = rng() * math.pi / 2;
      for (var k = 0; k < 4; k++) {
        final a = a0 + k * math.pi / 2;
        _line(
          g,
          23.5,
          6,
          23.5 + math.cos(a) * 7,
          6 + math.sin(a) * 7,
          1.4,
          'd',
        );
      }
      g.rect(0, 18, 15, 18, 'd');
      for (var px = 0; px <= 15; px += 3) {
        g.rect(px, 17, px, 19, 'd');
      }
    },
  ),
  (
    'river',
    '숲속 강',
    'Forest River',
    {'a': '#3F7D4E', 'b': '#1F5136', 'c': '#5AB0E0', 'd': '#7FB069'},
    (g, t, rng) {
      g.each((x, y) => y > 9, 'd');
      for (var k = 0; k < 9; k++) {
        g.ell(k * 4.0 + rng() * 2, 9.5, 2.6, 2.2 + rng(), 'a');
      }
      final ph = rng() * 6;
      g.each((x, y) {
        if (y < 10) return false;
        final c = 16 + 4 * math.sin(y * 0.45 + ph);
        final hw = 0.8 + (y - 10) * 0.55;
        return (x - c).abs() < hw;
      }, 'c');
      for (var k = 0; k < 8; k++) {
        final left = k.isEven;
        _pine(
          g,
          left ? 1.5 + k * 0.9 : 30 - k * 0.9,
          18 + (k % 3) * 1.6,
          6 + rng() * 3,
          'b',
        );
      }
    },
  ),
  (
    'canyon',
    '붉은 협곡',
    'Red Canyon',
    {'a': '#C2502E', 'b': '#E08A4F', 'c': '#EBC98A', 'd': '#7A2E1C'},
    (g, t, rng) {
      g.rect(0, 17, 31, 21, 'c');
      for (final (x0, x1, top) in [
        (0.0, 9.0, 6.0),
        (12.0, 20.0, 9.0),
        (23.0, 32.0, 5.0),
      ]) {
        g.each((x, y) => x >= x0 && x < x1 && y > top && y < 18, 'a');
        g.each(
          (x, y) =>
              x >= x0 &&
              x < x1 &&
              y > top &&
              y < 18 &&
              (y - top).floor() % 3 == 1,
          'b',
        );
        g.each((x, y) => x >= x1 - 1.6 && x < x1 && y > top && y < 18, 'd');
      }
      // 아치
      g.ell(16, 13, 2.6, 3.2, 's');
      g.each((x, y) => y > 13 && y < 17 && (x - 16).abs() < 2.4, 's');
      g.each((x, y) => y >= 17 && (x - 16).abs() < 2.4, 'c');
      for (var k = 0; k < 6; k++) {
        g.set((rng() * 32).floor(), 19 + (rng() * 3).floor(), 'd');
      }
    },
  ),
  (
    'palm',
    '열대 해변',
    'Tropical Beach',
    {'a': '#22A6B3', 'b': '#F2D7A1', 'c': '#2E9E57', 'd': '#8A5A33'},
    (g, t, rng) {
      g.rect(0, 11, 31, 21, 'a');
      g.each((x, y) => y > 15 + 2 * math.sin(x * 0.18), 'b');
      for (var k = 0; k < 8; k++) {
        g.set((rng() * 32).floor(), 12 + (rng() * 3).floor(), 'b');
      }
      for (final (px, lean) in [(6.0, 0.35), (25.0, -0.3)]) {
        for (var y = 18.0; y > 6; y -= 0.5) {
          final x = px + (18 - y) * lean * 0.5 + 0.4 * math.sin(y);
          g.ell(x, y, 0.75, 0.6, 'd');
        }
        final tx = px + 12 * lean * 0.5, ty = 6.0;
        for (var a = 0; a < 6; a++) {
          final ang = -math.pi + a * math.pi / 5;
          _line(
            g,
            tx,
            ty,
            tx + math.cos(ang) * 5,
            ty + math.sin(ang) * 2.4 + 1.6,
            1.3,
            'c',
          );
        }
      }
    },
  ),
  (
    'snowtown',
    '눈 내린 마을',
    'Snowy Village',
    {'a': '#EEF3F8', 'b': '#2D5F4A', 'c': '#B5643C', 'd': '#7A3B2E'},
    (g, t, rng) {
      g.each((x, y) => y > 13 + 1.6 * math.sin(x * 0.3), 'a');
      for (var k = 0; k < 6; k++) {
        _pine(g, 2 + k * 5.6 + rng(), 13.8, 5 + rng() * 3, 'b');
      }
      for (final hx in [4, 13, 22]) {
        _home(g, hx, 18, 5, 3, 'c', 'd', 'u');
        g.set(hx + 1, 17, 'u');
      }
      for (var k = 0; k < 18; k++) {
        final x = (rng() * 32).floor(), y = (rng() * 12).floor();
        if (g.at(x, y) == 's') g.set(x, y, 'a');
      }
    },
  ),
  (
    'volcano',
    '화산섬',
    'Volcano Island',
    {'a': '#5A4A42', 'b': '#F26B1D', 'c': '#2C7DB5', 'd': '#D9D4CF'},
    (g, t, rng) {
      g.rect(0, 16, 31, 21, 'c');
      g.poly([(3, 17), (13, 6), (19, 6), (29, 17)], 'a');
      g.ell(16, 6, 3, 1, 'b');
      for (var k = 0; k < 3; k++) {
        final x0 = 14.0 + k * 2;
        for (var y = 6.0; y < 16; y += 0.5) {
          g.ell(
            x0 + 0.8 * math.sin(y * 0.7 + k) + (y - 6) * (k - 1) * 0.35,
            y,
            0.55,
            0.5,
            'b',
          );
        }
      }
      for (var k = 0; k < 5; k++) {
        g.ell(15 + k * 1.6 + rng(), 4.5 - k * 0.9, 1.6 + k * 0.3, 1.0, 'd');
      }
      for (var k = 0; k < 8; k++) {
        g.set((rng() * 32).floor(), 18 + (rng() * 4).floor(), 'd');
      }
    },
  ),
  (
    'terrace',
    '계단식 논',
    'Rice Terraces',
    {'a': '#7CC05A', 'b': '#4E9A3F', 'c': '#9ED3E8', 'd': '#3B6B3A'},
    (g, t, rng) {
      final ph = rng() * 3;
      g.each((x, y) => y > 6 + 3 * math.sin(x * 0.12 + ph), 'd');
      g.each((x, y) {
        final top = 8 + 3 * math.sin(x * 0.12 + ph);
        return y > top;
      }, 'a');
      g.each((x, y) {
        final top = 8 + 3 * math.sin(x * 0.12 + ph);
        if (y <= top) return false;
        final band = ((y - top - 0.6 * math.sin(x * 0.4)) / 2.4).floor();
        return band.isOdd;
      }, 'b');
      g.each((x, y) {
        final top = 8 + 3 * math.sin(x * 0.12 + ph);
        if (y <= top) return false;
        final f = (y - top - 0.6 * math.sin(x * 0.4)) / 2.4;
        return f - f.floor() < 0.2 && (x * 3).floor() % 4 != 0;
      }, 'c');
    },
  ),
  (
    'castle',
    '언덕 위 성',
    'Hilltop Castle',
    {'a': '#5E9E4F', 'b': '#D8D2C4', 'c': '#3F5FB0', 'd': '#4B4038'},
    (g, t, rng) {
      g.each((x, y) => y > 14 - 4 * math.exp(-math.pow((x - 16) / 9, 2)), 'a');
      g.rect(9, 7, 22, 12, 'b');
      for (var x = 9; x <= 22; x += 2) {
        g.set(x, 6, 'b');
      }
      for (final (tx, top) in [(7, 3), (15, 1), (23, 3)]) {
        g.rect(tx, top + 2, tx + 2, 12, 'b');
        g.poly([
          (tx - 0.6, top + 2.0),
          (tx + 1.5, top - 1.5),
          (tx + 3.6, top + 2.0),
        ], 'c');
        g.set(tx + 1, top + 4, 'd');
      }
      g.ell(16, 11.5, 1.5, 2, 'd');
      g.rect(15, 11, 17, 12, 'd');
      _line(g, 16.5, -0.5, 16.5, 1.2, 0.8, 'd');
      g.rect(17, -1, 19, 0, 'c');
      for (var k = 0; k < 10; k++) {
        _pine(g, (rng() * 32), 18 + rng() * 4, 2.5 + rng() * 1.5, 'd');
      }
    },
  ),
  (
    'city',
    '강가의 도시',
    'Riverside City',
    {'a': '#4A5A78', 'b': '#6E7F9E', 'c': '#3F7FB0', 'd': '#2B3448'},
    (g, t, rng) {
      var x = 0;
      var k = 0;
      while (x < 32) {
        final w = 2 + (rng() * 3).floor(), h = 5 + (rng() * 9).floor();
        final ch = k.isEven ? 'a' : 'b';
        g.rect(x, 15 - h, x + w - 1, 15, ch);
        for (var wy = 16 - h; wy < 15; wy += 2) {
          for (var wx = x; wx < x + w; wx += 2) {
            if (rng() < 0.55) g.set(wx, wy, 'u');
          }
        }
        x += w;
        k++;
      }
      g.rect(0, 16, 31, 21, 'c');
      g.rect(0, 16, 31, 16, 'd');
      g.each(
        (x, y) =>
            y > 16 &&
            y < 21 &&
            (y.floor() % 2 == 0) &&
            g.at(x.floor(), (32 - y).floor()) != 's' &&
            rng() < 0.45,
        'b',
      );
    },
  ),
  (
    'bridge',
    '돌다리',
    'Stone Bridge',
    {'a': '#6DAA55', 'b': '#B9A68E', 'c': '#4C9BD6', 'd': '#6B5A48'},
    (g, t, rng) {
      g.each((x, y) => y > 10 + 0.08 * math.pow(x - 16, 2) * 0.3, 'a');
      g.each((x, y) => y > 13 && (x - 16).abs() < 6 + (y - 13) * 1.2, 'c');
      g.rect(2, 10, 29, 12, 'b');
      for (final cx in [9.0, 16.0, 23.0]) {
        g.ell(cx, 15, 2.6, 3.4, 'c');
      }
      g.each(
        (x, y) =>
            y > 12 &&
            y < 15 &&
            ((x - 9).abs() < 4.6 ||
                (x - 23).abs() < 4.6 ||
                (x - 16).abs() < 4.6) &&
            g.at(x.floor(), y.floor()) == 'a',
        'b',
      );
      for (var x = 2; x <= 29; x += 3) {
        g.set(x, 9, 'd');
      }
      g.rect(2, 10, 29, 10, 'd');
      for (var k = 0; k < 7; k++) {
        _pine(
          g,
          k < 4 ? 1.5 + k * 1.6 : 25.0 + k,
          19 + rng() * 2,
          3 + rng() * 2,
          'd',
        );
      }
    },
  ),
  (
    'falls',
    '절벽 폭포',
    'Cliff Waterfall',
    {'a': '#6C6A72', 'b': '#EAF6FF', 'c': '#3D8FD1', 'd': '#2F6E3E'},
    (g, t, rng) {
      g.each(
        (x, y) => y > 4 + 2 * math.sin(x * 0.4) && (x < 13 || x > 19),
        'a',
      );
      g.each((x, y) => y > 6 && x >= 13 && x <= 19, 'a');
      g.each((x, y) => y > 3 && y < 17 && (x - 16).abs() < 2.3, 'b');
      g.each(
        (x, y) =>
            y > 4 &&
            y < 17 &&
            (x - 16).abs() < 2.3 &&
            ((y * 2 + x).floor() % 5 == 0),
        'c',
      );
      g.ell(16, 18.5, 9, 3, 'c');
      g.ell(16, 16.8, 4, 1.2, 'b');
      for (var k = 0; k < 9; k++) {
        final x = k < 5 ? 1 + k * 2.4 : 22 + (k - 5) * 2.4;
        _pine(g, x, 21.5, 4 + rng() * 3, 'd');
      }
      for (var k = 0; k < 6; k++) {
        g.ell(2 + rng() * 9, 3 + rng() * 5, 1.4, 1.1, 'd');
        g.ell(21 + rng() * 9, 3 + rng() * 5, 1.4, 1.1, 'd');
      }
    },
  ),
  (
    'lavender',
    '라벤더 들판',
    'Lavender Fields',
    {'a': '#8E6CC8', 'b': '#5E8F4C', 'c': '#F1E6D2', 'd': '#B5543A'},
    (g, t, rng) {
      g.each((x, y) => y > 10, 'b');
      // 원근: 아래로 갈수록 넓어지는 보라 줄
      g.each((x, y) {
        if (y <= 10.5) return false;
        final d = (x - 16) / ((y - 9.5) * 0.9);
        return (d * 2).round().isEven && (d * 2 - (d * 2).round()).abs() < 0.32;
      }, 'a');
      _home(g, 22, 10, 5, 3, 'c', 'd', 'b');
      for (var k = 0; k < 5; k++) {
        g.ell(3 + k * 3.5, 9.8, 1.8, 1.2, 'b');
      }
    },
  ),
  (
    'lighthouse',
    '파도 치는 등대',
    'Lighthouse in the Waves',
    {'a': '#5B5246', 'b': '#F7F4EE', 'c': '#D23B3B', 'd': '#2766A6'},
    (g, t, rng) {
      g.rect(0, 14, 31, 21, 'd');
      g.poly([(0, 21), (0, 10), (8, 9), (14, 13), (16, 21)], 'a');
      g.poly([(8.6, 9.5), (9.6, 1.5), (12.4, 1.5), (13.4, 9.5)], 'b');
      for (final y in [3, 6]) {
        g.each(
          (x, yy) =>
              yy >= y && yy < y + 1.6 && g.at(x.floor(), yy.floor()) == 'b',
          'c',
        );
      }
      g.rect(10, 0, 12, 1, 'c');
      g.set(11, 1, 'u');
      _line(g, 12.5, 1, 22, -1.5, 1.4, 'u');
      for (var k = 0; k < 16; k++) {
        final x = 16 + (rng() * 16), y = 14 + rng() * 7;
        g.ell(x, y, 1.2, 0.5, 'b');
      }
    },
  ),
  (
    'onsen',
    '산속 온천',
    'Mountain Hot Spring',
    {'a': '#7A8C9E', 'b': '#F5F7FA', 'c': '#6FC3D9', 'd': '#5A5450'},
    (g, t, rng) {
      g.poly([(-1, 13), (8, 3), (15, 9), (22, 2), (33, 13)], 'a');
      g.each(
        (x, y) =>
            y > 4 &&
            y < 6.5 &&
            g.at(x.floor(), y.floor()) == 'a' &&
            y < 4 + (x - 22).abs() * 0.0 + 2.5,
        'b',
      );
      g.rect(0, 13, 31, 21, 'd');
      g.ell(16, 17, 11, 3.6, 'c');
      for (var k = 0; k < 14; k++) {
        final a = k / 14 * 2 * math.pi;
        g.ell(16 + math.cos(a) * 11.5, 17 + math.sin(a) * 3.9, 1.3, 0.9, 'd');
      }
      for (var k = 0; k < 4; k++) {
        final x0 = 9.0 + k * 4.5;
        for (var y = 15.0; y > 8; y -= 0.8) {
          g.ell(x0 + math.sin(y * 1.3 + k) * 0.9, y, 0.6, 0.45, 'b');
        }
      }
    },
  ),
];

List<ArtSource> _vistas() {
  final out = <ArtSource>[];
  final rng = mulberry32(7001);
  for (final (id, ko, en, pal, draw) in _scenes()) {
    for (final t in _times) {
      final g = _sky(32, 22, t, 4 + rng() * 24, 3.2, 2.2);
      draw(g, t, rng);
      _round(g, 2.5);
      out.add(
        makeArt('h_vista_${id}_${t.id}', '${t.ko} $ko', '$en at ${t.en}', {
          's': t.sky,
          'u': t.sun,
          for (final e in pal.entries) e.key: t.tint(e.value),
        }, g),
      );
    }
  }
  return out;
}

// ───────── 만다라 (31×31) ─────────

const _themes = [
  ('봄빛', 'Spring', ['#2F855A', '#F6E05E', '#ED64A6', '#FBD38D', '#FFFFFF']),
  ('바다', 'Ocean', ['#1A365D', '#4299E1', '#90CDF4', '#F6E05E', '#FFFFFF']),
  ('노을', 'Sunset', ['#742A2A', '#F56565', '#F6AD55', '#FEFCBF', '#553C9A']),
  ('보랏빛', 'Amethyst', ['#44337A', '#9F7AEA', '#E9D8FD', '#F6E05E', '#ED64A6']),
  ('숲', 'Forest', ['#1C4532', '#48BB78', '#C6F6D5', '#D69E2E', '#9C4221']),
  ('사탕', 'Candy', ['#97266D', '#F687B3', '#FED7E2', '#81E6D9', '#FAF089']),
  ('황금', 'Golden', ['#5F370E', '#D69E2E', '#FAF089', '#C53030', '#FFFFFF']),
  ('얼음', 'Frost', ['#2A4365', '#63B3ED', '#EBF8FF', '#B794F4', '#FFFFFF']),
];

const _motifs = [
  ('꽃 만다라', 'Flower Mandala'),
  ('별 만다라', 'Star Mandala'),
  ('물결 만다라', 'Wave Mandala'),
  ('연꽃 만다라', 'Lotus Mandala'),
  ('눈꽃 만다라', 'Snowflake Mandala'),
];

List<ArtSource> _mandalas() {
  final out = <ArtSource>[];
  final rng = mulberry32(7101);
  for (var ti = 0; ti < _themes.length; ti++) {
    final (tk, te, cols) = _themes[ti];
    for (var m = 0; m < _motifs.length; m++) {
      final g = Grid(31, 31);
      const c = 15.5;
      final k = [6, 8, 10, 12, 8][m] + (ti.isOdd && m != 4 ? 2 : 0);
      final r1 = 4.0 + rng() * 1.5, r2 = 9.0 + rng() * 1.5;
      final ph = rng() * math.pi;
      double r(double x, double y) =>
          math.sqrt(math.pow(x - c, 2) + math.pow(y - c, 2));
      double a(double x, double y) => math.atan2(y - c, x - c) + ph;
      g.each((x, y) => r(x, y) <= 15.4, 'a');
      // 바깥 꽃잎
      g.each((x, y) {
        final rr = r(x, y), aa = a(x, y);
        final petal = switch (m) {
          1 => r2 + 5.5 * math.pow((math.cos(k * aa / 2)).abs(), 6),
          2 => r2 + 3.8 + 1.6 * math.sin(k * aa),
          4 => r2 + 5 * math.pow((math.cos(k * aa / 2)).abs(), 12),
          _ => r2 + 5 * math.pow((math.cos(k * aa / 2)).abs(), 1.5),
        };
        return rr > r1 && rr < petal;
      }, 'b');
      // 안쪽 꽃잎 (반 칸 어긋나게)
      g.each((x, y) {
        final rr = r(x, y), aa = a(x, y) + math.pi / k;
        final petal =
            r1 +
            (r2 - r1) *
                (m == 3 ? 1.1 : 0.9) *
                math.pow((math.cos(k * aa / 2)).abs(), m == 3 ? 0.8 : 2.5);
        return rr > r1 * 0.6 && rr < petal;
      }, 'c');
      // 고리
      g.each((x, y) => (r(x, y) - r2).abs() < 0.55, 'd');
      g.each((x, y) => (r(x, y) - 15.0).abs() < 0.5, 'd');
      // 점
      for (var i = 0; i < k * 2; i++) {
        final aa = i * math.pi / k - ph;
        g.ell(
          c + math.cos(aa) * (r2 + 2.3),
          c + math.sin(aa) * (r2 + 2.3),
          0.7,
          0.7,
          i.isEven ? 'e' : 'd',
        );
      }
      g.ell(c, c, r1 * 0.55, r1 * 0.55, 'e');
      g.ell(c, c, 1.0, 1.0, 'd');
      final (mk, me) = _motifs[m];
      out.add(
        makeArt('h_mandala_${ti * 5 + m + 1}', '$tk $mk', '$te $me', {
          'a': cols[0],
          'b': cols[1],
          'c': cols[2],
          'd': cols[3],
          'e': cols[4],
        }, g),
      );
    }
  }
  return out;
}

// ───────── 퀼트 (30×24) ─────────

List<ArtSource> _quilts() {
  final out = <ArtSource>[];
  final rng = mulberry32(7201);
  const layouts = [
    ('바람개비 퀼트', 'Pinwheel Quilt'),
    ('별 퀼트', 'Star Quilt'),
    ('통나무집 퀼트', 'Log Cabin Quilt'),
    ('다이아몬드 퀼트', 'Diamond Quilt'),
    ('조각보', 'Patchwork Wrap'),
  ];
  for (var ti = 0; ti < 6; ti++) {
    final (tk, te, cols) = _themes[ti];
    for (var li = 0; li < layouts.length; li++) {
      final g = Grid(30, 24)..rect(0, 0, 29, 23, 'a');
      for (var by = 0; by < 4; by++) {
        for (var bx = 0; bx < 5; bx++) {
          final x0 = bx * 6, y0 = by * 6;
          final kind = li == 4 ? (rng() * 4).floor() : li;
          final c1 = ['b', 'c', 'd', 'e'][(bx + by + li) % 4];
          final c2 = ['c', 'd', 'e', 'b'][(bx * 2 + by + li) % 4];
          for (var y = 0; y < 6; y++) {
            for (var x = 0; x < 6; x++) {
              final u = x - 2.5, v = y - 2.5;
              String? ch;
              switch (kind) {
                case 0: // 바람개비: 사분면마다 삼각형
                  final q = (u < 0 ? 0 : 1) + (v < 0 ? 0 : 2);
                  final upper = q == 0
                      ? x > y
                      : q == 1
                      ? (5 - x) < y
                      : q == 2
                      ? (5 - x) > y
                      : x < y;
                  ch = upper ? c1 : c2;
                case 1: // 별
                  ch = u.abs() + v.abs() < 2.2
                      ? c1
                      : (u.abs() < 0.6 || v.abs() < 0.6)
                      ? c2
                      : null;
                case 2: // 통나무집: 동심 사각형
                  final ring = math.max(u.abs(), v.abs()).floor();
                  ch = ring == 0
                      ? 'e'
                      : ring.isOdd
                      ? c1
                      : c2;
                default: // 다이아몬드
                  ch = (u.abs() + v.abs()) < 3
                      ? ((u.abs() + v.abs()) < 1.5 ? c2 : c1)
                      : null;
              }
              if (ch != null) g.set(x0 + x, y0 + y, ch);
            }
          }
        }
      }
      // 바느질 땀 (테두리)
      for (var x = 0; x < 30; x += 2) {
        g.set(x, 0, 'f');
        g.set(x, 23, 'f');
      }
      for (var y = 0; y < 24; y += 2) {
        g.set(0, y, 'f');
        g.set(29, y, 'f');
      }
      final (lk, le) = layouts[li];
      out.add(
        makeArt('h_quilt_${ti * 5 + li + 1}', '$tk $lk', '$te $le', {
          'a': cols[4],
          'b': cols[0],
          'c': cols[1],
          'd': cols[2],
          'e': cols[3],
          'f': _mix(cols[0], '#000000', 0.3),
        }, g),
      );
    }
  }
  return out;
}

// ───────── 스테인드글라스 (24×32) ─────────

List<ArtSource> _glass() {
  final out = <ArtSource>[];
  const motifs = [
    ('해님 창', 'Sun Window'),
    ('나무 창', 'Tree Window'),
    ('새 창', 'Bird Window'),
    ('장미 창', 'Rose Window'),
    ('별빛 창', 'Starlight Window'),
    ('물결 창', 'Wave Window'),
  ];
  const themes = [
    ('푸른', 'Blue', ['#1E40AF', '#60A5FA', '#FBBF24', '#16A34A']),
    ('붉은', 'Ruby', ['#9B1C1C', '#F87171', '#FBBF24', '#6D28D9']),
    ('초록', 'Emerald', ['#065F46', '#34D399', '#FDE68A', '#2563EB']),
    ('호박빛', 'Amber', ['#92400E', '#F59E0B', '#FEF3C7', '#B91C1C']),
    ('자줏빛', 'Violet', ['#5B21B6', '#A78BFA', '#FDE68A', '#DB2777']),
  ];
  for (var m = 0; m < motifs.length; m++) {
    for (var t = 0; t < themes.length; t++) {
      final rng = mulberry32(7300 + m * 10 + t);
      final g = Grid(24, 32);
      bool inside(double x, double y) =>
          (y >= 12 && x > 0 && x < 24) ||
          math.pow(x - 12, 2) + math.pow(y - 12, 2) <= 144;
      // 보로노이 조각 + 납선
      final seeds = [
        for (var i = 0; i < 26; i++)
          (rng() * 24, rng() * 32, (rng() * 3).floor()),
      ];
      int near(double x, double y) {
        var best = 0;
        var bd = 1e9;
        for (var i = 0; i < seeds.length; i++) {
          final d = math.pow(x - seeds[i].$1, 2) + math.pow(y - seeds[i].$2, 2);
          if (d < bd) {
            bd = d.toDouble();
            best = i;
          }
        }
        return best;
      }

      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 24; x++) {
          if (!inside(x + 0.5, y + 0.5)) continue;
          final i = near(x + 0.5, y + 0.5);
          final edge =
              near(x + 1.5, y + 0.5) != i || near(x + 0.5, y + 1.5) != i;
          g.set(x, y, edge ? 'a' : ['b', 'c', 'e'][seeds[i].$3]);
        }
      }
      // 무늬
      switch (m) {
        case 0:
          g.ell(12, 13, 4.5, 4.5, 'd');
          for (var k = 0; k < 12; k++) {
            final a = k * math.pi / 6;
            _line(
              g,
              12 + math.cos(a) * 5.5,
              13 + math.sin(a) * 5.5,
              12 + math.cos(a) * 9,
              13 + math.sin(a) * 9,
              1.2,
              'd',
            );
          }
        case 1:
          g.rect(11, 16, 12, 29, 'a');
          g.ell(12, 11, 7, 6, 'e');
          for (var k = 0; k < 9; k++) {
            g.ell(7 + rng() * 10, 7 + rng() * 9, 0.9, 0.9, 'd');
          }
        case 2:
          g.ell(12, 16, 5, 3, 'd');
          g.ell(16.5, 13, 2.2, 2, 'd');
          g.poly([(18.4, 12.6), (21, 13.4), (18.4, 14)], 'a');
          g.poly([(9, 15), (3, 9), (12, 14)], 'e');
          g.poly([(7.5, 17), (2, 20), (8.5, 18.5)], 'd');
          g.set(17, 12, 'a');
        case 3:
          for (var k = 0; k < 8; k++) {
            final a = k * math.pi / 4;
            g.ell(
              12 + math.cos(a) * 3.4,
              14 + math.sin(a) * 3.4,
              2.2,
              2.2,
              'e',
            );
          }
          g.ell(12, 14, 2.4, 2.4, 'd');
          g.rect(11, 20, 12, 29, 'a');
          g.ell(9, 24, 2.2, 1.2, 'b');
        case 4:
          for (final (sx, sy, sr) in [
            (12.0, 9.0, 4.0),
            (6.0, 20.0, 2.6),
            (18.0, 22.0, 3.0),
            (11.0, 27.0, 2.0),
          ]) {
            g.each((x, y) {
              final a = math.atan2(y - sy, x - sx);
              final rr =
                  sr * (0.45 + 0.55 * math.pow((math.cos(2.5 * a)).abs(), 3));
              return math.pow(x - sx, 2) + math.pow(y - sy, 2) <= rr * rr;
            }, 'd');
          }
        default:
          for (var k = 0; k < 4; k++) {
            g.each(
              (x, y) =>
                  inside(x, y) &&
                  (y - (17 + k * 3.6 + 1.3 * math.sin(x * 0.7 + k))).abs() <
                      0.8,
              k.isEven ? 'd' : 'e',
            );
          }
      }
      // 테두리 납선
      g.each(
        (x, y) =>
            inside(x, y) &&
            !(inside(x - 1, y) &&
                inside(x + 1, y) &&
                inside(x, y - 1) &&
                inside(x, y + 1)),
        'a',
      );
      final (mk, me) = motifs[m];
      final (tk, te, cols) = themes[t];
      out.add(
        makeArt('h_glass_${m * 5 + t + 1}', '$tk $mk', '$te $me', {
          'a': '#2D2A26',
          'b': cols[0],
          'c': cols[1],
          'd': cols[2],
          'e': cols[3],
        }, g),
      );
    }
  }
  return out;
}

// ───────── 초상화 (26×30) ─────────

const _faces = [
  ('하람', 'Haram'),
  ('소이', 'Soi'),
  ('겨울', 'Gyeoul'),
  ('도담', 'Dodam'),
  ('라온', 'Raon'),
  ('미르', 'Mir'),
  ('바다', 'Bada'),
  ('새별', 'Saebyeol'),
  ('아라', 'Ara'),
  ('온유', 'Onyu'),
  ('유채', 'Yuchae'),
  ('은하', 'Eunha'),
  ('이든', 'Eden'),
  ('제이', 'Jay'),
  ('채운', 'Chaeun'),
  ('하율', 'Hayul'),
  ('가온', 'Gaon'),
  ('나래', 'Narae'),
  ('단비', 'Danbi'),
  ('루다', 'Ruda'),
  ('마음', 'Maeum'),
  ('별이', 'Byeori'),
  ('서리', 'Seori'),
  ('시아', 'Sia'),
  ('아토', 'Ato'),
  ('예준', 'Yejun'),
  ('우주', 'Uju'),
  ('윤아', 'Yuna'),
  ('지호', 'Jiho'),
  ('찬솔', 'Chansol'),
  ('태양', 'Taeyang'),
  ('푸름', 'Pureum'),
  ('하랑', 'Harang'),
  ('해솔', 'Haesol'),
  ('호수', 'Hosu'),
  ('가을', 'Gaeul'),
  ('노을', 'Noeul'),
  ('다온', 'Daon'),
  ('로운', 'Roun'),
  ('봄결', 'Bomgyeol'),
];
const _hairs = [
  '#2D2A26',
  '#6B4423',
  '#E8C547',
  '#C0392B',
  '#F28CB1',
  '#4F7CF7',
  '#3BAF7E',
  '#8E4EC6',
  '#D9D9D9',
];
const _skins = ['#F7D2B6', '#E8B48F', '#C68642', '#8D5524', '#FAD7C0'];
const _bgs = ['#BEE3F8', '#FED7E2', '#C6F6D5', '#FEFCBF', '#E9D8FD', '#FBD38D'];
const _wears = [
  '#E5484D',
  '#3E9BDB',
  '#46A758',
  '#F5B301',
  '#8E4EC6',
  '#F76B15',
  '#30A4A0',
  '#5C677D',
];

List<ArtSource> _portraits() {
  final out = <ArtSource>[];
  final rng = mulberry32(7401);
  for (var i = 0; i < _faces.length; i++) {
    final g = Grid(26, 30)..rect(0, 0, 25, 29, 'a');
    final style = i % 5, extra = (i ~/ 5) % 8;
    // 옷 (어깨)
    g.ell(13, 31, 12, 7.5, 'd');
    g.poly([(10.5, 23.5), (13, 27), (15.5, 23.5)], 'c');
    // 뒷머리
    if (style == 1) g.ell(13, 15, 9.5, 11, 'b'); // 긴 머리
    if (style == 3) {
      g.ell(5, 13, 3, 3, 'b');
      g.ell(21, 13, 3, 3, 'b');
    }
    // 목·얼굴·귀
    g.rect(11, 20, 15, 24, 'c');
    g.ell(13, 13.5, 7.2, 8.3, 'c');
    g.ell(5.8, 14, 1.3, 1.8, 'c');
    g.ell(20.2, 14, 1.3, 1.8, 'c');
    // 앞머리
    switch (style) {
      case 0: // 짧은 머리
        g.each(
          (x, y) =>
              math.pow((x - 13) / 7.8, 2) + math.pow((y - 11) / 7.2, 2) <= 1 &&
              y < 9.5 + 0.6 * math.sin(x * 1.3),
          'b',
        );
      case 1: // 긴 생머리 + 가르마
        g.each(
          (x, y) =>
              math.pow((x - 13) / 7.8, 2) + math.pow((y - 11) / 7.4, 2) <= 1 &&
              y < 9 + (x - 13).abs() * 0.35,
          'b',
        );
      case 2: // 곱슬
        for (var k = 0; k < 11; k++) {
          final a = math.pi + k * math.pi / 10;
          g.ell(13 + math.cos(a) * 7.5, 11 + math.sin(a) * 6.5, 2.2, 2.2, 'b');
        }
      case 3: // 양갈래 + 앞머리
        g.each(
          (x, y) =>
              math.pow((x - 13) / 7.6, 2) + math.pow((y - 11) / 7, 2) <= 1 &&
              y < 8.5,
          'b',
        );
      default: // 올림 머리
        g.ell(13, 3.5, 3.6, 3, 'b');
        g.each(
          (x, y) =>
              math.pow((x - 13) / 7.6, 2) + math.pow((y - 11) / 7, 2) <= 1 &&
              y < 8,
          'b',
        );
    }
    // 얼굴
    for (final ex in [10.0, 16.0]) {
      g.ell(ex, 14, 1.1, 1.4, 'e');
      g.set(ex.floor(), 13, 'a');
    }
    g.ell(8.6, 17, 1.2, 0.7, 'f');
    g.ell(17.4, 17, 1.2, 0.7, 'f');
    g.each(
      (x, y) => y > 18.2 && y < 19.6 && (x - 13).abs() < 1.8 - (y - 18.2) * 0.6,
      'e',
    );
    // 소품
    switch (extra) {
      case 0: // 안경
        for (final ex in [10.0, 16.0]) {
          g.each(
            (x, y) =>
                ((math.pow(x - ex, 2) + math.pow(y - 14, 2)) - 5.3).abs() < 1.9,
            'e',
          );
        }
        g.rect(12, 13, 13, 13, 'e');
      case 1: // 꽃 머리핀
        g.ell(19, 7, 1.8, 1.8, 'f');
        g.set(19, 7, 'a');
      case 2: // 모자
        g.rect(3, 6, 22, 7, 'f');
        g.ell(13, 4.5, 6.5, 3.6, 'f');
      case 3: // 리본
        g.poly([(13, 4), (8, 1.5), (8, 6.5)], 'f');
        g.poly([(13, 4), (18, 1.5), (18, 6.5)], 'f');
      case 4: // 왕관
        g.poly([
          (7, 6),
          (7, 1),
          (10, 4),
          (13, 0),
          (16, 4),
          (19, 1),
          (19, 6),
        ], 'f');
      case 5: // 헤드폰
        g.each(
          (x, y) =>
              (math.sqrt(math.pow(x - 13, 2) + math.pow(y - 12, 2)) - 9).abs() <
                  0.8 &&
              y < 12,
          'e',
        );
        g.ell(4.6, 14, 1.8, 2.6, 'f');
        g.ell(21.4, 14, 1.8, 2.6, 'f');
      case 6: // 목도리
        g.rect(7, 22, 19, 24, 'f');
        g.rect(15, 24, 17, 28, 'f');
      default: // 별 귀걸이·주근깨
        g.set(5, 16, 'f');
        g.set(20, 16, 'f');
        for (final (fx, fy) in [(9, 16), (10, 17), (16, 17), (17, 16)]) {
          g.set(fx, fy, 'e');
        }
    }
    final (ko, en) = _faces[i];
    out.add(
      makeArt('h_portrait_${i + 1}', '$ko의 초상', 'Portrait of $en', {
        'a': _bgs[(rng() * _bgs.length).floor()],
        'b': _hairs[(rng() * _hairs.length).floor()],
        'c': _skins[(rng() * _skins.length).floor()],
        'd': _wears[(rng() * _wears.length).floor()],
        'e': '#3B2F2A',
        'f': [
          '#F687B3',
          '#E5484D',
          '#FF8FA3',
          '#ED64A6',
        ][(rng() * 4).floor()], // 볼터치 겸 소품
      }, g),
    );
  }
  return out;
}

// ───────── 큰 동물 (30×24) ─────────
// 'a' 하늘 'b' 땅 'c' 몸 'd' 몸 둘째 색 'e' 눈·코 'f' 포인트

typedef _Beast = (
  String id,
  String ko,
  String en,
  String c,
  String d,
  String f,
  void Function(Grid g) draw,
);

List<_Beast> _beastList() => [
  (
    'cat',
    '고양이',
    'Cat',
    '#F2A65A',
    '#FFF1DE',
    '#F687B3',
    (g) {
      g.ell(15, 17, 8, 5.5, 'c');
      g.ell(15, 10, 6, 5, 'c');
      g.poly([(9.5, 8), (10, 2.5), (13, 6)], 'c');
      g.poly([(20.5, 8), (20, 2.5), (17, 6)], 'c');
      g.poly([(10.5, 7), (10.8, 4), (12.3, 6)], 'f');
      g.poly([(19.5, 7), (19.2, 4), (17.7, 6)], 'f');
      g.ell(15, 12, 3, 2, 'd');
      g.ell(15, 18, 4, 3.5, 'd');
      for (final ex in [12.5, 17.5]) {
        g.ell(ex, 9.5, 0.9, 1.3, 'e');
      }
      g.set(15, 11, 'f');
      _line(g, 22, 19, 27, 12, 1.6, 'c');
    },
  ),
  (
    'fox',
    '여우',
    'Fox',
    '#E8742A',
    '#FFF6EA',
    '#2D2A26',
    (g) {
      g.ell(14, 17, 8, 5, 'c');
      g.poly([(8, 12), (15, 17), (22, 12), (15, 6)], 'c');
      g.poly([(9, 9), (9, 2), (13, 7)], 'c');
      g.poly([(21, 9), (21, 2), (17, 7)], 'c');
      g.poly([(10, 12), (15, 17.5), (20, 12)], 'd');
      g.set(15, 17, 'e');
      for (final ex in [12.5, 17.5]) {
        g.ell(ex, 11, 0.8, 1, 'e');
      }
      g.poly([(9.5, 6), (9.5, 3), (11.5, 5.8)], 'f');
      g.poly([(20.5, 6), (20.5, 3), (18.5, 5.8)], 'f');
      g.ell(25, 16, 3.6, 5.5, 'c');
      g.ell(26, 20, 2, 1.8, 'd');
    },
  ),
  (
    'owl',
    '부엉이',
    'Owl',
    '#8B5E3C',
    '#E9D3B0',
    '#F5B301',
    (g) {
      g.ell(15, 13, 8, 9, 'c');
      g.ell(15, 16, 5.2, 5.5, 'd');
      for (final ex in [11.5, 18.5]) {
        g.ell(ex, 10, 3, 3, 'd');
        g.ell(ex, 10, 1.6, 1.6, 'f');
        g.ell(ex, 10, 0.8, 0.8, 'e');
      }
      g.poly([(14, 12), (16, 12), (15, 14.5)], 'f');
      g.poly([(8, 5), (9, 1), (11.5, 5)], 'c');
      g.poly([(22, 5), (21, 1), (18.5, 5)], 'c');
      for (var k = 0; k < 4; k++) {
        g.ell(12.5 + k * 1.7, 18 + (k % 2), 0.6, 0.5, 'c');
      }
      g.rect(2, 21, 27, 22, 'e');
      for (final fx in [12, 14, 16, 18]) {
        g.set(fx, 21, 'f');
      }
    },
  ),
  (
    'panda',
    '판다',
    'Panda',
    '#F7F7F2',
    '#2D2A26',
    '#46A758',
    (g) {
      g.ell(15, 17, 8.5, 6, 'c');
      g.ell(15, 9.5, 6.5, 5.5, 'c');
      g.ell(9.5, 5, 2, 2, 'd');
      g.ell(20.5, 5, 2, 2, 'd');
      g.ell(12, 9.5, 1.6, 2, 'd');
      g.ell(18, 9.5, 1.6, 2, 'd');
      g.set(12, 9, 'c');
      g.set(18, 9, 'c');
      g.ell(15, 12, 1, 0.7, 'd');
      g.ell(9, 17, 2.5, 4, 'd');
      g.ell(21, 17, 2.5, 4, 'd');
      _line(g, 20, 13, 27, 4, 1.4, 'f');
      for (var k = 0; k < 3; k++) {
        g.ell(24.5 + k, 7 - k * 1.5, 1.5, 0.7, 'f');
      }
    },
  ),
  (
    'rabbit',
    '토끼',
    'Rabbit',
    '#F4EFEA',
    '#F9B8C7',
    '#F28CB1',
    (g) {
      g.ell(15, 18, 7, 4.5, 'c');
      g.ell(15, 12, 5, 4.5, 'c');
      g.ell(12.5, 4.5, 1.5, 4.5, 'c');
      g.ell(17.5, 4.5, 1.5, 4.5, 'c');
      g.ell(12.5, 4.5, 0.7, 3.4, 'd');
      g.ell(17.5, 4.5, 0.7, 3.4, 'd');
      g.ell(13, 11.5, 0.8, 1, 'e');
      g.ell(17, 11.5, 0.8, 1, 'e');
      g.set(15, 13, 'f');
      g.ell(11, 14, 1.2, 0.6, 'd');
      g.ell(19, 14, 1.2, 0.6, 'd');
      g.ell(22, 19, 1.6, 1.6, 'c');
      g.ell(6, 20, 2, 1.2, 'f');
      g.rect(6, 17, 6, 19, 'b');
    },
  ),
  (
    'penguin',
    '펭귄',
    'Penguin',
    '#2D3748',
    '#F7FAFC',
    '#F6AD55',
    (g) {
      g.ell(15, 13.5, 7, 9.5, 'c');
      g.ell(15, 15, 4.8, 7, 'd');
      g.ell(13, 8, 1.4, 1.4, 'd');
      g.ell(17, 8, 1.4, 1.4, 'd');
      g.set(13, 8, 'e');
      g.set(17, 8, 'e');
      g.poly([(13.8, 10), (16.2, 10), (15, 12)], 'f');
      g.ell(8, 15, 1.5, 5, 'c');
      g.ell(22, 15, 1.5, 5, 'c');
      g.ell(12.5, 22.5, 2, 0.8, 'f');
      g.ell(17.5, 22.5, 2, 0.8, 'f');
    },
  ),
  (
    'whale',
    '고래',
    'Whale',
    '#3B6FB6',
    '#BFD9F2',
    '#FFFFFF',
    (g) {
      g.ell(14, 14, 11, 6.5, 'c');
      g.each(
        (x, y) =>
            y > 14 &&
            math.pow((x - 14) / 11, 2) + math.pow((y - 14) / 6.5, 2) <= 1,
        'd',
      );
      for (var y = 15; y < 20; y += 2) {
        g.each(
          (x, yy) =>
              yy >= y && yy < y + 0.7 && g.at(x.floor(), yy.floor()) == 'd',
          'c',
        );
      }
      g.poly([(24, 13), (29, 8), (28, 13), (29, 18)], 'c');
      g.ell(8, 12, 0.9, 0.9, 'e');
      for (var k = 0; k < 5; k++) {
        g.ell(
          12 + (k - 2) * 1.2,
          5 - (k % 2) * 1.2 - (2 - (k - 2).abs()) * 0.6,
          0.8,
          0.8,
          'f',
        );
      }
    },
  ),
  (
    'turtle',
    '거북이',
    'Turtle',
    '#3F8F4F',
    '#C9A86A',
    '#7FC97F',
    (g) {
      g.ell(15, 14, 9, 6, 'c');
      for (final (hx, hy) in [
        (11.0, 12.0),
        (15.0, 11.0),
        (19.0, 12.0),
        (13.0, 15.5),
        (17.0, 15.5),
      ]) {
        g.ell(hx, hy, 1.8, 1.6, 'f');
      }
      g.each((x, y) => y > 17 && y < 19.5 && (x - 15).abs() < 9.5, 'd');
      g.ell(26, 15, 2.6, 2.2, 'f');
      g.set(27, 14, 'e');
      for (final lx in [9.0, 20.0]) {
        g.ell(lx, 20, 1.8, 1.4, 'f');
      }
    },
  ),
  (
    'frog',
    '개구리',
    'Frog',
    '#5DBB63',
    '#C7F0B7',
    '#E5484D',
    (g) {
      g.ell(15, 16, 9, 6, 'c');
      g.ell(10, 8.5, 3, 3, 'c');
      g.ell(20, 8.5, 3, 3, 'c');
      g.ell(10, 8.5, 1.8, 1.8, 'd');
      g.ell(20, 8.5, 1.8, 1.8, 'd');
      g.ell(10, 8.5, 0.9, 1.2, 'e');
      g.ell(20, 8.5, 0.9, 1.2, 'e');
      g.ell(15, 17.5, 5, 3, 'd');
      g.each(
        (x, y) =>
            (y - (12.5 + 0.08 * math.pow(x - 15, 2))).abs() < 0.5 &&
            (x - 15).abs() < 4,
        'e',
      );
      g.ell(9, 13.5, 1, 0.6, 'f');
      g.ell(21, 13.5, 1, 0.6, 'f');
      g.ell(5, 21, 3, 1.2, 'c');
      g.ell(25, 21, 3, 1.2, 'c');
    },
  ),
  (
    'bear',
    '곰',
    'Bear',
    '#8B5A2B',
    '#D9B38C',
    '#2D2A26',
    (g) {
      g.ell(15, 17, 9, 6, 'c');
      g.ell(15, 10, 6.5, 5.8, 'c');
      g.ell(9.5, 5, 2.2, 2.2, 'c');
      g.ell(20.5, 5, 2.2, 2.2, 'c');
      g.ell(9.5, 5, 1.1, 1.1, 'd');
      g.ell(20.5, 5, 1.1, 1.1, 'd');
      g.ell(15, 12.5, 2.8, 2.1, 'd');
      g.ell(15, 11.6, 1.1, 0.7, 'e');
      g.ell(12.3, 9, 0.8, 0.9, 'e');
      g.ell(17.7, 9, 0.8, 0.9, 'e');
      g.ell(15, 18.5, 4.5, 3.5, 'd');
    },
  ),
  (
    'lion',
    '사자',
    'Lion',
    '#E8B04A',
    '#B5651D',
    '#2D2A26',
    (g) {
      for (var k = 0; k < 14; k++) {
        final a = k * math.pi / 7;
        g.ell(15 + math.cos(a) * 7, 11 + math.sin(a) * 6.5, 2.6, 2.6, 'd');
      }
      g.ell(15, 11, 6, 5.6, 'c');
      g.ell(15, 20, 7, 3.5, 'c');
      g.ell(12.5, 9.5, 0.8, 1, 'e');
      g.ell(17.5, 9.5, 0.8, 1, 'e');
      g.poly([(13.8, 12), (16.2, 12), (15, 13.6)], 'f');
      g.each(
        (x, y) =>
            (y - (14.6 + 0.12 * math.pow(x - 15, 2))).abs() < 0.45 &&
            (x - 15).abs() < 2,
        'f',
      );
    },
  ),
  (
    'elephant',
    '코끼리',
    'Elephant',
    '#9AA5B1',
    '#C9D1D9',
    '#F687B3',
    (g) {
      g.ell(17, 13, 9, 7, 'c');
      g.ell(10, 10, 5, 5, 'c');
      g.ell(13.5, 9, 4, 5, 'd');
      g.ell(13.8, 9, 2.4, 3.4, 'f');
      _line(g, 7, 12, 5, 20, 2.2, 'c');
      _line(g, 5, 20, 3.5, 19, 1.6, 'c');
      g.ell(9, 8.5, 0.8, 0.9, 'e');
      for (final lx in [11.0, 15.0, 20.0, 24.0]) {
        g.rect(lx.floor() - 1, 18, lx.floor() + 1, 22, 'c');
      }
      _line(g, 26, 12, 28, 16, 0.8, 'c');
    },
  ),
];

List<ArtSource> _beasts() {
  final out = <ArtSource>[];
  const backs = [
    ('들판의', 'in the Meadow', '#BEE3F8', '#8BC34A'),
    ('밤의', 'at Night', '#2C3E70', '#3E5C3A'),
  ];
  for (final (id, ko, en, c, d, f, draw) in _beastList()) {
    for (var b = 0; b < backs.length; b++) {
      final (bk, be, sky, ground) = backs[b];
      final g = Grid(30, 24)..rect(0, 0, 29, 23, 'a');
      g.each((x, y) => y > 18.5 + math.sin(x * 0.4) * 0.6, 'b');
      if (b == 1) {
        g.ell(25, 4, 2.2, 2.2, 'f');
        g.ell(26, 3.4, 1.8, 1.8, 'a');
      } else {
        g.ell(4, 4, 2.4, 1.4, 'd');
        g.ell(6, 3.4, 2, 1.4, 'd');
      }
      draw(g);
      _round(g, 2.5);
      out.add(
        makeArt('h_beast_${id}_${b + 1}', '$bk $ko', '$en $be', {
          'a': sky,
          'b': ground,
          'c': c,
          'd': d,
          'e': '#2D2A26',
          'f': f,
        }, g),
      );
    }
  }
  return out;
}

// ───────── 정물 (28×24) ─────────

List<ArtSource> _stillLife() {
  final out = <ArtSource>[];
  const subjects = [
    ('꽃병', 'Vase of Flowers'),
    ('과일 바구니', 'Fruit Basket'),
    ('찻잔과 주전자', 'Teapot and Cups'),
    ('케이크 접시', 'Cake Stand'),
  ];
  const pals = [
    ('따뜻한', 'Warm', ['#F3E3C3', '#B07A4A', '#E5484D', '#F5B301', '#46A758']),
    ('시원한', 'Cool', ['#DCEBF5', '#5C677D', '#3E9BDB', '#8E4EC6', '#30A4A0']),
    ('봄날', 'Spring', ['#FDF2F8', '#9C6B4E', '#F687B3', '#F6E05E', '#68D391']),
    ('가을', 'Autumn', ['#FBE7C6', '#6B4423', '#C05621', '#D69E2E', '#2F855A']),
    ('밤', 'Evening', ['#2A2F4A', '#7B5E57', '#ED64A6', '#FAF089', '#81E6D9']),
  ];
  for (var s = 0; s < subjects.length; s++) {
    for (var p = 0; p < pals.length; p++) {
      final rng = mulberry32(7500 + s * 10 + p);
      final g = Grid(28, 24)..rect(0, 0, 27, 23, 'a');
      g.rect(0, 17, 27, 23, 'b');
      g.each((x, y) => y > 17 && ((x + y * 2).floor() % 6 == 0), 'a');
      switch (s) {
        case 0:
          g.poly([
            (11, 17),
            (10, 12),
            (12, 10),
            (16, 10),
            (18, 12),
            (17, 17),
          ], 'c');
          g.rect(12, 8, 15, 10, 'c');
          for (var k = 0; k < 7; k++) {
            final fx = 7 + rng() * 14, fy = 2 + rng() * 5;
            _line(g, 14, 9, fx, fy, 0.7, 'f');
            g.ell(fx, fy, 1.8, 1.8, k.isEven ? 'd' : 'e');
            g.set(fx.floor(), fy.floor(), 'e');
          }
        case 1:
          g.ell(14, 15, 9, 3, 'b');
          g.each(
            (x, y) => y > 13 && y < 18 && (x - 14).abs() < 9 - (y - 13) * 0.8,
            'e',
          );
          g.each(
            (x, y) =>
                y > 13 &&
                y < 18 &&
                (x - 14).abs() < 9 - (y - 13) * 0.8 &&
                ((x + y).floor() % 3 == 0),
            'b',
          );
          for (final (fx, fy, ch) in [
            (9.0, 11.0, 'c'),
            (13.5, 10.0, 'd'),
            (18.0, 11.0, 'c'),
            (11.5, 7.5, 'f'),
            (16.0, 7.0, 'd'),
          ]) {
            g.ell(fx, fy, 2.6, 2.4, ch);
            g.set(fx.floor(), (fy - 2.4).floor(), 'f');
          }
        case 2:
          g.ell(9, 12, 5, 4.5, 'c');
          g.rect(7, 6, 11, 7, 'c');
          g.ell(9, 5.5, 1, 0.8, 'd');
          _line(g, 14, 10, 17, 7, 1.4, 'c');
          g.each(
            (x, y) =>
                ((math.pow(x - 3.5, 2) + math.pow(y - 12, 2)) - 6).abs() <
                    2.2 &&
                x < 4.5,
            'c',
          );
          g.each((x, y) => y > 11 && y < 13 && (x - 9).abs() < 5, 'd');
          for (final cx in [19.0, 24.0]) {
            g.rect(cx.floor() - 2, 13, cx.floor() + 1, 16, 'e');
            g.ell(cx - 0.5, 16.8, 3.2, 0.8, 'f');
            g.rect(cx.floor() - 2, 13, cx.floor() + 1, 13, 'd');
          }
        default:
          g.ell(14, 16.5, 8, 1.2, 'c');
          g.rect(13, 13, 14, 16, 'c');
          g.ell(14, 12.5, 6, 1, 'c');
          g.rect(9, 7, 19, 12, 'e');
          g.rect(9, 9, 19, 9, 'd');
          g.ell(14, 7, 5, 1, 'f');
          for (final (bx, by) in [(10.0, 6.0), (14.0, 5.5), (18.0, 6.0)]) {
            g.ell(bx, by, 1, 1, 'd');
          }
          _line(g, 14, 2, 14, 5, 0.7, 'f');
          g.set(14, 1, 'd');
      }
      final (sk, se) = subjects[s];
      final (pk, pe, cols) = pals[p];
      out.add(
        makeArt('h_still_${s * 5 + p + 1}', '$pk $sk', '$pe $se', {
          'a': cols[0],
          'b': cols[1],
          'c': cols[2],
          'd': cols[3],
          'e': cols[4],
          'f': _mix(cols[4], '#1A202C', 0.35),
        }, g),
      );
    }
  }
  return out;
}

// ───────── 탈것 (32×20) ─────────

List<ArtSource> _vehicles() {
  final out = <ArtSource>[];
  const kinds = [
    ('범선', 'Tall Ship'),
    ('증기 기관차', 'Steam Train'),
    ('열기구 축제', 'Balloon Festival'),
    ('구름 위 비행기', 'Plane Above the Clouds'),
  ];
  for (var k = 0; k < kinds.length; k++) {
    for (final t in _times) {
      final rng = mulberry32(7600 + k * 7 + t.id.length);
      final g = _sky(32, 20, t, 25, 3.5, 2);
      switch (k) {
        case 0:
          g.rect(0, 14, 31, 19, 'a');
          g.poly([(5, 13), (26, 13), (23, 17), (8, 17)], 'b');
          for (final mx in [10, 16, 21]) {
            g.rect(mx, 2, mx, 13, 'b');
            g.poly([
              (mx - 3.5, 3.5),
              (mx + 3.5, 3.5),
              (mx + 4, 8),
              (mx - 4, 8),
            ], 'c');
            g.poly([
              (mx - 4, 8.8),
              (mx + 4, 8.8),
              (mx + 4.5, 12.4),
              (mx - 4.5, 12.4),
            ], 'c');
          }
          g.rect(16, 0, 18, 1, 'd');
          for (var i = 0; i < 12; i++) {
            g.set((rng() * 32).floor(), 16 + (rng() * 4).floor(), 'c');
          }
        case 1:
          g.rect(0, 16, 31, 19, 'a');
          g.rect(0, 15, 31, 15, 'b');
          g.rect(14, 8, 25, 13, 'd');
          g.rect(22, 4, 27, 13, 'd');
          g.rect(16, 4, 17, 8, 'b');
          g.rect(23, 5, 26, 7, 'c');
          g.rect(1, 9, 12, 13, 'c');
          g.rect(3, 10, 4, 11, 'u');
          g.rect(8, 10, 9, 11, 'u');
          for (final wx in [3.5, 9.5, 16.5, 20.5, 25.0]) {
            g.ell(wx, 14.3, 1.7, 1.7, 'b');
          }
          for (var i = 0; i < 5; i++) {
            g.ell(16.5 - i * 2.4, 2.5 - i * 0.4, 1.4 + i * 0.25, 1.1, 'c');
          }
        case 2:
          g.each((x, y) => y > 16 + math.sin(x * 0.3), 'a');
          for (final (bx, by, r, ch) in [
            (7.0, 6.0, 4.0, 'b'),
            (18.0, 4.5, 3.2, 'c'),
            (26.0, 9.0, 2.6, 'd'),
            (13.0, 11.5, 2.2, 'd'),
          ]) {
            g.ell(bx, by, r, r * 1.1, ch);
            g.each(
              (x, y) =>
                  (x - bx).abs() < r * 0.3 &&
                  math.pow((x - bx) / r, 2) +
                          math.pow((y - by) / (r * 1.1), 2) <=
                      1,
              ch == 'b' ? 'c' : 'b',
            );
            g.rect(
              (bx - r * 0.25).floor(),
              (by + r * 1.3).floor(),
              (bx + r * 0.25).floor(),
              (by + r * 1.3 + 1).floor(),
              'b',
            );
          }
        default:
          for (var i = 0; i < 7; i++) {
            g.ell(rng() * 32, 14 + rng() * 5, 4 + rng() * 2, 2, 'a');
          }
          g.ell(15, 8, 9, 2, 'b');
          g.poly([(12, 8), (18, 8), (23, 14), (20, 14)], 'c');
          g.poly([(12, 8), (18, 8), (22, 3), (19.5, 3)], 'c');
          g.poly([(5, 8), (6.5, 3.5), (8.5, 3.5), (9, 7)], 'c');
          for (var i = 0; i < 5; i++) {
            g.set(13 + i * 2, 7, 'd');
          }
          g.ell(24, 8, 0.6, 1.8, 'd');
      }
      _round(g, 2.5);
      final (ko, en) = kinds[k];
      out.add(
        makeArt('h_ride_${k + 1}_${t.id}', '${t.ko} $ko', '$en at ${t.en}', {
          's': t.sky,
          'u': t.sun,
          'a': t.tint(['#2766A6', '#7A6A5A', '#6DAA55', '#FFFFFF'][k]),
          'b': t.tint(['#7A4B2A', '#2D2A26', '#E5484D', '#E8EEF4'][k]),
          'c': t.tint(['#F4EFE6', '#C0392B', '#F5B301', '#3E9BDB'][k]),
          'd': t.tint(['#C0392B', '#2F855A', '#8E4EC6', '#2D2A26'][k]),
        }, g),
      );
    }
  }
  return out;
}

// ───────── 정원 (30×22) ─────────

List<ArtSource> _gardens() {
  final out = <ArtSource>[];
  const names = [
    ('장미', 'Rose'),
    ('튤립', 'Tulip'),
    ('수국', 'Hydrangea'),
    ('해바라기', 'Sunflower'),
    ('라벤더', 'Lavender'),
    ('작약', 'Peony'),
    ('코스모스', 'Cosmos'),
    ('동백', 'Camellia'),
    ('데이지', 'Daisy'),
    ('양귀비', 'Poppy'),
  ];
  const kinds = [('정원', 'Garden'), ('분수 정원', 'Fountain Garden')];
  const flowers = [
    '#E5484D',
    '#F687B3',
    '#7F9CF5',
    '#F5B301',
    '#9F7AEA',
    '#ED64A6',
    '#FBB6CE',
    '#C53030',
    '#FFFFFF',
    '#F56565',
  ];
  for (var n = 0; n < names.length; n++) {
    for (var k = 0; k < kinds.length; k++) {
      final rng = mulberry32(7700 + n * 3 + k);
      final g = Grid(30, 22)..rect(0, 0, 29, 21, 'a');
      // 길
      g.each((x, y) => (x - 15).abs() < 1.6 || (y - 11).abs() < 1.2, 'b');
      if (k == 1) {
        g.ell(15, 11, 5, 4, 'b');
        g.ell(15, 11, 3.6, 2.8, 'e');
        g.ell(15, 11, 1.2, 1.0, 'b');
        g.rect(15, 6, 15, 10, 'e');
      }
      // 화단: 사분면마다 둥근 화단 + 꽃
      for (final (cx, cy) in [
        (7.0, 5.0),
        (23.0, 5.0),
        (7.0, 17.0),
        (23.0, 17.0),
      ]) {
        g.ell(cx, cy, 5.5, 3.5, 'c');
        for (var i = 0; i < 11; i++) {
          final a = rng() * 2 * math.pi, rr = math.sqrt(rng());
          final fx = cx + math.cos(a) * rr * 4.6,
              fy = cy + math.sin(a) * rr * 2.8;
          g.ell(fx, fy, 0.9, 0.9, 'd');
          if (rng() < 0.4) g.set(fx.floor(), fy.floor(), 'f');
        }
      }
      // 울타리 나무
      for (var x = 1.5; x < 30; x += 3) {
        if ((x - 15).abs() < 2.5) continue;
        g.ell(x, 0.8, 1.4, 1.2, 'c');
        g.ell(x, 21.2, 1.4, 1.2, 'c');
      }
      _round(g, 2);
      final (nk, ne) = names[n];
      final (kk, ke) = kinds[k];
      out.add(
        makeArt('h_garden_${n * 2 + k + 1}', '$nk $kk', '$ne $ke', {
          'a': '#8BC34A',
          'b': '#E8D9B5',
          'c': '#3F7D4E',
          'd': flowers[n],
          'e': '#5AB0E0',
          'f': '#FDE68A',
        }, g),
      );
    }
  }
  return out;
}

List<ArtSource> hiresArts() => [
  ..._vistas(),
  ..._mandalas(),
  ..._quilts(),
  ..._glass(),
  ..._portraits(),
  ..._beasts(),
  ..._stillLife(),
  ..._vehicles(),
  ..._gardens(),
];
