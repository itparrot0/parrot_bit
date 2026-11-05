// 더 복잡한 그림 100장 (2026-11-04): 큰 판(최대 22칸)에 요소가 많은 그림.
//  - 파노라마 풍경 40 (22×15): 장면 20가지 × 시간대 2
//  - 전신 캐릭터 30 (14×22)
//  - 큰 동물 10 (20×16)
//  - 실내 풍경 10 (20×17)
//  - 스테인드글라스 10 (15×21)
// 색은 여전히 6개 이하 (생성기 maxColors). 이름은 c_ 로 시작한다.
import 'dart:math' as math;

import 'package:bloom_wave/domain/generator.dart';

import 'art_gen.dart';
import 'art_source.dart';

class _T {
  const _T(this.ko, this.en, this.sky, this.sun, this.night, this.id);
  final String ko, en, sky, sun, id;
  final bool night;
}

const _tm = [
  _T('새벽', 'Dawn', '#F9C6D3', '#FFF4C2', false, 'dawn'),
  _T('한낮', 'Midday', '#8ECDF5', '#F5D90A', false, 'day'),
  _T('노을', 'Sunset', '#F59E61', '#FDE047', false, 'sunset'),
  _T('달밤', 'Moonlit', '#1E3A8A', '#FEF3C7', true, 'night'),
  _T('보랏빛 저녁', 'Violet Dusk', '#7C6FD6', '#FBD38D', false, 'dusk'),
];

/// 22×15 엽서. 하늘 's', 해/달 'u'
Grid _pano(_T t, double sunX, double sunY) {
  final g = Grid(22, 15)..rect(0, 0, 21, 14, 's');
  g.ell(sunX, sunY, 1.7, 1.7, 'u');
  if (t.night) {
    g.ell(sunX + 1.0, sunY - 0.6, 1.4, 1.4, 's');
    for (final (x, y) in const [
      (2, 1),
      (7, 2),
      (12, 1),
      (17, 3),
      (20, 1),
      (4, 4),
    ]) {
      if (g.at(x, y) == 's') g.set(x, y, 'u');
    }
  }
  return g;
}

void _corners(Grid g) {
  for (final (x, y) in [
    (0, 0),
    (g.w - 1, 0),
    (0, g.h - 1),
    (g.w - 1, g.h - 1),
  ]) {
    g.set(x, y, '.');
  }
}

void _hills(
  Grid g,
  double base,
  double amp,
  double freq,
  double ph,
  String ch,
) => g.each((x, y) => y > base + amp * math.sin(x * freq + ph), ch);

void _house(
  Grid g,
  int x,
  int base,
  int w,
  int h,
  String wall,
  String roof, {
  String? win,
}) {
  g.rect(x, base - h + 1, x + w - 1, base, wall);
  g.poly([
    (x - 0.8, base - h + 1.2),
    (x + w / 2, base - h - w / 2 + 0.6),
    (x + w + 0.8, base - h + 1.2),
  ], roof);
  if (win != null) g.set(x + w ~/ 2, base - 1, win);
}

void _pine(Grid g, double x, double base, double h, String ch) =>
    g.poly([(x - h * 0.42, base), (x, base - h), (x + h * 0.42, base)], ch);

void _tree(Grid g, double x, double y, double r, String crown, String trunk) {
  g.rect(x.floor(), y.floor(), x.floor(), (y + r + 1.4).floor(), trunk);
  g.ell(x + 0.5, y, r, r * 0.9, crown);
}

typedef _Recipe = (
  String id,
  String ko,
  String en,
  Map<String, String> Function(_T t) pal,
  void Function(Grid g, _T t, double Function() rng),
);

