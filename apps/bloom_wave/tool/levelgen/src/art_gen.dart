// 코드로 그리는 픽셀 아트 (2026-11-04): 풍경화 · 캐릭터 · 일러스트.
// 손으로 그린 art_source.dart 의 90장에 더해, 같은 그림이 1000 스테이지에서 3번 넘게 나오지 않도록 그림 수를 늘린다.
// 모든 그림은 시드가 고정이라 언제 돌려도 같은 결과다. 이름(ko/en)은 그림마다 다르다.
// 크기는 손그림과 비슷하게 16×16 이하, 색은 6개 이하 (생성기 maxColors).
import 'dart:math' as math;

import 'package:bloom_wave/domain/engine.dart' show dir8;
import 'package:bloom_wave/domain/generator.dart';

import 'art_complex.dart';
import 'art_hires.dart';
import 'art_source.dart';

/// 그림 묶음(유형). 같은 묶음끼리는 스테이지 배치에서 너무 가깝게 붙지 않게 한다
String familyOf(String name) {
  if (_alias.containsKey(name)) return _alias[name]!;
  final i = name.lastIndexOf('_');
  return (name.startsWith('g_') ||
              name.startsWith('c_') ||
              name.startsWith('h_')) &&
          i > 1
      ? name.substring(0, i)
      : name;
}

/// 손그림 중 코드 그림과 같은 유형인 것
const _alias = {
  'hot_air_balloon': 'g_balloon',
  'rocket': 'g_rocket',
  'sailboat': 'g_yacht',
  'car': 'g_car',
  'train': 'g_engine',
  'guitar': 'g_inst',
  'lighthouse': 'g_lighthouse',
  'house': 'g_cottage',
  'winter_cabin': 'g_village',
  'night_sky': 'g_aurora',
  'cherry_blossom': 'g_blossom',
};

/// 문자 격자에 도형을 칠하는 도구. 좌표는 칸 단위, 도형 판정은 칸 중심(x+0.5, y+0.5)으로 한다
class Grid {
  Grid(this.w, this.h) : _c = List.generate(h, (_) => List.filled(w, '.'));
  final int w, h;
  final List<List<String>> _c;

  String at(int x, int y) =>
      x < 0 || y < 0 || x >= w || y >= h ? '.' : _c[y][x];

  void set(int x, int y, String ch) {
    if (x >= 0 && y >= 0 && x < w && y < h) _c[y][x] = ch;
  }

  void each(bool Function(double x, double y) inside, String ch) {
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (inside(x + 0.5, y + 0.5)) _c[y][x] = ch;
      }
    }
  }

  /// 양 끝 포함 사각형
  void rect(int x0, int y0, int x1, int y1, String ch) {
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        set(x, y, ch);
      }
    }
  }

  void ell(double cx, double cy, double rx, double ry, String ch) => each(
    (x, y) => math.pow((x - cx) / rx, 2) + math.pow((y - cy) / ry, 2) <= 1,
    ch,
  );

  void poly(List<(double, double)> pts, String ch) => each((x, y) {
    var inside = false;
    for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      final (xi, yi) = pts[i];
      final (xj, yj) = pts[j];
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }, ch);

  /// 이미 칠한 칸만 바꾼다
  void recolor(String from, String to, bool Function(int x, int y) where) {
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (_c[y][x] == from && where(x, y)) _c[y][x] = to;
      }
    }
  }

  /// 좌우 대칭 (왼쪽 절반을 오른쪽으로)
  void mirrorX() {
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w ~/ 2; x++) {
        _c[y][w - 1 - x] = _c[y][x];
      }
    }
  }

  int count(String ch) =>
      _c.fold(0, (n, r) => n + r.where((c) => c == ch).length);

  List<String> get rows => [for (final r in _c) r.join()];
}

/// 쓰인 색만 팔레트에 남긴다. 6색(생성기 maxColors)을 넘으면 가장 적게 쓴 색을 이웃에 가장 많은 색으로 칠해 줄인다
List<String> _cleanPalette(Grid g, Map<String, String> pal) {
  while (true) {
    final used = [
      for (final k in pal.keys)
        if (g.count(k) > 0) k,
    ];
    if (used.length <= 6) return [for (final k in used) '$k=${pal[k]}'];
    used.sort((a, b) => g.count(a) - g.count(b));
    final rare = used.first;
    final near = <String, int>{};
    for (var y = 0; y < g.h; y++) {
      for (var x = 0; x < g.w; x++) {
        if (g.at(x, y) != rare) continue;
        for (final (dx, dy) in dir8) {
          final c = g.at(x + dx, y + dy);
          if (c != '.' && c != rare) near[c] = (near[c] ?? 0) + 1;
        }
      }
    }
    final to = near.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    g.recolor(rare, to, (x, y) => true);
  }
}

ArtSource makeArt(
  String name,
  String ko,
  String en,
  Map<String, String> pal,
  Grid g,
) => ArtSource(
  name: name,
  ko: ko,
  en: en,
  palette: _cleanPalette(g, pal),
  rows: g.rows,
);

// ───────────────────────── 풍경화 ─────────────────────────
// 엽서 모양 15×11 (네 귀퉁이를 깎음). 시간대가 하늘·해/달 색을 정한다.

class _Time {
  const _Time(this.id, this.ko, this.en, this.sky, this.sun, this.night);
  final String id, ko, en, sky, sun;
  final bool night;
}

const _times = [
  _Time('dawn', '새벽', 'Dawn', '#F9C6D3', '#FFF4C2', false),
  _Time('day', '한낮', 'Midday', '#8ECDF5', '#F5D90A', false),
  _Time('sunset', '노을', 'Sunset', '#F59E61', '#FDE047', false),
  _Time('night', '달밤', 'Moonlit', '#1E3A8A', '#FEF3C7', true),
  _Time('dusk', '보랏빛 저녁', 'Violet Dusk', '#7C6FD6', '#FBD38D', false),
  _Time('mist', '안개 낀', 'Misty', '#C9D6DF', '#FFFFFF', false),
];

Grid _postcard(String sky) {
  final g = Grid(15, 11)..rect(0, 0, 14, 10, 's');
  for (final (x, y) in const [(0, 0), (14, 0), (0, 10), (14, 10)]) {
    g.set(x, y, '.');
  }
  return g;
}

void _sunOrMoon(Grid g, _Time t, double cx, double cy) {
  if (t.id == 'mist') return;
  g.ell(cx, cy, 1.6, 1.6, 'u');
  if (t.night) {
    // 초승달: 오른쪽 위를 하늘색으로 덮는다
    g.ell(cx + 0.9, cy - 0.5, 1.3, 1.3, 's');
    for (final (x, y) in const [(2, 2), (6, 1), (10, 3), (12, 1)]) {
      if (g.at(x, y) == 's') g.set(x, y, 'u');
    }
  }
}

/// 묶음 하나 = 시간대 6가지 (그림 6장)
typedef _Scene =
    void Function(
      Grid g,
      _Time t,
      double Function() rng,
      Map<String, String> pal,
    );