List<_Recipe> _recipes() => [
  (
    'river_village',
    '강변 마을',
    'Riverside Village',
    (t) => {
      'g': t.night ? '#2F5D3A' : '#46A758',
      'b': t.night ? '#25508A' : '#3E9BDB',
      'w': '#F3E3B5',
      'r': '#B4553B',
    },
    (g, t, rng) {
      _hills(g, 6.5, 1.2, 0.3, rng() * 6, 'g');
      g.each(
        (x, y) => y > 9 && (x - (11 + 4 * math.sin(y / 2.2))).abs() < 1.6,
        'b',
      );
      var x = 1;
      while (x < 20) {
        final w = 3 + (rng() * 2).floor();
        if ((x + w / 2 - 11).abs() > 4) {
          _house(g, x, 10 + (rng() * 2).floor(), w, 3, 'w', 'r', win: 'b');
        }
        x += w + 2;
      }
      for (var i = 0; i < 3; i++) {
        g.ell(2 + rng() * 18, 12.5, 1.4, 1.2, 'g');
      }
    },
  ),
  (
    'windmill_hill',
    '언덕 위 풍차',
    'Windmill on the Hill',
    (t) => {
      'g': t.night ? '#2F5D3A' : '#46A758',
      'l': t.night ? '#3E7D4F' : '#9BD27D',
      'w': '#F3F4F6',
      'd': '#6B4423',
    },
    (g, t, rng) {
      _hills(g, 8.5, 1.6, 0.25, rng() * 6, 'g');
      g.recolor('g', 'l', (x, y) => y % 2 == 0 && y > 10);
      final mx = 6 + (rng() * 10).floor();
      g.poly([
        (mx - 1.6, 9.5),
        (mx - 0.6, 3.5),
        (mx + 1.6, 3.5),
        (mx + 2.6, 9.5),
      ], 'w');
      g.rect(mx, 7, mx + 1, 9, 'd');
      for (final (dx, dy) in const [
        (1.0, 1.0),
        (-1.0, 1.0),
        (1.0, -1.0),
        (-1.0, -1.0),
      ]) {
        g.each(
          (x, y) =>
              ((x - mx - 0.5) * dy - (y - 3.5) * dx).abs() < 0.75 &&
              (x - mx - 0.5) * dx > 0 &&
              (y - 3.5) * dy > 0 &&
              (x - mx - 0.5).abs() < 4.4,
          'd',
        );
      }
      for (var x = 0; x < 22; x += 2) {
        g.rect(x, 12, x, 13, 'd');
      }
      g.rect(0, 12, 21, 12, 'd');
    },
  ),
  (
    'lake_camp',
    '호숫가 캠핑',
    'Lakeside Camp',
    (t) => {
      'm': t.night ? '#4C5A8C' : '#7D8BAA',
      'w': '#FFFFFF',
      'b': t.night ? '#25508A' : '#5DADE2',
      'g': t.night ? '#1F4D33' : '#2A7E3B',
      'r': '#E5484D',
    },
    (g, t, rng) {
      g.poly([(-2, 9), (5 + rng() * 3, 2.5), (13, 9)], 'm');
      g.poly([(8, 9), (15 + rng() * 3, 3.5), (24, 9)], 'm');
      g.recolor('m', 'w', (x, y) => y < 5);
      g.rect(0, 9, 21, 14, 'b');
      for (var x = 1.0; x < 22; x += 2.5 + rng() * 1.5) {
        if (x > 8 && x < 14) continue;
        _pine(g, x, 10.5, 3 + rng() * 2, 'g');
      }
      g.rect(0, 10, 21, 10, 'g');
      g.poly([(8.5, 13.6), (11, 10), (13.5, 13.6)], 'r');
      g.rect(0, 13, 7, 14, 'g');
      g.rect(14, 13, 21, 14, 'g');
    },
  ),
  (
    'harbor',
    '항구 마을',
    'Harbor Town',
    (t) => {
      'b': t.night ? '#1D4E89' : '#3E9BDB',
      'd': '#6B4423',
      'w': '#F3E3B5',
      'r': '#E5484D',
    },
    (g, t, rng) {
      g.rect(0, 9, 21, 14, 'b');
      var x = 0;
      while (x < 21) {
        final w = 2 + (rng() * 2).floor();
        _house(g, x, 8, w, 2 + (rng() * 3).floor(), 'w', 'r', win: 'd');
        x += w + 1;
      }
      g.rect(0, 9, 21, 9, 'd');
      g.rect(14, 10, 15, 13, 'd');
      for (final bx in [3 + (rng() * 3).floor(), 9 + (rng() * 2).floor()]) {
        g.poly([
          (bx - 0.5, 11),
          (bx + 4.5, 11),
          (bx + 3.5, 12.6),
          (bx + 0.5, 12.6),
        ], 'r');
        g.rect(bx + 2, 8, bx + 2, 10, 'd');
        g.poly([(bx + 2.6, 8), (bx + 2.6, 10.8), (bx + 4.4, 10.8)], 'w');
      }
    },
  ),
  (
    'oasis',
    '사막 오아시스',
    'Desert Oasis',
    (t) => {
      'y': t.night ? '#B08850' : '#F2C46D',
      'o': t.night ? '#8A6533' : '#D9963B',
      'g': '#2A9D5C',
      'b': '#3E9BDB',
      'd': '#8B5A2B',
    },
    (g, t, rng) {
      final ph = rng() * 5;
      _hills(g, 7.5, 1.4, 0.35, ph, 'o');
      _hills(g, 9.5, 1.0, 0.28, ph + 2, 'y');
      g.poly([(13, 8.5), (16.5, 3.5), (20, 8.5)], 'o');
      g.ell(9, 12, 4.8, 1.6, 'b');
      for (final px in [4.0, 13.5]) {
        g.poly([
          (px - 0.4, 12),
          (px + 0.4, 12),
          (px + 1.2, 6),
          (px + 0.6, 6),
        ], 'd');
        g.ell(px + 0.4, 5.8, 2.6, 0.9, 'g');
        g.ell(px + 2.2, 6.6, 1.6, 0.7, 'g');
      }
    },
  ),
  (
    'snow_cabin',
    '눈 숲 오두막',
    'Snowy Forest Cabin',
    (t) => {
      'w': '#FFFFFF',
      'g': t.night ? '#1F4D33' : '#2A7E3B',
      'd': '#6B4423',
      'r': '#B4553B',
    },
    (g, t, rng) {
      _hills(g, 9, 0.8, 0.3, rng() * 6, 'w');
      for (var x = 0.5; x < 22; x += 2.2 + rng()) {
        if (x > 8 && x < 15) continue;
        _pine(g, x, 10.5, 4 + rng() * 3, 'g');
        g.set(x.floor(), (10.5 - 4).floor(), 'w');
      }
      _house(g, 9, 11, 5, 3, 'd', 'w', win: 'u');
      g.rect(13, 4, 13, 6, 'r');
    },
  ),
  (
    'city_park',
    '도시 공원',
    'City Park',
    (t) => {
      'k': t.night ? '#2B2D42' : '#8D99AE',
      'g': t.night ? '#2F5D3A' : '#2A9D5C',
      'l': t.night ? '#3E7D4F' : '#9BD27D',
      'b': t.night ? '#25508A' : '#5DADE2',
    },
    (g, t, rng) {
      var x = 0;
      while (x < 22) {
        final w = 2 + (rng() * 3).floor();
        g.rect(x, 2 + (rng() * 4).floor(), x + w - 1, 8, 'k');
        x += w;
      }
      g.rect(0, 8, 21, 14, 'l');
      g.ell(14, 11.5, 4.5, 1.8, 'b');
      for (var i = 0; i < 4; i++) {
        g.ell(2 + i * 2.6 + rng(), 8.6 + rng(), 1.5, 1.3, 'g');
      }
      g.poly([(0, 14), (3, 9.5), (5, 9.5), (8, 14)], 'k');
    },
  ),
  (
    'canyon_bridge',
    '협곡 다리',
    'Canyon Bridge',
    (t) => {
      'm': t.night ? '#4A4E69' : '#B87A4B',
      'b': t.night ? '#25508A' : '#3E9BDB',
      'r': '#E5484D',
      'g': '#46A758',
    },
    (g, t, rng) {
      g.poly([(-1, 15), (-1, 5), (4, 4), (7, 6), (8, 15)], 'm');
      g.poly([(23, 15), (23, 4), (18, 5), (15, 6), (14, 15)], 'm');
      g.rect(8, 12, 13, 14, 'b');
      g.each((x, y) => y > 5.6 && y < 6.6 && x > 6 && x < 16, 'r');
      g.each(
        (x, y) =>
            (math.pow((x - 11) / 4.4, 2) + math.pow((y - 9.6) / 3.6, 2) - 1)
                    .abs() <
                0.28 &&
            y < 9.6,
        'r',
      );
      for (var x = 7; x <= 15; x += 2) {
        g.rect(x, 6, x, 7, 'r');
      }
      g.ell(2, 4, 2.4, 1, 'g');
      g.ell(19.5, 4, 2.6, 1, 'g');
    },
  ),
  (
    'tulip_farm',
    '튤립 농장',
    'Tulip Farm',
    (t) => {'r': '#E5484D', 'y': '#F5C518', 'p': '#F28CB1', 'd': '#6B4423'},
    (g, t, rng) {
      const rows = ['r', 'y', 'p'];
      for (var y = 8; y < 15; y++) {
        for (var x = 0; x < 22; x++) {
          g.set(x, y, (x + y) % 2 == 0 ? rows[(y ~/ 2) % 3] : 'd');
        }
      }
      final bx = 3 + (rng() * 12).floor();
      _house(g, bx, 7, 5, 3, 'r', 'd');
      g.rect(bx + 2, 6, bx + 2, 7, 'd');
    },
  ),
  (
    'cliff_lighthouse',
    '절벽 등대',
    'Cliff Lighthouse',
    (t) => {
      'g': t.night ? '#2F5D3A' : '#46A758',
      'b': t.night ? '#1D4E89' : '#3E9BDB',
      'w': '#FFFFFF',
      'r': '#E5484D',
    },
    (g, t, rng) {
      g.rect(0, 9, 21, 14, 'b');
      g.poly([(-1, 15), (-1, 7), (10, 7.5), (12, 15)], 'g');
      for (var y = 2; y <= 7; y++) {
        g.rect(4, y, 5, y, y.isEven ? 'r' : 'w');
      }
      g.rect(4, 1, 5, 1, 'u');
      for (final y in const [10, 12]) {
        for (var x = 13 + y % 3; x < 22; x += 4) {
          g.set(x, y, 'w');
        }
      }
    },
  ),
  (
    'autumn_road',
    '단풍길',
    'Autumn Road',
    (t) => {
      'o': '#F76B15',
      'y': '#F5C518',
      'd': '#8B5A2B',
      'g': t.night ? '#2F5D3A' : '#8BAA4F',
    },
    (g, t, rng) {
      g.rect(0, 8, 21, 14, 'g');
      g.poly([(9, 8), (13, 8), (19, 15), (3, 15)], 'd');
      for (var i = 0; i < 6; i++) {
        final left = i.isEven, k = i ~/ 2;
        final x = left ? 6.5 - k * 2.6 : 15.5 + k * 2.6, y = 6.5 + k * 1.8;
        _tree(g, x, y - 1.5, 1.6 + k * 0.4, i % 3 == 0 ? 'y' : 'o', 'd');
      }
    },
  ),
  (
    'rice_terrace',
    '계단식 논',
    'Rice Terraces',
    (t) => {
      'g': t.night ? '#2F5D3A' : '#46A758',
      'l': t.night ? '#3E7D4F' : '#9BD27D',
      'b': t.night ? '#25508A' : '#7FD1F5',
      'd': '#6B4423',
    },
    (g, t, rng) {
      final ph = rng() * 4;
      for (var k = 0; k < 5; k++) {
        final base = 5.0 + k * 2;
        g.each(
          (x, y) => y > base + 1.2 * math.sin(x / 4 + ph + k * 0.6),
          k.isEven ? 'g' : 'l',
        );
        g.each(
          (x, y) =>
              (y - (base + 1.2 * math.sin(x / 4 + ph + k * 0.6))).abs() < 0.5,
          'b',
        );
      }
      _house(g, 16, 5, 3, 2, 'd', 'd');
    },
  ),
  (
    'volcano_island',
    '화산섬',
    'Volcano Island',
    (t) => {
      'b': t.night ? '#1D4E89' : '#3E9BDB',
      'd': '#5B4636',
      'r': '#F76B15',
      'g': '#2A9D5C',
    },
    (g, t, rng) {
      g.rect(0, 10, 21, 14, 'b');
      final vx = 8 + rng() * 6;
      g.poly([(vx - 8, 11), (vx - 1.6, 3), (vx + 1.6, 3), (vx + 8, 11)], 'd');
      g.poly([
        (vx - 1.4, 3.2),
        (vx + 1.4, 3.2),
        (vx + 0.6, 7.5),
        (vx - 0.4, 6),
      ], 'r');
      g.rect(vx.floor() - 1, 1, vx.floor() + 1, 2, 'r');
      g.ell(vx - 4, 10, 2.4, 1.2, 'g');
      g.ell(vx + 5, 10, 2.6, 1.2, 'g');
    },
  ),
  (
    'hill_castle',
    '언덕 위 성',
    'Castle on the Hill',
    (t) => {
      'm': '#C9C1B4',
      'r': '#4F7CF7',
      'g': t.night ? '#2F5D3A' : '#46A758',
      'y': '#F5C518',
    },
    (g, t, rng) {
      _hills(g, 10, 1.0, 0.3, rng() * 6, 'g');
      final cx = 7 + (rng() * 6).floor();
      g.rect(cx, 5, cx + 7, 10, 'm');
      for (final tx in [cx - 1, cx + 7]) {
        g.rect(tx, 3, tx + 1, 10, 'm');
        g.poly([(tx - 0.6, 3.2), (tx + 1.0, 0.2), (tx + 2.6, 3.2)], 'r');
      }
      for (var x = cx + 1; x < cx + 7; x += 2) {
        g.set(x, 4, 'm');
      }
      g.ell(cx + 4, 9.5, 1.2, 1.6, 'r');
      g.rect(cx + 3, 0, cx + 3, 4, 'm');
      g.rect(cx + 4, 0, cx + 5, 1, 'y');
    },
  ),
  (
    'night_market',
    '야시장 골목',
    'Night Market Alley',
    (t) => {'k': '#3D405B', 'r': '#E5484D', 'y': '#F5C518', 'd': '#6B4423'},
    (g, t, rng) {
      g.rect(0, 3, 6, 14, 'k');
      g.rect(15, 2, 21, 14, 'k');
      g.poly([(6, 14), (8.5, 6), (12.5, 6), (15, 14)], 'd');
      g.each(
        (x, y) =>
            (y - (3.5 + 0.08 * math.pow(x - 11, 2))).abs() < 0.5 &&
            x > 5 &&
            x < 16,
        'd',
      );
      for (var x = 6; x <= 16; x += 2) {
        final y = (3.5 + 0.08 * math.pow(x - 11, 2)).round() + 1;
        g.set(x, y, x % 4 == 0 ? 'r' : 'y');
        g.set(x, y + 1, x % 4 == 0 ? 'r' : 'y');
      }
      for (final (x0, x1) in const [(1, 5), (16, 20)]) {
        for (var y = 5; y < 13; y += 3) {
          g.rect(x0, y, x0 + 1, y + 1, 'y');
          g.rect(x1 - 1, y, x1, y + 1, 'r');
        }
      }
    },
  ),
  (
    'jungle_falls',
    '정글 폭포',
    'Jungle Falls',
    (t) => {'g': '#1F6B3A', 'w': '#E8F6FF', 'b': '#3E9BDB', 'p': '#F28CB1'},
    (g, t, rng) {
      g.poly([(-1, 15), (-1, 3), (8, 4), (8.5, 15)], 'g');
      g.poly([(23, 15), (23, 2), (13, 4), (12.5, 15)], 'g');
      g.rect(9, 4, 12, 11, 'w');
      g.ell(10.5, 12.8, 5.4, 1.8, 'b');
      g.rect(8, 11, 13, 11, 'w');
      for (var i = 0; i < 7; i++) {
        final x = (rng() * 21).floor(), y = 5 + (rng() * 9).floor();
        if (g.at(x, y) == 'g') {
          g.set(x, y, 'p');
          g.set(x + 1, y, 'p');
        }
      }
    },
  ),
  (
    'starry_hill',
    '별 언덕',
    'Starry Hill',
    (t) => {'g': '#2F5D3A', 'w': '#FFFFFF', 'y': '#F5D90A', 'd': '#6B4423'},
    (g, t, rng) {
      for (var i = 0; i < 12; i++) {
        final x = (rng() * 22).floor(), y = (rng() * 7).floor();
        if (g.at(x, y) == 's') g.set(x, y, i.isEven ? 'w' : 'y');
      }
      _hills(g, 9.5, 2.2, 0.2, rng() * 4, 'g');
      _tree(g, 13 + rng() * 4, 5.8, 2.2, 'g', 'd');
      g.rect(4, 9, 4, 12, 'd');
      g.rect(3, 9, 5, 9, 'y');
    },
  ),
  (
    'ski_slope',
    '스키장',
    'Ski Slope',
    (t) => {'w': '#FFFFFF', 'g': '#2A7E3B', 'r': '#E5484D', 'd': '#4B5563'},
    (g, t, rng) {
      g.poly([(-1, 15), (-1, 5), (22, 12), (22, 15)], 'w');
      for (var x = 1.0; x < 22; x += 3) {
        _pine(g, x, 6.5 + x * 0.3, 3, 'g');
      }
      g.each((x, y) => (y - (2 + x * 0.25)).abs() < 0.4, 'd');
      for (final x in const [6, 12, 18]) {
        g.rect(x, (2 + x * 0.25).round(), x, (2 + x * 0.25).round() + 2, 'd');
        g.rect(
          x - 1,
          (2 + x * 0.25).round() + 2,
          x + 1,
          (2 + x * 0.25).round() + 2,
          'r',
        );
      }
      g.rect(9, 11, 10, 12, 'r');
      g.rect(8, 13, 11, 13, 'd');
    },
  ),
  (
    'bamboo_path',
    '대나무 숲길',
    'Bamboo Path',
    (t) => {'g': '#2A7E3B', 'l': '#8BD17C', 'y': '#E9D3A8', 'm': '#9CA3AF'},
    (g, t, rng) {
      g.poly([(8, 15), (10, 6), (12, 6), (14, 15)], 'y');
      for (var x = 0; x < 22; x += 2) {
        if (x > 7 && x < 14) continue;
        final ch = (x ~/ 2).isEven ? 'g' : 'l';
        g.rect(x, 0, x, 14, ch);
        for (var y = 2 + x % 3; y < 14; y += 4) {
          g.set(x + (x < 11 ? 1 : -1), y, ch);
        }
      }
      g.rect(15, 10, 17, 10, 'm');
      g.rect(16, 11, 16, 13, 'm');
      g.rect(15, 14, 17, 14, 'm');
    },
  ),
  (
    'beach_resort',
    '해변 휴양지',
    'Beach Resort',
    (t) => {
      'b': t.night ? '#1D4E89' : '#3E9BDB',
      'y': '#F2D59B',
      'r': '#E5484D',
      'g': '#2A9D5C',
    },
    (g, t, rng) {
      g.rect(0, 7, 21, 10, 'b');
      g.rect(0, 11, 21, 14, 'y');
      g.each((x, y) => (y - (10.6 + 0.5 * math.sin(x / 1.5))).abs() < 0.5, 'b');
      for (final ux in [4 + (rng() * 3).floor(), 12 + (rng() * 4).floor()]) {
        g.each(
          (x, y) =>
              math.pow((x - ux - 0.5) / 2.8, 2) +
                      math.pow((y - 10.2) / 1.6, 2) <=
                  1 &&
              y < 10.2,
          'r',
        );
        g.recolor('r', 'y', (x, y) => (x - ux).abs() == 1 && y < 10);
        g.rect(ux, 10, ux, 13, 'r');
      }
      g.poly([(18.6, 13), (19.4, 13), (20.4, 6), (19.8, 6)], 'r');
      g.ell(19.8, 5.8, 2.4, 0.9, 'g');
    },
  ),
];

List<ArtSource> _panoramas() {
  final out = <ArtSource>[];
  final rng = mulberry32(501);
  for (final (id, ko, en, palOf, draw) in _recipes()) {
    final i0 = (rng() * _tm.length).floor();
    final i1 = (i0 + 1 + (rng() * (_tm.length - 1)).floor()) % _tm.length;
    for (final t in [_tm[i0], _tm[i1]]) {
      final g = _pano(t, 3 + rng() * 16, 2.4);
      draw(g, t, rng);
      _corners(g);
      final pal = {'s': t.sky, 'u': t.sun, ...palOf(t)};
      out.add(
        makeArt('c_${id}_${t.id}', '${t.ko} $ko', '$en at ${t.en}', pal, g),
      );
    }
  }
  return out;
}

// ───────── 전신 캐릭터 (14×22) ─────────
const _skinC = ['#F7D2B6', '#E8B48F', '#C68642', '#8D5524', '#FAD7C0'];
const _hairC = [
  '#2D2A26',
  '#6B4423',
  '#E8C547',
  '#C0392B',
  '#F28CB1',
  '#4F7CF7',
  '#3BAF7E',
  '#8E4EC6',
];
const _clothC = [
  '#E5484D',
  '#3E9BDB',
  '#46A758',
  '#F5B301',
  '#8E4EC6',
  '#F76B15',
  '#30A4A0',
  '#FF8FA3',
  '#5C677D',
];
const _people = [
  ('가람', 'Garam'),
  ('나린', 'Narin'),
  ('다인', 'Dain'),
  ('라희', 'Rahee'),
  ('마루', 'Maru'),
  ('보람', 'Boram'),
  ('세찬', 'Sechan'),
  ('아로', 'Aro'),
  ('윤슬', 'Yunseul'),
  ('지안', 'Jian'),
  ('초롱', 'Chorong'),
  ('태린', 'Taerin'),
  ('하늬', 'Hanui'),
  ('한결', 'Hangyeol'),
  ('누리', 'Nuri'),
  ('다솜', 'Dasom'),
  ('로하', 'Roha'),
  ('미소', 'Miso'),
  ('봄이', 'Bomi'),
  ('새롬', 'Saerom'),
  ('여울', 'Yeoul'),
  ('은솔', 'Eunsol'),
  ('이랑', 'Irang'),
  ('주원', 'Juwon'),
  ('차오', 'Chao'),
  ('파랑', 'Parang'),
  ('해나', 'Haena'),
  ('호림', 'Horim'),
  ('아윤', 'Ayun'),
  ('라엘', 'Rael'),
];
const _items = [
  ('풍선', 'a Balloon'),
  ('꽃', 'a Flower'),
  ('우산', 'an Umbrella'),
  ('마법봉', 'a Wand'),
  ('책', 'a Book'),
  ('바구니', 'a Basket'),
  ('나무칼', 'a Wooden Sword'),
  ('깃발', 'a Flag'),
  ('잠자리채', 'a Bug Net'),
  ('연', 'a Kite'),
];