List<ArtSource> _landscapes() {
  final out = <ArtSource>[];
  void family(
    String id,
    String ko,
    String en,
    int seed,
    _Scene draw, {
    List<_Time>? times,
  }) {
    final rng = mulberry32(seed);
    for (final t in times ?? _times) {
      final pal = <String, String>{'s': t.sky, 'u': t.sun};
      final g = _postcard(t.sky);
      draw(g, t, rng, pal);
      out.add(
        makeArt(
          'g_${id}_${t.id}',
          '${t.ko} $ko',
          '$en at ${t.en}'.replaceFirst(' at Misty', ' in Mist'),
          pal,
          g,
        ),
      );
    }
  }

  family('mountain', '산', 'Mountains', 11, (g, t, rng, pal) {
    _sunOrMoon(g, t, 3 + rng() * 9, 2.5);
    pal['a'] = t.night ? '#4C5A8C' : '#9AA9C9';
    pal['b'] = t.night ? '#2C3866' : '#5B6B8C';
    pal['w'] = '#FFFFFF';
    pal['g'] = t.night ? '#2F5D3A' : '#46A758';
    final p1 = 2 + rng() * 4, p2 = 8 + rng() * 4, h1 = 2 + rng() * 2;
    g.poly([(-1, 9), (p1, h1), (p1 + 6, 9)], 'a');
    g.poly([(p2 - 7, 9.5), (p2, 3.5 + rng() * 2), (p2 + 7, 9.5)], 'b');
    g.recolor('a', 'w', (x, y) => y < h1 + 1.6);
    g.recolor('b', 'w', (x, y) => y < 5);
    g.rect(0, 9, 14, 10, 'g');
  });
  family('seaside', '바닷가', 'Seaside', 12, (g, t, rng, pal) {
    _sunOrMoon(g, t, 3 + rng() * 9, 4.6);
    pal['b'] = t.night ? '#1D4E89' : '#3E9BDB';
    pal['w'] = '#FFFFFF';
    pal['y'] = '#F2D59B';
    pal['k'] = '#6B4423';
    g.rect(0, 5, 14, 8, 'b');
    for (final y in const [6, 8]) {
      final o = (rng() * 4).floor();
      for (var x = o; x < 15; x += 5) {
        g.set(x, y, 'w');
        g.set(x + 1, y, 'w');
      }
    }
    g.rect(0, 9, 14, 10, 'y');
    final bx = 2 + (rng() * 8).floor();
    g.rect(bx, 5, bx + 3, 5, 'k');
    g.poly([(bx + 1.5, 1.5), (bx + 1.5, 4.9), (bx + 3.6, 4.9)], 'w');
    g.set(0, 10, '.');
    g.set(14, 10, '.');
  });
  family('lake', '숲속 호수', 'Forest Lake', 13, (g, t, rng, pal) {
    _sunOrMoon(g, t, 3 + rng() * 9, 2);
    pal['g'] = t.night ? '#1F4D33' : '#2A7E3B';
    pal['b'] = t.night ? '#25508A' : '#5DADE2';
    pal['r'] = t.night ? '#173A66' : '#2E86C1';
    pal['d'] = '#7A5230';
    for (var x = 1.0; x < 15; x += 3 + rng()) {
      final top = 1.2 + rng() * 1.8;
      g.poly([(x - 2.1, 6.6), (x, top), (x + 2.1, 6.6)], 'g');
    }
    g.rect(0, 6, 14, 6, 'd');
    g.rect(0, 7, 14, 10, 'b');
    for (var x = 0; x < 15; x++) {
      if (g.at(x, 5) == 'g') g.set(x, 7, 'r');
      if (g.at(x, 4) == 'g') g.set(x, 8, 'r');
    }
    g.set(0, 10, '.');
    g.set(14, 10, '.');
  });
  family('desert', '사막', 'Desert', 14, (g, t, rng, pal) {
    _sunOrMoon(g, t, 9 + rng() * 3, 2.5);
    pal['y'] = t.night ? '#B08850' : '#F2C46D';
    pal['o'] = t.night ? '#8A6533' : '#D9963B';
    pal['g'] = '#3F8F4F';
    final ph = rng() * 6;
    g.each((x, y) => y > 6.5 + 1.2 * math.sin(x / 2.5 + ph), 'y');
    g.each((x, y) => y > 8.2 + math.sin(x / 2 + ph + 2), 'o');
    final cx = 2 + (rng() * 3).floor();
    g.rect(cx, 3, cx, 8, 'g');
    g.rect(cx - 1, 5, cx - 1, 6, 'g');
    g.rect(cx + 1, 4, cx + 1, 5, 'g');
    g.set(0, 10, '.');
    g.set(14, 10, '.');
  });
  family('village', '눈 마을', 'Snowy Village', 15, (g, t, rng, pal) {
    _sunOrMoon(g, t, 11 + rng() * 2, 2);
    pal['w'] = '#FFFFFF';
    pal['h'] = '#B4553B';
    pal['r'] = '#6B3E2E';
    pal['y'] = '#F5D90A';
    var x = 0;
    while (x < 14) {
      final hw = 3 + (rng() * 2).floor(), top = 4 + (rng() * 2).floor();
      g.poly([
        (x - 0.3, top + 2.0),
        (x + hw / 2, top + 0.0),
        (x + hw + 0.3, top + 2.0),
      ], 'w');
      g.rect(x, top + 2, x + hw - 1, 8, 'h');
      g.set(x + hw ~/ 2, top + 3, 'y');
      g.set(x + hw ~/ 2, 7, 'r');
      g.set(x + hw ~/ 2, 8, 'r');
      x += hw + 1;
    }
    g.rect(0, 9, 14, 10, 'w');
    g.set(0, 10, '.');
    g.set(14, 10, '.');
  });
  family('city', '도시', 'City', 16, (g, t, rng, pal) {
    _sunOrMoon(g, t, 2 + rng() * 3, 2);
    pal['k'] = t.night ? '#2B2D42' : '#5C677D';
    pal['n'] = t.night ? '#3D405B' : '#8D99AE';
    pal['y'] = t.night ? '#F5D90A' : '#DCEBF5';
    pal['b'] = t.night ? '#14213D' : '#3E9BDB';
    var x = 0;
    var tone = 'k';
    while (x < 15) {
      final bw = 2 + (rng() * 2).floor(), top = 2 + (rng() * 5).floor();
      g.rect(x, top, x + bw - 1, 8, tone);
      for (var y = top + 1; y < 8; y += 2) {
        for (var wx = x; wx < x + bw; wx += 2) {
          if (rng() < 0.6) g.set(wx, y, 'y');
        }
      }
      tone = tone == 'k' ? 'n' : 'k';
      x += bw;
    }
    g.rect(0, 9, 14, 10, 'b');
    for (var wx = 1; wx < 14; wx += 3) {
      g.set(wx, 9, 'y');
    }
    g.set(0, 10, '.');
    g.set(14, 10, '.');
  });
  family('hills', '언덕', 'Rolling Hills', 17, (g, t, rng, pal) {
    _sunOrMoon(g, t, 10 + rng() * 3, 2.2);
    pal['w'] = '#FFFFFF';
    pal['l'] = t.night ? '#3E7D4F' : '#8BD17C';
    pal['g'] = t.night ? '#2A5C3A' : '#46A758';
    pal['d'] = '#7A5230';
    final ph = rng() * 5;
    if (!t.night) g.ell(3 + rng() * 3, 2, 2.2, 0.9, 'w');
    g.each((x, y) => y > 5.5 + math.sin(x / 3 + ph), 'l');
    g.each((x, y) => y > 7.6 + 0.9 * math.sin(x / 2.4 + ph + 1.5), 'g');
    final tx = 4 + (rng() * 7).floor();
    g.ell(tx + 0.5, 3.6, 1.7, 1.5, 'g');
    g.rect(tx, 5, tx, 6, 'd');
  });
  family('island', '섬', 'Island', 18, (g, t, rng, pal) {
    _sunOrMoon(g, t, 2.5 + rng() * 2, 2.2);
    pal['b'] = t.night ? '#1D4E89' : '#3E9BDB';
    pal['y'] = '#F2D59B';
    pal['d'] = '#8B5A2B';
    pal['g'] = '#2A9D5C';
    g.rect(0, 7, 14, 10, 'b');
    final ix = 8 + rng() * 2;
    g.ell(ix, 7.6, 3.6, 1.4, 'y');
    g.poly([
      (ix - 0.4, 7),
      (ix + 0.3, 7),
      (ix + 1.2, 3.2),
      (ix + 0.7, 3.2),
    ], 'd');
    g.ell(ix - 0.2, 2.9, 2.2, 0.8, 'g');
    g.ell(ix + 2, 3.2, 1.5, 0.7, 'g');
    g.set(0, 10, '.');
    g.set(14, 10, '.');
  });
  family('waterfall', '폭포', 'Waterfall', 19, (g, t, rng, pal) {
    _sunOrMoon(g, t, 7 + rng() * 2, 1.8);
    pal['c'] = t.night ? '#4A4E69' : '#8D7B68';
    pal['w'] = '#E8F6FF';
    pal['b'] = t.night ? '#25508A' : '#3E9BDB';
    pal['g'] = t.night ? '#2F5D3A' : '#46A758';
    final gap = 6 + (rng() * 2).floor();
    g.rect(0, 3, gap - 1, 8, 'c');
    g.rect(gap + 3, 4, 14, 8, 'c');
    g.rect(0, 3, gap - 1, 3, 'g');
    g.rect(gap + 3, 4, 14, 4, 'g');
    g.rect(gap, 3, gap + 2, 8, 'w');
    g.rect(0, 9, 14, 10, 'b');
    g.rect(gap - 1, 9, gap + 3, 9, 'w');
    g.set(0, 10, '.');
    g.set(14, 10, '.');
  });
  family('lighthouse', '등대 언덕', 'Lighthouse Cove', 20, (g, t, rng, pal) {
    pal['b'] = t.night ? '#1D4E89' : '#3E9BDB';
    pal['c'] = '#6B7280';
    pal['w'] = '#FFFFFF';
    pal['r'] = '#E5484D';
    pal['y'] = '#F5D90A';
    g.rect(0, 7, 14, 10, 'b');
    final lx = 3 + (rng() * 2).floor();
    g.ell(lx + 1.0, 8.5, 3.5, 2.2, 'c');
    for (var y = 2; y <= 6; y++) {
      g.rect(lx, y, lx + 1, y, y.isEven ? 'r' : 'w');
    }
    g.rect(lx, 1, lx + 1, 1, 'y');
    if (t.night || t.id == 'dusk' || t.id == 'mist') {
      g.poly([(lx + 2.0, 1.0), (14.5, -0.5), (14.5, 3.5)], 'y');
    } else {
      _sunOrMoon(g, t, 11, 3);
      g.recolor('u', 'y', (x, y) => true); // 해는 등불과 같은 노랑 (색 6개 이하)
    }
    g.set(0, 10, '.');
    g.set(14, 10, '.');
  });
  family('blossom', '벚꽃길', 'Blossom Lane', 21, (g, t, rng, pal) {
    _sunOrMoon(g, t, 7.5, 1.8);
    pal['p'] = '#F7A8C4';
    pal['d'] = '#6B4423';
    pal['y'] = '#E9D3A8';
    pal['g'] = t.night ? '#2F5D3A' : '#6CC070';
    g.rect(0, 7, 14, 10, 'g');
    g.poly([(5.5, 7), (9.5, 7), (12, 11), (3, 11)], 'y');
    for (final cx in [2.0, 12.5]) {
      g.rect(cx.floor(), 4, cx.floor(), 7, 'd');
      g.ell(cx + 0.5, 3, 2.6 + rng() * 0.6, 2, 'p');
    }
    g.set(0, 10, '.');
    g.set(14, 10, '.');
  });
  family('aurora', '오로라', 'Aurora', 22, (g, t, rng, pal) {
    pal['s'] = '#0F1A3A';
    pal['a'] = const [
      '#4ADE80',
      '#C084FC',
      '#F472B6',
      '#5EEAD4',
      '#FDE047',
      '#93C5FD',
    ][_times.indexOf(t)];
    pal['w'] = '#FFFFFF';
    pal['k'] = '#3E4C73';
    final ph = rng() * 6;
    g.each(
      (x, y) => (y - (3.2 + 1.5 * math.sin(x / 2.2 + ph))).abs() < 0.9,
      'a',
    );
    for (final (x, y) in const [
      (1, 1),
      (5, 0),
      (9, 1),
      (13, 2),
      (3, 5),
      (11, 5),
    ]) {
      if (g.at(x, y) == 's') g.set(x, y, 'w');
    }
    g.poly([(-1, 10.5), (4, 6), (7, 8), (10.5, 5.5), (16, 10.5)], 'k');
    g.recolor('k', 'w', (x, y) => y <= 5.5);
  });
  // 오로라는 시간대 대신 색이 바뀐다: 이름도 색으로
  final aurora = out.where((a) => a.name.startsWith('g_aurora_')).toList();
  const auroraKo = ['초록', '보라', '분홍', '청록', '노란', '푸른'];
  const auroraEn = ['Green', 'Violet', 'Pink', 'Teal', 'Golden', 'Blue'];
  for (var i = 0; i < aurora.length; i++) {
    final a = aurora[i];
    out[out.indexOf(a)] = ArtSource(
      name: a.name,
      ko: '${auroraKo[i]} 오로라',
      en: '${auroraEn[i]} Aurora',
      palette: a.palette,
      rows: a.rows,
    );
  }
  return out;
}