List<ArtSource> _fullBody() {
  final out = <ArtSource>[];
  final rng = mulberry32(611);
  for (var i = 0; i < 30; i++) {
    final g = Grid(14, 22);
    final skirt = i % 3 == 1;
    // 다리·신발
    g.rect(5, 17, 6, 19, skirt ? 's' : 'b');
    g.rect(8, 17, 9, 19, skirt ? 's' : 'b');
    g.rect(4, 20, 6, 21, 'k');
    g.rect(8, 20, 10, 21, 'k');
    if (skirt) {
      g.poly([(3.6, 17.2), (4.6, 14), (9.4, 14), (10.4, 17.2)], 'b');
    } else {
      g.rect(5, 14, 9, 16, 'b');
    }
    // 몸통·팔
    g.poly([(4, 14.2), (3.6, 9.4), (10.4, 9.4), (10, 14.2)], 'c');
    g.rect(2, 10, 3, 13, 'c');
    g.rect(11, 10, 12, 13, 'c');
    g.rect(2, 14, 3, 14, 's');
    g.rect(11, 14, 12, 14, 's');
    if (i % 4 == 2) g.recolor('c', 'a', (x, y) => y.isEven && y > 9);
    // 머리
    g.rect(6, 8, 7, 9, 's');
    g.ell(7, 4.8, 3.6, 3.8, 's');
    bool head(double x, double y) =>
        math.pow((x - 7) / 3.6, 2) + math.pow((y - 4.8) / 3.8, 2) <= 1;
    g.each((x, y) => head(x, y) && y < 3.6, 'h');
    g.each((x, y) => head(x, y) && y < 5.5 && (x < 4.2 || x > 9.8), 'h');
    switch (i % 6) {
      case 0:
        g.set(6, 3, 'h');
        g.set(7, 3, 'h');
      case 1:
        g.rect(3, 4, 3, 10, 'h');
        g.rect(10, 4, 10, 10, 'h');
      case 2:
        g.ell(7, 0.6, 1.6, 1.0, 'h');
      case 3:
        g.ell(2.6, 6.6, 0.9, 1.8, 'h');
        g.ell(11.4, 6.6, 0.9, 1.8, 'h');
      case 4:
        for (final x in const [4.0, 6.5, 9.0]) {
          g.poly([(x - 1.2, 2.2), (x + 0.2, -0.3), (x + 1.4, 2.2)], 'h');
        }
      default:
        for (final (x, y) in const [
          (4.0, 1.8),
          (7.0, 0.8),
          (10.0, 1.8),
          (3.4, 4.4),
          (10.6, 4.4),
        ]) {
          g.ell(x, y, 1.4, 1.3, 'h');
        }
    }
    g.set(5, 5, 'k');
    g.set(5, 6, 'k');
    g.set(8, 5, 'k');
    g.set(8, 6, 'k');
    g.set(6, 7, 'k');
    g.set(7, 7, 'k');
    // 손에 든 것 (오른손, x 11~13)
    final item = i % _items.length;
    switch (item) {
      case 0: // 풍선
        g.ell(12, 2.4, 1.6, 2.0, 'a');
        g.rect(12, 5, 12, 13, 'k');
      case 1: // 꽃
        g.rect(12, 9, 12, 13, 'k');
        g.ell(12.5, 8, 1.3, 1.2, 'a');
      case 2: // 우산
        g.each(
          (x, y) =>
              math.pow((x - 10.5) / 3.5, 2) + math.pow((y - 2) / 2.2, 2) <= 1 &&
              y < 2.4,
          'a',
        );
        g.rect(12, 2, 12, 13, 'k');
      case 3: // 마법봉
        g.rect(12, 8, 12, 13, 'k');
        g.poly([(12.5, 5.2), (13.6, 7.6), (11.4, 7.6)], 'a');
        g.poly([(12.5, 8.4), (13.6, 6.0), (11.4, 6.0)], 'a');
      case 4: // 책
        g.rect(11, 12, 13, 15, 'a');
      case 5: // 바구니
        g.rect(11, 14, 13, 16, 'a');
        g.set(11, 13, 'k');
        g.set(13, 13, 'k');
      case 6: // 나무칼
        g.rect(12, 6, 12, 13, 'a');
        g.rect(11, 12, 13, 12, 'k');
      case 7: // 깃발
        g.rect(12, 3, 12, 13, 'k');
        g.rect(13, 3, 13, 6, 'a');
      case 8: // 잠자리채
        g.rect(12, 5, 12, 13, 'k');
        g.ell(12.5, 3.4, 1.4, 1.8, 'a');
      default: // 연
        g.poly([(12.5, 0), (14, 2), (12.5, 4), (11, 2)], 'a');
        g.rect(12, 5, 12, 13, 'k');
    }
    final pal = {
      's': _skinC[(i * 3 + (rng() * 2).floor()) % _skinC.length],
      'h': _hairC[(i * 5) % _hairC.length],
      'k': '#2D2A26',
      'c': _clothC[(i * 4 + 1) % _clothC.length],
      'b': _clothC[(i * 4 + 5) % _clothC.length],
      'a': _clothC[(i * 7 + 3) % _clothC.length],
    };
    final (nk, ne) = _people[i];
    final (ik, ie) = _items[item];
    out.add(makeArt('c_kid_$i', '$ik 든 $nk', '$ne with $ie', pal, g));
  }
  return out;
}

// ───────── 큰 동물 (20×16) ─────────
List<ArtSource> _bigAnimals() {
  final out = <ArtSource>[];
  void animal(
    String id,
    String ko,
    String en,
    Map<String, String> pal,
    void Function(Grid g) draw, {
    int w = 20,
    int h = 16,
  }) {
    final g = Grid(w, h);
    draw(g);
    out.add(makeArt('c_animal_$id', ko, en, pal, g));
  }

  animal(
    'giraffe',
    '기린',
    'Giraffe',
    {'y': '#F2C46D', 'o': '#B5651D', 'k': '#2D2A26', 'g': '#46A758'},
    (g) {
      g.ell(9, 10, 5, 2.6, 'y');
      g.poly([(11, 9), (13.6, 9), (16.4, 2), (14.6, 1.4)], 'y');
      g.ell(16, 1.8, 2.2, 1.3, 'y');
      for (final x in const [5, 7, 11, 13]) {
        g.rect(x, 12, x, 15, 'y');
        g.set(x, 15, 'k');
      }
      g.recolor('y', 'o', (x, y) => (x * 3 + y * 5) % 7 == 0 && y < 12);
      g.set(16, 1, 'k');
      g.rect(15, 0, 15, 0, 'o');
      g.rect(0, 15, 3, 15, 'g');
      g.rect(16, 15, 19, 15, 'g');
      g.rect(3, 9, 4, 9, 'k');
    },
  );
  animal(
    'zebra',
    '얼룩말',
    'Zebra',
    {'w': '#FFFFFF', 'k': '#2D2A26', 'g': '#8BD17C'},
    (g) {
      g.ell(9, 8, 6, 3, 'w');
      g.poly([(13, 7), (15, 7), (18.6, 3), (17, 2)], 'w');
      g.ell(17.6, 3.4, 1.8, 1.4, 'w');
      for (final x in const [5, 7, 11, 13]) {
        g.rect(x, 10, x, 13, 'w');
      }
      g.recolor('w', 'k', (x, y) => (x + (y > 8 ? 1 : 0)) % 3 == 0 && y > 1);
      g.rect(14, 1, 16, 1, 'k');
      g.rect(2, 7, 3, 7, 'k');
      g.rect(0, 14, 19, 15, 'g');
    },
  );
  animal(
    'elephant',
    '코끼리',
    'Elephant',
    {
      'm': '#9CA3AF',
      'l': '#C7CBD3',
      'w': '#FFFFFF',
      'k': '#2D2A26',
      'g': '#8BAA4F',
    },
    (g) {
      g.ell(8, 8, 6.4, 4.4, 'm');
      g.ell(14.6, 6, 3.4, 3.2, 'm');
      g.ell(13, 6.2, 2.0, 2.8, 'l');
      g.rect(17, 7, 18, 12, 'm');
      g.set(18, 13, 'm');
      g.set(16, 9, 'w');
      g.set(16, 10, 'w');
      g.set(15, 5, 'k');
      for (final x in const [3, 6, 10, 12]) {
        g.rect(x, 11, x + 1, 14, 'm');
      }
      g.rect(0, 15, 19, 15, 'g');
    },
  );
  animal(
    'peacock',
    '공작',
    'Peacock',
    {
      'b': '#2563EB',
      'g': '#16A34A',
      'y': '#F5C518',
      't': '#30A4A0',
      'k': '#2D2A26',
    },
    (g) {
      g.ell(7, 8, 7.2, 7.2, 'g');
      for (var a = 0.0; a < math.pi * 1.05; a += math.pi / 6) {
        final x = 7 - math.cos(a) * 5.4, y = 8 - math.sin(a) * 5.4;
        g.ell(x, y, 1.0, 1.0, 't');
        g.set(x.floor(), y.floor(), 'y');
      }
      g.ell(13, 9, 2.4, 3.4, 'b');
      g.ell(15, 4.6, 1.3, 1.4, 'b');
      g.rect(14, 5, 14, 7, 'b');
      g.set(16, 4, 'k');
      g.set(15, 2, 'b');
      g.rect(12, 13, 12, 15, 'k');
      g.rect(14, 13, 14, 15, 'k');
    },
  );
  animal(
    'parrot',
    '앵무새',
    'Parrot',
    {
      'r': '#E5484D',
      'y': '#F5C518',
      'b': '#3E9BDB',
      'd': '#6B4423',
      'k': '#2D2A26',
      'g': '#46A758',
    },
    (g) {
      g.rect(0, 12, 19, 12, 'd');
      g.ell(9, 6.4, 3.4, 4.6, 'r');
      g.ell(10, 2.6, 2.6, 2.2, 'r');
      g.poly([(12, 2.4), (14, 3.4), (12.4, 4.6)], 'y');
      g.set(10, 2, 'k');
      g.ell(8, 7.4, 2.0, 3.4, 'b');
      g.recolor('b', 'y', (x, y) => y < 6);
      g.poly([(7, 10), (8.6, 10), (6.4, 15.6), (5, 15.6)], 'b');
      g.ell(16, 11, 2.4, 1.2, 'g');
      g.ell(3, 11, 2.0, 1.0, 'g');
    },
  );
  animal(
    'koi',
    '비단잉어',
    'Koi',
    {
      'w': '#FFFFFF',
      'o': '#F76B15',
      'k': '#2D2A26',
      'b': '#3E9BDB',
      'r': '#E5484D',
    },
    (g) {
      g.rect(0, 0, 19, 15, 'b');
      g.ell(9, 8, 6.6, 3.2, 'w');
      g.poly([(14.6, 8), (19.2, 4.4), (18, 8), (19.2, 11.6)], 'w');
      g.poly([(8, 5), (11, 2.6), (12, 5.6)], 'o');
      g.poly([(8, 11), (10.6, 13.6), (11.6, 10.4)], 'o');
      g.recolor(
        'w',
        'o',
        (x, y) =>
            (x - 7).abs() + (y - 7) * 1.4 < 2.5 || (x > 10 && x < 13 && y > 7),
      );
      g.recolor('w', 'r', (x, y) => x > 15 && y > 6 && y < 10);
      g.set(4, 7, 'k');
      for (final (x, y) in const [(2, 2), (16, 13), (1, 12)]) {
        g.set(x, y, 'w');
      }
    },
  );
  animal(
    'deer',
    '꽃사슴',
    'Spotted Deer',
    {
      'o': '#B5651D',
      'w': '#FFFFFF',
      'd': '#5B3A1E',
      'k': '#2D2A26',
      'g': '#8BD17C',
    },
    (g) {
      g.ell(8, 8.6, 5.6, 2.6, 'o');
      g.poly([(11.6, 8), (13.8, 8), (15.6, 3.6), (14, 3)], 'o');
      g.ell(15.4, 3.2, 1.8, 1.3, 'o');
      for (final x in const [4, 6, 10, 12]) {
        g.rect(x, 11, x, 14, 'o');
      }
      g.recolor(
        'o',
        'w',
        (x, y) => (x * 2 + y * 3) % 5 == 0 && y < 10 && x < 12,
      );
      for (final (x0, dir) in const [(14, -1), (16, 1)]) {
        g.rect(x0, 0, x0, 2, 'd');
        g.set(x0 + dir, 0, 'd');
      }
      g.set(16, 3, 'k');
      g.rect(0, 15, 19, 15, 'g');
    },
  );
  animal(
    'horse',
    '말',
    'Horse',
    {'d': '#8B5A2B', 'k': '#2D2A26', 'w': '#F3F4F6', 'g': '#46A758'},
    (g) {
      g.ell(8.4, 8, 6.2, 2.8, 'd');
      g.poly([(12, 7), (14.4, 7.6), (17.6, 2.6), (15.6, 1.6)], 'd');
      g.poly([(16.4, 1.4), (19.4, 3.2), (18.6, 4.6), (16, 3.4)], 'd');
      g.poly([(12.6, 6), (15.2, 1.0), (14.4, 0.6), (11.6, 5.6)], 'k');
      g.poly([(2.4, 6.6), (0.4, 11.6), (1.6, 11.6), (3.2, 8)], 'k');
      for (final x in const [4, 6, 11, 13]) {
        g.rect(x, 10, x, 13, 'd');
        g.set(x, 14, 'k');
      }
      g.set(17, 2, 'w');
      g.rect(0, 15, 19, 15, 'g');
    },
  );
  animal(
    'flamingo',
    '홍학',
    'Flamingo',
    {'p': '#F28CB1', 'k': '#2D2A26', 'b': '#7FD1F5', 'w': '#FFFFFF'},
    (g) {
      g.rect(0, 12, 19, 15, 'b');
      g.ell(9, 6.4, 4.0, 2.4, 'p');
      g.each(
        (x, y) =>
            (x - (13.4 + 1.6 * math.sin(y / 1.6))).abs() < 0.7 &&
            y < 6 &&
            y > 0.6,
        'p',
      );
      g.ell(14.2, 1.2, 1.4, 1.0, 'p');
      g.poly([(15, 1), (17, 1.6), (15.6, 3)], 'k');
      g.rect(9, 9, 9, 13, 'p');
      g.rect(10, 9, 10, 11, 'p');
      g.rect(11, 11, 12, 11, 'p');
      g.set(14, 1, 'w');
      for (final x in const [2, 7, 15]) {
        g.set(x, 13, 'w');
        g.set(x + 1, 13, 'w');
      }
    },
  );
  animal(
    'tiger',
    '호랑이',
    'Tiger',
    {'o': '#F59E0B', 'k': '#2D2A26', 'w': '#FFFFFF', 'g': '#46A758'},
    (g) {
      g.ell(8, 8.6, 6.4, 2.8, 'o');
      g.ell(15.6, 6.6, 3.0, 2.8, 'o');
      g.ell(14.2, 4.0, 0.9, 0.9, 'o');
      g.ell(17.2, 4.0, 0.9, 0.9, 'o');
      for (final x in const [3, 5, 10, 12]) {
        g.rect(x, 10, x + 1, 14, 'o');
      }
      g.each(
        (x, y) => (x - 1.2 - math.sin(y)).abs() < 0.6 && y > 3 && y < 8.6,
        'o',
      );
      g.recolor('o', 'k', (x, y) => x % 3 == 0 && y < 10 && x < 13);
      g.ell(16.4, 8, 1.6, 0.8, 'w');
      g.set(15, 6, 'k');
      g.set(17, 6, 'k');
      g.rect(0, 15, 19, 15, 'g');
    },
  );
  return out;
}