// ───────────────────────── 캐릭터 ─────────────────────────
// 12×14 상반신 초상. 기본 틀(머리·몸) 위에 머리 모양·모자·옷을 얹는다. 모두 이 게임만의 캐릭터다.

const _skins = ['#F7D2B6', '#E8B48F', '#C68642', '#8D5524', '#FAD7C0'];
const _hairs = [
  '#2D2A26',
  '#6B4423',
  '#E8C547',
  '#C0392B',
  '#F28CB1',
  '#4F7CF7',
  '#3BAF7E',
  '#8E4EC6',
  '#E5E7EB',
];
const _cloth = [
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
const _names = [
  ('하나', 'Hana'),
  ('두리', 'Duri'),
  ('민지', 'Minji'),
  ('도윤', 'Doyun'),
  ('서연', 'Seoyeon'),
  ('지호', 'Jiho'),
  ('하린', 'Harin'),
  ('준서', 'Junseo'),
  ('유나', 'Yuna'),
  ('시우', 'Siwoo'),
  ('다온', 'Daon'),
  ('은호', 'Eunho'),
  ('소라', 'Sora'),
  ('태오', 'Taeo'),
  ('아린', 'Arin'),
  ('로이', 'Roy'),
  ('나래', 'Narae'),
  ('우진', 'Woojin'),
  ('별이', 'Byeori'),
  ('해솔', 'Haesol'),
  ('가온', 'Gaon'),
  ('바다', 'Bada'),
  ('새봄', 'Saebom'),
  ('하람', 'Haram'),
  ('이든', 'Eden'),
  ('수아', 'Sua'),
  ('단비', 'Danbi'),
  ('로운', 'Rowoon'),
  ('미루', 'Miru'),
  ('찬', 'Chan'),
  ('예준', 'Yejun'),
  ('채아', 'Chaea'),
  ('온유', 'Onyu'),
  ('라온', 'Raon'),
  ('보리', 'Bori'),
  ('하율', 'Hayul'),
];

/// 머리(얼굴)와 어깨. 얼굴 's', 눈 'k', 볼·입 'r', 옷 'c'
Grid _bust({bool face = true}) {
  final g = Grid(12, 14);
  g.poly([(1.2, 14), (2.6, 10.4), (9.4, 10.4), (10.8, 14)], 'c');
  g.ell(6, 5.6, 4.2, 4.4, 's');
  if (face) _face(g);
  return g;
}

void _face(Grid g, {int eyeY = 5}) {
  for (final x in const [4, 7]) {
    g.set(x, eyeY, 'k');
    g.set(x, eyeY + 1, 'k');
  }
  for (final (x, y) in [
    (3, eyeY + 2),
    (8, eyeY + 2),
    (5, eyeY + 3),
    (6, eyeY + 3),
  ]) {
    g.set(x, y, 'r');
  }
}

void _hair(Grid g, int style) {
  bool head(double x, double y) =>
      math.pow((x - 6) / 4.2, 2) + math.pow((y - 5.6) / 4.4, 2) <= 1;
  // 공통: 머리 윗부분
  g.each((x, y) => head(x, y) && y < 4.1, 'h');
  g.each((x, y) => head(x, y) && y < 6 && (x < 2.6 || x > 9.4), 'h');
  switch (style) {
    case 0: // 짧은 머리 + 앞머리
      g.set(5, 4, 'h');
      g.set(6, 4, 'h');
    case 1: // 긴 생머리
      g.rect(1, 4, 2, 11, 'h');
      g.rect(9, 4, 10, 11, 'h');
    case 2: // 단발
      g.rect(1, 4, 2, 8, 'h');
      g.rect(9, 4, 10, 8, 'h');
      g.rect(3, 4, 8, 4, 'h');
    case 3: // 올림머리
      g.ell(6, 1.0, 2.0, 1.2, 'h');
    case 4: // 양갈래
      g.ell(1.0, 7.0, 1.2, 2.0, 'h');
      g.ell(11.0, 7.0, 1.2, 2.0, 'h');
    case 5: // 삐죽 머리
      for (final x in const [2.5, 5.0, 7.5, 10.0]) {
        g.poly([(x - 1.4, 2.4), (x, -0.4), (x + 1.4, 2.4)], 'h');
      }
    default: // 곱슬
      for (final (x, y) in const [
        (2.0, 2.4),
        (4.4, 1.2),
        (7.6, 1.2),
        (10.0, 2.4),
        (1.4, 5.0),
        (10.6, 5.0),
      ]) {
        g.ell(x, y, 1.5, 1.4, 'h');
      }
  }
}

List<ArtSource> _characters() {
  final out = <ArtSource>[];
  final rng = mulberry32(31);
  var n = 0;
  (String, String) nextName() => _names[n++ % _names.length];
  int pick(int len) => (rng() * len).floor();

  // 1) 친구들: 머리 모양 7 × 머리색·피부·옷·장신구
  for (var i = 0; i < 30; i++) {
    final g = _bust();
    _hair(g, i % 7);
    final acc = i % 5; // 0 없음, 1 리본, 2 안경, 3 모자, 4 머리띠
    final pal = {
      's': _skins[pick(_skins.length)],
      'h': _hairs[(i * 4 + pick(3)) % _hairs.length],
      'k': '#1F2933',
      'r': '#F28C8C',
      'c': _cloth[(i * 5 + 2) % _cloth.length],
      'a': _cloth[(i * 5 + 6) % _cloth.length],
    };
    switch (acc) {
      case 1:
        g.poly([(7.5, 0.6), (10.5, -0.4), (10.5, 2.6)], 'a');
        g.poly([(7.5, 0.6), (5.0, -0.4), (5.0, 2.0)], 'a');
      case 2:
        for (final x in const [3, 4, 5, 6, 7, 8]) {
          g.set(x, 4, 'a');
        }
        g.set(3, 5, 'a');
        g.set(8, 5, 'a');
      case 3:
        g.rect(2, 0, 9, 2, 'a');
        g.rect(1, 2, 11, 2, 'a');
      case 4:
        g.each(
          (x, y) =>
              (math.pow((x - 6) / 4.4, 2) + math.pow((y - 5.6) / 4.6, 2) - 1)
                      .abs() <
                  0.22 &&
              y < 3.6,
          'a',
        );
    }
    final (ko, en) = nextName();
    out.add(makeArt('g_friend_$i', '친구 $ko', 'Friend $en', pal, g));
  }

  // 2) 직업 친구들: 12가지 × 3명
  final jobs =
      <
        (
          String id,
          String ko,
          String en,
          void Function(Grid g, Map<String, String> pal, int v),
        )
      >[
        (
          'chef',
          '요리사',
          'Chef',
          (g, pal, v) {
            _hair(g, 0);
            g.ell(6, 0.9, 4.0, 1.3, 'w');
            g.rect(2, 1, 9, 2, 'w');
            g.recolor('c', 'w', (x, y) => true);
            g.rect(5, 10, 6, 11, 'a');
            pal['w'] = '#FFFFFF';
          },
        ),
        (
          'astronaut',
          '우주비행사',
          'Astronaut',
          (g, pal, v) {
            g.each(
              (x, y) =>
                  math.pow((x - 6) / 5.6, 2) + math.pow((y - 5.6) / 5.4, 2) <=
                      1 &&
                  math.pow((x - 6) / 4.2, 2) + math.pow((y - 5.8) / 3.9, 2) > 1,
              'w',
            );
            g.recolor('c', 'w', (x, y) => true);
            g.rect(4, 11, 7, 12, 'a');
            pal['w'] = '#E5E7EB';
          },
        ),
        (
          'knight',
          '기사',
          'Knight',
          (g, pal, v) {
            g.each(
              (x, y) =>
                  math.pow((x - 6) / 4.4, 2) + math.pow((y - 5.4) / 4.6, 2) <=
                      1 &&
                  (y < 4.6 || y > 7.4 || x < 3 || x > 9),
              'm',
            );
            g.poly([(5, 1), (6, -1), (9, -0.5), (7, 1.5)], 'a');
            g.recolor('c', 'm', (x, y) => y > 10.5);
            g.rect(5, 10, 6, 13, 'a');
            pal['m'] = '#9CA3AF';
          },
        ),
        (
          'witch',
          '마녀',
          'Witch',
          (g, pal, v) {
            _hair(g, 1);
            g.poly([(2.5, 2.4), (7.5, -1.5), (9.5, 2.4)], 'a');
            g.rect(0, 2, 11, 2, 'a');
            g.recolor('c', 'a', (x, y) => true);
          },
        ),
        (
          'pirate',
          '해적',
          'Pirate',
          (g, pal, v) {
            _hair(g, 6);
            g.rect(2, 1, 9, 3, 'a');
            g.rect(10, 2, 11, 4, 'a');
            g.set(7, 5, 'k');
            g.rect(6, 4, 8, 4, 'k');
            g.recolor('c', 'w', (x, y) => y.isEven);
            pal['w'] = '#FFFFFF';
          },
        ),
        (
          'wizard',
          '마법사',
          'Wizard',
          (g, pal, v) {
            g.poly([(2, 2.6), (6, -2.5), (10, 2.6)], 'a');
            g.rect(1, 2, 10, 2, 'a');
            g.set(5, 0, 'y');
            g.set(7, 1, 'y');
            g.set(4, 2, 'y');
            g.poly([(2.5, 7.8), (9.5, 7.8), (6, 13.5)], 'w');
            pal['w'] = '#F3F4F6';
            pal['y'] = '#F5D90A';
          },
        ),
        (
          'farmer',
          '농부',
          'Farmer',
          (g, pal, v) {
            _hair(g, 0);
            g.rect(0, 2, 11, 2, 'y');
            g.ell(6, 1.2, 3.4, 1.4, 'y');
            g.rect(3, 11, 8, 13, 'a');
            g.set(3, 10, 'a');
            g.set(8, 10, 'a');
            pal['y'] = '#E9C46A';
          },
        ),
        (
          'firefighter',
          '소방관',
          'Firefighter',
          (g, pal, v) {
            g.ell(6, 2.6, 4.8, 2.7, 'a');
            g.rect(0, 3, 11, 3, 'a');
            g.rect(5, 1, 6, 2, 'y');
            g.recolor('c', 'y', (x, y) => y == 12);
            pal['a'] = '#D62828';
            pal['y'] = '#F5D90A';
            pal['c'] = '#B08850';
          },
        ),
        (
          'ninja',
          '닌자',
          'Ninja',
          (g, pal, v) {
            g.each(
              (x, y) =>
                  math.pow((x - 6) / 4.4, 2) + math.pow((y - 5.6) / 4.6, 2) <=
                      1 &&
                  !(y > 4 && y < 7.2 && x > 2.4 && x < 9.6),
              'n',
            );
            g.recolor('r', 'n', (x, y) => true);
            g.recolor('c', 'n', (x, y) => true);
            g.rect(0, 4, 2, 4, 'a');
            g.rect(1, 12, 10, 12, 'a');
            pal['n'] = '#2B2D42';
          },
        ),
        (
          'royal',
          '왕자님',
          'Royal',
          (g, pal, v) {
            _hair(g, v == 1 ? 1 : 0);
            g.rect(3, 1, 8, 2, 'y');
            for (final x in const [3, 5, 6, 8]) {
              g.set(x, 0, 'y');
            }
            g.poly([(0.5, 14), (2.0, 10.5), (3.2, 10.5), (2.4, 14)], 'a');
            g.poly([(11.5, 14), (10.0, 10.5), (8.8, 10.5), (9.6, 14)], 'a');
            pal['y'] = '#F5B301';
          },
        ),
        (
          'detective',
          '탐정',
          'Detective',
          (g, pal, v) {
            g.ell(6, 2.0, 3.4, 1.8, 'a');
            g.rect(0, 3, 11, 3, 'a');
            g.recolor('c', 'y', (x, y) => true);
            g.rect(5, 10, 6, 13, 'a');
            pal['y'] = '#C8A26B';
            pal['a'] = '#6B4423';
          },
        ),
        (
          'painter',
          '화가',
          'Painter',
          (g, pal, v) {
            _hair(g, 2);
            g.ell(5.5, 1.4, 4.2, 1.5, 'a');
            g.set(9, 0, 'a');
            g.recolor('c', 'w', (x, y) => true);
            for (final (x, y) in const [(4, 11), (7, 12), (5, 13)]) {
              g.set(x, y, 'a');
            }
            pal['w'] = '#F3F4F6';
          },
        ),
      ];
  const royalKo = ['왕자님', '공주님', '임금님'],
      royalEn = ['Prince', 'Princess', 'Monarch'];
  for (final (id, ko, en, draw) in jobs) {
    for (var v = 0; v < 3; v++) {
      final g = _bust();
      final pal = <String, String>{
        's': _skins[(v * 2 + id.length) % _skins.length],
        'h': _hairs[(v * 3 + id.length) % _hairs.length],
        'k': '#1F2933',
        'r': '#F28C8C',
        'c': _cloth[(v * 3 + id.length) % _cloth.length],
        'a': _cloth[(v * 3 + id.length + 4) % _cloth.length],
      };
      draw(g, pal, v);
      final (nk, ne) = nextName();
      final jk = id == 'royal' ? royalKo[v] : ko,
          je = id == 'royal' ? royalEn[v] : en;
      out.add(makeArt('g_${id}_$v', '$jk $nk', '$je $ne', pal, g));
    }
  }

  // 3) 로봇
  const robots = [
    ('볼트', 'Bolt'),
    ('너트', 'Nut'),
    ('기어', 'Gear'),
    ('스파크', 'Spark'),
    ('픽셀', 'Pixel'),
    ('큐브', 'Cube'),
    ('코코', 'Coco'),
    ('비비', 'Bibi'),
    ('로로', 'Roro'),
    ('제트', 'Jet'),
    ('핑', 'Ping'),
    ('모모', 'Momo'),
  ];
  for (var i = 0; i < robots.length; i++) {
    final g = Grid(12, 14);
    final round = i % 3 == 1, wide = i % 3 == 2;
    g.rect(2, 10, 9, 13, 'c');
    g.rect(1, 11, 1, 13, 'm');
    g.rect(10, 11, 10, 13, 'm');
    if (round) {
      g.ell(6, 5.5, 4.4, 3.9, 'm');
    } else {
      g.rect(wide ? 0 : 1, 2, wide ? 11 : 10, 8, 'm');
      g.set(wide ? 0 : 1, 2, '.');
      g.set(wide ? 11 : 10, 2, '.');
    }
    g.rect(5, 9, 6, 9, 'k');
    g.rect(5, 0, 6, 1, 'a');
    if (i % 4 == 0) g.rect(5, 0, 6, 0, 'e');
    switch (i % 4) {
      case 0 || 1:
        g.rect(3, 4, 4, 5, 'e');
        g.rect(7, 4, 8, 5, 'e');
      case 2:
        g.rect(3, 4, 8, 5, 'e');
      default:
        g.ell(6, 4.8, 1.6, 1.4, 'e');
    }
    g.rect(4, 7, 7, 7, 'k');
    g.set(4, 12, 'a');
    g.set(7, 12, 'e');
    final pal = {
      'm': const [
        '#9CA3AF',
        '#60A5FA',
        '#F87171',
        '#FBBF24',
        '#A78BFA',
        '#34D399',
      ][i % 6],
      'c': const [
        '#4B5563',
        '#1E40AF',
        '#9F1239',
        '#B45309',
        '#5B21B6',
        '#065F46',
      ][(i + 1) % 6],
      'e': const ['#22D3EE', '#F5D90A', '#FFFFFF', '#F472B6'][i % 4],
      'a': '#E5484D',
      'k': '#1F2933',
    };
    out.add(
      makeArt(
        'g_robot_$i',
        '로봇 ${robots[i].$1}',
        'Robot ${robots[i].$2}',
        pal,
        g,
      ),
    );
  }

  // 4) 귀여운 몬스터: 5종 × 3색
  const monCols = [
    ['#7DD87D', '#3E9E5A'],
    ['#93C5FD', '#3B82F6'],
    ['#F9A8D4', '#DB2777'],
  ];
  const monColKo = ['초록', '파랑', '분홍'], monColEn = ['Green', 'Blue', 'Pink'];
  final mons = <(String, String, String, void Function(Grid g))>[
    (
      'slime',
      '슬라임',
      'Slime',
      (g) {
        g.poly([
          (0.5, 13),
          (2, 6),
          (4.5, 2.5),
          (7.5, 2.5),
          (10, 6),
          (11.5, 13),
        ], 'm');
        g.ell(6, 12.4, 5.8, 1.2, 'd');
        g.set(4, 5, 'w');
        g.set(4, 4, 'w');
        _face(g, eyeY: 7);
      },
    ),
    (
      'ghost',
      '유령',
      'Ghost',
      (g) {
        g.ell(6, 5.5, 4.8, 5.0, 'm');
        g.rect(1, 6, 10, 11, 'm');
        for (final x in const [1, 4, 7, 10]) {
          g.rect(x, 12, x + 1, 12, 'm');
        }
        g.rect(1, 11, 10, 11, 'd');
        _face(g, eyeY: 5);
      },
    ),
    (
      'alien',
      '외계인',
      'Alien',
      (g) {
        g.ell(6, 6.5, 4.6, 4.4, 'm');
        g.rect(3, 11, 8, 13, 'd');
        g.rect(2, 0, 2, 2, 'd');
        g.rect(9, 0, 9, 2, 'd');
        g.ell(4, 6.2, 1.3, 1.6, 'k');
        g.ell(8, 6.2, 1.3, 1.6, 'k');
        g.rect(5, 9, 6, 9, 'r');
      },
    ),
    (
      'cyclops',
      '외눈 몬스터',
      'One-eyed Monster',
      (g) {
        g.ell(6, 7.5, 5.2, 5.4, 'm');
        g.poly([(2, 3.5), (2.5, 0), (4.5, 2.8)], 'd');
        g.poly([(10, 3.5), (9.5, 0), (7.5, 2.8)], 'd');
        g.ell(6, 6.5, 2.2, 2.1, 'w');
        g.rect(6, 6, 6, 7, 'k');
        g.set(5, 6, 'k');
        g.rect(4, 10, 7, 10, 'k');
        g.set(5, 11, 'w');
        g.set(6, 11, 'w');
      },
    ),
    (
      'dragon',
      '아기 용',
      'Baby Dragon',
      (g) {
        g.ell(6, 5, 3.8, 3.6, 'm');
        g.ell(6, 11, 3.2, 2.6, 'm');
        g.ell(6, 11.4, 1.8, 1.8, 'w');
        g.poly([(1.5, 9), (0, 6), (2.6, 8)], 'd');
        g.poly([(10.5, 9), (12, 6), (9.4, 8)], 'd');
        for (final x in const [4, 6, 8]) {
          g.set(x, 1, 'd');
        }
        _face(g, eyeY: 4);
      },
    ),
  ];
  for (final (id, ko, en, draw) in mons) {
    for (var v = 0; v < 3; v++) {
      final g = Grid(12, 14);
      draw(g);
      final pal = {
        'm': monCols[v][0],
        'd': monCols[v][1],
        'w': '#FFFFFF',
        'k': '#1F2933',
        'r': '#F28C8C',
      };
      out.add(
        makeArt(
          'g_${id}_$v',
          '${monColKo[v]} $ko',
          '${monColEn[v]} $en',
          pal,
          g,
        ),
      );
    }
  }

  // 5) 동물 친구 (마스코트): 얼굴 + 옷
  final animals =
      <(String, String, String, String, String, void Function(Grid g))>[
        (
          'bear',
          '곰돌이',
          'Bear Pal',
          '#A0704A',
          '#E8C9A0',
          (g) {
            g.ell(2.5, 2.2, 1.6, 1.6, 'm');
            g.ell(9.5, 2.2, 1.6, 1.6, 'm');
          },
        ),
        (
          'bunny',
          '토끼',
          'Bunny Pal',
          '#F3F4F6',
          '#F9A8D4',
          (g) {
            g.ell(4, 1.5, 1.0, 2.6, 'm');
            g.ell(8, 1.5, 1.0, 2.6, 'm');
            g.rect(4, 0, 4, 2, 'l');
            g.rect(8, 0, 8, 2, 'l');
          },
        ),
        (
          'kitty',
          '야옹이',
          'Kitty Pal',
          '#F59E0B',
          '#FDE7C1',
          (g) {
            g.poly([(1.5, 4), (2, 0), (5, 2.5)], 'm');
            g.poly([(10.5, 4), (10, 0), (7, 2.5)], 'm');
          },
        ),
        (
          'fox',
          '여우',
          'Fox Pal',
          '#EA7A2E',
          '#FFFFFF',
          (g) {
            g.poly([(1.5, 4), (1.8, -0.2), (5, 2.5)], 'm');
            g.poly([(10.5, 4), (10.2, -0.2), (7, 2.5)], 'm');
          },
        ),
        (
          'panda',
          '판다',
          'Panda Pal',
          '#FFFFFF',
          '#2D2A26',
          (g) {
            g.ell(2.5, 2.2, 1.6, 1.6, 'l');
            g.ell(9.5, 2.2, 1.6, 1.6, 'l');
          },
        ),
        (
          'frog',
          '개구리',
          'Frog Pal',
          '#6CC070',
          '#FFFFFF',
          (g) {
            g.ell(3.5, 2.2, 1.8, 1.8, 'm');
            g.ell(8.5, 2.2, 1.8, 1.8, 'm');
          },
        ),
        (
          'piggy',
          '꿀꿀이',
          'Piggy Pal',
          '#F9A8B8',
          '#E06A88',
          (g) {
            g.poly([(2, 3.5), (2.5, 0.5), (4.8, 2.3)], 'm');
            g.poly([(10, 3.5), (9.5, 0.5), (7.2, 2.3)], 'm');
          },
        ),
        (
          'mouse',
          '생쥐',
          'Mouse Pal',
          '#B8BCC6',
          '#F9A8D4',
          (g) {
            g.ell(2.2, 2.4, 2.2, 2.2, 'm');
            g.ell(9.8, 2.4, 2.2, 2.2, 'm');
            g.ell(2.2, 2.4, 1.2, 1.2, 'l');
            g.ell(9.8, 2.4, 1.2, 1.2, 'l');
          },
        ),
        (
          'tiger',
          '호랑이',
          'Tiger Pal',
          '#F59E0B',
          '#2D2A26',
          (g) {
            g.ell(2.6, 2.4, 1.5, 1.5, 'm');
            g.ell(9.4, 2.4, 1.5, 1.5, 'm');
          },
        ),
        (
          'raccoon',
          '너구리',
          'Raccoon Pal',
          '#9CA3AF',
          '#3F3F46',
          (g) {
            g.ell(2.6, 2.3, 1.5, 1.5, 'm');
            g.ell(9.4, 2.3, 1.5, 1.5, 'm');
          },
        ),
        (
          'koala',
          '코알라',
          'Koala Pal',
          '#A8AFBC',
          '#F3F4F6',
          (g) {
            g.ell(1.8, 3.4, 2.0, 2.2, 'm');
            g.ell(10.2, 3.4, 2.0, 2.2, 'm');
            g.ell(1.8, 3.4, 1.0, 1.2, 'l');
            g.ell(10.2, 3.4, 1.0, 1.2, 'l');
          },
        ),
        (
          'monkey',
          '원숭이',
          'Monkey Pal',
          '#8B5A2B',
          '#F2C9A0',
          (g) {
            g.ell(1.4, 5.6, 1.4, 1.6, 'm');
            g.ell(10.6, 5.6, 1.4, 1.6, 'm');
          },
        ),
        (
          'lion',
          '사자',
          'Lion Pal',
          '#F5B301',
          '#B45309',
          (g) {
            g.ell(6, 5.6, 5.9, 5.6, 'l');
          },
        ),
        (
          'owl',
          '부엉이',
          'Owl Pal',
          '#8B6B4A',
          '#F5D90A',
          (g) {
            g.poly([(1.6, 3.5), (2.2, 0.2), (4.6, 2.4)], 'm');
            g.poly([(10.4, 3.5), (9.8, 0.2), (7.4, 2.4)], 'm');
          },
        ),
        (
          'hamster',
          '햄스터',
          'Hamster Pal',
          '#F2B66D',
          '#FFFFFF',
          (g) {
            g.ell(2.6, 2.4, 1.3, 1.3, 'm');
            g.ell(9.4, 2.4, 1.3, 1.3, 'm');
          },
        ),
        (
          'sheep',
          '양',
          'Sheep Pal',
          '#F3F4F6',
          '#4B4B55',
          (g) {
            for (final (x, y) in const [
              (2.0, 2.6),
              (4.4, 1.4),
              (7.6, 1.4),
              (10.0, 2.6),
              (1.4, 5.6),
              (10.6, 5.6),
            ]) {
              g.ell(x, y, 1.6, 1.5, 'm');
            }
          },
        ),
      ];
  for (var i = 0; i < animals.length; i++) {
    final (id, ko, en, main, light, ears) = animals[i];
    final g = Grid(12, 14);
    g.poly([(1.2, 14), (2.6, 10.4), (9.4, 10.4), (10.8, 14)], 'c');
    ears(g);
    g.ell(6, 5.8, 4.4, 4.4, 'm');
    // 얼굴 무늬
    switch (id) {
      case 'fox' ||
          'hamster' ||
          'monkey' ||
          'koala' ||
          'bunny' ||
          'bear' ||
          'kitty':
        g.ell(6, 7.6, 2.6, 1.9, 'l');
      case 'panda' || 'raccoon':
        g.ell(4, 5.6, 1.3, 1.2, 'l');
        g.ell(8, 5.6, 1.3, 1.2, 'l');
      case 'tiger':
        for (final x in const [3, 6, 9]) {
          g.rect(x, 2, x, 3, 'l');
        }
      case 'owl' || 'frog':
        g.ell(4, 5.2, 1.5, 1.5, 'l');
        g.ell(8, 5.2, 1.5, 1.5, 'l');
      case 'sheep':
        g.ell(6, 6.6, 2.8, 2.8, 'l');
      default:
    }
    for (final x in const [4, 7]) {
      g.set(x, 5, 'k');
      g.set(x, 6, 'k');
    }
    if (id == 'panda' || id == 'raccoon' || id == 'sheep') {
      g.set(4, 5, 'w');
      g.set(7, 5, 'w');
    }
    g.rect(5, 7, 6, 7, id == 'piggy' ? 'l' : 'k');
    final pal = {
      'm': main,
      'l': light,
      'k': '#1F2933',
      'w': '#FFFFFF',
      'c': _cloth[(i * 4 + 1) % _cloth.length],
    };
    out.add(makeArt('g_pal_$id', '$ko 친구', en, pal, g));
  }
  return out;
}

// ───────────────────────── 일러스트 ─────────────────────────

const _colorWords = [
  ('빨간', 'Red', '#E5484D'),
  ('파란', 'Blue', '#3E9BDB'),
  ('초록', 'Green', '#46A758'),
  ('노란', 'Yellow', '#F5C518'),
  ('보라', 'Purple', '#8E4EC6'),
  ('주황', 'Orange', '#F76B15'),
  ('분홍', 'Pink', '#F28CB1'),
  ('청록', 'Teal', '#30A4A0'),
];

List<ArtSource> _illustrations() {
  final out = <ArtSource>[];

  // 열기구: 무늬 4 × 색 2
  const patterns = [
    ('줄무늬', 'Striped'),
    ('물방울', 'Polka-dot'),
    ('지그재그', 'Zigzag'),
    ('체크', 'Checked'),
  ];
  for (var i = 0; i < 8; i++) {
    final g = Grid(12, 16);
    g.ell(6, 5.6, 5.4, 5.6, 'a');
    g.poly([(2.2, 9.0), (9.8, 9.0), (7.4, 11.6), (4.6, 11.6)], 'a');
    final pat = i % 4;
    g.recolor(
      'a',
      'b',
      (x, y) => switch (pat) {
        0 => x ~/ 2 % 2 == 0,
        1 => (x + y) % 4 == 0 && y % 2 == 0,
        2 => (y + (x % 4 < 2 ? x % 4 : 3 - x % 4)) % 4 == 0,
        _ => (x ~/ 2 + y ~/ 2) % 2 == 0,
      },
    );
    g.set(4, 12, 'k');
    g.set(7, 12, 'k');
    g.rect(4, 13, 7, 15, 'd');
    final c1 = _colorWords[i % 8], c2 = _colorWords[(i * 3 + 3) % 8];
    final pal = {'a': c1.$3, 'b': c2.$3, 'k': '#6B4423', 'd': '#A0704A'};
    out.add(
      makeArt(
        'g_balloon_$i',
        '${c1.$1} ${patterns[pat].$1} 열기구',
        '${c1.$2} ${patterns[pat].$2} Balloon',
        pal,
        g,
      ),
    );
  }

  // 우주: 고리 행성 · 로켓 · 비행접시 × 4색
  for (var i = 0; i < 4; i++) {
    final c = _colorWords[(i * 2 + 1) % 8], d = _colorWords[(i * 2 + 4) % 8];
    final p1 = Grid(16, 12);
    bool ring(double x, double y) {
      final v = math.pow((x - 8) / 7.6, 2) + math.pow((y - 6.4) / 2.4, 2);
      return v <= 1 && v >= 0.45;
    }

    p1.each(ring, 'r');
    p1.ell(8, 5.6, 4.4, 4.4, 'a');
    p1.recolor('a', 'b', (x, y) => y == 3 || y == 7);
    p1.each((x, y) => ring(x, y) && y > 6.4, 'r');
    out.add(
      makeArt('g_planet_$i', '${c.$1} 고리 행성', '${c.$2} Ringed Planet', {
        'a': c.$3,
        'b': d.$3,
        'r': '#F3E3B5',
      }, p1),
    );

    final r = Grid(10, 16);
    r.poly([(5, -0.5), (8.2, 4), (1.8, 4)], 'a');
    r.rect(2, 4, 7, 11, 'w');
    r.ell(5, 6.5, 1.5, 1.5, 'b');
    r.poly([(2, 8), (-0.2, 12.2), (2, 12.2)], 'a');
    r.poly([(8, 8), (10.2, 12.2), (8, 12.2)], 'a');
    r.rect(3, 12, 6, 12, 'k');
    r.poly([(3, 13), (7, 13), (5, 16)], 'f');
    out.add(
      makeArt('g_rocket_$i', '${c.$1} 로켓', '${c.$2} Rocket', {
        'a': c.$3,
        'w': '#F3F4F6',
        'b': '#7FD1F5',
        'k': '#4B5563',
        'f': '#F59E0B',
      }, r),
    );

    final u = Grid(16, 12);
    u.ell(8, 3.2, 3.2, 2.6, 'b');
    u.ell(8, 5.6, 7.6, 2.0, 'a');
    for (final x in const [3, 6, 9, 12]) {
      u.set(x, 6, 'y');
    }
    u.poly([(5, 7.5), (11, 7.5), (13.5, 12), (2.5, 12)], 'l');
    out.add(
      makeArt('g_ufo_$i', '${c.$1} 비행접시', '${c.$2} UFO', {
        'b': '#9EE6F5',
        'a': c.$3,
        'y': '#F5D90A',
        'l': '#E9F7B5',
      }, u),
    );
  }

  // 정물: 꽃병 4 · 과일 그릇 4
  for (var i = 0; i < 4; i++) {
    final c = _colorWords[(i * 3) % 8], f = _colorWords[(i * 3 + 6) % 8];
    final g = Grid(12, 15);
    if (i.isEven) {
      g.ell(6, 11.5, 3.6, 3.4, 'v');
      g.rect(5, 7, 6, 8, 'v');
    } else {
      g.poly([(3.5, 15), (4.5, 7.2), (7.5, 7.2), (8.5, 15)], 'v');
    }
    g.poly([(2.6, 3.6), (3.4, 3.6), (5.6, 7.4), (4.8, 7.4)], 'g');
    g.poly([(8.6, 3.6), (9.4, 3.6), (7.2, 7.4), (6.4, 7.4)], 'g');
    g.rect(5, 3, 6, 7, 'g');
    for (final (x, y) in const [(2.6, 3.0), (6.0, 1.9), (9.4, 3.0)]) {
      g.ell(x, y, 2.0, 1.9, 'f');
    }
    g.ell(6.0, 1.9, 0.9, 0.9, 'y');
    out.add(
      makeArt('g_vase_$i', '${f.$1} 꽃 화병', '${f.$2} Flower Vase', {
        'v': c.$3,
        'w': '#FFFFFF',
        'g': '#3F8F4F',
        'f': f.$3,
        'y': '#F5D90A',
      }, g),
    );
  }
  const fruitSets = [
    (['#E5484D', '#F5C518', '#46A758'], '사과와 레몬', 'Apples & Lemons'),
    (['#F76B15', '#8E4EC6', '#46A758'], '오렌지와 포도', 'Oranges & Grapes'),
    (['#F28CB1', '#E5484D', '#F5C518'], '복숭아 접시', 'Peach Plate'),
    (['#46A758', '#F5C518', '#8E4EC6'], '여름 과일 그릇', 'Summer Fruit Bowl'),
  ];
  for (var i = 0; i < fruitSets.length; i++) {
    final (cols, ko, en) = fruitSets[i];
    final g = Grid(15, 11);
    g.ell(4, 4.6, 2.4, 2.4, 'a');
    g.ell(10.6, 4.6, 2.4, 2.4, 'b');
    g.ell(7.4, 3.0, 2.2, 2.2, 'c');
    g.poly([(0.5, 6.4), (14.5, 6.4), (11.5, 10.6), (3.5, 10.6)], 'd');
    g.recolor('d', 'e', (x, y) => y == 7);
    out.add(
      makeArt('g_fruitbowl_$i', ko, en, {
        'a': cols[0],
        'b': cols[1],
        'c': cols[2],
        'd': '#A0704A',
        'e': '#E9C46A',
      }, g),
    );
  }

  // 탈것
  void vehicle(
    String id,
    String ko,
    String en,
    Map<String, String> pal,
    void Function(Grid g) draw, {
    int w = 16,
    int h = 11,
  }) {
    final g = Grid(w, h);
    draw(g);
    out.add(makeArt('g_$id', ko, en, pal, g));
  }

  for (var i = 0; i < 3; i++) {
    final c = _colorWords[[0, 1, 3][i]];
    vehicle(
      'car_$i',
      '${c.$1} 자동차',
      '${c.$2} Car',
      {
        'a': c.$3,
        'b': '#BEE3F8',
        'k': '#2D2A26',
        'w': '#D1D5DB',
        'y': '#F5D90A',
      },
      (g) {
        g.poly([(4, 4.5), (5.5, 1.5), (10.5, 1.5), (12, 4.5)], 'b');
        g.rect(1, 4, 14, 7, 'a');
        g.rect(7, 2, 8, 4, 'a');
        g.ell(4.5, 8.2, 1.8, 1.8, 'k');
        g.ell(11.5, 8.2, 1.8, 1.8, 'k');
        g.set(4, 8, 'w');
        g.set(11, 8, 'w');
        g.set(14, 5, 'y');
      },
    );
  }
  for (var i = 0; i < 2; i++) {
    final c = _colorWords[[3, 2][i]];
    vehicle(
      'bus_$i',
      '${c.$1} 버스',
      '${c.$2} Bus',
      {'a': c.$3, 'b': '#BEE3F8', 'k': '#2D2A26', 'w': '#FFFFFF'},
      (g) {
        g.rect(0, 1, 15, 8, 'a');
        for (var x = 1; x < 14; x += 3) {
          g.rect(x, 2, x + 1, 4, 'b');
        }
        g.rect(14, 2, 15, 6, 'b');
        g.rect(0, 6, 15, 6, 'w');
        g.ell(3.5, 9, 1.6, 1.6, 'k');
        g.ell(12.5, 9, 1.6, 1.6, 'k');
      },
    );
  }
  for (var i = 0; i < 2; i++) {
    final c = _colorWords[[0, 2][i]];
    vehicle(
      'engine_$i',
      '${c.$1} 증기기관차',
      '${c.$2} Steam Engine',
      {'a': c.$3, 'k': '#2D2A26', 'y': '#F5D90A', 'w': '#E5E7EB'},
      (g) {
        g.rect(1, 4, 9, 8, 'a');
        g.rect(10, 1, 14, 8, 'k');
        g.rect(11, 2, 13, 4, 'y');
        g.rect(3, 1, 4, 3, 'k');
        g.ell(2.5, -0.2, 1.6, 1.2, 'w');
        g.ell(3.5, 9.4, 1.5, 1.5, 'k');
        g.ell(7.5, 9.4, 1.5, 1.5, 'k');
        g.ell(12, 9.4, 1.5, 1.5, 'k');
      },
    );
  }
  for (var i = 0; i < 2; i++) {
    final c = _colorWords[[4, 7][i]];
    vehicle(
      'yacht_$i',
      '${c.$1} 돛 요트',
      '${c.$2} Yacht',
      {'w': '#FFFFFF', 'a': c.$3, 'k': '#6B4423', 'b': '#3E9BDB'},
      (g) {
        g.rect(7, 0, 7, 8, 'k');
        g.poly([(7.6, 0.5), (7.6, 7.5), (13, 7.5)], 'w');
        g.poly([(6.4, 1.5), (6.4, 7.5), (2, 7.5)], 'a');
        g.poly([(1, 8), (15, 8), (13, 10.5), (3, 10.5)], 'k');
        g.rect(0, 10, 15, 10, 'b');
      },
    );
  }
  for (var i = 0; i < 2; i++) {
    final c = _colorWords[[1, 0][i]];
    vehicle(
      'plane_$i',
      '${c.$1} 비행기',
      '${c.$2} Airplane',
      {'w': '#F3F4F6', 'a': c.$3, 'b': '#7FD1F5'},
      (g) {
        g.ell(8, 5, 7.4, 1.6, 'w');
        g.poly([(6, 5), (10, 5), (7, 10), (5, 10)], 'a');
        g.poly([(6, 5), (10, 5), (7, 0), (5, 0)], 'a');
        g.poly([(0.5, 5), (2.5, 5), (1.5, 2), (0.5, 2)], 'a');
        for (final x in const [9, 11, 13]) {
          g.set(x, 4, 'b');
        }
      },
    );
  }
  for (var i = 0; i < 2; i++) {
    final c = _colorWords[[3, 5][i]];
    vehicle(
      'submarine_$i',
      '${c.$1} 잠수함',
      '${c.$2} Submarine',
      {'a': c.$3, 'b': '#BEE3F8', 'k': '#4B5563', 'w': '#3E9BDB'},
      (g) {
        g.ell(7.5, 6.5, 6.8, 2.8, 'a');
        g.rect(6, 2, 9, 4, 'a');
        g.rect(8, 0, 8, 2, 'k');
        g.rect(8, 0, 10, 0, 'k');
        for (final x in const [4, 7, 10]) {
          g.ell(x + 0.5, 6.5, 0.9, 0.9, 'b');
        }
        g.poly([(0, 4.5), (1.6, 6.5), (0, 8.5)], 'k');
      },
    );
  }
  vehicle(
    'tractor',
    '트랙터',
    'Tractor',
    {'a': '#46A758', 'k': '#2D2A26', 'y': '#F5D90A', 'b': '#BEE3F8'},
    (g) {
      g.rect(1, 4, 10, 7, 'a');
      g.rect(7, 0, 11, 4, 'a');
      g.rect(8, 1, 10, 3, 'b');
      g.rect(2, 2, 2, 4, 'k');
      g.ell(10, 8, 2.6, 2.6, 'k');
      g.ell(3, 9, 1.8, 1.8, 'k');
      g.set(10, 8, 'y');
      g.set(3, 9, 'y');
    },
  );

  // 건물
  void building(
    String id,
    String ko,
    String en,
    Map<String, String> pal,
    void Function(Grid g) draw,
  ) {
    final g = Grid(14, 14);
    draw(g);
    out.add(makeArt('g_$id', ko, en, pal, g));
  }

  for (var i = 0; i < 2; i++) {
    final c = _colorWords[[4, 0][i]];
    building(
      'castle_$i',
      '${c.$1} 지붕 성',
      '${c.$2}-roofed Castle',
      {'m': '#C9C1B4', 'a': c.$3, 'k': '#6B4423', 'y': '#F5D90A'},
      (g) {
        g.rect(2, 6, 11, 13, 'm');
        for (final x in const [0, 10]) {
          g.rect(x, 4, x + 3, 13, 'm');
          g.poly([(x - 0.4, 4.2), (x + 2.0, -0.2), (x + 4.4, 4.2)], 'a');
        }
        for (var x = 4; x < 10; x += 2) {
          g.set(x, 5, 'm');
        }
        g.ell(7, 11.6, 1.6, 2.4, 'k');
        g.set(1, 7, 'y');
        g.set(12, 7, 'y');
      },
    );
  }
  for (var i = 0; i < 2; i++) {
    building(
      'windmill_$i',
      i == 0 ? '풍차' : '노을 풍차',
      i == 0 ? 'Windmill' : 'Sunset Windmill',
      {
        'm': i == 0 ? '#F3E3B5' : '#E8B48F',
        'k': '#6B4423',
        'w': '#FFFFFF',
        'r': '#B4553B',
        'g': '#46A758',
      },
      (g) {
        g.poly([(4, 13), (5.5, 5), (8.5, 5), (10, 13)], 'm');
        g.poly([(4.5, 5.2), (7, 2.6), (9.5, 5.2)], 'r');
        g.rect(6, 10, 7, 12, 'k');
        for (final (dx, dy) in const [
          (1.0, 1.0),
          (-1.0, 1.0),
          (1.0, -1.0),
          (-1.0, -1.0),
        ]) {
          g.each(
            (x, y) =>
                ((x - 7) * dy - (y - 4) * dx).abs() < 0.8 &&
                (x - 7) * dx > 0 &&
                (y - 4) * dy > 0 &&
                (x - 7).abs() < 5.6,
            'w',
          );
        }
        g.rect(0, 13, 13, 13, 'g');
      },
    );
  }
  for (var i = 0; i < 2; i++) {
    final c = _colorWords[[0, 1][i]];
    building(
      'cottage_$i',
      '${c.$1} 지붕 오두막',
      '${c.$2}-roofed Cottage',
      {
        'a': c.$3,
        'm': '#F3E3B5',
        'k': '#6B4423',
        'b': '#BEE3F8',
        'g': '#46A758',
        'w': '#FFFFFF',
      },
      (g) {
        g.poly([(0, 6.5), (7, 0.5), (14, 6.5)], 'a');
        g.rect(2, 6, 11, 12, 'm');
        g.rect(10, 1, 11, 4, 'k');
        g.rect(6, 9, 7, 12, 'k');
        g.rect(3, 8, 4, 9, 'b');
        g.rect(9, 8, 10, 9, 'b');
        g.rect(0, 13, 13, 13, 'g');
        g.ell(10.5, 0.2, 1.2, 0.8, 'w');
      },
    );
  }
  for (var i = 0; i < 2; i++) {
    final c = _colorWords[[5, 7][i]];
    building(
      'tent_$i',
      '${c.$1} 캠핑 텐트',
      '${c.$2} Camping Tent',
      {
        'a': c.$3,
        'k': '#2D2A26',
        'g': '#46A758',
        'y': '#F5D90A',
        'o': '#F76B15',
      },
      (g) {
        g.poly([(0.5, 12.5), (6, 2), (11.5, 12.5)], 'a');
        g.poly([(4.2, 12.5), (6, 7.5), (7.8, 12.5)], 'k');
        g.rect(0, 13, 13, 13, 'g');
        g.poly([(11, 13), (12.5, 9.5), (14, 13)], 'o');
        g.set(12, 11, 'y');
      },
    );
  }
  building(
    'pagoda',
    '탑',
    'Pagoda',
    {'r': '#B4553B', 'm': '#F3E3B5', 'k': '#2D2A26', 'y': '#F5B301'},
    (g) {
      for (final (y, hw) in const [(1, 3.0), (5, 4.5), (9, 6.0)]) {
        g.poly([
          (7 - hw - 1, y + 1.5),
          (7, y - 1.0),
          (7 + hw + 1, y + 1.5),
        ], 'r');
        g.rect((7 - hw + 1).floor(), y + 1, (7 + hw - 2).ceil(), y + 3, 'm');
      }
      g.rect(6, 11, 7, 13, 'k');
      g.rect(6, 0, 7, 0, 'y');
    },
  );
  building(
    'igloo',
    '이글루',
    'Igloo',
    {'w': '#F3F4F6', 'b': '#BEE3F8', 'k': '#3F5B7A'},
    (g) {
      g.each(
        (x, y) =>
            math.pow((x - 7) / 6.6, 2) + math.pow((y - 13) / 8.6, 2) <= 1 &&
            y < 13.5,
        'w',
      );
      g.recolor('w', 'b', (x, y) => y % 3 == 0 || (x + y ~/ 3) % 4 == 0);
      g.ell(10.5, 11.8, 1.8, 2.4, 'k');
    },
  );

  // 문양 (타일·만다라): 6가지 × 계절 색 4 = 24장. 1/8 조각을 시드로 칠하고 8방향으로 접는다
  const motifs = [
    ('별꽃 문양', 'Star Tile'),
    ('눈꽃 문양', 'Snowflake Tile'),
    ('장미창', 'Rose Window'),
    ('만다라', 'Mandala'),
    ('꽃 타일', 'Flower Tile'),
    ('바람개비 문양', 'Pinwheel Tile'),
  ];
  const seasons = [
    ('봄', 'Spring', ['#F7A8C4', '#8BD17C', '#F5D90A', '#FFFFFF']),
    ('여름', 'Summer', ['#3E9BDB', '#30A4A0', '#F5C518', '#E9F7FF']),
    ('가을', 'Autumn', ['#D9963B', '#B4553B', '#E9C46A', '#6B4423']),
    ('겨울', 'Winter', ['#5B7DB1', '#BEE3F8', '#8E4EC6', '#FFFFFF']),
  ];
  for (var m = 0; m < motifs.length; m++) {
    for (var sIdx = 0; sIdx < seasons.length; sIdx++) {
      final rng = mulberry32(100 + m * 10 + sIdx);
      final g = Grid(13, 13);
      const keys = ['a', 'b', 'c', 'd'];
      for (var y = 0; y <= 6; y++) {
        for (var x = y; x <= 6; x++) {
          final dx = 6 - x, dy = 6 - y;
          final r = math.sqrt(dx * dx + dy * dy);
          if (r > 6.4) continue;
          final ch =
              keys[((r * (1.2 + m * 0.35)).floor() +
                      (rng() < 0.35 ? 1 : 0) +
                      m) %
                  4];
          for (final (px, py) in [
            (x, y),
            (y, x),
            (12 - x, y),
            (12 - y, x),
            (x, 12 - y),
            (y, 12 - x),
            (12 - x, 12 - y),
            (12 - y, 12 - x),
          ]) {
            g.set(px, py, ch);
          }
        }
      }
      final (sk, se, cols) = seasons[sIdx];
      out.add(
        makeArt(
          'g_tile${m}_$sIdx',
          '$sk ${motifs[m].$1}',
          '$se ${motifs[m].$2}',
          {'a': cols[0], 'b': cols[1], 'c': cols[2], 'd': cols[3]},
          g,
        ),
      );
    }
  }

  // 음식
  void food(
    String id,
    String ko,
    String en,
    Map<String, String> pal,
    void Function(Grid g) draw, {
    int w = 14,
    int h = 12,
  }) {
    final g = Grid(w, h);
    draw(g);
    out.add(makeArt('g_food_$id', ko, en, pal, g));
  }

  food(
    'burger',
    '햄버거',
    'Burger',
    {
      'b': '#E9A23B',
      'w': '#FFF4C2',
      'g': '#6CC070',
      'r': '#E5484D',
      'k': '#6B3E2E',
      'y': '#F5D90A',
    },
    (g) {
      g.ell(7, 3.4, 6.2, 3.2, 'b');
      g.rect(1, 3, 12, 4, 'b');
      for (final x in const [4, 7, 10]) {
        g.set(x, 1, 'w');
      }
      g.rect(0, 5, 13, 5, 'g');
      g.rect(1, 6, 12, 6, 'r');
      g.rect(1, 7, 12, 7, 'y');
      g.rect(1, 8, 12, 8, 'k');
      g.rect(1, 9, 12, 10, 'b');
    },
  );
  food(
    'pizza',
    '피자 조각',
    'Pizza Slice',
    {'y': '#F5C518', 'c': '#D9963B', 'r': '#E5484D', 'g': '#46A758'},
    (g) {
      g.poly([(0, 0), (14, 0), (7, 12)], 'y');
      g.rect(0, 0, 13, 1, 'c');
      for (final (x, y) in const [(4, 3), (8, 3), (6, 6), (9, 5)]) {
        g.set(x, y, 'r');
        g.set(x + 1, y, 'r');
      }
      g.set(5, 4, 'g');
      g.set(7, 8, 'g');
    },
  );
  food(
    'sushi',
    '초밥',
    'Sushi',
    {'w': '#FFFFFF', 'o': '#F59E61', 'l': '#FDE1CB', 'k': '#2D3A2E'},
    (g) {
      g.ell(7, 8, 6.4, 2.8, 'w');
      g.ell(7, 4.6, 6.6, 2.6, 'o');
      g.recolor('o', 'l', (x, y) => (x + y) % 4 == 0);
      g.rect(6, 3, 7, 10, 'k');
    },
  );
  food(
    'ramen',
    '라면 한 그릇',
    'Ramen Bowl',
    {
      'r': '#E5484D',
      'y': '#F3D27A',
      'w': '#FFFFFF',
      'g': '#46A758',
      'k': '#6B3E2E',
      'o': '#F5B301',
    },
    (g) {
      g.poly([(0, 5), (14, 5), (11, 11.5), (3, 11.5)], 'r');
      g.rect(1, 4, 12, 5, 'y');
      g.ell(4, 3.6, 1.6, 1.4, 'w');
      g.set(4, 3, 'o');
      g.set(8, 3, 'g');
      g.set(9, 3, 'g');
      g.rect(10, 0, 10, 4, 'k');
      g.rect(12, 0, 12, 4, 'k');
      g.recolor('r', 'w', (x, y) => y == 8);
    },
  );
  food(
    'sandwich',
    '샌드위치',
    'Sandwich',
    {
      'b': '#F3D9A4',
      'c': '#C68642',
      'g': '#6CC070',
      'r': '#E5484D',
      'y': '#F5D90A',
    },
    (g) {
      g.ell(7, 2.6, 6.6, 2.2, 'c');
      g.ell(7, 2.9, 5.8, 1.6, 'b');
      g.rect(0, 4, 13, 4, 'g');
      g.rect(1, 5, 12, 5, 'r');
      g.rect(1, 6, 12, 6, 'y');
      g.rect(0, 7, 13, 7, 'g');
      g.rect(1, 8, 12, 10, 'b');
      g.rect(0, 11, 13, 11, 'c');
      g.rect(0, 8, 0, 10, 'c');
      g.rect(13, 8, 13, 10, 'c');
    },
  );
  food(
    'onigiri',
    '주먹밥',
    'Rice Ball',
    {'w': '#FFFFFF', 'k': '#2D3A2E', 'p': '#F28CB1'},
    (g) {
      g.poly([(0.6, 11.4), (5, 1.2), (9, 1.2), (13.4, 11.4)], 'w');
      g.ell(7, 2.0, 2.6, 1.6, 'w');
      g.rect(4, 7, 9, 11, 'k');
      g.set(6, 4, 'p');
      g.set(7, 4, 'p');
      g.set(7, 5, 'p');
    },
  );
  food(
    'dumpling',
    '만두',
    'Dumplings',
    {'w': '#FFF4E0', 'c': '#E3C49A', 'k': '#6B3E2E', 'g': '#46A758'},
    (g) {
      g.ell(7, 10.6, 7.0, 1.4, 'k');
      for (final (cx, cy) in const [(3.6, 7.6), (10.4, 7.6), (7.0, 5.0)]) {
        g.each(
          (x, y) =>
              math.pow((x - cx) / 3.4, 2) + math.pow((y - cy - 1.6) / 3.2, 2) <=
                  1 &&
              y < cy + 1.8,
          'w',
        );
        for (var x = (cx - 2).round(); x <= (cx + 2).round(); x += 2) {
          g.set(x, (cy - 1).round(), 'c');
        }
      }
      g.set(6, 2, 'g');
      g.set(7, 2, 'g');
    },
  );
  food(
    'popsicle',
    '아이스바',
    'Popsicle',
    {'a': '#F28CB1', 'b': '#F5C518', 'c': '#3E9BDB', 'k': '#C8A26B'},
    (g) {
      g.ell(7, 2.8, 4.0, 2.6, 'a');
      g.rect(3, 3, 10, 5, 'a');
      g.rect(3, 6, 10, 7, 'b');
      g.rect(3, 8, 10, 9, 'c');
      g.rect(6, 10, 7, 11, 'k');
    },
    h: 12,
  );
  food(
    'egg',
    '달걀 프라이',
    'Fried Egg',
    {'w': '#FFFFFF', 'y': '#F5B301', 'o': '#F59E0B'},
    (g) {
      for (final (x, y, r) in const [
        (4.5, 5.0, 3.6),
        (9.0, 4.5, 3.6),
        (7.0, 8.0, 3.6),
        (3.6, 8.4, 2.4),
        (11.0, 8.0, 2.4),
      ]) {
        g.ell(x, y, r, r * 0.9, 'w');
      }
      g.ell(7, 6, 2.4, 2.2, 'y');
      g.set(6, 5, 'o');
      g.set(6, 6, 'o');
      g.set(7, 5, 'o');
    },
  );
  food(
    'hotdog',
    '핫도그',
    'Hot Dog',
    {'b': '#E9A23B', 'r': '#B4553B', 'y': '#F5D90A'},
    (g) {
      g.ell(7, 7.2, 6.8, 2.8, 'b');
      g.ell(7, 5.6, 7.2, 1.6, 'r');
      for (var x = 1; x < 13; x += 2) {
        g.set(x, x % 4 == 1 ? 5 : 6, 'y');
      }
    },
    w: 15,
    h: 11,
  );
  food(
    'taco',
    '타코',
    'Taco',
    {
      'y': '#F5C518',
      'o': '#D9963B',
      'g': '#6CC070',
      'r': '#E5484D',
      'k': '#6B3E2E',
      'w': '#FFF4C2',
    },
    (g) {
      // 반달 모양 껍질 위로 속이 보인다
      bool shell(double x, double y) =>
          math.pow((x - 7) / 6.6, 2) + math.pow((y - 4) / 7.4, 2) <= 1 &&
          y >= 4;
      g.each(shell, 'y');
      g.each((x, y) => shell(x, y) && (x + y).floor() % 5 == 0, 'o');
      g.ell(7, 3.6, 6.0, 1.6, 'g');
      for (final x in const [2, 5, 8, 11]) {
        g.set(x, 3, 'r');
      }
      for (final x in const [3, 7, 10]) {
        g.set(x, 2, 'k');
      }
      g.set(6, 2, 'w');
      g.set(9, 3, 'w');
    },
  );
  food(
    'bento',
    '도시락',
    'Bento Box',
    {
      'k': '#2D2A26',
      'w': '#FFFFFF',
      'r': '#E5484D',
      'g': '#46A758',
      'y': '#F5D90A',
      'o': '#F76B15',
    },
    (g) {
      g.rect(0, 1, 13, 11, 'k');
      g.rect(1, 2, 6, 10, 'w');
      g.set(3, 6, 'r');
      g.set(4, 6, 'r');
      g.rect(8, 2, 12, 5, 'g');
      g.rect(8, 7, 9, 10, 'y');
      g.rect(11, 7, 12, 10, 'o');
    },
  );

  // 악기
  void inst(
    String id,
    String ko,
    String en,
    Map<String, String> pal,
    void Function(Grid g) draw, {
    int w = 14,
    int h = 14,
  }) {
    final g = Grid(w, h);
    draw(g);
    out.add(makeArt('g_inst_$id', ko, en, pal, g));
  }

  inst(
    'drum',
    '북',
    'Drum',
    {'r': '#E5484D', 'w': '#F3F4F6', 'y': '#F5B301', 'k': '#6B4423'},
    (g) {
      g.ell(7, 5, 6.2, 2.2, 'w');
      g.rect(1, 5, 12, 11, 'r');
      g.ell(7, 11, 6.2, 2.0, 'r');
      g.recolor('r', 'y', (x, y) => (x + y) % 4 == 0 && y > 5 && y < 12);
      g.poly([(2, 0), (3, 0), (6, 4), (5, 4)], 'k');
      g.poly([(11, 0), (12, 0), (9, 4), (8, 4)], 'k');
    },
  );
  inst(
    'piano',
    '피아노 건반',
    'Piano Keys',
    {'w': '#FFFFFF', 'k': '#2D2A26', 'r': '#B4553B'},
    (g) {
      g.rect(0, 2, 15, 3, 'r');
      g.rect(0, 4, 15, 11, 'w');
      for (var x = 1; x < 16; x += 2) {
        g.rect(x, 4, x, 11, x % 4 == 1 ? 'w' : 'w');
      }
      for (final x in const [1, 3, 7, 9, 11]) {
        g.rect(x, 4, x + 1, 7, 'k');
      }
      for (var x = 2; x < 16; x += 2) {
        g.set(x, 11, 'k');
      }
    },
    w: 16,
    h: 12,
  );
  inst(
    'xylophone',
    '실로폰',
    'Xylophone',
    {
      'a': '#E5484D',
      'b': '#F76B15',
      'c': '#F5C518',
      'd': '#46A758',
      'e': '#3E9BDB',
      'f': '#8E4EC6',
    },
    (g) {
      const keys = ['a', 'b', 'c', 'd', 'e', 'f'];
      for (var i = 0; i < 6; i++) {
        final x = 1 + i * 2;
        g.rect(x, 1 + i, x + 1, 13 - i, keys[i]);
      }
    },
  );
  inst(
    'trumpet',
    '트럼펫',
    'Trumpet',
    {'y': '#F5B301', 'o': '#D9963B', 'w': '#FFF4C2'},
    (g) {
      g.rect(0, 5, 10, 6, 'y');
      g.poly([(9, 6), (13.6, 1.5), (13.6, 10.5)], 'y');
      g.rect(13, 2, 13, 9, 'o');
      g.rect(3, 3, 3, 8, 'o');
      g.rect(5, 3, 5, 8, 'o');
      g.rect(7, 3, 7, 8, 'o');
      g.set(3, 2, 'w');
      g.set(5, 2, 'w');
      g.set(7, 2, 'w');
    },
    h: 12,
  );
  return out;
}

List<ArtSource> generatedArts() => [
  ..._landscapes(),
  ..._characters(),
  ..._illustrations(),
  ...complexArts(),
  ...hiresArts(),
];