// ───────── 실내 풍경 (20×17) ─────────
List<ArtSource> _rooms() {
  final out = <ArtSource>[];
  void room(
    String id,
    String ko,
    String en,
    Map<String, String> pal,
    void Function(Grid g) draw,
  ) {
    final g = Grid(20, 17)
      ..rect(0, 0, 19, 13, 'w')
      ..rect(0, 14, 19, 16, 'f');
    draw(g);
    out.add(makeArt('c_room_$id', ko, en, pal, g));
  }

  void window(Grid g, int x, int y, int w, int h) {
    g.rect(x, y, x + w - 1, y + h - 1, 'd');
    g.rect(x + 1, y + 1, x + w - 2, y + h - 2, 'b');
    g.rect(x + w ~/ 2, y + 1, x + w ~/ 2, y + h - 2, 'd');
  }

  room(
    'living',
    '거실',
    'Living Room',
    {
      'w': '#F3E3B5',
      'f': '#B08850',
      'd': '#6B4423',
      'b': '#8ECDF5',
      'a': '#E5484D',
      'g': '#46A758',
    },
    (g) {
      window(g, 2, 2, 6, 5);
      g.rect(10, 2, 15, 6, 'd');
      g.rect(11, 3, 14, 5, 'g');
      g.rect(4, 9, 15, 13, 'a');
      g.rect(3, 8, 4, 13, 'a');
      g.rect(15, 8, 16, 13, 'a');
      g.rect(5, 10, 14, 10, 'd');
      g.rect(18, 9, 18, 13, 'd');
      g.ell(18, 7.6, 1.4, 1.8, 'g');
    },
  );
  room(
    'bedroom',
    '침실',
    'Bedroom',
    {
      'w': '#C9D6F5',
      'f': '#B08850',
      'd': '#6B4423',
      'b': '#1E3A8A',
      'a': '#F28CB1',
      'y': '#F5D90A',
    },
    (g) {
      window(g, 12, 2, 6, 5);
      g.set(14, 3, 'y');
      g.rect(1, 9, 11, 13, 'a');
      g.rect(1, 6, 1, 13, 'd');
      g.rect(2, 8, 4, 9, 'w');
      g.recolor('a', 'w', (x, y) => y == 11);
      g.rect(14, 10, 17, 13, 'd');
      g.rect(15, 8, 16, 9, 'y');
    },
  );
  room(
    'study',
    '서재',
    'Study',
    {
      'w': '#E9D3A8',
      'f': '#8B5A2B',
      'd': '#5B3A1E',
      'a': '#E5484D',
      'g': '#46A758',
      'b': '#3E9BDB',
    },
    (g) {
      g.rect(1, 1, 9, 13, 'd');
      const books = ['a', 'g', 'b', 'w'];
      for (final y in const [2, 6, 10]) {
        for (var x = 2; x <= 8; x++) {
          g.rect(x, y, x, y + 2, books[(x + y) % 4]);
        }
      }
      g.rect(11, 9, 18, 9, 'd');
      g.rect(12, 10, 12, 13, 'd');
      g.rect(17, 10, 17, 13, 'd');
      g.rect(13, 7, 15, 8, 'b');
      g.rect(16, 6, 16, 8, 'g');
    },
  );
  room(
    'kitchen',
    '부엌',
    'Kitchen',
    {
      'w': '#F3F4F6',
      'f': '#9CA3AF',
      'd': '#6B4423',
      'a': '#E5484D',
      'k': '#2D2A26',
      'y': '#F5C518',
    },
    (g) {
      g.recolor('w', 'f', (x, y) => (x + y).isEven && y < 6);
      g.rect(0, 9, 19, 13, 'd');
      g.rect(0, 9, 19, 9, 'w');
      g.rect(7, 7, 12, 9, 'k');
      g.rect(8, 5, 11, 6, 'a');
      g.rect(14, 7, 16, 8, 'y');
      g.rect(2, 2, 6, 2, 'd');
      g.rect(2, 1, 2, 1, 'a');
      g.rect(4, 1, 4, 1, 'y');
    },
  );
  room(
    'cafe',
    '카페',
    'Café',
    {
      'w': '#F3E3B5',
      'f': '#6B4423',
      'k': '#2D3A2E',
      'a': '#E5484D',
      'g': '#46A758',
      'y': '#FFFFFF',
    },
    (g) {
      g.rect(1, 1, 8, 6, 'k');
      for (var y = 2; y <= 5; y++) {
        g.rect(2, y, 3 + (y * 3) % 5, y, 'y');
      }
      g.rect(0, 10, 19, 13, 'f');
      g.rect(0, 10, 19, 10, 'k');
      for (final x in const [3, 8, 13]) {
        g.rect(x, 8, x + 1, 9, 'y');
        g.set(x + 2, 8, 'y');
      }
      g.ell(17, 7, 1.8, 2.4, 'g');
      g.rect(17, 9, 17, 9, 'a');
      g.rect(11, 1, 17, 1, 'a');
    },
  );
  room(
    'florist',
    '꽃집',
    'Flower Shop',
    {
      'w': '#FDF2F8',
      'f': '#8B5A2B',
      'g': '#46A758',
      'a': '#E5484D',
      'p': '#F28CB1',
      'y': '#F5C518',
    },
    (g) {
      for (var i = 0; i < 5; i++) {
        final x = 1 + i * 4;
        g.rect(x, 10, x + 2, 13, 'f');
        g.rect(x + 1, 7, x + 1, 9, 'g');
        g.ell(x + 1.5, 6, 1.6, 1.4, const ['a', 'p', 'y', 'p', 'a'][i]);
      }
      g.rect(0, 1, 19, 2, 'g');
      for (var x = 1; x < 19; x += 3) {
        g.set(x, 3, 'p');
      }
    },
  );
  room(
    'bakery',
    '빵집',
    'Bakery',
    {
      'w': '#FEF3C7',
      'f': '#B08850',
      'd': '#6B4423',
      'y': '#E9A23B',
      'o': '#B45309',
      'a': '#E5484D',
    },
    (g) {
      for (final y in const [3, 7, 11]) {
        g.rect(1, y + 2, 18, y + 2, 'd');
        for (var x = 2; x < 18; x += 3) {
          g.ell(x + 0.8, y + 1.2, 1.3, 0.9, (x + y).isEven ? 'y' : 'o');
        }
      }
      g.rect(0, 0, 19, 0, 'a');
      g.recolor('a', 'w', (x, y) => x.isOdd);
    },
  );
  room(
    'workshop',
    '목공방',
    'Woodshop',
    {
      'w': '#D6C7A1',
      'f': '#6B4423',
      'd': '#8B5A2B',
      'k': '#4B5563',
      'a': '#E5484D',
      'y': '#F5C518',
    },
    (g) {
      g.rect(0, 9, 19, 9, 'd');
      g.rect(1, 10, 1, 13, 'd');
      g.rect(18, 10, 18, 13, 'd');
      g.rect(3, 7, 8, 8, 'y');
      g.rect(11, 6, 11, 8, 'k');
      g.rect(10, 5, 12, 5, 'k');
      for (var x = 2; x < 18; x += 3) {
        g.rect(x, 1, x, 3, 'k');
        g.set(x, 4, x % 2 == 0 ? 'a' : 'y');
      }
      g.rect(14, 7, 17, 8, 'a');
    },
  );
  room(
    'attic',
    '다락방',
    'Attic Room',
    {
      'w': '#E9D3A8',
      'f': '#8B5A2B',
      'd': '#5B3A1E',
      'b': '#8ECDF5',
      'a': '#F76B15',
      'g': '#46A758',
    },
    (g) {
      g.poly([(-1, -1), (7, -1), (-1, 9)], 'd');
      g.poly([(21, -1), (13, -1), (21, 9)], 'd');
      g.ell(10, 4, 2.6, 2.6, 'd');
      g.ell(10, 4, 1.8, 1.8, 'b');
      g.rect(10, 2, 10, 6, 'd');
      g.rect(2, 10, 6, 13, 'a');
      g.rect(3, 8, 5, 9, 'a');
      g.recolor('a', 'd', (x, y) => y == 11);
      g.rect(13, 11, 17, 13, 'g');
      g.rect(15, 9, 15, 10, 'd');
    },
  );
  room(
    'greenhouse',
    '온실',
    'Greenhouse',
    {
      'w': '#DFF5E1',
      'f': '#8B5A2B',
      'k': '#5C677D',
      'g': '#2A7E3B',
      'l': '#8BD17C',
      'a': '#F28CB1',
    },
    (g) {
      for (var x = 0; x < 20; x += 5) {
        g.rect(x, 0, x, 13, 'k');
      }
      g.rect(0, 4, 19, 4, 'k');
      for (var i = 0; i < 6; i++) {
        final x = 1.5 + i * 3.2;
        g.rect(x.floor(), 11, x.floor() + 1, 13, 'f');
        g.ell(x + 0.6, 8.6, 1.4, 2.4, i.isEven ? 'g' : 'l');
        if (i % 3 == 1) g.set(x.floor(), 7, 'a');
      }
    },
  );
  return out;
}

// ───────── 스테인드글라스 (15×21) ─────────
List<ArtSource> _stainedGlass() {
  final out = <ArtSource>[];
  const themes = [
    ('푸른', 'Azure', ['#2563EB', '#60A5FA', '#F5C518', '#16A34A']),
    ('붉은', 'Crimson', ['#B91C1C', '#F87171', '#F5C518', '#7C3AED']),
  ];
  const motifs = [
    ('장미창', 'Rose Window'),
    ('마름모 창', 'Diamond Window'),
    ('꽃 창', 'Flower Window'),
    ('생명의 나무 창', 'Tree of Life Window'),
    ('무지개 아치 창', 'Rainbow Arch Window'),
  ];
  for (var m = 0; m < motifs.length; m++) {
    for (var t = 0; t < themes.length; t++) {
      final g = Grid(15, 21);
      bool inside(double x, double y) =>
          (y >= 7 && x > 0 && x < 15) ||
          math.pow((x - 7.5) / 7.5, 2) + math.pow((y - 7.5) / 7.5, 2) <= 1;
      g.each(inside, 'a');
      final (tk, te, cols) = themes[t];
      switch (m) {
        case 0:
          g.each(
            (x, y) =>
                inside(x, y) &&
                ((math.atan2(y - 8, x - 7.5) * 8 / math.pi).floor()).isEven,
            'b',
          );
          g.each(
            (x, y) =>
                inside(x, y) &&
                math.sqrt(math.pow(x - 7.5, 2) + math.pow(y - 8, 2)) < 2.4,
            'c',
          );
        case 1:
          g.each(
            (x, y) =>
                inside(x, y) &&
                (((x + y) / 3).floor() + ((x - y) / 3).floor()).isEven,
            'b',
          );
        case 2:
          for (final (cx, cy) in const [
            (7.5, 6.0),
            (4.0, 12.0),
            (11.0, 12.0),
            (7.5, 17.0),
          ]) {
            for (var a = 0.0; a < 2 * math.pi; a += math.pi / 3) {
              g.ell(
                cx + math.cos(a) * 1.6,
                cy + math.sin(a) * 1.6,
                1.0,
                1.0,
                'b',
              );
            }
            g.ell(cx, cy, 0.9, 0.9, 'c');
          }
        case 3:
          g.rect(7, 10, 8, 19, 'd');
          g.ell(7.5, 7.5, 5.0, 4.0, 'b');
          for (final (x, y) in const [
            (5, 6),
            (9, 5),
            (7, 8),
            (4, 9),
            (11, 8),
          ]) {
            g.set(x, y, 'c');
          }
          g.rect(1, 19, 13, 20, 'd');
        default:
          g.each(
            (x, y) =>
                inside(x, y) &&
                (math.sqrt(math.pow(x - 7.5, 2) + math.pow(y - 20, 2)) / 2.6)
                    .floor()
                    .isEven,
            'b',
          );
          g.each(
            (x, y) =>
                inside(x, y) &&
                (math.sqrt(math.pow(x - 7.5, 2) + math.pow(y - 20, 2)) / 2.6)
                            .floor() %
                        3 ==
                    1,
            'c',
          );
      }
      // 납 테두리
      g.each(
        (x, y) =>
            inside(x, y) &&
            (!inside(x - 1, y) ||
                !inside(x + 1, y) ||
                !inside(x, y - 1) ||
                y > 20),
        'k',
      );
      g.each(
        (x, y) =>
            inside(x, y) &&
            (y.floor() == 7 || x.floor() == 7) &&
            m != 0 &&
            m != 3,
        'k',
      );
      final pal = {
        'a': cols[1],
        'b': cols[0],
        'c': cols[2],
        'd': cols[3],
        'k': '#2D2A26',
      };
      out.add(
        makeArt(
          'c_glass${m}_$t',
          '$tk ${motifs[m].$1}',
          '$te ${motifs[m].$2}',
          pal,
          g,
        ),
      );
    }
  }
  return out;
}

List<ArtSource> complexArts() => [
  ..._panoramas(),
  ..._fullBody(),
  ..._bigAnimals(),
  ..._rooms(),
  ..._stainedGlass(),
];
